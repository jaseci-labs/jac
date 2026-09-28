"""Native shared-cursor grouping for itertools.groupby.

Comparisons may advance either iterator recursively. Snapshot comparison
operands and publish state before releasing Python references.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyIter_Next,
    PyObject,
    PyObject_CallOneArg,
    PyObject_GetIter,
    PyObject_RichCompareBool,
    PyTuple_New,
    Py_NewRef,
    jacpy_is_none,
    jacpy_release,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.capi { required, checked, boundary_failure }

obj group_state {
    has make_group: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
        source: ptr[PyObject] = NULL,
        function: ptr[PyObject] = NULL,
        target: ptr[PyObject] = NULL,
        key: ptr[PyObject] = NULL,
        value: ptr[PyObject] = NULL,
        active_group: ptr[PyObject] = NULL;
}

def:pub jacpy_group_init(
    state: group_state, iterable: ptr[PyObject], function: ptr[PyObject]
) -> i64 {
    state.source = PyObject_GetIter(iterable);
    if state.source == 0 {
        return -1;
    }
    if jacpy_is_none(function) == 0 {
        state.function = Py_NewRef(function);
    }
    return 0;
}

def:pub jacpy_group_field(state: group_state, field: i64) -> ptr[PyObject] {
    if field == 0 {
        return state.source;
    }
    if field == 1 {
        return state.function;
    }
    if field == 2 {
        return state.target;
    }
    if field == 3 {
        return state.key;
    }
    return state.value;
}

def:pub jacpy_group_clear(state: group_state) {
    source = state.source;
    function = state.function;
    target = state.target;
    key = state.key;
    value = state.value;
    state.source = NULL;
    state.function = NULL;
    state.target = NULL;
    state.key = NULL;
    state.value = NULL;
    state.active_group = NULL;
    jacpy_release(source);
    jacpy_release(function);
    jacpy_release(target);
    jacpy_release(key);
    jacpy_release(value);
}

def:pub jacpy_group_activate(state: group_state, group: ptr[PyObject]) {
    state.active_group = group;
}

def:priv group_step(state: group_state) -> bool {
    value = PyIter_Next(state.source);
    if value == 0 {
        return False;
    }
    key = Py_NewRef(value)
        if state.function == 0
        else PyObject_CallOneArg(state.function, value);
    if key == 0 {
        jacpy_release(value);
        return False;
    }
    old_value = state.value;
    old_key = state.key;
    state.value = value;
    state.key = key;
    jacpy_release(old_value);
    jacpy_release(old_key);
    return True;
}

def:pub jacpy_group_next(state: group_state, owner: ptr[PyObject]) -> ptr[PyObject] {
    state.active_group = NULL;
    target: ptr[PyObject] = NULL;
    key: ptr[PyObject] = NULL;
    group: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        while True {
            if state.key != 0 {
                if state.target == 0 {
                    break;
                }
                target = Py_NewRef(state.target);
                key = Py_NewRef(state.key);
                comparison = PyObject_RichCompareBool(target, key, 2);
                jacpy_release(target);
                target = NULL;
                jacpy_release(key);
                key = NULL;
                checked(comparison);
                if comparison == 0 {
                    break;
                }
            }
            if not group_step(state) {
                return NULL;
            }
        }
        key = Py_NewRef(state.key);
        previous = state.target;
        state.target = Py_NewRef(key);
        jacpy_release(previous);
        group = required(state.make_group(owner, key));
        result = required(PyTuple_New(2));
        checked(jacpy_tuple_set_owned(result, 0, Py_NewRef(key)));
        checked(jacpy_tuple_set_owned(result, 1, Py_NewRef(group)));
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(target);
        jacpy_release(key);
        jacpy_release(group);
        jacpy_release(result);
    }
}

def:pub jacpy_grouper_next(
    state: group_state, owner: ptr[PyObject], target: ptr[PyObject]
) -> ptr[PyObject] {
    if state.active_group != owner {
        return NULL;
    }
    if state.value == 0 and not group_step(state) {
        return NULL;
    }
    target_snapshot = Py_NewRef(target);
    key_snapshot = Py_NewRef(state.key);
    comparison = PyObject_RichCompareBool(target_snapshot, key_snapshot, 2);
    jacpy_release(target_snapshot);
    jacpy_release(key_snapshot);
    if comparison <= 0 {
        return NULL;
    }
    result = state.value;
    old_key = state.key;
    state.value = NULL;
    state.key = NULL;
    jacpy_release(old_key);
    return result;
}
