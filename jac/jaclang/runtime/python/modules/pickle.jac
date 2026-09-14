"""Public native ABI for pickle state and Python object adapters."""
import from jaclang.runtime.python.modules.pickle_encode { pickle_state }
import from jaclang.runtime.python.modules.pickle_decode { unpickle_state }
import from jaclang.runtime.python.modules.pickle_objects { find_global }
import from jaclang.runtime.python.modules.pickle_stream { builtin_stream_error }
import from jaclang.runtime.python.capi {
    text_value,
    required,
    checked,
    boundary_failure,
    jacpy_retain,
    jacpy_release,
    jacpy_dict_memory,
    jacpy_dict_new,
    jacpy_dict_copy,
    jacpy_dict_clear,
    jacpy_dict_set,
    jacpy_is_dict,
    jacpy_is_tuple,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_mapping_items,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_int,
    jacpy_uint,
    jacpy_integer_value,
    jacpy_error_pending,
    jacpy_iter,
    jac_heap_size,
    jac_list_heap_size,
    jacpy_bytearray_memory
}

def retain_optional(value: u64) -> u64 {
    if value != 0 {
        return jacpy_retain(value);
    }
    return 0;
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
    write: u64,
    protocol: i64,
    fix_imports: i64,
    callback: u64,
    error: u64
) -> i64 {
    try {
        state.clear();
        state.error = jacpy_retain(error);
        state.protocol = int(protocol);
        state.fix_imports = fix_imports != 0;
        state.memo = required(jacpy_dict_new());
        state.buffer_callback = retain_optional(callback);
        state.stream.initialize(write, False);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_pickler_dump(
    state: pickle_state,
    value: u64,
    persistent: u64,
    reducer: u64,
    dispatch: u64,
    fast: i64
) -> i64 {
    try {
        state.persistent_id = retain_optional(persistent);
        state.reducer_override = retain_optional(reducer);
        state.dispatch = jacpy_retain(dispatch);
        state.fast = fast != 0;
        state.dump(value);
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        old_pid = state.persistent_id;
        old_reducer = state.reducer_override;
        old_dispatch = state.dispatch;
        state.persistent_id = 0;
        state.reducer_override = 0;
        state.dispatch = 0;
        jacpy_release(old_pid);
        jacpy_release(old_reducer);
        jacpy_release(old_dispatch);
    }
}

def:pub jacpy_pickler_field(state: pickle_state, index: i64) -> u64 {
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
    read: u64,
    readline: u64,
    error: u64,
    buffers: u64,
    encoding: u64,
    errors: u64
) -> i64 {
    try {
        state.clear();
        state.error = jacpy_retain(error);
        state.encoding = text_value(encoding);
        state.errors = text_value(errors);
        state.memo = required(jacpy_dict_new());
        state.stream.initialize(read, readline, error);
        if buffers != 0 {
            state.buffers = required(jacpy_iter(buffers));
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_unpickler_load(state: unpickle_state, find: u64, persistent: u64) -> u64 {
    try {
        state.find_class = jacpy_retain(find);
        state.persistent_load = retain_optional(persistent);
        return state.load();
    } except boundary_failure {
        return 0;
    } finally {
        state.reset_stack();
        old_find = state.find_class;
        old_persistent = state.persistent_load;
        state.find_class = 0;
        state.persistent_load = 0;
        jacpy_release(old_find);
        jacpy_release(old_persistent);
    }
}

def:pub jacpy_unpickler_find(
    state: unpickle_state, module: u64, name: u64, fix_imports: i64
) -> u64 {
    try {
        return find_global(module, name, state.protocol, fix_imports != 0);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_unpickler_field_count(state: unpickle_state) -> i64 {
    return 9 + i64(len(state.stack));
}

def:pub jacpy_unpickler_field(state: unpickle_state, index: i64) -> u64 {
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

def:pub jacpy_pickler_memo(state: pickle_state) -> u64 {
    return jacpy_dict_copy(state.memo) if state.memo != 0 else jacpy_dict_new();
}

def:pub jacpy_pickler_memo_clear(state: pickle_state) {
    if state.memo != 0 {
        jacpy_dict_clear(state.memo);
    }
}

def:pub jacpy_unpickler_memo(state: unpickle_state) -> u64 {
    return jacpy_dict_copy(state.memo) if state.memo != 0 else jacpy_dict_new();
}

def:pub jacpy_unpickler_memo_clear(state: unpickle_state) {
    if state.memo != 0 {
        jacpy_dict_clear(state.memo);
    }
}

def memo_copy(value: u64, pickler: bool) -> u64 {
    if jacpy_is_dict(value) == 0 {
        builtin_stream_error(
            "TypeError", "'memo' attribute must be a memo proxy or dict"
        );
    }
    result = required(jacpy_dict_new());
    items: u64 = 0;
    try {
        items = required(jacpy_mapping_items(value));
        for i in range(int(jacpy_list_size(items))) {
            pair = required(jacpy_list_item(items, i64(i)));
            key: u64 = 0;
            val: u64 = 0;
            index: u64 = 0;
            stored: u64 = 0;
            identity: u64 = 0;
            try {
                key = required(jacpy_tuple_item(pair, 0));
                val = required(jacpy_tuple_item(pair, 1));
                if pickler {
                    if jacpy_is_tuple(val) == 0 or jacpy_tuple_size(val) != 2 {
                        builtin_stream_error(
                            "TypeError", "'memo' values must be 2-item tuples"
                        );
                    }
                    index = required(jacpy_tuple_item(val, 0));
                    stored = required(jacpy_tuple_item(val, 1));
                    number = jacpy_integer_value(index);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    identity = required(jacpy_uint(stored));
                    checked(jacpy_dict_set(result, identity, val));
                } else {
                    number = jacpy_integer_value(key);
                    if jacpy_error_pending() != 0 {
                        raise boundary_failure();
                    }
                    if number < 0 {
                        builtin_stream_error(
                            "ValueError", "memo key must be positive integers."
                        );
                    }
                    index = required(jacpy_int(number));
                    checked(jacpy_dict_set(result, index, val));
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
        return jacpy_retain(result);
    } finally {
        jacpy_release(result);
        jacpy_release(items);
    }
}

def:pub jacpy_pickler_memo_set(state: pickle_state, value: u64) -> i64 {
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

def:pub jacpy_unpickler_memo_set(state: unpickle_state, value: u64) -> i64 {
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
