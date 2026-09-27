"""Native streaming iterator policies for itertools.

CPython owns the user objects and invokes native iterator slots. Tuple storage
is recycled only under exclusive ownership, with finalizers deferred until the
replacement contents have been published. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Clear,
    PyIter_Next,
    PyList_Append,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyNumber_Add,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetIter,
    PyObject_IsTrue,
    PySequence_Tuple,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    jacpy_call_two,
    jacpy_error_pending,
    jacpy_is_long,
    jacpy_is_none,
    jacpy_list_exchange,
    jacpy_list_new,
    jacpy_list_size,
    jacpy_none,
    jacpy_release,
    jacpy_tuple_exchange,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_tuple_unique
}
import from jaclang.runtime.python.capi {
    required,
    checked,
    boundary_failure,
    object_error,
    text_object,
    repr_value,
    type_name
}

# These values identify iterator policies in the native bindings.
enum pipeline_kind {
    ACCUMULATE = 0,
    BATCHED = 1,
    CHAIN = 2,
    COMPRESS = 3,
    COUNT = 4,
    CYCLE = 5,
    DROPWHILE = 6,
    FILTERFALSE = 7,
    ISLICE = 8,
    PAIRWISE = 9,
    REPEAT = 10,
    STARMAP = 11,
    TAKEWHILE = 12,
    ZIP_LONGEST = 13
}

obj pipeline_state {
    has kind: i64 = 0,
        source: ptr[PyObject] = NULL,
        auxiliary: ptr[PyObject] = NULL,
        function: ptr[PyObject] = NULL,
        value: ptr[PyObject] = NULL,
        initial: ptr[PyObject] = NULL,
        result: ptr[PyObject] = NULL,
        saved: ptr[PyObject] = NULL,
        position: i64 = 0,
        stop: i64 = -1,
        step: i64 = 1,
        consumed: i64 = 0,
        active: i64 = 0,
        flag: bool = False;
}

def:pub jacpy_pipeline_new -> pipeline_state {
    return pipeline_state();
}

def:pub jacpy_pipeline_field(state: pipeline_state, field: i64) -> ptr[PyObject] {
    if field == 0 {
        return state.source;
    }
    if field == 1 {
        return state.auxiliary;
    }
    if field == 2 {
        return state.function;
    }
    if field == 3 {
        return state.value;
    }
    if field == 4 {
        return state.initial;
    }
    if field == 5 {
        return state.result;
    }
    return state.saved;
}

def:pub jacpy_pipeline_clear(state: pipeline_state) {
    source = state.source;
    auxiliary = state.auxiliary;
    function = state.function;
    value = state.value;
    initial = state.initial;
    result = state.result;
    saved = state.saved;
    state.source = NULL;
    state.auxiliary = NULL;
    state.function = NULL;
    state.value = NULL;
    state.initial = NULL;
    state.result = NULL;
    state.saved = NULL;
    jacpy_release(source);
    jacpy_release(auxiliary);
    jacpy_release(function);
    jacpy_release(value);
    jacpy_release(initial);
    jacpy_release(result);
    jacpy_release(saved);
}

def:pub jacpy_pipeline_init(
    state: pipeline_state,
    kind: i64,
    source: ptr[PyObject],
    second: ptr[PyObject],
    function: ptr[PyObject],
    initial: ptr[PyObject],
    first: i64,
    stop: i64,
    step: i64,
    flag: i64
) -> i64 {
    state.kind = kind;
    state.position = first;
    state.stop = stop;
    state.step = step;
    state.flag = flag != 0;
    item: ptr[PyObject] = NULL;
    iterator: ptr[PyObject] = NULL;
    try {
        if kind == pipeline_kind.COUNT.value or kind == pipeline_kind.REPEAT.value {
            state.value = Py_NewRef(source);
            if second != 0 {
                state.auxiliary = Py_NewRef(second);
            }
        } elif kind == pipeline_kind.ZIP_LONGEST.value {
            state.source = required(jacpy_list_new());
            state.function = Py_NewRef(function);
            state.active = PyTuple_Size(source);
            for i in range(int(state.active)) {
                item = required(jacpy_tuple_item(source, i64(i)));
                iterator = required(PyObject_GetIter(item));
                checked(PyList_Append(state.source, iterator));
                jacpy_release(item);
                item = NULL;
                jacpy_release(iterator);
                iterator = NULL;
            }
        } else {
            state.source = required(PyObject_GetIter(source));
            if second != 0 {
                state.auxiliary = required(PyObject_GetIter(second));
            }
            if function != 0 and jacpy_is_none(function) == 0 {
                state.function = Py_NewRef(function);
            }
            if initial != 0 and jacpy_is_none(initial) == 0 {
                state.initial = Py_NewRef(initial);
            }
            if kind == pipeline_kind.CYCLE.value {
                state.saved = required(jacpy_list_new());
            }
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(item);
        jacpy_release(iterator);
    }
}

# The returned tuple is owned by the caller, so callback-driven next() cannot
# recycle it while its previous elements are being released.
def reusable_tuple(previous: ptr[PyObject], width: i64) -> ptr[PyObject] {
    if previous != 0 and jacpy_tuple_unique(previous) != 0 {
        return Py_NewRef(previous);
    }
    result = required(PyTuple_New(width));
    for i in range(int(width)) {
        checked(jacpy_tuple_set_owned(result, i64(i), jacpy_none()));
    }
    return result;
}

def:priv stop_source(state: pipeline_state) {
    old = state.source;
    state.source = NULL;
    jacpy_release(old);
}

def:priv pipeline_pairwise(state: pipeline_state) -> ptr[PyObject] {
    if state.source == 0 {
        return NULL;
    }
    old: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    previous_left: ptr[PyObject] = NULL;
    previous_right: ptr[PyObject] = NULL;
    replaced: ptr[PyObject] = NULL;
    try {
        if not state.value {
            value = PyIter_Next(state.source);
            replaced = state.value;
            state.value = value;
            value = NULL;
            jacpy_release(replaced);
            if state.value == 0 {
                stop_source(state);
                return NULL;
            }
            if state.source == 0 {
                replaced = state.value;
                state.value = NULL;
                jacpy_release(replaced);
                return NULL;
            }
        }
        old = Py_NewRef(state.value);
        value = PyIter_Next(state.source);
        if value == 0 {
            stop_source(state);
            replaced = state.value;
            state.value = NULL;
            jacpy_release(replaced);
            return NULL;
        }
        result = reusable_tuple(state.result, 2);
        previous_left = jacpy_tuple_exchange(result, 0, old);
        previous_right = jacpy_tuple_exchange(result, 1, value);
        prior = state.result;
        state.result = Py_NewRef(result);
        jacpy_release(prior);
        prior = state.value;
        state.value = value;
        value = NULL;
        jacpy_release(prior);
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(old);
        jacpy_release(value);
        jacpy_release(result);
        jacpy_release(previous_left);
        jacpy_release(previous_right);
    }
}

def:priv pipeline_zip(state: pipeline_state) -> ptr[PyObject] {
    if state.active == 0 {
        return NULL;
    }
    width = jacpy_list_size(state.source);
    result: ptr[PyObject] = NULL;
    iterator: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    old_values: list[ptr[PyObject]] = [];
    try {
        result = reusable_tuple(state.result, width);
        for i in range(int(width)) {
            iterator = required(PyList_GetItemRef(state.source, i64(i)));
            if jacpy_is_none(iterator) != 0 {
                item = Py_NewRef(state.function);
            } else {
                item = PyIter_Next(iterator);
                if item == 0 {
                    state.active -= 1;
                    if state.active == 0 or jacpy_error_pending() != 0 {
                        state.active = 0;
                        return NULL;
                    }
                    empty = jacpy_none();
                    previous = jacpy_list_exchange(state.source, i64(i), empty);
                    jacpy_release(empty);
                    jacpy_release(previous);
                    item = Py_NewRef(state.function);
                }
            }
            old_values.append(jacpy_tuple_exchange(result, i64(i), item));
            jacpy_release(item);
            item = NULL;
            jacpy_release(iterator);
            iterator = NULL;
        }
        prior = state.result;
        state.result = Py_NewRef(result);
        jacpy_release(prior);
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(result);
        jacpy_release(iterator);
        jacpy_release(item);
        for old in old_values {
            jacpy_release(old);
        }
    }
}

def:pub jacpy_pipeline_next(state: pipeline_state) -> ptr[PyObject] {
    kind = state.kind;
    if kind == pipeline_kind.PAIRWISE.value {
        return pipeline_pairwise(state);
    }
    if kind == pipeline_kind.ZIP_LONGEST.value {
        return pipeline_zip(state);
    }
    item: ptr[PyObject] = NULL;
    good: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        if kind == pipeline_kind.COUNT.value {
            item = Py_NewRef(state.value);
            result = required(PyNumber_Add(item, state.auxiliary));
            prior = state.value;
            state.value = result;
            result = NULL;
            jacpy_release(prior);
            answer = item;
            item = NULL;
            return answer;
        }
        if kind == pipeline_kind.REPEAT.value {
            if state.stop == 0 {
                return NULL;
            }
            if state.stop > 0 {
                state.stop -= 1;
            }
            return Py_NewRef(state.value);
        }
        if kind == pipeline_kind.ACCUMULATE.value and state.initial != 0 {
            prior = state.value;
            state.value = state.initial;
            state.initial = NULL;
            jacpy_release(prior);
            return Py_NewRef(state.value);
        }
        if kind == pipeline_kind.CYCLE.value {
            if state.source != 0 {
                item = PyIter_Next(state.source);
                if item != 0 {
                    checked(PyList_Append(state.saved, item));
                    answer = item;
                    item = NULL;
                    return answer;
                }
                if jacpy_error_pending() != 0 {
                    return NULL;
                }
                stop_source(state);
            }
            size = jacpy_list_size(state.saved);
            if size == 0 {
                return NULL;
            }
            result = PyList_GetItemRef(state.saved, state.position);
            state.position = (state.position + 1) % size;
            answer = result;
            result = NULL;
            return answer;
        }
        if state.source == 0 {
            return NULL;
        }
        if kind == pipeline_kind.CHAIN.value {
            while state.source != 0 {
                if state.auxiliary == 0 {
                    item = PyIter_Next(state.source);
                    if item == 0 {
                        stop_source(state);
                        return NULL;
                    }
                    good = PyObject_GetIter(item);
                    jacpy_release(item);
                    item = NULL;
                    if good == 0 {
                        stop_source(state);
                        return NULL;
                    }
                    state.auxiliary = good;
                    good = NULL;
                }
                item = PyIter_Next(state.auxiliary);
                if item != 0 {
                    answer = item;
                    item = NULL;
                    return answer;
                }
                if jacpy_error_pending() != 0 {
                    return NULL;
                }
                prior = state.auxiliary;
                state.auxiliary = NULL;
                jacpy_release(prior);
            }
            return NULL;
        }
        if kind == pipeline_kind.ISLICE.value {
            while state.consumed < state.position {
                item = PyIter_Next(state.source);
                if item == 0 {
                    stop_source(state);
                    return NULL;
                }
                jacpy_release(item);
                item = NULL;
                state.consumed += 1;
            }
            if state.stop >= 0 and state.consumed >= state.stop {
                stop_source(state);
                return NULL;
            }
            item = PyIter_Next(state.source);
            if item == 0 {
                stop_source(state);
                return NULL;
            }
            state.consumed += 1;
            if state.position > i64(9223372036854775807) - state.step {
                state.position = state.stop;
            } else {
                state.position += state.step;
                if state.stop >= 0 and state.position > state.stop {
                    state.position = state.stop;
                }
            }
            answer = item;
            item = NULL;
            return answer;
        }
        if kind == pipeline_kind.BATCHED.value {
            result = required(PyTuple_New(state.step));
            for i in range(int(state.step)) {
                item = PyIter_Next(state.source);
                if item == 0 {
                    stop_source(state);
                    if jacpy_error_pending() != 0 or i == 0 {
                        return NULL;
                    }
                    if state.flag {
                        object_error("ValueError", "batched(): incomplete batch");
                        return NULL;
                    }
                    # Copy the initialized prefix; the unused tuple slots stay NULL.
                    short = required(PyTuple_New(i64(i)));
                    for j in range(i) {
                        checked(
                            jacpy_tuple_set_owned(
                                short,
                                i64(j),
                                required(jacpy_tuple_item(result, i64(j)))
                            )
                        );
                    }
                    return short;
                }
                checked(jacpy_tuple_set_owned(result, i64(i), item));
                item = NULL;
            }
            answer = result;
            result = NULL;
            return answer;
        }
        if kind == pipeline_kind.TAKEWHILE.value and state.flag {
            return NULL;
        }
        while True {
            item = PyIter_Next(state.source);
            if item == 0 {
                return NULL;
            }
            if kind == pipeline_kind.ACCUMULATE.value {
                if state.value == 0 {
                    state.value = Py_NewRef(item);
                    answer = item;
                    item = NULL;
                    return answer;
                }
                result = required(
                    PyNumber_Add(state.value, item)
                        if state.function == 0
                        else jacpy_call_two(state.function, state.value, item)
                );
                prior = state.value;
                state.value = Py_NewRef(result);
                jacpy_release(prior);
                answer = result;
                result = NULL;
                return answer;
            }
            if kind == pipeline_kind.STARMAP.value {
                good = required(PySequence_Tuple(item));
                return PyObject_Call(state.function, good, NULL);
            }
            if kind == pipeline_kind.DROPWHILE.value and state.flag {
                answer = item;
                item = NULL;
                return answer;
            }
            if kind == pipeline_kind.COMPRESS.value {
                good = PyIter_Next(state.auxiliary);
                if good == 0 {
                    return NULL;
                }
            } elif state.function == 0 {
                good = Py_NewRef(item);
            } else {
                good = required(PyObject_CallOneArg(state.function, item));
            }
            truth = PyObject_IsTrue(good);
            checked(truth);
            jacpy_release(good);
            good = NULL;
            if kind == pipeline_kind.TAKEWHILE.value {
                if truth == 0 {
                    state.flag = True;
                    return NULL;
                }
                answer = item;
                item = NULL;
                return answer;
            }
            if (kind == pipeline_kind.COMPRESS.value and truth != 0)
                or (kind != pipeline_kind.COMPRESS.value and truth == 0) {
                if kind == pipeline_kind.DROPWHILE.value {
                    state.flag = True;
                }
                answer = item;
                item = NULL;
                return answer;
            }
            jacpy_release(item);
            item = NULL;
        }
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(item);
        jacpy_release(good);
        jacpy_release(result);
    }
}

def:pub jacpy_pipeline_length(state: pipeline_state) -> i64 {
    return state.stop;
}

def:pub jacpy_pipeline_repr(
    state: pipeline_state, owner: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        name = type_name(owner, False);
        if name.startswith("itertools.") {
            name = name[10:];
        }
        if state.kind == pipeline_kind.REPEAT.value {
            return text_object(
                name
                    + "("
                    + repr_value(state.value)
                    + (", " + str(state.stop) if state.stop >= 0 else "")
                    + ")"
            );
        }
        show_step = True;
        if jacpy_is_long(state.auxiliary) != 0 {
            step = PyLong_AsLongLong(state.auxiliary);
            if jacpy_error_pending() != 0 {
                PyErr_Clear();
            } else {
                show_step = step != 1;
            }
        }
        return text_object(
            name
                + "("
                + repr_value(state.value)
                + (", " + repr_value(state.auxiliary) if show_step else "")
                + ")"
        );
    } except boundary_failure {
        return NULL;
    }
}
