# Objects/enumobject.c ported to native Jac.
#
# enumerate ("enumerate") and reversed ("reversed"): two GC iterator types
# over the shared 53-field type layout, both BASETYPE (flags 17408) with
# vectorcall constructors (the tp_vectorcall field now has the C arity:
# type, args, nargsf, kwnames).
#
# Layout facts pinned from CPython 3.14.6: enumobject = head + en_index +
# en_sit + en_result + en_longindex + one = 56 bytes; reversedobject = head
# + index + seq = 32 bytes. The critical sections and FT_ATOMIC_* accessors
# are GIL-build no-ops (plain field access). METH_O|METH_CLASS = 8|16 = 24.
#
# Residue: _PyLong_GetOne (static inline in pycore_long.h), the tuple
# item macros (direct ob_item access), the Py_BuildValue formats, the
# _PyObject_LookupSpecial(&_Py_ID(__reversed__)) static identifier, the
# "%.200s is not reversible"/"'%S' is an invalid keyword"/"(N given)"
# formatters, and the (None, None) result tuple seed.


import from jaclang.runtime.python.refcount { py_incref, py_decref }

import from c {
    obj PyObject;
    # A vectorcall `PyObject *const *args` array (up to 3 positional args):
    # read `args[i]` directly instead of a C helper call.
    obj ArgVec3 {
        has a0: ptr[PyObject] = ptr[PyObject](),
            a1: ptr[PyObject] = ptr[PyObject](),
            a2: ptr[PyObject] = ptr[PyObject]();
    }
    # A 2-item PyTupleObject (3.14 caches ob_hash before ob_item): the
    # PyTuple_GET_ITEM / PyTuple_SET_ITEM macros on enumerate's result pair.
    obj PyTuple2_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            ob_size: i64 = 0,
            ob_hash: i64 = 0,
            item0: ptr[PyObject] = ptr[PyObject](),
            item1: ptr[PyObject] = ptr[PyObject]();
    }
    # PyGC_Head, the 16 bytes before a GC object.
    obj PyGCHead_Layout {
        has gc_next: i64 = 0,
            gc_prev: i64 = 0;
    }
    # Local copy of the 53-field type layout (cellobject.jac owns the
    # reference spelling): extern struct globals need a same-module
    # layout for native lowering; imported obj types only lower
    # behind ptr[...].
    obj PyTypeObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            ob_size: i64 = 0,
            tp_name: ptr[u8] = ptr[u8](),
            tp_basicsize: i64 = 0,
            tp_itemsize: i64 = 0,
            tp_dealloc: Callable[[ptr[PyObject]], None] = 0,
            tp_vectorcall_offset: i64 = 0,
            tp_getattr: Callable[[ptr[PyObject], ptr[u8]], ptr[PyObject]] = 0,
            tp_setattr: Callable[[ptr[PyObject], ptr[u8], ptr[PyObject]], i32] = 0,
            tp_as_async: ptr = ptr(),
            tp_repr: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_as_number: ptr = ptr(),
            tp_as_sequence: ptr = ptr(),
            tp_as_mapping: ptr = ptr(),
            tp_hash: Callable[[ptr[PyObject]], i64] = 0,
            tp_call: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_str: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_getattro: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_setattro: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            tp_as_buffer: ptr = ptr(),
            tp_flags: u64 = 0,
            tp_doc: ptr[u8] = ptr[u8](),
            tp_traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            tp_clear: Callable[[ptr[PyObject]], i32] = 0,
            tp_richcompare: Callable[[ptr[PyObject], ptr[PyObject], i32], ptr[PyObject]] = 0,
            tp_weaklistoffset: i64 = 0,
            tp_iter: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_iternext: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_methods: ptr = ptr(),
            tp_members: ptr = ptr(),
            tp_getset: ptr = ptr(),
            tp_base: ptr[PyTypeObject_Layout] = ptr[PyTypeObject_Layout](),
            tp_dict: ptr[PyObject] = ptr[PyObject](),
            tp_descr_get: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_descr_set: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], None] = 0,
            tp_dictoffset: i64 = 0,
            tp_init: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            tp_alloc: Callable[[ptr[PyTypeObject_Layout], i64], ptr[PyObject]] = 0,
            tp_new: Callable[[ptr[PyTypeObject_Layout], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_free: Callable[[ptr], None] = 0,
            tp_is_gc: Callable[[ptr[PyObject]], i32] = 0,
            tp_bases: ptr[PyObject] = ptr[PyObject](),
            tp_mro: ptr[PyObject] = ptr[PyObject](),
            tp_cache: ptr[PyObject] = ptr[PyObject](),
            tp_subclasses: ptr = ptr(),
            tp_weaklist: ptr[PyObject] = ptr[PyObject](),
            tp_del: Callable[[ptr[PyObject]], None] = 0,
            tp_version_tag: u32 = 0,
            tp_finalize: Callable[[ptr[PyObject]], None] = 0,
            tp_vectorcall: Callable[[ptr[PyObject], ptr[PyObject], i64, ptr[PyObject]], ptr[PyObject]] = 0,
            tp_watched: u8 = 0,
            tp_versions_used: u16 = 0;
    }

    obj PyObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject]();
    }

    obj PyMethodDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }

    obj _Enum_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    obj _ReversedIter_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout(),
            e3: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    # enumobject
    obj _Enum_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            en_index: i64 = 0,
            en_sit: ptr[PyObject] = ptr[PyObject](),
            en_result: ptr[PyObject] = ptr[PyObject](),
            en_longindex: ptr[PyObject] = ptr[PyObject](),
            one: ptr[PyObject] = ptr[PyObject]();
    }

    # reversedobject
    obj _Reversed_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            index: i64 = 0,
            seq: ptr[PyObject] = ptr[PyObject]();
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyExc_TypeError: ptr[PyObject];
    glob PyExc_IndexError: ptr[PyObject];
    glob PyExc_StopIteration: ptr[PyObject];
    # Py_None / Py_NotImplemented are macros over these exported structs.
    glob _Py_NoneStruct: PyObject_Layout;

    # Py_VISIT: `visit` is a C function pointer, not a Jac Callable.
    def jacpy_visit(visitf: ptr, o: ptr[PyObject], arg: ptr) -> i32;
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyErr_Clear() -> None;
    def PyErr_Occurred() -> ptr[PyObject];
    def PyErr_ExceptionMatches(exc: ptr[PyObject]) -> i32;
    def _PyObject_GC_New(tp: ptr[PyTypeObject_Layout]) -> ptr[PyObject];
    def PyObject_GC_UnTrack(o: ptr[PyObject]) -> None;
    def PyObject_GC_Del(o: ptr[PyObject]) -> None;
    def PyType_GenericAlloc(tp: ptr[PyTypeObject_Layout], nitems: i64) -> ptr[PyObject];
    def PyObject_CallNoArgs(fn: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_SelfIter(self: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_GetIter(iterable: ptr[PyObject]) -> ptr[PyObject];
    def PyLong_FromSsize_t(v: i64) -> ptr[PyObject];
    def PyLong_AsSsize_t(v: ptr[PyObject]) -> i64;
    def PyLong_FromLong(v: i64) -> ptr[PyObject];
    def PyNumber_Index(o: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Add(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PySequence_Check(seq: ptr[PyObject]) -> i32;
    def PySequence_Size(seq: ptr[PyObject]) -> i64;
    def PySequence_GetItem(seq: ptr[PyObject], i: i64) -> ptr[PyObject];
    def PyTuple_New(len: i64) -> ptr[PyObject];
    def PyTuple_Size(p: ptr[PyObject]) -> i64;
    def PyTuple_GetItem(p: ptr[PyObject], index: i64) -> ptr[PyObject];
    def PyDict_Size(d: ptr[PyObject]) -> i64;
    def _PyArg_NoKeywords(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def _PyArg_NoKwnames(fname: ptr[u8], kwnames: ptr[PyObject]) -> i32;
    def _PyArg_CheckPositional(fname: ptr[u8], nargs: i64, min: i64, max: i64) -> i32;
    def jacpy_is_tuple(handle: ptr[PyObject]) -> i64;
    def jacpy_exception_type(kind: ptr[u8]) -> ptr[PyObject];
    def jacpy_enum_new_too_many(nargs: i64) -> None;
    def jacpy_reversed_new_too_many(nargs: i64) -> None;
    def _PyUnicode_EqualToASCIIString(u: ptr[PyObject], s: ptr[u8]) -> i32;
    def Py_GenericAlias(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_tuple_recycle(op: ptr[PyObject]) -> None;
    def jacpy_long_one() -> ptr[PyObject];
    def jacpy_tuple_borrow(t: ptr[PyObject], index: i64) -> ptr[PyObject];
    # (iterable,) or (iterable, start) from enumerate(*args, **kwargs).
    def jacpy_enum_new_args(args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_reversed_reject_kwargs(tp: ptr[PyTypeObject_Layout], kwargs: ptr[PyObject]) -> i32;
    def jacpy_tuple_set_item(t: ptr[PyObject], index: i64, v: ptr[PyObject]) -> None;
    def jacpy_enum_result_tuple() -> ptr[PyObject];
    def jacpy_enum_bad_keyword(kw: ptr[PyObject]) -> None;
    def jacpy_enum_too_many(nargs: i64) -> None;
    def jacpy_enum_not_reversible(tp_name: ptr[u8]) -> None;
    def jacpy_reversed_lookup(seq: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_iter_reduce_seq(iter: ptr[PyObject], seq: ptr[PyObject], index: i64) -> ptr[PyObject];
    def jacpy_enum_reduce_long(tp: ptr[PyObject], sit: ptr[PyObject], longindex: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_enum_reduce_plain(tp: ptr[PyObject], sit: ptr[PyObject], index: i64) -> ptr[PyObject];
    def jacpy_reversed_reduce_seq(tp: ptr[PyObject], seq: ptr[PyObject], index: i64) -> ptr[PyObject];
    def jacpy_reversed_reduce_empty(tp: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_capsule_is_tracked(o: ptr[PyObject]) -> i32;
    def jacpy_capsule_track(o: ptr[PyObject]) -> None;
}

# ------------------------------- enumerate ----------------------------------

def enum_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds != ptr[PyObject]() and PyDict_Size(kwds) > 0 {
        # Keyword form (iterable=, start=): the clinic keyword parser.
        parsed = jacpy_enum_new_args(args, kwds);
        if parsed == ptr[PyObject]() {
            return ptr[PyObject]();
        }
        kw_start = ptr[PyObject]();
        if PyTuple_Size(parsed) == 2 {
            kw_start = PyTuple_GetItem(parsed, 1);
        }
        result = enum_new_impl(type_, PyTuple_GetItem(parsed, 0), kw_start);
        py_decref(parsed);
        return result;
    }
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return ptr[PyObject]();
    }
    nargs = PyTuple_Size(args);
    if nargs < 1 {
        PyErr_SetString(
            PyExc_TypeError,
            "enumerate() missing required argument 'iterable' (pos 1)"
        );
        return ptr[PyObject]();
    }
    if nargs > 2 {
        jacpy_enum_new_too_many(nargs);
        return ptr[PyObject]();
    }
    iterable = PyTuple_GetItem(args, 0);
    if iterable == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    start = ptr[PyObject]();
    if nargs == 2 {
        start = PyTuple_GetItem(args, 1);
        if start == ptr[PyObject]() {
            return ptr[PyObject]();
        }
    }
    return enum_new_impl(type_, iterable, start);
}

def enum_new_impl(
    type_: ptr[PyTypeObject_Layout], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject] {
    en_obj = type_.tp_alloc(type_, 0);
    if en_obj == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    en = ptr[_Enum_Layout](en_obj);
    if start != ptr[PyObject]() {
        start = PyNumber_Index(start);
        if start == ptr[PyObject]() {
            py_decref(en_obj);
            return ptr[PyObject]();
        }
        en.en_index = PyLong_AsSsize_t(start);
        if en.en_index == -1 and PyErr_Occurred() != ptr[PyObject]() {
            PyErr_Clear();
            en.en_index = 9223372036854775807;
            en.en_longindex = start;
        } else {
            en.en_longindex = ptr[PyObject]();
            py_decref(start);
        }
    } else {
        en.en_index = 0;
        en.en_longindex = ptr[PyObject]();
    }
    en.en_sit = PyObject_GetIter(iterable);
    if en.en_sit == ptr[PyObject]() {
        py_decref(en_obj);
        return ptr[PyObject]();
    }
    en.en_result = jacpy_enum_result_tuple();
    if en.en_result == ptr[PyObject]() {
        py_decref(en_obj);
        return ptr[PyObject]();
    }
    en.one = jacpy_long_one();
    return en_obj;
}

def check_keyword(kwnames: ptr[PyObject], index: i64, name: ptr[u8]) -> i32 {
    kw = jacpy_tuple_borrow(kwnames, index);
    if not _PyUnicode_EqualToASCIIString(kw, name) {
        jacpy_enum_bad_keyword(kw);
        return 0;
    }
    return 1;
}

def enumerate_vectorcall(
    type_: ptr[PyTypeObject_Layout], args: ptr, nargsf: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = nargsf & 9223372036854775807;
    nkwargs: i64 = 0;
    if kwnames != ptr[PyObject]() {
        nkwargs = PyTuple_Size(kwnames);
    }

    # Manually implement enumerate(iterable, start=...)
    if nargs + nkwargs == 2 {
        if nkwargs == 1 {
            if not check_keyword(kwnames, 0, "start") {
                return ptr[PyObject]();
            }
        } elif nkwargs == 2 {
            kw0 = jacpy_tuple_borrow(kwnames, 0);
            if _PyUnicode_EqualToASCIIString(kw0, "start") {
                if not check_keyword(kwnames, 1, "iterable") {
                    return ptr[PyObject]();
                }
                return enum_new_impl(type_, ptr[ArgVec3](args).a1, ptr[ArgVec3](args).a0);
            }
            if not check_keyword(kwnames, 0, "iterable") {
                return ptr[PyObject]();
            }
            if not check_keyword(kwnames, 1, "start") {
                return ptr[PyObject]();
            }
        }
        return enum_new_impl(type_, ptr[ArgVec3](args).a0, ptr[ArgVec3](args).a1);
    }

    if nargs + nkwargs == 1 {
        if nkwargs == 1 and not check_keyword(kwnames, 0, "iterable") {
            return ptr[PyObject]();
        }
        return enum_new_impl(type_, ptr[ArgVec3](args).a0, ptr[PyObject]());
    }

    if nargs == 0 {
        PyErr_SetString(PyExc_TypeError, "enumerate() missing required argument 'iterable'");
        return ptr[PyObject]();
    }

    jacpy_enum_too_many(nargs + nkwargs);
    return ptr[PyObject]();
}

def enum_dealloc(op: ptr[PyObject]) -> None {
    en = ptr[_Enum_Layout](op);
    PyObject_GC_UnTrack(op);
    if en.en_sit != ptr[PyObject]() {
        py_decref(en.en_sit);
    }
    if en.en_result != ptr[PyObject]() {
        py_decref(en.en_result);
    }
    if en.en_longindex != ptr[PyObject]() {
        py_decref(en.en_longindex);
    }
    head = ptr[PyObject_Layout](op);
    ty = ptr[PyTypeObject_Layout](head.ob_type);
    ty.tp_free(op);
}

def enum_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    en = ptr[_Enum_Layout](op);
    if en.en_sit != ptr[PyObject]() {
        vret = jacpy_visit(visitf, en.en_sit, arg);
        if vret != 0 {
            return vret;
        }
    }
    if en.en_result != ptr[PyObject]() {
        vret = jacpy_visit(visitf, en.en_result, arg);
        if vret != 0 {
            return vret;
        }
    }
    if en.en_longindex != ptr[PyObject]() {
        vret = jacpy_visit(visitf, en.en_longindex, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

# Increment en_longindex, return the next index to be used or NULL on error.
def increment_longindex_lock_held(en: ptr[_Enum_Layout]) -> ptr[PyObject] {
    next_index = en.en_longindex;
    if next_index == ptr[PyObject]() {
        next_index = PyLong_FromSsize_t(9223372036854775807);
        if next_index == ptr[PyObject]() {
            return ptr[PyObject]();
        }
    }
    stepped_up = PyNumber_Add(next_index, en.one);
    if stepped_up == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    en.en_longindex = stepped_up;
    return next_index;
}

# _PyTuple_Recycle: reset the hash cache and re-track the tuple if the GC
# untracked it (bpo-42536); tracking itself stays C (rare path).
def tuple_recycle(t: ptr[PyObject]) -> None {
    pair = ptr[PyTuple2_Layout](t);
    pair.ob_hash = -1;
    gc = ptr[PyGCHead_Layout](ptr(t) - 16);
    if gc.gc_next == 0 {
        jacpy_tuple_recycle(t);
    }
}

def enum_next_long(en: ptr[_Enum_Layout], next_item: ptr[PyObject]) -> ptr[PyObject] {
    result = en.en_result;
    next_index = increment_longindex_lock_held(en);
    if next_index == ptr[PyObject]() {
        py_decref(next_item);
        return ptr[PyObject]();
    }

    head = ptr[PyObject_Layout](result);
    if head.ob_refcnt == 1 {
        py_incref(result);
        pair = ptr[PyTuple2_Layout](result);
        old_index = pair.item0;
        old_item = pair.item1;
        pair.item0 = next_index;
        pair.item1 = next_item;
        py_decref(old_index);
        py_decref(old_item);
        # The GC may have untracked this result tuple; since we're
        # recycling it, make sure it's tracked again.
        tuple_recycle(result);
        return result;
    }
    result = PyTuple_New(2);
    if result == ptr[PyObject]() {
        py_decref(next_index);
        py_decref(next_item);
        return ptr[PyObject]();
    }
    fresh = ptr[PyTuple2_Layout](result);
    fresh.item0 = next_index;
    fresh.item1 = next_item;
    return result;
}

def enum_next(op: ptr[PyObject]) -> ptr[PyObject] {
    en = ptr[_Enum_Layout](op);
    result = en.en_result;
    it = en.en_sit;

    ihead = ptr[PyObject_Layout](it);
    ity = ptr[PyTypeObject_Layout](ihead.ob_type);
    next_item = ity.tp_iternext(it);
    if next_item == ptr[PyObject]() {
        return ptr[PyObject]();
    }

    en_index = en.en_index;
    if en_index == 9223372036854775807 {
        return enum_next_long(en, next_item);
    }

    next_index = PyLong_FromSsize_t(en_index);
    if next_index == ptr[PyObject]() {
        py_decref(next_item);
        return ptr[PyObject]();
    }
    # en_index < PY_SSIZE_T_MAX here (the max case took the long path).
    en.en_index = wrapping_add(en_index, 1);

    head = ptr[PyObject_Layout](result);
    if head.ob_refcnt == 1 {
        py_incref(result);
        pair = ptr[PyTuple2_Layout](result);
        old_index = pair.item0;
        old_item = pair.item1;
        pair.item0 = next_index;
        pair.item1 = next_item;
        py_decref(old_index);
        py_decref(old_item);
        tuple_recycle(result);
        return result;
    }
    result = PyTuple_New(2);
    if result == ptr[PyObject]() {
        py_decref(next_index);
        py_decref(next_item);
        return ptr[PyObject]();
    }
    fresh = ptr[PyTuple2_Layout](result);
    fresh.item0 = next_index;
    fresh.item1 = next_item;
    return result;
}

def enum_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    en = ptr[_Enum_Layout](op);
    head = ptr[PyObject_Layout](op);
    if en.en_longindex != ptr[PyObject]() {
        return jacpy_enum_reduce_long(head.ob_type, en.en_sit, en.en_longindex);
    }
    return jacpy_enum_reduce_plain(head.ob_type, en.en_sit, en.en_index);
}

glob enum_methods: _Enum_Methods = _Enum_Methods(
    e0=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=enum_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling."
    ),
    e1=PyMethodDef_Layout(
        name="__class_getitem__",
        ml_meth=Py_GenericAlias,
        ml_flags=24,
        ml_doc="'enumerate' objects are generic over the type of their values"
    )
);

glob:pub PyEnum_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="enumerate",
    tp_basicsize=56,
    tp_itemsize=0,
    tp_dealloc=enum_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=17408,
    tp_doc=(
        "enumerate(iterable, start=0)\n"
        "--\n"
        "\n"
        "Return an enumerate object.\n"
        "\n"
        "  iterable\n"
        "    an object supporting iteration\n"
        "\n"
        "The enumerate object yields pairs containing a count (from start, which\n"
        "defaults to zero) and a value yielded by the iterable argument.\n"
        "\n"
        "enumerate is useful for obtaining an indexed list:\n"
        "    (0, seq[0]), (1, seq[1]), (2, seq[2]), ..."
    ),
    tp_traverse=enum_traverse,
    tp_iter=PyObject_SelfIter,
    tp_iternext=enum_next,
    tp_methods=enum_methods,
    tp_alloc=PyType_GenericAlloc,
    tp_new=enum_new,
    tp_free=PyObject_GC_Del,
    tp_vectorcall=enumerate_vectorcall
);

# ------------------------------- reversed -----------------------------------

def reversed_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    # Keywords are rejected for reversed itself and for subclasses that keep
    # its tp_init (the C test compares tp_init function pointers).
    if jacpy_reversed_reject_kwargs(type_, kwds) != 0 {
        return ptr[PyObject]();
    }
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return ptr[PyObject]();
    }
    nargs = PyTuple_Size(args);
    if nargs < 1 {
        PyErr_SetString(
            PyExc_TypeError,
            "reversed() missing required argument 'sequence' (pos 1)"
        );
        return ptr[PyObject]();
    }
    if nargs > 1 {
        jacpy_reversed_new_too_many(nargs);
        return ptr[PyObject]();
    }
    seq = PyTuple_GetItem(args, 0);
    if seq == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    return reversed_new_impl(type_, seq);
}

def reversed_new_impl(type_: ptr[PyTypeObject_Layout], seq: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    reversed_meth = jacpy_reversed_lookup(seq);
    if reversed_meth == none_obj {
        py_decref(reversed_meth);
        shead = ptr[PyObject_Layout](seq);
        sty = ptr[PyTypeObject_Layout](shead.ob_type);
        jacpy_enum_not_reversible(sty.tp_name);
        return ptr[PyObject]();
    }
    if reversed_meth != ptr[PyObject]() {
        res = PyObject_CallNoArgs(reversed_meth);
        py_decref(reversed_meth);
        return res;
    }
    if PyErr_Occurred() != ptr[PyObject]() {
        return ptr[PyObject]();
    }

    if not PySequence_Check(seq) {
        shead = ptr[PyObject_Layout](seq);
        sty = ptr[PyTypeObject_Layout](shead.ob_type);
        jacpy_enum_not_reversible(sty.tp_name);
        return ptr[PyObject]();
    }

    n = PySequence_Size(seq);
    if n == -1 {
        return ptr[PyObject]();
    }

    ro_obj = type_.tp_alloc(type_, 0);
    if ro_obj == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    ro = ptr[_Reversed_Layout](ro_obj);
    ro.index = n - 1;
    ro.seq = seq;
    py_incref(seq);
    return ro_obj;
}

def reversed_vectorcall(
    type_: ptr[PyTypeObject_Layout], args: ptr, nargsf: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames != ptr[PyObject]() and not _PyArg_NoKwnames("reversed", kwnames) {
        return ptr[PyObject]();
    }
    nargs = nargsf & 9223372036854775807;
    if nargs != 1 and not _PyArg_CheckPositional("reversed", nargs, 1, 1) {
        return ptr[PyObject]();
    }
    return reversed_new_impl(type_, ptr[ArgVec3](args).a0);
}

def reversed_dealloc(op: ptr[PyObject]) -> None {
    ro = ptr[_Reversed_Layout](op);
    PyObject_GC_UnTrack(op);
    if ro.seq != ptr[PyObject]() {
        py_decref(ro.seq);
    }
    head = ptr[PyObject_Layout](op);
    ty = ptr[PyTypeObject_Layout](head.ob_type);
    ty.tp_free(op);
}

def reversed_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    ro = ptr[_Reversed_Layout](op);
    if ro.seq != ptr[PyObject]() {
        vret = jacpy_visit(visitf, ro.seq, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

def reversed_next(op: ptr[PyObject]) -> ptr[PyObject] {
    ro = ptr[_Reversed_Layout](op);
    index = ro.index;

    if index >= 0 {
        item = PySequence_GetItem(ro.seq, index);
        if item != ptr[PyObject]() {
            ro.index = index - 1;
            return item;
        }
        if PyErr_ExceptionMatches(PyExc_IndexError) or PyErr_ExceptionMatches(PyExc_StopIteration) {
            PyErr_Clear();
        }
    }
    ro.index = -1;
    # Py_CLEAR(ro->seq) (GIL build)
    if ro.seq != ptr[PyObject]() {
        py_decref(ro.seq);
        ro.seq = ptr[PyObject]();
    }
    return ptr[PyObject]();
}

def reversed_len(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    ro = ptr[_Reversed_Layout](op);
    index = ro.index;

    if index == -1 {
        return PyLong_FromLong(0);
    }
    seqsize = PySequence_Size(ro.seq);
    if seqsize == -1 {
        return ptr[PyObject]();
    }
    position = index + 1;
    if seqsize < position {
        return PyLong_FromSsize_t(0);
    }
    return PyLong_FromSsize_t(position);
}

def reversed_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    ro = ptr[_Reversed_Layout](op);
    head = ptr[PyObject_Layout](op);
    index = ro.index;
    if index != -1 {
        return jacpy_reversed_reduce_seq(head.ob_type, ro.seq, ro.index);
    }
    return jacpy_reversed_reduce_empty(head.ob_type);
}

def reversed_setstate(op: ptr[PyObject], state: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    ro = ptr[_Reversed_Layout](op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return ptr[PyObject]();
    }
    ro_index = ro.index;
    # If the iterator is exhausted we do not set the state (backwards
    # compatibility; see gh-120971).
    if ro_index != -1 {
        n = PySequence_Size(ro.seq);
        if n < 0 {
            return ptr[PyObject]();
        }
        if index < -1 {
            index = -1;
        } elif index > n - 1 {
            index = n - 1;
        }
        ro.index = index;
    }
    py_incref(none_obj);
    return none_obj;
}

glob reversediter_methods: _ReversedIter_Methods = _ReversedIter_Methods(
    e0=PyMethodDef_Layout(
        name="__length_hint__",
        ml_meth=reversed_len,
        ml_flags=4,
        ml_doc="Private method returning an estimate of len(list(it))."
    ),
    e1=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=reversed_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling."
    ),
    e2=PyMethodDef_Layout(
        name="__setstate__",
        ml_meth=reversed_setstate,
        ml_flags=8,
        ml_doc="Set state information for unpickling."
    )
);

glob:pub PyReversed_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="reversed",
    tp_basicsize=32,
    tp_itemsize=0,
    tp_dealloc=reversed_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=17408,
    tp_doc=(
        "reversed(sequence, /)\n"
        "--\n"
        "\n"
        "Return a reverse iterator over the values of the given sequence."
    ),
    tp_traverse=reversed_traverse,
    tp_iter=PyObject_SelfIter,
    tp_iternext=reversed_next,
    tp_methods=reversediter_methods,
    tp_alloc=PyType_GenericAlloc,
    tp_new=reversed_new,
    tp_free=PyObject_GC_Del,
    tp_vectorcall=reversed_vectorcall
);
