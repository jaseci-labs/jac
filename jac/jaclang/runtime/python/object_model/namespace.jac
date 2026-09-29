"""The simple namespace type: Objects/namespaceobject.c in native Jac.

`_PyNamespace_Type` (types.SimpleNamespace) is C data Jac defines under its C
name, and `_PyNamespace_New` a C function under its name, so sys.implementation
and the C API use them unchanged. The object layout, `_PyNamespaceObject`,
comes from layouts.jac. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_UnpackTuple,
    PyArg_ValidateKeywordArguments,
    PyDict_GetItemRef,
    PyDict_Keys,
    PyDict_New,
    PyDict_Type,
    PyDict_Update,
    PyErr_Format,
    PyErr_Occurred,
    PyExc_TypeError,
    PyIter_Next,
    PyList_Append,
    PyList_New,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_GC_Del,
    PyObject_GC_UnTrack,
    PyObject_GenericGetAttr,
    PyObject_GenericSetAttr,
    PyObject_GetIter,
    PyObject_RichCompare,
    PyTuple_New,
    PyTuple_Pack,
    PyType_GenericAlloc,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_Join,
    Py_NewRef,
    Py_NotImplemented,
    Py_ReprEnter,
    Py_ReprLeave,
    _PyArg_NoPositional,
    _PyType_Name,
    jacpy_is_exact_dict,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_size
}
import from jaclang.runtime.python.layouts {
    METH_KEYWORDS,
    METH_NOARGS,
    METH_VARARGS,
    PyTypeObject,
    PyVarObject,
    Py_READONLY,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _PyNamespaceObject,
    _PyNamespaceObject_NS_DICT,
    _PyNamespaceObject_SIZE,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_T_OBJECT,
    _object
}
import from jaclang.runtime.python.object_model.header {
    PyType_Type,
    object_is_type,
    object_type,
    object_type_check
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv namespace_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__dict__"),
                 type_=_Py_T_OBJECT,
                 offset=_PyNamespaceObject_NS_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         namespace_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(namespace_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__replace__"),
                 ml_meth=ptr(namespace_replace),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__replace__($self, /, **changes)\n--\n\n"
                     "Return a copy of the namespace object with new values for the specified attributes."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _PyNamespace_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("types.SimpleNamespace"),
             tp_basicsize=_PyNamespaceObject_SIZE,
             tp_dealloc=namespace_dealloc,
             tp_repr=namespace_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_setattro=PyObject_GenericSetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "SimpleNamespace(mapping_or_iterable=(), /, **kwargs)\n--\n\n"
                 "A simple attribute-based namespace."
             ),
             tp_traverse=namespace_traverse,
             tp_clear=namespace_clear,
             tp_richcompare=namespace_richcompare,
             tp_methods=addressof(namespace_methods),
             tp_members=addressof(namespace_members),
             tp_dictoffset=_PyNamespaceObject_NS_DICT,
             tp_init=namespace_init,
             tp_alloc=PyType_GenericAlloc,
             tp_new=namespace_new,
             tp_free=PyObject_GC_Del
         );
}

"""The namespace layout behind a handle."""
def namespace_of(op: ptr[PyObject]) -> ptr[_PyNamespaceObject] {
    return ptr[_PyNamespaceObject](op);
}

"""The namespace's attribute dict (borrowed)."""
def namespace_dict(op: ptr[PyObject]) -> ptr[PyObject] {
    return namespace_of(op).view(1)[0].ns_dict;
}

"""_PyNamespace_Check."""
def namespace_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(_PyNamespace_Type));
}

# Methods

def namespace_new(
    _type: ptr[PyTypeObject], _args: ptr[PyObject], _kwds: ptr[PyObject]
) -> ptr[PyObject] {
    op = _type.view(1)[0].tp_alloc(_type, 0);
    if op {
        namespace_of(op).view(1)[0].ns_dict = PyDict_New();
        if not namespace_dict(op) {
            jacpy_release(op);
            return NULL;
        }
    }
    return op;
}

def namespace_init(op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    arg = NULL;
    if PyArg_UnpackTuple(
        args, _PyType_Name(ptr[PyObject](object_type(op))), 0, 1, &mut arg
    )
        == 0 {
        return i32(-1);
    }
    if arg {
        dict = NULL;
        if jacpy_is_exact_dict(arg) != 0 {
            dict = Py_NewRef(arg);
        } else {
            dict = PyObject_CallOneArg(ptr[PyObject](addressof(PyDict_Type)), arg);
            if not dict {
                return i32(-1);
            }
        }
        failed = PyArg_ValidateKeywordArguments(dict) == 0
            or PyDict_Update(namespace_dict(op), dict) < 0;
        jacpy_release(dict);
        if failed {
            return i32(-1);
        }
    }
    if not kwds {
        return i32(0);
    }
    if PyArg_ValidateKeywordArguments(kwds) == 0 {
        return i32(-1);
    }
    return PyDict_Update(namespace_dict(op), kwds);
}

def namespace_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    namespace_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def namespace_repr(ns: ptr[PyObject]) -> ptr[PyObject] {
    name = ptr[u8]("namespace")
        if object_is_type(ns, addressof(_PyNamespace_Type))
        else object_type(ns).view(1)[0].tp_name;
    i = Py_ReprEnter(ns);
    if i != 0 {
        return PyUnicode_FromFormat("%s(...)", name) if i > 0 else NULL;
    }
    repr = NULL;
    pairs = PyList_New(0);
    d = NULL;
    keys = NULL;
    keys_iter = NULL;
    if pairs {
        d = Py_NewRef(namespace_dict(ns));
        keys = PyDict_Keys(d);
    }
    if keys {
        keys_iter = PyObject_GetIter(keys);
    }
    if keys_iter {
        failed = False;
        key = PyIter_Next(keys_iter);
        while key {
            if jacpy_is_unicode(key) != 0 and jacpy_unicode_size(key) > 0 {
                value = NULL;
                has_key = PyDict_GetItemRef(d, key, &mut value);
                if has_key == 1 {
                    item = PyUnicode_FromFormat("%U=%R", key, value);
                    jacpy_release(value);
                    if not item {
                        failed = True;
                    } else {
                        failed = PyList_Append(pairs, item) != 0;
                        jacpy_release(item);
                    }
                } elif has_key < 0 {
                    failed = True;
                }
            }
            jacpy_release(key);
            if failed {
                break;
            }
            key = PyIter_Next(keys_iter);
        }
        if not failed and not PyErr_Occurred() {
            separator = PyUnicode_FromString(", ");
            if separator {
                pairsrepr = PyUnicode_Join(separator, pairs);
                jacpy_release(separator);
                if pairsrepr {
                    repr = PyUnicode_FromFormat("%s(%S)", name, pairsrepr);
                    jacpy_release(pairsrepr);
                }
            }
        }
    }
    jacpy_release(pairs);
    jacpy_release(d);
    jacpy_release(keys);
    jacpy_release(keys_iter);
    Py_ReprLeave(ns);
    return repr;
}

def namespace_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(namespace_dict(op), visitor, arg);
}

def namespace_clear(op: ptr[PyObject]) -> i32 {
    old = namespace_dict(op);
    namespace_of(op).view(1)[0].ns_dict = NULL;
    jacpy_release(old);
    return i32(0);
}

def namespace_richcompare(
    left: ptr[PyObject], right: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if namespace_check(left) and namespace_check(right) {
        return PyObject_RichCompare(namespace_dict(left), namespace_dict(right), op);
    }
    return Py_NewRef(Py_NotImplemented);
}

def namespace_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    args = PyTuple_New(0);
    if not args {
        return NULL;
    }
    result = PyTuple_Pack(3, object_type(op), args, namespace_dict(op));
    jacpy_release(args);
    return result;
}

def namespace_replace(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if args and _PyArg_NoPositional("__replace__", args) == 0 {
        return NULL;
    }
    result = PyObject_CallNoArgs(ptr[PyObject](object_type(op)));
    if not result {
        return NULL;
    }
    if not namespace_check(result) {
        PyErr_Format(
            PyExc_TypeError,
            "expect %N type, but %T() returned '%T' object",
            addressof(_PyNamespace_Type),
            op,
            result
        );
        jacpy_release(result);
        return NULL;
    }
    if PyDict_Update(namespace_dict(result), namespace_dict(op)) < 0 {
        jacpy_release(result);
        return NULL;
    }
    if kwargs and PyDict_Update(namespace_dict(result), kwargs) < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

import from c {
    def _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject] {
        ns = namespace_new(addressof(_PyNamespace_Type), NULL, NULL);
        if not ns {
            return NULL;
        }
        if not kwds {
            return ns;
        }
        if PyDict_Update(namespace_dict(ns), kwds) != 0 {
            jacpy_release(ns);
            return NULL;
        }
        return ns;
    }
}
