# Objects/sliceobject.c ported to native Jac.
#
# Two things live here: the Ellipsis singleton (PyEllipsis_Type +
# _Py_EllipsisObject, the Py_Ellipsis macro target) and slice objects
# (PySlice_Type over PySliceObject: head + start + stop + step = 40 bytes).
#
# The C-API index helpers keep their exact C ABI (def:pub, called from
# ceval/containers): PySlice_Unpack/GetIndices/GetIndicesEx write through
# the caller's Py_ssize_t pointers — pointer writes and the u64 hash mixing
# are C residue for now (jacpy_slice_* helpers below). The freelist is
# dropped: allocations go straight through PyObject_GC_New/Del.
#
# Long sign/tag facts (from boolobject.jac): lv_tag low two bits encode the
# sign as (1 - sign) → 0: positive, 1: zero, 2: negative.
#
# Residue: jacpy_slice_repr/indices_tuple/reduce_tuple/pack3 (%R/%O
# formatters), jacpy_slice_too_few/too_many (UnpackTuple arg-count errors),
# jacpy_long_zero (static inline), jacpy_ptr_store3 (pointer out-param
# stores), jacpy_slice_hash (u64 xxHash rotation), and the
# _PySlice_GetLongIndices implementation detail: the C ABI out-pointers are
# served from an internal record; the pub wrapper stores through the
# callers' pointers with residue.

import from jaclang.runtime.python.boolobject { PyLongObject_Layout, PyNumberMethods }

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

    obj PyMethodDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }

    obj PyMemberDef_Layout {
        has name: ptr[u8] = ptr[u8](),
            type: i32 = 0,
            offset: i64 = 0,
            flags: i32 = 0,
            doc: ptr[u8] = ptr[u8]();
    }

    obj _Slice_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout(),
            e2: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    obj _Slice_Members {
        has e0: PyMemberDef_Layout = PyMemberDef_Layout(),
            e1: PyMemberDef_Layout = PyMemberDef_Layout(),
            e2: PyMemberDef_Layout = PyMemberDef_Layout(),
            e3: PyMemberDef_Layout = PyMemberDef_Layout();
    }

    obj _Ellipsis_Methods {
        has e0: PyMethodDef_Layout = PyMethodDef_Layout(),
            e1: PyMethodDef_Layout = PyMethodDef_Layout();
    }

    # PySliceObject
    obj PySliceObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            start: ptr[PyObject] = ptr[PyObject](),
            stop: ptr[PyObject] = ptr[PyObject](),
            step: ptr[PyObject] = ptr[PyObject]();
    }

    # Internal result record for the long-indices computation.
    obj _GliResult {
        has start: ptr[PyObject] = ptr[PyObject](),
            stop: ptr[PyObject] = ptr[PyObject](),
            step: ptr[PyObject] = ptr[PyObject](),
            ok: i32 = 0;
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyLong_Type: PyTypeObject_Layout;
    # Py_True/Py_False are C macros (no linkable symbol): the residue returns
    # new references to the singletons.
    def jacpy_bool_true() -> ptr[PyObject];
    def jacpy_bool_false() -> ptr[PyObject];
    # Py_None / Py_NotImplemented are macros over these exported structs.
    glob _Py_NoneStruct: PyObject_Layout;
    glob _Py_NotImplementedStruct: PyObject_Layout;
    glob PyExc_TypeError: ptr[PyObject];
    glob PyExc_ValueError: ptr[PyObject];

    # Py_VISIT: `visit` is a C function pointer, not a Jac Callable.
    def jacpy_visit(visitf: ptr, o: ptr[PyObject], arg: ptr) -> i32;
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyErr_Clear() -> None;
    def PyErr_ExceptionMatches(exc: ptr[PyObject]) -> i32;
    def _Py_SetImmortal(o: ptr[PyObject]) -> None;
    def PyObject_GC_UnTrack(o: ptr[PyObject]) -> None;
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_RichCompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];
    def PyObject_RichCompareBool(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> i32;
    def PyType_IsSubtype(a: ptr[PyTypeObject_Layout], b: ptr[PyTypeObject_Layout]) -> i32;
    def PyUnicode_FromString(s: ptr[u8]) -> ptr[PyObject];
    def PyLong_FromSsize_t(v: i64) -> ptr[PyObject];
    def PyLong_AsSsize_t(v: ptr[PyObject]) -> i64;
    def PyNumber_Index(o: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Add(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyDict_Size(d: ptr[PyObject]) -> i64;
    def PyTuple_Size(p: ptr[PyObject]) -> i64;
    def PyTuple_GetItem(p: ptr[PyObject], index: i64) -> ptr[PyObject];
    def _PyEval_SliceIndex(v: ptr[PyObject], out: ptr[i64]) -> i32;
    def _PyArg_NoKeywords(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def jacpy_is_tuple(handle: ptr[PyObject]) -> i64;
    def jacpy_exception_type(kind: ptr[u8]) -> ptr[PyObject];
    def jacpy_capsule_track(o: ptr[PyObject]) -> None;
    # The `slices` freelist (per-thread interpreter state, reached through
    # pycore_freelist.h's inline helpers): pop or GC-allocate, push or free.
    def jacpy_slice_alloc() -> ptr[PyObject];
    def jacpy_slice_free(o: ptr[PyObject]) -> None;
    def jacpy_long_one() -> ptr[PyObject];
    def jacpy_long_zero() -> ptr[PyObject];
    def jacpy_slice_too_few(nargs: i64) -> None;
    def jacpy_slice_too_many(nargs: i64) -> None;
    def jacpy_slice_repr(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_slice_indices_tuple(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_slice_reduce_tuple(tp: ptr[PyObject], start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_slice_pack3(a: ptr[PyObject], b: ptr[PyObject], c: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_slice_hash(o: ptr[PyObject]) -> i64;
    def jacpy_isize_load(p: ptr[i64]) -> i64;
    def jacpy_isize_store(p: ptr[i64], v: i64) -> None;
    def jacpy_ptr_store3(a: ptr[ptr[PyObject]], b: ptr[ptr[PyObject]], c: ptr[ptr[PyObject]], s: ptr[PyObject], t: ptr[PyObject], u: ptr[PyObject]) -> None;
}

# lv_tag sign encoding: (1 - sign) in the low two bits.
def long_sign(o: ptr[PyObject]) -> i32 {
    l = ptr[PyLongObject_Layout](o);
    return i32(1 - (l.lv_tag & 3));
}

def long_is_negative(o: ptr[PyObject]) -> i32 {
    if long_sign(o) < 0 {
        return 1;
    }
    return 0;
}

# PyLong_Check: exact int or a subtype.
def _slice_is_long(v: ptr[PyObject]) -> i32 {
    head = ptr[PyObject_Layout](v);
    lt: ptr[PyObject] = PyLong_Type;
    if head.ob_type == lt {
        return 1;
    }
    if PyType_IsSubtype(ptr[PyTypeObject_Layout](head.ob_type), ptr[PyTypeObject_Layout](lt)) != 0 {
        return 1;
    }
    return 0;
}

# _PyIndex_Check: type has an nb_index slot.
def index_check(v: ptr[PyObject]) -> i32 {
    head = ptr[PyObject_Layout](v);
    ty = ptr[PyTypeObject_Layout](head.ob_type);
    if ty.tp_as_number == ptr() {
        return 0;
    }
    num = ptr[PyNumberMethods](ty.tp_as_number);
    if num.nb_index != 0 {
        return 1;
    }
    return 0;
}

# ------------------------------- Ellipsis -----------------------------------

def ellipsis_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if PyTuple_Size(args) != 0 {
        PyErr_SetString(PyExc_TypeError, "EllipsisType takes no arguments");
        return ptr[PyObject]();
    }
    if kwargs != ptr[PyObject]() and PyDict_Size(kwargs) != 0 {
        PyErr_SetString(PyExc_TypeError, "EllipsisType takes no arguments");
        return ptr[PyObject]();
    }
    e: ptr[PyObject] = _Py_EllipsisObject;
    return e;
}

def ellipsis_dealloc(ellipsis: ptr[PyObject]) -> None {
    # Immortal: re-set the reference count instead of dying.
    _Py_SetImmortal(ellipsis);
}

def ellipsis_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString("Ellipsis");
}

def ellipsis_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString("Ellipsis");
}

glob ellipsis_methods: _Ellipsis_Methods = _Ellipsis_Methods(
    e0=PyMethodDef_Layout(name="__reduce__", ml_meth=ellipsis_reduce, ml_flags=4)
);

glob:pub PyEllipsis_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="ellipsis",
    tp_basicsize=0,
    tp_itemsize=0,
    tp_dealloc=ellipsis_dealloc,
    tp_repr=ellipsis_repr,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=0,
    tp_doc=(
        "ellipsis()\n"
        "--\n"
        "\n"
        "The type of the Ellipsis singleton."
    ),
    tp_methods=ellipsis_methods,
    tp_new=ellipsis_new
);

glob:pub _Py_EllipsisObject: PyObject_Layout = PyObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyEllipsis_Type
);

# ------------------------------ slice object --------------------------------

# _PyBuildSlice_Consume2: takes references (start/stop consumed on failure).
def _PyBuildSlice_Consume2(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject] {
    allocated = jacpy_slice_alloc();
    if allocated == ptr[PyObject]() {
        py_decref(start);
        py_decref(stop);
        return ptr[PyObject]();
    }
    r = ptr[PySliceObject_Layout](allocated);
    r.start = start;
    r.stop = stop;
    r.step = step;
    py_incref(step);
    jacpy_capsule_track(allocated);
    return allocated;
}

def:pub PySlice_New(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    if step == ptr[PyObject]() {
        step = none_obj;
    }
    if start == ptr[PyObject]() {
        start = none_obj;
    }
    if stop == ptr[PyObject]() {
        stop = none_obj;
    }
    py_incref(start);
    py_incref(stop);
    return _PyBuildSlice_Consume2(start, stop, step);
}

def:pub _PyBuildSlice_ConsumeRefs(start: ptr[PyObject], stop: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    n: ptr[PyObject] = none_obj;
    return _PyBuildSlice_Consume2(start, stop, n);
}

def:pub _PySlice_FromIndices(istart: i64, istop: i64) -> ptr[PyObject] {
    start = PyLong_FromSsize_t(istart);
    if start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    end = PyLong_FromSsize_t(istop);
    if end == ptr[PyObject]() {
        py_decref(start);
        return ptr[PyObject]();
    }
    slice = PySlice_New(start, end, ptr[PyObject]());
    py_decref(start);
    py_decref(end);
    return slice;
}

def:pub PySlice_GetIndices(
    _r: ptr[PyObject], length: i64, start: ptr[i64], stop: ptr[i64], step: ptr[i64]
) -> i32 {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    r = ptr[PySliceObject_Layout](_r);
    nn: ptr[PyObject] = none_obj;
    if r.step == nn {
        jacpy_isize_store(step, 1);
    } else {
        if not _slice_is_long(r.step) {
            return -1;
        }
        jacpy_isize_store(step, PyLong_AsSsize_t(r.step));
    }
    if r.start == nn {
        if jacpy_isize_load(step) < 0 {
            jacpy_isize_store(start, length - 1);
        } else {
            jacpy_isize_store(start, 0);
        }
    } else {
        if not _slice_is_long(r.start) {
            return -1;
        }
        v = PyLong_AsSsize_t(r.start);
        if v < 0 {
            v = v + length;
        }
        jacpy_isize_store(start, v);
    }
    if r.stop == nn {
        if jacpy_isize_load(step) < 0 {
            jacpy_isize_store(stop, -1);
        } else {
            jacpy_isize_store(stop, length);
        }
    } else {
        if not _slice_is_long(r.stop) {
            return -1;
        }
        v = PyLong_AsSsize_t(r.stop);
        if v < 0 {
            v = v + length;
        }
        jacpy_isize_store(stop, v);
    }
    if jacpy_isize_load(stop) > length {
        return -1;
    }
    if jacpy_isize_load(start) >= length {
        return -1;
    }
    if jacpy_isize_load(step) == 0 {
        return -1;
    }
    return 0;
}

def:pub PySlice_Unpack(
    _r: ptr[PyObject], start: ptr[i64], stop: ptr[i64], step: ptr[i64]
) -> i32 {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    r = ptr[PySliceObject_Layout](_r);
    nn: ptr[PyObject] = none_obj;
    max_ssize = 9223372036854775807;
    min_ssize = -9223372036854775807 - 1;

    if r.step == nn {
        jacpy_isize_store(step, 1);
    } else {
        if not _PyEval_SliceIndex(r.step, step) {
            return -1;
        }
        if jacpy_isize_load(step) == 0 {
            PyErr_SetString(PyExc_ValueError, "slice step cannot be zero");
            return -1;
        }
        # Replace -PY_SSIZE_T_MAX-1 with -PY_SSIZE_T_MAX; semantics are
        # unchanged and it guards later `step = -step` reversal overflow.
        if jacpy_isize_load(step) < -max_ssize {
            jacpy_isize_store(step, -max_ssize);
        }
    }

    if r.start == nn {
        if jacpy_isize_load(step) < 0 {
            jacpy_isize_store(start, max_ssize);
        } else {
            jacpy_isize_store(start, 0);
        }
    } else {
        if not _PyEval_SliceIndex(r.start, start) {
            return -1;
        }
    }

    if r.stop == nn {
        if jacpy_isize_load(step) < 0 {
            jacpy_isize_store(stop, min_ssize);
        } else {
            jacpy_isize_store(stop, max_ssize);
        }
    } else {
        if not _PyEval_SliceIndex(r.stop, stop) {
            return -1;
        }
    }

    return 0;
}

def:pub PySlice_AdjustIndices(length: i64, start: ptr[i64], stop: ptr[i64], step: i64) -> i64 {
    s = jacpy_isize_load(start);
    e = jacpy_isize_load(stop);

    if s < 0 {
        s = s + length;
        if s < 0 {
            if step < 0 {
                s = -1;
            } else {
                s = 0;
            }
        }
    } elif s >= length {
        if step < 0 {
            s = length - 1;
        } else {
            s = length;
        }
    }

    if e < 0 {
        e = e + length;
        if e < 0 {
            if step < 0 {
                e = -1;
            } else {
                e = 0;
            }
        }
    } elif e >= length {
        if step < 0 {
            e = length - 1;
        } else {
            e = length;
        }
    }

    jacpy_isize_store(start, s);
    jacpy_isize_store(stop, e);

    if step < 0 {
        if e < s {
            return (s - e - 1) // (-step) + 1;
        }
    } else {
        if s < e {
            return (e - s - 1) // step + 1;
        }
    }
    return 0;
}

def:pub PySlice_GetIndicesEx(
    _r: ptr[PyObject], length: i64, start: ptr[i64], stop: ptr[i64], step: ptr[i64],
    slicelength: ptr[i64]
) -> i32 {
    if PySlice_Unpack(_r, start, stop, step) < 0 {
        return -1;
    }
    v = PySlice_AdjustIndices(length, start, stop, jacpy_isize_load(step));
    jacpy_isize_store(slicelength, v);
    return 0;
}

def slice_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    if kw != ptr[PyObject]() and not _PyArg_NoKeywords("slice", kw) {
        return ptr[PyObject]();
    }
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return ptr[PyObject]();
    }
    nargs = PyTuple_Size(args);
    if nargs < 1 {
        jacpy_slice_too_few(nargs);
        return ptr[PyObject]();
    }
    if nargs > 3 {
        jacpy_slice_too_many(nargs);
        return ptr[PyObject]();
    }
    start = PyTuple_GetItem(args, 0);
    if start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    stop = ptr[PyObject]();
    step = ptr[PyObject]();
    if nargs >= 2 {
        stop = PyTuple_GetItem(args, 1);
        if stop == ptr[PyObject]() {
            return ptr[PyObject]();
        }
    }
    if nargs >= 3 {
        step = PyTuple_GetItem(args, 2);
        if step == ptr[PyObject]() {
            return ptr[PyObject]();
        }
    }
    # This swapping of stop and start is to maintain similarity with range().
    if stop == ptr[PyObject]() {
        stop = start;
        start = ptr[PyObject]();
    }
    return PySlice_New(start, stop, step);
}

def slice_dealloc(op: ptr[PyObject]) -> None {
    r = ptr[PySliceObject_Layout](op);
    PyObject_GC_UnTrack(op);
    py_decref(r.step);
    py_decref(r.start);
    py_decref(r.stop);
    jacpy_slice_free(op);
}

def slice_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PySliceObject_Layout](op);
    return jacpy_slice_repr(r.start, r.stop, r.step);
}

glob slice_members: _Slice_Members = _Slice_Members(
    e0=PyMemberDef_Layout(name="start", type=6, offset=16, flags=1),
    e1=PyMemberDef_Layout(name="stop", type=6, offset=24, flags=1),
    e2=PyMemberDef_Layout(name="step", type=6, offset=32, flags=1)
);

def evaluate_slice_index(v: ptr[PyObject]) -> ptr[PyObject] {
    if index_check(v) {
        return PyNumber_Index(v);
    }
    PyErr_SetString(
        PyExc_TypeError,
        "slice indices must be integers or None or have an __index__ method"
    );
    return ptr[PyObject]();
}

# Compute start/stop as PyLongs for slice.indices; -1 on error (partials
# cleaned internally, mirroring the C error path).
def _slice_gli_impl(self_op: ptr[PyObject], length: ptr[PyObject]) -> _GliResult {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    res = _GliResult();
    self = ptr[PySliceObject_Layout](self_op);
    nn: ptr[PyObject] = none_obj;

    if self.step == nn {
        res.step = jacpy_long_one();
        step_is_negative = 0;
    } else {
        res.step = evaluate_slice_index(self.step);
        if res.step == ptr[PyObject]() {
            res.ok = -1;
            return res;
        }
        sign = long_sign(res.step);
        if sign == 0 {
            PyErr_SetString(PyExc_ValueError, "slice step cannot be zero");
            py_decref(res.step);
            res.step = ptr[PyObject]();
            res.ok = -1;
            return res;
        }
        if sign < 0 {
            step_is_negative = 1;
        } else {
            step_is_negative = 0;
        }
    }

    # Find lower and upper bounds for start and stop.
    if step_is_negative == 1 {
        lower = PyLong_FromSsize_t(-1);
        if lower == ptr[PyObject]() {
            py_decref(res.step);
            res.step = ptr[PyObject]();
            res.ok = -1;
            return res;
        }
        upper = PyNumber_Add(length, lower);
        if upper == ptr[PyObject]() {
            py_decref(lower);
            py_decref(res.step);
            res.step = ptr[PyObject]();
            res.ok = -1;
            return res;
        }
    } else {
        lower = jacpy_long_zero();
        upper = length;
        py_incref(upper);
    }

    # Compute start.
    if self.start == nn {
        if step_is_negative == 1 {
            res.start = upper;
        } else {
            res.start = lower;
        }
        py_incref(res.start);
    } else {
        res.start = evaluate_slice_index(self.start);
        if res.start != ptr[PyObject]() {
            res.start = _slice_clip_to_bound(res.start, length, lower, upper);
        }
        if res.start == ptr[PyObject]() {
            py_decref(lower);
            py_decref(upper);
            py_decref(res.step);
            res.step = ptr[PyObject]();
            res.ok = -1;
            return res;
        }
    }

    # Compute stop.
    if self.stop == nn {
        if step_is_negative == 1 {
            res.stop = lower;
        } else {
            res.stop = upper;
        }
        py_incref(res.stop);
    } else {
        res.stop = evaluate_slice_index(self.stop);
        if res.stop != ptr[PyObject]() {
            res.stop = _slice_clip_to_bound(res.stop, length, lower, upper);
        }
        if res.stop == ptr[PyObject]() {
            py_decref(res.start);
            res.start = ptr[PyObject]();
            py_decref(lower);
            py_decref(upper);
            py_decref(res.step);
            res.step = ptr[PyObject]();
            res.ok = -1;
            return res;
        }
    }

    py_decref(upper);
    py_decref(lower);
    res.ok = 0;
    return res;
}

def _slice_clip_to_bound(v: ptr[PyObject], length: ptr[PyObject], lower: ptr[PyObject], upper: ptr[PyObject]) -> ptr[PyObject] {
    # Negative: v += length, clip against lower. Non-negative: clip against
    # upper. Errors propagate as NULL.
    if long_is_negative(v) {
        tmp = PyNumber_Add(v, length);
        if tmp == ptr[PyObject]() {
            return ptr[PyObject]();
        }
        py_decref(v);
        v = tmp;
        cmp_result = PyObject_RichCompareBool(v, lower, 0);
        if cmp_result < 0 {
            return ptr[PyObject]();
        }
        if cmp_result != 0 {
            py_decref(v);
            v = lower;
            py_incref(v);
        }
        return v;
    }
    cmp_result = PyObject_RichCompareBool(v, upper, 4);
    if cmp_result < 0 {
        return ptr[PyObject]();
    }
    if cmp_result != 0 {
        py_decref(v);
        v = upper;
        py_incref(v);
    }
    return v;
}

def:pub _PySlice_GetLongIndices(
    self_op: ptr, length: ptr,
    start_ptr: ptr, stop_ptr: ptr, step_ptr: ptr
) -> i32 {
    res = _slice_gli_impl(ptr[PyObject](self_op), ptr[PyObject](length));
    jacpy_ptr_store3(
        ptr[ptr[PyObject]](start_ptr),
        ptr[ptr[PyObject]](stop_ptr),
        ptr[ptr[PyObject]](step_ptr),
        res.start,
        res.stop,
        res.step
    );
    return res.ok;
}

def slice_indices(op: ptr[PyObject], len: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    # Length to an integer; raise for negative length.
    length = PyNumber_Index(len);
    if length == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if long_is_negative(length) {
        PyErr_SetString(PyExc_ValueError, "length should not be negative");
        py_decref(length);
        return ptr[PyObject]();
    }

    res = _slice_gli_impl(op, length);
    py_decref(length);
    if res.ok == -1 {
        return ptr[PyObject]();
    }
    return jacpy_slice_indices_tuple(res.start, res.stop, res.step);
}

glob slice_methods: _Slice_Methods = _Slice_Methods(
    e0=PyMethodDef_Layout(
        name="indices",
        ml_meth=slice_indices,
        ml_flags=8,
        ml_doc=(
            "S.indices(len) -> (start, stop, stride)\n"
            "\n"
            "Assuming a sequence of length len, calculate the start and stop\n"
            "indices, and the stride length of the extended slice described by\n"
            "S. Out of bounds indices are clipped in a manner consistent with the\n"
            "handling of normal slices."
        )
    ),
    e1=PyMethodDef_Layout(
        name="__reduce__",
        ml_meth=slice_reduce,
        ml_flags=4,
        ml_doc="Return state information for pickling."
    )
);

def slice_reduce(op: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    self = ptr[PySliceObject_Layout](op);
    head = ptr[PyObject_Layout](op);
    return jacpy_slice_reduce_tuple(head.ob_type, self.start, self.stop, self.step);
}

def slice_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    notimpl_obj: ptr[PyObject] = _Py_NotImplementedStruct;
    if not slice_is_slice(v) or not slice_is_slice(w) {
        py_incref(notimpl_obj);
        return notimpl_obj;
    }

    if v == w {
        # Shortcut: identical objects compare equal/le/ge as themselves.
        if op == 2 or op == 1 or op == 5 {
            return jacpy_bool_true();
        }
        return jacpy_bool_false();
    }

    s1 = ptr[PySliceObject_Layout](v);
    s2 = ptr[PySliceObject_Layout](w);
    t1 = jacpy_slice_pack3(s1.start, s1.stop, s1.step);
    if t1 == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    t2 = jacpy_slice_pack3(s2.start, s2.stop, s2.step);
    if t2 == ptr[PyObject]() {
        py_decref(t1);
        return ptr[PyObject]();
    }
    res = PyObject_RichCompare(t1, t2, op);
    py_decref(t1);
    py_decref(t2);
    return res;
}

def slice_is_slice(v: ptr) -> i32 {
    head = ptr[PyObject_Layout](v);
    st: ptr[PyObject] = PySlice_Type;
    if head.ob_type == st {
        return 1;
    }
    return 0;
}

def slice_traverse(
    op: ptr[PyObject],
    visitf: ptr,
    arg: ptr[PyObject]
) -> i32 {
    v = ptr[PySliceObject_Layout](op);
    if v.start != ptr[PyObject]() {
        vret = jacpy_visit(visitf, v.start, arg);
        if vret != 0 {
            return vret;
        }
    }
    if v.stop != ptr[PyObject]() {
        vret = jacpy_visit(visitf, v.stop, arg);
        if vret != 0 {
            return vret;
        }
    }
    if v.step != ptr[PyObject]() {
        vret = jacpy_visit(visitf, v.step, arg);
        if vret != 0 {
            return vret;
        }
    }
    return 0;
}

glob:pub PySlice_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    ob_size=0,
    tp_name="slice",
    tp_basicsize=40,
    tp_itemsize=0,
    tp_dealloc=slice_dealloc,
    tp_repr=slice_repr,
    tp_hash=jacpy_slice_hash,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=16384,
    tp_doc=(
        "slice(stop)\n"
        "slice(start, stop[, step])\n"
        "\n"
        "Create a slice object.\n"
        "\n"
        "This is used for extended slicing (e.g. a[0:10:2])."
    ),
    tp_traverse=slice_traverse,
    tp_richcompare=slice_richcompare,
    tp_methods=slice_methods,
    tp_members=slice_members,
    tp_new=slice_new
);
