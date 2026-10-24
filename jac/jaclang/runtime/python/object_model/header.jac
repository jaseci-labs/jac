import from c {
    glob PyType_Type: PyTypeObject,
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject;
}

def object_incref(op: ptr[PyObject]);

def object_new_ref(op: ptr[PyObject]) -> ptr[PyObject];

def object_decref(op: ptr[PyObject]);

glob:priv IMMORTAL_MINIMUM_REFCNT: i64 = 0x80000000;

def refcnt_add(op: ptr[PyObject], n: i64);

def object_xdecref(op: ptr[PyObject]);

def object_type(op: ptr[PyObject]) -> ptr[PyTypeObject];

def object_is_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool;

def object_type_check(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool;

def object_size(op: ptr[PyObject]) -> i64;

def object_refcount(op: ptr[PyObject]) -> i64;

def type_has_feature(type: ptr[PyTypeObject], feature: u64) -> bool;

def tuple_items(tuple: ptr[PyObject]) -> ptr[ptr[PyObject]];

def fast_items(fast: ptr[PyObject]) -> ptr[ptr[PyObject]];

def tuple_get_item(tuple: ptr[PyObject], index: i64) -> ptr[PyObject];

def tuple_set_item(tuple: ptr[PyObject], index: i64, item: ptr[PyObject]);

def tuple_recycle(tuple: ptr[PyObject]);

def rich_compare_values(left: i64, right: i64, op: i32) -> ptr[PyObject];

def eval_builtin(name: str) -> ptr[PyObject];

def current_tstate -> ptr[PyThreadState];

def current_interp -> ptr[u8];

def freelist_in(interp: ptr[u8], offset: i64) -> ptr[_Py_freelist];

def freelist(offset: i64) -> ptr[_Py_freelist];

def freelist_pop(offset: i64) -> ptr[PyObject];

def freelist_pop_in(interp: ptr[u8], offset: i64) -> ptr[PyObject];

def freelist_push(offset: i64, op: ptr[PyObject], maxsize: i64) -> bool;

def freelist_push_in(
    interp: ptr[u8], offset: i64, op: ptr[PyObject], maxsize: i64
) -> bool;

def gc_head(op: ptr[PyObject]) -> int;

def object_gc_is_tracked(op: ptr[PyObject]) -> bool;

def gc_track_in(interp: ptr[u8], op: ptr[PyObject]);

def gc_untrack_in(interp: ptr[u8], op: ptr[PyObject]);

def object_gc_track(op: ptr[PyObject]);

def object_gc_untrack(op: ptr[PyObject]);

impl object_incref(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0xFFFFFFFF) >= _Py_IMMORTAL_INITIAL_REFCNT {
        return;
    }
    header.view(1)[0].ob_refcnt_full = full + 1;
}

impl object_new_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    object_incref(op);
    return op;
}

impl object_decref(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0x80000000) != 0 {
        return;
    }
    full -= 1;
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        _Py_Dealloc(op);
    }
}

impl refcnt_add(op: ptr[PyObject], n: i64) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    count = full & 0xFFFFFFFF;
    if (count & 0x80000000) != 0 {
        return;
    }
    added = count + n;
    if added >= IMMORTAL_MINIMUM_REFCNT {
        added = _Py_IMMORTAL_INITIAL_REFCNT;
    }
    header.view(1)[0].ob_refcnt_full = (full - count) | (added & 0xFFFFFFFF);
}

impl object_xdecref(op: ptr[PyObject]) {
    if op {
        object_decref(op);
    }
}

impl object_type(op: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[_object](op).view(1)[0].ob_type;
}

impl object_is_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_type(op) == type;
}

impl object_type_check(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_is_type(op, type)
        or PyType_IsSubtype(ptr[PyObject](object_type(op)), ptr[PyObject](type)) != 0;
}

impl object_size(op: ptr[PyObject]) -> i64 {
    return ptr[PyVarObject](op).view(1)[0].ob_size;
}

impl object_refcount(op: ptr[PyObject]) -> i64 {
    return ptr[_object](op).view(1)[0].ob_refcnt_full & i64(4294967295);
}

impl type_has_feature(type: ptr[PyTypeObject], feature: u64) -> bool {
    return (type.view(1)[0].tp_flags & feature) != u64(0);
}

impl tuple_items(tuple: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tuple) + PyTupleObject_ITEMS);
}

impl fast_items(fast: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    if (object_type(fast).view(1)[0].tp_flags & Py_TPFLAGS_LIST_SUBCLASS) != u64(0) {
        return ptr[PyListObject](fast).view(1)[0].ob_item;
    }
    return tuple_items(fast);
}

impl tuple_get_item(tuple: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return (tuple_items(tuple) + index).view(1)[0];
}

impl tuple_set_item(tuple: ptr[PyObject], index: i64, item: ptr[PyObject]) {
    (tuple_items(tuple) + index).view(1)[0] = item;
}

impl tuple_recycle(tuple: ptr[PyObject]) {
    ptr[PyTupleObject](tuple).view(1)[0].ob_hash = -1;
    if not object_gc_is_tracked(tuple) {
        object_gc_track(tuple);
    }
}

impl rich_compare_values(left: i64, right: i64, op: i32) -> ptr[PyObject] {
    result = False;
    if op == Py_EQ {
        result = left == right;
    } elif op == Py_NE {
        result = left != right;
    } elif op == Py_LT {
        result = left < right;
    } elif op == Py_GT {
        result = left > right;
    } elif op == Py_LE {
        result = left <= right;
    } elif op == Py_GE {
        result = left >= right;
    } else {
        return Py_NewRef(Py_NotImplemented);
    }
    return addressof(_Py_TrueStruct) if result else addressof(_Py_FalseStruct);
}

impl eval_builtin(name: str) -> ptr[PyObject] {
    key = jacpy_unicode_intern_text(name);
    if not key {
        return NULL;
    }
    result = _PyEval_GetBuiltin(key);
    jacpy_release(key);
    return result;
}

impl current_tstate -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](__c_thread_local("_Py_tss_tstate")).view(1)[0];
}

impl current_interp -> ptr[u8] {
    tstate = ptr[u8](current_tstate());
    return ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
}

impl freelist_in(interp: ptr[u8], offset: i64) -> ptr[_Py_freelist] {
    return ptr[_Py_freelist](interp + PyInterpreterState_FREELISTS + offset);
}

impl freelist(offset: i64) -> ptr[_Py_freelist] {
    return freelist_in(current_interp(), offset);
}

impl freelist_pop(offset: i64) -> ptr[PyObject] {
    return freelist_pop_in(current_interp(), offset);
}

impl freelist_pop_in(interp: ptr[u8], offset: i64) -> ptr[PyObject] {
    fl = freelist_in(interp, offset);
    op = ptr[PyObject](fl.view(1)[0].freelist);
    if op {
        fl.view(1)[0].freelist = ptr[ptr](op).view(1)[0];
        fl.view(1)[0].size -= 1;
        _Py_NewReference(op);
    }
    return op;
}

impl freelist_push(offset: i64, op: ptr[PyObject], maxsize: i64) -> bool {
    return freelist_push_in(current_interp(), offset, op, maxsize);
}

impl freelist_push_in(
    interp: ptr[u8], offset: i64, op: ptr[PyObject], maxsize: i64
) -> bool {
    fl = freelist_in(interp, offset);
    size = fl.view(1)[0].size;
    if size < maxsize and size >= 0 {
        ptr[ptr](op).view(1)[0] = fl.view(1)[0].freelist;
        fl.view(1)[0].freelist = ptr(op);
        fl.view(1)[0].size = size + 1;
        return True;
    }
    return False;
}

impl gc_head(op: ptr[PyObject]) -> int {
    return int(op) - PyGC_Head_SIZE;
}

impl object_gc_is_tracked(op: ptr[PyObject]) -> bool {
    return ptr[i64](gc_head(op)).view(1)[0] != 0;
}

impl gc_track_in(interp: ptr[u8], op: ptr[PyObject]) {
    gc = gc_head(op);
    gcstate = interp + PyInterpreterState_GC;
    generation0 = ptr[i64](gcstate + _gc_runtime_state_GENERATION0).view(1)[0];
    head = ptr[i64](generation0).view(2);
    last = head[1];
    ptr[i64](last).view(1)[0] = gc;
    words = ptr[i64](gc).view(2);
    words[1] = (words[1] & _PyGC_PREV_FLAGS) | last;
    words[0] = generation0;
    head[1] = gc;
    heap_size = ptr[i64](gcstate + _gc_runtime_state_HEAP_SIZE).view(1);
    heap_size[0] = wrapping_add(heap_size[0], 1);
}

impl gc_untrack_in(interp: ptr[u8], op: ptr[PyObject]) {
    words = ptr[i64](gc_head(op)).view(2);
    prev = words[1] & _PyGC_PREV_MASK;
    next = words[0];
    ptr[i64](prev).view(1)[0] = next;
    next_words = ptr[i64](next).view(2);
    next_words[1] = (next_words[1] & _PyGC_PREV_FLAGS) | prev;
    words[0] = 0;
    words[1] = words[1] & _PyGC_PREV_MASK_FINALIZED;
    heap_size = ptr[i64](
        interp + PyInterpreterState_GC + _gc_runtime_state_HEAP_SIZE
    ).view(
        1
    );
    heap_size[0] = wrapping_sub(heap_size[0], 1);
}

impl object_gc_track(op: ptr[PyObject]) {
    gc_track_in(current_interp(), op);
}

impl object_gc_untrack(op: ptr[PyObject]) {
    if object_gc_is_tracked(op) {
        gc_untrack_in(current_interp(), op);
    }
}
