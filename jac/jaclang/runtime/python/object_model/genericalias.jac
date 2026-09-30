"""types.GenericAlias, e.g. list[int]: Objects/genericaliasobject.c in native Jac.

`Py_GenericAliasType` and `_Py_GenericAliasIterType` are C data Jac defines
under their C names, and `Py_GenericAlias` (every `__class_getitem__` of the
builtin types) and the parameter substitution `_Py_make_parameters` /
`_Py_subs_parameters` that typing.Union shares are C functions under theirs.
The object layouts, `gaobject` and `gaiterobject`, come from layouts.jac.
See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_ExceptionMatches,
    PyErr_Clear,
    PyErr_Format,
    PyErr_Occurred,
    PyErr_SetNone,
    PyErr_SetString,
    PyExc_AttributeError,
    PyExc_StopIteration,
    PyExc_TypeError,
    PyList_Append,
    PyList_GetItemRef,
    PyList_New,
    PyList_SetSlice,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallOneArg,
    PyObject_ClearWeakRefs,
    PyObject_Dir,
    PyObject_GC_Del,
    PyObject_GenericGetAttr,
    PyObject_GetAttr,
    PyObject_GetItem,
    PyObject_GetIter,
    PyObject_GetOptionalAttrString,
    PyObject_HasAttrWithError,
    PyObject_Hash,
    PyObject_IsTrue,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    PyObject_SelfIter,
    PyObject_SetAttrString,
    PyObject_Vectorcall,
    PySequence_Contains,
    PySequence_List,
    PySequence_Tuple,
    PyTuple_New,
    PyTuple_Pack,
    PyType_GenericAlloc,
    PyUnicodeWriter,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteASCII,
    PyUnicodeWriter_WriteChar,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    PyVectorcall_Function,
    Py_BuildValue,
    Py_Ellipsis,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyArg_CheckPositional,
    _PyArg_NoKeywords,
    _PyObject_GC_New,
    _PyTuple_Resize,
    _PyUnicode_EqualToASCIIString,
    _Py_typing_type_repr,
    jacpy_is_exact_list,
    jacpy_is_list,
    jacpy_is_tuple,
    jacpy_is_type,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_NOARGS,
    METH_O,
    PyGetSetDef,
    PyMappingMethods,
    PyNumberMethods,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_NE,
    Py_READONLY,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_HAVE_VECTORCALL,
    Py_T_BOOL,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_T_OBJECT,
    _object,
    gaiterobject,
    gaiterobject_SIZE,
    gaobject,
    gaobject_ARGS,
    gaobject_ORIGIN,
    gaobject_SIZE,
    gaobject_STARRED,
    gaobject_VECTORCALL,
    gaobject_WEAKREFLIST
}
import from jaclang.runtime.python.object_model.header {
    _Py_FalseStruct,
    _Py_TrueStruct,
    eval_builtin,
    object_gc_track,
    object_gc_untrack,
    object_size,
    object_type,
    object_type_check,
    PyType_Type,
    tuple_get_item,
    tuple_set_item
}
import from jaclang.runtime.python.object_model.union { _Py_union_type_or }
import from jaclang.runtime.python.bindings.module { visit_reference }

# Attributes of the alias itself, which take priority over `__origin__`'s.
glob:priv ATTR_EXCEPTIONS: list[str] = [
         "__class__",
         "__origin__",
         "__args__",
         "__unpacked__",
         "__parameters__",
         "__typing_unpacked_tuple_args__",
         "__mro_entries__",
         "__reduce_ex__",  # needed so we don't look up object.__reduce_ex__
         "__reduce__"
     ],
     # Attributes never proxied to `__origin__`, so existing code keeps working.
     ATTR_BLOCKED: list[str] = ["__bases__", "__copy__", "__deepcopy__"];

import from c {
    glob PyTuple_Type: PyTypeObject;
    # The interned __typing_subst__ name, found on first use.
    glob:priv typing_subst_key: ptr[PyObject] = ptr[PyObject](),
         ga_as_mapping: PyMappingMethods = PyMappingMethods(mp_subscript=ga_getitem),
         ga_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__mro_entries__"),
                 ml_meth=ptr(ga_mro_entries),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__instancecheck__"),
                 ml_meth=ptr(ga_instancecheck),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__subclasscheck__"),
                 ml_meth=ptr(ga_subclasscheck),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(ga_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__dir__"),
                 ml_meth=ptr(ga_dir),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         ga_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__origin__"),
                 type_=_Py_T_OBJECT,
                 offset=gaobject_ORIGIN,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__args__"),
                 type_=_Py_T_OBJECT,
                 offset=gaobject_ARGS,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__unpacked__"),
                 type_=Py_T_BOOL,
                 offset=gaobject_STARRED,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         ga_properties: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("__parameters__"),
                 get=ga_parameters,
                 doc=ptr[u8]("Type variables in the GenericAlias.")
             ),
             PyGetSetDef(
                 name=ptr[u8]("__typing_unpacked_tuple_args__"),
                 get=ga_unpacked_tuple_args
             ),
             PyGetSetDef()
         ],
         ga_as_number: PyNumberMethods = PyNumberMethods(nb_or=_Py_union_type_or),
         ga_iter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(ga_iter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ];
    # gh-91632: exported to be cleared in _PyTypes_FiniTypes.
    glob _Py_GenericAliasIterType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("generic_alias_iterator"),
             tp_basicsize=gaiterobject_SIZE,
             tp_iter=PyObject_SelfIter,
             tp_iternext=ga_iternext,
             tp_traverse=ga_iter_traverse,
             tp_methods=addressof(ga_iter_methods),
             tp_dealloc=ga_iter_dealloc,
             tp_clear=ga_iter_clear,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC
         ),
         Py_GenericAliasType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("types.GenericAlias"),
             tp_doc=ptr[u8](
                 "GenericAlias(origin, args, /)\n--\n\n"
                 "Represent a PEP 585 generic type\n\n"
                 "E.g. for t = list[int], t.__origin__ is list and t.__args__ is (int,)."
             ),
             tp_basicsize=gaobject_SIZE,
             tp_dealloc=ga_dealloc,
             tp_repr=ga_repr,
             tp_as_number=addressof(ga_as_number),
             tp_as_mapping=addressof(ga_as_mapping),
             tp_hash=ga_hash,
             tp_call=ga_call,
             tp_getattro=ga_getattro,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_HAVE_GC
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_HAVE_VECTORCALL,
             tp_traverse=ga_traverse,
             tp_richcompare=ga_richcompare,
             tp_weaklistoffset=gaobject_WEAKREFLIST,
             tp_methods=addressof(ga_methods),
             tp_members=addressof(ga_members),
             tp_alloc=PyType_GenericAlloc,
             tp_new=ga_new,
             tp_free=PyObject_GC_Del,
             tp_getset=addressof(ga_properties),
             tp_iter=ga_iter,
             tp_vectorcall_offset=gaobject_VECTORCALL
         );
}

def ga_of(op: ptr[PyObject]) -> ptr[gaobject] {
    return ptr[gaobject](op);
}

"""_PyGenericAlias_Check."""
def generic_alias_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, addressof(Py_GenericAliasType));
}

def py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

def ga_dealloc(op: ptr[PyObject]) {
    alias = ga_of(op);
    object_gc_untrack(op);
    if alias.view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    jacpy_release(alias.view(1)[0].origin);
    jacpy_release(alias.view(1)[0].args);
    jacpy_release(alias.view(1)[0].parameters);
    object_type(op).view(1)[0].tp_free(ptr(op));
}

def ga_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    alias = ga_of(op);
    status = visit_reference(alias.view(1)[0].origin, visitor, arg);
    if status == 0 {
        status = visit_reference(alias.view(1)[0].args, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(alias.view(1)[0].parameters, visitor, arg);
    }
    return status;
}

def ga_repr_items_list(writer: ptr[PyUnicodeWriter], p: ptr[PyObject]) -> i32 {
    length = object_size(p);
    if PyUnicodeWriter_WriteChar(writer, u32(91)) < 0 {
        return i32(-1);
    }
    for i in range(length) {
        if i > 0 and PyUnicodeWriter_WriteASCII(writer, ", ", 2) < 0 {
            return i32(-1);
        }
        item = PyList_GetItemRef(p, i64(i));
        if not item {
            return i32(-1);  # list can be mutated in a callback
        }
        result = _Py_typing_type_repr(writer, item);
        jacpy_release(item);
        if result < 0 {
            return i32(-1);
        }
    }
    if PyUnicodeWriter_WriteChar(writer, u32(93)) < 0 {
        return i32(-1);
    }
    return i32(0);
}

def ga_repr_into(writer: ptr[PyUnicodeWriter], alias: ptr[gaobject]) -> bool {
    args = alias.view(1)[0].args;
    length = object_size(args);
    if alias.view(1)[0].starred != u8(0)
        and PyUnicodeWriter_WriteChar(writer, u32(42)) < 0 {
        return False;
    }
    if _Py_typing_type_repr(writer, alias.view(1)[0].origin) < 0
        or PyUnicodeWriter_WriteChar(writer, u32(91)) < 0 {
        return False;
    }
    for i in range(length) {
        if i > 0 and PyUnicodeWriter_WriteASCII(writer, ", ", 2) < 0 {
            return False;
        }
        p = tuple_get_item(args, i64(i));
        if jacpy_is_exact_list(p) != 0 {
            # Looks like we are working with ParamSpec's list of type args:
            if ga_repr_items_list(writer, p) < 0 {
                return False;
            }
        } elif _Py_typing_type_repr(writer, p) < 0 {
            return False;
        }
    }
    # for something like tuple[()] we should print a "()"
    if length == 0 and PyUnicodeWriter_WriteASCII(writer, "()", 2) < 0 {
        return False;
    }
    return PyUnicodeWriter_WriteChar(writer, u32(93)) >= 0;
}

def ga_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    alias = ga_of(op);
    length = object_size(alias.view(1)[0].args);
    # Estimation based on the shortest format: "int[int, int, int]"
    estimate = length * 5 if length <= i64.MAX // 5 else length;
    writer = PyUnicodeWriter_Create(3 + 1 + estimate + 1);
    if not writer {
        return NULL;
    }
    if not ga_repr_into(writer, alias) {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

# Index of item in tuple[:length], or -1 if not found.
def tuple_index(tuple: ptr[PyObject], length: i64, item: ptr[PyObject]) -> i64 {
    for i in range(length) {
        if tuple_get_item(tuple, i64(i)) == item {
            return i64(i);
        }
    }
    return -1;
}

# Store item at `length` when it is not among the first `length` items;
# 1 when stored.
def tuple_add(tuple: ptr[PyObject], length: i64, item: ptr[PyObject]) -> i64 {
    if tuple_index(tuple, length, item) < 0 {
        tuple_set_item(tuple, length, Py_NewRef(item));
        return 1;
    }
    return 0;
}

# Grow `dst` by count-1 and copy the items of `src` into it from `dstindex`:
# the resized tuple and the next index, or (NULL, -1) with the error set (the
# old tuple released, as _PyTuple_Resize() does).
def tuple_extend(
    dst: ptr[PyObject], dstindex: i64, src: ptr[PyObject], count: i64
) -> tuple[ptr[PyObject], i64] {
    target = dst;
    if _PyTuple_Resize(&mut target, object_size(dst) + count - 1) != 0 {
        return (NULL, i64(-1));
    }
    for i in range(count) {
        tuple_set_item(target, dstindex + i, Py_NewRef(tuple_get_item(src, i64(i))));
    }
    return (target, dstindex + count);
}

# The argument items of a subscription: a tuple's items, or the one item.
def arg_count(item: ptr[PyObject]) -> i64 {
    return object_size(item) if jacpy_is_tuple(item) != 0 else i64(1);
}

def arg_at(item: ptr[PyObject], index: i64) -> ptr[PyObject] {
    return tuple_get_item(item, index) if jacpy_is_tuple(item) != 0 else item;
}

# If obj is a generic alias, substitute type variables params with the
# substitutions of `item`. For example, if obj is list[T], params is (T, S),
# and item is (str, int), return list[str]. If obj doesn't have a
# __parameters__ attribute or that's not a non-empty tuple, return a new
# reference to obj.
def subs_tvars(
    obj_arg: ptr[PyObject], params: ptr[PyObject], item: ptr[PyObject]
) -> ptr[PyObject] {
    subparams = NULL;
    if PyObject_GetOptionalAttrString(obj_arg, "__parameters__", &mut subparams) < 0 {
        return NULL;
    }
    if not subparams or jacpy_is_tuple(subparams) == 0 or object_size(subparams) == 0 {
        jacpy_release(subparams);
        return Py_NewRef(obj_arg);
    }
    nparams = object_size(params);
    nsubargs = object_size(subparams);
    subargs = PyTuple_New(nsubargs);
    if not subargs {
        jacpy_release(subparams);
        return NULL;
    }
    j = i64(0);
    for i in range(nsubargs) {
        arg = tuple_get_item(subparams, i64(i));
        iparam = tuple_index(params, nparams, arg);
        if iparam >= 0 {
            param = tuple_get_item(params, iparam);
            arg = arg_at(item, iparam);
            if int(object_type(param).view(1)[0].tp_iter) != 0
                and jacpy_is_tuple(arg) != 0 {
                # TypeVarTuple
                (subargs, j) = tuple_extend(subargs, j, arg, object_size(arg));
                if j < 0 {
                    jacpy_release(subparams);
                    return NULL;
                }
                continue;
            }
        }
        tuple_set_item(subargs, j, Py_NewRef(arg));
        j += 1;
    }
    result = PyObject_GetItem(obj_arg, subargs);
    jacpy_release(subargs);
    jacpy_release(subparams);
    return result;
}

def is_unpacked_typevartuple(arg: ptr[PyObject]) -> i32 {
    if jacpy_is_type(arg) != 0 {
        return i32(0);
    }
    tmp = NULL;
    result = PyObject_GetOptionalAttrString(
        arg, "__typing_is_unpacked_typevartuple__", &mut tmp
    );
    if result > 0 {
        result = PyObject_IsTrue(tmp);
        jacpy_release(tmp);
    }
    return result;
}

def unpacked_tuple_args(arg: ptr[PyObject]) -> ptr[PyObject] {
    # Fast path
    if generic_alias_check(arg)
        and ga_of(arg).view(1)[0].starred != u8(0)
        and ga_of(arg).view(1)[0].origin == ptr[PyObject](addressof(PyTuple_Type)) {
        return Py_NewRef(ga_of(arg).view(1)[0].args);
    }
    result = NULL;
    if PyObject_GetOptionalAttrString(
        arg, "__typing_unpacked_tuple_args__", &mut result
    )
        > 0 {
        if result == Py_None {
            jacpy_release(result);
            return NULL;
        }
        return result;
    }
    return NULL;
}

def unpack_args(item: ptr[PyObject]) -> ptr[PyObject] {
    newargs = PyList_New(0);
    if not newargs {
        return NULL;
    }
    for i in range(arg_count(item)) {
        arg = arg_at(item, i64(i));
        if jacpy_is_type(arg) == 0 {
            subargs = unpacked_tuple_args(arg);
            if subargs
                and jacpy_is_tuple(subargs) != 0
                and not (
                    object_size(subargs) != 0
                    and tuple_get_item(subargs, object_size(subargs) - 1) == Py_Ellipsis
                ) {
                if PyList_SetSlice(newargs, i64.MAX, i64.MAX, subargs) < 0 {
                    jacpy_release(subargs);
                    jacpy_release(newargs);
                    return NULL;
                }
                jacpy_release(subargs);
                continue;
            }
            jacpy_release(subargs);
            if PyErr_Occurred() {
                jacpy_release(newargs);
                return NULL;
            }
        }
        if PyList_Append(newargs, arg) < 0 {
            jacpy_release(newargs);
            return NULL;
        }
    }
    result = PySequence_Tuple(newargs);
    jacpy_release(newargs);
    return result;
}

import from c {
    def _Py_make_parameters(args: ptr[PyObject]) -> ptr[PyObject] {
        tuple_args = NULL;
        if jacpy_is_list(args) != 0 {
            tuple_args = PySequence_Tuple(args);
            if not tuple_args {
                return NULL;
            }
            args = tuple_args;
        }
        nargs = object_size(args);
        length = nargs;
        parameters = PyTuple_New(length);
        if not parameters {
            jacpy_release(tuple_args);
            return NULL;
        }
        iparam = i64(0);
        for iarg in range(nargs) {
            t = tuple_get_item(args, i64(iarg));
            # We don't want __parameters__ descriptor of a bare Python class.
            if jacpy_is_type(t) != 0 {
                continue;
            }
            rc = PyObject_HasAttrWithError(t, typing_subst_name());
            if rc < 0 {
                jacpy_release(parameters);
                jacpy_release(tuple_args);
                return NULL;
            }
            if rc != 0 {
                iparam += tuple_add(parameters, iparam, t);
                continue;
            }
            subparams = NULL;
            if PyObject_GetOptionalAttrString(t, "__parameters__", &mut subparams)
                < 0 {
                jacpy_release(parameters);
                jacpy_release(tuple_args);
                return NULL;
            }
            if not subparams and (jacpy_is_tuple(t) != 0 or jacpy_is_list(t) != 0) {
                # Recursively call _Py_make_parameters for lists/tuples and
                # add the results to the current parameters.
                subparams = _Py_make_parameters(t);
                if not subparams {
                    jacpy_release(parameters);
                    jacpy_release(tuple_args);
                    return NULL;
                }
            }
            if subparams and jacpy_is_tuple(subparams) != 0 {
                len2 = object_size(subparams);
                needed = len2 - 1 - (i64(iarg) - iparam);
                if needed > 0 {
                    length += needed;
                    if _PyTuple_Resize(&mut parameters, length) < 0 {
                        jacpy_release(subparams);
                        jacpy_release(tuple_args);
                        return NULL;
                    }
                }
                for j in range(len2) {
                    iparam += tuple_add(
                        parameters, iparam, tuple_get_item(subparams, i64(j))
                    );
                }
            }
            jacpy_release(subparams);
        }
        if iparam < length {
            if _PyTuple_Resize(&mut parameters, iparam) < 0 {
                jacpy_release(parameters);
                jacpy_release(tuple_args);
                return NULL;
            }
        }
        jacpy_release(tuple_args);
        return parameters;
    }  def _Py_subs_parameters(
        op: ptr[PyObject],
        args: ptr[PyObject],
        parameters: ptr[PyObject],
        item: ptr[PyObject]
    ) -> ptr[PyObject] {
        nparams = object_size(parameters);
        if nparams == 0 {
            PyErr_Format(PyExc_TypeError, "%R is not a generic class", op);
            return NULL;
        }
        item = unpack_args(item);
        if not item {
            return NULL;
        }
        for i in range(nparams) {
            param = tuple_get_item(parameters, i64(i));
            prepare = NULL;
            if PyObject_GetOptionalAttrString(
                param, "__typing_prepare_subst__", &mut prepare
            )
                < 0 {
                jacpy_release(item);
                return NULL;
            }
            if prepare and prepare != Py_None {
                tmp = PyObject_CallFunction(prepare, "OO", op, item)
                    if jacpy_is_tuple(item) != 0
                    else PyObject_CallFunction(prepare, "O(O)", op, item);
                jacpy_release(prepare);
                jacpy_release(item);
                item = tmp;
                if not item {
                    return NULL;
                }
            } else {
                jacpy_release(prepare);
            }
        }
        nitems = arg_count(item);
        if nitems != nparams {
            jacpy_release(item);
            PyErr_Format(
                PyExc_TypeError,
                "Too %s arguments for %R; actual %zd, expected %zd",
                ptr[u8]("many") if nitems > nparams else ptr[u8]("few"),
                op,
                nitems,
                nparams
            );
            return NULL;
        }
        # Replace all type variables (specified by parameters) with the
        # corresponding values of the items:
        #   t = list[T];          t[int]      -> newargs = [int]
        #   t = dict[str, T];     t[int]      -> newargs = [str, int]
        #   t = dict[T, list[S]]; t[str, int] -> newargs = [str, list[int]]
        #   t = list[[T]];        t[str]      -> newargs = [[str]]
        tuple_args = NULL;
        if jacpy_is_list(args) != 0 {
            tuple_args = PySequence_Tuple(args);
            if not tuple_args {
                return NULL;
            }
            args = tuple_args;
        }
        nargs = object_size(args);
        newargs = PyTuple_New(nargs);
        if not newargs {
            jacpy_release(item);
            jacpy_release(tuple_args);
            return NULL;
        }
        jarg = i64(0);
        for iarg in range(nargs) {
            arg = tuple_get_item(args, i64(iarg));
            if jacpy_is_type(arg) != 0 {
                tuple_set_item(newargs, jarg, Py_NewRef(arg));
                jarg += 1;
                continue;
            }
            # Recursively substitute params in lists/tuples.
            if jacpy_is_tuple(arg) != 0 or jacpy_is_list(arg) != 0 {
                subargs = _Py_subs_parameters(op, arg, parameters, item);
                if subargs and jacpy_is_tuple(arg) == 0 {
                    # _Py_subs_parameters returns a tuple. If the original arg
                    # was a list, convert subargs to a list as well.
                    subargs_list = PySequence_List(subargs);
                    jacpy_release(subargs);
                    subargs = subargs_list;
                }
                if not subargs {
                    jacpy_release(newargs);
                    jacpy_release(item);
                    jacpy_release(tuple_args);
                    return NULL;
                }
                tuple_set_item(newargs, jarg, subargs);
                jarg += 1;
                continue;
            }
            unpack = is_unpacked_typevartuple(arg);
            if unpack < 0 {
                jacpy_release(newargs);
                jacpy_release(item);
                jacpy_release(tuple_args);
                return NULL;
            }
            subst = NULL;
            if PyObject_GetOptionalAttrString(arg, "__typing_subst__", &mut subst)
                < 0 {
                jacpy_release(newargs);
                jacpy_release(item);
                jacpy_release(tuple_args);
                return NULL;
            }
            substituted = NULL;
            if subst {
                iparam = tuple_index(parameters, nparams, arg);
                substituted = PyObject_CallOneArg(subst, arg_at(item, iparam));
                jacpy_release(subst);
            } else {
                substituted = subs_tvars(arg, parameters, item);
            }
            if not substituted {
                jacpy_release(newargs);
                jacpy_release(item);
                jacpy_release(tuple_args);
                return NULL;
            }
            if unpack != 0 {
                if jacpy_is_tuple(substituted) == 0 {
                    jacpy_release(newargs);
                    jacpy_release(item);
                    PyErr_Format(
                        PyExc_TypeError,
                        "expected __typing_subst__ of %T objects to return a tuple, not %T",
                        tuple_get_item(args, i64(iarg)),
                        substituted
                    );
                    jacpy_release(tuple_args);
                    jacpy_release(substituted);
                    return NULL;
                }
                (newargs, jarg) = tuple_extend(
                    newargs, jarg, substituted, object_size(substituted)
                );
                jacpy_release(substituted);
                if jarg < 0 {
                    jacpy_release(item);
                    jacpy_release(tuple_args);
                    return NULL;
                }
            } else {
                tuple_set_item(newargs, jarg, substituted);
                jarg += 1;
            }
        }
        jacpy_release(item);
        jacpy_release(tuple_args);
        return newargs;
    }
}

"""The __typing_subst__ attribute name, interned."""
def typing_subst_name -> ptr[PyObject] {
    if not typing_subst_key {
        typing_subst_key = PyUnicode_InternFromString("__typing_subst__");
    }
    return typing_subst_key;
}

# Populate __parameters__ if needed; NULL with the error set.
def ga_parameters_of(alias: ptr[gaobject]) -> ptr[PyObject] {
    if not alias.view(1)[0].parameters {
        alias.view(1)[0].parameters = _Py_make_parameters(alias.view(1)[0].args);
    }
    return alias.view(1)[0].parameters;
}

def ga_getitem(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    alias = ga_of(op);
    parameters = ga_parameters_of(alias);
    if not parameters {
        return NULL;
    }
    newargs = _Py_subs_parameters(op, alias.view(1)[0].args, parameters, item);
    if not newargs {
        return NULL;
    }
    result = Py_GenericAlias(alias.view(1)[0].origin, newargs);
    jacpy_release(newargs);
    if result {
        ga_of(result).view(1)[0].starred = alias.view(1)[0].starred;
    }
    return result;
}

def ga_hash(op: ptr[PyObject]) -> i64 {
    alias = ga_of(op);
    # TODO: Hash in the hash for the origin
    h0 = PyObject_Hash(alias.view(1)[0].origin);
    if h0 == -1 {
        return -1;
    }
    h1 = PyObject_Hash(alias.view(1)[0].args);
    if h1 == -1 {
        return -1;
    }
    return h0 ^ h1;
}

def set_orig_class(result: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject] {
    if result and PyObject_SetAttrString(result, "__orig_class__", op) < 0 {
        if PyErr_ExceptionMatches(PyExc_AttributeError) == 0
            and PyErr_ExceptionMatches(PyExc_TypeError) == 0 {
            jacpy_release(result);
            return NULL;
        }
        PyErr_Clear();
    }
    return result;
}

def ga_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return set_orig_class(PyObject_Call(ga_of(op).view(1)[0].origin, args, kwds), op);
}

def ga_vectorcall(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return set_orig_class(
        PyObject_Vectorcall(ga_of(op).view(1)[0].origin, args, nargsf, kwnames), op
    );
}

def ga_getattro(op: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(name) != 0 {
        # Blocked attributes are not proxied to `__origin__`, so existing code
        # keeps working.
        for blocked in ATTR_BLOCKED {
            if _PyUnicode_EqualToASCIIString(name, blocked) != 0 {
                return PyObject_GenericGetAttr(op, name);
            }
        }
        # The alias's own attributes take priority over `__origin__`'s.
        for attribute in ATTR_EXCEPTIONS {
            if _PyUnicode_EqualToASCIIString(name, attribute) != 0 {
                return PyObject_GenericGetAttr(op, name);
            }
        }
        return PyObject_GetAttr(ga_of(op).view(1)[0].origin, name);
    }
    return PyObject_GenericGetAttr(op, name);
}

def ga_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not generic_alias_check(b) or (op != Py_EQ and op != Py_NE) {
        return Py_NewRef(Py_NotImplemented);
    }
    if op == Py_NE {
        equal = ga_richcompare(a, b, Py_EQ);
        if not equal {
            return NULL;
        }
        jacpy_release(equal);
        return py_bool(equal != ptr[PyObject](addressof(_Py_TrueStruct)));
    }
    aa = ga_of(a);
    bb = ga_of(b);
    if aa.view(1)[0].starred != bb.view(1)[0].starred {
        return py_bool(False);
    }
    eq = PyObject_RichCompareBool(aa.view(1)[0].origin, bb.view(1)[0].origin, Py_EQ);
    if eq < 0 {
        return NULL;
    }
    if eq == 0 {
        return py_bool(False);
    }
    return PyObject_RichCompare(aa.view(1)[0].args, bb.view(1)[0].args, Py_EQ);
}

def ga_mro_entries(op: ptr[PyObject], _args: ptr[PyObject]) -> ptr[PyObject] {
    return PyTuple_Pack(1, ga_of(op).view(1)[0].origin);
}

def ga_instancecheck(_op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_TypeError, "isinstance() argument 2 cannot be a parameterized generic"
    );
    return NULL;
}

def ga_subclasscheck(_op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_TypeError, "issubclass() argument 2 cannot be a parameterized generic"
    );
    return NULL;
}

def ga_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    alias = ga_of(op);
    if alias.view(1)[0].starred != u8(0) {
        tmp = Py_GenericAlias(alias.view(1)[0].origin, alias.view(1)[0].args);
        if tmp {
            iterator = PyObject_GetIter(tmp);
            jacpy_release(tmp);
            tmp = iterator;
        }
        if not tmp {
            return NULL;
        }
        return Py_BuildValue("N(N)", eval_builtin("next"), tmp);
    }
    return Py_BuildValue(
        "O(OO)", object_type(op), alias.view(1)[0].origin, alias.view(1)[0].args
    );
}

def ga_dir(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    dir = PyObject_Dir(ga_of(op).view(1)[0].origin);
    if not dir {
        return NULL;
    }
    for attribute in ATTR_EXCEPTIONS {
        listed = PyUnicode_FromString(attribute);
        if not listed {
            jacpy_release(dir);
            return NULL;
        }
        contains = PySequence_Contains(dir, listed);
        if contains < 0 or (contains == 0 and PyList_Append(dir, listed) < 0) {
            jacpy_release(listed);
            jacpy_release(dir);
            return NULL;
        }
        jacpy_release(listed);
    }
    return dir;
}

def ga_parameters(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    parameters = ga_parameters_of(ga_of(op));
    return Py_NewRef(parameters) if parameters else NULL;
}

def ga_unpacked_tuple_args(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    alias = ga_of(op);
    if alias.view(1)[0].starred != u8(0)
        and alias.view(1)[0].origin == ptr[PyObject](addressof(PyTuple_Type)) {
        return Py_NewRef(alias.view(1)[0].args);
    }
    return Py_NewRef(Py_None);
}

# Create the alias's args tuple and set its attributes; False with the error
# set.
def setup_ga(alias: ptr[gaobject], origin: ptr[PyObject], args: ptr[PyObject]) -> bool {
    if jacpy_is_tuple(args) == 0 {
        args = PyTuple_Pack(1, args);
        if not args {
            return False;
        }
    } else {
        args = Py_NewRef(args);
    }
    alias.view(1)[0].origin = Py_NewRef(origin);
    alias.view(1)[0].args = args;
    alias.view(1)[0].parameters = NULL;
    alias.view(1)[0].weakreflist = NULL;
    if ptr(PyVectorcall_Function(origin)) {
        alias.view(1)[0].vectorcall = ga_vectorcall;
    } else {
        alias.view(1)[0].vectorcall = 0;
    }
    return True;
}

def ga_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds and _PyArg_NoKeywords("GenericAlias", kwds) == 0 {
        return NULL;
    }
    nargs = object_size(args);
    if nargs != 2 and _PyArg_CheckPositional("GenericAlias", nargs, 2, 2) == 0 {
        return NULL;
    }
    op = _type.view(1)[0].tp_alloc(_type, 0);
    if not op {
        return NULL;
    }
    if not setup_ga(ga_of(op), tuple_get_item(args, 0), tuple_get_item(args, 1)) {
        jacpy_release(op);
        return NULL;
    }
    return op;
}

# ---------------------------------------------------------------- iterator
def gaiter_of(op: ptr[PyObject]) -> ptr[gaiterobject] {
    return ptr[gaiterobject](op);
}

def ga_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    gi = gaiter_of(op);
    wrapped = gi.view(1)[0].obj_;
    if not wrapped {
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }
    alias = ga_of(wrapped);
    starred_alias = Py_GenericAlias(alias.view(1)[0].origin, alias.view(1)[0].args);
    if not starred_alias {
        return NULL;
    }
    ga_of(starred_alias).view(1)[0].starred = 1;
    gi.view(1)[0].obj_ = NULL;
    jacpy_release(wrapped);
    return starred_alias;
}

def ga_iter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    jacpy_release(gaiter_of(op).view(1)[0].obj_);
    PyObject_GC_Del(op);
}

def ga_iter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(gaiter_of(op).view(1)[0].obj_, visitor, arg);
}

def ga_iter_clear(op: ptr[PyObject]) -> i32 {
    wrapped = gaiter_of(op).view(1)[0].obj_;
    gaiter_of(op).view(1)[0].obj_ = NULL;
    jacpy_release(wrapped);
    return i32(0);
}

def ga_iter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    # _PyEval_GetBuiltin can invoke arbitrary code, so the call must come
    # before the iterator's fields are read. see issue #101765
    iterator = eval_builtin("iter");
    wrapped = gaiter_of(op).view(1)[0].obj_;
    if wrapped {
        return Py_BuildValue("N(O)", iterator, wrapped);
    }
    return Py_BuildValue("N(())", iterator);
}

def ga_iter(op: ptr[PyObject]) -> ptr[PyObject] {
    gi = _PyObject_GC_New(ptr[PyObject](addressof(_Py_GenericAliasIterType)));
    if not gi {
        return NULL;
    }
    gaiter_of(gi).view(1)[0].obj_ = Py_NewRef(op);
    object_gc_track(gi);
    return gi;
}

import from c {
    def Py_GenericAlias(origin: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
        op = PyType_GenericAlloc(ptr[PyObject](addressof(Py_GenericAliasType)), 0);
        if not op {
            return NULL;
        }
        if not setup_ga(ga_of(op), origin, args) {
            jacpy_release(op);
            return NULL;
        }
        return op;
    }
}
