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

def templateiter_of(op: ptr[PyObject]) -> ptr[templateiterobject];

def templateiter_next(op: ptr[PyObject]) -> ptr[PyObject];

def templateiter_dealloc(op: ptr[PyObject]);

def templateiter_clear(op: ptr[PyObject]) -> i32;

def templateiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def template_of(op: ptr[PyObject]) -> ptr[templateobject];

def template_check_exact(op: ptr[PyObject]) -> bool;

def empty_string -> ptr[PyObject];

def template_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def template_dealloc(op: ptr[PyObject]);

def template_clear(op: ptr[PyObject]) -> i32;

def template_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def template_repr(op: ptr[PyObject]) -> ptr[PyObject];

def template_iter(op: ptr[PyObject]) -> ptr[PyObject];

def template_strings_concat(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject];

def template_concat_templates(t: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject];

def template_values_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def template_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyTemplate_Concat(t: ptr[PyObject], other: ptr[PyObject]) -> ptr[PyObject] {
        if template_check_exact(t) and template_check_exact(other) {
            return template_concat_templates(t, other);
        }
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "can only concatenate string.templatelib.Template (not \"%T\") to string.templatelib.Template"
            ),
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
        object_gc_track(op);
        return op;
    }
}

impl templateiter_of(op: ptr[PyObject]) -> ptr[templateiterobject] {
    return ptr[templateiterobject](op);
}

impl templateiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
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

impl templateiter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_type(op).view(1)[0].tp_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl templateiter_clear(op: ptr[PyObject]) -> i32 {
    it = templateiter_of(op);
    strings = it.view(1)[0].stringsiter;
    it.view(1)[0].stringsiter = NULL;
    jacpy_release(strings);
    interpolations = it.view(1)[0].interpolationsiter;
    it.view(1)[0].interpolationsiter = NULL;
    jacpy_release(interpolations);
    return i32(0);
}

impl templateiter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    it = templateiter_of(op);
    status = visit_reference(it.view(1)[0].stringsiter, visitor, arg);
    if status == 0 {
        status = visit_reference(it.view(1)[0].interpolationsiter, visitor, arg);
    }
    return status;
}

impl template_of(op: ptr[PyObject]) -> ptr[templateobject] {
    return ptr[templateobject](op);
}

impl template_check_exact(op: ptr[PyObject]) -> bool {
    return object_type(op) == addressof(_PyTemplate_Type);
}

impl empty_string -> ptr[PyObject] {
    return Py_GetConstantBorrowed(Py_CONSTANT_EMPTY_STR);
}

impl template_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("Template.__new__ only accepts *args arguments")
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
                ptr[u8](
                    "Template.__new__ *args need to be of type 'str' or 'Interpolation', got %T"
                ),
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

impl template_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_type(op).view(1)[0].tp_clear(op);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl template_clear(op: ptr[PyObject]) -> i32 {
    t = template_of(op);
    strings = t.view(1)[0].strings;
    t.view(1)[0].strings = NULL;
    jacpy_release(strings);
    interpolations = t.view(1)[0].interpolations;
    t.view(1)[0].interpolations = NULL;
    jacpy_release(interpolations);
    return i32(0);
}

impl template_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    t = template_of(op);
    status = visit_reference(t.view(1)[0].strings, visitor, arg);
    if status == 0 {
        status = visit_reference(t.view(1)[0].interpolations, visitor, arg);
    }
    return status;
}

impl template_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    t = template_of(op);
    return PyUnicode_FromFormat(
        "%s(strings=%R, interpolations=%R)",
        _PyType_Name(ptr[PyObject](object_type(op))),
        t.view(1)[0].strings,
        t.view(1)[0].interpolations
    );
}

impl template_iter(op: ptr[PyObject]) -> ptr[PyObject] {
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
    object_gc_track(iterator);
    return iterator;
}

impl template_strings_concat(
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

impl template_concat_templates(
    t: ptr[PyObject], other: ptr[PyObject]
) -> ptr[PyObject] {
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

impl template_values_get(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
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

impl template_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    module = PyImport_ImportModule("string.templatelib");
    if not module {
        return NULL;
    }
    func = PyObject_GetAttrString(module, ptr[u8]("_template_unpickle"));
    jacpy_release(module);
    if not func {
        return NULL;
    }
    t = template_of(op);
    result = Py_BuildValue(
        ptr[u8]("O(OO)"), func, t.view(1)[0].strings, t.view(1)[0].interpolations
    );
    jacpy_release(func);
    return result;
}
