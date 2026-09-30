"""The slice type and the Ellipsis singleton: Objects/sliceobject.c in native
Jac.

`PySlice_Type`, `PyEllipsis_Type` and `_Py_EllipsisObject` (Py_Ellipsis) are
C data Jac defines under their C names, and the slice API (`PySlice_New`,
`PySlice_Unpack`, `PySlice_AdjustIndices`, `_PyBuildSlice_ConsumeRefs`,
`_PySlice_GetLongIndices`, ...) C functions under theirs, so the evaluator's
BUILD_SLICE and the C API use them unchanged. `PySliceObject` comes from
layouts.jac; slices are recycled through the interpreter's freelist as
sliceobject.c does. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_UnpackTuple,
    PyDict_Size,
    PyErr_SetString,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyLong_GetSign,
    PyMemberDef,
    PyMethodDef,
    PyNumber_Add,
    PyNumber_Index,
    PyObject,
    PyObject_GC_Del,
    PyObject_GenericGetAttr,
    PyObject_Hash,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    PyTuple_Pack,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyArg_NoKeywords,
    _PyEval_SliceIndex,
    _PyObject_GC_New,
    _Py_SetImmortal,
    jacpy_is_long,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_NOARGS,
    METH_O,
    PySliceObject,
    PySliceObject_SIZE,
    PySliceObject_START,
    PySliceObject_STEP,
    PySliceObject_STOP,
    PyTypeObject,
    PyVarObject,
    Py_EQ,
    Py_GE,
    Py_GT,
    Py_LE,
    Py_LT,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_slices_MAXFREELIST,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_T_OBJECT,
    _Py_freelists_SLICES,
    _object
}
import from jaclang.runtime.python.object_model.header {
    _Py_FalseStruct,
    _Py_TrueStruct,
    freelist_pop,
    freelist_push,
    object_gc_track,
    object_gc_untrack,
    object_is_type,
    object_size,
    object_type,
    PyType_Type
}
import from jaclang.runtime.python.bindings.module { visit_reference }

# code based on tuplehash() of Objects/tupleobject.c (64-bit Py_uhash_t)
glob:priv XXPRIME_1: u64 = 11400714785074694791,
     XXPRIME_2: u64 = 14029467366897019727,
     XXPRIME_5: u64 = 2870177450012600261;

import from c {
    glob:priv ellipsis_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(ellipsis_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         slice_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("start"),
                 type_=_Py_T_OBJECT,
                 offset=PySliceObject_START,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("stop"),
                 type_=_Py_T_OBJECT,
                 offset=PySliceObject_STOP,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("step"),
                 type_=_Py_T_OBJECT,
                 offset=PySliceObject_STEP,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         slice_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("indices"),
                 ml_meth=ptr(slice_indices),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "S.indices(len) -> (start, stop, stride)\n\n"
                     "Assuming a sequence of length len, calculate the start and stop\n"
                     "indices, and the stride length of the extended slice described by\n"
                     "S. Out of bounds indices are clipped in a manner consistent with the\n"
                     "handling of normal slices."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(slice_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyEllipsis_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("ellipsis"),
             tp_dealloc=ellipsis_dealloc,
             tp_repr=ellipsis_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8]("ellipsis()\n--\n\nThe type of the Ellipsis singleton."),
             tp_methods=addressof(ellipsis_methods),
             tp_new=ellipsis_new
         ),
         # Py_Ellipsis, the '...' rubber index token: like Py_None, the one
         # object of its type.
         _Py_EllipsisObject: _object = _object(
             ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
             ob_type=addressof(PyEllipsis_Type)
         ),
         PySlice_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("slice"),
             tp_basicsize=PySliceObject_SIZE,
             tp_dealloc=slice_dealloc,
             tp_repr=slice_repr,
             tp_hash=slice_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "slice(stop)\n"
                 "slice(start, stop[, step])\n\n"
                 "Create a slice object.\n\n"
                 "This is used for extended slicing (e.g. a[0:10:2])."
             ),
             tp_traverse=slice_traverse,
             tp_richcompare=slice_richcompare,
             tp_methods=addressof(slice_methods),
             tp_members=addressof(slice_members),
             tp_new=slice_new
         );
}

# ---------------------------------------------------------------- Ellipsis
"""Py_Ellipsis."""
def py_ellipsis -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_EllipsisObject));
}

def ellipsis_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if object_size(args) != 0 or (kwargs and PyDict_Size(kwargs) != 0) {
        PyErr_SetString(PyExc_TypeError, "EllipsisType takes no arguments");
        return NULL;
    }
    return py_ellipsis();
}

# This should never get called, but we also don't want to SEGV if we
# accidentally decref Ellipsis out of existence. Instead, since Ellipsis is
# an immortal object, re-set the reference count.
def ellipsis_dealloc(ellipsis: ptr[PyObject]) {
    _Py_SetImmortal(ellipsis);
}

def ellipsis_repr(_op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString("Ellipsis");
}

def ellipsis_reduce(_op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromString("Ellipsis");
}

# ---------------------------------------------------------------- slices
# start, stop, and step are python objects with None indicating no index is
# present.

def slice_of(op: ptr[PyObject]) -> ptr[PySliceObject] {
    return ptr[PySliceObject](op);
}

"""PySlice_Check."""
def slice_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PySlice_Type));
}

# A slice owning `start` and `stop` (stolen) and a new reference to `step`,
# from the freelist when it has one.
def build_slice_consume2(
    start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]
) -> ptr[PyObject] {
    op = freelist_pop(_Py_freelists_SLICES);
    if not op {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PySlice_Type)));
        if not op {
            jacpy_release(start);
            jacpy_release(stop);
            return NULL;
        }
    }
    slice = slice_of(op);
    slice.view(1)[0].start = start;
    slice.view(1)[0].stop = stop;
    slice.view(1)[0].step = Py_NewRef(step);
    object_gc_track(op);
    return op;
}

import from c {
    def PySlice_New(
        start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not step {
            step = Py_None;
        }
        if not start {
            start = Py_None;
        }
        if not stop {
            stop = Py_None;
        }
        return build_slice_consume2(Py_NewRef(start), Py_NewRef(stop), step);
    }  def _PyBuildSlice_ConsumeRefs(
        start: ptr[PyObject], stop: ptr[PyObject]
    ) -> ptr[PyObject] {
        return build_slice_consume2(start, stop, Py_None);
    }  def _PySlice_FromIndices(istart: i64, istop: i64) -> ptr[PyObject] {
        start = PyLong_FromSsize_t(istart);
        if not start {
            return NULL;
        }
        end = PyLong_FromSsize_t(istop);
        if not end {
            jacpy_release(start);
            return NULL;
        }
        slice = PySlice_New(start, end, NULL);
        jacpy_release(start);
        jacpy_release(end);
        return slice;
    }  def PySlice_GetIndices(
        op: ptr[PyObject], length: i64, start: ptr[i64], stop: ptr[i64], step: ptr[i64]
    ) -> i32 {
        r = slice_of(op);
        # XXX support long ints
        if r.view(1)[0].step == Py_None {
            step.view(1)[0] = 1;
        } else {
            if jacpy_is_long(r.view(1)[0].step) == 0 {
                return i32(-1);
            }
            step.view(1)[0] = PyLong_AsSsize_t(r.view(1)[0].step);
        }
        if r.view(1)[0].start == Py_None {
            start.view(1)[0] = length - 1 if step.view(1)[0] < 0 else i64(0);
        } else {
            if jacpy_is_long(r.view(1)[0].start) == 0 {
                return i32(-1);
            }
            start.view(1)[0] = PyLong_AsSsize_t(r.view(1)[0].start);
            if start.view(1)[0] < 0 {
                start.view(1)[0] += length;
            }
        }
        if r.view(1)[0].stop == Py_None {
            stop.view(1)[0] = i64(-1) if step.view(1)[0] < 0 else length;
        } else {
            if jacpy_is_long(r.view(1)[0].stop) == 0 {
                return i32(-1);
            }
            stop.view(1)[0] = PyLong_AsSsize_t(r.view(1)[0].stop);
            if stop.view(1)[0] < 0 {
                stop.view(1)[0] += length;
            }
        }
        if stop.view(1)[0] > length
            or start.view(1)[0] >= length
            or step.view(1)[0] == 0 {
            return i32(-1);
        }
        return i32(0);
    }  def PySlice_Unpack(
        op: ptr[PyObject], start: ptr[i64], stop: ptr[i64], step: ptr[i64]
    ) -> i32 {
        r = slice_of(op);
        # this is harder to get right than you might think
        value = i64(0);
        if r.view(1)[0].step == Py_None {
            step.view(1)[0] = 1;
        } else {
            if _PyEval_SliceIndex(r.view(1)[0].step, &mut value) == 0 {
                return i32(-1);
            }
            if value == 0 {
                PyErr_SetString(PyExc_ValueError, "slice step cannot be zero");
                return i32(-1);
            }
            # Here the step might be -PY_SSIZE_T_MAX-1; in this case we replace
            # it with -PY_SSIZE_T_MAX. This doesn't affect the semantics, and
            # it guards against later undefined behaviour resulting from code
            # that does "step = -step" as part of a slice reversal.
            if value < -i64.MAX {
                value = -i64.MAX;
            }
            step.view(1)[0] = value;
        }
        if r.view(1)[0].start == Py_None {
            start.view(1)[0] = i64.MAX if step.view(1)[0] < 0 else i64(0);
        } else {
            if _PyEval_SliceIndex(r.view(1)[0].start, &mut value) == 0 {
                return i32(-1);
            }
            start.view(1)[0] = value;
        }
        if r.view(1)[0].stop == Py_None {
            stop.view(1)[0] = i64.MIN if step.view(1)[0] < 0 else i64.MAX;
        } else {
            if _PyEval_SliceIndex(r.view(1)[0].stop, &mut value) == 0 {
                return i32(-1);
            }
            stop.view(1)[0] = value;
        }
        return i32(0);
    }  def PySlice_AdjustIndices(
        length: i64, start: ptr[i64], stop: ptr[i64], step: i64
    ) -> i64 {
        # this is harder to get right than you might think
        if start.view(1)[0] < 0 {
            start.view(1)[0] += length;
            if start.view(1)[0] < 0 {
                start.view(1)[0] = i64(-1) if step < 0 else i64(0);
            }
        } elif start.view(1)[0] >= length {
            start.view(1)[0] = length - 1 if step < 0 else length;
        }
        if stop.view(1)[0] < 0 {
            stop.view(1)[0] += length;
            if stop.view(1)[0] < 0 {
                stop.view(1)[0] = i64(-1) if step < 0 else i64(0);
            }
        } elif stop.view(1)[0] >= length {
            stop.view(1)[0] = length - 1 if step < 0 else length;
        }
        if step < 0 {
            if stop.view(1)[0] < start.view(1)[0] {
                return (start.view(1)[0] - stop.view(1)[0] - 1) // (-step) + 1;
            }
        } elif start.view(1)[0] < stop.view(1)[0] {
            return (stop.view(1)[0] - start.view(1)[0] - 1) // step + 1;
        }
        return 0;
    }  def PySlice_GetIndicesEx(
        op: ptr[PyObject],
        length: i64,
        start: ptr[i64],
        stop: ptr[i64],
        step: ptr[i64],
        slicelength: ptr[i64]
    ) -> i32 {
        if PySlice_Unpack(op, start, stop, step) < 0 {
            return i32(-1);
        }
        slicelength.view(1)[0] = PySlice_AdjustIndices(
            length, start, stop, step.view(1)[0]
        );
        return i32(0);
    }
}

def slice_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    start = NULL;
    stop = NULL;
    step = NULL;
    if kw and _PyArg_NoKeywords("slice", kw) == 0 {
        return NULL;
    }
    if PyArg_UnpackTuple(args, "slice", 1, 3, &mut start, &mut stop, &mut step) == 0 {
        return NULL;
    }
    # This swapping of stop and start is to maintain similarity with range().
    if not stop {
        stop = start;
        start = NULL;
    }
    return PySlice_New(start, stop, step);
}

def slice_dealloc(op: ptr[PyObject]) {
    slice = slice_of(op);
    object_gc_untrack(op);
    jacpy_release(slice.view(1)[0].step);
    jacpy_release(slice.view(1)[0].start);
    jacpy_release(slice.view(1)[0].stop);
    if not freelist_push(_Py_freelists_SLICES, op, Py_slices_MAXFREELIST) {
        PyObject_GC_Del(op);
    }
}

def slice_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    r = slice_of(op);
    return PyUnicode_FromFormat(
        "slice(%R, %R, %R)", r.view(1)[0].start, r.view(1)[0].stop, r.view(1)[0].step
    );
}

# Convert a slice argument to a PyLong, and raise TypeError with a suitable
# message on failure.
def evaluate_slice_index(v: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(v) != 0 {
        return PyNumber_Index(v);
    }
    PyErr_SetString(
        PyExc_TypeError,
        "slice indices must be integers or None or have an __index__ method"
    );
    return NULL;
}

"""_PyLong_IsNegative for an int."""
def long_is_negative(value: ptr[PyObject]) -> bool {
    sign = i32(0);
    PyLong_GetSign(value, &mut sign);
    return sign < 0;
}

# An index clipped to [lower, upper] after adding `length` when negative, as
# slice.indices computes start and stop; a new reference, NULL on error.
def clip_long_index(
    index: ptr[PyObject],
    length: ptr[PyObject],
    lower: ptr[PyObject],
    upper: ptr[PyObject]
) -> ptr[PyObject] {
    if long_is_negative(index) {
        # index += length
        shifted = PyNumber_Add(index, length);
        jacpy_release(index);
        if not shifted {
            return NULL;
        }
        below = PyObject_RichCompareBool(shifted, lower, Py_LT);
        if below < 0 {
            jacpy_release(shifted);
            return NULL;
        }
        if below != 0 {
            jacpy_release(shifted);
            return Py_NewRef(lower);
        }
        return shifted;
    }
    above = PyObject_RichCompareBool(index, upper, Py_GT);
    if above < 0 {
        jacpy_release(index);
        return NULL;
    }
    if above != 0 {
        jacpy_release(index);
        return Py_NewRef(upper);
    }
    return index;
}

# Compute slice indices given a slice and length: (start, stop, step) as new
# references, or three NULLs with the error set. Used by slice.indices and
# range slicing. Assumes that `length` is a nonnegative instance of PyLong.
def slice_get_long_indices(
    op: ptr[PyObject], length: ptr[PyObject]
) -> tuple[ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    r = slice_of(op);
    start = NULL;
    stop = NULL;
    step = NULL;
    upper = NULL;
    lower = NULL;
    failed = False;
    step_is_negative = False;
    # Convert step to an integer; raise for zero step.
    if r.view(1)[0].step == Py_None {
        step = PyLong_FromLong(1);
    } else {
        step = evaluate_slice_index(r.view(1)[0].step);
        if not step {
            failed = True;
        } else {
            step_sign = i32(0);
            PyLong_GetSign(step, &mut step_sign);
            if step_sign == 0 {
                PyErr_SetString(PyExc_ValueError, "slice step cannot be zero");
                failed = True;
            }
            step_is_negative = step_sign < 0;
        }
    }
    # Find lower and upper bounds for start and stop.
    if not failed {
        if step_is_negative {
            lower = PyLong_FromLong(-1);
            upper = PyNumber_Add(length, lower) if lower else NULL;
            failed = not upper;
        } else {
            lower = PyLong_FromLong(0);
            upper = Py_NewRef(length);
        }
    }
    # Compute start.
    if not failed {
        if r.view(1)[0].start == Py_None {
            start = Py_NewRef(upper if step_is_negative else lower);
        } else {
            start = evaluate_slice_index(r.view(1)[0].start);
            if start {
                start = clip_long_index(start, length, lower, upper);
            }
            failed = not start;
        }
    }
    # Compute stop.
    if not failed {
        if r.view(1)[0].stop == Py_None {
            stop = Py_NewRef(lower if step_is_negative else upper);
        } else {
            stop = evaluate_slice_index(r.view(1)[0].stop);
            if stop {
                stop = clip_long_index(stop, length, lower, upper);
            }
            failed = not stop;
        }
    }
    jacpy_release(upper);
    jacpy_release(lower);
    if failed {
        jacpy_release(start);
        jacpy_release(stop);
        jacpy_release(step);
        return (NULL, NULL, NULL);
    }
    return (start, stop, step);
}

import from c {
    def _PySlice_GetLongIndices(
        op: ptr[PyObject],
        length: ptr[PyObject],
        start_ptr: ptr[ptr[PyObject]],
        stop_ptr: ptr[ptr[PyObject]],
        step_ptr: ptr[ptr[PyObject]]
    ) -> i32 {
        (start, stop, step) = slice_get_long_indices(op, length);
        start_ptr.view(1)[0] = start;
        stop_ptr.view(1)[0] = stop;
        step_ptr.view(1)[0] = step;
        return i32(-1) if not step else i32(0);
    }
}

# Implementation of slice.indices.
def slice_indices(op: ptr[PyObject], length_arg: ptr[PyObject]) -> ptr[PyObject] {
    # Convert length to an integer if necessary; raise for negative length.
    length = PyNumber_Index(length_arg);
    if not length {
        return NULL;
    }
    if long_is_negative(length) {
        PyErr_SetString(PyExc_ValueError, "length should not be negative");
        jacpy_release(length);
        return NULL;
    }
    (start, stop, step) = slice_get_long_indices(op, length);
    jacpy_release(length);
    if not step {
        return NULL;
    }
    return Py_BuildValue("(NNN)", start, stop, step);
}

def slice_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    r = slice_of(op);
    return Py_BuildValue(
        "O(OOO)",
        object_type(op),
        r.view(1)[0].start,
        r.view(1)[0].stop,
        r.view(1)[0].step
    );
}

def slice_richcompare(v: ptr[PyObject], w: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not slice_check(v) or not slice_check(w) {
        return Py_NewRef(Py_NotImplemented);
    }
    if v == w {
        # XXX Do we really need this shortcut?
        # There's a unit test for it, but is that fair?
        if op == Py_EQ or op == Py_LE or op == Py_GE {
            return ptr[PyObject](addressof(_Py_TrueStruct));
        }
        return ptr[PyObject](addressof(_Py_FalseStruct));
    }
    a = slice_of(v);
    t1 = PyTuple_Pack(3, a.view(1)[0].start, a.view(1)[0].stop, a.view(1)[0].step);
    if not t1 {
        return NULL;
    }
    b = slice_of(w);
    t2 = PyTuple_Pack(3, b.view(1)[0].start, b.view(1)[0].stop, b.view(1)[0].step);
    if not t2 {
        jacpy_release(t1);
        return NULL;
    }
    result = PyObject_RichCompare(t1, t2, op);
    jacpy_release(t1);
    jacpy_release(t2);
    return result;
}

def slice_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    v = slice_of(op);
    status = visit_reference(v.view(1)[0].start, visitor, arg);
    if status == 0 {
        status = visit_reference(v.view(1)[0].stop, visitor, arg);
    }
    if status == 0 {
        status = visit_reference(v.view(1)[0].step, visitor, arg);
    }
    return status;
}

# One xxHash round: fold a component's hash into the accumulator.
def slice_hash_round(acc: u64, lane: u64) -> u64 {
    acc = wrapping_add(acc, wrapping_mul(lane, XXPRIME_2));
    acc = wrapping_shl(acc, u64(31)) | (acc >> u64(33));  # Rotate left 31 bits
    return wrapping_mul(acc, XXPRIME_1);
}

def slice_hash(op: ptr[PyObject]) -> i64 {
    v = slice_of(op);
    lane = u64.wrap(PyObject_Hash(v.view(1)[0].start));
    if lane == u64.MAX {
        return -1;
    }
    acc = slice_hash_round(XXPRIME_5, lane);
    lane = u64.wrap(PyObject_Hash(v.view(1)[0].stop));
    if lane == u64.MAX {
        return -1;
    }
    acc = slice_hash_round(acc, lane);
    lane = u64.wrap(PyObject_Hash(v.view(1)[0].step));
    if lane == u64.MAX {
        return -1;
    }
    acc = slice_hash_round(acc, lane);
    if acc == u64.MAX {
        return 1546275796;
    }
    return i64.wrap(acc);
}
