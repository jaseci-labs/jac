"""The enumerate and reversed types: Objects/enumobject.c in native Jac.

`PyEnum_Type` and `PyReversed_Type` are C data Jac defines under their C
names, so the builtins module and C code use them unchanged. Their `__new__`
argument parsing is Objects/clinic/enumobject.c.h's, and their vectorcall
entry points parse positional and keyword arguments by hand as the C file
does. The object layouts come from layouts.jac. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_ParseTupleAndKeywords,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_IndexError,
    PyExc_StopIteration,
    PyExc_TypeError,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyMethodDef,
    PyNumber_Add,
    PyNumber_Index,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_GC_Del,
    PyObject_GC_UnTrack,
    PyObject_GenericGetAttr,
    PyObject_GetIter,
    PyObject_SelfIter,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    PyTuple_New,
    PyTuple_Pack,
    PyType_GenericAlloc,
    PyUnicode_InternFromString,
    PyVectorcall_NARGS,
    Py_BuildValue,
    Py_GenericAlias,
    Py_IncRef,
    Py_NewRef,
    Py_None,
    _PyArg_CheckPositional,
    _PyArg_NoKeywords,
    _PyArg_NoKwnames,
    _PyObject_LookupSpecial,
    _PyUnicode_EqualToASCIIString,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_NOARGS,
    METH_O,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object,
    enumobject,
    enumobject_SIZE,
    reversedobject,
    reversedobject_SIZE
}
import from jaclang.runtime.python.object_model.header {
    PyType_Type,
    object_refcount,
    object_size,
    object_type,
    tuple_get_item,
    tuple_recycle,
    tuple_set_item
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv enum_keywords: list[ptr[u8]] = [
             ptr[u8]("iterable"),
             ptr[u8]("start"),
             ptr[u8]()
         ],
         enum_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(enum_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "'enumerate' objects are generic over the type of their values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         reversediter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(reversed_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(reversed_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(reversed_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyEnum_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("enumerate"),
             tp_basicsize=enumobject_SIZE,
             tp_dealloc=enum_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "enumerate(iterable, start=0)\n--\n\n"
                 "Return an enumerate object.\n\n"
                 "  iterable\n"
                 "    an object supporting iteration\n\n"
                 "The enumerate object yields pairs containing a count (from start, which\n"
                 "defaults to zero) and a value yielded by the iterable argument.\n\n"
                 "enumerate is useful for obtaining an indexed list:\n"
                 "    (0, seq[0]), (1, seq[1]), (2, seq[2]), ..."
             ),
             tp_traverse=enum_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=enum_next,
             tp_methods=addressof(enum_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=enum_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=enumerate_vectorcall
         ),
         PyReversed_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("reversed"),
             tp_basicsize=reversedobject_SIZE,
             tp_dealloc=reversed_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "reversed(sequence, /)\n--\n\n"
                 "Return a reverse iterator over the values of the given sequence."
             ),
             tp_traverse=reversed_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=reversed_next,
             tp_methods=addressof(reversediter_methods),
             tp_alloc=PyType_GenericAlloc,
             tp_new=reversed_new,
             tp_free=PyObject_GC_Del,
             tp_vectorcall=reversed_vectorcall
         );
}

# ---------------------------------------------------------------- enumerate
def enum_of(op: ptr[PyObject]) -> ptr[enumobject] {
    return ptr[enumobject](op);
}

# enumerate.__new__(iterable, start=0), as Argument Clinic parses it.
def enum_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    iterable = NULL;
    start = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        "O|O:enumerate",
        ptr(addressof(enum_keywords)),
        &mut iterable,
        &mut start
    )
        == 0 {
        return NULL;
    }
    return enum_new_impl(_type, iterable, start);
}

def enum_new_impl(
    _type: ptr[PyTypeObject], iterable: ptr[PyObject], start: ptr[PyObject]
) -> ptr[PyObject] {
    op = _type.view(1)[0].tp_alloc(_type, 0);
    if not op {
        return NULL;
    }
    en = enum_of(op);
    if start {
        start = PyNumber_Index(start);
        if not start {
            jacpy_release(op);
            return NULL;
        }
        en.view(1)[0].en_index = PyLong_AsSsize_t(start);
        if en.view(1)[0].en_index == -1 and PyErr_Occurred() {
            PyErr_Clear();
            en.view(1)[0].en_index = i64.MAX;
            en.view(1)[0].en_longindex = start;
        } else {
            en.view(1)[0].en_longindex = NULL;
            jacpy_release(start);
        }
    } else {
        en.view(1)[0].en_index = 0;
        en.view(1)[0].en_longindex = NULL;
    }
    en.view(1)[0].en_sit = PyObject_GetIter(iterable);
    if not en.view(1)[0].en_sit {
        jacpy_release(op);
        return NULL;
    }
    en.view(1)[0].en_result = PyTuple_Pack(2, Py_None, Py_None);
    if not en.view(1)[0].en_result {
        jacpy_release(op);
        return NULL;
    }
    # borrowed reference to the immortal one
    en.view(1)[0].one = PyLong_FromLong(1);
    return op;
}

def check_keyword(kwnames: ptr[PyObject], index: i64, name: str) -> bool {
    kw = tuple_get_item(kwnames, index);
    if _PyUnicode_EqualToASCIIString(kw, name) == 0 {
        PyErr_Format(
            PyExc_TypeError, "'%S' is an invalid keyword argument for enumerate()", kw
        );
        return False;
    }
    return True;
}

def enumerate_vectorcall(
    _type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tp = ptr[PyTypeObject](_type);
    nargs = PyVectorcall_NARGS(nargsf);
    nkwargs = i64(0);
    if kwnames {
        nkwargs = object_size(kwnames);
    }
    # Manually implement enumerate(iterable, start=...)
    if nargs + nkwargs == 2 {
        if nkwargs == 1 {
            if not check_keyword(kwnames, 0, "start") {
                return NULL;
            }
        } elif nkwargs == 2 {
            kw0 = tuple_get_item(kwnames, 0);
            if _PyUnicode_EqualToASCIIString(kw0, "start") != 0 {
                if not check_keyword(kwnames, 1, "iterable") {
                    return NULL;
                }
                return enum_new_impl(tp, (args + 1).view(1)[0], args.view(1)[0]);
            }
            if not check_keyword(kwnames, 0, "iterable")
                or not check_keyword(kwnames, 1, "start") {
                return NULL;
            }
        }
        return enum_new_impl(tp, args.view(1)[0], (args + 1).view(1)[0]);
    }
    if nargs + nkwargs == 1 {
        if nkwargs == 1 and not check_keyword(kwnames, 0, "iterable") {
            return NULL;
        }
        return enum_new_impl(tp, args.view(1)[0], NULL);
    }
    if nargs == 0 {
        PyErr_SetString(
            PyExc_TypeError, "enumerate() missing required argument 'iterable'"
        );
        return NULL;
    }
    PyErr_Format(
        PyExc_TypeError,
        "enumerate() takes at most 2 arguments (%zd given)",
        nargs + nkwargs
    );
    return NULL;
}

def enum_dealloc(op: ptr[PyObject]) {
    en = enum_of(op);
    PyObject_GC_UnTrack(op);
    jacpy_release(en.view(1)[0].en_sit);
    jacpy_release(en.view(1)[0].en_result);
    jacpy_release(en.view(1)[0].en_longindex);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def enum_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    en = enum_of(op);
    status = visit_reference(en.view(1)[0].en_sit, visitor, arg);
    if status == 0 {
        status = visit_reference(en.view(1)[0].en_result, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(en.view(1)[0].en_longindex, visitor, arg);
    }
    return status;
}

# Advance en_longindex; return the next index to be used, or NULL on error.
def increment_longindex(en: ptr[enumobject]) -> ptr[PyObject] {
    next_index = en.view(1)[0].en_longindex;
    if not next_index {
        next_index = PyLong_FromSsize_t(i64.MAX);
        if not next_index {
            return NULL;
        }
    }
    stepped_up = PyNumber_Add(next_index, en.view(1)[0].one);
    if not stepped_up {
        return NULL;
    }
    en.view(1)[0].en_longindex = stepped_up;
    return next_index;
}

# The (index, item) pair, reusing the result tuple when nothing else holds it;
# both are stolen.
def enum_pair(
    en: ptr[enumobject], next_index: ptr[PyObject], next_item: ptr[PyObject]
) -> ptr[PyObject] {
    result = en.view(1)[0].en_result;
    if object_refcount(result) == 1 {
        Py_IncRef(result);
        old_index = tuple_get_item(result, 0);
        old_item = tuple_get_item(result, 1);
        tuple_set_item(result, 0, next_index);
        tuple_set_item(result, 1, next_item);
        jacpy_release(old_index);
        jacpy_release(old_item);
        tuple_recycle(result);
        return result;
    }
    result = PyTuple_New(2);
    if not result {
        jacpy_release(next_index);
        jacpy_release(next_item);
        return NULL;
    }
    tuple_set_item(result, 0, next_index);
    tuple_set_item(result, 1, next_item);
    return result;
}

def enum_next_long(en: ptr[enumobject], next_item: ptr[PyObject]) -> ptr[PyObject] {
    next_index = increment_longindex(en);
    if not next_index {
        jacpy_release(next_item);
        return NULL;
    }
    return enum_pair(en, next_index, next_item);
}

def enum_next(op: ptr[PyObject]) -> ptr[PyObject] {
    en = enum_of(op);
    it = en.view(1)[0].en_sit;
    next_item = object_type(it).view(1)[0].tp_iternext(it);
    if not next_item {
        return NULL;
    }
    en_index = en.view(1)[0].en_index;
    if en_index == i64.MAX {
        return enum_next_long(en, next_item);
    }
    next_index = PyLong_FromSsize_t(en_index);
    if not next_index {
        jacpy_release(next_item);
        return NULL;
    }
    en.view(1)[0].en_index = en_index + 1;
    return enum_pair(en, next_index, next_item);
}

def enum_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    en = enum_of(op);
    if en.view(1)[0].en_longindex {
        return Py_BuildValue(
            "O(OO)", object_type(op), en.view(1)[0].en_sit, en.view(1)[0].en_longindex
        );
    }
    return Py_BuildValue(
        "O(On)", object_type(op), en.view(1)[0].en_sit, en.view(1)[0].en_index
    );
}

# ---------------------------------------------------------------- reversed
def reversed_of(op: ptr[PyObject]) -> ptr[reversedobject] {
    return ptr[reversedobject](op);
}

def reversed_new_impl(_type: ptr[PyTypeObject], seq: ptr[PyObject]) -> ptr[PyObject] {
    name = PyUnicode_InternFromString("__reversed__");
    if not name {
        return NULL;
    }
    reversed_meth = _PyObject_LookupSpecial(seq, name);
    jacpy_release(name);
    if reversed_meth == Py_None {
        jacpy_release(reversed_meth);
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not reversible",
            object_type(seq).view(1)[0].tp_name
        );
        return NULL;
    }
    if reversed_meth {
        result = PyObject_CallNoArgs(reversed_meth);
        jacpy_release(reversed_meth);
        return result;
    } elif PyErr_Occurred() {
        return NULL;
    }
    if PySequence_Check(seq) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%.200s' object is not reversible",
            object_type(seq).view(1)[0].tp_name
        );
        return NULL;
    }
    n = PySequence_Size(seq);
    if n == -1 {
        return NULL;
    }
    op = _type.view(1)[0].tp_alloc(_type, 0);
    if not op {
        return NULL;
    }
    reversed_of(op).view(1)[0].index = n - 1;
    reversed_of(op).view(1)[0].seq = Py_NewRef(seq);
    return op;
}

# reversed.__new__(sequence, /), as Argument Clinic parses it.
def reversed_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base_tp = addressof(PyReversed_Type);
    if (
        _type == base_tp
        or int(_type.view(1)[0].tp_init) == int(base_tp.view(1)[0].tp_init)
    )
        and kwargs
        and _PyArg_NoKeywords("reversed", kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs != 1 and _PyArg_CheckPositional("reversed", nargs, 1, 1) == 0 {
        return NULL;
    }
    return reversed_new_impl(_type, tuple_get_item(args, 0));
}

def reversed_vectorcall(
    _type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames and _PyArg_NoKwnames("reversed", kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs != 1 and _PyArg_CheckPositional("reversed", nargs, 1, 1) == 0 {
        return NULL;
    }
    return reversed_new_impl(ptr[PyTypeObject](_type), args.view(1)[0]);
}

def reversed_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    jacpy_release(reversed_of(op).view(1)[0].seq);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def reversed_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(reversed_of(op).view(1)[0].seq, visitor, arg);
}

def reversed_next(op: ptr[PyObject]) -> ptr[PyObject] {
    ro = reversed_of(op);
    index = ro.view(1)[0].index;
    if index >= 0 {
        item = PySequence_GetItem(ro.view(1)[0].seq, index);
        if item {
            ro.view(1)[0].index = index - 1;
            return item;
        }
        if PyErr_ExceptionMatches(PyExc_IndexError) != 0
            or PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
            PyErr_Clear();
        }
    }
    ro.view(1)[0].index = -1;
    seq = ro.view(1)[0].seq;
    ro.view(1)[0].seq = NULL;
    jacpy_release(seq);
    return NULL;
}

def reversed_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    ro = reversed_of(op);
    index = ro.view(1)[0].index;
    if index == -1 {
        return PyLong_FromLong(0);
    }
    seqsize = PySequence_Size(ro.view(1)[0].seq);
    if seqsize == -1 {
        return NULL;
    }
    position = index + 1;
    return PyLong_FromSsize_t(0 if seqsize < position else position);
}

def reversed_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    ro = reversed_of(op);
    if ro.view(1)[0].index != -1 {
        return Py_BuildValue(
            "O(O)n", object_type(op), ro.view(1)[0].seq, ro.view(1)[0].index
        );
    }
    return Py_BuildValue("O(())", object_type(op));
}

def reversed_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    ro = reversed_of(op);
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    # if the iterator is exhausted we do not set the state; this is for
    # backwards compatibility reasons (gh-120971).
    if ro.view(1)[0].index != -1 {
        n = PySequence_Size(ro.view(1)[0].seq);
        if n < 0 {
            return NULL;
        }
        if index < -1 {
            index = -1;
        } elif index > n - 1 {
            index = n - 1;
        }
        ro.view(1)[0].index = index;
    }
    return Py_NewRef(Py_None);
}
