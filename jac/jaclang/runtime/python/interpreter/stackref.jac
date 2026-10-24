import from c { def _PyLong_ExactDealloc(op: ptr[PyObject]);  }

glob SR_NULL: Final[u64] = u64(1),
     SR_TAG_REFCNT: Final[u64] = u64(1),
     SR_TAG_BITS: Final[u64] = u64(3),
     SR_INT_TAG: Final[u64] = u64(3),
     SR_PTR_MASK: Final[u64] = u64(0xFFFFFFFFFFFFFFFE);

def sr_borrow(ref: u64) -> ptr[PyObject];

def sr_is_null(ref: u64) -> bool;

def sr_refcount_on_object(ref: u64) -> bool;

def sr_incref_mortal(op: ptr[PyObject]);

def sr_decref_mortal(op: ptr[PyObject]);

def sr_dup(ref: u64) -> u64;

def sr_close(ref: u64);

def sr_xclose(ref: u64);

def sr_close_long(ref: u64);

def sr_borrow_ref(ref: u64) -> u64;

def sr_from_borrow(op: ptr[PyObject]) -> u64;

def sr_immortal(op: ptr[PyObject]) -> u64;

def sr_steal(op: ptr[PyObject]) -> u64;

def sr_steal_mortal(op: ptr[PyObject]) -> u64;

def sr_new(op: ptr[PyObject]) -> u64;

def sr_new_mortal(op: ptr[PyObject]) -> u64;

def sr_as_steal(ref: u64) -> ptr[PyObject];

def sr_true -> u64;

def sr_false -> u64;

def sr_none -> u64;

def sr_is_true(ref: u64) -> bool;

def sr_is_false(ref: u64) -> bool;

def sr_is_none(ref: u64) -> bool;

def sr_is(a: u64, b: u64) -> bool;

def sr_is_tagged_int(ref: u64) -> bool;

def sr_tag_int(value: i64) -> u64;

def sr_untag_int(ref: u64) -> i64;

def sr_is_heap_safe(ref: u64) -> bool;

def sr_make_heap_safe(ref: u64) -> u64;

def sr_type(ref: u64) -> ptr[PyTypeObject];

impl sr_borrow(ref: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(ref & SR_PTR_MASK));
}

impl sr_is_null(ref: u64) -> bool {
    return ref == SR_NULL;
}

impl sr_refcount_on_object(ref: u64) -> bool {
    return (ref & SR_TAG_REFCNT) == u64(0);
}

impl sr_incref_mortal(op: ptr[PyObject]) {
    header = ptr[_object](op);
    header.view(1)[0].ob_refcnt_full = header.view(1)[0].ob_refcnt_full + 1;
}

impl sr_decref_mortal(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full - 1;
    header.view(1)[0].ob_refcnt_full = full;
    if (full & 0xFFFFFFFF) == 0 {
        _Py_Dealloc(op);
    }
}

impl sr_dup(ref: u64) -> u64 {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        sr_incref_mortal(ptr[PyObject](i64.wrap(ref)));
    }
    return ref;
}

impl sr_close(ref: u64) {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        sr_decref_mortal(ptr[PyObject](i64.wrap(ref)));
    }
}

impl sr_xclose(ref: u64) {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        sr_decref_mortal(ptr[PyObject](i64.wrap(ref)));
    }
}

impl sr_close_long(ref: u64) {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        op = ptr[PyObject](i64.wrap(ref));
        header = ptr[_object](op);
        full = header.view(1)[0].ob_refcnt_full - 1;
        header.view(1)[0].ob_refcnt_full = full;
        if (full & 0xFFFFFFFF) == 0 {
            reftracer_track(op, 1);
            _PyLong_ExactDealloc(op);
        }
    }
}

impl sr_borrow_ref(ref: u64) -> u64 {
    return ref | SR_TAG_REFCNT;
}

impl sr_from_borrow(op: ptr[PyObject]) -> u64 {
    return u64(int(op)) | SR_TAG_REFCNT;
}

impl sr_immortal(op: ptr[PyObject]) -> u64 {
    return u64(int(op)) | SR_TAG_REFCNT;
}

impl sr_steal(op: ptr[PyObject]) -> u64 {
    full = ptr[_object](op).view(1)[0].ob_refcnt_full;
    return u64(int(op)) | (u64(full >> 48) & SR_TAG_REFCNT);
}

impl sr_steal_mortal(op: ptr[PyObject]) -> u64 {
    return u64(int(op));
}

impl sr_new(op: ptr[PyObject]) -> u64 {
    full = ptr[_object](op).view(1)[0].ob_refcnt_full;
    if (full & 0x80000000) != 0 {
        return u64(int(op)) | SR_TAG_REFCNT;
    }
    ptr[_object](op).view(1)[0].ob_refcnt_full = full + 1;
    return u64(int(op));
}

impl sr_new_mortal(op: ptr[PyObject]) -> u64 {
    sr_incref_mortal(op);
    return u64(int(op));
}

impl sr_as_steal(ref: u64) -> ptr[PyObject] {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        return ptr[PyObject](i64.wrap(ref));
    }
    return object_new_ref(ptr[PyObject](i64.wrap(ref & SR_PTR_MASK)));
}

impl sr_true -> u64 {
    return u64(int(addressof(_Py_TrueStruct))) | SR_TAG_REFCNT;
}

impl sr_false -> u64 {
    return u64(int(addressof(_Py_FalseStruct))) | SR_TAG_REFCNT;
}

impl sr_none -> u64 {
    return u64(int(addressof(_Py_NoneStruct))) | SR_TAG_REFCNT;
}

impl sr_is_true(ref: u64) -> bool {
    return ref == (u64(int(addressof(_Py_TrueStruct))) | SR_TAG_REFCNT);
}

impl sr_is_false(ref: u64) -> bool {
    return ref == (u64(int(addressof(_Py_FalseStruct))) | SR_TAG_REFCNT);
}

impl sr_is_none(ref: u64) -> bool {
    return ref == (u64(int(addressof(_Py_NoneStruct))) | SR_TAG_REFCNT);
}

impl sr_is(a: u64, b: u64) -> bool {
    return (a & SR_PTR_MASK) == (b & SR_PTR_MASK);
}

impl sr_is_tagged_int(ref: u64) -> bool {
    return (ref & SR_INT_TAG) == SR_INT_TAG;
}

impl sr_tag_int(value: i64) -> u64 {
    return ((u64.wrap(value) & u64(0x3FFFFFFFFFFFFFFF)) << u64(2)) | SR_INT_TAG;
}

impl sr_untag_int(ref: u64) -> i64 {
    return i64.wrap(ref) >> 2;
}

impl sr_is_heap_safe(ref: u64) -> bool {
    if (ref & SR_TAG_BITS) != SR_TAG_REFCNT or ref == SR_NULL {
        return True;
    }
    full = ptr[_object](sr_borrow(ref)).view(1)[0].ob_refcnt_full;
    return (full & 0x80000000) != 0;
}

impl sr_make_heap_safe(ref: u64) -> u64 {
    if sr_is_heap_safe(ref) {
        return ref;
    }
    op = sr_borrow(ref);
    object_incref(op);
    return u64(int(op));
}

impl sr_type(ref: u64) -> ptr[PyTypeObject] {
    return ptr[_object](sr_borrow(ref)).view(1)[0].ob_type;
}
