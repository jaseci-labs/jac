import from c {
    glob PyType_Type: PyTypeObject; def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def Py_HashPointer(p: ptr) -> i64;  def _PyType_GetTextSignatureFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8], flags: i32
    ) -> ptr[PyObject];  def _PyType_GetDocFromInternalDoc(
        name: ptr[u8], internal_doc: ptr[u8]
    ) -> ptr[PyObject];  def _Py_CheckFunctionResult(
        tstate: ptr, callable: ptr[PyObject], result: ptr[PyObject], where: ptr[u8]
    ) -> ptr[PyObject];  def _PyObject_FunctionStr(
        op: ptr[PyObject]
    ) -> ptr[PyObject];  def Py_EnterRecursiveCall(where: str) -> i32;  obj MethodCall {
        has one: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            fast: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0,
            fast_keywords:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            method:
                Callable[
                    [
                        ptr[PyObject],
                        ptr[PyTypeObject],
                        ptr[ptr[PyObject]],
                        i64,
                        ptr[PyObject]
                    ],
                    ptr[PyObject]
                ] = 0,
            keywords:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0;
    }  glob:priv call_slot: MethodCall = MethodCall(),
         meth_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(meth_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         meth_getsets: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__doc__"), get=meth_get__doc__),
             PyGetSetDef(name=ptr[u8]("__name__"), get=meth_get__name__),
             PyGetSetDef(name=ptr[u8]("__qualname__"), get=meth_get__qualname__),
             PyGetSetDef(name=ptr[u8]("__self__"), get=meth_get__self__),
             PyGetSetDef(
                 name=ptr[u8]("__text_signature__"), get=meth_get__text_signature__
             ),
             PyGetSetDef()
         ],
         meth_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__module__"),
                 type_=_Py_T_OBJECT,
                 offset=PyCFunctionObject_MODULE,
                 flags=0
             ),
             PyMemberDef()
         ]; glob PyCFunction_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("builtin_function_or_method"),
             tp_basicsize=PyCFunctionObject_SIZE,
             tp_dealloc=meth_dealloc,
             tp_vectorcall_offset=PyCFunctionObject_VECTORCALL,
             tp_repr=meth_repr,
             tp_hash=meth_hash,
             tp_call=cfunction_call,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_HAVE_VECTORCALL,
             tp_traverse=meth_traverse,
             tp_richcompare=meth_richcompare,
             tp_weaklistoffset=PyCFunctionObject_WEAKREFLIST,
             tp_methods=addressof(meth_methods),
             tp_members=addressof(meth_members),
             tp_getset=addressof(meth_getsets)
         ),
         PyCMethod_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("builtin_method"),
             tp_basicsize=PyCMethodObject_SIZE,
             tp_base=addressof(PyCFunction_Type)
         );
}

def cfunction_of(op: ptr[PyObject]) -> ptr[PyCFunctionObject];

def method_def(op: ptr[PyObject]) -> ptr[PyMethodDef];

def cfunction_self(op: ptr[PyObject]) -> ptr[PyObject];

def cfunction_m_self(op: ptr[PyObject]) -> ptr[PyObject];

def cfunction_flags(op: ptr[PyObject]) -> i32;

def cfunction_class(op: ptr[PyObject]) -> ptr[PyTypeObject];

def cfunction_check(op: ptr[PyObject]) -> bool;

def module_check(op: ptr[PyObject]) -> bool;

def object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject];

glob:priv VECTORCALL_NONE: i64 = 0,
     VECTORCALL_FASTCALL: i64 = 1,
     VECTORCALL_FASTCALL_KEYWORDS: i64 = 2,
     VECTORCALL_NOARGS: i64 = 3,
     VECTORCALL_O: i64 = 4,
     VECTORCALL_METHOD: i64 = 5,
     VECTORCALL_BAD: i64 = -1;

def vectorcall_kind(flags: i32) -> i64;

import from c {
    def PyCFunction_New(ml: ptr[PyMethodDef], self: ptr[PyObject]) -> ptr[PyObject] {
        return PyCFunction_NewEx(ml, self, NULL);
    }  def PyCFunction_NewEx(
        ml: ptr[PyMethodDef], self: ptr[PyObject], module: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyCMethod_New(ml, self, module, ptr[PyTypeObject]());
    }  def PyCMethod_New(
        ml: ptr[PyMethodDef],
        self: ptr[PyObject],
        module: ptr[PyObject],
        cls: ptr[PyTypeObject]
    ) -> ptr[PyObject] {
        flags = ml.view(1)[0].ml_flags;
        kind = vectorcall_kind(flags);
        if kind == VECTORCALL_BAD {
            PyErr_Format(
                PyExc_SystemError, "%s() method: bad call flags", ml.view(1)[0].ml_name
            );
            return NULL;
        }
        op = NULL;
        if (flags & METH_METHOD) != i32(0) {
            if not cls {
                PyErr_SetString(
                    PyExc_SystemError,
                    "attempting to create PyCMethod with a METH_METHOD flag but no class"
                );
                return NULL;
            }
            op = freelist_pop(_Py_freelists_PYCMETHODOBJECT);
            if not op {
                op = _PyObject_GC_New(ptr[PyObject](addressof(PyCMethod_Type)));
                if not op {
                    return NULL;
                }
            }
            ptr[PyCMethodObject](op).view(1)[0].mm_class = ptr[PyTypeObject](
                object_new_ref(ptr[PyObject](cls))
            );
        } else {
            if cls {
                PyErr_SetString(
                    PyExc_SystemError,
                    "attempting to create PyCFunction with class but no METH_METHOD flag"
                );
                return NULL;
            }
            op = freelist_pop(_Py_freelists_PYCFUNCTIONOBJECT);
            if not op {
                op = _PyObject_GC_New(ptr[PyObject](addressof(PyCFunction_Type)));
                if not op {
                    return NULL;
                }
            }
        }
        f = cfunction_of(op);
        f.view(1)[0].m_weakreflist = NULL;
        f.view(1)[0].m_ml = ml;
        f.view(1)[0].m_self = object_xnew_ref(self);
        f.view(1)[0].m_module = object_xnew_ref(module);
        f.view(1)[0].vectorcall = int(vectorcall_entry(kind));
        object_gc_track(op);
        return op;
    }  def PyCFunction_GetFunction(op: ptr[PyObject]) -> ptr {
        if not cfunction_check(op) {
            PyErr_BadInternalCall();
            return ptr();
        }
        return method_def(op).view(1)[0].ml_meth;
    }  def PyCFunction_GetSelf(op: ptr[PyObject]) -> ptr[PyObject] {
        if not cfunction_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return cfunction_self(op);
    }  def PyCFunction_GetFlags(op: ptr[PyObject]) -> i32 {
        if not cfunction_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        return cfunction_flags(op);
    }  def PyCMethod_GetClass(op: ptr[PyObject]) -> ptr[PyTypeObject] {
        if not cfunction_check(op) {
            PyErr_BadInternalCall();
            return ptr[PyTypeObject]();
        }
        return cfunction_class(op);
    }
}

def vectorcall_entry(kind: i64) -> ptr;

def meth_dealloc(op: ptr[PyObject]);

def meth_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def meth_get__text_signature__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def meth_get__doc__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def meth_get__name__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def meth_get__qualname__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def meth_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def meth_get__self__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def meth_repr(op: ptr[PyObject]) -> ptr[PyObject];

def meth_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];

def meth_hash(op: ptr[PyObject]) -> i64;

def unicode_from_cstring(text: ptr[u8]) -> ptr[PyObject];

def no_keywords(func: ptr[PyObject], kwnames: ptr[PyObject]) -> bool;

def enter_call(func: ptr[PyObject]) -> ptr;

def cfunction_vectorcall_FASTCALL(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def cfunction_vectorcall_FASTCALL_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def cfunction_vectorcall_FASTCALL_KEYWORDS_METHOD(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def cfunction_vectorcall_NOARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def cfunction_vectorcall_O(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def cfunction_call(
    func: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def dict_used(dict: ptr[PyObject]) -> i64;

impl cfunction_of(op: ptr[PyObject]) -> ptr[PyCFunctionObject] {
    return ptr[PyCFunctionObject](op);
}

impl method_def(op: ptr[PyObject]) -> ptr[PyMethodDef] {
    return cfunction_of(op).view(1)[0].m_ml;
}

impl cfunction_self(op: ptr[PyObject]) -> ptr[PyObject] {
    if (method_def(op).view(1)[0].ml_flags & METH_STATIC) != i32(0) {
        return NULL;
    }
    return cfunction_of(op).view(1)[0].m_self;
}

impl cfunction_m_self(op: ptr[PyObject]) -> ptr[PyObject] {
    return cfunction_of(op).view(1)[0].m_self;
}

impl cfunction_flags(op: ptr[PyObject]) -> i32 {
    return method_def(op).view(1)[0].ml_flags;
}

impl cfunction_class(op: ptr[PyObject]) -> ptr[PyTypeObject] {
    if (cfunction_flags(op) & METH_METHOD) != i32(0) {
        return ptr[PyCMethodObject](op).view(1)[0].mm_class;
    }
    return ptr[PyTypeObject]();
}

impl cfunction_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(PyCFunction_Type));
}

impl module_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyModule_Type)));
}

impl object_xnew_ref(op: ptr[PyObject]) -> ptr[PyObject] {
    if op {
        object_incref(op);
    }
    return op;
}

impl vectorcall_kind(flags: i32) -> i64 {
    convention = flags
        & (
            METH_VARARGS
            | METH_FASTCALL
            | METH_NOARGS
            | METH_O
            | METH_KEYWORDS
            | METH_METHOD
        );
    if convention == METH_VARARGS or convention == (METH_VARARGS | METH_KEYWORDS) {
        return VECTORCALL_NONE;
    }
    if convention == METH_FASTCALL {
        return VECTORCALL_FASTCALL;
    }
    if convention == (METH_FASTCALL | METH_KEYWORDS) {
        return VECTORCALL_FASTCALL_KEYWORDS;
    }
    if convention == METH_NOARGS {
        return VECTORCALL_NOARGS;
    }
    if convention == METH_O {
        return VECTORCALL_O;
    }
    if convention == (METH_METHOD | METH_FASTCALL | METH_KEYWORDS) {
        return VECTORCALL_METHOD;
    }
    return VECTORCALL_BAD;
}

impl vectorcall_entry(kind: i64) -> ptr {
    if kind == VECTORCALL_FASTCALL {
        return ptr(cfunction_vectorcall_FASTCALL);
    }
    if kind == VECTORCALL_FASTCALL_KEYWORDS {
        return ptr(cfunction_vectorcall_FASTCALL_KEYWORDS);
    }
    if kind == VECTORCALL_NOARGS {
        return ptr(cfunction_vectorcall_NOARGS);
    }
    if kind == VECTORCALL_O {
        return ptr(cfunction_vectorcall_O);
    }
    if kind == VECTORCALL_METHOD {
        return ptr(cfunction_vectorcall_FASTCALL_KEYWORDS_METHOD);
    }
    return ptr();
}

impl meth_dealloc(op: ptr[PyObject]) {
    f = cfunction_of(op);
    object_gc_untrack(op);
    if f.view(1)[0].m_weakreflist {
        PyObject_ClearWeakRefs(op);
    }

    flags = cfunction_flags(op);
    object_xdecref(ptr[PyObject](cfunction_class(op)));
    object_xdecref(f.view(1)[0].m_self);
    object_xdecref(f.view(1)[0].m_module);
    offset = _Py_freelists_PYCFUNCTIONOBJECT;
    limit = Py_pycfunctionobject_MAXFREELIST;
    if (flags & METH_METHOD) != i32(0) {
        offset = _Py_freelists_PYCMETHODOBJECT;
        limit = Py_pycmethodobject_MAXFREELIST;
    }
    if not freelist_push(offset, op, limit) {
        PyObject_GC_Del(ptr(op));
    }
}

impl meth_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    self = cfunction_m_self(op);
    name = method_def(op).view(1)[0].ml_name;
    if not self or module_check(self) {
        return unicode_from_cstring(name);
    }
    return Py_BuildValue("N(Os)", eval_builtin("getattr"), self, name);
}

impl meth_get__text_signature__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    ml = method_def(op);
    return _PyType_GetTextSignatureFromInternalDoc(
        ml.view(1)[0].ml_name, ml.view(1)[0].ml_doc, ml.view(1)[0].ml_flags
    );
}

impl meth_get__doc__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    ml = method_def(op);
    return _PyType_GetDocFromInternalDoc(ml.view(1)[0].ml_name, ml.view(1)[0].ml_doc);
}

impl meth_get__name__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return unicode_from_cstring(method_def(op).view(1)[0].ml_name);
}

impl meth_get__qualname__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    self = cfunction_m_self(op);
    name = method_def(op).view(1)[0].ml_name;
    if not self or module_check(self) {
        return unicode_from_cstring(name);
    }
    type = self
        if type_has_feature(object_type(self), Py_TPFLAGS_TYPE_SUBCLASS)
        else ptr[PyObject](object_type(self));
    type_qualname = PyObject_GetAttrString(type, ptr[u8]("__qualname__"));
    if not type_qualname {
        return NULL;
    }
    if not type_has_feature(object_type(type_qualname), Py_TPFLAGS_UNICODE_SUBCLASS) {
        PyErr_SetString(
            PyExc_TypeError, "<method>.__class__.__qualname__ is not a unicode object"
        );
        object_decref(type_qualname);
        return NULL;
    }
    res = PyUnicode_FromFormat("%S.%s", type_qualname, name);
    object_decref(type_qualname);
    return res;
}

impl meth_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](cfunction_class(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(cfunction_m_self(op), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(cfunction_of(op).view(1)[0].m_module, visitor, arg);
}

impl meth_get__self__(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    self = cfunction_self(op);
    return object_new_ref(self or Py_None);
}

impl meth_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    self = cfunction_m_self(op);
    name = method_def(op).view(1)[0].ml_name;
    if not self or module_check(self) {
        return PyUnicode_FromFormat("<built-in function %s>", name);
    }
    return PyUnicode_FromFormat(
        "<built-in method %s of %s object at %p>",
        name,
        object_type(self).view(1)[0].tp_name,
        self
    );
}

impl meth_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if (op != Py_EQ and op != Py_NE)
        or not cfunction_check(a)
        or not cfunction_check(b) {
        return object_new_ref(Py_NotImplemented);
    }
    eq = cfunction_m_self(a) == cfunction_m_self(b)
        and int(method_def(a).view(1)[0].ml_meth)
            == int(method_def(b).view(1)[0].ml_meth);
    if op == Py_EQ {
        return object_new_ref(py_true() if eq else py_false());
    }
    return object_new_ref(py_false() if eq else py_true());
}

impl meth_hash(op: ptr[PyObject]) -> i64 {
    x = PyObject_GenericHash(cfunction_m_self(op));
    y = Py_HashPointer(method_def(op).view(1)[0].ml_meth);
    x = x ^ y;
    if x == -1 {
        x = -2;
    }
    return x;
}

impl unicode_from_cstring(text: ptr[u8]) -> ptr[PyObject] {
    return PyUnicode_FromStringAndSize(text, i64(strlen(text)));
}

impl no_keywords(func: ptr[PyObject], kwnames: ptr[PyObject]) -> bool {
    if kwnames and object_size(kwnames) != 0 {
        funcstr = _PyObject_FunctionStr(func);
        if funcstr {
            PyErr_Format(PyExc_TypeError, "%U takes no keyword arguments", funcstr);
            object_decref(funcstr);
        }
        return False;
    }
    return True;
}

impl enter_call(func: ptr[PyObject]) -> ptr {
    if Py_EnterRecursiveCall(" while calling a Python object") != 0 {
        return ptr();
    }
    return method_def(func).view(1)[0].ml_meth;
}

impl cfunction_vectorcall_FASTCALL(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(func, kwnames) {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    meth = enter_call(func);
    if not meth {
        return NULL;
    }
    slot = addressof(call_slot);
    slot.view(1)[0].fast = int(meth);
    return slot.view(1)[0].fast(cfunction_self(func), args, nargs);
}

impl cfunction_vectorcall_FASTCALL_KEYWORDS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    meth = enter_call(func);
    if not meth {
        return NULL;
    }
    slot = addressof(call_slot);
    slot.view(1)[0].fast_keywords = int(meth);
    return slot.view(1)[0].fast_keywords(cfunction_self(func), args, nargs, kwnames);
}

impl cfunction_vectorcall_FASTCALL_KEYWORDS_METHOD(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    cls = cfunction_class(func);
    nargs = PyVectorcall_NARGS(nargsf);
    meth = enter_call(func);
    if not meth {
        return NULL;
    }
    slot = addressof(call_slot);
    slot.view(1)[0].method = int(meth);
    return slot.view(1)[0].method(cfunction_self(func), cls, args, nargs, kwnames);
}

impl cfunction_vectorcall_NOARGS(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(func, kwnames) {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs != 0 {
        funcstr = _PyObject_FunctionStr(func);
        if funcstr {
            PyErr_Format(
                PyExc_TypeError, "%U takes no arguments (%zd given)", funcstr, nargs
            );
            object_decref(funcstr);
        }
        return NULL;
    }
    meth = enter_call(func);
    if not meth {
        return NULL;
    }
    slot = addressof(call_slot);
    slot.view(1)[0].one = int(meth);
    return slot.view(1)[0].one(cfunction_self(func), NULL);
}

impl cfunction_vectorcall_O(
    func: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not no_keywords(func, kwnames) {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if nargs != 1 {
        funcstr = _PyObject_FunctionStr(func);
        if funcstr {
            PyErr_Format(
                PyExc_TypeError,
                "%U takes exactly one argument (%zd given)",
                funcstr,
                nargs
            );
            object_decref(funcstr);
        }
        return NULL;
    }
    meth = enter_call(func);
    if not meth {
        return NULL;
    }
    slot = addressof(call_slot);
    slot.view(1)[0].one = int(meth);
    return slot.view(1)[0].one(cfunction_self(func), args.view(1)[0]);
}

impl cfunction_call(
    func: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    flags = cfunction_flags(func);
    if (flags & METH_VARARGS) == i32(0) {
        return PyVectorcall_Call(func, args, kwargs);
    }
    meth = method_def(func).view(1)[0].ml_meth;
    self = cfunction_self(func);
    slot = addressof(call_slot);
    result = NULL;
    if (flags & METH_KEYWORDS) != i32(0) {
        slot.view(1)[0].keywords = int(meth);
        result = slot.view(1)[0].keywords(self, args, kwargs);
    } else {
        if kwargs and dict_used(kwargs) != 0 {
            PyErr_Format(
                PyExc_TypeError,
                "%.200s() takes no keyword arguments",
                method_def(func).view(1)[0].ml_name
            );
            return NULL;
        }
        slot.view(1)[0].one = int(meth);
        result = slot.view(1)[0].one(self, args);
    }
    return _Py_CheckFunctionResult(ptr(current_tstate()), func, result, ptr[u8]());
}

impl dict_used(dict: ptr[PyObject]) -> i64 {
    return ptr[i64](ptr[u8](dict) + PyDictObject_USED).view(1)[0];
}
