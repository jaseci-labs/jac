# Objects/capsule.c ported to native Jac.
#
# PyCapsule: wraps a C void* for hand-off between extension modules. The
# struct is the C layout (head + pointer + name + context + destructor +
# traverse_func + clear_func = 64 bytes); PyCapsule_Type is a glob:pub
# static over the shared 53-field type layout.
#
# Residue here: the GC-track macros (_PyObject_GC_IS_TRACKED/_PyObject_GC_TRACK
# write GC header bits), the in-place `*dot++ = 0` split in PyCapsule_Import,
# and the varargs formatters (PyUnicode_FromFormat with %p, two PyErr_Format
# %s errors), and the calls through the destructor/traverse/clear function
# pointers (jacpy_capsule_call_*: indirect calls do not lower natively, so
# those fields are opaque `ptr` here). strcmp/strlen stay extern libc calls.


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

    obj PyObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject]();
    }

    # Internal PyCapsule structure.
    obj PyCapsule_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            pointer: ptr = ptr(),
            name: ptr[u8] = ptr[u8](),
            context: ptr = ptr(),
            destructor: ptr = ptr(),
            traverse_func: ptr = ptr(),
            clear_func: ptr = ptr();
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyExc_ValueError: ptr[PyObject];
    glob PyExc_ImportError: ptr[PyObject];
    glob PyExc_AttributeError: ptr[PyObject];

    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyErr_NoMemory() -> ptr[PyObject];
    def _PyObject_GC_New(tp: ptr[PyTypeObject_Layout]) -> ptr[PyObject];
    def PyObject_GC_UnTrack(o: ptr[PyObject]) -> None;
    def PyObject_GC_Del(o: ptr[PyObject]) -> None;
    def strcmp(s1: ptr[u8], s2: ptr[u8]) -> i32;
    def strlen(s: ptr[u8]) -> i64;
    def memcpy(dst: ptr, src: ptr, n: i64) -> ptr;
    def PyMem_Malloc(size: i64) -> ptr;
    def PyMem_Free(p: ptr) -> None;
    def PyImport_ImportModule(name: ptr[u8]) -> ptr[PyObject];
    def PyObject_GetAttrString(o: ptr[PyObject], attr: ptr[u8]) -> ptr[PyObject];
    def jacpy_capsule_is_tracked(o: ptr[PyObject]) -> i32;
    def jacpy_capsule_track(o: ptr[PyObject]) -> None;
    def jacpy_capsule_split(trace: ptr[u8]) -> ptr[u8];
    def jacpy_capsule_repr(o: ptr[PyObject], name: ptr[u8], quote: ptr[u8]) -> ptr[PyObject];
    def jacpy_capsule_import_module_error(trace: ptr[u8]) -> None;
    def jacpy_capsule_import_attr_error(name: ptr[u8]) -> None;
    def jacpy_capsule_call_destructor(fn: ptr, op: ptr[PyObject]) -> None;
    def jacpy_capsule_call_traverse(fn: ptr, op: ptr[PyObject], visitf: ptr, arg: ptr[PyObject]) -> i32;
    def jacpy_capsule_call_clear(fn: ptr, op: ptr[PyObject]) -> i32;
}

def capsule_is_capsule(op: ptr[PyObject]) -> i32 {
    if op == ptr[PyObject]() {
        return 0;
    }
    head = ptr[PyObject_Layout](op);
    ct: ptr[PyObject] = PyCapsule_Type;
    if head.ob_type == ct {
        return 1;
    }
    return 0;
}

def _is_legal_capsule(op: ptr[PyObject], invalid_capsule: ptr[u8]) -> i32 {
    if op == ptr[PyObject]() or not capsule_is_capsule(op) {
        PyErr_SetString(PyExc_ValueError, invalid_capsule);
        return 0;
    }
    capsule = ptr[PyCapsule_Layout](op);
    if capsule.pointer == ptr() {
        PyErr_SetString(PyExc_ValueError, invalid_capsule);
        return 0;
    }
    return 1;
}

def name_matches(name1: ptr[u8], name2: ptr[u8]) -> i32 {
    # If either is NULL, they're only the same if they're both NULL.
    if name1 == ptr[u8]() or name2 == ptr[u8]() {
        if name1 == name2 {
            return 1;
        }
        return 0;
    }
    if not strcmp(name1, name2) {
        return 1;
    }
    return 0;
}

def:pub PyCapsule_New(
    pointer: ptr, name: ptr[u8], destructor: ptr
) -> ptr[PyObject] {
    if not pointer {
        PyErr_SetString(PyExc_ValueError, "PyCapsule_New called with null pointer");
        return ptr[PyObject]();
    }
    cap_obj = _PyObject_GC_New(PyCapsule_Type);
    if cap_obj == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    capsule = ptr[PyCapsule_Layout](cap_obj);
    capsule.pointer = pointer;
    capsule.name = name;
    capsule.context = ptr();
    capsule.destructor = destructor;
    capsule.traverse_func = ptr();
    capsule.clear_func = ptr();
    # Only track the object by the GC when _PyCapsule_SetTraverse() is called.
    return cap_obj;
}

def:pub PyCapsule_IsValid(op: ptr[PyObject], name: ptr[u8]) -> i32 {
    if op == ptr[PyObject]() {
        return 0;
    }
    if not capsule_is_capsule(op) {
        return 0;
    }
    capsule = ptr[PyCapsule_Layout](op);
    if capsule.pointer == ptr() {
        return 0;
    }
    return name_matches(capsule.name, name);
}

def:pub PyCapsule_GetPointer(op: ptr[PyObject], name: ptr[u8]) -> ptr {
    if not _is_legal_capsule(op, "PyCapsule_GetPointer called with invalid PyCapsule object") {
        return ptr();
    }
    capsule = ptr[PyCapsule_Layout](op);
    if not name_matches(name, capsule.name) {
        PyErr_SetString(PyExc_ValueError, "PyCapsule_GetPointer called with incorrect name");
        return ptr();
    }
    return capsule.pointer;
}

def:pub PyCapsule_GetName(op: ptr[PyObject]) -> ptr[u8] {
    if not _is_legal_capsule(op, "PyCapsule_GetName called with invalid PyCapsule object") {
        return ptr[u8]();
    }
    capsule = ptr[PyCapsule_Layout](op);
    return capsule.name;
}

def:pub PyCapsule_GetDestructor(op: ptr[PyObject]) -> ptr {
    if not _is_legal_capsule(op, "PyCapsule_GetDestructor called with invalid PyCapsule object") {
        return ptr();
    }
    capsule = ptr[PyCapsule_Layout](op);
    return capsule.destructor;
}

def:pub PyCapsule_GetContext(op: ptr[PyObject]) -> ptr {
    if not _is_legal_capsule(op, "PyCapsule_GetContext called with invalid PyCapsule object") {
        return ptr();
    }
    capsule = ptr[PyCapsule_Layout](op);
    return capsule.context;
}

def:pub PyCapsule_SetPointer(op: ptr[PyObject], pointer: ptr) -> i32 {
    if not _is_legal_capsule(op, "PyCapsule_SetPointer called with invalid PyCapsule object") {
        return -1;
    }
    capsule = ptr[PyCapsule_Layout](op);
    if not pointer {
        PyErr_SetString(PyExc_ValueError, "PyCapsule_SetPointer called with null pointer");
        return -1;
    }
    capsule.pointer = pointer;
    return 0;
}

def:pub PyCapsule_SetName(op: ptr[PyObject], name: ptr[u8]) -> i32 {
    if not _is_legal_capsule(op, "PyCapsule_SetName called with invalid PyCapsule object") {
        return -1;
    }
    capsule = ptr[PyCapsule_Layout](op);
    capsule.name = name;
    return 0;
}

def:pub PyCapsule_SetDestructor(
    op: ptr[PyObject], destructor: ptr
) -> i32 {
    if not _is_legal_capsule(op, "PyCapsule_SetDestructor called with invalid PyCapsule object") {
        return -1;
    }
    capsule = ptr[PyCapsule_Layout](op);
    capsule.destructor = destructor;
    return 0;
}

def:pub PyCapsule_SetContext(op: ptr[PyObject], context: ptr) -> i32 {
    if not _is_legal_capsule(op, "PyCapsule_SetContext called with invalid PyCapsule object") {
        return -1;
    }
    capsule = ptr[PyCapsule_Layout](op);
    capsule.context = context;
    return 0;
}

def:pub _PyCapsule_SetTraverse(
    op: ptr[PyObject],
    traverse_func: ptr,
    clear_func: ptr
) -> i32 {
    if not _is_legal_capsule(op, "_PyCapsule_SetTraverse called with invalid PyCapsule object") {
        return -1;
    }
    capsule = ptr[PyCapsule_Layout](op);
    if traverse_func == ptr() or clear_func == ptr() {
        PyErr_SetString(
            PyExc_ValueError,
            "_PyCapsule_SetTraverse() called with NULL callback"
        );
        return -1;
    }
    if not jacpy_capsule_is_tracked(op) {
        jacpy_capsule_track(op);
    }
    capsule.traverse_func = traverse_func;
    capsule.clear_func = clear_func;
    return 0;
}

def:pub PyCapsule_Import(name: ptr[u8], no_block: i32) -> ptr {
    mod = ptr[PyObject]();
    return_value = ptr();
    name_length = (strlen(name) + 1);
    name_dup = ptr[u8](PyMem_Malloc(name_length));
    if name_dup == ptr[u8]() {
        PyErr_NoMemory();
        return ptr();
    }

    # memcpy(name_dup, name, name_length)
    memcpy(ptr(name_dup), ptr(name), name_length);

    trace = name_dup;
    while trace != ptr[u8]() {
        dot = jacpy_capsule_split(trace);
        if mod == ptr[PyObject]() {
            mod = PyImport_ImportModule(trace);
            if mod == ptr[PyObject]() {
                jacpy_capsule_import_module_error(trace);
            }
        } else {
            object2 = PyObject_GetAttrString(mod, trace);
            # Py_SETREF(obj, object2)
            py_decref(mod);
            mod = object2;
        }
        if mod == ptr[PyObject]() {
            PyMem_Free(ptr(name_dup));
            return return_value;
        }
        trace = dot;
    }

    # Compare attribute name to module.name by hand.
    if PyCapsule_IsValid(mod, name) {
        capsule = ptr[PyCapsule_Layout](mod);
        return_value = capsule.pointer;
    } else {
        jacpy_capsule_import_attr_error(name);
    }

    py_decref(mod);
    PyMem_Free(ptr(name_dup));
    return return_value;
}

def capsule_dealloc(op: ptr[PyObject]) -> None {
    capsule = ptr[PyCapsule_Layout](op);
    PyObject_GC_UnTrack(op);
    if capsule.destructor != ptr() {
        jacpy_capsule_call_destructor(capsule.destructor, op);
    }
    PyObject_GC_Del(op);
}

def capsule_repr(o: ptr[PyObject]) -> ptr[PyObject] {
    capsule = ptr[PyCapsule_Layout](o);
    if capsule.name != ptr[u8]() {
        return jacpy_capsule_repr(o, capsule.name, "\"");
    }
    return jacpy_capsule_repr(o, "NULL", "");
}

def capsule_traverse(
    self: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    # Tracked by the GC only if _PyCapsule_SetTraverse() was called, but
    # gc.get_referents() can still trigger this.
    capsule = ptr[PyCapsule_Layout](self);
    if capsule.traverse_func != ptr() {
        return jacpy_capsule_call_traverse(capsule.traverse_func, self, visitf, arg);
    }
    return 0;
}

def capsule_clear(self: ptr[PyObject]) -> i32 {
    capsule = ptr[PyCapsule_Layout](self);
    return jacpy_capsule_call_clear(capsule.clear_func, self);
}

glob:pub PyCapsule_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,          # _Py_STATIC_IMMORTAL_INITIAL_REFCNT
    ob_type=PyType_Type,                 # PyVarObject_HEAD_INIT(&PyType_Type, 0)
    ob_size=0,
    tp_name="PyCapsule",
    tp_basicsize=64,                     # sizeof(PyCapsule)
    tp_itemsize=0,
    tp_dealloc=capsule_dealloc,
    tp_repr=capsule_repr,
    tp_flags=16384,                      # Py_TPFLAGS_DEFAULT|HAVE_GC
    tp_doc=(
        "Capsule objects let you wrap a C \"void *\" pointer in a Python\n"
        "object.  They're a way of passing data through the Python interpreter\n"
        "without creating your own custom type.\n"
        "\n"
        "Capsules are used for communication between extension modules.\n"
        "They provide a way for an extension module to export a C interface\n"
        "to other extension modules, so that extension modules can use the\n"
        "Python import mechanism to link to one another.\n"
    ),
    tp_traverse=capsule_traverse,
    tp_clear=capsule_clear
);
