"""The range type and its iterators: Objects/rangeobject.c in native Jac.

`PyRange_Type`, `PyRangeIter_Type` and `PyLongRangeIter_Type` are C data Jac
defines under their C names, so the builtins module, the evaluator's
FOR_ITER_RANGE specialization (which reads `_PyRangeIterObject` directly) and
C code use them unchanged. The object layouts come from layouts.jac; range
objects and C-long range iterators are recycled through the interpreter's
freelists as rangeobject.c does. Lengths above PY_SSIZE_T_MAX are supported
with int arithmetic. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_BadArgument,
    PyErr_Clear,
    PyErr_Format,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_IndexError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyLong_AsLong,
    PyLong_AsLongAndOverflow,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyLong_GetSign,
    PyMemberDef,
    PyMethodDef,
    PyNumber_Add,
    PyNumber_AsSsize_t,
    PyNumber_FloorDivide,
    PyNumber_Index,
    PyNumber_Multiply,
    PyNumber_Negative,
    PyNumber_Remainder,
    PyNumber_Subtract,
    PyObject,
    PyObject_Free,
    PyObject_GenericGetAttr,
    PyObject_Hash,
    PyObject_IsTrue,
    PyObject_Not,
    PyObject_RichCompareBool,
    PyObject_SelfIter,
    PyTuple_New,
    PyUnicode_FromFormat,
    PyVectorcall_NARGS,
    Py_BuildValue,
    Py_IncRef,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    _PyArg_NoKeywords,
    _PyArg_NoKwnames,
    _PyObject_New,
    _PySequence_IterSearch,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    METH_NOARGS,
    METH_O,
    PyMappingMethods,
    PyNumberMethods,
    PySequenceMethods,
    PyTypeObject,
    PyVarObject,
    PY_ITERSEARCH_CONTAINS,
    PY_ITERSEARCH_COUNT,
    PY_ITERSEARCH_INDEX,
    Py_EQ,
    Py_GE,
    Py_GT,
    Py_LE,
    Py_LT,
    Py_NE,
    Py_READONLY,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_SEQUENCE,
    Py_T_OBJECT_EX,
    Py_range_iters_MAXFREELIST,
    Py_ranges_MAXFREELIST,
    _PyRangeIterObject,
    _PyRangeIterObject_SIZE,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _Py_freelists_RANGES,
    _Py_freelists_RANGE_ITERS,
    _object,
    longrangeiterobject,
    longrangeiterobject_SIZE,
    rangeobject,
    rangeobject_SIZE,
    rangeobject_START,
    rangeobject_STEP,
    rangeobject_STOP
}
import from jaclang.runtime.python.object_model.header {
    PyType_Type,
    _Py_FalseStruct,
    _Py_TrueStruct,
    eval_builtin,
    freelist_pop,
    freelist_push,
    object_is_type,
    object_size,
    object_type,
    tuple_items,
    tuple_set_item
}
import from jaclang.runtime.python.object_model.bool { bool_check }
import from jaclang.runtime.python.object_model.slice {
    slice_check,
    slice_get_long_indices
}

import from c {
    glob PyLong_Type: PyTypeObject; glob:priv range_as_sequence:
             PySequenceMethods = PySequenceMethods(
             sq_length=range_length, sq_item=range_item, sq_contains=range_contains
         ),
         range_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=range_length, mp_subscript=range_subscript
         ),
         range_as_number: PyNumberMethods = PyNumberMethods(nb_bool=range_bool),
         range_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reversed__"),
                 ml_meth=ptr(range_reverse),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return a reverse iterator.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(range_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(range_count),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "rangeobject.count(value) -> integer -- return number of occurrences of value"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(range_index),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "rangeobject.index(value) -> integer -- return index of value.\n"
                     "Raise ValueError if the value is not present."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         range_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("start"),
                 type_=Py_T_OBJECT_EX,
                 offset=rangeobject_START,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("stop"),
                 type_=Py_T_OBJECT_EX,
                 offset=rangeobject_STOP,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("step"),
                 type_=Py_T_OBJECT_EX,
                 offset=rangeobject_STEP,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         rangeiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(rangeiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(rangeiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(rangeiter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         longrangeiter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(longrangeiter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(longrangeiter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(longrangeiter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyRange_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("range"),
             tp_basicsize=rangeobject_SIZE,
             tp_dealloc=range_dealloc,
             tp_repr=range_repr,
             tp_as_number=addressof(range_as_number),
             tp_as_sequence=addressof(range_as_sequence),
             tp_as_mapping=addressof(range_as_mapping),
             tp_hash=range_hash,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_SEQUENCE,
             tp_doc=ptr[u8](
                 "range(stop) -> range object\n"
                 "range(start, stop[, step]) -> range object\n\n"
                 "Return an object that produces a sequence of integers from start (inclusive)\n"
                 "to stop (exclusive) by step.  range(i, j) produces i, i+1, i+2, ..., j-1.\n"
                 "start defaults to 0, and stop is omitted!  range(4) produces 0, 1, 2, 3.\n"
                 "These are exactly the valid indices for a list of 4 elements.\n"
                 "When step is given, it specifies the increment (or decrement)."
             ),
             tp_richcompare=range_richcompare,
             tp_iter=range_iter,
             tp_methods=addressof(range_methods),
             tp_members=addressof(range_members),
             tp_new=range_new,
             tp_vectorcall=range_vectorcall
         ),
         PyRangeIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("range_iterator"),
             tp_basicsize=_PyRangeIterObject_SIZE,
             tp_dealloc=rangeiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_iter=PyObject_SelfIter,
             tp_iternext=rangeiter_next,
             tp_methods=addressof(rangeiter_methods)
         ),
         PyLongRangeIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("longrange_iterator"),
             tp_basicsize=longrangeiterobject_SIZE,
             tp_dealloc=longrangeiter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_iter=PyObject_SelfIter,
             tp_iternext=longrangeiter_next,
             tp_methods=addressof(longrangeiter_methods)
         );
}

# The immortal small ints 0 and 1 (_PyLong_GetZero, _PyLong_GetOne): borrowed.
def long_zero -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

def long_one -> ptr[PyObject] {
    return PyLong_FromLong(1);
}

"""PyLong_CheckExact(ob) || PyBool_Check(ob)."""
def exact_int_or_bool(ob: ptr[PyObject]) -> bool {
    return object_is_type(ob, addressof(PyLong_Type)) or bool_check(ob);
}

def range_of(op: ptr[PyObject]) -> ptr[rangeobject] {
    return ptr[rangeobject](op);
}

# Support objects whose length is > PY_SSIZE_T_MAX.

# Validate the step: a new reference, 1 when absent, or NULL on error.
def validate_step(step: ptr[PyObject]) -> ptr[PyObject] {
    # No step specified, use a step of 1.
    if not step {
        return PyLong_FromLong(1);
    }
    step = PyNumber_Index(step);
    if step {
        sign = i32(0);
        PyLong_GetSign(step, &mut sign);
        if sign == 0 {
            PyErr_SetString(PyExc_ValueError, "range() arg 3 must not be zero");
            jacpy_release(step);
            return NULL;
        }
    }
    return step;
}

# A range owning `start`, `stop` and `step`, or NULL (the caller releases them).
def make_range_object(
    _type: ptr[PyTypeObject],
    start: ptr[PyObject],
    stop: ptr[PyObject],
    step: ptr[PyObject]
) -> ptr[PyObject] {
    length = compute_range_length(start, stop, step);
    if not length {
        return NULL;
    }
    op = freelist_pop(_Py_freelists_RANGES);
    if not op {
        op = _PyObject_New(ptr[PyObject](_type));
        if not op {
            jacpy_release(length);
            return NULL;
        }
    }
    r = range_of(op);
    r.view(1)[0].start = start;
    r.view(1)[0].stop = stop;
    r.view(1)[0].step = step;
    r.view(1)[0].length = length;
    return op;
}

def range_from_array(
    _type: ptr[PyTypeObject], args: ptr[ptr[PyObject]], num_args: i64
) -> ptr[PyObject] {
    start = NULL;
    stop = NULL;
    step = NULL;
    if num_args == 2 or num_args == 3 {
        if num_args == 3 {
            step = (args + 2).view(1)[0];
        }
        # Convert borrowed refs to owned refs
        start = PyNumber_Index(args.view(1)[0]);
        if not start {
            return NULL;
        }
        stop = PyNumber_Index((args + 1).view(1)[0]);
        if not stop {
            jacpy_release(start);
            return NULL;
        }
        step = validate_step(step);  # Caution, this can clear exceptions
        if not step {
            jacpy_release(start);
            jacpy_release(stop);
            return NULL;
        }
    } elif num_args == 1 {
        stop = PyNumber_Index(args.view(1)[0]);
        if not stop {
            return NULL;
        }
        start = long_zero();
        step = long_one();
    } elif num_args == 0 {
        PyErr_SetString(PyExc_TypeError, "range expected at least 1 argument, got 0");
        return NULL;
    } else {
        PyErr_Format(
            PyExc_TypeError, "range expected at most 3 arguments, got %zd", num_args
        );
        return NULL;
    }
    op = make_range_object(_type, start, stop, step);
    if op {
        return op;
    }
    # Failed to create object, release attributes
    jacpy_release(start);
    jacpy_release(stop);
    jacpy_release(step);
    return NULL;
}

def range_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    if kw and _PyArg_NoKeywords("range", kw) == 0 {
        return NULL;
    }
    return range_from_array(_type, tuple_items(args), object_size(args));
}

def range_vectorcall(
    rangetype: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = PyVectorcall_NARGS(nargsf);
    if kwnames and _PyArg_NoKwnames("range", kwnames) == 0 {
        return NULL;
    }
    return range_from_array(ptr[PyTypeObject](rangetype), args, nargs);
}

def range_dealloc(op: ptr[PyObject]) {
    r = range_of(op);
    jacpy_release(r.view(1)[0].start);
    jacpy_release(r.view(1)[0].stop);
    jacpy_release(r.view(1)[0].step);
    jacpy_release(r.view(1)[0].length);
    if not freelist_push(_Py_freelists_RANGES, op, Py_ranges_MAXFREELIST) {
        PyObject_Free(ptr(op));
    }
}

# Return number of items in range (lo, hi, step). step != 0 required. The
# result always fits in an unsigned long: for step > 0 and lo < hi the last of
# n values is lo + (n-1)*step <= hi-1, so n = (hi - lo - 1)/step + 1, and
# hi-lo-1 is at most 2*LONG_MAX, which unsigned arithmetic holds exactly. The
# analysis for step < 0 is similar.
def get_len_of_range(lo: i64, hi: i64, step: i64) -> u64 {
    if step > 0 and lo < hi {
        return u64(1)
            + wrapping_sub(wrapping_sub(u64.wrap(hi), u64(1)), u64.wrap(lo))
                // u64.wrap(step);
    }
    if step < 0 and lo > hi {
        return u64(1)
            + wrapping_sub(wrapping_sub(u64.wrap(lo), u64(1)), u64.wrap(hi))
                // wrapping_sub(u64(0), u64.wrap(step));
    }
    return u64(0);
}

# Return the length as a long, -2 for an overflow and -1 for any other type of
# error. In case of an overflow no error is set.
def compute_range_length_long(
    start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]
) -> i64 {
    overflow = i32(0);
    long_start = PyLong_AsLongAndOverflow(start, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_start == -1 and PyErr_Occurred() {
        return -1;
    }
    long_stop = PyLong_AsLongAndOverflow(stop, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_stop == -1 and PyErr_Occurred() {
        return -1;
    }
    long_step = PyLong_AsLongAndOverflow(step, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_step == -1 and PyErr_Occurred() {
        return -1;
    }
    ulen = get_len_of_range(long_start, long_stop, long_step);
    if ulen > u64(i64.MAX) {
        # length too large for a long
        return -2;
    }
    return i64(ulen);
}

# Return number of items in range (lo, hi, step) as a PyLong object, when
# arguments are PyLong objects: get_len_of_range() on int objects.
def compute_range_length(
    start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]
) -> ptr[PyObject] {
    zero = long_zero();
    one = long_one();
    # fast path when all arguments fit into a long integer
    length = compute_range_length_long(start, stop, step);
    if length >= 0 {
        return PyLong_FromLong(length);
    } elif length == -1 {
        # unexpected error from compute_range_length_long, we propagate to the
        # caller
        return NULL;
    }
    cmp_result = PyObject_RichCompareBool(step, zero, Py_GT);
    if cmp_result == -1 {
        return NULL;
    }
    lo = start;
    hi = stop;
    if cmp_result == 1 {
        step = Py_NewRef(step);
    } else {
        lo = stop;
        hi = start;
        step = PyNumber_Negative(step);
        if not step {
            return NULL;
        }
    }
    # if (lo >= hi), return length of 0.
    cmp_result = PyObject_RichCompareBool(lo, hi, Py_GE);
    if cmp_result != 0 {
        jacpy_release(step);
        if cmp_result < 0 {
            return NULL;
        }
        return Py_NewRef(zero);
    }
    result = NULL;
    tmp1 = PyNumber_Subtract(hi, lo);
    diff = PyNumber_Subtract(tmp1, one) if tmp1 else NULL;
    tmp2 = PyNumber_FloorDivide(diff, step) if diff else NULL;
    if tmp2 {
        result = PyNumber_Add(tmp2, one);
    }
    jacpy_release(tmp2);
    jacpy_release(diff);
    jacpy_release(step);
    jacpy_release(tmp1);
    return result;
}

def range_length(op: ptr[PyObject]) -> i64 {
    return PyLong_AsSsize_t(range_of(op).view(1)[0].length);
}

# r.start + (i * r.step), on int objects.
def compute_item(r: ptr[rangeobject], i: ptr[PyObject]) -> ptr[PyObject] {
    if r.view(1)[0].step == long_one() {
        return PyNumber_Add(r.view(1)[0].start, i);
    }
    incr = PyNumber_Multiply(i, r.view(1)[0].step);
    if not incr {
        return NULL;
    }
    result = PyNumber_Add(r.view(1)[0].start, incr);
    jacpy_release(incr);
    return result;
}

def compute_range_item(r: ptr[rangeobject], arg: ptr[PyObject]) -> ptr[PyObject] {
    zero = long_zero();
    length = r.view(1)[0].length;
    # i = r.length + arg if arg < 0 else arg
    cmp_result = PyObject_RichCompareBool(arg, zero, Py_LT);
    if cmp_result == -1 {
        return NULL;
    }
    i = NULL;
    if cmp_result == 1 {
        i = PyNumber_Add(length, arg);
        if not i {
            return NULL;
        }
    } else {
        i = Py_NewRef(arg);
    }
    # if i < 0 or i >= r.length: <report index out of bounds>
    cmp_result = PyObject_RichCompareBool(i, zero, Py_LT);
    if cmp_result == 0 {
        cmp_result = PyObject_RichCompareBool(i, length, Py_GE);
    }
    if cmp_result == -1 {
        jacpy_release(i);
        return NULL;
    }
    if cmp_result == 1 {
        jacpy_release(i);
        PyErr_SetString(PyExc_IndexError, "range object index out of range");
        return NULL;
    }
    result = compute_item(r, i);
    jacpy_release(i);
    return result;
}

def range_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    arg = PyLong_FromSsize_t(i);
    if not arg {
        return NULL;
    }
    result = compute_range_item(range_of(op), arg);
    jacpy_release(arg);
    return result;
}

def compute_slice(r: ptr[rangeobject], slice: ptr[PyObject]) -> ptr[PyObject] {
    (start, stop, step) = slice_get_long_indices(slice, r.view(1)[0].length);
    if not step {
        return NULL;
    }
    substart = NULL;
    substop = NULL;
    substep = PyNumber_Multiply(r.view(1)[0].step, step);
    jacpy_release(step);
    if substep {
        substart = compute_item(r, start);
    }
    jacpy_release(start);
    if substart {
        substop = compute_item(r, stop);
    }
    jacpy_release(stop);
    if substop {
        result = make_range_object(
            object_type(ptr[PyObject](r)), substart, substop, substep
        );
        if result {
            return result;
        }
    }
    jacpy_release(substart);
    jacpy_release(substop);
    jacpy_release(substep);
    return NULL;
}

# Assumes (PyLong_CheckExact(ob) || PyBool_Check(ob))
def range_contains_long(r: ptr[rangeobject], ob: ptr[PyObject]) -> i32 {
    zero = long_zero();
    # Check if the value can possibly be in the range.
    cmp1 = PyObject_RichCompareBool(r.view(1)[0].step, zero, Py_GT);
    if cmp1 == -1 {
        return i32(-1);
    }
    cmp2 = i32(0);
    cmp3 = i32(0);
    if cmp1 == 1 {
        # positive steps: start <= ob < stop
        cmp2 = PyObject_RichCompareBool(r.view(1)[0].start, ob, Py_LE);
        cmp3 = PyObject_RichCompareBool(ob, r.view(1)[0].stop, Py_LT);
    } else {
        # negative steps: stop < ob <= start
        cmp2 = PyObject_RichCompareBool(ob, r.view(1)[0].start, Py_LE);
        cmp3 = PyObject_RichCompareBool(r.view(1)[0].stop, ob, Py_LT);
    }
    if cmp2 == -1 or cmp3 == -1 {
        # TypeError
        return i32(-1);
    }
    if cmp2 == 0 or cmp3 == 0 {
        # ob outside of range
        return i32(0);
    }
    # Check that the stride does not invalidate ob's membership.
    result = i32(-1);
    tmp1 = PyNumber_Subtract(ob, r.view(1)[0].start);
    tmp2 = PyNumber_Remainder(tmp1, r.view(1)[0].step) if tmp1 else NULL;
    if tmp2 {
        # result = ((int(ob) - start) % step) == 0
        result = PyObject_RichCompareBool(tmp2, zero, Py_EQ);
    }
    jacpy_release(tmp1);
    jacpy_release(tmp2);
    return result;
}

def range_contains(op: ptr[PyObject], ob: ptr[PyObject]) -> i32 {
    if exact_int_or_bool(ob) {
        return range_contains_long(range_of(op), ob);
    }
    return i32(_PySequence_IterSearch(op, ob, PY_ITERSEARCH_CONTAINS));
}

# Compare two range objects: 1 for equal, 0 for not equal and -1 on error.
# Roughly: r0 is r1, or equal lengths and (empty, or equal starts and (one
# item, or equal steps)).
def range_equals(r0: ptr[rangeobject], r1: ptr[rangeobject]) -> i32 {
    if r0 == r1 {
        return i32(1);
    }
    cmp_result = PyObject_RichCompareBool(
        r0.view(1)[0].length, r1.view(1)[0].length, Py_EQ
    );
    # Return False or error to the caller.
    if cmp_result != 1 {
        return cmp_result;
    }
    cmp_result = PyObject_Not(r0.view(1)[0].length);
    # Return True or error to the caller.
    if cmp_result != 0 {
        return cmp_result;
    }
    cmp_result = PyObject_RichCompareBool(
        r0.view(1)[0].start, r1.view(1)[0].start, Py_EQ
    );
    # Return False or error to the caller.
    if cmp_result != 1 {
        return cmp_result;
    }
    cmp_result = PyObject_RichCompareBool(r0.view(1)[0].length, long_one(), Py_EQ);
    # Return True or error to the caller.
    if cmp_result != 0 {
        return cmp_result;
    }
    return PyObject_RichCompareBool(r0.view(1)[0].step, r1.view(1)[0].step, Py_EQ);
}

def range_richcompare(
    op: ptr[PyObject], other: ptr[PyObject], cmp: i32
) -> ptr[PyObject] {
    if not object_is_type(other, addressof(PyRange_Type)) {
        return Py_NewRef(Py_NotImplemented);
    }
    if cmp == Py_NE or cmp == Py_EQ {
        result = range_equals(range_of(op), range_of(other));
        if result == -1 {
            return NULL;
        }
        if cmp == Py_NE {
            result = i32(result == 0);
        }
        if result != 0 {
            return ptr[PyObject](addressof(_Py_TrueStruct));
        }
        return ptr[PyObject](addressof(_Py_FalseStruct));
    }
    if cmp == Py_LE or cmp == Py_GE or cmp == Py_LT or cmp == Py_GT {
        return Py_NewRef(Py_NotImplemented);
    }
    PyErr_BadArgument();
    return NULL;
}

# Hash function for range objects: hash((len(r), None, None)) when empty,
# hash((len(r), r.start, None)) for one item, else
# hash((len(r), r.start, r.step)).
def range_hash(op: ptr[PyObject]) -> i64 {
    r = range_of(op);
    t = PyTuple_New(3);
    if not t {
        return -1;
    }
    result = i64(-1);
    tuple_set_item(t, 0, Py_NewRef(r.view(1)[0].length));
    cmp_result = PyObject_Not(r.view(1)[0].length);
    if cmp_result == 1 {
        tuple_set_item(t, 1, Py_NewRef(Py_None));
        tuple_set_item(t, 2, Py_NewRef(Py_None));
        result = PyObject_Hash(t);
    } elif cmp_result == 0 {
        tuple_set_item(t, 1, Py_NewRef(r.view(1)[0].start));
        cmp_result = PyObject_RichCompareBool(r.view(1)[0].length, long_one(), Py_EQ);
        if cmp_result == 1 {
            tuple_set_item(t, 2, Py_NewRef(Py_None));
            result = PyObject_Hash(t);
        } elif cmp_result == 0 {
            tuple_set_item(t, 2, Py_NewRef(r.view(1)[0].step));
            result = PyObject_Hash(t);
        }
    }
    jacpy_release(t);
    return result;
}

def range_count(op: ptr[PyObject], ob: ptr[PyObject]) -> ptr[PyObject] {
    if exact_int_or_bool(ob) {
        result = range_contains_long(range_of(op), ob);
        if result == -1 {
            return NULL;
        }
        return PyLong_FromLong(i64(result));
    }
    count = _PySequence_IterSearch(op, ob, PY_ITERSEARCH_COUNT);
    if count == -1 {
        return NULL;
    }
    return PyLong_FromSsize_t(count);
}

def range_index(op: ptr[PyObject], ob: ptr[PyObject]) -> ptr[PyObject] {
    r = range_of(op);
    if not exact_int_or_bool(ob) {
        index = _PySequence_IterSearch(op, ob, PY_ITERSEARCH_INDEX);
        if index == -1 {
            return NULL;
        }
        return PyLong_FromSsize_t(index);
    }
    contains = range_contains_long(r, ob);
    if contains == -1 {
        return NULL;
    }
    if contains != 0 {
        idx = PyNumber_Subtract(ob, r.view(1)[0].start);
        if not idx {
            return NULL;
        }
        if r.view(1)[0].step == long_one() {
            return idx;
        }
        # idx = (ob - r.start) // r.step
        sidx = PyNumber_FloorDivide(idx, r.view(1)[0].step);
        jacpy_release(idx);
        return sidx;
    }
    # object is not in the range
    PyErr_SetString(PyExc_ValueError, "range.index(x): x not in range");
    return NULL;
}

def range_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    r = range_of(op);
    # Check for special case values for printing. We don't always need the
    # step value. We don't care about overflow.
    istep = PyNumber_AsSsize_t(r.view(1)[0].step, NULL);
    if istep == -1 and PyErr_Occurred() {
        return NULL;
    }
    if istep == 1 {
        return PyUnicode_FromFormat(
            "range(%R, %R)", r.view(1)[0].start, r.view(1)[0].stop
        );
    }
    return PyUnicode_FromFormat(
        "range(%R, %R, %R)", r.view(1)[0].start, r.view(1)[0].stop, r.view(1)[0].step
    );
}

# Pickling support
def range_reduce(op: ptr[PyObject], _args: ptr[PyObject]) -> ptr[PyObject] {
    r = range_of(op);
    return Py_BuildValue(
        "(O(OOO))",
        object_type(op),
        r.view(1)[0].start,
        r.view(1)[0].stop,
        r.view(1)[0].step
    );
}

def range_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != 0 {
        i = PyNumber_Index(item);
        if not i {
            return NULL;
        }
        result = compute_range_item(range_of(op), i);
        jacpy_release(i);
        return result;
    }
    if slice_check(item) {
        return compute_slice(range_of(op), item);
    }
    PyErr_Format(
        PyExc_TypeError,
        "range indices must be integers or slices, not %.200s",
        object_type(item).view(1)[0].tp_name
    );
    return NULL;
}

def range_bool(op: ptr[PyObject]) -> i32 {
    return PyObject_IsTrue(range_of(op).view(1)[0].length);
}

# ---------------------------------------------------------- range iterators
# There are 2 types of iterators, one for C longs, the other for Python ints.
# This makes iteration fast in the normal case, but possible for any numeric
# value.

def rangeiter_of(op: ptr[PyObject]) -> ptr[_PyRangeIterObject] {
    return ptr[_PyRangeIterObject](op);
}

def rangeiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    r = rangeiter_of(op);
    if r.view(1)[0].len > 0 {
        result = r.view(1)[0].start;
        r.view(1)[0].start = result + r.view(1)[0].step;
        r.view(1)[0].len -= 1;
        return PyLong_FromLong(result);
    }
    return NULL;
}

def rangeiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(rangeiter_of(op).view(1)[0].len);
}

def rangeiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    r = rangeiter_of(op);
    # create a range object for pickling
    start = PyLong_FromLong(r.view(1)[0].start);
    stop = PyLong_FromLong(r.view(1)[0].start + r.view(1)[0].len * r.view(1)[0].step)
        if start
        else NULL;
    step = PyLong_FromLong(r.view(1)[0].step) if stop else NULL;
    if step {
        pickled = make_range_object(addressof(PyRange_Type), start, stop, step);
        if pickled {
            # return the result
            return Py_BuildValue("N(N)O", eval_builtin("iter"), pickled, Py_None);
        }
    }
    jacpy_release(start);
    jacpy_release(stop);
    jacpy_release(step);
    return NULL;
}

def rangeiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    r = rangeiter_of(op);
    index = PyLong_AsLong(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    # silently clip the index value
    if index < 0 {
        index = 0;
    } elif index > r.view(1)[0].len {
        index = r.view(1)[0].len;  # exhausted iterator
    }
    r.view(1)[0].start += index * r.view(1)[0].step;
    r.view(1)[0].len -= index;
    return Py_NewRef(Py_None);
}

def rangeiter_dealloc(op: ptr[PyObject]) {
    if not freelist_push(_Py_freelists_RANGE_ITERS, op, Py_range_iters_MAXFREELIST) {
        PyObject_Free(ptr(op));
    }
}

# A C-long range iterator; its length is known to fit a C long.
def fast_range_iter(start: i64, _stop: i64, step: i64, length: i64) -> ptr[PyObject] {
    op = freelist_pop(_Py_freelists_RANGE_ITERS);
    if not op {
        op = _PyObject_New(ptr[PyObject](addressof(PyRangeIter_Type)));
        if not op {
            return NULL;
        }
    }
    it = rangeiter_of(op);
    it.view(1)[0].start = start;
    it.view(1)[0].step = step;
    it.view(1)[0].len = length;
    return op;
}

def longrangeiter_of(op: ptr[PyObject]) -> ptr[longrangeiterobject] {
    return ptr[longrangeiterobject](op);
}

def longrangeiter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(longrangeiter_of(op).view(1)[0].len);
}

def longrangeiter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    r = longrangeiter_of(op);
    # create a range object for pickling. Must calculate the "stop" value
    product = PyNumber_Multiply(r.view(1)[0].len, r.view(1)[0].step);
    if not product {
        return NULL;
    }
    stop = PyNumber_Add(r.view(1)[0].start, product);
    jacpy_release(product);
    if not stop {
        return NULL;
    }
    pickled = make_range_object(
        addressof(PyRange_Type),
        Py_NewRef(r.view(1)[0].start),
        stop,
        Py_NewRef(r.view(1)[0].step)
    );
    if not pickled {
        jacpy_release(r.view(1)[0].start);
        jacpy_release(stop);
        jacpy_release(r.view(1)[0].step);
        return NULL;
    }
    # return the result
    return Py_BuildValue("N(N)O", eval_builtin("iter"), pickled, Py_None);
}

def longrangeiter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    if not object_is_type(state, addressof(PyLong_Type)) {
        PyErr_Format(PyExc_TypeError, "state must be an int, not %T", state);
        return NULL;
    }
    r = longrangeiter_of(op);
    zero = long_zero();
    # clip the value
    cmp = PyObject_RichCompareBool(state, zero, Py_LT);
    if cmp < 0 {
        return NULL;
    }
    if cmp > 0 {
        state = zero;
    } else {
        cmp = PyObject_RichCompareBool(r.view(1)[0].len, state, Py_LT);
        if cmp < 0 {
            return NULL;
        }
        if cmp > 0 {
            state = r.view(1)[0].len;
        }
    }
    product = PyNumber_Multiply(state, r.view(1)[0].step);
    if not product {
        return NULL;
    }
    new_start = PyNumber_Add(r.view(1)[0].start, product);
    jacpy_release(product);
    if not new_start {
        return NULL;
    }
    new_len = PyNumber_Subtract(r.view(1)[0].len, state);
    if not new_len {
        jacpy_release(new_start);
        return NULL;
    }
    old_start = r.view(1)[0].start;
    r.view(1)[0].start = new_start;
    old_len = r.view(1)[0].len;
    r.view(1)[0].len = new_len;
    jacpy_release(old_len);
    jacpy_release(old_start);
    return Py_NewRef(Py_None);
}

def longrangeiter_dealloc(op: ptr[PyObject]) {
    r = longrangeiter_of(op);
    jacpy_release(r.view(1)[0].start);
    jacpy_release(r.view(1)[0].step);
    jacpy_release(r.view(1)[0].len);
    PyObject_Free(ptr(op));
}

def longrangeiter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    r = longrangeiter_of(op);
    if PyObject_RichCompareBool(r.view(1)[0].len, long_zero(), Py_GT) != 1 {
        return NULL;
    }
    new_start = PyNumber_Add(r.view(1)[0].start, r.view(1)[0].step);
    if not new_start {
        return NULL;
    }
    new_len = PyNumber_Subtract(r.view(1)[0].len, long_one());
    if not new_len {
        jacpy_release(new_start);
        return NULL;
    }
    result = r.view(1)[0].start;
    r.view(1)[0].start = new_start;
    old_len = r.view(1)[0].len;
    r.view(1)[0].len = new_len;
    jacpy_release(old_len);
    return result;
}

# A long range iterator over the range's int fields, as new references.
def long_range_iter(r: ptr[rangeobject]) -> ptr[PyObject] {
    op = _PyObject_New(ptr[PyObject](addressof(PyLongRangeIter_Type)));
    if not op {
        return NULL;
    }
    it = longrangeiter_of(op);
    it.view(1)[0].start = Py_NewRef(r.view(1)[0].start);
    it.view(1)[0].step = Py_NewRef(r.view(1)[0].step);
    it.view(1)[0].len = Py_NewRef(r.view(1)[0].length);
    return op;
}

# The C longs of a range's start, stop and step, and whether all three fit
# (the error is cleared when one does not).
def long_fields(r: ptr[rangeobject]) -> tuple[i64, i64, i64, bool] {
    start = PyLong_AsLong(r.view(1)[0].start);
    if start == -1 and PyErr_Occurred() {
        PyErr_Clear();
        return (i64(0), i64(0), i64(0), False);
    }
    stop = PyLong_AsLong(r.view(1)[0].stop);
    if stop == -1 and PyErr_Occurred() {
        PyErr_Clear();
        return (i64(0), i64(0), i64(0), False);
    }
    step = PyLong_AsLong(r.view(1)[0].step);
    if step == -1 and PyErr_Occurred() {
        PyErr_Clear();
        return (i64(0), i64(0), i64(0), False);
    }
    return (start, stop, step, True);
}

def range_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    r = range_of(seq);
    # If all three fields and the length convert to long, use the int version
    (lstart, lstop, lstep, fits) = long_fields(r);
    if not fits {
        return long_range_iter(r);
    }
    ulen = get_len_of_range(lstart, lstop, lstep);
    if ulen > u64(i64.MAX) {
        return long_range_iter(r);
    }
    # check for potential overflow of lstart + ulen * lstep
    if ulen != u64(0) {
        if lstep > 0 {
            if lstop > i64.MAX - (lstep - 1) {
                return long_range_iter(r);
            }
        } elif lstop < i64.MIN + (-1 - lstep) {
            return long_range_iter(r);
        }
    }
    return fast_range_iter(lstart, lstop, lstep, i64(ulen));
}

# reversed(range(start, stop, step)) is range(start+(n-1)*step, start-step,
# -step), where n is the number of integers in the range. When start, stop,
# step, -step, start-step and the length all fit a C long, the C-long iterator
# runs it; that excludes some reversible ranges but keeps the checks simple.
def range_reverse(seq: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    r = range_of(seq);
    (lstart, lstop, lstep, fits) = long_fields(r);
    # check for possible overflow of -lstep
    fits = fits and lstep != i64.MIN;
    ulen = u64(0);
    if fits {
        # check for overflow of lstart - lstep, as unsigned longs to avoid
        # signed overflow: lstart - LONG_MIN < lstep for lstep > 0, and
        # LONG_MAX - lstart < -lstep for lstep < 0.
        if lstep > 0 {
            fits = wrapping_sub(u64.wrap(lstart), u64.wrap(i64.MIN)) >= u64(lstep);
        } else {
            fits = wrapping_sub(u64(i64.MAX), u64.wrap(lstart))
                >= wrapping_sub(u64(0), u64.wrap(lstep));
        }
    }
    if fits {
        ulen = get_len_of_range(lstart, lstop, lstep);
        fits = ulen <= u64(i64.MAX);
    }
    if fits {
        new_stop = lstart - lstep;
        new_start = i64.wrap(
            wrapping_add(u64.wrap(new_stop), wrapping_mul(ulen, u64.wrap(lstep)))
        );
        return fast_range_iter(new_start, new_stop, -lstep, i64(ulen));
    }
    op = _PyObject_New(ptr[PyObject](addressof(PyLongRangeIter_Type)));
    if not op {
        return NULL;
    }
    it = longrangeiter_of(op);
    it.view(1)[0].start = NULL;
    it.view(1)[0].step = NULL;
    # start + (len - 1) * step
    it.view(1)[0].len = Py_NewRef(r.view(1)[0].length);
    diff = PyNumber_Subtract(it.view(1)[0].len, long_one());
    product = PyNumber_Multiply(diff, r.view(1)[0].step) if diff else NULL;
    jacpy_release(diff);
    if product {
        it.view(1)[0].start = PyNumber_Add(r.view(1)[0].start, product);
        jacpy_release(product);
    }
    if it.view(1)[0].start {
        it.view(1)[0].step = PyNumber_Negative(r.view(1)[0].step);
    }
    if not it.view(1)[0].step {
        jacpy_release(op);
        return NULL;
    }
    return op;
}
