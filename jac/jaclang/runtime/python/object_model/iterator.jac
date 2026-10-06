"""Sequence, callable and anext iterators: Objects/iterobject.c in native Jac.

`PySeqIter_Type` (iter(sequence)), `PyCallIter_Type` (iter(callable,
sentinel)) and `_PyAnextAwaitable_Type` (anext(iterator, default)) are C data
Jac defines under their C names, and `PySeqIter_New`, `PyCallIter_New` and
`PyAnextAwaitable_New` C functions under theirs, so the builtins and the C
API use them unchanged. The object layouts come from layouts.jac. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_BadInternalCall,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_IndexError,
    PyExc_OverflowError,
    PyExc_StopAsyncIteration,
    PyExc_StopIteration,
    PyExc_TypeError,
    PyIter_Check,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyMethodDef,
    PyObject,
    PyObject_CallMethod,
    PyObject_CallNoArgs,
    PyObject_GC_Del,
    PyObject_GenericGetAttr,
    PyObject_RichCompareBool,
    PyObject_SelfIter,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyCoro_GetAwaitableIter,
    _PyGen_SetStopIterationValue,
    _PyObject_GC_New,
    _PyObject_HasLen,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_NOARGS,
    METH_O,
    METH_VARARGS,
    PyAsyncMethods,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object,
    anextawaitableobject,
    anextawaitableobject_SIZE,
    calliterobject,
    calliterobject_SIZE,
    seqiterobject,
    seqiterobject_SIZE
}
import from jaclang.runtime.python.object_model.header {
    eval_builtin,
    object_gc_track,
    object_gc_untrack,
    object_type,
    PyType_Type
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv seqiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(iter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(iter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(iter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         calliter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(calliter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         anextawaitable_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(anextawaitable_send),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "send(arg) -> send 'arg' into the wrapped iterator,\n"
                     "return next yielded value or raise StopIteration."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("throw"),
                 ml_meth=ptr(anextawaitable_throw),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "throw(value)\n"
                     "throw(typ[,val[,tb]])\n\n"
                     "raise exception in the wrapped iterator, return next yielded value\n"
                     "or raise StopIteration.\n"
                     "the (type, val, tb) signature is deprecated, \n"
                     "and may be removed in a future version of Python."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(anextawaitable_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("close() -> raise GeneratorExit inside generator.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         anextawaitable_as_async: PyAsyncMethods = PyAsyncMethods(
             am_await=PyObject_SelfIter
         ); glob PySeqIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("iterator"),
             tp_basicsize=seqiterobject_SIZE,
             tp_dealloc=iter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=iter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=iter_iternext,
             tp_methods=addressof(seqiter_methods)
         ),
         PyCallIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("callable_iterator"),
             tp_basicsize=calliterobject_SIZE,
             tp_dealloc=calliter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=calliter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=calliter_iternext,
             tp_methods=addressof(calliter_methods)
         ),
         _PyAnextAwaitable_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("anext_awaitable"),
             tp_basicsize=anextawaitableobject_SIZE,
             tp_dealloc=anextawaitable_dealloc,
             tp_as_async=addressof(anextawaitable_as_async),
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=anextawaitable_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=anextawaitable_iternext,
             tp_methods=addressof(anextawaitable_methods)
         );
}

# ---------------------------------------------------------- sequence iterator
def seqiter_of(op: ptr[PyObject]) -> ptr[seqiterobject] {
    return ptr[seqiterobject](op);
}

import from c {
    def PySeqIter_New(seq: ptr[PyObject]) -> ptr[PyObject] {
        if PySequence_Check(seq) == 0 {
            PyErr_BadInternalCall();
            return NULL;
        }
        op = _PyObject_GC_New(ptr[PyObject](addressof(PySeqIter_Type)));
        if not op {
            return NULL;
        }
        seqiter_of(op).view(1)[0].it_index = 0;
        seqiter_of(op).view(1)[0].it_seq = Py_NewRef(seq);
        object_gc_track(op);
        return op;
    }
}

def iter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    jacpy_release(seqiter_of(op).view(1)[0].it_seq);
    PyObject_GC_Del(op);
}

def iter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(seqiter_of(op).view(1)[0].it_seq, visitor, arg);
}

def iter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    it = seqiter_of(op);
    seq = it.view(1)[0].it_seq;
    if not seq {
        return NULL;
    }
    if it.view(1)[0].it_index == i64.MAX {
        PyErr_SetString(PyExc_OverflowError, "iter index too large");
        return NULL;
    }
    result = PySequence_GetItem(seq, it.view(1)[0].it_index);
    if result {
        it.view(1)[0].it_index += 1;
        return result;
    }
    if PyErr_ExceptionMatches(PyExc_IndexError) != 0
        or PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
        PyErr_Clear();
        it.view(1)[0].it_seq = NULL;
        jacpy_release(seq);
    }
    return NULL;
}

def iter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    it = seqiter_of(op);
    seq = it.view(1)[0].it_seq;
    if seq {
        if _PyObject_HasLen(seq) == 0 {
            return Py_NewRef(Py_NotImplemented);
        }
        seqsize = PySequence_Size(seq);
        if seqsize == -1 {
            return NULL;
        }
        remaining = seqsize - it.view(1)[0].it_index;
        if remaining >= 0 {
            return PyLong_FromSsize_t(remaining);
        }
    }
    return PyLong_FromLong(0);
}

def iter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    # _PyEval_GetBuiltin can invoke arbitrary code, so the call must come
    # before the iterator's fields are read. see issue #101765
    iterator = eval_builtin("iter");
    it = seqiter_of(op);
    if it.view(1)[0].it_seq {
        return Py_BuildValue(
            "N(O)n", iterator, it.view(1)[0].it_seq, it.view(1)[0].it_index
        );
    }
    return Py_BuildValue("N(())", iterator);
}

def iter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    it = seqiter_of(op);
    if it.view(1)[0].it_seq {
        it.view(1)[0].it_index = index if index >= 0 else i64(0);
    }
    return Py_NewRef(Py_None);
}

# ---------------------------------------------------------- callable iterator
def calliter_of(op: ptr[PyObject]) -> ptr[calliterobject] {
    return ptr[calliterobject](op);
}

import from c {
    def PyCallIter_New(
        function: ptr[PyObject], sentinel: ptr[PyObject]
    ) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyCallIter_Type)));
        if not op {
            return NULL;
        }
        calliter_of(op).view(1)[0].it_callable = Py_NewRef(function);
        calliter_of(op).view(1)[0].it_sentinel = Py_NewRef(sentinel);
        object_gc_track(op);
        return op;
    }
}

def calliter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    jacpy_release(calliter_of(op).view(1)[0].it_callable);
    jacpy_release(calliter_of(op).view(1)[0].it_sentinel);
    PyObject_GC_Del(op);
}

def calliter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(calliter_of(op).view(1)[0].it_callable, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(calliter_of(op).view(1)[0].it_sentinel, visitor, arg);
}

"""Py_CLEAR of both fields: the iterator is exhausted."""
def calliter_exhaust(it: ptr[calliterobject]) {
    function = it.view(1)[0].it_callable;
    it.view(1)[0].it_callable = NULL;
    jacpy_release(function);
    sentinel = it.view(1)[0].it_sentinel;
    it.view(1)[0].it_sentinel = NULL;
    jacpy_release(sentinel);
}

def calliter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    it = calliter_of(op);
    if not it.view(1)[0].it_callable {
        return NULL;
    }
    result = PyObject_CallNoArgs(it.view(1)[0].it_callable);
    if result and it.view(1)[0].it_sentinel {
        ok = PyObject_RichCompareBool(it.view(1)[0].it_sentinel, result, Py_EQ);
        if ok == 0 {
            return result;  # Common case, fast path
        }
        if ok > 0 {
            calliter_exhaust(it);
        }
    } elif PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
        PyErr_Clear();
        calliter_exhaust(it);
    }
    jacpy_release(result);
    return NULL;
}

def calliter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    # _PyEval_GetBuiltin can invoke arbitrary code, so the call must come
    # before the iterator's fields are read. see issue #101765
    iterator = eval_builtin("iter");
    it = calliter_of(op);
    if it.view(1)[0].it_callable and it.view(1)[0].it_sentinel {
        return Py_BuildValue(
            "N(OO)", iterator, it.view(1)[0].it_callable, it.view(1)[0].it_sentinel
        );
    }
    return Py_BuildValue("N(())", iterator);
}

# ---------------------------------------------------------- anext awaitable
def anext_of(op: ptr[PyObject]) -> ptr[anextawaitableobject] {
    return ptr[anextawaitableobject](op);
}

def anextawaitable_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    jacpy_release(anext_of(op).view(1)[0].wrapped);
    jacpy_release(anext_of(op).view(1)[0].default_value);
    PyObject_GC_Del(op);
}

def anextawaitable_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(anext_of(op).view(1)[0].wrapped, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(anext_of(op).view(1)[0].default_value, visitor, arg);
}

def anextawaitable_getiter(op: ptr[PyObject]) -> ptr[PyObject] {
    awaitable = _PyCoro_GetAwaitableIter(anext_of(op).view(1)[0].wrapped);
    if not awaitable {
        return NULL;
    }
    if int(object_type(awaitable).view(1)[0].tp_iternext) == 0 {
        # _PyCoro_GetAwaitableIter returns a Coroutine, a Generator,
        # or an iterator. Of these, only coroutines lack tp_iternext.
        new_awaitable = object_type(awaitable).view(1)[0].tp_as_async.view(1)[
            0
        ].am_await(
            awaitable
        );
        jacpy_release(awaitable);
        if not new_awaitable {
            return NULL;
        }
        awaitable = new_awaitable;
        if PyIter_Check(awaitable) == 0 {
            PyErr_SetString(PyExc_TypeError, "__await__ returned a non-iterable");
            jacpy_release(awaitable);
            return NULL;
        }
    }
    return awaitable;
}

def anextawaitable_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    # `await anext(a)` for an object with an async __anext__ calls
    # a.__anext__().__await__().__next__(); for an async generator,
    # gen.__anext__().__next__() is enough.
    awaitable = anextawaitable_getiter(op);
    if not awaitable {
        return NULL;
    }
    result = object_type(awaitable).view(1)[0].tp_iternext(awaitable);
    jacpy_release(awaitable);
    if result {
        return result;
    }
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0 {
        PyErr_Clear();
        _PyGen_SetStopIterationValue(anext_of(op).view(1)[0].default_value);
    }
    return NULL;
}

def anextawaitable_proxy(
    op: ptr[PyObject], meth: str, arg: ptr[PyObject]
) -> ptr[PyObject] {
    awaitable = anextawaitable_getiter(op);
    if not awaitable {
        return NULL;
    }
    # When specified, 'arg' may be a tuple (if coming from a METH_VARARGS
    # method) or a single object (if coming from a METH_O method).
    result = PyObject_CallMethod(awaitable, meth, ptr[u8]())
        if not arg
        else PyObject_CallMethod(awaitable, meth, "O", arg);
    jacpy_release(awaitable);
    if result {
        return result;
    }
    if PyErr_ExceptionMatches(PyExc_StopAsyncIteration) != 0 {
        # The anext awaitable is only used by anext() when a default value is
        # provided, so StopAsyncIteration becomes StopIteration(default), as
        # if it was the return value of the __anext__() coroutine.
        PyErr_Clear();
        _PyGen_SetStopIterationValue(anext_of(op).view(1)[0].default_value);
    }
    return NULL;
}

def anextawaitable_send(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return anextawaitable_proxy(op, "send", arg);
}

def anextawaitable_throw(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return anextawaitable_proxy(op, "throw", args);
}

def anextawaitable_close(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return anextawaitable_proxy(op, "close", NULL);
}

import from c {
    def PyAnextAwaitable_New(
        awaitable: ptr[PyObject], default_value: ptr[PyObject]
    ) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(_PyAnextAwaitable_Type)));
        if not op {
            return NULL;
        }
        anext_of(op).view(1)[0].wrapped = Py_NewRef(awaitable);
        anext_of(op).view(1)[0].default_value = Py_NewRef(default_value);
        object_gc_track(op);
        return op;
    }
}
