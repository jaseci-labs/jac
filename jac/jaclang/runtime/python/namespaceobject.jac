# Objects/namespaceobject.c ported to native Jac.
#
# types.SimpleNamespace with the C ABI: _PyNamespace_Type is a `glob:pub`
# static type object over the shared 53-field layout; the methods and
# members tables are record structs with the exact bytes of the C
# PyMethodDef[3] / PyMemberDef[2] arrays (static array-of-struct
# initializers are not an initializer form yet — same idiom as the cell
# getset table).
#
# Layout facts pinned from CPython 3.14.6: sizeof(_PyNamespaceObject) = 24,
# offsetof(ns_dict) = 16 (tp_dictoffset); Py_TPFLAGS_DEFAULT|HAVE_GC|
# BASETYPE = 0 | (1<<14) | (1<<10) = 17408; METH_NOARGS = 0x0004,
# METH_VARARGS|METH_KEYWORDS = 0x0003; _Py_T_OBJECT = 6, Py_READONLY = 1.
# PyMethodDef.ml_meth is declared with the wide (self, args, kwargs) shape:
# the METH_NOARGS entry never reads the third slot, which the C cast also
# guarantees.
#
# The repr loop reads values with PyDict_GetItemWithError (borrowed ref,
# NULL + error set on failure) instead of PyDict_GetItemRef's PyObject **
# out-param, which has no native Jac shape yet.
#
# C residue: the varargs formatters (jacpy_namespace_* below) and the
# too-many-args TypeError; same residue rules as cellobject.jac.


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

    # PyObject head only: enough to read ob_type of any object.
    obj PyObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject]();
    }

    # PyObject head plus PyASCIIObject.length (offset 16): enough for
    # PyUnicode_GET_LENGTH on compact strings, which is what dict keys are.
    obj PyASCIIObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            length: i64 = 0,
            hash: i64 = 0,
            state: u32 = 0,
            wstr: ptr = ptr();
    }

    # PyMemberDef: {name, type, offset, flags, doc} — 32 bytes with padding.
    obj PyMemberDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            type: i32 = 0,
            offset: i64 = 0,
            flags: i32 = 0,
            doc: ptr[u8] = ptr[u8]();
    }

    obj _PyNamespace_Members {
        has e0: PyMemberDef_Layout = PyMemberDef_Layout(),
            e1: PyMemberDef_Layout = PyMemberDef_Layout();
    }

    # PyMethodDef: {name, ml_meth, ml_flags, ml_doc} — 32 bytes with padding.
    obj PyMethodDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }

    obj _PyNamespace_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    # _PyNamespaceObject: PyObject head + ns_dict.
    obj _PyNamespaceObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            ns_dict: ptr[PyObject] = ptr[PyObject]();
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyDict_Type: PyTypeObject_Layout;
    glob PyUnicode_Type: PyTypeObject_Layout;
    glob PyExc_TypeError: ptr[PyObject];
    # Py_NotImplemented is a macro over this exported struct.
    glob _Py_NotImplementedStruct: PyObject_Layout;

    # Py_VISIT: `visit` is a C function pointer, not a Jac Callable.
    def jacpy_visit(visitf: ptr, o: ptr[PyObject], arg: ptr) -> i32;
    def PyType_IsSubtype(a: ptr[PyObject], b: ptr[PyObject]) -> i32;
    def PyType_GenericAlloc(tp: ptr[PyTypeObject_Layout], nitems: i64) -> ptr[PyObject];
    def PyObject_GC_UnTrack(o: ptr[PyObject]) -> None;
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_GenericSetAttr(o: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]) -> i32;
    def PyObject_GC_Del(o: ptr[PyObject]) -> None;
    def PyObject_RichCompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];
    def PyObject_CallOneArg(fn: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_CallNoArgs(fn: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_GetIter(o: ptr[PyObject]) -> ptr[PyObject];
    def PyIter_Next(o: ptr[PyObject]) -> ptr[PyObject];
    def PyDict_New() -> ptr[PyObject];
    def PyDict_Update(mp: ptr[PyObject], other: ptr[PyObject]) -> i32;
    def PyDict_Keys(mp: ptr[PyObject]) -> ptr[PyObject];
    def PyDict_GetItemWithError(mp: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];
    def PyList_New(len: i64) -> ptr[PyObject];
    def PyList_Append(l: ptr[PyObject], item: ptr[PyObject]) -> i32;
    def PyTuple_New(len: i64) -> ptr[PyObject];
    def PyTuple_Size(p: ptr[PyObject]) -> i64;
    def PyTuple_GetItem(p: ptr[PyObject], index: i64) -> ptr[PyObject];
    def PyUnicode_FromString(s: ptr[u8]) -> ptr[PyObject];
    def PyUnicode_Join(sep: ptr[PyObject], seq: ptr[PyObject]) -> ptr[PyObject];
    def Py_ReprEnter(o: ptr[PyObject]) -> i32;
    def Py_ReprLeave(o: ptr[PyObject]) -> None;
    def PyErr_Occurred() -> ptr[PyObject];
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyArg_ValidateKeywordArguments(kw: ptr[PyObject]) -> i32;
    def _PyArg_NoPositional(fname: ptr[u8], args: ptr[PyObject]) -> i32;
    def _PyType_Name(tp: ptr[PyObject]) -> ptr[u8];
    def jacpy_is_tuple(handle: ptr[PyObject]) -> i64;
    def jacpy_namespace_too_many(name: ptr[u8], nargs: i64) -> None;
    def jacpy_namespace_pair(key: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_namespace_repr_closed(name: ptr[u8], pairs: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_namespace_repr_selfref(name: ptr[u8]) -> ptr[PyObject];
    def jacpy_namespace_reduce_pack(tp: ptr[PyObject], args: ptr[PyObject], dict: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_namespace_replace_type_error(ns_type: ptr[PyObject], self: ptr[PyObject], result: ptr[PyObject]) -> None;
    def jacpy_exception_type(kind: ptr[u8]) -> ptr[PyObject];
}

def ob_type_of(o: ptr[PyObject]) -> ptr[PyObject] {
    h = ptr[PyObject_Layout](o);
    return h.ob_type;
}

def namespace_is_ns_exact(op: ptr[PyObject]) -> i32 {
    head = ptr[_PyNamespaceObject_Layout](op);
    nt: ptr[PyObject] = _PyNamespace_Type;
    if head.ob_type == nt {
        return 1;
    }
    return 0;
}

def namespace_is_ns_sub(op: ptr[PyObject]) -> i32 {
    head = ptr[_PyNamespaceObject_Layout](op);
    if PyType_IsSubtype(head.ob_type, _PyNamespace_Type) {
        return 1;
    }
    return 0;
}

# Methods

def namespace_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    self: ptr[PyObject] = type_.tp_alloc(type_, 0);
    if self != ptr[PyObject]() {
        ns = ptr[_PyNamespaceObject_Layout](self);
        ns.ns_dict = PyDict_New();
        if ns.ns_dict == ptr[PyObject]() {
            py_decref(self);
            return ptr[PyObject]();
        }
    }
    return self;
}

def namespace_init(op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    ns = ptr[_PyNamespaceObject_Layout](op);
    f: ptr[PyObject] = ptr[PyObject]();
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return -1;
    }
    nargs = PyTuple_Size(args);
    if nargs > 1 {
        jacpy_namespace_too_many(_PyType_Name(ns.ob_type), nargs);
        return -1;
    }
    if nargs == 1 {
        f = PyTuple_GetItem(args, 0);
        if not f {
            return -1;
        }
    }
    if f != ptr[PyObject]() {
        dt: ptr[PyObject] = PyDict_Type;
        # PyDict_CheckExact(f)
        if ob_type_of(f) == dt {
            d = f;
            py_incref(d);
        } else {
            d = PyObject_CallOneArg(dt, f);
            if d == ptr[PyObject]() {
                return -1;
            }
        }
        if PyArg_ValidateKeywordArguments(d) == 0 or PyDict_Update(ns.ns_dict, d) < 0 {
            py_decref(d);
            return -1;
        }
        py_decref(d);
    }
    if kwds == ptr[PyObject]() {
        return 0;
    }
    if not PyArg_ValidateKeywordArguments(kwds) {
        return -1;
    }
    return PyDict_Update(ns.ns_dict, kwds);
}

def namespace_dealloc(op: ptr[PyObject]) -> None {
    ns = ptr[_PyNamespaceObject_Layout](op);
    PyObject_GC_UnTrack(op);
    # Py_CLEAR(ns->ns_dict)
    tmp = ns.ns_dict;
    ns.ns_dict = ptr[PyObject]();
    if tmp != ptr[PyObject]() {
        py_decref(tmp);
    }
    # Py_TYPE(ns)->tp_free(ns)
    ty = ptr[PyTypeObject_Layout](ns.ob_type);
    ty.tp_free(op);
}

def namespace_repr(ns: ptr[PyObject]) -> ptr[PyObject] {
    head = ptr[_PyNamespaceObject_Layout](ns);
    name: ptr[u8] = "namespace";
    if not namespace_is_ns_exact(ns) {
        ty = ptr[PyTypeObject_Layout](head.ob_type);
        name = ty.tp_name;
    }

    i = Py_ReprEnter(ns);
    if i != 0 {
        Py_ReprLeave(ns);
        if i > 0 {
            return jacpy_namespace_repr_selfref(name);
        }
        return ptr[PyObject]();
    }

    pairs = PyList_New(0);
    if pairs == ptr[PyObject]() {
        Py_ReprLeave(ns);
        return ptr[PyObject]();
    }

    d = head.ns_dict;
    py_incref(d);

    keys = PyDict_Keys(d);
    if keys == ptr[PyObject]() {
        py_decref(d);
        py_decref(pairs);
        Py_ReprLeave(ns);
        return ptr[PyObject]();
    }

    keys_iter = PyObject_GetIter(keys);
    if keys_iter == ptr[PyObject]() {
        py_decref(keys);
        py_decref(d);
        py_decref(pairs);
        Py_ReprLeave(ns);
        return ptr[PyObject]();
    }

    loop_error: i32 = 0;
    key = PyIter_Next(keys_iter);
    while key != ptr[PyObject]() {
        if PyType_IsSubtype(ob_type_of(key), PyUnicode_Type) {
            u = ptr[PyASCIIObject_Layout](key);
            if u.length > 0 {
                value = PyDict_GetItemWithError(d, key);
                if value != ptr[PyObject]() {
                    py_incref(value);
                    item = jacpy_namespace_pair(key, value);
                    py_decref(value);
                    if item == ptr[PyObject]() {
                        loop_error = 1;
                    } else {
                        loop_error = PyList_Append(pairs, item);
                        py_decref(item);
                    }
                } elif PyErr_Occurred() != ptr[PyObject]() {
                    loop_error = 1;
                }
            }
        }
        py_decref(key);
        if loop_error != 0 {
            break;
        }
        key = PyIter_Next(keys_iter);
    }

    rval = ptr[PyObject]();
    if loop_error == 0 and PyErr_Occurred() == ptr[PyObject]() {
        separator = PyUnicode_FromString(", ");
        if separator != ptr[PyObject]() {
            pairsrepr = PyUnicode_Join(separator, pairs);
            py_decref(separator);
            if pairsrepr != ptr[PyObject]() {
                rval = jacpy_namespace_repr_closed(name, pairsrepr);
                py_decref(pairsrepr);
            }
        }
    }

    py_decref(keys_iter);
    py_decref(keys);
    py_decref(d);
    py_decref(pairs);
    Py_ReprLeave(ns);
    return rval;
}

def namespace_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    ns = ptr[_PyNamespaceObject_Layout](op);
    if ns.ns_dict != ptr[PyObject]() {
        vret = jacpy_visit(visitf, ns.ns_dict, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

def namespace_clear(op: ptr[PyObject]) -> i32 {
    ns = ptr[_PyNamespaceObject_Layout](op);
    tmp = ns.ns_dict;
    ns.ns_dict = ptr[PyObject]();
    if tmp != ptr[PyObject]() {
        py_decref(tmp);
    }
    return 0;
}

def namespace_richcompare(self: ptr[PyObject], other: ptr[PyObject], op: i32) -> ptr[PyObject] {
    notimpl_obj: ptr[PyObject] = _Py_NotImplementedStruct;
    if namespace_is_ns_sub(self) and namespace_is_ns_sub(other) {
        s = ptr[_PyNamespaceObject_Layout](self);
        o = ptr[_PyNamespaceObject_Layout](other);
        return PyObject_RichCompare(s.ns_dict, o.ns_dict, op);
    }
    py_incref(notimpl_obj);
    return notimpl_obj;
}

def namespace_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    ns = ptr[_PyNamespaceObject_Layout](op);
    args = PyTuple_New(0);
    if args == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    t: ptr[PyObject] = ns.ob_type;
    result = jacpy_namespace_reduce_pack(t, args, ns.ns_dict);
    py_decref(args);
    return result;
}

def namespace_replace(self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]) -> ptr[PyObject] {
    if args != ptr[PyObject]() and not _PyArg_NoPositional("__replace__", args) {
        return ptr[PyObject]();
    }
    s = ptr[_PyNamespaceObject_Layout](self);
    t: ptr[PyObject] = s.ob_type;
    result = PyObject_CallNoArgs(t);
    if result == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if not namespace_is_ns_sub(result) {
        ns_type: ptr[PyObject] = _PyNamespace_Type;
        jacpy_namespace_replace_type_error(ns_type, self, result);
        py_decref(result);
        return ptr[PyObject]();
    }
    r = ptr[_PyNamespaceObject_Layout](result);
    if PyDict_Update(r.ns_dict, s.ns_dict) < 0 {
        py_decref(result);
        return ptr[PyObject]();
    }
    if kwargs != ptr[PyObject]() {
        if PyDict_Update(r.ns_dict, kwargs) < 0 {
            py_decref(result);
            return ptr[PyObject]();
        }
    }
    return result;
}

glob namespace_methods: _PyNamespace_Methods = _PyNamespace_Methods(
    e0=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=namespace_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling"
    ),
    e1=PyMethodDef_Layout(
        name="__replace__",
        ml_meth=namespace_replace,
        ml_flags=3,
        ml_doc=(
            "__replace__($self, /, **changes)\n"
            "--\n"
            "\n"
            "Return a copy of the namespace object with new values for the specified attributes."
        )
    )
    # e2 is the {NULL, NULL} sentinel.
);

glob namespace_members: _PyNamespace_Members = _PyNamespace_Members(
    e0=PyMemberDef_Layout(name="__dict__", type=6, offset=16, flags=1)
    # e1 is the NULL sentinel.
);

glob:pub _PyNamespace_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,          # _Py_STATIC_IMMORTAL_INITIAL_REFCNT
    ob_type=PyType_Type,                 # PyVarObject_HEAD_INIT(&PyType_Type, 0)
    ob_size=0,
    tp_name="types.SimpleNamespace",
    tp_basicsize=24,                     # sizeof(_PyNamespaceObject)
    tp_itemsize=0,
    tp_dealloc=namespace_dealloc,
    tp_repr=namespace_repr,
    tp_getattro=PyObject_GenericGetAttr,
    tp_setattro=PyObject_GenericSetAttr,
    tp_flags=17408,                      # Py_TPFLAGS_DEFAULT|HAVE_GC|BASETYPE
    tp_doc=(
        "SimpleNamespace(mapping_or_iterable=(), /, **kwargs)\n"
        "--\n"
        "\n"
        "A simple attribute-based namespace."
    ),
    tp_traverse=namespace_traverse,
    tp_clear=namespace_clear,
    tp_richcompare=namespace_richcompare,
    tp_methods=namespace_methods,
    tp_members=namespace_members,
    tp_dictoffset=16,                    # offsetof(_PyNamespaceObject, ns_dict)
    tp_init=namespace_init,
    tp_alloc=PyType_GenericAlloc,
    tp_new=namespace_new,
    tp_free=PyObject_GC_Del
);

def:pub _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject] {
    null = ptr[PyObject]();
    ns = namespace_new(_PyNamespace_Type, null, null);
    if ns == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if kwds == ptr[PyObject]() {
        return ns;
    }
    n = ptr[_PyNamespaceObject_Layout](ns);
    if PyDict_Update(n.ns_dict, kwds) != 0 {
        py_decref(ns);
        return ptr[PyObject]();
    }
    return ns;
}
