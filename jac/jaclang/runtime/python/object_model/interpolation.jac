"""The t-string Interpolation type: Objects/interpolationobject.c in native Jac.

`_PyInterpolation_Type` (string.templatelib.Interpolation) is C data Jac
defines under its C name, and `_PyInterpolation_Build` (which the evaluator's
BUILD_INTERPOLATION calls), `_PyInterpolation_GetValueRef` and
`_PyInterpolation_InitTypes` are C functions under theirs. `__new__` parses
its arguments as Objects/clinic/interpolationobject.c.h does. The object
layout, `interpolationobject`, comes from layouts.jac. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_SetItemString,
    PyErr_Format,
    PyErr_SetString,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyInterpreterState,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyType_GenericAlloc,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_FromFormat,
    PyUnicode_FromOrdinal,
    Py_BuildValue,
    Py_GetConstantBorrowed,
    Py_NewRef,
    Py_None,
    _PyArg_BadArgument,
    _PyObject_GC_New,
    _PyType_GetDict,
    _PyType_Name,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    FVC_ASCII,
    FVC_REPR,
    FVC_STR,
    METH_CLASS,
    METH_NOARGS,
    METH_O,
    PyStatus,
    PyTypeObject,
    PyVarObject,
    Py_CONSTANT_EMPTY_STR,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_T_OBJECT_EX,
    _PyStatus_TYPE_ERROR,
    _PyStatus_TYPE_OK,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object,
    interpolationobject,
    interpolationobject_CONVERSION,
    interpolationobject_EXPRESSION,
    interpolationobject_FORMAT_SPEC,
    interpolationobject_SIZE,
    interpolationobject_VALUE
}
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    PARSE_KEYWORDS,
    invoke
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv interpolation_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("value"),
                 type_=Py_T_OBJECT_EX,
                 offset=interpolationobject_VALUE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Value")
             ),
             PyMemberDef(
                 name=ptr[u8]("expression"),
                 type_=Py_T_OBJECT_EX,
                 offset=interpolationobject_EXPRESSION,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Expression")
             ),
             PyMemberDef(
                 name=ptr[u8]("conversion"),
                 type_=Py_T_OBJECT_EX,
                 offset=interpolationobject_CONVERSION,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Conversion")
             ),
             PyMemberDef(
                 name=ptr[u8]("format_spec"),
                 type_=Py_T_OBJECT_EX,
                 offset=interpolationobject_FORMAT_SPEC,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Format specifier")
             ),
             PyMemberDef()
         ],
         interpolation_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(interpolation_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__() -> (cls, state)")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "Interpolations are generic over the types of their values"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _PyInterpolation_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("string.templatelib.Interpolation"),
             tp_doc=ptr[u8]("Interpolation object"),
             tp_basicsize=interpolationobject_SIZE,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_new=interpolation_new,
             tp_alloc=PyType_GenericAlloc,
             tp_dealloc=interpolation_dealloc,
             tp_clear=interpolation_clear,
             tp_free=PyObject_GC_Del,
             tp_repr=interpolation_repr,
             tp_members=addressof(interpolation_members),
             tp_methods=addressof(interpolation_methods),
             tp_traverse=interpolation_traverse
         );
}

glob:priv interpolation_new_signature = CallSignature(
         "Interpolation",
         ["value", "expression", "conversion", "format_spec"],
         1,
         4,
         0,
         parser=PARSE_KEYWORDS
     );

def interpolation_of(op: ptr[PyObject]) -> ptr[interpolationobject] {
    return ptr[interpolationobject](op);
}

"""_PyInterpolation_CheckExact."""
def interpolation_check_exact(op: ptr[PyObject]) -> bool {
    return object_type(op) == addressof(_PyInterpolation_Type);
}

# Interpolation(value, expression="", conversion=None, format_spec=""), as
# Argument Clinic parses it.
def interpolation_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(
        interpolation_new_signature,
        args,
        kwargs,
        interpolation_new_bound,
        ptr[PyObject](_type)
    );
}

def interpolation_new_bound(args: BoundArguments) -> ptr[PyObject] {
    value = args.values[0];
    expression = args.values[1];
    conversion = args.values[2];
    format_spec = args.values[3];
    if not expression {
        expression = Py_GetConstantBorrowed(Py_CONSTANT_EMPTY_STR);
    } elif jacpy_is_unicode(expression) == 0 {
        _PyArg_BadArgument("Interpolation", "argument 'expression'", "str", expression);
        return NULL;
    }
    if not conversion {
        conversion = Py_None;
    } elif not conversion_converter(conversion) {
        return NULL;
    }
    if not format_spec {
        format_spec = Py_GetConstantBorrowed(Py_CONSTANT_EMPTY_STR);
    } elif jacpy_is_unicode(format_spec) == 0 {
        _PyArg_BadArgument(
            "Interpolation", "argument 'format_spec'", "str", format_spec
        );
        return NULL;
    }
    return interpolation_new_impl(
        ptr[PyTypeObject](args.context), value, expression, conversion, format_spec
    );
}

# _conversion_converter: None, or one of the strings "s", "a" and "r".
def conversion_converter(arg: ptr[PyObject]) -> bool {
    if arg == Py_None {
        return True;
    }
    if jacpy_is_unicode(arg) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "Interpolation() argument 'conversion' must be str, not %T",
            arg
        );
        return False;
    }
    length = i64(0);
    text = PyUnicode_AsUTF8AndSize(arg, &mut length);
    code = text.view(1)[0] if text and length == 1 else u8(0);
    if length != 1 or not (code == 97 or code == 114 or code == 115) {
        PyErr_SetString(
            PyExc_ValueError,
            "Interpolation() argument 'conversion' must be one of 's', 'a' or 'r'"
        );
        return False;
    }
    return True;
}

def interpolation_new_impl(
    _type: ptr[PyTypeObject],
    value: ptr[PyObject],
    expression: ptr[PyObject],
    conversion: ptr[PyObject],
    format_spec: ptr[PyObject]
) -> ptr[PyObject] {
    op = _PyObject_GC_New(ptr[PyObject](_type));
    if not op {
        return NULL;
    }
    item = interpolation_of(op);
    item.view(1)[0].value = Py_NewRef(value);
    item.view(1)[0].expression = Py_NewRef(expression);
    item.view(1)[0].conversion = Py_NewRef(conversion);
    item.view(1)[0].format_spec = Py_NewRef(format_spec);
    PyObject_GC_Track(op);
    return op;
}

def interpolation_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    object_type(op).view(1)[0].tp_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def interpolation_clear(op: ptr[PyObject]) -> i32 {
    item = interpolation_of(op);
    value = item.view(1)[0].value;
    item.view(1)[0].value = NULL;
    jacpy_release(value);
    expression = item.view(1)[0].expression;
    item.view(1)[0].expression = NULL;
    jacpy_release(expression);
    conversion = item.view(1)[0].conversion;
    item.view(1)[0].conversion = NULL;
    jacpy_release(conversion);
    format_spec = item.view(1)[0].format_spec;
    item.view(1)[0].format_spec = NULL;
    jacpy_release(format_spec);
    return i32(0);
}

def interpolation_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    item = interpolation_of(op);
    status = visit_reference(item.view(1)[0].value, visitor, arg);
    if status == 0 {
        status = visit_reference(item.view(1)[0].expression, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(item.view(1)[0].conversion, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(item.view(1)[0].format_spec, visitor, arg);
    }
    return status;
}

def interpolation_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    item = interpolation_of(op);
    return PyUnicode_FromFormat(
        "%s(%R, %R, %R, %R)",
        _PyType_Name(ptr[PyObject](object_type(op))),
        item.view(1)[0].value,
        item.view(1)[0].expression,
        item.view(1)[0].conversion,
        item.view(1)[0].format_spec
    );
}

def interpolation_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    item = interpolation_of(op);
    return Py_BuildValue(
        "(O(OOOO))",
        object_type(op),
        item.view(1)[0].value,
        item.view(1)[0].expression,
        item.view(1)[0].conversion,
        item.view(1)[0].format_spec
    );
}

import from c {
    def _PyInterpolation_InitTypes(_interp: ptr[PyInterpreterState]) -> PyStatus {
        tuple = Py_BuildValue(
            "(ssss)", "value", "expression", "conversion", "format_spec"
        );
        if tuple {
            dict = _PyType_GetDict(ptr[PyObject](addressof(_PyInterpolation_Type)));
            if dict {
                status = PyDict_SetItemString(dict, "__match_args__", tuple);
                jacpy_release(tuple);
                if status >= 0 {
                    return PyStatus(
                        _type=_PyStatus_TYPE_OK,
                        func=ptr[u8](),
                        err_msg=ptr[u8](),
                        exitcode=i32(0)
                    );
                }
            } else {
                jacpy_release(tuple);
            }
        }
        return PyStatus(
            _type=_PyStatus_TYPE_ERROR,
            func=ptr[u8]("_PyInterpolation_InitTypes"),
            err_msg=ptr[u8]("Can't initialize interpolation types"),
            exitcode=i32(0)
        );
    }  def _PyInterpolation_Build(
        value: ptr[PyObject],
        text: ptr[PyObject],
        conversion: i32,
        format_spec: ptr[PyObject]
    ) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(_PyInterpolation_Type)));
        if not op {
            return NULL;
        }
        item = interpolation_of(op);
        item.view(1)[0].value = Py_NewRef(value);
        item.view(1)[0].expression = Py_NewRef(text);
        item.view(1)[0].format_spec = Py_NewRef(format_spec);
        item.view(1)[0].conversion = NULL;
        if conversion == 0 {
            item.view(1)[0].conversion = Py_None;
        } elif conversion == FVC_ASCII {
            item.view(1)[0].conversion = PyUnicode_FromOrdinal(i32(97));
        } elif conversion == FVC_REPR {
            item.view(1)[0].conversion = PyUnicode_FromOrdinal(i32(114));
        } elif conversion == FVC_STR {
            item.view(1)[0].conversion = PyUnicode_FromOrdinal(i32(115));
        } else {
            PyErr_SetString(
                PyExc_SystemError,
                "Interpolation() argument 'conversion' must be one of 's', 'a' or 'r'"
            );
            jacpy_release(op);
            return NULL;
        }
        PyObject_GC_Track(op);
        return op;
    }  def _PyInterpolation_GetValueRef(op: ptr[PyObject]) -> ptr[PyObject] {
        return Py_NewRef(interpolation_of(op).view(1)[0].value);
    }
}
