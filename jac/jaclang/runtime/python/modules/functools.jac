"""Native argument binding, reduction and least-recently-used cache policies.

The object boundary retains Python callbacks and containers, including the
runtime's ordered dictionary. No Python implementation of these policies runs.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyCallable_Check,
    PyDict_Clear,
    PyDict_Copy,
    PyDict_New,
    PyDict_SetItem,
    PyDict_Update,
    PyIter_Next,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyObject_Hash,
    PyObject_RichCompare,
    PyObject_SetItem,
    PyObject_Str,
    PySequence_Tuple,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    Py_ReprEnter,
    Py_ReprLeave,
    jacpy_call_two,
    jacpy_dict_entry,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_is,
    jacpy_error_pending,
    jacpy_is_dict,
    jacpy_is_exact_dict,
    jacpy_is_exact_long,
    jacpy_is_exact_tuple,
    jacpy_is_exact_unicode,
    jacpy_is_none,
    jacpy_is_tuple,
    jacpy_none,
    jacpy_object_type,
    jacpy_ordered_dict_new,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.capi {
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
def:pub jacpy_reduce(
    function: ptr[PyObject], iterable: ptr[PyObject], initial: ptr[PyObject]
) -> ptr[PyObject] {
    iterator = PyObject_GetIter(iterable);
    if iterator == 0 {
        if jacpy_error_is("TypeError") != 0 {
            object_error("TypeError", "reduce() arg 2 must support iteration");
        }
        return NULL;
    }
    accumulator: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    try {
        accumulator = Py_NewRef(initial) if initial != 0 else PyIter_Next(iterator);
        if accumulator == 0 {
            if jacpy_error_pending() == 0 {
                object_error(
                    "TypeError", "reduce() of empty iterable with no initial value"
                );
            }
            return NULL;
        }
        while True {
            item = PyIter_Next(iterator);
            if item == 0 {
                break;
            }
            next_value = required(jacpy_call_two(function, accumulator, item));
            jacpy_release(accumulator);
            accumulator = next_value;
            jacpy_release(item);
            item = NULL;
        }
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        result = accumulator;
        accumulator = NULL;
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(iterator);
        jacpy_release(accumulator);
        jacpy_release(item);
    }
}

def:pub jacpy_cmp_key(
    function: ptr[PyObject], left: ptr[PyObject], right: ptr[PyObject], operation: i64
) -> ptr[PyObject] {
    value: ptr[PyObject] = NULL;
    zero: ptr[PyObject] = NULL;
    try {
        value = required(jacpy_call_two(function, left, right));
        zero = required(PyLong_FromLongLong(0));
        return PyObject_RichCompare(value, zero, i32(operation));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
        jacpy_release(zero);
    }
}

obj partial_state {
    has function: ptr[PyObject] = NULL,
        args: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL,
        placeholder: ptr[PyObject] = NULL;
}

def:pub jacpy_partial_new -> partial_state {
    return partial_state();
}

def:pub jacpy_partial_field(state: partial_state, field: i64) -> ptr[PyObject] {
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
    state.function = NULL;
    state.args = NULL;
    state.keywords = NULL;
    state.placeholder = NULL;
    jacpy_release(fn);
    jacpy_release(args);
    jacpy_release(kw);
    jacpy_release(ph);
}

# Produce a fresh tuple, filling holes left-to-right. Construction may preserve
# holes; invocation must supply every hole, even when it supplies Placeholder.
def:priv merge_args(
    old: ptr[PyObject], args: ptr[PyObject], placeholder: ptr[PyObject], calling: bool
) -> ptr[PyObject] {
    n = PyTuple_Size(args);
    old_n = PyTuple_Size(old) if old != 0 else i64(0);
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
    result = required(PyTuple_New(size));
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

def:priv validate_tail(args: ptr[PyObject], placeholder: ptr[PyObject]) {
    size = PyTuple_Size(args);
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
    function: ptr[PyObject],
    args: ptr[PyObject],
    keywords: ptr[PyObject],
    old_args: ptr[PyObject],
    old_kw: ptr[PyObject],
    placeholder: ptr[PyObject]
) -> i64 {
    merged: ptr[PyObject] = NULL;
    kw: ptr[PyObject] = NULL;
    pair: ptr[PyObject] = NULL;
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
                pos = PyLong_AsLongLong(position);
                jacpy_release(position);
                value = required(jacpy_tuple_item(pair, 2));
                invalid = value == placeholder;
                jacpy_release(value);
                jacpy_release(pair);
                pair = NULL;
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
        kw = required(PyDict_Copy(old_kw) if old_kw != 0 else PyDict_New());
        if keywords != 0 {
            checked(PyDict_Update(kw, keywords));
        }
        state.function = Py_NewRef(function);
        state.placeholder = Py_NewRef(placeholder);
        state.args = merged;
        merged = NULL;
        state.keywords = kw;
        kw = NULL;
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(merged);
        jacpy_release(kw);
        jacpy_release(pair);
    }
}

def:pub jacpy_partial_call(
    state: partial_state, args: ptr[PyObject], keywords: ptr[PyObject]
) -> ptr[PyObject] {
    fn = Py_NewRef(state.function);
    saved_args = Py_NewRef(state.args);
    saved_kw = Py_NewRef(state.keywords);
    merged: ptr[PyObject] = NULL;
    kw: ptr[PyObject] = NULL;
    try {
        merged = required(merge_args(saved_args, args, state.placeholder, True));
        kw = required(PyDict_Copy(saved_kw));
        if keywords != 0 {
            checked(PyDict_Update(kw, keywords));
        }
        return PyObject_Call(fn, merged, kw);
    } except boundary_failure {
        return NULL;
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
def:pub jacpy_partial_restore(
    state: partial_state, saved: ptr[PyObject]
) -> ptr[PyObject] {
    fn: ptr[PyObject] = NULL;
    args: ptr[PyObject] = NULL;
    kw: ptr[PyObject] = NULL;
    dictionary: ptr[PyObject] = NULL;
    try {
        if jacpy_is_tuple(saved) == 0 or PyTuple_Size(saved) != 4 {
            object_error("TypeError", "invalid partial state");
            raise boundary_failure();
        }
        fn = required(jacpy_tuple_item(saved, 0));
        args = required(jacpy_tuple_item(saved, 1));
        kw = required(jacpy_tuple_item(saved, 2));
        dictionary = required(jacpy_tuple_item(saved, 3));
        if PyCallable_Check(fn) == 0
            or jacpy_is_tuple(args) == 0
            or (jacpy_is_none(kw) == 0 and jacpy_is_dict(kw) == 0)
            or (jacpy_is_none(dictionary) == 0 and jacpy_is_dict(dictionary) == 0) {
            object_error("TypeError", "invalid partial state");
            raise boundary_failure();
        }
        validate_tail(args, state.placeholder);
        if jacpy_is_exact_tuple(args) == 0 {
            normalized = required(PySequence_Tuple(args));
            jacpy_release(args);
            args = normalized;
        }
        if jacpy_is_none(kw) != 0 {
            normalized_kw = required(PyDict_New());
            jacpy_release(kw);
            kw = normalized_kw;
        } elif jacpy_is_exact_dict(kw) == 0 {
            normalized_kw = required(PyDict_Copy(kw));
            jacpy_release(kw);
            kw = normalized_kw;
        }
        old_fn = state.function;
        old_args = state.args;
        old_kw = state.keywords;
        state.function = fn;
        fn = NULL;
        state.args = args;
        args = NULL;
        state.keywords = kw;
        kw = NULL;
        jacpy_release(old_fn);
        jacpy_release(old_args);
        jacpy_release(old_kw);
        result = dictionary;
        dictionary = NULL;
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(fn);
        jacpy_release(args);
        jacpy_release(kw);
        jacpy_release(dictionary);
    }
}

def:pub jacpy_partial_repr(
    state: partial_state, owner: ptr[PyObject]
) -> ptr[PyObject] {
    entered = Py_ReprEnter(owner);
    if entered < 0 {
        return NULL;
    }
    if entered > 0 {
        return text_object("...");
    }
    fn = Py_NewRef(state.function);
    args = Py_NewRef(state.args);
    kw = Py_NewRef(state.keywords);
    pair: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    key: ptr[PyObject] = NULL;
    text: ptr[PyObject] = NULL;
    try {
        arguments = "";
        for i in range(int(PyTuple_Size(args))) {
            item = required(jacpy_tuple_item(args, i64(i)));
            arguments += ", " + repr_value(item);
            jacpy_release(item);
            item = NULL;
        }
        pos: i64 = 0;
        while True {
            pair = jacpy_dict_entry(kw, pos);
            if pair == 0 {
                break;
            }
            item = required(jacpy_tuple_item(pair, 0));
            pos = PyLong_AsLongLong(item);
            jacpy_release(item);
            item = NULL;
            key = required(jacpy_tuple_item(pair, 1));
            item = required(jacpy_tuple_item(pair, 2));
            text = required(PyObject_Str(key));
            arguments += ", " + text_value(text) + "=" + repr_value(item);
            jacpy_release(item);
            item = NULL;
            jacpy_release(key);
            key = NULL;
            jacpy_release(text);
            text = NULL;
            jacpy_release(pair);
            pair = NULL;
        }
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        return text_object(
            type_name(owner, True) + "(" + repr_value(fn) + arguments + ")"
        );
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(fn);
        jacpy_release(args);
        jacpy_release(kw);
        jacpy_release(pair);
        jacpy_release(item);
        jacpy_release(key);
        jacpy_release(text);
        Py_ReprLeave(owner);
    }
}

obj lru_state {
    has key_factory: Callable[[ptr[PyObject], ptr[PyObject], i64], ptr[PyObject]],
        function: ptr[PyObject] = NULL,
        cache: ptr[PyObject] = NULL,
        marker: ptr[PyObject] = NULL,
        info_type: ptr[PyObject] = NULL,
        key_type: ptr[PyObject] = NULL,
        move: ptr[PyObject] = NULL,
        pop: ptr[PyObject] = NULL,
        maximum: i64 = 0,
        typed: bool = False,
        hits: i64 = 0,
        misses: i64 = 0;
}

def:pub jacpy_lru_field(state: lru_state, field: i64) -> ptr[PyObject] {
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
    state.function = NULL;
    state.cache = NULL;
    state.marker = NULL;
    state.info_type = NULL;
    state.key_type = NULL;
    state.move = NULL;
    state.pop = NULL;
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
    function: ptr[PyObject],
    maximum: i64,
    typed: i64,
    info_type: ptr[PyObject],
    key_type: ptr[PyObject],
    marker: ptr[PyObject]
) -> i64 {
    state.function = Py_NewRef(function);
    state.marker = Py_NewRef(marker);
    state.info_type = Py_NewRef(info_type);
    state.key_type = Py_NewRef(key_type);
    state.maximum = maximum;
    state.typed = typed != 0;
    try {
        state.cache = required(
            jacpy_ordered_dict_new() if maximum > 0 else PyDict_New()
        );
        if maximum > 0 {
            state.move = required(PyObject_GetAttrString(state.cache, "move_to_end"));
            state.pop = required(PyObject_GetAttrString(state.cache, "popitem"));
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:priv cache_key(
    state: lru_state, args: ptr[PyObject], keywords: ptr[PyObject]
) -> ptr[PyObject] {
    n = PyTuple_Size(args);
    nk = jacpy_dict_size(keywords) if keywords != 0 else i64(0);
    if not state.typed and nk == 0 {
        if n == 1 {
            item = required(jacpy_tuple_item(args, 0));
            if jacpy_is_exact_long(item) != 0 or jacpy_is_exact_unicode(item) != 0 {
                return item;
            }
            jacpy_release(item);
        }
        return Py_NewRef(args);
    }
    count = n
        + (2 * nk + 1 if nk > 0 else i64(0))
        + (n + nk if state.typed else i64(0));
    key = required(PyTuple_New(count));
    pair: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
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
            checked(jacpy_tuple_set_owned(key, position, Py_NewRef(state.marker)));
            position += 1;
            pos: i64 = 0;
            while True {
                pair = jacpy_dict_entry(keywords, pos);
                if pair == 0 {
                    break;
                }
                item = required(jacpy_tuple_item(pair, 0));
                pos = PyLong_AsLongLong(item);
                jacpy_release(item);
                item = NULL;
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
                pair = NULL;
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
                item = NULL;
            }
            pos = i64(0);
            while nk > 0 {
                pair = jacpy_dict_entry(keywords, pos);
                if pair == 0 {
                    break;
                }
                item = required(jacpy_tuple_item(pair, 0));
                pos = PyLong_AsLongLong(item);
                jacpy_release(item);
                item = required(jacpy_tuple_item(pair, 2));
                checked(
                    jacpy_tuple_set_owned(
                        key, position, required(jacpy_object_type(item))
                    )
                );
                position += 1;
                jacpy_release(item);
                item = NULL;
                jacpy_release(pair);
                pair = NULL;
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

def:pub jacpy_lru_call(
    state: lru_state, args: ptr[PyObject], keywords: ptr[PyObject]
) -> ptr[PyObject] {
    if state.maximum == 0 {
        state.misses += 1;
        return PyObject_Call(state.function, args, keywords);
    }
    key: ptr[PyObject] = NULL;
    wrapped: ptr[PyObject] = NULL;
    record: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    canonical: ptr[PyObject] = NULL;
    moved: ptr[PyObject] = NULL;
    evicted: ptr[PyObject] = NULL;
    first: ptr[PyObject] = NULL;
    try {
        key = required(cache_key(state, args, keywords));
        hash = PyObject_Hash(key);
        if hash == -1 and jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        wrapped = required(state.key_factory(state.key_type, key, hash));
        record = jacpy_dict_get(state.cache, wrapped);
        if record != 0 {
            if state.maximum > 0 {
                canonical = required(jacpy_tuple_item(record, 0));
                value = required(jacpy_tuple_item(record, 1));
                moved = required(PyObject_CallOneArg(state.move, canonical));
            } else {
                value = Py_NewRef(record);
            }
            state.hits += 1;
            result = value;
            value = NULL;
            return result;
        }
        if jacpy_error_pending() != 0 {
            raise boundary_failure();
        }
        state.misses += 1;
        value = required(PyObject_Call(state.function, args, keywords));
        if state.maximum < 0 {
            checked(PyDict_SetItem(state.cache, wrapped, value));
        } else {
            record = jacpy_dict_get(state.cache, wrapped);
            if record == 0 {
                if jacpy_error_pending() != 0 {
                    raise boundary_failure();
                }
                if jacpy_dict_size(state.cache) >= state.maximum {
                    first = required(PyBool_FromLong(0));
                    evicted = required(PyObject_CallOneArg(state.pop, first));
                }
                record = required(PyTuple_New(2));
                checked(jacpy_tuple_set_owned(record, 0, Py_NewRef(wrapped)));
                checked(jacpy_tuple_set_owned(record, 1, Py_NewRef(value)));
                # PyDict_SetItem bypasses OrderedDict's ordering slots.
                checked(PyObject_SetItem(state.cache, wrapped, record));
            }
        }
        result = value;
        value = NULL;
        return result;
    } except boundary_failure {
        return NULL;
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
        method: ptr[PyObject] = NULL;
        args: ptr[PyObject] = NULL;
        result: ptr[PyObject] = NULL;
        try {
            method = required(PyObject_GetAttrString(state.cache, "clear"));
            args = required(PyTuple_New(0));
            result = required(PyObject_Call(method, args, NULL));
            return 0;
        } except boundary_failure {
            return -1;
        } finally {
            jacpy_release(method);
            jacpy_release(args);
            jacpy_release(result);
        }
    }
    PyDict_Clear(state.cache);
    return 0;
}

def:pub jacpy_lru_info(state: lru_state) -> ptr[PyObject] {
    args: ptr[PyObject] = NULL;
    try {
        args = required(PyTuple_New(4));
        checked(
            jacpy_tuple_set_owned(args, 0, required(PyLong_FromLongLong(state.hits)))
        );
        checked(
            jacpy_tuple_set_owned(args, 1, required(PyLong_FromLongLong(state.misses)))
        );
        checked(
            jacpy_tuple_set_owned(
                args,
                2,
                required(
                    jacpy_none()
                        if state.maximum < 0
                        else PyLong_FromLongLong(state.maximum)
                )
            )
        );
        checked(
            jacpy_tuple_set_owned(
                args, 3, required(PyLong_FromLongLong(jacpy_dict_size(state.cache)))
            )
        );
        return PyObject_Call(state.info_type, args, NULL);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(args);
    }
}
