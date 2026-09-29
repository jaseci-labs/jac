"""typing.Union, e.g. Union[int, str] and int | str: Objects/unionobject.c in
native Jac.

`_PyUnion_Type` is C data Jac defines under its C name, and
`_Py_union_type_or` (the `|` of types), `_Py_union_args` and
`_Py_union_from_tuple` are C functions under theirs. The object layout,
`unionobject`, comes from layouts.jac. The parameter substitution it shares
with types.GenericAlias is genericalias.jac's. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Clear,
    PyErr_Format,
    PyErr_SetString,
    PyExc_TypeError,
    PyFrozenSet_New,
    PyImport_ImportModule,
    PyList_Append,
    PyList_AsTuple,
    PyList_GetItem,
    PyList_New,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_CallFunctionObjArgs,
    PyObject_ClearWeakRefs,
    PyObject_GC_Del,
    PyObject_GenericGetAttr,
    PyObject_GetAttr,
    PyObject_GetAttrString,
    PyObject_Hash,
    PyObject_RichCompareBool,
    PySequence_Contains,
    PySet_Add,
    PySet_Contains,
    PySet_New,
    PyType_GenericAlloc,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteASCII,
    PyUnicode_FromString,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyNone_Type,
    _PyObject_GC_New,
    _PyTypeAlias_Type,
    _PyUnicode_EqualToASCIIString,
    _Py_typing_type_repr,
    jacpy_is_exact_tuple,
    jacpy_is_type,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_O,
    PyGetSetDef,
    PyMappingMethods,
    PyNumberMethods,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_NE,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_T_OBJECT,
    _object,
    unionobject,
    unionobject_ARGS,
    unionobject_SIZE,
    unionobject_WEAKREFLIST
}
import from jaclang.runtime.python.object_model.header {
    _Py_FalseStruct,
    _Py_TrueStruct,
    object_gc_track,
    object_gc_untrack,
    object_is_type,
    object_size,
    object_type,
    object_type_check,
    PyType_Type,
    tuple_get_item
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    # Defined by genericalias.jac, which imports this module.
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

def union_of(op: ptr[PyObject]) -> ptr[unionobject] {
    return ptr[unionobject](op);
}

"""_PyUnion_Check."""
def union_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(_PyUnion_Type));
}

def unionobject_dealloc(op: ptr[PyObject]) {
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

def union_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
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

def union_hash(op: ptr[PyObject]) -> i64 {
    alias = union_of(op);
    # If there are any unhashable args, treat this union as unhashable.
    # Otherwise, two unions might compare equal but have different hashes.
    unhashable = alias.view(1)[0].unhashable_args;
    if unhashable {
        # Attempt to get an error from one of the values.
        n = object_size(unhashable);
        for i in range(n) {
            if PyObject_Hash(tuple_get_item(unhashable, i64(i))) == -1 {
                return -1;
            }
        }
        # The unhashable values somehow became hashable again. Still raise an
        # error.
        PyErr_Format(PyExc_TypeError, "union contains %zd unhashable elements", n);
        return -1;
    }
    return PyObject_Hash(alias.view(1)[0].hashable_args);
}

# Whether every item of `left` is in `right`: 1, 0, or -1 on error.
def all_contained(left: ptr[PyObject], right: ptr[PyObject]) -> i32 {
    for i in range(object_size(left)) {
        result = PySequence_Contains(right, tuple_get_item(left, i64(i)));
        if result != 1 {
            return result;
        }
    }
    return i32(1);
}

def unions_equal(a: ptr[unionobject], b: ptr[unionobject]) -> i32 {
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

def py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

def union_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not union_check(b) or (op != Py_EQ and op != Py_NE) {
        return Py_NewRef(Py_NotImplemented);
    }
    equal = unions_equal(union_of(a), union_of(b));
    if equal == -1 {
        return NULL;
    }
    return py_bool((equal != 0) == (op == Py_EQ));
}

# unionobject.c's unionbuilder, held in the caller's locals so building a
# union allocates nothing but the union: `args` (list) and `hashable_args`
# (set) are created up front and filled in place, and `unhashable_args` (a
# list, NULL until an unhashable arg arrives) is lent to the adders with
# `&mut`, which is why they are C definitions.

import from c {
    # Create the builder's list and set into `args` / `hashable_args`; False
    # with the error set.
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
) {
    jacpy_release(args);
    jacpy_release(hashable_args);
    jacpy_release(unhashable_args);
}

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
            arg = ptr[PyObject](addressof(_PyNone_Type));  # immortal
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

def is_unionable(op: ptr[PyObject]) -> bool {
    return op == Py_None
        or jacpy_is_type(op) != 0
        or object_type_check(op, addressof(Py_GenericAliasType))
        or union_check(op)
        or object_is_type(op, ptr[PyTypeObject](addressof(_PyTypeAlias_Type)));
}

def union_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    args = union_of(op).view(1)[0].args;
    length = object_size(args);
    # Shortest type name "int" (3 chars) + " | " (3 chars) separator
    estimate = length * 6 if length <= i64.MAX // 6 else length;
    writer = PyUnicodeWriter_Create(estimate);
    if not writer {
        return NULL;
    }
    for i in range(length) {
        if (i > 0 and PyUnicodeWriter_WriteASCII(writer, " | ", 3) < 0)
            or _Py_typing_type_repr(writer, tuple_get_item(args, i64(i))) < 0 {
            PyUnicodeWriter_Discard(writer);
            return NULL;
        }
    }
    return PyUnicodeWriter_Finish(writer);
}

# Populate __parameters__ if needed; -1 with the error set.
def union_init_parameters(alias: ptr[unionobject]) -> i32 {
    if not alias.view(1)[0].parameters {
        alias.view(1)[0].parameters = _Py_make_parameters(alias.view(1)[0].args);
        if not alias.view(1)[0].parameters {
            return i32(-1);
        }
    }
    return i32(0);
}

def union_getitem(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
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

def union_parameters(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    alias = union_of(op);
    if union_init_parameters(alias) < 0 {
        return NULL;
    }
    return Py_NewRef(alias.view(1)[0].parameters);
}

def union_name(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyUnicode_FromString("Union");
}

def union_origin(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(ptr[PyObject](addressof(_PyUnion_Type)));
}

def union_nb_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return union_of_pair(a, b, True);
}

# The union of `a` and `b`, as union_nb_or and _Py_union_type_or build it.
def union_of_pair(
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

def union_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    # "__module__" is required for compatibility with typing module
    if jacpy_is_unicode(name) != 0
        and _PyUnicode_EqualToASCIIString(name, "__module__") != 0 {
        return PyObject_GetAttr(ptr[PyObject](object_type(op)), name);
    }
    return PyObject_GenericGetAttr(op, name);
}

# typing._type_check(arg, msg), as a new reference.
def call_typing_type_check(
    arg: ptr[PyObject], message: ptr[PyObject]
) -> ptr[PyObject] {
    typing = PyImport_ImportModule("typing");
    if not typing {
        return NULL;
    }
    func = PyObject_GetAttrString(typing, "_type_check");
    if not func {
        jacpy_release(typing);
        return NULL;
    }
    result = PyObject_CallFunctionObjArgs(func, arg, message, NULL);
    jacpy_release(func);
    jacpy_release(typing);
    return result;
}

def type_check(arg: ptr[PyObject], msg: str) -> ptr[PyObject] {
    if arg == Py_None {
        # NoneType is immortal, so don't need an INCREF
        return ptr[PyObject](object_type(arg));
    }
    # Fast path to avoid calling into typing.py
    if is_unionable(arg) {
        return Py_NewRef(arg);
    }
    message = PyUnicode_FromString(msg);
    if not message {
        return NULL;
    }
    result = call_typing_type_check(arg, message);
    jacpy_release(message);
    return result;
}

def union_class_getitem(_cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _Py_union_from_tuple(args);
}

def union_mro_entries(op: ptr[PyObject], _args: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_Format(PyExc_TypeError, "Cannot subclass %R", op);
    return NULL;
}

# The union of a builder's args (consuming the builder), or its only arg.
def make_union(
    builder_args: ptr[PyObject],
    builder_hashable: ptr[PyObject],
    builder_unhashable: ptr[PyObject]
) -> ptr[PyObject] {
    n = object_size(builder_args);
    if n == 0 {
        PyErr_SetString(PyExc_TypeError, "Cannot take a Union of no types.");
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

import from c {
    def _Py_union_type_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
        if not is_unionable(a) or not is_unionable(b) {
            return Py_NewRef(Py_NotImplemented);
        }
        # unchecked because is_unionable() already checked them
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
