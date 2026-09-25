"""Native shared replay blocks for itertools.tee.

Each block has one Python GC owner, so shared cursors never report the same
owned reference twice. Cursor movement and replay are Jac algorithms; Python's
standard trashcan mechanism bounds destruction of long block chains.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyIter_Next,
    PyList_GetItemRef,
    PyObject,
    PyObject_GetIter,
    PyTuple_New,
    Py_NewRef,
    jacpy_list_size,
    jacpy_object_type,
    jacpy_release,
    jacpy_tuple_set_owned,
    jacpy_type_check
}
import from jaclang.runtime.python.capi {
    required,
    checked,
    object_error,
    boundary_failure
}

obj tee_block {
    has source: ptr[PyObject] = NULL,
        next_block: ptr[PyObject] = NULL,
        values: list[ptr[PyObject]] = [],
        running: bool = False;
}

obj tee_cursor {
    has bindings: TeeBindings,
        block: ptr[PyObject] = NULL,
        index: int = 0;
}

# The binding supplies typed ownership access without routing through C callbacks.
obj TeeBindings {
    def wrap_block(type_handle: ptr[PyObject], state: tee_block) -> ptr[PyObject] abst;
    def wrap_cursor(
        type_handle: ptr[PyObject], state: tee_cursor
    ) -> ptr[PyObject] abst;

    def block_state(handle: ptr[PyObject]) -> tee_block abst;
    def cursor_state(handle: ptr[PyObject]) -> tee_cursor abst;
}

def:pub jacpy_tee_block_new -> tee_block {
    return tee_block();
}

def:pub jacpy_tee_block_init(
    state: tee_block,
    source: ptr[PyObject],
    values: ptr[PyObject],
    next_block: ptr[PyObject]
) -> i64 {
    if values != 0 and jacpy_list_size(values) > 57 {
        object_error("ValueError", "Invalid arguments");
        return -1;
    }
    state.source = Py_NewRef(source);
    if next_block != 0 {
        state.next_block = Py_NewRef(next_block);
    }
    if values != 0 {
        for i in range(int(jacpy_list_size(values))) {
            value = PyList_GetItemRef(values, i64(i));
            if value == 0 {
                return -1;
            }
            state.values.append(value);
        }
    }
    return 0;
}

def:pub jacpy_tee_block_count(state: tee_block) -> i64 {
    return i64(len(state.values)) + 2;
}

def:pub jacpy_tee_block_field(state: tee_block, field: i64) -> ptr[PyObject] {
    if field == 0 {
        return state.source;
    }
    if field == 1 {
        return state.next_block;
    }
    return state.values[int(field - 2)];
}

def:pub jacpy_tee_block_clear(state: tee_block) {
    source = state.source;
    next_block = state.next_block;
    values = state.values;
    state.source = NULL;
    state.next_block = NULL;
    state.values = [];
    jacpy_release(source);
    for value in values {
        jacpy_release(value);
    }
    jacpy_release(next_block);
}

def:pub jacpy_tee_cursor_field(state: tee_cursor) -> ptr[PyObject] {
    return state.block;
}

def:pub jacpy_tee_cursor_clear(state: tee_cursor) {
    previous = state.block;
    state.block = NULL;
    jacpy_release(previous);
}

def:pub jacpy_tee_construct(
    bindings: TeeBindings,
    type_handle: ptr[PyObject],
    data_type: ptr[PyObject],
    iterable: ptr[PyObject]
) -> ptr[PyObject] {
    iterator: ptr[PyObject] = NULL;
    block: ptr[PyObject] = NULL;
    cursor = tee_cursor(bindings);
    try {
        iterator = required(PyObject_GetIter(iterable));
        if jacpy_type_check(iterator, type_handle) != 0 {
            previous = bindings.cursor_state(iterator);
            cursor.block = Py_NewRef(previous.block);
            cursor.index = previous.index;
        } else {
            data = tee_block(source=Py_NewRef(iterator));
            block = bindings.wrap_block(data_type, data);
            if block == 0 {
                jacpy_tee_block_clear(data);
                raise boundary_failure();
            }
            cursor.block = block;
            block = NULL;
        }
        result = bindings.wrap_cursor(type_handle, cursor);
        if result == 0 {
            jacpy_tee_cursor_clear(cursor);
        }
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(iterator);
        jacpy_release(block);
    }
}

def:pub jacpy_tee_split(
    bindings: TeeBindings,
    type_handle: ptr[PyObject],
    data_type: ptr[PyObject],
    iterable: ptr[PyObject],
    count: i64
) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    first: ptr[PyObject] = NULL;
    try {
        result = required(PyTuple_New(count));
        if count > 0 {
            first = required(
                jacpy_tee_construct(bindings, type_handle, data_type, iterable)
            );
            checked(jacpy_tuple_set_owned(result, 0, Py_NewRef(first)));
            for i in range(1, int(count)) {
                checked(
                    jacpy_tuple_set_owned(
                        result,
                        i64(i),
                        required(
                            jacpy_tee_construct(bindings, type_handle, data_type, first)
                        )
                    )
                );
            }
        }
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(result);
        jacpy_release(first);
    }
}

def:pub jacpy_tee_next(cursor: tee_cursor) -> ptr[PyObject] {
    if cursor.block == 0 {
        return NULL;
    }
    state = cursor.bindings.block_state(cursor.block);
    if cursor.index >= 57 {
        if state.next_block == 0 {
            type_handle = jacpy_object_type(cursor.block);
            if type_handle == 0 {
                return NULL;
            }
            following = tee_block(source=Py_NewRef(state.source));
            next_block = cursor.bindings.wrap_block(type_handle, following);
            jacpy_release(type_handle);
            if next_block == 0 {
                jacpy_tee_block_clear(following);
                return NULL;
            }
            state.next_block = next_block;
        }
        previous = cursor.block;
        cursor.block = Py_NewRef(state.next_block);
        cursor.index = 0;
        jacpy_release(previous);
        state = cursor.bindings.block_state(cursor.block);
    }
    if cursor.index >= len(state.values) {
        if state.running {
            object_error("RuntimeError", "cannot re-enter the tee iterator");
            return NULL;
        }
        state.running = True;
        value = PyIter_Next(state.source);
        state.running = False;
        if value == 0 {
            return NULL;
        }
        state.values.append(value);
    }
    result = Py_NewRef(state.values[cursor.index]);
    cursor.index += 1;
    return result;
}
