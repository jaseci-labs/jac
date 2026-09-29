"""Struct sequences, tuples with named fields: Objects/structseq.c in native Jac.

The struct-sequence C API (`PyStructSequence_New`, `_SetItem`, `_GetItem`,
`_InitType2`, `_NewType`) and the interpreter's `_PyStructSequence_*`
functions are C functions under their C names, and
`PyStructSequence_UnnamedField` is C data under its. A struct sequence is a
`PyTupleObject` whose invisible fields follow its visible items; the field
counts are the type's `n_sequence_fields`, `n_fields` and `n_unnamed_fields`.
`__new__` parses its arguments as Objects/clinic/structseq.c.h does. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_GetItemRef,
    PyDict_GetItemWithError,
    PyDict_Keys,
    PyDict_New,
    PyDict_Pop,
    PyDict_SetItem,
    PyDict_Size,
    PyErr_BadInternalCall,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyInterpreterState,
    PyInterpreterState_Main,
    PyLong_AsSsize_t,
    PyLong_FromSsize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyMemberDef,
    PyMethodDef,
    PyObject,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PySequence_Fast,
    PyTuple_New,
    PyType_FromSpecWithBases,
    PyType_Ready,
    PyType_Slot,
    PyType_Spec,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteChar,
    PyUnicodeWriter_WriteRepr,
    PyUnicodeWriter_WriteStr,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    Py_BuildValue,
    Py_IncRef,
    Py_NewRef,
    Py_None,
    _PyArg_NoPositional,
    _PyObject_GC_NewVar,
    _PyStaticType_FiniBuiltin,
    _PyStaticType_InitBuiltin,
    _PyTuple_FromArray,
    _PyTuple_Resize,
    _PyType_GetDict,
    _PyType_HasSubclasses,
    _Py_SetImmortal,
    jacpy_is_dict,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_KEYWORDS,
    METH_NOARGS,
    METH_VARARGS,
    PY_MEMBER_DEF_SIZE,
    PY_TYPE_SLOT_SIZE,
    PY_TYPE_SPEC_SIZE,
    PyStructSequence_Desc,
    PyStructSequence_Field,
    PyStructSequence_SIZE,
    PyTupleObject,
    PyTupleObject_ITEMS,
    PyTypeObject,
    PyVarObject,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_HEAPTYPE,
    Py_TPFLAGS_READY,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_members,
    Py_tp_methods,
    Py_tp_new,
    Py_tp_repr,
    Py_tp_traverse,
    _Py_T_OBJECT,
    _object
}
import from jaclang.runtime.python.object_model.header {
    PyType_Type,
    fast_items,
    object_decref,
    object_new_ref,
    object_size,
    object_xdecref,
    object_type,
    tuple_get_item,
    tuple_items,
    type_has_feature
}
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    PARSE_KEYWORDS,
    invoke
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob PyTuple_Type: PyTypeObject;
    # Fields with this name have only a field index, not a field name. They
    # are only allowed for indices < n_visible_fields.
    glob PyStructSequence_UnnamedField: ptr[u8] = ptr[u8]("unnamed field"); glob:priv structseq_methods:
             list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(structseq_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__replace__"),
                 ml_meth=ptr(structseq_replace),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "__replace__($self, /, **changes)\n--\n\n"
                     "Return a copy of the structure with new values for the specified fields."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         # The interned names of the type attributes, found on first use:
         # n_sequence_fields, n_fields, n_unnamed_fields.
         size_keys: list[ptr[PyObject]] = [
             ptr[PyObject](),
             ptr[PyObject](),
             ptr[PyObject]()
         ];
}

glob:priv VISIBLE: int = 0,
     REAL: int = 1,
     UNNAMED: int = 2,
     SIZE_KEY_NAMES: list[str] = ["n_sequence_fields", "n_fields", "n_unnamed_fields"];

glob:priv structseq_new_signature = CallSignature(
         "structseq", ["sequence", "dict"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

"""The item slots of a struct sequence (visible and hidden)."""
def items_of(op: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return tuple_items(op);
}

# The type attribute `which` (VISIBLE, REAL, UNNAMED) as a size, -1 with the
# error set when it is missing.
def type_attr_as_size(tp: ptr[PyTypeObject], which: int) -> i64 {
    slot = ptr[ptr[PyObject]](addressof(size_keys)) + which;
    name = slot.view(1)[0];
    if not name {
        name = PyUnicode_InternFromString(SIZE_KEY_NAMES[which]);
        if not name {
            return -1;
        }
        slot.view(1)[0] = name;
    }
    v = PyDict_GetItemWithError(_PyType_GetDict(ptr[PyObject](tp)), name);
    if not v and not PyErr_Occurred() {
        PyErr_Format(
            PyExc_TypeError,
            "Missed attribute '%U' of type %s",
            name,
            tp.view(1)[0].tp_name
        );
        return -1;
    }
    return PyLong_AsSsize_t(v);
}

# The real size from the visible size (Py_SIZE()) and the number of
# non-sequence fields accounted for in tp_basicsize.
def get_real_size(op: ptr[PyObject]) -> i64 {
    hidden = object_type(op).view(1)[0].tp_basicsize - PyTupleObject_ITEMS;
    return object_size(op) + hidden // 8;
}

"""A member name as a new str, NULL with the error set."""
def member_name(members: ptr[PyMemberDef], index: i64) -> ptr[PyObject] {
    return PyUnicode_FromString((members + index).view(1)[0].name);
}

import from c {
    def PyStructSequence_New(type_object: ptr[PyObject]) -> ptr[PyObject] {
        type = ptr[PyTypeObject](type_object);
        size = type_attr_as_size(type, REAL);
        if size < 0 {
            return NULL;
        }
        vsize = type_attr_as_size(type, VISIBLE);
        if vsize < 0 {
            return NULL;
        }
        op = _PyObject_GC_NewVar(ptr[PyObject](type), size);
        if not op {
            return NULL;
        }
        ptr[PyTupleObject](op).view(1)[0].ob_hash = -1;
        # Hack the size of the variable object, so invisible fields don't
        # appear to Python code.
        ptr[PyVarObject](op).view(1)[0].ob_size = vsize;
        items = items_of(op);
        for i in range(size) {
            (items + i).view(1)[0] = NULL;
        }
        return op;
    }  def PyStructSequence_SetItem(
        op: ptr[PyObject], index: i64, value: ptr[PyObject]
    ) {
        (items_of(op) + index).view(1)[0] = value;
    }  def PyStructSequence_GetItem(op: ptr[PyObject], index: i64) -> ptr[PyObject] {
        return (items_of(op) + index).view(1)[0];
    }
}

def structseq_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    tp = object_type(op);
    if type_has_feature(tp, Py_TPFLAGS_HEAPTYPE) {
        status = visit_reference(ptr[PyObject](tp), visitor, arg);
        if status != 0 {
            return status;
        }
    }
    items = items_of(op);
    for i in range(get_real_size(op)) {
        status = visit_reference((items + i).view(1)[0], visitor, arg);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

def structseq_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    tp = object_type(op);
    # gh-122527: the size comes from the object, not the type's dictionary,
    # which the garbage collector may have cleared already.
    items = items_of(op);
    for i in range(get_real_size(op)) {
        object_xdecref((items + i).view(1)[0]);
    }
    PyObject_GC_Del(op);
    if type_has_feature(tp, Py_TPFLAGS_HEAPTYPE) {
        jacpy_release(ptr[PyObject](tp));
    }
}

# structseq.__new__(sequence, dict={}), as Argument Clinic parses it.
def structseq_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    # _PyArg_UnpackKeywords' fast path: positional arguments only, within
    # range, are the tuple's items.
    if not kwargs {
        nargs = object_size(args);
        if nargs >= 1 and nargs <= 2 {
            dict = tuple_get_item(args, 1) if nargs > 1 else NULL;
            return structseq_new_impl(_type, tuple_get_item(args, 0), dict);
        }
    }
    return invoke(
        structseq_new_signature, args, kwargs, structseq_new_bound, ptr[PyObject](_type)
    );
}

def structseq_new_bound(args: BoundArguments) -> ptr[PyObject] {
    return structseq_new_impl(
        ptr[PyTypeObject](args.context), args.values[0], args.values[1]
    );
}

def structseq_new_impl(
    type: ptr[PyTypeObject], arg: ptr[PyObject], dict: ptr[PyObject]
) -> ptr[PyObject] {
    min_len = type_attr_as_size(type, VISIBLE);
    if min_len < 0 {
        return NULL;
    }
    max_len = type_attr_as_size(type, REAL);
    if max_len < 0 {
        return NULL;
    }
    n_unnamed_fields = type_attr_as_size(type, UNNAMED);
    if n_unnamed_fields < 0 {
        return NULL;
    }
    fast = PySequence_Fast(arg, "constructor requires a sequence");
    if not fast {
        return NULL;
    }
    name = type.view(1)[0].tp_name;
    if dict and jacpy_is_dict(dict) == 0 {
        PyErr_Format(
            PyExc_TypeError, "%.500s() takes a dict as second arg, if any", name
        );
        jacpy_release(fast);
        return NULL;
    }
    length = object_size(fast);
    if min_len != max_len {
        if length < min_len {
            PyErr_Format(
                PyExc_TypeError,
                "%.500s() takes an at least %zd-sequence (%zd-sequence given)",
                name,
                min_len,
                length
            );
            jacpy_release(fast);
            return NULL;
        }
        if length > max_len {
            PyErr_Format(
                PyExc_TypeError,
                "%.500s() takes an at most %zd-sequence (%zd-sequence given)",
                name,
                max_len,
                length
            );
            jacpy_release(fast);
            return NULL;
        }
    } elif length != min_len {
        PyErr_Format(
            PyExc_TypeError,
            "%.500s() takes a %zd-sequence (%zd-sequence given)",
            name,
            min_len,
            length
        );
        jacpy_release(fast);
        return NULL;
    }
    res = PyStructSequence_New(ptr[PyObject](type));
    if not res {
        jacpy_release(fast);
        return NULL;
    }
    items = items_of(res);
    source = fast_items(fast);
    for i in range(length) {
        (items + i).view(1)[0] = object_new_ref((source + i).view(1)[0]);
    }
    object_decref(fast);
    if dict and PyDict_Size(dict) > 0 {
        n_found_keys = i64(0);
        members = type.view(1)[0].tp_members;
        for i in range(length, max_len) {
            key = member_name(members, i64(i) - n_unnamed_fields);
            ob = NULL;
            if not key or PyDict_GetItemRef(dict, key, &mut ob) < 0 {
                jacpy_release(key);
                jacpy_release(res);
                return NULL;
            }
            jacpy_release(key);
            if not ob {
                ob = Py_NewRef(Py_None);
            } else {
                n_found_keys += 1;
            }
            (items + i).view(1)[0] = ob;
        }
        if PyDict_Size(dict) > n_found_keys {
            PyErr_Format(
                PyExc_TypeError,
                "%.500s() got duplicate or unexpected field name(s)",
                name
            );
            jacpy_release(res);
            return NULL;
        }
    } else {
        for i in range(length, max_len) {
            (items + i).view(1)[0] = Py_NewRef(Py_None);
        }
    }
    PyObject_GC_Track(res);
    return res;
}

def structseq_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    typ = object_type(op);
    visible = object_size(op);
    type_name = PyUnicode_FromString(typ.view(1)[0].tp_name);
    if not type_name {
        return NULL;
    }
    # count 5 characters per item: "x=1, "
    writer = PyUnicodeWriter_Create(i64(0) + visible * 5 + 2);
    if not writer {
        jacpy_release(type_name);
        return NULL;
    }
    failed = PyUnicodeWriter_WriteStr(writer, type_name) < 0
        or PyUnicodeWriter_WriteChar(writer, u32(40)) < 0;
    jacpy_release(type_name);
    members = typ.view(1)[0].tp_members;
    items = items_of(op);
    i = i64(0);
    while not failed and i < visible {
        if i > 0 {
            # Write ", "
            failed = PyUnicodeWriter_WriteChar(writer, u32(44)) < 0
                or PyUnicodeWriter_WriteChar(writer, u32(32)) < 0;
            if failed {
                break;
            }
        }
        # Write name
        if not (members + i).view(1)[0].name {
            PyErr_Format(
                PyExc_SystemError,
                "In structseq_repr(), member %zd name is NULL for type %.500s",
                i,
                typ.view(1)[0].tp_name
            );
            failed = True;
            break;
        }
        name = member_name(members, i);
        failed = not name or PyUnicodeWriter_WriteStr(writer, name) < 0;
        jacpy_release(name);
        # Write "=" + repr(value)
        failed = failed
            or PyUnicodeWriter_WriteChar(writer, u32(61)) < 0
            or PyUnicodeWriter_WriteRepr(writer, (items + i).view(1)[0]) < 0;
        i += 1;
    }
    if failed or PyUnicodeWriter_WriteChar(writer, u32(41)) < 0 {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

def structseq_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    n_fields = get_real_size(op);
    n_visible_fields = object_size(op);
    n_unnamed_fields = type_attr_as_size(object_type(op), UNNAMED);
    if n_unnamed_fields < 0 {
        return NULL;
    }
    items = items_of(op);
    tup = _PyTuple_FromArray(items, n_visible_fields);
    if not tup {
        return NULL;
    }
    dict = PyDict_New();
    if not dict {
        jacpy_release(tup);
        return NULL;
    }
    members = object_type(op).view(1)[0].tp_members;
    for i in range(n_visible_fields, n_fields) {
        key = member_name(members, i64(i) - n_unnamed_fields);
        if not key or PyDict_SetItem(dict, key, (items + i).view(1)[0]) < 0 {
            jacpy_release(key);
            jacpy_release(tup);
            jacpy_release(dict);
            return NULL;
        }
        jacpy_release(key);
    }
    result = Py_BuildValue("(O(OO))", object_type(op), tup, dict);
    jacpy_release(tup);
    jacpy_release(dict);
    return result;
}

def structseq_replace(
    op: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if args and _PyArg_NoPositional("__replace__", args) == 0 {
        return NULL;
    }
    n_fields = get_real_size(op);
    n_unnamed_fields = type_attr_as_size(object_type(op), UNNAMED);
    if n_unnamed_fields < 0 {
        return NULL;
    }
    if n_unnamed_fields > 0 {
        PyErr_Format(
            PyExc_TypeError,
            "__replace__() is not supported for %.500s because it has unnamed field(s)",
            object_type(op).view(1)[0].tp_name
        );
        return NULL;
    }
    result = PyStructSequence_New(ptr[PyObject](object_type(op)));
    if not result {
        return NULL;
    }
    items = items_of(op);
    result_items = items_of(result);
    if kwargs {
        # Types with unnamed fields are not supported, so members index the
        # fields directly.
        members = object_type(op).view(1)[0].tp_members;
        for i in range(n_fields) {
            key = member_name(members, i64(i));
            ob = NULL;
            if not key or PyDict_Pop(kwargs, key, &mut ob) < 0 {
                jacpy_release(key);
                jacpy_release(result);
                return NULL;
            }
            jacpy_release(key);
            if not ob {
                ob = Py_NewRef((items + i).view(1)[0]);
            }
            (result_items + i).view(1)[0] = ob;
        }
        # Check if there are any unexpected fields.
        if PyDict_Size(kwargs) > 0 {
            names = PyDict_Keys(kwargs);
            if names {
                PyErr_Format(
                    PyExc_TypeError, "Got unexpected field name(s): %R", names
                );
                jacpy_release(names);
            }
            jacpy_release(result);
            return NULL;
        }
    } else {
        # Just create a copy of the original.
        for i in range(n_fields) {
            (result_items + i).view(1)[0] = Py_NewRef((items + i).view(1)[0]);
        }
    }
    PyObject_GC_Track(result);
    return result;
}

# ---------------------------------------------------------------- type setup
"""Whether a descriptor field is the unnamed marker (compared by address)."""
def is_unnamed(name: ptr[u8]) -> bool {
    return int(name) == int(PyStructSequence_UnnamedField);
}

# The number of fields of `desc` and how many of them are unnamed.
def count_members(desc: ptr[PyStructSequence_Desc]) -> tuple[i64, i64] {
    fields = desc.view(1)[0].fields;
    i = i64(0);
    unnamed = i64(0);
    while (fields + i).view(1)[0].name {
        if is_unnamed((fields + i).view(1)[0].name) {
            unnamed += 1;
        }
        i += 1;
    }
    return (i, unnamed);
}

# n_sequence_fields, n_fields, n_unnamed_fields and __match_args__ in the
# type's dict; -1 with the error set on failure.
def initialize_structseq_dict(
    desc: ptr[PyStructSequence_Desc],
    dict: ptr[PyObject],
    n_members: i64,
    n_unnamed_members: i64
) -> i32 {
    n_in_sequence = i64(desc.view(1)[0].n_in_sequence);
    sizes = [n_in_sequence, n_members, n_unnamed_members];
    for which in range(3) {
        v = PyLong_FromSsize_t(sizes[which]);
        if not v {
            return i32(-1);
        }
        key = PyUnicode_InternFromString(SIZE_KEY_NAMES[which]);
        failed = not key or PyDict_SetItem(dict, key, v) < 0;
        jacpy_release(key);
        jacpy_release(v);
        if failed {
            return i32(-1);
        }
    }
    # Prepare and set __match_args__
    keys = PyTuple_New(n_in_sequence);
    if not keys {
        return i32(-1);
    }
    fields = desc.view(1)[0].fields;
    k = i64(0);
    for i in range(n_in_sequence) {
        name = (fields + i).view(1)[0].name;
        if is_unnamed(name) {
            continue;
        }
        new_member = PyUnicode_FromString(name);
        if not new_member {
            jacpy_release(keys);
            return i32(-1);
        }
        (tuple_items(keys) + k).view(1)[0] = new_member;
        k += 1;
    }
    if _PyTuple_Resize(&mut keys, k) == -1 {
        jacpy_release(keys);
        return i32(-1);
    }
    key = PyUnicode_InternFromString("__match_args__");
    failed = not key or PyDict_SetItem(dict, key, keys) < 0;
    jacpy_release(key);
    jacpy_release(keys);
    return i32(-1) if failed else i32(0);
}

# The tp_members of a struct sequence type, in PyMem memory the type keeps;
# NULL with the error set.
def initialize_members(
    desc: ptr[PyStructSequence_Desc], n_members: i64, n_unnamed_members: i64
) -> ptr[PyMemberDef] {
    members = ptr[PyMemberDef](
        PyMem_Malloc(u64((n_members - n_unnamed_members + 1) * PY_MEMBER_DEF_SIZE))
    );
    if not members {
        PyErr_NoMemory();
        return members;
    }
    fields = desc.view(1)[0].fields;
    k = i64(0);
    for i in range(n_members) {
        field = fields + i;
        if is_unnamed(field.view(1)[0].name) {
            continue;
        }
        # The names and docstrings in these member definitions are statically
        # allocated, so they outlive them.
        member = members + k;
        member.view(1)[0].name = field.view(1)[0].name;
        member.view(1)[0].type_ = _Py_T_OBJECT;
        member.view(1)[0].offset = PyTupleObject_ITEMS + i64(i) * 8;
        member.view(1)[0].flags = Py_READONLY;
        member.view(1)[0].doc = field.view(1)[0].doc;
        k += 1;
    }
    (members + k).view(1)[0].name = ptr[u8]();
    return members;
}

def initialize_static_fields(
    type: ptr[PyTypeObject],
    desc: ptr[PyStructSequence_Desc],
    tp_members: ptr[PyMemberDef],
    n_members: i64,
    tp_flags: u64
) {
    type.view(1)[0].tp_name = desc.view(1)[0].name;
    # Account for hidden members in tp_basicsize because they are not
    # included in the variable size.
    n_hidden = n_members - i64(desc.view(1)[0].n_in_sequence);
    type.view(1)[0].tp_basicsize = PyStructSequence_SIZE + (n_hidden - 1) * 8;
    type.view(1)[0].tp_itemsize = 8;
    type.view(1)[0].tp_dealloc = structseq_dealloc;
    type.view(1)[0].tp_repr = structseq_repr;
    type.view(1)[0].tp_doc = desc.view(1)[0].doc;
    type.view(1)[0].tp_base = addressof(PyTuple_Type);
    type.view(1)[0].tp_methods = addressof(structseq_methods);
    type.view(1)[0].tp_new = structseq_new;
    type.view(1)[0].tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | tp_flags;
    type.view(1)[0].tp_traverse = int(ptr(structseq_traverse));
    type.view(1)[0].tp_members = tp_members;
}

import from c {
    def _PyStructSequence_InitBuiltinWithFlags(
        interp: ptr[PyInterpreterState],
        type_object: ptr[PyObject],
        desc: ptr[PyStructSequence_Desc],
        tp_flags: u64
    ) -> i32 {
        type = ptr[PyTypeObject](type_object);
        if not ptr[_object](type).view(1)[0].ob_type {
            ptr[_object](type).view(1)[0].ob_type = addressof(PyType_Type);
        }
        (n_members, n_unnamed_members) = count_members(desc);
        members = ptr[PyMemberDef]();
        if (type.view(1)[0].tp_flags & Py_TPFLAGS_READY) == u64(0) {
            members = initialize_members(desc, n_members, n_unnamed_members);
            if not members {
                return i32(-1);
            }
            initialize_static_fields(type, desc, members, n_members, tp_flags);
            _Py_SetImmortal(ptr[PyObject](type));
        }
        if _PyStaticType_InitBuiltin(interp, ptr[PyObject](type)) < 0 {
            PyErr_Format(
                PyExc_RuntimeError,
                "Can't initialize builtin type %s",
                desc.view(1)[0].name
            );
            PyMem_Free(ptr(members));
            return i32(-1);
        }
        if initialize_structseq_dict(
            desc, _PyType_GetDict(ptr[PyObject](type)), n_members, n_unnamed_members
        )
            < 0 {
            PyMem_Free(ptr(members));
            return i32(-1);
        }
        return i32(0);
    }  def PyStructSequence_InitType2(
        type_object: ptr[PyObject], desc: ptr[PyStructSequence_Desc]
    ) -> i32 {
        type = ptr[PyTypeObject](type_object);
        # The type object has already been initialized.
        if (ptr[_object](type).view(1)[0].ob_refcnt_full & i64(4294967295)) != 0 {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        (n_members, n_unnamed_members) = count_members(desc);
        members = initialize_members(desc, n_members, n_unnamed_members);
        if not members {
            return i32(-1);
        }
        initialize_static_fields(type, desc, members, n_members, u64(0));
        if PyType_Ready(ptr[PyObject](type)) < 0 {
            PyMem_Free(ptr(members));
            return i32(-1);
        }
        Py_IncRef(ptr[PyObject](type));
        if initialize_structseq_dict(
            desc, _PyType_GetDict(ptr[PyObject](type)), n_members, n_unnamed_members
        )
            < 0 {
            jacpy_release(ptr[PyObject](type));
            PyMem_Free(ptr(members));
            return i32(-1);
        }
        return i32(0);
    }  def PyStructSequence_InitType(
        type_object: ptr[PyObject], desc: ptr[PyStructSequence_Desc]
    ) {
        PyStructSequence_InitType2(type_object, desc);
    }
    # Only called on builtin static types, which are all initialized by
    # _PyStructSequence_InitBuiltinWithFlags().
    def _PyStructSequence_FiniBuiltin(
        interp: ptr[PyInterpreterState], type_object: ptr[PyObject]
    ) {
        type = ptr[PyTypeObject](type_object);
        # Cannot delete a type if it still has subclasses
        if _PyType_HasSubclasses(ptr[PyObject](type)) != 0 {
            return;
        }
        _PyStaticType_FiniBuiltin(interp, ptr[PyObject](type));
        if interp == PyInterpreterState_Main() {
            # Undo _PyStructSequence_InitBuiltinWithFlags().
            type.view(1)[0].tp_name = ptr[u8]();
            PyMem_Free(ptr(type.view(1)[0].tp_members));
            type.view(1)[0].tp_members = ptr[PyMemberDef]();
            type.view(1)[0].tp_base = ptr[PyTypeObject]();
        }
    }  def _PyStructSequence_NewType(
        desc: ptr[PyStructSequence_Desc], tp_flags: u64
    ) -> ptr[PyObject] {
        (n_members, n_unnamed_members) = count_members(desc);
        members = initialize_members(desc, n_members, n_unnamed_members);
        if not members {
            return NULL;
        }
        slots = ptr[PyType_Slot](PyMem_Malloc(u64(8 * PY_TYPE_SLOT_SIZE)));
        spec = ptr[PyType_Spec](PyMem_Malloc(u64(PY_TYPE_SPEC_SIZE)));
        if not slots or not spec {
            PyMem_Free(ptr(slots));
            PyMem_Free(ptr(spec));
            PyMem_Free(ptr(members));
            PyErr_NoMemory();
            return NULL;
        }
        entries = [
            (Py_tp_dealloc, ptr(structseq_dealloc)),
            (Py_tp_repr, ptr(structseq_repr)),
            (Py_tp_doc, ptr(desc.view(1)[0].doc)),
            (Py_tp_methods, ptr(addressof(structseq_methods))),
            (Py_tp_new, ptr(structseq_new)),
            (Py_tp_members, ptr(members)),
            (Py_tp_traverse, ptr(structseq_traverse)),
            (i32(0), ptr())
        ];
        for i in range(8) {
            (slots + i).view(1)[0].slot = entries[i][0];
            (slots + i).view(1)[0].pfunc = entries[i][1];
        }
        # The name in this spec is statically allocated, so it outlives it.
        hidden = n_members - i64(desc.view(1)[0].n_in_sequence);
        spec.view(1)[0].name = desc.view(1)[0].name;
        spec.view(1)[0].basicsize = i32(PyStructSequence_SIZE + (hidden - 1) * 8);
        spec.view(1)[0].itemsize = 8;
        spec.view(1)[0].flags = u32(Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | tp_flags);
        spec.view(1)[0].slots = slots;
        type = PyType_FromSpecWithBases(spec, ptr[PyObject](addressof(PyTuple_Type)));
        PyMem_Free(ptr(slots));
        PyMem_Free(ptr(spec));
        PyMem_Free(ptr(members));
        if not type {
            return NULL;
        }
        if initialize_structseq_dict(
            desc, _PyType_GetDict(type), n_members, n_unnamed_members
        )
            < 0 {
            jacpy_release(type);
            return NULL;
        }
        return type;
    }  def PyStructSequence_NewType(desc: ptr[PyStructSequence_Desc]) -> ptr[PyObject] {
        return _PyStructSequence_NewType(desc, u64(0));
    }
}
