def:pub jacpy_reduce(
    function: ptr[PyObject], iterable: ptr[PyObject], initial: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_cmp_key(
    function: ptr[PyObject], left: ptr[PyObject], right: ptr[PyObject], operation: i64
) -> ptr[PyObject];

obj partial_state {
    has function: ptr[PyObject] = NULL,
        args: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL,
        placeholder: ptr[PyObject] = NULL;
}

def:pub jacpy_partial_new -> partial_state;

def:pub jacpy_partial_field(state: partial_state, field: i64) -> ptr[PyObject];

def:pub jacpy_partial_clear(state: partial_state);

def:priv merge_args(
    old: ptr[PyObject], args: ptr[PyObject], placeholder: ptr[PyObject], calling: bool
) -> ptr[PyObject];

def:priv validate_tail(args: ptr[PyObject], placeholder: ptr[PyObject]);

def:pub jacpy_partial_init(
    state: partial_state,
    function: ptr[PyObject],
    args: ptr[PyObject],
    keywords: ptr[PyObject],
    old_args: ptr[PyObject],
    old_kw: ptr[PyObject],
    placeholder: ptr[PyObject]
) -> i64;

def:pub jacpy_partial_call(
    state: partial_state, args: ptr[PyObject], keywords: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_partial_restore(
    state: partial_state, saved: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_partial_repr(
    state: partial_state, owner: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    obj lru_list_elem {
        has ob_base: _object,
            prev: ptr[lru_list_elem],
            next: ptr[lru_list_elem],
            hash: i64,
            key: ptr[PyObject],
            result: ptr[PyObject];
    }  obj lru_cache_object {
        has ob_base: _object,
            prev: ptr[lru_list_elem],
            next: ptr[lru_list_elem],
            hash: i64,
            key: ptr[PyObject],
            result: ptr[PyObject],
            wrapper:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
            typed: i32,
            cache: ptr[PyObject],
            hits: i64,
            func: ptr[PyObject],
            maxsize: i64,
            misses: i64,
            kwd_mark: ptr[PyObject],
            lru_list_elem_type: ptr[PyObject],
            cache_info_type: ptr[PyObject],
            dct: ptr[PyObject],
            weakreflist: ptr[PyObject];
    }  def _PyDict_GetItemRef_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], hash: i64, result: &mut ptr[PyObject]
    ) -> i32;  def _PyDict_SetItem_KnownHash(
        op: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject], hash: i64
    ) -> i32;  def _PyDict_Pop_KnownHash(
        mp: ptr[PyObject], key: ptr[PyObject], hash: i64, result: &mut ptr[PyObject]
    ) -> i32;
}

glob LRU_LIST_ELEM_SIZE: Final[i64] = 56,
     LRU_CACHE_OBJECT_SIZE: Final[i64] = 152,
     LRU_CACHE_OBJECT_DICT: Final[i64] = 136,
     LRU_CACHE_OBJECT_WEAKREFLIST: Final[i64] = 144;

def lru_list_elem_dealloc(op: ptr[PyObject]);

def:priv lru_cache_make_key(
    kwd_mark: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], typed: i32
) -> ptr[PyObject];

def uncached_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def infinite_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def:priv lru_cache_extract_link(link: ptr[lru_list_elem]);

def:priv lru_cache_append_link(op: ptr[PyObject], link: ptr[lru_list_elem]);

def:priv lru_cache_prepend_link(op: ptr[PyObject], link: ptr[lru_list_elem]);

def:priv bounded_lru_cache_get_lock_held(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject], i64);

def:priv bounded_lru_cache_update_lock_held(
    op: ptr[PyObject], result: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> ptr[PyObject];

def bounded_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def lru_cache_new(
    type: ptr[PyObject],
    func: ptr[PyObject],
    maxsize_O: ptr[PyObject],
    typed: i32,
    cache_info_type: ptr[PyObject],
    kwd_mark: ptr[PyObject],
    lru_list_elem_type: ptr[PyObject]
) -> ptr[PyObject];

def:priv lru_cache_unlink_list(op: ptr[PyObject]) -> ptr[lru_list_elem];

def:priv lru_cache_clear_list(link: ptr[lru_list_elem]);

def lru_cache_tp_clear(op: ptr[PyObject]) -> i32;

def lru_cache_dealloc(op: ptr[PyObject]);

def:pub jacpy_lru_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def lru_cache_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def lru_cache_reduce(self_: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def lru_cache_copy(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def lru_cache_deepcopy(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def lru_cache_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

import from c {
    glob:priv lru_list_elem_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(lru_list_elem_dealloc)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob lru_list_elem_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("functools._lru_list_elem"),
             basicsize=i32(LRU_LIST_ELEM_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(lru_list_elem_type_slots)
         ); glob:priv lru_cache_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__dict__"),
                 get=PyObject_GenericGetDict,
                 set=PyObject_GenericSetDict
             ),
             PyGetSetDef()
         ],
         lru_cache_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=LRU_CACHE_OBJECT_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=LRU_CACHE_OBJECT_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         lru_cache_type_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(lru_cache_dealloc)),
             PyType_Slot(slot=Py_tp_call, pfunc=ptr(jacpy_lru_call)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(lru_cache_tp_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(lru_cache_tp_clear)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(lru_cache_memberlist))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(lru_cache_getsetlist))),
             PyType_Slot(slot=Py_tp_descr_get, pfunc=ptr(lru_cache_descr_get)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob lru_cache_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("functools._lru_cache_wrapper"),
             basicsize=i32(LRU_CACHE_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_METHOD_DESCRIPTOR
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(lru_cache_type_slots)
         );
}

def lru_cache_install_slots(doc: ptr[u8], methods: ptr[PyMethodDef], new: ptr);

def lru_cache_slots_ready -> bool;

glob KeyWrapper_token = ClassToken();

def _functools_reduce_impl(
    module: ptr[PyObject],
    function: ptr[PyObject],
    iterable: ptr[PyObject],
    initial: ptr[PyObject]
) -> ptr[PyObject];

def _functools_cmp_to_key_impl(
    module: ptr[PyObject], mycmp: ptr[PyObject]
) -> ptr[PyObject];

def _functools__lru_cache_wrapper_cache_info_impl(
    instance: ptr[PyObject]
) -> ptr[PyObject];

def _functools__lru_cache_wrapper_cache_clear_impl(
    instance: ptr[PyObject]
) -> ptr[PyObject];

impl jacpy_reduce(
    function: ptr[PyObject], iterable: ptr[PyObject], initial: ptr[PyObject]
) -> ptr[PyObject] {
    iterator = PyObject_GetIter(iterable);
    if iterator == 0 {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            object_error(PyExc_TypeError, "reduce() arg 2 must support iteration");
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
                    PyExc_TypeError, "reduce() of empty iterable with no initial value"
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

impl jacpy_cmp_key(
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

impl jacpy_partial_new -> partial_state {
    return partial_state();
}

impl jacpy_partial_field(state: partial_state, field: i64) -> ptr[PyObject] {
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

impl jacpy_partial_clear(state: partial_state) {
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

impl merge_args(
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
            PyExc_TypeError,
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

impl validate_tail(args: ptr[PyObject], placeholder: ptr[PyObject]) {
    size = PyTuple_Size(args);
    if size > 0 {
        last = required(jacpy_tuple_item(args, size - 1));
        invalid = last == placeholder;
        jacpy_release(last);
        if invalid {
            object_error(PyExc_TypeError, "trailing Placeholders are not allowed");
            raise boundary_failure();
        }
    }
}

impl jacpy_partial_init(
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
    try {
        validate_tail(args, placeholder);
        if keywords != 0 {
            pos: i64 = 0;
            key: ptr[PyObject] = NULL;
            value: ptr[PyObject] = NULL;
            while PyDict_Next(keywords, &mut pos, &mut key, &mut value) != 0 {
                if value == placeholder {
                    object_error(
                        PyExc_TypeError,
                        "Placeholder cannot be passed as a keyword argument"
                    );
                    raise boundary_failure();
                }
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
    }
}

impl jacpy_partial_call(
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

impl jacpy_partial_restore(
    state: partial_state, saved: ptr[PyObject]
) -> ptr[PyObject] {
    fn: ptr[PyObject] = NULL;
    args: ptr[PyObject] = NULL;
    kw: ptr[PyObject] = NULL;
    dictionary: ptr[PyObject] = NULL;
    try {
        if jacpy_is_tuple(saved) == 0 or PyTuple_Size(saved) != 4 {
            object_error(PyExc_TypeError, "invalid partial state");
            raise boundary_failure();
        }
        fn = required(jacpy_tuple_item(saved, 0));
        args = required(jacpy_tuple_item(saved, 1));
        kw = required(jacpy_tuple_item(saved, 2));
        dictionary = required(jacpy_tuple_item(saved, 3));
        if PyCallable_Check(fn) == 0
            or jacpy_is_tuple(args) == 0
            or (kw != Py_None and jacpy_is_dict(kw) == 0)
            or (dictionary != Py_None and jacpy_is_dict(dictionary) == 0) {
            object_error(PyExc_TypeError, "invalid partial state");
            raise boundary_failure();
        }
        validate_tail(args, state.placeholder);
        if jacpy_is_exact_tuple(args) == 0 {
            normalized = required(PySequence_Tuple(args));
            jacpy_release(args);
            args = normalized;
        }
        if kw == Py_None {
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

impl jacpy_partial_repr(state: partial_state, owner: ptr[PyObject]) -> ptr[PyObject] {
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
        entry_key: ptr[PyObject] = NULL;
        entry_value: ptr[PyObject] = NULL;
        while PyDict_Next(kw, &mut pos, &mut entry_key, &mut entry_value) != 0 {
            key = Py_NewRef(entry_key);
            item = Py_NewRef(entry_value);
            text = required(PyObject_Str(key));
            arguments += ", " + text_value(text) + "=" + repr_value(item);
            jacpy_release(item);
            item = NULL;
            jacpy_release(key);
            key = NULL;
            jacpy_release(text);
            text = NULL;
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
        jacpy_release(item);
        jacpy_release(key);
        jacpy_release(text);
        Py_ReprLeave(owner);
    }
}

impl _functools_reduce_impl(
    module: ptr[PyObject],
    function: ptr[PyObject],
    iterable: ptr[PyObject],
    initial: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_reduce(function, iterable, initial);
}

impl _functools_cmp_to_key_impl(
    module: ptr[PyObject], mycmp: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(jacpy_binding_state_get(module, 1));
    if instance == 0 {
        return NULL;
    }
    state = ReferenceState(references=[Py_NewRef(mycmp), NULL]);
    if jacpy_binding_native_set(instance, KeyWrapper_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}


impl lru_list_elem_dealloc(op: ptr[PyObject]) {
    link = ptr[lru_list_elem](op).view(1);
    tp = object_type(op);
    object_xdecref(link[0].key);
    object_xdecref(link[0].result);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl lru_cache_make_key(
    kwd_mark: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], typed: i32
) -> ptr[PyObject] {
    kwds_size: i64 = 0;
    if kwds {
        kwds_size = PyDict_Size(kwds);
    }

    if typed == 0 and kwds_size == 0 {
        if object_size(args) == 1 {
            key = tuple_get_item(args, 0);
            if unicode_check_exact(key) or long_check_exact(key) {
                return object_new_ref(key);
            }
        }
        return object_new_ref(args);
    }
    nargs = object_size(args);
    key_size = nargs;
    if kwds_size != 0 {
        key_size += kwds_size * 2 + 1;
    }
    if typed != 0 {
        key_size += nargs + kwds_size;
    }
    key = PyTuple_New(key_size);
    if not key {
        return NULL;
    }
    key_pos: i64 = 0;
    for index in range(nargs) {
        tuple_set_item(key, key_pos, object_new_ref(tuple_get_item(args, index)));
        key_pos += 1;
    }
    position: i64 = 0;
    keyword: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    if kwds_size != 0 {
        tuple_set_item(key, key_pos, object_new_ref(kwd_mark));
        key_pos += 1;
        while PyDict_Next(kwds, &mut position, &mut keyword, &mut value) != 0 {
            tuple_set_item(key, key_pos, object_new_ref(keyword));
            key_pos += 1;
            tuple_set_item(key, key_pos, object_new_ref(value));
            key_pos += 1;
        }
    }
    if typed != 0 {
        for index in range(nargs) {
            item = ptr[PyObject](object_type(tuple_get_item(args, index)));
            tuple_set_item(key, key_pos, object_new_ref(item));
            key_pos += 1;
        }
        if kwds_size != 0 {
            position = 0;
            while PyDict_Next(kwds, &mut position, &mut keyword, &mut value) != 0 {
                item = ptr[PyObject](object_type(value));
                tuple_set_item(key, key_pos, object_new_ref(item));
                key_pos += 1;
            }
        }
    }
    return key;
}

impl uncached_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[lru_cache_object](op).view(1);
    self_[0].misses = self_[0].misses + 1;
    return PyObject_Call(self_[0].func, args, kwds);
}

impl infinite_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[lru_cache_object](op).view(1);
    key = lru_cache_make_key(self_[0].kwd_mark, args, kwds, self_[0].typed);
    if not key {
        return NULL;
    }
    hash_ = PyObject_Hash(key);
    if hash_ == -1 {
        object_decref(key);
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    res = _PyDict_GetItemRef_KnownHash(self_[0].cache, key, hash_, &mut result);
    if res > 0 {
        self_[0].hits = self_[0].hits + 1;
        object_decref(key);
        return result;
    }
    if res < 0 {
        object_decref(key);
        return NULL;
    }
    self_[0].misses = self_[0].misses + 1;
    result = PyObject_Call(self_[0].func, args, kwds);
    if not result {
        object_decref(key);
        return NULL;
    }
    if _PyDict_SetItem_KnownHash(self_[0].cache, key, result, hash_) < 0 {
        object_decref(result);
        object_decref(key);
        return NULL;
    }
    object_decref(key);
    return result;
}

impl lru_cache_extract_link(link: ptr[lru_list_elem]) {
    link_prev = link.view(1)[0].prev;
    link_next = link.view(1)[0].next;
    link_prev.view(1)[0].next = link.view(1)[0].next;
    link_next.view(1)[0].prev = link.view(1)[0].prev;
}

impl lru_cache_append_link(op: ptr[PyObject], link: ptr[lru_list_elem]) {
    top = ptr[lru_list_elem](op);
    last = top.view(1)[0].prev;
    top.view(1)[0].prev = link;
    last.view(1)[0].next = link;
    link.view(1)[0].prev = last;
    link.view(1)[0].next = top;
}

impl lru_cache_prepend_link(op: ptr[PyObject], link: ptr[lru_list_elem]) {
    top = ptr[lru_list_elem](op);
    first = top.view(1)[0].next;
    top.view(1)[0].next = link;
    first.view(1)[0].prev = link;
    link.view(1)[0].prev = top;
    link.view(1)[0].next = first;
}

impl bounded_lru_cache_get_lock_held(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> (i32, ptr[PyObject], ptr[PyObject], i64) {
    self_ = ptr[lru_cache_object](op).view(1);
    key = lru_cache_make_key(self_[0].kwd_mark, args, kwds, self_[0].typed);
    if not key {
        return (i32(-1), NULL, NULL, i64(0));
    }
    hash_ = PyObject_Hash(key);
    if hash_ == -1 {
        object_decref(key);
        return (i32(-1), NULL, NULL, i64(0));
    }
    found: ptr[PyObject] = NULL;
    res = _PyDict_GetItemRef_KnownHash(self_[0].cache, key, hash_, &mut found);
    if res > 0 {
        link = ptr[lru_list_elem](found);
        lru_cache_extract_link(link);
        lru_cache_append_link(op, link);
        result = link.view(1)[0].result;
        self_[0].hits = self_[0].hits + 1;
        object_incref(result);
        object_decref(found);
        object_decref(key);
        return (i32(1), result, NULL, hash_);
    }
    if res < 0 {
        object_decref(key);
        return (i32(-1), NULL, NULL, i64(0));
    }
    self_[0].misses = self_[0].misses + 1;
    return (i32(0), NULL, key, hash_);
}

impl bounded_lru_cache_update_lock_held(
    op: ptr[PyObject], result: ptr[PyObject], key: ptr[PyObject], hash: i64
) -> ptr[PyObject] {
    self_ = ptr[lru_cache_object](op).view(1);
    if not result {
        object_decref(key);
        return NULL;
    }
    testresult: ptr[PyObject] = NULL;
    res = _PyDict_GetItemRef_KnownHash(self_[0].cache, key, hash, &mut testresult);
    if res > 0 {
        object_decref(testresult);
        object_decref(key);
        return result;
    }
    if res < 0 {
        object_decref(key);
        object_decref(result);
        return NULL;
    }

    top = ptr[lru_list_elem](op);
    if PyDict_Size(self_[0].cache) < self_[0].maxsize or self_[0].next == top {
        fresh = _PyObject_New(self_[0].lru_list_elem_type);
        if not fresh {
            object_decref(key);
            object_decref(result);
            return NULL;
        }
        link = ptr[lru_list_elem](fresh);
        link.view(1)[0].hash = hash;
        link.view(1)[0].key = key;
        link.view(1)[0].result = result;

        if _PyDict_SetItem_KnownHash(self_[0].cache, key, fresh, hash) < 0 {
            object_decref(fresh);
            return NULL;
        }
        lru_cache_append_link(op, link);
        return object_new_ref(result);
    }

    link = self_[0].next;
    lru_cache_extract_link(link);

    popresult: ptr[PyObject] = NULL;
    res = _PyDict_Pop_KnownHash(
        self_[0].cache, link.view(1)[0].key, link.view(1)[0].hash, &mut popresult
    );
    if res < 0 {
        lru_cache_prepend_link(op, link);
        object_decref(key);
        object_decref(result);
        return NULL;
    }
    if res == 0 {
        object_decref(ptr[PyObject](link));
        object_decref(key);
        return result;
    }

    oldkey = link.view(1)[0].key;
    oldresult = link.view(1)[0].result;

    link.view(1)[0].hash = hash;
    link.view(1)[0].key = key;
    link.view(1)[0].result = result;

    if _PyDict_SetItem_KnownHash(self_[0].cache, key, ptr[PyObject](link), hash) < 0 {
        object_decref(popresult);
        object_decref(ptr[PyObject](link));
        object_decref(oldkey);
        object_decref(oldresult);
        return NULL;
    }
    lru_cache_append_link(op, link);
    object_incref(result);
    object_decref(popresult);
    object_decref(oldkey);
    object_decref(oldresult);
    return result;
}

impl bounded_lru_cache_wrapper(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    (res, result, key, hash_) = bounded_lru_cache_get_lock_held(op, args, kwds);
    if res < 0 {
        return NULL;
    }
    if res > 0 {
        return result;
    }
    called = PyObject_Call(ptr[lru_cache_object](op).view(1)[0].func, args, kwds);

    return bounded_lru_cache_update_lock_held(op, called, key, hash_);
}

impl lru_cache_new(
    type: ptr[PyObject],
    func: ptr[PyObject],
    maxsize_O: ptr[PyObject],
    typed: i32,
    cache_info_type: ptr[PyObject],
    kwd_mark: ptr[PyObject],
    lru_list_elem_type: ptr[PyObject]
) -> ptr[PyObject] {
    if PyCallable_Check(func) == 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("the first argument must be callable")
        );
        return NULL;
    }

    maxsize: i64 = -1;
    kind = 0;
    if maxsize_O == Py_None {
        kind = 1;
    } elif PyIndex_Check(maxsize_O) != 0 {
        maxsize = PyNumber_AsSsize_t(maxsize_O, PyExc_OverflowError);
        if maxsize == -1 and PyErr_Occurred() {
            return NULL;
        }
        if maxsize < 0 {
            maxsize = 0;
        }
        kind = 0 if maxsize == 0 else 2;
    } else {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("maxsize should be integer or None"));
        return NULL;
    }
    cachedict = PyDict_New();
    if not cachedict {
        return NULL;
    }
    created = ptr[PyTypeObject](type).view(1)[0].tp_alloc(ptr[PyTypeObject](type), 0);
    if not created {
        object_decref(cachedict);
        return NULL;
    }
    obj_ = ptr[lru_cache_object](created).view(1);
    top = ptr[lru_list_elem](created);
    obj_[0].prev = top;
    obj_[0].next = top;
    if kind == 1 {
        obj_[0].wrapper = infinite_lru_cache_wrapper;
    } elif kind == 0 {
        obj_[0].wrapper = uncached_lru_cache_wrapper;
    } else {
        obj_[0].wrapper = bounded_lru_cache_wrapper;
    }
    obj_[0].typed = typed;
    obj_[0].cache = cachedict;
    obj_[0].func = object_new_ref(func);
    obj_[0].misses = 0;
    obj_[0].hits = 0;
    obj_[0].maxsize = maxsize;
    obj_[0].kwd_mark = object_new_ref(kwd_mark);
    obj_[0].lru_list_elem_type = object_new_ref(lru_list_elem_type);
    obj_[0].cache_info_type = object_new_ref(cache_info_type);
    obj_[0].dct = NULL;
    obj_[0].weakreflist = NULL;
    return created;
}

impl lru_cache_unlink_list(op: ptr[PyObject]) -> ptr[lru_list_elem] {
    top = ptr[lru_list_elem](op);
    link = top.view(1)[0].next;
    if link == top {
        return ptr[lru_list_elem]();
    }
    top.view(1)[0].prev.view(1)[0].next = ptr[lru_list_elem]();
    top.view(1)[0].next = top;
    top.view(1)[0].prev = top;
    return link;
}

impl lru_cache_clear_list(link: ptr[lru_list_elem]) {
    while link {
        next_link = link.view(1)[0].next;
        object_decref(ptr[PyObject](link));
        link = next_link;
    }
}

impl lru_cache_tp_clear(op: ptr[PyObject]) -> i32 {
    self_ = ptr[lru_cache_object](op).view(1);
    lst = lru_cache_unlink_list(op);
    cache = self_[0].cache;
    self_[0].cache = NULL;
    object_xdecref(cache);
    func = self_[0].func;
    self_[0].func = NULL;
    object_xdecref(func);
    kwd_mark = self_[0].kwd_mark;
    self_[0].kwd_mark = NULL;
    object_xdecref(kwd_mark);
    elem_type = self_[0].lru_list_elem_type;
    self_[0].lru_list_elem_type = NULL;
    object_xdecref(elem_type);
    info_type = self_[0].cache_info_type;
    self_[0].cache_info_type = NULL;
    object_xdecref(info_type);
    dct = self_[0].dct;
    self_[0].dct = NULL;
    object_xdecref(dct);
    lru_cache_clear_list(lst);
    return i32(0);
}

impl lru_cache_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);

    PyObject_GC_UnTrack(ptr(op));
    if ptr[lru_cache_object](op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    lru_cache_tp_clear(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl jacpy_lru_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return ptr[lru_cache_object](op).view(1)[0].wrapper(op, args, kwds);
}

impl lru_cache_descr_get(
    self_: ptr[PyObject], obj_: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    if obj_ == Py_None or not obj_ {
        return object_new_ref(self_);
    }
    return PyMethod_New(self_, obj_);
}

impl _functools__lru_cache_wrapper_cache_info_impl(
    instance: ptr[PyObject]
) -> ptr[PyObject] {
    lru = ptr[lru_cache_object](instance).view(1);
    hits: i64 = lru[0].hits;
    misses: i64 = lru[0].misses;
    size: i64 = PyDict_Size(lru[0].cache);
    if lru[0].maxsize == -1 {
        return PyObject_CallFunction(
            lru[0].cache_info_type, "nnOn", hits, misses, Py_None, size
        );
    }
    maxsize: i64 = lru[0].maxsize;
    return PyObject_CallFunction(
        lru[0].cache_info_type, "nnnn", hits, misses, maxsize, size
    );
}

impl _functools__lru_cache_wrapper_cache_clear_impl(
    instance: ptr[PyObject]
) -> ptr[PyObject] {
    lru = ptr[lru_cache_object](instance).view(1);
    lst = lru_cache_unlink_list(instance);
    lru[0].hits = 0;
    lru[0].misses = 0;
    PyDict_Clear(lru[0].cache);
    lru_cache_clear_list(lst);
    return object_new_ref(Py_None);
}

impl lru_cache_reduce(self_: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_GetAttrString(self_, ptr[u8]("__qualname__"));
}

impl lru_cache_copy(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(self_);
}

impl lru_cache_deepcopy(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(self_);
}

impl lru_cache_tp_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[lru_cache_object](op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    top = ptr[lru_list_elem](op);
    link = self_[0].next;
    while link != top {
        next_link = link.view(1)[0].next;
        status = visit_reference(link.view(1)[0].key, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(link.view(1)[0].result, visitor, arg);
        if status != 0 {
            return status;
        }
        status = visit_reference(
            ptr[PyObject](object_type(ptr[PyObject](link))), visitor, arg
        );
        if status != 0 {
            return status;
        }
        link = next_link;
    }
    status = visit_reference(self_[0].cache, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].func, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].kwd_mark, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].lru_list_elem_type, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].cache_info_type, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].dct, visitor, arg);
    if status != 0 {
        return status;
    }
    return i32(0);
}

impl lru_cache_slots_ready -> bool {
    slots = ptr[PyType_Slot](addressof(lru_cache_type_slots));
    return int((slots + 5).view(1)[0].pfunc) != 0;
}

impl lru_cache_install_slots(doc: ptr[u8], methods: ptr[PyMethodDef], new: ptr) {
    slots = ptr[PyType_Slot](addressof(lru_cache_type_slots));
    (slots + 2).view(1)[0].pfunc = ptr(doc);
    (slots + 9).view(1)[0].pfunc = new;
    (slots + 5).view(1)[0].pfunc = ptr(methods);
}
