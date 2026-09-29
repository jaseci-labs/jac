"""Public native ABI for pickle state and Python object adapters."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_Clear,
    PyDict_Copy,
    PyDict_New,
    PyDict_SetItem,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyLong_FromUnsignedLongLong,
    PyLong_FromVoidPtr,
    PyMapping_Items,
    PyObject,
    PyObject_GetIter,
    PyTuple_Size,
    Py_NewRef,
    jacpy_bytearray_memory,
    jacpy_dict_memory,
    jacpy_error_pending,
    jacpy_is_dict,
    jacpy_is_tuple,
    jacpy_list_size,
    jacpy_release,
    jacpy_tuple_item
}
import from jaclang.runtime.python.modules.pickle_encode { pickle_state }
import from jaclang.runtime.python.modules.pickle_decode { unpickle_state }
import from jaclang.runtime.python.modules.pickle_objects { find_global }
import from jaclang.runtime.python.modules.pickle_stream { builtin_stream_error }
import from jaclang.runtime.python.capi {
    text_value,
    required,
    checked,
    boundary_failure,
    jac_heap_size,
    jac_list_heap_size
}

def retain_optional(value: ptr[PyObject]) -> ptr[PyObject] {
    if value != 0 {
        return Py_NewRef(value);
    }
    return NULL;
}

def:pub jacpy_pickler_new -> pickle_state {
    return pickle_state();
}

def:pub jacpy_pickler_clear(state: pickle_state) {
    state.clear();
}

def:pub jacpy_unpickler_new -> unpickle_state {
    return unpickle_state();
}

def:pub jacpy_unpickler_clear(state: unpickle_state) {
    state.clear();
}

def:pub jacpy_pickler_init(
    state: pickle_state,
    write: ptr[PyObject],
    protocol: i64,
    fix_imports: i64,
    callback: ptr[PyObject],
    error: ptr[PyObject]
) -> i64 {
    try {
        state.clear();
        state.error = Py_NewRef(error);
        state.protocol = int(protocol);
        state.fix_imports = fix_imports != 0;
        state.memo = required(PyDict_New());
        state.buffer_callback = retain_optional(callback);
        state.stream.initialize(write, False);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_pickler_dump(
    state: pickle_state,
    value: ptr[PyObject],
    persistent: ptr[PyObject],
    reducer: ptr[PyObject],
    dispatch: ptr[PyObject],
    fast: i64
) -> i64 {
    try {
        state.persistent_id = retain_optional(persistent);
        state.reducer_override = retain_optional(reducer);
        state.dispatch = Py_NewRef(dispatch);
        state.fast = fast != 0;
        state.dump(value);
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        old_pid = state.persistent_id;
        old_reducer = state.reducer_override;
        old_dispatch = state.dispatch;
        state.persistent_id = NULL;
        state.reducer_override = NULL;
        state.dispatch = NULL;
        jacpy_release(old_pid);
        jacpy_release(old_reducer);
        jacpy_release(old_dispatch);
    }
}

def:pub jacpy_pickler_field(state: pickle_state, index: i64) -> ptr[PyObject] {
    return [
        state.stream.buffer,
        state.stream.write,
        state.memo,
        state.persistent_id,
        state.reducer_override,
        state.dispatch,
        state.buffer_callback,
        state.error
    ][int(index)];
}

def:pub jacpy_pickler_size(state: pickle_state) -> i64 {
    result = jac_heap_size(u64(id(state))) + jac_heap_size(u64(id(state.stream)));
    if state.stream.buffer != 0 {
        result += jacpy_bytearray_memory(state.stream.buffer);
    }
    if state.memo != 0 {
        memory = jacpy_dict_memory(state.memo);
        if memory < 0 {
            return -1;
        }
        result += memory;
    }
    return result;
}

def:pub jacpy_unpickler_init(
    state: unpickle_state,
    read: ptr[PyObject],
    readline: ptr[PyObject],
    error: ptr[PyObject],
    buffers: ptr[PyObject],
    encoding: ptr[PyObject],
    errors: ptr[PyObject]
) -> i64 {
    try {
        state.clear();
        state.error = Py_NewRef(error);
        state.encoding = text_value(encoding);
        state.errors = text_value(errors);
        state.memo = required(PyDict_New());
        state.stream.initialize(read, readline, error);
        if buffers != 0 {
            state.buffers = required(PyObject_GetIter(buffers));
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_unpickler_load(
    state: unpickle_state, find: ptr[PyObject], persistent: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        state.find_class = Py_NewRef(find);
        state.persistent_load = retain_optional(persistent);
        return state.load();
    } except boundary_failure {
        return NULL;
    } finally {
        state.reset_stack();
        old_find = state.find_class;
        old_persistent = state.persistent_load;
        state.find_class = NULL;
        state.persistent_load = NULL;
        jacpy_release(old_find);
        jacpy_release(old_persistent);
    }
}

def:pub jacpy_unpickler_find(
    state: unpickle_state, module: ptr[PyObject], name: ptr[PyObject], fix_imports: i64
) -> ptr[PyObject] {
    try {
        return find_global(module, name, state.protocol, fix_imports != 0);
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_unpickler_field_count(state: unpickle_state) -> i64 {
    return 9 + i64(len(state.stack));
}

def:pub jacpy_unpickler_field(state: unpickle_state, index: i64) -> ptr[PyObject] {
    if index >= 9 {
        return state.stack[int(index - 9)];
    }
    return [
        state.stream.read,
        state.stream.readline,
        state.stream.frame,
        state.stream.error,
        state.memo,
        state.find_class,
        state.persistent_load,
        state.buffers,
        state.error
    ][int(index)];
}

def:pub jacpy_unpickler_size(state: unpickle_state) -> i64 {
    result = jac_heap_size(u64(id(state)))
        + jac_heap_size(u64(id(state.stream)))
        + jac_list_heap_size(u64(id(state.stack)))
        + jac_list_heap_size(u64(id(state.marks)));
    if state.memo != 0 {
        memory = jacpy_dict_memory(state.memo);
        if memory < 0 {
            return -1;
        }
        result += memory;
    }
    return result;
}

def:pub jacpy_pickler_memo(state: pickle_state) -> ptr[PyObject] {
    return PyDict_Copy(state.memo) if state.memo != 0 else PyDict_New();
}

def:pub jacpy_pickler_memo_clear(state: pickle_state) {
    if state.memo != 0 {
        PyDict_Clear(state.memo);
    }
}

def:pub jacpy_unpickler_memo(state: unpickle_state) -> ptr[PyObject] {
    return PyDict_Copy(state.memo) if state.memo != 0 else PyDict_New();
}

def:pub jacpy_unpickler_memo_clear(state: unpickle_state) {
    if state.memo != 0 {
        PyDict_Clear(state.memo);
    }
}

def memo_copy(value: ptr[PyObject], pickler: bool) -> ptr[PyObject] {
    if jacpy_is_dict(value) == 0 {
        builtin_stream_error(
            "TypeError", "'memo' attribute must be a memo proxy or dict"
        );
    }
    result = required(PyDict_New());
    items: ptr[PyObject] = NULL;
    try {
        items = required(PyMapping_Items(value));
        for i in range(int(jacpy_list_size(items))) {
            pair = required(PyList_GetItemRef(items, i64(i)));
            key: ptr[PyObject] = NULL;
            val: ptr[PyObject] = NULL;
            index: ptr[PyObject] = NULL;
            stored: ptr[PyObject] = NULL;
            identity: ptr[PyObject] = NULL;
            try {
                key = required(jacpy_tuple_item(pair, 0));
                val = required(jacpy_tuple_item(pair, 1));
                if pickler {
                    if jacpy_is_tuple(val) == 0 or PyTuple_Size(val) != 2 {
                        builtin_stream_error(
                            "TypeError", "'memo' values must be 2-item tuples"
                        );
                    }
                    index = required(jacpy_tuple_item(val, 0));
                    stored = required(jacpy_tuple_item(val, 1));
                    number = PyLong_AsLongLong(index);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    identity = required(PyLong_FromVoidPtr(stored));
                    checked(PyDict_SetItem(result, identity, val));
                } else {
                    number = PyLong_AsLongLong(key);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    if number < 0 {
                        builtin_stream_error(
                            "ValueError", "memo key must be positive integers."
                        );
                    }
                    index = required(PyLong_FromLongLong(number));
                    checked(PyDict_SetItem(result, index, val));
                }
            } finally {
                jacpy_release(pair);
                jacpy_release(key);
                jacpy_release(val);
                jacpy_release(index);
                jacpy_release(stored);
                jacpy_release(identity);
            }
        }
        return Py_NewRef(result);
    } finally {
        jacpy_release(result);
        jacpy_release(items);
    }
}

def:pub jacpy_pickler_memo_set(state: pickle_state, value: ptr[PyObject]) -> i64 {
    try {
        updated = memo_copy(value, True);
        old = state.memo;
        state.memo = updated;
        jacpy_release(old);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_unpickler_memo_set(state: unpickle_state, value: ptr[PyObject]) -> i64 {
    try {
        updated = memo_copy(value, False);
        old = state.memo;
        state.memo = updated;
        jacpy_release(old);
        return 0;
    } except boundary_failure {
        return -1;
    }
}
