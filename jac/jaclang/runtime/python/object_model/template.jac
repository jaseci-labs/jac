"""The t-string Template type: Objects/templateobject.c in native Jac.

`_PyTemplate_Type` (string.templatelib.Template) and `_PyTemplateIter_Type`
are C data Jac defines under their C names, and `_PyTemplate_Build` (which
the evaluator's BUILD_TEMPLATE calls) and `_PyTemplate_Concat` are C
functions under theirs. The object layouts come from layouts.jac. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Format,
    PyErr_SetString,
    PyExc_TypeError,
    PyImport_ImportModule,
    PyIter_Next,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyObject_SelfIter,
    PySequence_Concat,
    PyTuple_New,
    PyType_GenericAlloc,
    PyUnicode_Concat,
    PyUnicode_FromFormat,
    Py_BuildValue,
    Py_GetConstantBorrowed,
    Py_NewRef,
    _PyObject_GC_New,
    _PyType_Name,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_size
}
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_NOARGS,
    METH_O,
    PyGetSetDef,
    PySequenceMethods,
    PyTypeObject,
    PyVarObject,
    Py_CONSTANT_EMPTY_STR,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_T_OBJECT_EX,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object,
    templateiterobject,
    templateiterobject_SIZE,
    templateobject,
    templateobject_INTERPOLATIONS,
    templateobject_SIZE,
    templateobject_STRINGS
}
import from jaclang.runtime.python.object_model.header {
    object_size,
    object_type,
    tuple_get_item,
    tuple_set_item
}
import from jaclang.runtime.python.object_model.interpolation {
    _PyInterpolation_GetValueRef,
    interpolation_check_exact
}
import from jaclang.runtime.python.object_model.genericalias { Py_GenericAlias }
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob _PyTemplateIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("string.templatelib.TemplateIter"),
             tp_doc=ptr[u8]("Template iterator object"),
             tp_basicsize=templateiterobject_SIZE,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_alloc=PyType_GenericAlloc,
             tp_dealloc=templateiter_dealloc,
             tp_clear=templateiter_clear,
             tp_free=PyObject_GC_Del,
             tp_traverse=templateiter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=templateiter_next
         ); glob:priv template_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("strings"),
                 type_=Py_T_OBJECT_EX,
                 offset=templateobject_STRINGS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Strings")
             ),
             PyMemberDef(
                 name=ptr[u8]("interpolations"),
                 type_=Py_T_OBJECT_EX,
                 offset=templateobject_INTERPOLATIONS,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Interpolations")
             ),
             PyMemberDef()
         ],
         template_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("values"),
                 get=template_values_get,
                 doc=ptr[u8]("Values of interpolations")
             ),
             PyGetSetDef()
         ],
         template_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_concat=_PyTemplate_Concat
         ),
         template_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(template_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(Py_GenericAlias),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]("Template supports [] for generic usage")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _PyTemplate_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("string.templatelib.Template"),
             tp_doc=ptr[u8]("Template object"),
             tp_basicsize=templateobject_SIZE,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_as_sequence=addressof(template_as_sequence),
             tp_new=template_new,
             tp_alloc=PyType_GenericAlloc,
             tp_dealloc=template_dealloc,
             tp_clear=template_clear,
             tp_free=PyObject_GC_Del,
             tp_repr=template_repr,
             tp_members=addressof(template_members),
             tp_methods=addressof(template_methods),
             tp_getset=addressof(template_getset),
             tp_iter=template_iter,
             tp_traverse=template_traverse
         );
}

# ---------------------------------------------------------------- iterator
def templateiter_of(op: ptr[PyObject]) -> ptr[templateiterobject] {
    return ptr[templateiterobject](op);
}

def templateiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = templateiter_of(op);
    item = NULL;
    if it.view(1)[0].from_strings != 0 {
        item = PyIter_Next(it.view(1)[0].stringsiter);
        it.view(1)[0].from_strings = 0;
        if not item {
            return NULL;
        }
        if jacpy_unicode_size(item) == 0 {
            empty = item;
            item = PyIter_Next(it.view(1)[0].interpolationsiter);
            jacpy_release(empty);
            it.view(1)[0].from_strings = 1;
        }
    } else {
        item = PyIter_Next(it.view(1)[0].interpolationsiter);
        it.view(1)[0].from_strings = 1;
    }
    return item;
}

def templateiter_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    object_type(op).view(1)[0].tp_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def templateiter_clear(op: ptr[PyObject]) -> i32 {
    it = templateiter_of(op);
    strings = it.view(1)[0].stringsiter;
    it.view(1)[0].stringsiter = NULL;
    jacpy_release(strings);
    interpolations = it.view(1)[0].interpolationsiter;
    it.view(1)[0].interpolationsiter = NULL;
    jacpy_release(interpolations);
    return i32(0);
}

def templateiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    it = templateiter_of(op);
    status = visit_reference(it.view(1)[0].stringsiter, visitor, arg);
    if status == 0 {
        status = visit_reference(it.view(1)[0].interpolationsiter, visitor, arg);
    }
    return status;
}

# ---------------------------------------------------------------- template
def template_of(op: ptr[PyObject]) -> ptr[templateobject] {
    return ptr[templateobject](op);
}

"""_PyTemplate_CheckExact."""
def template_check_exact(op: ptr[PyObject]) -> bool {
    return object_type(op) == addressof(_PyTemplate_Type);
}

"""The empty string (_Py_STR(empty)), immortal."""
def empty_string -> ptr[PyObject] {
    return Py_GetConstantBorrowed(Py_CONSTANT_EMPTY_STR);
}

def template_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds {
        PyErr_SetString(
            PyExc_TypeError, "Template.__new__ only accepts *args arguments"
        );
        return NULL;
    }
    argslen = object_size(args);
    stringslen = i64(0);
    interpolationslen = i64(0);
    last_was_str = False;
    for i in range(argslen) {
        item = tuple_get_item(args, i64(i));
        if jacpy_is_unicode(item) != 0 {
            if not last_was_str {
                stringslen += 1;
            }
            last_was_str = True;
        } elif interpolation_check_exact(item) {
            if not last_was_str {
                stringslen += 1;
            }
            interpolationslen += 1;
            last_was_str = False;
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "Template.__new__ *args need to be of type 'str' or 'Interpolation', got %T",
                item
            );
            return NULL;
        }
    }
    if not last_was_str {
        stringslen += 1;
    }
    strings = PyTuple_New(stringslen);
    if not strings {
        return NULL;
    }
    interpolations = PyTuple_New(interpolationslen);
    if not interpolations {
        jacpy_release(strings);
        return NULL;
    }
    last_was_str = False;
    stringsidx = i64(0);
    interpolationsidx = i64(0);
    for i in range(argslen) {
        item = tuple_get_item(args, i64(i));
        if jacpy_is_unicode(item) != 0 {
            if last_was_str {
                laststring = tuple_get_item(strings, stringsidx - 1);
                concat = PyUnicode_Concat(laststring, item);
                if not concat {
                    jacpy_release(strings);
                    jacpy_release(interpolations);
                    return NULL;
                }
                # Replace laststring with concat
                tuple_set_item(strings, stringsidx - 1, concat);
                jacpy_release(laststring);
            } else {
                tuple_set_item(strings, stringsidx, Py_NewRef(item));
                stringsidx += 1;
            }
            last_was_str = True;
        } elif interpolation_check_exact(item) {
            if not last_was_str {
                tuple_set_item(strings, stringsidx, empty_string());
                stringsidx += 1;
            }
            tuple_set_item(interpolations, interpolationsidx, Py_NewRef(item));
            interpolationsidx += 1;
            last_was_str = False;
        }
    }
    if not last_was_str {
        tuple_set_item(strings, stringsidx, empty_string());
        stringsidx += 1;
    }
    template = _PyTemplate_Build(strings, interpolations);
    jacpy_release(strings);
    jacpy_release(interpolations);
    return template;
}

def template_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    object_type(op).view(1)[0].tp_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def template_clear(op: ptr[PyObject]) -> i32 {
    t = template_of(op);
    strings = t.view(1)[0].strings;
    t.view(1)[0].strings = NULL;
    jacpy_release(strings);
    interpolations = t.view(1)[0].interpolations;
    t.view(1)[0].interpolations = NULL;
    jacpy_release(interpolations);
    return i32(0);
}

def template_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    t = template_of(op);
    status = visit_reference(t.view(1)[0].strings, visitor, arg);
    if status == 0 {
        status = visit_reference(t.view(1)[0].interpolations, visitor, arg);
    }
    return status;
}

def template_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    t = template_of(op);
    return PyUnicode_FromFormat(
        "%s(strings=%R, interpolations=%R)",
        _PyType_Name(ptr[PyObject](object_type(op))),
        t.view(1)[0].strings,
        t.view(1)[0].interpolations
    );
}

def template_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    t = template_of(op);
    iterator = _PyObject_GC_New(ptr[PyObject](addressof(_PyTemplateIter_Type)));
    if not iterator {
        return NULL;
    }
    stringsiter = PyObject_GetIter(t.view(1)[0].strings);
    if not stringsiter {
        jacpy_release(iterator);
        return NULL;
    }
    interpolationsiter = PyObject_GetIter(t.view(1)[0].interpolations);
    if not interpolationsiter {
        jacpy_release(iterator);
        jacpy_release(stringsiter);
        return NULL;
    }
    it = templateiter_of(iterator);
    it.view(1)[0].stringsiter = stringsiter;
    it.view(1)[0].interpolationsiter = interpolationsiter;
    it.view(1)[0].from_strings = 1;
    PyObject_GC_Track(iterator);
    return iterator;
}

def template_strings_concat(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject] {
    left_stringslen = object_size(left);
    left_laststring = tuple_get_item(left, left_stringslen - 1);
    right_stringslen = object_size(right);
    right_firststring = tuple_get_item(right, 0);
    concat = PyUnicode_Concat(left_laststring, right_firststring);
    if not concat {
        return NULL;
    }
    newstrings = PyTuple_New(left_stringslen + right_stringslen - 1);
    if not newstrings {
        jacpy_release(concat);
        return NULL;
    }
    index = i64(0);
    for i in range(left_stringslen - 1) {
        tuple_set_item(newstrings, index, Py_NewRef(tuple_get_item(left, i64(i))));
        index += 1;
    }
    tuple_set_item(newstrings, index, concat);
    index += 1;
    for i in range(1, right_stringslen) {
        tuple_set_item(newstrings, index, Py_NewRef(tuple_get_item(right, i64(i))));
        index += 1;
    }
    return newstrings;
}

def template_concat_templates(t: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
    newstrings = template_strings_concat(
        template_of(t).view(1)[0].strings, template_of(other).view(1)[0].strings
    );
    if not newstrings {
        return NULL;
    }
    newinterpolations = PySequence_Concat(
        template_of(t).view(1)[0].interpolations,
        template_of(other).view(1)[0].interpolations
    );
    if not newinterpolations {
        jacpy_release(newstrings);
        return NULL;
    }
    newtemplate = _PyTemplate_Build(newstrings, newinterpolations);
    jacpy_release(newstrings);
    jacpy_release(newinterpolations);
    return newtemplate;
}

def template_values_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    interpolations = template_of(op).view(1)[0].interpolations;
    length = object_size(interpolations);
    values = PyTuple_New(length);
    if not values {
        return NULL;
    }
    for i in range(length) {
        item = tuple_get_item(interpolations, i64(i));
        tuple_set_item(values, i64(i), _PyInterpolation_GetValueRef(item));
    }
    return values;
}

def template_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    module = PyImport_ImportModule("string.templatelib");
    if not module {
        return NULL;
    }
    func = PyObject_GetAttrString(module, "_template_unpickle");
    jacpy_release(module);
    if not func {
        return NULL;
    }
    t = template_of(op);
    result = Py_BuildValue(
        "O(OO)", func, t.view(1)[0].strings, t.view(1)[0].interpolations
    );
    jacpy_release(func);
    return result;
}

import from c {
    def _PyTemplate_Concat(t: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
        if template_check_exact(t) and template_check_exact(other) {
            return template_concat_templates(t, other);
        }
        PyErr_Format(
            PyExc_TypeError,
            "can only concatenate string.templatelib.Template (not \"%T\") to string.templatelib.Template",
            other
        );
        return NULL;
    }  def _PyTemplate_Build(
        strings: ptr[PyObject], interpolations: ptr[PyObject]
    ) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(_PyTemplate_Type)));
        if not op {
            return NULL;
        }
        t = template_of(op);
        t.view(1)[0].strings = Py_NewRef(strings);
        t.view(1)[0].interpolations = Py_NewRef(interpolations);
        PyObject_GC_Track(op);
        return op;
    }
}
