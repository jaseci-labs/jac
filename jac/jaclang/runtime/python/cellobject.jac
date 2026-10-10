# Objects/cellobject.c ported to native Jac.
#
# The cell object model is the C ABI: PyCellObject is the C layout, and
# PyCell_Type is a static type object exported under its C name so the C
# side (frameobject, ceval, object_api.c's runtime-object table) links
# against the Jac definition. Slot functions keep their C names inside this
# file; PyCell_New/PyCell_Get/PyCell_Set and PyCell_Type are exported.
#
# cell_getsetlist is declared as a two-field record rather than PyGetSetDef[2]:
# identical bytes (two consecutive structs, same alignment), so C readers of
# tp_getset see the sentinel-terminated array CPython expects. Static arrays
# are not a native static-initializer form yet.
#
# C residue used here (see the residue table in
# cli/docs/internals/jacpython-migration.md): jacpy_cell_repr (varargs
# PyUnicode_FromFormat plus a tp_name read), jacpy_is_cell (PyCell_Check),
# jacpy_not_implemented and jacpy_exception_type (data symbols).

import from jaclang.runtime.python.refcount { py_incref, py_decref }

import from c {
    obj PyObject;  obj PyUnicodeWriter;  obj PyModuleDef;

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

    obj PyGetSetDef {
        has name: ptr[u8] = ptr[u8](),
            get: Callable[[ptr[PyObject], ptr], ptr[PyObject]] = 0,
            set: Callable[[ptr[PyObject], ptr[PyObject], ptr], i32] = 0,
            doc: ptr[u8] = ptr[u8](),
            closure: ptr = ptr();
    }

    # Byte-identical stand-in for `PyGetSetDef cell_getsetlist[] = {..., {NULL}}`.
    obj CellGetSetList {
        has first: PyGetSetDef,
            sentinel: PyGetSetDef;
    }

    obj PyCellObject {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            ob_ref: ptr[PyObject] = ptr[PyObject]();
    }

    glob PyType_Type: PyTypeObject_Layout;

    def _PyObject_GC_New(tp: ptr[PyTypeObject_Layout]) -> ptr[PyObject];
    def PyObject_GC_Track(op: ptr[PyObject]) -> None;
    def PyObject_GC_UnTrack(op: ptr[PyObject]) -> None;
    def PyObject_GC_Del(op: ptr[PyObject]) -> None;
    # Py_VISIT: `visit` is a C function pointer, not a Jac Callable.
    def jacpy_visit(visitf: ptr, o: ptr[PyObject], arg: ptr) -> i32;
    # PyBool_FromLong is defined natively in boolobject.jac; declaring it as a
    # C extern here would shadow that definition at link time.
    def jacpy_bool_true() -> ptr[PyObject];
    def jacpy_bool_false() -> ptr[PyObject];
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_RichCompare(a: ptr[PyObject], b: ptr[PyObject], opid: i32) -> ptr[PyObject];
    def PyTuple_Size(p: ptr[PyObject]) -> i64;
    def PyTuple_GetItem(p: ptr[PyObject], index: i64) -> ptr[PyObject];
    def _PyArg_NoKeywords(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def PyErr_BadInternalCall() -> None;
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def jacpy_is_cell(handle: ptr[PyObject]) -> i64;
    def jacpy_is_tuple(handle: ptr[PyObject]) -> i64;
    def jacpy_cell_new_too_many(nargs: i64) -> None;
    def jacpy_cell_repr(self: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_exception_type(kind: ptr[u8]) -> ptr[PyObject];
    def jacpy_not_implemented() -> ptr[PyObject];
}

glob:pub PyCell_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    1,                                   # ob_refcnt
    PyType_Type,                         # ob_type
    0,                                   # ob_size
    "cell",                              # tp_name
    24,                                  # tp_basicsize: sizeof(PyCellObject), LP64
    0,                                   # tp_itemsize
    cell_dealloc,                        # tp_dealloc
    0,                                   # tp_vectorcall_offset
    0,                                   # tp_getattr
    0,                                   # tp_setattr
    ptr(),                               # tp_as_async
    cell_repr,                           # tp_repr
    ptr(),                               # tp_as_number
    ptr(),                               # tp_as_sequence
    ptr(),                               # tp_as_mapping
    0,                                   # tp_hash
    0,                                   # tp_call
    0,                                   # tp_str
    PyObject_GenericGetAttr,             # tp_getattro
    0,                                   # tp_setattro
    ptr(),                               # tp_as_buffer
    16384,                               # tp_flags: Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC
    (
        "cell([contents])\n"
        "--\n"
        "\n"
        "Create a new cell object.\n"
        "\n"
        "  contents\n"
        "    the contents of the cell. If not specified, the cell will be empty,\n"
        "    and \n further attempts to access its cell_contents attribute will\n"
        "    raise a ValueError."
    ),                                   # tp_doc
    cell_traverse,                       # tp_traverse
    cell_clear,                          # tp_clear
    cell_richcompare,                    # tp_richcompare
    0,                                   # tp_weaklistoffset
    ptr[PyObject](),                     # tp_iter
    ptr[PyObject](),                     # tp_iternext
    ptr(),                               # tp_methods
    ptr(),                               # tp_members
    cell_getsetlist,                     # tp_getset
    ptr[PyTypeObject_Layout](),          # tp_base
    ptr[PyObject](),                     # tp_dict
    ptr[PyObject](),                     # tp_descr_get
    ptr[PyObject](),                     # tp_descr_set
    0,                                   # tp_dictoffset
    0,                                   # tp_init
    0,                                   # tp_alloc
    cell_new,                            # tp_new
    0,                                   # tp_free
    0,                                   # tp_is_gc
    ptr[PyObject](),                     # tp_bases
    ptr[PyObject](),                     # tp_mro
    ptr[PyObject](),                     # tp_cache
    ptr(),                               # tp_subclasses
    ptr[PyObject](),                     # tp_weaklist
    0,                                   # tp_del
    0,                                   # tp_version_tag
    0,                                   # tp_finalize
    0,                                   # tp_vectorcall
    0,                                   # tp_watched
    0                                    # tp_versions_used
);

glob cell_getsetlist: CellGetSetList = CellGetSetList(
    PyGetSetDef(
        "cell_contents",
        cell_get_contents,
        cell_set_contents,
        ptr[u8](),
        ptr()
    )
);

def cell_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if kwargs {
        if not _PyArg_NoKeywords("cell", kwargs) {
            return ptr[PyObject]();
        }
    }
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return ptr[PyObject]();
    }
    nargs = PyTuple_Size(args);
    if nargs > 1 {
        jacpy_cell_new_too_many(nargs);
        return ptr[PyObject]();
    }
    ob = ptr[PyObject]();
    if nargs == 1 {
        ob = PyTuple_GetItem(args, 0);
        if not ob {
            return ptr[PyObject]();
        }
    }
    return PyCell_New(ob);
}

def _cell_bool(v: bool) -> ptr[PyObject] {
    if v {
        return jacpy_bool_true();
    }
    return jacpy_bool_false();
}

def:pub PyCell_New(ob: ptr[PyObject]) -> ptr[PyObject] {
    op = _PyObject_GC_New(PyCell_Type);
    if not op {
        return ptr[PyObject]();
    }
    cell = ptr[PyCellObject](op);
    if ob {
        py_incref(ob);
    }
    cell.ob_ref = ob;
    PyObject_GC_Track(op);
    return op;
}

def:pub PyCell_Get(op: ptr[PyObject]) -> ptr[PyObject] {
    if not jacpy_is_cell(op) {
        PyErr_BadInternalCall();
        return ptr[PyObject]();
    }
    cell = ptr[PyCellObject](op);
    res = cell.ob_ref;
    if res {
        py_incref(res);
    }
    return res;
}

def:pub PyCell_Set(op: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    if not jacpy_is_cell(op) {
        PyErr_BadInternalCall();
        return -1;
    }
    cell = ptr[PyCellObject](op);
    if value {
        py_incref(value);
    }
    old_value = cell.ob_ref;
    cell.ob_ref = value;
    if old_value {
        py_decref(old_value);
    }
    return 0;
}

def cell_dealloc(self: ptr[PyObject]) -> None {
    PyObject_GC_UnTrack(self);
    cell = ptr[PyCellObject](self);
    old_ref = cell.ob_ref;
    if old_ref {
        py_decref(old_ref);
    }
    PyObject_GC_Del(self);
}

def cell_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cell_repr(self);
}

def cell_traverse(self: ptr[PyObject], visitf: ptr, arg: ptr) -> i32 {
    # Py_VISIT(cell->ob_ref)
    cell = ptr[PyCellObject](self);
    ref = cell.ob_ref;
    if ref {
        vret = jacpy_visit(visitf, ref, arg);
        if vret {
            return vret;
        }
    }
    return 0;
}

def cell_clear(self: ptr[PyObject]) -> i32 {
    # PyCell_SetTakeRef(op, NULL) without the XNewRef half
    cell = ptr[PyCellObject](self);
    old_value = cell.ob_ref;
    cell.ob_ref = ptr[PyObject]();
    if old_value {
        py_decref(old_value);
    }
    return 0;
}

def cell_richcompare(
    a: ptr[PyObject], b: ptr[PyObject], opid: i32
) -> ptr[PyObject] {
    if not jacpy_is_cell(a) or not jacpy_is_cell(b) {
        return jacpy_not_implemented();
    }
    a_ref = PyCell_Get(a);
    b_ref = PyCell_Get(b);
    res: ptr[PyObject] = ptr[PyObject]();
    if a_ref and b_ref {
        res = PyObject_RichCompare(a_ref, b_ref, opid);
    } else {
        # Py_RETURN_RICHCOMPARE(b == NULL, a == NULL, op):
        # empty cells come before anything else.
        left: i32 = 0;
        right: i32 = 0;
        if not b_ref {
            left = 1;
        }
        if not a_ref {
            right = 1;
        }
        if opid == 2 {
            res = _cell_bool(left == right);
        } elif opid == 3 {
            res = _cell_bool(left != right);
        } elif opid == 0 {
            res = _cell_bool(left < right);
        } elif opid == 1 {
            res = _cell_bool(left <= right);
        } elif opid == 4 {
            res = _cell_bool(left > right);
        } else {
            res = _cell_bool(left >= right);
        }
    }
    if a_ref {
        py_decref(a_ref);
    }
    if b_ref {
        py_decref(b_ref);
    }
    return res;
}

def cell_get_contents(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    cell = ptr[PyCellObject](self);
    res = cell.ob_ref;
    if res {
        py_incref(res);
        return res;
    }
    PyErr_SetString(
        jacpy_exception_type("ValueError"), "Cell is empty"
    );
    return ptr[PyObject]();
}

def cell_set_contents(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    cell = ptr[PyCellObject](self);
    if value {
        py_incref(value);
    }
    old_value = cell.ob_ref;
    cell.ob_ref = value;
    if old_value {
        py_decref(old_value);
    }
    return 0;
}
