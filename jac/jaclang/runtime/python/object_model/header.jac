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
    PyObject_GC_IsTracked,
    PyObject_GC_Track,
    PyType_IsSubtype,
    PyUnicode_InternFromString,
    Py_NewRef,
    Py_NotImplemented,
    _PyEval_GetBuiltin,
    _Py_Dealloc,
    _Py_NewReference,
    jacpy_freelists,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    _Py_freelist,
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
    if PyObject_GC_IsTracked(tuple) == 0 {
        PyObject_GC_Track(tuple);
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

"""The interpreter freelist at `offset` in struct _Py_freelists (one of the
layouts.jac `_Py_freelists_*` offsets)."""
def freelist(offset: i64) -> ptr[_Py_freelist] {
    return ptr[_Py_freelist](ptr[u8](jacpy_freelists()) + offset);
}

"""_Py_FREELIST_POP: a freed object of the freelist at `offset`, its
reference count reset to 1, or NULL when the list is empty. The list links
objects through their first word."""
def freelist_pop(offset: i64) -> ptr[PyObject] {
    fl = freelist(offset);
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
    fl = freelist(offset);
    size = fl.view(1)[0].size;
    if size < maxsize and size >= 0 {
        ptr[ptr](op).view(1)[0] = fl.view(1)[0].freelist;
        fl.view(1)[0].freelist = ptr(op);
        fl.view(1)[0].size = size + 1;
        return True;
    }
    return False;
}
