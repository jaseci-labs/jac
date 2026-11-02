import from c {
    glob Py_GenericAliasType: PyTypeObject; def _Py_make_parameters(
        args: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_subs_parameters(
        op: ptr[PyObject],
        args: ptr[PyObject],
        parameters: ptr[PyObject],
        item: ptr[PyObject]
    ) -> ptr[PyObject];  glob:priv union_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__args__"),
                 type_=_Py_T_OBJECT,
                 offset=unionobject_ARGS,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         union_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_subscript=union_getitem
         ),
         union_properties: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__name__"),
                 get=union_name,
                 doc=ptr[u8]("Name of the type")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__qualname__"),
                 get=union_name,
                 doc=ptr[u8]("Qualified name of the type")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__origin__"),
                 get=union_origin,
                 doc=ptr[u8]("Always returns the type")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__parameters__"),
                 get=union_parameters,
                 doc=ptr[u8]("Type variables in the types.UnionType.")
             ),
             PyGetSetDef()
         ],
         union_as_number: PyNumberMethods = PyNumberMethods(nb_or=union_nb_or),
         union_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(union_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__class_getitem__"),
                 ml_meth=ptr(union_class_getitem),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8]("Create a union containing the given types")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob _PyUnion_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("typing.Union"),
             tp_doc=ptr[u8]("Represent a union type\n\nE.g. for int | str"),
             tp_basicsize=unionobject_SIZE,
             tp_dealloc=unionobject_dealloc,
             tp_alloc=PyType_GenericAlloc,
             tp_free=PyObject_GC_Del,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=union_traverse,
             tp_hash=union_hash,
             tp_getattro=union_getattro,
             tp_members=addressof(union_members),
             tp_methods=addressof(union_methods),
             tp_richcompare=union_richcompare,
             tp_as_mapping=addressof(union_as_mapping),
             tp_as_number=addressof(union_as_number),
             tp_repr=union_repr,
             tp_getset=addressof(union_properties),
             tp_weaklistoffset=unionobject_WEAKREFLIST
         );
}

def union_of(op: ptr[PyObject]) -> ptr[unionobject];

def union_check(op: ptr[PyObject]) -> bool;

def unionobject_dealloc(op: ptr[PyObject]);

def union_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def union_hash(op: ptr[PyObject]) -> i64;

def all_contained(left: ptr[PyObject], right: ptr[PyObject]) -> i32;

def unions_equal(a: ptr[unionobject], b: ptr[unionobject]) -> i32;

def py_bool(value: bool) -> ptr[PyObject];

def union_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];

import from c {
    def unionbuilder_new(
        args: ptr[ptr[PyObject]], hashable_args: ptr[ptr[PyObject]]
    ) -> bool {
        created = PyList_New(0);
        if not created {
            return False;
        }
        hashable = PySet_New(NULL);
        if not hashable {
            jacpy_release(created);
            return False;
        }
        args.view(1)[0] = created;
        hashable_args.view(1)[0] = hashable;
        return True;
    }
}

def unionbuilder_finalize(
    args: ptr[PyObject], hashable_args: ptr[PyObject], unhashable_args: ptr[PyObject]
);

import from c {
    def unionbuilder_add_single_unchecked(
        args: ptr[PyObject],
        hashable_args: ptr[PyObject],
        unhashable_args: ptr[ptr[PyObject]],
        arg: ptr[PyObject]
    ) -> bool {
        if PyObject_Hash(arg) == -1 {
            PyErr_Clear();
            unhashable = unhashable_args.view(1)[0];
            if not unhashable {
                unhashable = PyList_New(0);
                if not unhashable {
                    return False;
                }
                unhashable_args.view(1)[0] = unhashable;
            } else {
                contains = PySequence_Contains(unhashable, arg);
                if contains < 0 {
                    return False;
                }
                if contains == 1 {
                    return True;
                }
            }
            if PyList_Append(unhashable, arg) < 0 {
                return False;
            }
        } else {
            contains = PySet_Contains(hashable_args, arg);
            if contains < 0 {
                return False;
            }
            if contains == 1 {
                return True;
            }
            if PySet_Add(hashable_args, arg) < 0 {
                return False;
            }
        }
        return PyList_Append(args, arg) == 0;
    }  def unionbuilder_add_single(
        args: ptr[PyObject],
        hashable_args: ptr[PyObject],
        unhashable_args: ptr[ptr[PyObject]],
        is_checked: bool,
        arg: ptr[PyObject]
    ) -> bool {
        if arg == Py_None {
            arg = ptr[PyObject](addressof(_PyNone_Type));
        } elif union_check(arg) {
            return unionbuilder_add_tuple(
                args,
                hashable_args,
                unhashable_args,
                is_checked,
                union_of(arg).view(1)[0].args
            );
        }
        if not is_checked {
            return unionbuilder_add_single_unchecked(
                args, hashable_args, unhashable_args, arg
            );
        }
        checked = type_check(arg, "Union[arg, ...]: each arg must be a type.");
        if not checked {
            return False;
        }
        result = unionbuilder_add_single_unchecked(
            args, hashable_args, unhashable_args, checked
        );
        jacpy_release(checked);
        return result;
    }  def unionbuilder_add_tuple(
        args: ptr[PyObject],
        hashable_args: ptr[PyObject],
        unhashable_args: ptr[ptr[PyObject]],
        is_checked: bool,
        tuple: ptr[PyObject]
    ) -> bool {
        for i in range(object_size(tuple)) {
            if not unionbuilder_add_single(
                args,
                hashable_args,
                unhashable_args,
                is_checked,
                tuple_get_item(tuple, i64(i))
            ) {
                return False;
            }
        }
        return True;
    }
}

def is_unionable(op: ptr[PyObject]) -> bool;

def union_repr(op: ptr[PyObject]) -> ptr[PyObject];

def union_init_parameters(alias: ptr[unionobject]) -> i32;

def union_getitem(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def union_parameters(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def union_name(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def union_origin(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def union_nb_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def union_of_pair(
    a: ptr[PyObject], b: ptr[PyObject], is_checked: bool
) -> ptr[PyObject];

def union_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def call_typing_type_check(
    arg: ptr[PyObject], message: ptr[PyObject]
) -> ptr[PyObject];

def type_check(arg: ptr[PyObject], msg: str) -> ptr[PyObject];

def union_class_getitem(_cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def union_mro_entries(op: ptr[PyObject], _args: ptr[PyObject]) -> ptr[PyObject];

def make_union(
    builder_args: ptr[PyObject],
    builder_hashable: ptr[PyObject],
    builder_unhashable: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    def _Py_union_type_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
        if not is_unionable(a) or not is_unionable(b) {
            return Py_NewRef(Py_NotImplemented);
        }

        return union_of_pair(a, b, False);
    }  def _Py_union_args(op: ptr[PyObject]) -> ptr[PyObject] {
        return union_of(op).view(1)[0].args;
    }  def _Py_union_from_tuple(args: ptr[PyObject]) -> ptr[PyObject] {
        builder_args: ptr[PyObject] = NULL;
        hashable_args: ptr[PyObject] = NULL;
        unhashable_args: ptr[PyObject] = NULL;
        if not unionbuilder_new(&mut builder_args, &mut hashable_args) {
            return NULL;
        }
        added = unionbuilder_add_tuple(
            builder_args, hashable_args, &mut unhashable_args, True, args
        )
            if jacpy_is_exact_tuple(args) != 0
            else unionbuilder_add_single(
                builder_args, hashable_args, &mut unhashable_args, True, args
            );
        if not added {
            unionbuilder_finalize(builder_args, hashable_args, unhashable_args);
            return NULL;
        }
        return make_union(builder_args, hashable_args, unhashable_args);
    }
}

impl union_of(op: ptr[PyObject]) -> ptr[unionobject] {
    return ptr[unionobject](op);
}

impl union_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(_PyUnion_Type));
}

impl unionobject_dealloc(op: ptr[PyObject]) {
    alias = union_of(op);
    object_gc_untrack(op);
    if alias.view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    jacpy_release(alias.view(1)[0].args);
    jacpy_release(alias.view(1)[0].hashable_args);
    jacpy_release(alias.view(1)[0].unhashable_args);
    jacpy_release(alias.view(1)[0].parameters);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl union_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    alias = union_of(op);
    status = visit_reference(alias.view(1)[0].args, visitor, arg);
    if status == 0 {
        status = visit_reference(alias.view(1)[0].hashable_args, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(alias.view(1)[0].unhashable_args, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(alias.view(1)[0].parameters, visitor, arg);
    }
    return status;
}

impl union_hash(op: ptr[PyObject]) -> i64 {
    alias = union_of(op);

    unhashable = alias.view(1)[0].unhashable_args;
    if unhashable {
        n = object_size(unhashable);
        for i in range(n) {
            if PyObject_Hash(tuple_get_item(unhashable, i64(i))) == -1 {
                return -1;
            }
        }

        PyErr_Format(
            PyExc_TypeError, ptr[u8]("union contains %zd unhashable elements"), n
        );
        return -1;
    }
    return PyObject_Hash(alias.view(1)[0].hashable_args);
}

impl all_contained(left: ptr[PyObject], right: ptr[PyObject]) -> i32 {
    for i in range(object_size(left)) {
        result = PySequence_Contains(right, tuple_get_item(left, i64(i)));
        if result != 1 {
            return result;
        }
    }
    return i32(1);
}

impl unions_equal(a: ptr[unionobject], b: ptr[unionobject]) -> i32 {
    result = PyObject_RichCompareBool(
        a.view(1)[0].hashable_args, b.view(1)[0].hashable_args, Py_EQ
    );
    if result != 1 {
        return result;
    }
    ua = a.view(1)[0].unhashable_args;
    ub = b.view(1)[0].unhashable_args;
    if ua and ub {
        if object_size(ua) != object_size(ub) {
            return i32(0);
        }
        result = all_contained(ua, ub);
        if result != 1 {
            return result;
        }
        return all_contained(ub, ua);
    } elif ua or ub {
        return i32(0);
    }
    return i32(1);
}

impl py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

impl union_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not union_check(b) or (op != Py_EQ and op != Py_NE) {
        return Py_NewRef(Py_NotImplemented);
    }
    equal = unions_equal(union_of(a), union_of(b));
    if equal == -1 {
        return NULL;
    }
    return py_bool((equal != 0) == (op == Py_EQ));
}

impl unionbuilder_finalize(
    args: ptr[PyObject], hashable_args: ptr[PyObject], unhashable_args: ptr[PyObject]
) {
    jacpy_release(args);
    jacpy_release(hashable_args);
    jacpy_release(unhashable_args);
}

impl is_unionable(op: ptr[PyObject]) -> bool {
    return op == Py_None
        or jacpy_is_type(op) != 0
        or object_type_check(op, addressof(Py_GenericAliasType))
        or union_check(op)
        or object_is_type(op, ptr[PyTypeObject](addressof(_PyTypeAlias_Type)));
}

impl union_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    args = union_of(op).view(1)[0].args;
    length = object_size(args);

    estimate = length * 6 if length <= i64.MAX // 6 else length;
    writer = PyUnicodeWriter_Create(estimate);
    if not writer {
        return NULL;
    }
    for i in range(length) {
        if (i > 0 and PyUnicodeWriter_WriteASCII(writer, ptr[u8](" | "), 3) < 0)
            or _Py_typing_type_repr(writer, tuple_get_item(args, i64(i))) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    return PyUnicodeWriter_Finish(writer);
}

impl union_init_parameters(alias: ptr[unionobject]) -> i32 {
    if not alias.view(1)[0].parameters {
        alias.view(1)[0].parameters = _Py_make_parameters(alias.view(1)[0].args);
        if not alias.view(1)[0].parameters {
            return i32(-1);
        }
    }
    return i32(0);
}

impl union_getitem(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    alias = union_of(op);
    if union_init_parameters(alias) < 0 {
        return NULL;
    }
    newargs = _Py_subs_parameters(
        op, alias.view(1)[0].args, alias.view(1)[0].parameters, item
    );
    if not newargs {
        return NULL;
    }
    result = _Py_union_from_tuple(newargs);
    jacpy_release(newargs);
    return result;
}

impl union_parameters(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    alias = union_of(op);
    if union_init_parameters(alias) < 0 {
        return NULL;
    }
    return Py_NewRef(alias.view(1)[0].parameters);
}

impl union_name(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("Union"));
}

impl union_origin(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(ptr[PyObject](addressof(_PyUnion_Type)));
}

impl union_nb_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return union_of_pair(a, b, True);
}

impl union_of_pair(
    a: ptr[PyObject], b: ptr[PyObject], is_checked: bool
) -> ptr[PyObject] {
    args: ptr[PyObject] = NULL;
    hashable_args: ptr[PyObject] = NULL;
    unhashable_args: ptr[PyObject] = NULL;
    if not unionbuilder_new(&mut args, &mut hashable_args) {
        return NULL;
    }
    if not unionbuilder_add_single(
        args, hashable_args, &mut unhashable_args, is_checked, a
    )
        or not unionbuilder_add_single(
            args, hashable_args, &mut unhashable_args, is_checked, b
        ) {
        unionbuilder_finalize(args, hashable_args, unhashable_args);
        return NULL;
    }
    return make_union(args, hashable_args, unhashable_args);
}

impl union_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(name) != 0
        and _PyUnicode_EqualToASCIIString(name, ptr[u8]("__module__")) != 0 {
        return PyObject_GetAttr(ptr[PyObject](object_type(op)), name);
    }
    return PyObject_GenericGetAttr(op, name);
}

impl call_typing_type_check(
    arg: ptr[PyObject], message: ptr[PyObject]
) -> ptr[PyObject] {
    typing = PyImport_ImportModule(ptr[u8]("typing"));
    if not typing {
        return NULL;
    }
    func = PyObject_GetAttrString(typing, ptr[u8]("_type_check"));
    if not func {
        jacpy_release(typing);
        return NULL;
    }
    result = PyObject_CallFunctionObjArgs(func, arg, message, NULL);
    jacpy_release(func);
    jacpy_release(typing);
    return result;
}

impl type_check(arg: ptr[PyObject], msg: str) -> ptr[PyObject] {
    if arg == Py_None {
        return ptr[PyObject](object_type(arg));
    }

    if is_unionable(arg) {
        return Py_NewRef(arg);
    }
    message = jacpy_unicode_from_text(msg);
    if not message {
        return NULL;
    }
    result = call_typing_type_check(arg, message);
    jacpy_release(message);
    return result;
}

impl union_class_getitem(_cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _Py_union_from_tuple(args);
}

impl union_mro_entries(op: ptr[PyObject], _args: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_Format(PyExc_TypeError, ptr[u8]("Cannot subclass %R"), op);
    return NULL;
}

impl make_union(
    builder_args: ptr[PyObject],
    builder_hashable: ptr[PyObject],
    builder_unhashable: ptr[PyObject]
) -> ptr[PyObject] {
    n = object_size(builder_args);
    if n == 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("Cannot take a Union of no types."));
        unionbuilder_finalize(builder_args, builder_hashable, builder_unhashable);
        return NULL;
    }
    if n == 1 {
        result = Py_NewRef(PyList_GetItem(builder_args, 0));
        unionbuilder_finalize(builder_args, builder_hashable, builder_unhashable);
        return result;
    }
    args = PyList_AsTuple(builder_args);
    hashable_args = PyFrozenSet_New(builder_hashable) if args else NULL;
    unhashable_args = NULL;
    failed = not hashable_args;
    if not failed and builder_unhashable {
        unhashable_args = PyList_AsTuple(builder_unhashable);
        failed = not unhashable_args;
    }
    op = NULL;
    if not failed {
        op = _PyObject_GC_New(ptr[PyObject](addressof(_PyUnion_Type)));
    }
    unionbuilder_finalize(builder_args, builder_hashable, builder_unhashable);
    if not op {
        jacpy_release(args);
        jacpy_release(hashable_args);
        jacpy_release(unhashable_args);
        return NULL;
    }
    created = union_of(op);
    created.view(1)[0].parameters = NULL;
    created.view(1)[0].args = args;
    created.view(1)[0].hashable_args = hashable_args;
    created.view(1)[0].unhashable_args = unhashable_args;
    created.view(1)[0].weakreflist = NULL;
    object_gc_track(op);
    return op;
}
