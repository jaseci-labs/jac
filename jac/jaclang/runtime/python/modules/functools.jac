"""Native argument binding, reduction and least-recently-used cache policies.

The object boundary retains Python callbacks and containers, including the
runtime's ordered dictionary. No Python implementation of these policies runs.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_error_pending,
    jacpy_error_is,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_call,
    jacpy_call_one,
    jacpy_call_two,
    jacpy_compare,
    jacpy_int,
    jacpy_none,
    jacpy_boolean,
    jacpy_tuple_new,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_sequence_tuple,
    jacpy_is_tuple,
    jacpy_is_exact_tuple,
    jacpy_setitem,
    jacpy_dict_new,
    jacpy_dict_copy,
    jacpy_dict_update,
    jacpy_dict_entry,
    jacpy_dict_size,
    jacpy_dict_get,
    jacpy_dict_set,
    jacpy_dict_clear,
    jacpy_is_dict,
    jacpy_is_exact_dict,
    jacpy_is_none,
    jacpy_callable,
    jacpy_is_exact_long,
    jacpy_is_exact_unicode,
    jacpy_object_type,
    jacpy_object_hash,
    jacpy_ordered_dict_new,
    jacpy_getattr_string,
    jacpy_integer_value,
    jacpy_repr_enter,
    jacpy_repr_leave,
    jacpy_object_str,
    object_error,
    required,
    checked,
    boundary_failure,
    text_object,
    text_value,
    repr_value,
    type_name
}

# A two-argument object call owns the callable arguments for the whole callback.
def:pub jacpy_reduce(function: u64, iterable: u64, initial: u64) -> u64 {
    iterator = jacpy_iter(iterable);
    if iterator == 0 {
        if jacpy_error_is("TypeError") != 0 {
            object_error("TypeError", "reduce() arg 2 must support iteration");
        }
        return 0;
    }
    accumulator: u64 = 0;
    item: u64 = 0;
    try {
        accumulator = jacpy_retain(initial)
            if initial != 0
            else jacpy_iter_next(iterator);
        if accumulator == 0 {
            if jacpy_error_pending() == 0 {
                object_error(
                    "TypeError", "reduce() of empty iterable with no initial value"
                );
            }
            return 0;
        }
        while True {
            item = jacpy_iter_next(iterator);
            if item == 0 {
                break;
            }
            next_value = required(jacpy_call_two(function, accumulator, item));
            jacpy_release(accumulator);
            accumulator = next_value;
            jacpy_release(item);
            item = 0;
        }
        if jacpy_error_pending() != 0 {
            return 0;
        }
        result = accumulator;
        accumulator = 0;
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(iterator);
        jacpy_release(accumulator);
        jacpy_release(item);
    }
}

def:pub jacpy_cmp_key(function: u64, left: u64, right: u64, operation: i64) -> u64 {
    value: u64 = 0;
    zero: u64 = 0;
    try {
        value = required(jacpy_call_two(function, left, right));
        zero = required(jacpy_int(0));
        return jacpy_compare(value, zero, operation);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(value);
        jacpy_release(zero);
    }
}

obj partial_state {
    has function: u64 = 0,
        args: u64 = 0,
        keywords: u64 = 0,
        placeholder: u64 = 0;
}

def:pub jacpy_partial_new -> partial_state {
    return partial_state();
}

def:pub jacpy_partial_field(state: partial_state, field: i64) -> u64 {
    if field == 0 {
        return state.function;
    }
    if field == 1 {
        return state.args;
    }
    if field == 2 {
        return state.keywords;
    }
    return state.placeholder;
}

def:pub jacpy_partial_clear(state: partial_state) {
    fn = state.function;
    args = state.args;
    kw = state.keywords;
    ph = state.placeholder;
    state.function = 0;
    state.args = 0;
    state.keywords = 0;
    state.placeholder = 0;
    jacpy_release(fn);
    jacpy_release(args);
    jacpy_release(kw);
    jacpy_release(ph);
}

# Produce a fresh tuple, filling holes left-to-right. Construction may preserve
# holes; invocation must supply every hole, even when it supplies Placeholder.
def:priv merge_args(old: u64, args: u64, placeholder: u64, calling: bool) -> u64 {
    n = jacpy_tuple_size(args);
    old_n = jacpy_tuple_size(old) if old != 0 else i64(0);
    holes: i64 = 0;
    for i in range(int(old_n)) {
        item = required(jacpy_tuple_item(old, i64(i)));
        if item == placeholder {
            holes += 1;
        }
        jacpy_release(item);
    }
    if calling and n < holes {
        object_error(
            "TypeError",
            "missing positional arguments in 'partial' call; expected at least "
                + str(holes)
                + ", got "
                + str(n)
        );
        raise boundary_failure();
    }
    size = old_n + n - min(n, holes);
    result = required(jacpy_tuple_new(size));
    used: i64 = 0;
    try {
        for i in range(int(old_n)) {
            item = required(jacpy_tuple_item(old, i64(i)));
            if item == placeholder and used < n {
                jacpy_release(item);
                item = required(jacpy_tuple_item(args, used));
                used += 1;
            }
            checked(jacpy_tuple_set_owned(result, i64(i), item));
        }
        position = old_n;
        while used < n {
            checked(
                jacpy_tuple_set_owned(
                    result, position, required(jacpy_tuple_item(args, used))
                )
            );
            used += 1;
            position += 1;
        }
        return result;
    } except boundary_failure {
        jacpy_release(result);
        raise;
    }
}

def:priv validate_tail(args: u64, placeholder: u64) {
    size = jacpy_tuple_size(args);
    if size > 0 {
        last = required(jacpy_tuple_item(args, size - 1));
        invalid = last == placeholder;
        jacpy_release(last);
        if invalid {
            object_error("TypeError", "trailing Placeholders are not allowed");
            raise boundary_failure();
        }
    }
}

def:pub jacpy_partial_init(
    state: partial_state,
    function: u64,
    args: u64,
    keywords: u64,
    old_args: u64,
    old_kw: u64,
    placeholder: u64
) -> i64 {
    merged: u64 = 0;
    kw: u64 = 0;
    pair: u64 = 0;
    try {
        validate_tail(args, placeholder);
        if keywords != 0 {
            pos: i64 = 0;
            while True {
                pair = jacpy_dict_entry(keywords, pos);
                if pair == 0 {
                    break;
                }
                position = required(jacpy_tuple_item(pair, 0));
                pos = jacpy_integer_value(position);
                jacpy_release(position);
                value = required(jacpy_tuple_item(pair, 2));
                invalid = value == placeholder;
                jacpy_release(value);
                jacpy_release(pair);
                pair = 0;
                if invalid {
                    object_error(
                        "TypeError",
                        "Placeholder cannot be passed as a keyword argument"
                    );
                    raise boundary_failure();
                }
            }
            if jacpy_error_pending() != 0 {
                raise boundary_failure();
            }
        }
        merged = required(merge_args(old_args, args, placeholder, False));
        kw = required(jacpy_dict_copy(old_kw) if old_kw != 0 else jacpy_dict_new());
        if keywords != 0 {
            checked(jacpy_dict_update(kw, keywords));
        }
        state.function = jacpy_retain(function);
        state.placeholder = jacpy_retain(placeholder);
        state.args = merged;
        merged = 0;
        state.keywords = kw;
        kw = 0;
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(merged);
        jacpy_release(kw);
        jacpy_release(pair);
    }
}

def:pub jacpy_partial_call(state: partial_state, args: u64, keywords: u64) -> u64 {
    fn = jacpy_retain(state.function);
    saved_args = jacpy_retain(state.args);
    saved_kw = jacpy_retain(state.keywords);
    merged: u64 = 0;
    kw: u64 = 0;
    try {
        merged = required(merge_args(saved_args, args, state.placeholder, True));
        kw = required(jacpy_dict_copy(saved_kw));
        if keywords != 0 {
            checked(jacpy_dict_update(kw, keywords));
        }
        return jacpy_call(fn, merged, kw);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(fn);
        jacpy_release(saved_args);
        jacpy_release(saved_kw);
        jacpy_release(merged);
        jacpy_release(kw);
    }
}

# Return the normalized instance dictionary. Publish all callable fields before
# releasing their old values, which may invoke arbitrary Python finalizers.
def:pub jacpy_partial_restore(state: partial_state, saved: u64) -> u64 {
    fn: u64 = 0;
    args: u64 = 0;
    kw: u64 = 0;
    dictionary: u64 = 0;
    try {
        if jacpy_is_tuple(saved) == 0 or jacpy_tuple_size(saved) != 4 {
            object_error("TypeError", "invalid partial state");
            raise boundary_failure();
        }
        fn = required(jacpy_tuple_item(saved, 0));
        args = required(jacpy_tuple_item(saved, 1));
        kw = required(jacpy_tuple_item(saved, 2));
        dictionary = required(jacpy_tuple_item(saved, 3));
        if jacpy_callable(fn) == 0
            or jacpy_is_tuple(args) == 0
            or (jacpy_is_none(kw) == 0 and jacpy_is_dict(kw) == 0)
            or (jacpy_is_none(dictionary) == 0 and jacpy_is_dict(dictionary) == 0) {
            object_error("TypeError", "invalid partial state");
            raise boundary_failure();
        }
        validate_tail(args, state.placeholder);
        if jacpy_is_exact_tuple(args) == 0 {
            normalized = required(jacpy_sequence_tuple(args));
            jacpy_release(args);
            args = normalized;
        }
        if jacpy_is_none(kw) != 0 {
            normalized_kw = required(jacpy_dict_new());
            jacpy_release(kw);
            kw = normalized_kw;
        } elif jacpy_is_exact_dict(kw) == 0 {
            normalized_kw = required(jacpy_dict_copy(kw));
            jacpy_release(kw);
            kw = normalized_kw;
        }
        old_fn = state.function;
        old_args = state.args;
        old_kw = state.keywords;
        state.function = fn;
        fn = 0;
        state.args = args;
        args = 0;
        state.keywords = kw;
        kw = 0;
        jacpy_release(old_fn);
        jacpy_release(old_args);
        jacpy_release(old_kw);
        result = dictionary;
        dictionary = 0;
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(fn);
        jacpy_release(args);
        jacpy_release(kw);
        jacpy_release(dictionary);
    }
}

def:pub jacpy_partial_repr(state: partial_state, owner: u64) -> u64 {
    entered = jacpy_repr_enter(owner);
    if entered < 0 {
        return 0;
    }
    if entered > 0 {
        return text_object("...");
    }
    fn = jacpy_retain(state.function);
    args = jacpy_retain(state.args);
    kw = jacpy_retain(state.keywords);
    pair: u64 = 0;
    item: u64 = 0;
    key: u64 = 0;
    text: u64 = 0;
    try {
        arguments = "";
        for i in range(int(jacpy_tuple_size(args))) {
            item = required(jacpy_tuple_item(args, i64(i)));
            arguments += ", " + repr_value(item);
            jacpy_release(item);
            item = 0;
        }
        pos: i64 = 0;
        while True {
            pair = jacpy_dict_entry(kw, pos);
            if pair == 0 {
                break;
            }
            item = required(jacpy_tuple_item(pair, 0));
            pos = jacpy_integer_value(item);
            jacpy_release(item);
            item = 0;
            key = required(jacpy_tuple_item(pair, 1));
            item = required(jacpy_tuple_item(pair, 2));
            text = required(jacpy_object_str(key));
            arguments += ", " + text_value(text) + "=" + repr_value(item);
            jacpy_release(item);
            item = 0;
            jacpy_release(key);
            key = 0;
            jacpy_release(text);
            text = 0;
            jacpy_release(pair);
            pair = 0;
        }
        if jacpy_error_pending() != 0 {
            return 0;
        }
        return text_object(
            type_name(owner, True) + "(" + repr_value(fn) + arguments + ")"
        );
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(fn);
        jacpy_release(args);
        jacpy_release(kw);
        jacpy_release(pair);
        jacpy_release(item);
        jacpy_release(key);
        jacpy_release(text);
        jacpy_repr_leave(owner);
    }
}

obj lru_state {
    has key_factory: Callable[[u64, u64, i64], u64],
        function: u64 = 0,
        cache: u64 = 0,
        marker: u64 = 0,
        info_type: u64 = 0,
        key_type: u64 = 0,
        move: u64 = 0,
        pop: u64 = 0,
        maximum: i64 = 0,
        typed: bool = False,
        hits: i64 = 0,
        misses: i64 = 0;
}

def:pub jacpy_lru_field(state: lru_state, field: i64) -> u64 {
    if field == 0 {
        return state.function;
    }
    if field == 1 {
        return state.cache;
    }
    if field == 2 {
        return state.marker;
    }
    if field == 3 {
        return state.info_type;
    }
    if field == 4 {
        return state.key_type;
    }
    if field == 5 {
        return state.move;
    }
    return state.pop;
}

def:pub jacpy_lru_destroy(state: lru_state) {
    fn = state.function;
    cache = state.cache;
    marker = state.marker;
    info = state.info_type;
    key = state.key_type;
    move = state.move;
    pop = state.pop;
    state.function = 0;
    state.cache = 0;
    state.marker = 0;
    state.info_type = 0;
    state.key_type = 0;
    state.move = 0;
    state.pop = 0;
    jacpy_release(fn);
    jacpy_release(cache);
    jacpy_release(marker);
    jacpy_release(info);
    jacpy_release(key);
    jacpy_release(move);
    jacpy_release(pop);
}

def:pub jacpy_lru_init(
    state: lru_state,
    function: u64,
    maximum: i64,
    typed: i64,
    info_type: u64,
    key_type: u64,
    marker: u64
) -> i64 {
    state.function = jacpy_retain(function);
    state.marker = jacpy_retain(marker);
    state.info_type = jacpy_retain(info_type);
    state.key_type = jacpy_retain(key_type);
    state.maximum = maximum;
    state.typed = typed != 0;
    try {
        state.cache = required(
            jacpy_ordered_dict_new() if maximum > 0 else jacpy_dict_new()
        );
        if maximum > 0 {
            state.move = required(jacpy_getattr_string(state.cache, "move_to_end"));
            state.pop = required(jacpy_getattr_string(state.cache, "popitem"));
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:priv cache_key(state: lru_state, args: u64, keywords: u64) -> u64 {
    n = jacpy_tuple_size(args);
    nk = jacpy_dict_size(keywords) if keywords != 0 else i64(0);
    if not state.typed and nk == 0 {
        if n == 1 {
            item = required(jacpy_tuple_item(args, 0));
            if jacpy_is_exact_long(item) != 0 or jacpy_is_exact_unicode(item) != 0 {
                return item;
            }
            jacpy_release(item);
        }
        return jacpy_retain(args);
    }
    count = n
        + (2 * nk + 1 if nk > 0 else i64(0))
        + (n + nk if state.typed else i64(0));
    key = required(jacpy_tuple_new(count));
    pair: u64 = 0;
    item: u64 = 0;
    try {
        position: i64 = 0;
        for i in range(int(n)) {
            checked(
                jacpy_tuple_set_owned(
                    key, position, required(jacpy_tuple_item(args, i64(i)))
                )
            );
            position += 1;
        }
        if nk > 0 {
            checked(jacpy_tuple_set_owned(key, position, jacpy_retain(state.marker)));
            position += 1;
            pos: i64 = 0;
            while True {
                pair = jacpy_dict_entry(keywords, pos);
                if pair == 0 {
                    break;
                }
                item = required(jacpy_tuple_item(pair, 0));
                pos = jacpy_integer_value(item);
                jacpy_release(item);
                item = 0;
                checked(
                    jacpy_tuple_set_owned(
                        key, position, required(jacpy_tuple_item(pair, 1))
                    )
                );
                position += 1;
                checked(
                    jacpy_tuple_set_owned(
                        key, position, required(jacpy_tuple_item(pair, 2))
                    )
                );
                position += 1;
                jacpy_release(pair);
                pair = 0;
            }
        }
        if state.typed {
            for i in range(int(n)) {
                item = required(jacpy_tuple_item(args, i64(i)));
                checked(
                    jacpy_tuple_set_owned(
                        key, position, required(jacpy_object_type(item))
                    )
                );
                position += 1;
                jacpy_release(item);
                item = 0;
            }
            pos = i64(0);
            while nk > 0 {
                pair = jacpy_dict_entry(keywords, pos);
                if pair == 0 {
                    break;
                }
                item = required(jacpy_tuple_item(pair, 0));
                pos = jacpy_integer_value(item);
                jacpy_release(item);
                item = required(jacpy_tuple_item(pair, 2));
                checked(
                    jacpy_tuple_set_owned(
                        key, position, required(jacpy_object_type(item))
                    )
                );
                position += 1;
                jacpy_release(item);
                item = 0;
                jacpy_release(pair);
                pair = 0;
            }
        }
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        return key;
    } except boundary_failure {
        jacpy_release(key);
        raise;
    } finally {
        jacpy_release(pair);
        jacpy_release(item);
    }
}

def:pub jacpy_lru_call(state: lru_state, args: u64, keywords: u64) -> u64 {
    if state.maximum == 0 {
        state.misses += 1;
        return jacpy_call(state.function, args, keywords);
    }
    key: u64 = 0;
    wrapped: u64 = 0;
    record: u64 = 0;
    value: u64 = 0;
    canonical: u64 = 0;
    moved: u64 = 0;
    evicted: u64 = 0;
    first: u64 = 0;
    try {
        key = required(cache_key(state, args, keywords));
        hash = jacpy_object_hash(key);
        if hash == -1 and jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        wrapped = required(state.key_factory(state.key_type, key, hash));
        record = jacpy_dict_get(state.cache, wrapped);
        if record != 0 {
            if state.maximum > 0 {
                canonical = required(jacpy_tuple_item(record, 0));
                value = required(jacpy_tuple_item(record, 1));
                moved = required(jacpy_call_one(state.move, canonical));
            } else {
                value = jacpy_retain(record);
            }
            state.hits += 1;
            result = value;
            value = 0;
            return result;
        }
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        state.misses += 1;
        value = required(jacpy_call(state.function, args, keywords));
        if state.maximum < 0 {
            checked(jacpy_dict_set(state.cache, wrapped, value));
        } else {
            record = jacpy_dict_get(state.cache, wrapped);
            if record == 0 {
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                if jacpy_dict_size(state.cache) >= state.maximum {
                    first = required(jacpy_boolean(0));
                    evicted = required(jacpy_call_one(state.pop, first));
                }
                record = required(jacpy_tuple_new(2));
                checked(jacpy_tuple_set_owned(record, 0, jacpy_retain(wrapped)));
                checked(jacpy_tuple_set_owned(record, 1, jacpy_retain(value)));
                # PyDict_SetItem bypasses OrderedDict's ordering slots.
                checked(jacpy_setitem(state.cache, wrapped, record));
            }
        }
        result = value;
        value = 0;
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(key);
        jacpy_release(wrapped);
        jacpy_release(record);
        jacpy_release(value);
        jacpy_release(canonical);
        jacpy_release(moved);
        jacpy_release(evicted);
        jacpy_release(first);
    }
}

def:pub jacpy_lru_clear(state: lru_state) -> i64 {
    state.hits = 0;
    state.misses = 0;
    if state.maximum > 0 {
        method: u64 = 0;
        args: u64 = 0;
        result: u64 = 0;
        try {
            method = required(jacpy_getattr_string(state.cache, "clear"));
            args = required(jacpy_tuple_new(0));
            result = required(jacpy_call(method, args, 0));
            return 0;
        } except boundary_failure {
            return -1;
        } finally {
            jacpy_release(method);
            jacpy_release(args);
            jacpy_release(result);
        }
    }
    jacpy_dict_clear(state.cache);
    return 0;
}

def:pub jacpy_lru_info(state: lru_state) -> u64 {
    args: u64 = 0;
    try {
        args = required(jacpy_tuple_new(4));
        checked(jacpy_tuple_set_owned(args, 0, required(jacpy_int(state.hits))));
        checked(jacpy_tuple_set_owned(args, 1, required(jacpy_int(state.misses))));
        checked(
            jacpy_tuple_set_owned(
                args,
                2,
                required(
                    jacpy_none() if state.maximum < 0 else jacpy_int(state.maximum)
                )
            )
        );
        checked(
            jacpy_tuple_set_owned(
                args, 3, required(jacpy_int(jacpy_dict_size(state.cache)))
            )
        );
        return jacpy_call(state.info_type, args, 0);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(args);
    }
}
