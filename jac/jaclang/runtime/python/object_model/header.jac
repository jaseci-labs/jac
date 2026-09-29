"""The object header operations of Include/object.h, inline in Jac.

CPython defines Py_TYPE, Py_IS_TYPE, Py_SIZE and PyType_HasFeature as static
inline functions; object ports read the header through the layouts instead of
calling the exported compatibility functions. The tuple item macros of
Include/cpython/tupleobject.h, Py_REFCNT and Py_RETURN_RICHCOMPARE are here
too. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyObject,
    PyType_IsSubtype,
    PyUnicode_InternFromString,
    Py_NewRef,
    Py_NotImplemented,
    _PyEval_GetBuiltin,
    _Py_Dealloc,
    PyThreadState_GetUnchecked,
    _Py_NewReference,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    _Py_freelist,
    PyGC_Head_SIZE,
    PyInterpreterState_FREELISTS,
    PyInterpreterState_GC,
    PyThreadState_INTERP,
    _PyGC_PREV_FLAGS,
    _PyGC_PREV_MASK,
    _PyGC_PREV_MASK_FINALIZED,
    _gc_runtime_state_GENERATION0,
    _gc_runtime_state_HEAP_SIZE,
    PyListObject,
    PyTupleObject,
    PyTupleObject_ITEMS,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_GE,
    Py_GT,
    Py_LE,
    Py_LT,
    Py_NE,
    Py_TPFLAGS_LIST_SUBCLASS,
    _Py_IMMORTAL_INITIAL_REFCNT,
    _object
}

import from c {
    glob PyType_Type: PyTypeObject,
         # Defined by bool.jac; Py_True and Py_False are their addresses.
         _Py_TrueStruct: PyObject,
         _Py_FalseStruct: PyObject;
}

"""Py_INCREF: count a new reference to `op` unless it is immortal (the
release build's 32-bit count at or above _Py_IMMORTAL_INITIAL_REFCNT)."""
def object_incref(op: ptr[PyObject]) {
    header = ptr[_object](op);
    full = header.view(1)[0].ob_refcnt_full;
    if (full & 0xFFFFFFFF) >= _Py_IMMORTAL_INITIAL_REFCNT {
        return;
    }
    header.view(1)[0].ob_refcnt_full = full + 1;
}

"""Py_NewRef: `op` with a new reference counted."""
def object_new_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    object_incref(op);
    return op;
}

"""Py_DECREF: drop a reference to `op`, deallocating it at zero; an immortal
object (a negative 32-bit count) is left alone."""
def object_decref(op: ptr[PyObject]) {
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

"""Py_XDECREF."""
def object_xdecref(op: ptr[PyObject]) {
    if op {
        object_decref(op);
    }
}

"""Py_TYPE: the type of `op` (borrowed)."""
def object_type(op: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[_object](op).view(1)[0].ob_type;
}

"""Py_IS_TYPE."""
def object_is_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_type(op) == type;
}

"""PyObject_TypeCheck: `op` is an instance of `type` or of a subtype."""
def object_type_check(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_is_type(op, type)
        or PyType_IsSubtype(ptr[PyObject](object_type(op)), ptr[PyObject](type)) != 0;
}

"""Py_SIZE: the item count of a variable-size object."""
def object_size(op: ptr[PyObject]) -> i64 {
    return ptr[PyVarObject](op).view(1)[0].ob_size;
}

"""Py_REFCNT: the release build's 32-bit reference count, the low part of
`ob_refcnt_full`."""
def object_refcount(op: ptr[PyObject]) -> i64 {
    return ptr[_object](op).view(1)[0].ob_refcnt_full & i64(4294967295);
}

"""PyType_HasFeature."""
def type_has_feature(type: ptr[PyTypeObject], feature: u64) -> bool {
    return (type.view(1)[0].tp_flags & feature) != u64(0);
}

"""_PyTuple_ITEMS: the address of a tuple's first item."""
def tuple_items(tuple: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tuple) + PyTupleObject_ITEMS);
}

"""PySequence_Fast_ITEMS: the item array of PySequence_Fast's list or tuple."""
def fast_items(fast: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    if (object_type(fast).view(1)[0].tp_flags & Py_TPFLAGS_LIST_SUBCLASS) != u64(0) {
        return ptr[PyListObject](fast).view(1)[0].ob_item;
    }
    return tuple_items(fast);
}

"""PyTuple_GET_ITEM (borrowed)."""
def tuple_get_item(tuple: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return (tuple_items(tuple) + index).view(1)[0];
}

"""PyTuple_SET_ITEM: stores `item` (stealing it) without releasing the old item."""
def tuple_set_item(tuple: ptr[PyObject], index: i64, item: ptr[PyObject]) {
    (tuple_items(tuple) + index).view(1)[0] = item;
}

"""_PyTuple_Recycle: a tuple reused in place gets its hash cache reset and is
tracked by the GC again (bpo-42536: the GC may have untracked it)."""
def tuple_recycle(tuple: ptr[PyObject]) {
    ptr[PyTupleObject](tuple).view(1)[0].ob_hash = -1;
    if not object_gc_is_tracked(tuple) {
        object_gc_track(tuple);
    }
}

"""Py_RETURN_RICHCOMPARE: the bool of comparing `left` and `right` by `op`
(NotImplemented for an unknown operator, which C leaves unreachable)."""
def rich_compare_values(left: i64, right: i64, op: i32) -> ptr[PyObject] {
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

"""_PyEval_GetBuiltin(&_Py_ID(name)): the builtin `name` as a new reference,
AttributeError when it is missing. The _Py_ID strings live in _PyRuntime at
build-dependent offsets; interning returns them."""
def eval_builtin(name: str) -> ptr[PyObject] {
    key = PyUnicode_InternFromString(name);
    if not key {
        return NULL;
    }
    result = _PyEval_GetBuiltin(key);
    jacpy_release(key);
    return result;
}

"""_PyInterpreterState_GET: the current thread's interpreter, read from its
thread state as the release build does."""
def current_interp -> ptr[u8] {
    tstate = ptr[u8](PyThreadState_GetUnchecked());
    return ptr[ptr[u8]](tstate + PyThreadState_INTERP).view(1)[0];
}

"""The freelist at `offset` in `interp`'s struct _Py_freelists (one of the
layouts.jac `_Py_freelists_*` offsets)."""
def freelist_in(interp: ptr[u8], offset: i64) -> ptr[_Py_freelist] {
    return ptr[_Py_freelist](interp + PyInterpreterState_FREELISTS + offset);
}

"""_Py_freelists_GET()->NAME for the freelist at `offset`."""
def freelist(offset: i64) -> ptr[_Py_freelist] {
    return freelist_in(current_interp(), offset);
}

"""_Py_FREELIST_POP: a freed object of the freelist at `offset`, its
reference count reset to 1, or NULL when the list is empty. The list links
objects through their first word."""
def freelist_pop(offset: i64) -> ptr[PyObject] {
    return freelist_pop_in(current_interp(), offset);
}

"""freelist_pop with the interpreter the caller already has."""
def freelist_pop_in(interp: ptr[u8], offset: i64) -> ptr[PyObject] {
    fl = freelist_in(interp, offset);
    op = ptr[PyObject](fl.view(1)[0].freelist);
    if op {
        fl.view(1)[0].freelist = ptr[ptr](op).view(1)[0];
        fl.view(1)[0].size -= 1;
        _Py_NewReference(op);
    }
    return op;
}

"""_PyFreeList_Push: keep `op` on the freelist at `offset` unless it holds
`maxsize` objects already (or is disabled); True when kept."""
def freelist_push(offset: i64, op: ptr[PyObject], maxsize: i64) -> bool {
    return freelist_push_in(current_interp(), offset, op, maxsize);
}

"""freelist_push with the interpreter the caller already has."""
def freelist_push_in(
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

"""_Py_AS_GC: the address of the GC header in front of a GC object, whose
two words are `_gc_next` and `_gc_prev` (the PyGC_Head layout)."""
def gc_head(op: ptr[PyObject]) -> int {
    return int(op) - PyGC_Head_SIZE;
}

"""_PyObject_GC_IS_TRACKED."""
def object_gc_is_tracked(op: ptr[PyObject]) -> bool {
    return ptr[i64](gc_head(op)).view(1)[0] != 0;
}

"""_PyObject_GC_TRACK in `interp`: link `op` (untracked) at the end of
generation 0 and count it in the heap size."""
def gc_track_in(interp: ptr[u8], op: ptr[PyObject]) {
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

"""_PyObject_GC_UNTRACK in `interp`: unlink `op` (tracked), keeping only its
finalized flag, and uncount it."""
def gc_untrack_in(interp: ptr[u8], op: ptr[PyObject]) {
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

"""PyObject_GC_Track, inline."""
def object_gc_track(op: ptr[PyObject]) {
    gc_track_in(current_interp(), op);
}

"""PyObject_GC_UnTrack, inline: untrack `op` if it is tracked."""
def object_gc_untrack(op: ptr[PyObject]) {
    if object_gc_is_tracked(op) {
        gc_untrack_in(current_interp(), op);
    }
}
