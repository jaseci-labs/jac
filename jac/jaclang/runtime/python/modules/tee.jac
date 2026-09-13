"""Native shared replay blocks for itertools.tee.

Each block has one Python GC owner, so shared cursors never report the same
owned reference twice. Cursor movement and replay are Jac algorithms; Python's
standard trashcan mechanism bounds destruction of long block chains.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_type_check,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    required,
    checked,
    object_error,
    boundary_failure
}

obj tee_block {
    has source: u64 = 0,
        next_block: u64 = 0,
        values: list[u64] = [],
        running: bool = False;
}

obj tee_cursor {
    has bindings: TeeBindings,
        block: u64 = 0,
        index: int = 0;
}

# The binding supplies typed ownership access without routing through C callbacks.
obj TeeBindings {
    def wrap_block(type_handle: u64, state: tee_block) -> u64 abst;
    def wrap_cursor(type_handle: u64, state: tee_cursor) -> u64 abst;
    def block_state(handle: u64) -> tee_block abst;
    def cursor_state(handle: u64) -> tee_cursor abst;
}

import from c { def jacpy_object_type(value: u64) -> u64;  }

def:pub jacpy_tee_block_new -> tee_block {
    return tee_block();
}

def:pub jacpy_tee_block_init(
    state: tee_block, source: u64, values: u64, next_block: u64
) -> i64 {
    if values != 0 and jacpy_list_size(values) > 57 {
        object_error("ValueError", "Invalid arguments");
        return -1;
    }
    state.source = jacpy_retain(source);
    if next_block != 0 {
        state.next_block = jacpy_retain(next_block);
    }
    if values != 0 {
        for i in range(int(jacpy_list_size(values))) {
            value = jacpy_list_item(values, i64(i));
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

def:pub jacpy_tee_block_field(state: tee_block, field: i64) -> u64 {
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
    state.source = 0;
    state.next_block = 0;
    state.values = [];
    jacpy_release(source);
    for value in values {
        jacpy_release(value);
    }
    jacpy_release(next_block);
}

def:pub jacpy_tee_cursor_field(state: tee_cursor) -> u64 {
    return state.block;
}

def:pub jacpy_tee_cursor_clear(state: tee_cursor) {
    previous = state.block;
    state.block = 0;
    jacpy_release(previous);
}

def:pub jacpy_tee_construct(
    bindings: TeeBindings, type_handle: u64, data_type: u64, iterable: u64
) -> u64 {
    iterator: u64 = 0;
    block: u64 = 0;
    cursor = tee_cursor(bindings);
    try {
        iterator = required(jacpy_iter(iterable));
        if jacpy_type_check(iterator, type_handle) != 0 {
            previous = bindings.cursor_state(iterator);
            cursor.block = jacpy_retain(previous.block);
            cursor.index = previous.index;
        } else {
            data = tee_block(source=jacpy_retain(iterator));
            block = bindings.wrap_block(data_type, data);
            if block == 0 {
                jacpy_tee_block_clear(data);
                raise boundary_failure();
            }
            cursor.block = block;
            block = 0;
        }
        result = bindings.wrap_cursor(type_handle, cursor);
        if result == 0 {
            jacpy_tee_cursor_clear(cursor);
        }
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(iterator);
        jacpy_release(block);
    }
}

def:pub jacpy_tee_split(
    bindings: TeeBindings, type_handle: u64, data_type: u64, iterable: u64, count: i64
) -> u64 {
    result: u64 = 0;
    first: u64 = 0;
    try {
        result = required(jacpy_tuple_new(count));
        if count > 0 {
            first = required(
                jacpy_tee_construct(bindings, type_handle, data_type, iterable)
            );
            checked(jacpy_tuple_set_owned(result, 0, jacpy_retain(first)));
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
        result = 0;
        return answer;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(result);
        jacpy_release(first);
    }
}

def:pub jacpy_tee_next(cursor: tee_cursor) -> u64 {
    if cursor.block == 0 {
        return 0;
    }
    state = cursor.bindings.block_state(cursor.block);
    if cursor.index >= 57 {
        if state.next_block == 0 {
            type_handle = jacpy_object_type(cursor.block);
            if type_handle == 0 {
                return 0;
            }
            following = tee_block(source=jacpy_retain(state.source));
            next_block = cursor.bindings.wrap_block(type_handle, following);
            jacpy_release(type_handle);
            if next_block == 0 {
                jacpy_tee_block_clear(following);
                return 0;
            }
            state.next_block = next_block;
        }
        previous = cursor.block;
        cursor.block = jacpy_retain(state.next_block);
        cursor.index = 0;
        jacpy_release(previous);
        state = cursor.bindings.block_state(cursor.block);
    }
    if cursor.index >= len(state.values) {
        if state.running {
            object_error("RuntimeError", "cannot re-enter the tee iterator");
            return 0;
        }
        state.running = True;
        value = jacpy_iter_next(state.source);
        state.running = False;
        if value == 0 {
            return 0;
        }
        state.values.append(value);
    }
    result = jacpy_retain(state.values[cursor.index]);
    cursor.index += 1;
    return result;
}
