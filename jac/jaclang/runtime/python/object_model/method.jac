"""Bound methods and instance methods: Objects/classobject.c in native Jac.

`PyMethod_Type` (bound methods, instance.methodname) and
`PyInstanceMethod_Type` are C data Jac defines under their C names, and the
method C API (`PyMethod_New`, `PyMethod_Function`, `PyMethod_Self`,
`PyInstanceMethod_New`, `PyInstanceMethod_Function`) C functions under
theirs. `PyMethodObject` and `PyInstanceMethodObject` come from layouts.jac,
so the evaluator's bound-method specializations read them in place; method
objects are recycled through the interpreter's freelist as classobject.c
does. `__new__` parses its arguments as Objects/clinic/classobject.c.h does.
See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCallable_Check,
    PyErr_BadInternalCall,
    PyErr_SetString,
    PyExc_TypeError,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_Call,
    PyObject_ClearWeakRefs,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GenericHash,
    PyObject_GenericSetAttr,
    PyObject_GetAttr,
    PyObject_GetAttrString,
    PyObject_GetOptionalAttrString,
    PyObject_Hash,
    PyObject_RichCompareBool,
    PyThreadState_GetUnchecked,
    PyType_Ready,
    PyUnicode_FromFormat,
    PyVectorcall_Call,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyArg_CheckPositional,
    _PyArg_NoKeywords,
    _PyObject_GC_New,
    _PyObject_VectorcallPrepend,
    _PyType_LookupRef,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_NOARGS,
    PyGetSetDef,
    PyInstanceMethodObject,
    PyInstanceMethodObject_FUNC,
    PyInstanceMethodObject_SIZE,
    PyMethodObject,
    PyMethodObject_FUNC,
    PyMethodObject_SELF,
    PyMethodObject_SIZE,
    PyMethodObject_VECTORCALL,
    PyMethodObject_WEAKREFLIST,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_NE,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_HAVE_VECTORCALL,
    Py_pymethodobjects_MAXFREELIST,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_T_OBJECT,
    _Py_freelists_PYMETHODOBJECTS,
    _object
}
import from jaclang.runtime.python.object_model.header {
    PyType_Type,
    _Py_FalseStruct,
    _Py_TrueStruct,
    eval_builtin,
    freelist_pop,
    freelist_push,
    object_decref,
    object_is_type,
    object_new_ref,
    object_size,
    object_type,
    tuple_get_item
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv method_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(method_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__($self, /)\n--\n\n")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         method_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__func__"),
                 type_=_Py_T_OBJECT,
                 offset=PyMethodObject_FUNC,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the function (or other callable) implementing a method")
             ),
             PyMemberDef(
                 name=ptr[u8]("__self__"),
                 type_=_Py_T_OBJECT,
                 offset=PyMethodObject_SELF,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the instance to which a method is bound")
             ),
             PyMemberDef()
         ],
         method_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=method_get_doc),
             PyGetSetDef()
         ],
         instancemethod_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__func__"),
                 type_=_Py_T_OBJECT,
                 offset=PyInstanceMethodObject_FUNC,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the function (or other callable) implementing a method")
             ),
             PyMemberDef()
         ],
         instancemethod_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=instancemethod_get_doc),
             PyGetSetDef()
         ]; glob PyMethod_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("method"),
             tp_basicsize=PyMethodObject_SIZE,
             tp_dealloc=method_dealloc,
             tp_vectorcall_offset=PyMethodObject_VECTORCALL,
             tp_repr=method_repr,
             tp_hash=method_hash,
             tp_call=PyVectorcall_Call,
             tp_getattro=method_getattro,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_HAVE_VECTORCALL,
             tp_doc=ptr[u8](
                 "method(function, instance, /)\n--\n\nCreate a bound instance method object."
             ),
             tp_traverse=method_traverse,
             tp_richcompare=method_richcompare,
             tp_weaklistoffset=PyMethodObject_WEAKREFLIST,
             tp_methods=addressof(method_methods),
             tp_members=addressof(method_memberlist),
             tp_getset=addressof(method_getset),
             tp_descr_get=method_descr_get,
             tp_new=method_new
         ),
         PyInstanceMethod_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("instancemethod"),
             tp_basicsize=PyInstanceMethodObject_SIZE,
             tp_dealloc=instancemethod_dealloc,
             tp_repr=instancemethod_repr,
             tp_call=instancemethod_call,
             tp_getattro=instancemethod_getattro,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "instancemethod(function, /)\n--\n\nBind a function to a class."
             ),
             tp_traverse=instancemethod_traverse,
             tp_richcompare=instancemethod_richcompare,
             tp_members=addressof(instancemethod_memberlist),
             tp_getset=addressof(instancemethod_getset),
             tp_descr_get=instancemethod_descr_get,
             tp_new=instancemethod_new
         );
}

def py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

# ---------------------------------------------------------------- method
def method_of(op: ptr[PyObject]) -> ptr[PyMethodObject] {
    return ptr[PyMethodObject](op);
}

"""PyMethod_Check."""
def method_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyMethod_Type));
}

def method_vectorcall(
    method: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    m = method_of(method);
    return _PyObject_VectorcallPrepend(
        PyThreadState_GetUnchecked(),
        m.view(1)[0].im_func,
        m.view(1)[0].im_self,
        args,
        nargsf,
        kwnames
    );
}

import from c {
    def PyMethod_Function(im: ptr[PyObject]) -> ptr[PyObject] {
        if not method_check(im) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return method_of(im).view(1)[0].im_func;
    }  def PyMethod_Self(im: ptr[PyObject]) -> ptr[PyObject] {
        if not method_check(im) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return method_of(im).view(1)[0].im_self;
    }
    # Method objects are used for bound instance methods returned by
    # instancename.methodname. ClassName.methodname returns an ordinary
    # function.
    def PyMethod_New(func: ptr[PyObject], self_obj: ptr[PyObject]) -> ptr[PyObject] {
        if not self_obj {
            PyErr_BadInternalCall();
            return NULL;
        }
        op = freelist_pop(_Py_freelists_PYMETHODOBJECTS);
        if not op {
            op = _PyObject_GC_New(ptr[PyObject](addressof(PyMethod_Type)));
            if not op {
                return NULL;
            }
        }
        m = method_of(op);
        m.view(1)[0].im_weakreflist = NULL;
        m.view(1)[0].im_func = object_new_ref(func);
        m.view(1)[0].im_self = object_new_ref(self_obj);
        m.view(1)[0].vectorcall = method_vectorcall;
        PyObject_GC_Track(op);
        return op;
    }
}

def method_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    m = method_of(op);
    funcname = PyObject_GetAttrString(m.view(1)[0].im_func, "__name__");
    if not funcname {
        return NULL;
    }
    return Py_BuildValue(
        "N(ON)", eval_builtin("getattr"), m.view(1)[0].im_self, funcname
    );
}

# Method attributes nearly always override function attributes; the one
# exception is __doc__, whose default is for the class, not the instances.
def method_get_doc(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyObject_GetAttrString(method_of(op).view(1)[0].im_func, "__doc__");
}

# The attribute of the method type itself (a descriptor bound to `op`), or
# NULL with no error when the type has none.
def type_attribute(
    op: ptr[PyObject], name: ptr[PyObject]
) -> tuple[bool, ptr[PyObject]] {
    tp = object_type(op);
    if not tp.view(1)[0].tp_dict and PyType_Ready(ptr[PyObject](tp)) < 0 {
        return (True, NULL);
    }
    descr = _PyType_LookupRef(ptr[PyObject](tp), name);
    if not descr {
        return (False, NULL);
    }
    if int(object_type(descr).view(1)[0].tp_descr_get) == 0 {
        return (True, descr);
    }
    result = object_type(descr).view(1)[0].tp_descr_get(descr, op, ptr[PyObject](tp));
    jacpy_release(descr);
    return (True, result);
}

def method_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    (found, result) = type_attribute(op, name);
    if found {
        return result;
    }
    return PyObject_GetAttr(method_of(op).view(1)[0].im_func, name);
}

# method.__new__(function, instance, /), as Argument Clinic parses it.
def method_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base_tp = addressof(PyMethod_Type);
    if (
        _type == base_tp
        or int(_type.view(1)[0].tp_init) == int(base_tp.view(1)[0].tp_init)
    )
        and kwargs
        and _PyArg_NoKeywords("method", kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs != 2 and _PyArg_CheckPositional("method", nargs, 2, 2) == 0 {
        return NULL;
    }
    function = tuple_get_item(args, 0);
    instance = tuple_get_item(args, 1);
    if PyCallable_Check(function) == 0 {
        PyErr_SetString(PyExc_TypeError, "first argument must be callable");
        return NULL;
    }
    if not instance or instance == Py_None {
        PyErr_SetString(PyExc_TypeError, "instance must not be None");
        return NULL;
    }
    return PyMethod_New(function, instance);
}

def method_dealloc(op: ptr[PyObject]) {
    m = method_of(op);
    PyObject_GC_UnTrack(op);
    if m.view(1)[0].im_weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    object_decref(m.view(1)[0].im_func);
    object_decref(m.view(1)[0].im_self);
    if not freelist_push(
        _Py_freelists_PYMETHODOBJECTS, op, Py_pymethodobjects_MAXFREELIST
    ) {
        PyObject_GC_Del(op);
    }
}

def method_richcompare(
    op: ptr[PyObject], other: ptr[PyObject], cmp: i32
) -> ptr[PyObject] {
    if (cmp != Py_EQ and cmp != Py_NE)
        or not method_check(op)
        or not method_check(other) {
        return Py_NewRef(Py_NotImplemented);
    }
    a = method_of(op);
    b = method_of(other);
    eq = PyObject_RichCompareBool(a.view(1)[0].im_func, b.view(1)[0].im_func, Py_EQ);
    if eq == 1 {
        eq = i32(a.view(1)[0].im_self == b.view(1)[0].im_self);
    } elif eq < 0 {
        return NULL;
    }
    return py_bool((eq != 0) == (cmp == Py_EQ));
}

# `funcname` when it is a str (released otherwise), or NULL.
def str_or_none(funcname: ptr[PyObject]) -> ptr[PyObject] {
    if funcname and jacpy_is_unicode(funcname) == 0 {
        jacpy_release(funcname);
        return NULL;
    }
    return funcname;
}

def method_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    m = method_of(op);
    func = m.view(1)[0].im_func;
    funcname = NULL;
    if PyObject_GetOptionalAttrString(func, "__qualname__", &mut funcname) < 0 {
        return NULL;
    }
    if not funcname
        and PyObject_GetOptionalAttrString(func, "__name__", &mut funcname) < 0 {
        return NULL;
    }
    funcname = str_or_none(funcname);
    # XXX Shouldn't use repr()/%R here!
    result = PyUnicode_FromFormat(
        "<bound method %V of %R>", funcname, ptr[u8]("?"), m.view(1)[0].im_self
    );
    jacpy_release(funcname);
    return result;
}

def method_hash(op: ptr[PyObject]) -> i64 {
    m = method_of(op);
    x = PyObject_GenericHash(m.view(1)[0].im_self);
    y = PyObject_Hash(m.view(1)[0].im_func);
    if y == -1 {
        return -1;
    }
    x = x ^ y;
    if x == -1 {
        x = -2;
    }
    return x;
}

def method_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    m = method_of(op);
    status = visit_reference(m.view(1)[0].im_func, visitor, arg);
    if status == 0 {
        status = visit_reference(m.view(1)[0].im_self, visitor, arg);
    }
    return status;
}

def method_descr_get(
    meth: ptr[PyObject], _obj: ptr[PyObject], _cls: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(meth);
}

# ---------------------------------------------------------------- instance method
def instancemethod_of(op: ptr[PyObject]) -> ptr[PyInstanceMethodObject] {
    return ptr[PyInstanceMethodObject](op);
}

"""PyInstanceMethod_Check."""
def instancemethod_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyInstanceMethod_Type));
}

"""PyInstanceMethod_GET_FUNCTION (borrowed)."""
def instancemethod_function(op: ptr[PyObject]) -> ptr[PyObject] {
    return instancemethod_of(op).view(1)[0].func;
}

import from c {
    def PyInstanceMethod_New(func: ptr[PyObject]) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyInstanceMethod_Type)));
        if not op {
            return NULL;
        }
        instancemethod_of(op).view(1)[0].func = Py_NewRef(func);
        PyObject_GC_Track(op);
        return op;
    }  def PyInstanceMethod_Function(im: ptr[PyObject]) -> ptr[PyObject] {
        if not instancemethod_check(im) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return instancemethod_function(im);
    }
}

def instancemethod_get_doc(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyObject_GetAttrString(instancemethod_function(op), "__doc__");
}

def instancemethod_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    (found, result) = type_attribute(op, name);
    if found {
        return result;
    }
    return PyObject_GetAttr(instancemethod_function(op), name);
}

def instancemethod_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    jacpy_release(instancemethod_function(op));
    PyObject_GC_Del(op);
}

def instancemethod_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(instancemethod_function(op), visitor, arg);
}

def instancemethod_call(
    op: ptr[PyObject], arg: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    return PyObject_Call(instancemethod_function(op), arg, kw);
}

def instancemethod_descr_get(
    descr: ptr[PyObject], obj_arg: ptr[PyObject], _type: ptr[PyObject]
) -> ptr[PyObject] {
    func = instancemethod_function(descr);
    if not obj_arg {
        return Py_NewRef(func);
    }
    return PyMethod_New(func, obj_arg);
}

def instancemethod_richcompare(
    op: ptr[PyObject], other: ptr[PyObject], cmp: i32
) -> ptr[PyObject] {
    if (cmp != Py_EQ and cmp != Py_NE)
        or not instancemethod_check(op)
        or not instancemethod_check(other) {
        return Py_NewRef(Py_NotImplemented);
    }
    eq = PyObject_RichCompareBool(
        instancemethod_function(op), instancemethod_function(other), Py_EQ
    );
    if eq < 0 {
        return NULL;
    }
    return py_bool((eq != 0) == (cmp == Py_EQ));
}

def instancemethod_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    func = PyInstanceMethod_Function(op);
    if not func {
        PyErr_BadInternalCall();
        return NULL;
    }
    funcname = NULL;
    if PyObject_GetOptionalAttrString(func, "__name__", &mut funcname) < 0 {
        return NULL;
    }
    funcname = str_or_none(funcname);
    result = PyUnicode_FromFormat(
        "<instancemethod %V at %p>", funcname, ptr[u8]("?"), op
    );
    jacpy_release(funcname);
    return result;
}

# instancemethod.__new__(function, /), as Argument Clinic parses it.
def instancemethod_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    base_tp = addressof(PyInstanceMethod_Type);
    if (
        _type == base_tp
        or int(_type.view(1)[0].tp_init) == int(base_tp.view(1)[0].tp_init)
    )
        and kwargs
        and _PyArg_NoKeywords("instancemethod", kwargs) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs != 1 and _PyArg_CheckPositional("instancemethod", nargs, 1, 1) == 0 {
        return NULL;
    }
    function = tuple_get_item(args, 0);
    if PyCallable_Check(function) == 0 {
        PyErr_SetString(PyExc_TypeError, "first argument must be callable");
        return NULL;
    }
    return PyInstanceMethod_New(function);
}
