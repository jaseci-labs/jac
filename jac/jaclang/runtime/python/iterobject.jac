# Objects/iterobject.c ported to native Jac.
#
# Three iterator types over the shared 53-field type layout:
#   - PySeqIter_Type ("iterator", seqiterobject: head + it_index + it_seq,
#     32 bytes) — PySeqIter_New is def:pub;
#   - PyCallIter_Type ("callable_iterator", calliterobject: head + two
#     object slots, 32 bytes) — PyCallIter_New is def:pub;
#   - _PyAnextAwaitable_Type ("anext_awaitable", anextawaitableobject: head
#     + wrapped + default_value, 32 bytes) — PyAnextAwaitable_New is
#     def:pub. Its tp_as_async points at a defined static PyAsyncMethods
#     record (am_await = PyObject_SelfIter), decayed into the raw pointer
#     field like the other static records.
#
# All three are GC types (flags 16384) with tp_iternext slots; iteration
# dispatch (`(*Py_TYPE(x))->tp_iternext)(x)`) is a typed field call.
#
# Residue: the Py_BuildValue formats (N(O)n / N(()) / N(OO)), the
# PyObject_CallMethod proxy, and the cached `iter` builtin
# (_PyEval_GetBuiltin(&_Py_ID(iter))); also the GC-track/untrack calls
# stay C helpers beside the capsule ones.


import from jaclang.runtime.python.refcount { py_incref, py_decref }

import from c {
    obj PyObject;
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

    # PySequenceMethods, only the head we need: sq_length decides
    # _PyObject_HasLen.
    obj PySequenceMethods_Layout {
        has sq_length: Callable[[ptr[PyObject]], i64] = 0;
    }

    # PyAsyncMethods for the anext-awaitable type.
    obj PyAsyncMethods_Layout {
        has am_await: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            am_aiter: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            am_anext: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            am_send: Callable[[ptr[PyObject], ptr, ptr, ptr], i64] = 0;
    }

    obj PyMethodDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }

    obj _SeqIter_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout(),
            e3: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    obj _CallIter_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    obj _AnextAwaitable_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout(),
            e3: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    # seqiterobject
    obj _SeqIter_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            it_index: i64 = 0,
            it_seq: ptr[PyObject] = ptr[PyObject]();
    }

    # calliterobject
    obj _CallIter_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            it_callable: ptr[PyObject] = ptr[PyObject](),
            it_sentinel: ptr[PyObject] = ptr[PyObject]();
    }

    # anextawaitableobject
    obj _AnextAwaitable_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            wrapped: ptr[PyObject] = ptr[PyObject](),
            default_value: ptr[PyObject] = ptr[PyObject]();
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyExc_OverflowError: ptr[PyObject];
    glob PyExc_IndexError: ptr[PyObject];
    glob PyExc_StopIteration: ptr[PyObject];
    glob PyExc_StopAsyncIteration: ptr[PyObject];
    glob PyExc_TypeError: ptr[PyObject];
    # Py_None / Py_NotImplemented are macros over these exported structs.
    glob _Py_NoneStruct: PyObject_Layout;
    glob _Py_NotImplementedStruct: PyObject_Layout;

    # Py_VISIT: `visit` is a C function pointer, not a Jac Callable.
    def jacpy_visit(visitf: ptr, o: ptr[PyObject], arg: ptr) -> i32;
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyErr_BadInternalCall() -> None;
    def PyErr_Clear() -> None;
    def PyErr_ExceptionMatches(exc: ptr[PyObject]) -> i32;
    def PyErr_Occurred() -> ptr[PyObject];
    def _PyObject_GC_New(tp: ptr[PyTypeObject_Layout]) -> ptr[PyObject];
    def PyObject_GC_UnTrack(o: ptr[PyObject]) -> None;
    def PyObject_GC_Del(o: ptr[PyObject]) -> None;
    def PyObject_SelfIter(self: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PySequence_Check(seq: ptr[PyObject]) -> i32;
    def PySequence_GetItem(seq: ptr[PyObject], i: i64) -> ptr[PyObject];
    def PySequence_Size(seq: ptr[PyObject]) -> i64;
    def PyLong_FromSsize_t(v: i64) -> ptr[PyObject];
    def PyLong_FromLong(v: i64) -> ptr[PyObject];
    def PyLong_AsSsize_t(v: ptr[PyObject]) -> i64;
    def PyObject_RichCompareBool(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> i32;
    def PyObject_CallNoArgs(fn: ptr[PyObject]) -> ptr[PyObject];
    def _PyCoro_GetAwaitableIter(o: ptr[PyObject]) -> ptr[PyObject];
    def _PyGen_SetStopIterationValue(v: ptr[PyObject]) -> i32;
    def jacpy_iter_builtin() -> ptr[PyObject];
    def jacpy_iter_reduce_seq(iter: ptr[PyObject], seq: ptr[PyObject], index: i64) -> ptr[PyObject];
    def jacpy_iter_reduce_empty(iter: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_iter_reduce_pair(iter: ptr[PyObject], callable: ptr[PyObject], sentinel: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_iter_proxy(awaitable: ptr[PyObject], meth: ptr[u8], arg: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_capsule_is_tracked(o: ptr[PyObject]) -> i32;
    def jacpy_capsule_track(o: ptr[PyObject]) -> None;
}

# ----------------------------- sequence iterator ----------------------------

def:pub PySeqIter_New(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not PySequence_Check(seq) {
        PyErr_BadInternalCall();
        return ptr[PyObject]();
    }
    it = _PyObject_GC_New(PySeqIter_Type);
    if it == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    sit = ptr[_SeqIter_Layout](it);
    sit.it_index = 0;
    sit.it_seq = seq;
    py_incref(seq);
    jacpy_capsule_track(it);
    return it;
}

def iter_dealloc(op: ptr[PyObject]) -> None {
    it = ptr[_SeqIter_Layout](op);
    PyObject_GC_UnTrack(op);
    if it.it_seq != ptr[PyObject]() {
        py_decref(it.it_seq);
    }
    PyObject_GC_Del(op);
}

def iter_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    it = ptr[_SeqIter_Layout](op);
    if it.it_seq != ptr[PyObject]() {
        vret = jacpy_visit(visitf, it.it_seq, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

def iter_iternext(iterator: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[_SeqIter_Layout](iterator);
    seq = it.it_seq;
    if seq == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if it.it_index == 9223372036854775807 {
        PyErr_SetString(PyExc_OverflowError, "iter index too large");
        return ptr[PyObject]();
    }
    result = PySequence_GetItem(seq, it.it_index);
    if result != ptr[PyObject]() {
        it.it_index = it.it_index + 1;
        return result;
    }
    if PyErr_ExceptionMatches(PyExc_IndexError) or PyErr_ExceptionMatches(PyExc_StopIteration) {
        PyErr_Clear();
        it.it_seq = ptr[PyObject]();
        py_decref(seq);
    }
    return ptr[PyObject]();
}

def iter_len(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    notimpl_obj: ptr[PyObject] = _Py_NotImplementedStruct;
    it = ptr[_SeqIter_Layout](op);
    if it.it_seq != ptr[PyObject]() {
        if _iter_has_len(it.it_seq) {
            seqsize = PySequence_Size(it.it_seq);
            if seqsize == -1 {
                return ptr[PyObject]();
            }
        } else {
            py_incref(notimpl_obj);
            return notimpl_obj;
        }
        len = seqsize - it.it_index;
        if len >= 0 {
            return PyLong_FromSsize_t(len);
        }
    }
    return PyLong_FromLong(0);
}

def iter_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[_SeqIter_Layout](op);
    iter = jacpy_iter_builtin();
    # _PyEval_GetBuiltin can invoke arbitrary code, call must come before
    # access of iterator pointers.
    if it.it_seq != ptr[PyObject]() {
        return jacpy_iter_reduce_seq(iter, it.it_seq, it.it_index);
    }
    return jacpy_iter_reduce_empty(iter);
}

def iter_setstate(op: ptr[PyObject], state: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    it = ptr[_SeqIter_Layout](op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if it.it_seq != ptr[PyObject]() {
        if index < 0 {
            index = 0;
        }
        it.it_index = index;
    }
    py_incref(none_obj);
    return none_obj;
}

def _iter_has_len(o: ptr[PyObject]) -> i32 {
    head = ptr[PyObject_Layout](o);
    ty = ptr[PyTypeObject_Layout](head.ob_type);
    if ty.tp_as_sequence == ptr() {
        return 0;
    }
    sq = ptr[PySequenceMethods_Layout](ty.tp_as_sequence);
    if sq.sq_length != 0 {
        return 1;
    }
    return 0;
}

glob iter_methods: _SeqIter_Methods = _SeqIter_Methods(
    e0=PyMethodDef_Layout(
        name="__length_hint__",
        ml_meth=iter_len,
        ml_flags=4,
        ml_doc="Private method returning an estimate of len(list(it))."
    ),
    e1=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=iter_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling."
    ),
    e2=PyMethodDef_Layout(
        name="__setstate__",
        ml_meth=iter_setstate,
        ml_flags=8,
        ml_doc="Set state information for unpickling."
    )
);

glob:pub PySeqIter_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="iterator",
    tp_basicsize=32,
    tp_itemsize=0,
    tp_dealloc=iter_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=16384,
    tp_traverse=iter_traverse,
    tp_iter=PyObject_SelfIter,
    tp_iternext=iter_iternext,
    tp_methods=iter_methods
);

# ------------------------------ call iterator -------------------------------

def:pub PyCallIter_New(callable: ptr[PyObject], sentinel: ptr[PyObject]) -> ptr[PyObject] {
    it = _PyObject_GC_New(PyCallIter_Type);
    if it == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    cit = ptr[_CallIter_Layout](it);
    cit.it_callable = callable;
    cit.it_sentinel = sentinel;
    py_incref(callable);
    py_incref(sentinel);
    jacpy_capsule_track(it);
    return it;
}

def calliter_dealloc(op: ptr[PyObject]) -> None {
    it = ptr[_CallIter_Layout](op);
    PyObject_GC_UnTrack(op);
    if it.it_callable != ptr[PyObject]() {
        py_decref(it.it_callable);
    }
    if it.it_sentinel != ptr[PyObject]() {
        py_decref(it.it_sentinel);
    }
    PyObject_GC_Del(op);
}

def calliter_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    it = ptr[_CallIter_Layout](op);
    if it.it_callable != ptr[PyObject]() {
        vret = jacpy_visit(visitf, it.it_callable, arg);
        if vret != 0 {
            return vret;
        }
    }
    if it.it_sentinel != ptr[PyObject]() {
        vret = jacpy_visit(visitf, it.it_sentinel, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

def calliter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[_CallIter_Layout](op);
    if it.it_callable == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    result = PyObject_CallNoArgs(it.it_callable);
    if result != ptr[PyObject]() and it.it_sentinel != ptr[PyObject]() {
        ok = PyObject_RichCompareBool(it.it_sentinel, result, 2);
        if ok == 0 {
            return result;
        }
        if ok > 0 {
            it.it_callable = ptr[PyObject]();
            it.it_sentinel = ptr[PyObject]();
        }
    } elif PyErr_ExceptionMatches(PyExc_StopIteration) {
        PyErr_Clear();
        it.it_callable = ptr[PyObject]();
        it.it_sentinel = ptr[PyObject]();
    }
    if result != ptr[PyObject]() {
        py_decref(result);
    }
    return ptr[PyObject]();
}

def calliter_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[_CallIter_Layout](op);
    iter = jacpy_iter_builtin();
    if it.it_callable != ptr[PyObject]() and it.it_sentinel != ptr[PyObject]() {
        return jacpy_iter_reduce_pair(iter, it.it_callable, it.it_sentinel);
    }
    return jacpy_iter_reduce_empty(iter);
}

glob calliter_methods: _CallIter_Methods = _CallIter_Methods(
    e0=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=calliter_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling."
    )
);

glob:pub PyCallIter_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="callable_iterator",
    tp_basicsize=32,
    tp_itemsize=0,
    tp_dealloc=calliter_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=16384,
    tp_traverse=calliter_traverse,
    tp_iter=PyObject_SelfIter,
    tp_iternext=calliter_iternext,
    tp_methods=calliter_methods
);

# ---------------------------- anext-awaitable -------------------------------

def anextawaitable_dealloc(op: ptr[PyObject]) -> None {
    aw = ptr[_AnextAwaitable_Layout](op);
    PyObject_GC_UnTrack(op);
    if aw.wrapped != ptr[PyObject]() {
        py_decref(aw.wrapped);
    }
    if aw.default_value != ptr[PyObject]() {
        py_decref(aw.default_value);
    }
    PyObject_GC_Del(op);
}

def anextawaitable_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    aw = ptr[_AnextAwaitable_Layout](op);
    if aw.wrapped != ptr[PyObject]() {
        vret = jacpy_visit(visitf, aw.wrapped, arg);
        if vret != 0 {
            return vret;
        }
    }
    if aw.default_value != ptr[PyObject]() {
        vret = jacpy_visit(visitf, aw.default_value, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

def anextawaitable_getiter(aw: ptr[_AnextAwaitable_Layout]) -> ptr[PyObject] {
    awaitable = _PyCoro_GetAwaitableIter(aw.wrapped);
    if awaitable == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    ahead = ptr[PyObject_Layout](awaitable);
    aty = ptr[PyTypeObject_Layout](ahead.ob_type);
    if aty.tp_iternext == 0 {
        # _PyCoro_GetAwaitableIter returns a Coroutine, a Generator, or an
        # iterator; only coroutines lack tp_iternext.
        aasync = ptr[PyAsyncMethods_Layout](aty.tp_as_async);
        new_awaitable = aasync.am_await(awaitable);
        if new_awaitable == ptr[PyObject]() {
            py_decref(awaitable);
            return ptr[PyObject]();
        }
        py_decref(awaitable);
        awaitable = new_awaitable;
        ahead = ptr[PyObject_Layout](awaitable);
        aty = ptr[PyTypeObject_Layout](ahead.ob_type);
        if aty.tp_iternext == 0 {
            PyErr_SetString(PyExc_TypeError, "__await__ returned a non-iterable");
            py_decref(awaitable);
            return ptr[PyObject]();
        }
    }
    return awaitable;
}

def anextawaitable_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    aw = ptr[_AnextAwaitable_Layout](op);
    awaitable = anextawaitable_getiter(aw);
    if awaitable == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    ahead = ptr[PyObject_Layout](awaitable);
    aty = ptr[PyTypeObject_Layout](ahead.ob_type);
    result = aty.tp_iternext(awaitable);
    py_decref(awaitable);
    if result != ptr[PyObject]() {
        return result;
    }
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) {
        PyErr_Clear();
        _PyGen_SetStopIterationValue(aw.default_value);
    }
    return ptr[PyObject]();
}

def anextawaitable_proxy(aw: ptr[_AnextAwaitable_Layout], meth: ptr[u8], arg: ptr[PyObject]) -> ptr[PyObject] {
    awaitable = anextawaitable_getiter(aw);
    if awaitable == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    # arg may be a tuple (METH_VARARGS) or a single object (METH_O); NULL
    # means the method takes no arguments.
    ret = jacpy_iter_proxy(awaitable, meth, arg);
    py_decref(awaitable);
    if ret != ptr[PyObject]() {
        return ret;
    }
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) {
        # Replace StopAsyncIteration with StopIteration(default), as if it
        # were the return value of the __anext__ coroutine.
        PyErr_Clear();
        _PyGen_SetStopIterationValue(aw.default_value);
    }
    return ptr[PyObject]();
}

def anextawaitable_send(op: ptr[PyObject], arg: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    aw = ptr[_AnextAwaitable_Layout](op);
    return anextawaitable_proxy(aw, "send", arg);
}

def anextawaitable_throw(op: ptr[PyObject], args: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    aw = ptr[_AnextAwaitable_Layout](op);
    return anextawaitable_proxy(aw, "throw", args);
}

def anextawaitable_close(op: ptr[PyObject], dummy: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    aw = ptr[_AnextAwaitable_Layout](op);
    return anextawaitable_proxy(aw, "close", ptr[PyObject]());
}

glob anextawaitable_methods: _AnextAwaitable_Methods = _AnextAwaitable_Methods(
    e0=PyMethodDef_Layout(
        name="send",
        ml_meth=anextawaitable_send,
        ml_flags=8,
        ml_doc=(
            "send(arg) -> send 'arg' into the wrapped iterator,\n"
            "return next yielded value or raise StopIteration."
        )
    ),
    e1=PyMethodDef_Layout(
        name="throw",
        ml_meth=anextawaitable_throw,
        ml_flags=1,
        ml_doc=(
            "throw(value)\n"
            "throw(typ[,val[,tb]])\n"
            "\n"
            "raise exception in the wrapped iterator, return next yielded value\n"
            "or raise StopIteration.\n"
            "the (type, val, tb) signature is deprecated, \n"
            "and may be removed in a future version of Python."
        )
    ),
    e2=PyMethodDef_Layout(
        name="close",
        ml_meth=anextawaitable_close,
        ml_flags=4,
        ml_doc="close() -> raise GeneratorExit inside generator."
    )
);

glob anextawaitable_as_async: PyAsyncMethods_Layout = PyAsyncMethods_Layout(
    am_await=PyObject_SelfIter
);

glob:pub _PyAnextAwaitable_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="anext_awaitable",
    tp_basicsize=32,
    tp_itemsize=0,
    tp_dealloc=anextawaitable_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_as_async=anextawaitable_as_async,
    tp_flags=16384,
    tp_traverse=anextawaitable_traverse,
    tp_iter=PyObject_SelfIter,
    tp_iternext=anextawaitable_iternext,
    tp_methods=anextawaitable_methods
);

def:pub PyAnextAwaitable_New(awaitable: ptr[PyObject], default_value: ptr[PyObject]) -> ptr[PyObject] {
    anext_obj = _PyObject_GC_New(_PyAnextAwaitable_Type);
    if anext_obj == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    anext = ptr[_AnextAwaitable_Layout](anext_obj);
    anext.wrapped = awaitable;
    anext.default_value = default_value;
    py_incref(awaitable);
    py_incref(default_value);
    jacpy_capsule_track(anext_obj);
    return anext_obj;
}
