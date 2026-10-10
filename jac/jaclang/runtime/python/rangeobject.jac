# Objects/rangeobject.c ported to native Jac.
#
# Range values and both iterator representations retain CPython's exact
# layouts. The small-integer iterator is used when its state fits in long;
# the arbitrary-precision iterator covers all remaining integer ranges.
# Freelist operations are omitted; allocation and deallocation use CPython's
# public object APIs.

import from jaclang.runtime.python.boolobject { PyLongObject_Layout, PyNumberMethods }

import from jaclang.runtime.python.refcount { py_incref, py_decref }

import from c {
    obj PyObject;
    # A vectorcall `PyObject *const *args` array (up to 3 positional args):
    # read `args[i]` directly instead of a C helper call.
    obj ArgVec3 {
        has a0: ptr[PyObject] = ptr[PyObject](),
            a1: ptr[PyObject] = ptr[PyObject](),
            a2: ptr[PyObject] = ptr[PyObject]();
    }
    obj PyObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject]();
    }
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
    obj PyRangeObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            start: ptr[PyObject] = ptr[PyObject](),
            stop: ptr[PyObject] = ptr[PyObject](),
            step: ptr[PyObject] = ptr[PyObject](),
            length: ptr[PyObject] = ptr[PyObject]();
    }
    obj PyRangeIterObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            start: i64 = 0,
            step: i64 = 0,
            len: i64 = 0;
    }
    obj PyLongRangeIterObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            start: ptr[PyObject] = ptr[PyObject](),
            step: ptr[PyObject] = ptr[PyObject](),
            len: ptr[PyObject] = ptr[PyObject]();
    }
    obj PySequenceMethods_Layout {
        has sq_length: Callable[[ptr[PyObject]], i64] = 0,
            sq_concat: ptr = ptr(),
            sq_repeat: ptr = ptr(),
            sq_item: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            sq_slice: ptr = ptr(),
            sq_ass_item: ptr = ptr(),
            sq_ass_slice: ptr = ptr(),
            sq_contains: Callable[[ptr[PyObject], ptr[PyObject]], i32] = 0,
            sq_inplace_concat: ptr = ptr(),
            sq_inplace_repeat: ptr = ptr();
    }
    obj PyMappingMethods_Layout {
        has mp_length: Callable[[ptr[PyObject]], i64] = 0,
            mp_subscript: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            mp_ass_subscript: ptr = ptr();
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
    obj RangeMethods_Layout {
        has e0: PyMethodDef_Layout,
            e1: PyMethodDef_Layout,
            e2: PyMethodDef_Layout,
            e3: PyMethodDef_Layout,
            sentinel: PyMethodDef_Layout;
    }
    obj RangeIterMethods_Layout {
        has e0: PyMethodDef_Layout,
            e1: PyMethodDef_Layout,
            e2: PyMethodDef_Layout,
            sentinel: PyMethodDef_Layout;
    }
    obj RangeMembers_Layout {
        has e0: PyMemberDef_Layout,
            e1: PyMemberDef_Layout,
            e2: PyMemberDef_Layout,
            sentinel: PyMemberDef_Layout;
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyExc_TypeError: ptr[PyObject];
    glob PyExc_ValueError: ptr[PyObject];
    glob PyExc_IndexError: ptr[PyObject];
    glob PyExc_OverflowError: ptr[PyObject];
    # Py_None / Py_NotImplemented are macros over these exported structs.
    glob _Py_NoneStruct: PyObject_Layout;
    glob _Py_NotImplementedStruct: PyObject_Layout;

    def PyObject_Free(o: ptr) -> None;
    def PyObject_GenericGetAttr(o: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];
    def PyObject_IsTrue(o: ptr[PyObject]) -> i32;
    def PyObject_Not(o: ptr[PyObject]) -> i32;
    def PyObject_Hash(o: ptr[PyObject]) -> i64;
    def PyObject_RichCompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject];
    def PyObject_RichCompareBool(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> i32;
    def PyObject_SelfIter(o: ptr[PyObject]) -> ptr[PyObject];
    def PyErr_Clear() -> None;
    def PyErr_Occurred() -> ptr[PyObject];
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyNumber_Add(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Subtract(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Multiply(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_FloorDivide(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Remainder(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Negative(a: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_Index(a: ptr[PyObject]) -> ptr[PyObject];
    def PyNumber_AsSsize_t(a: ptr[PyObject], exc: ptr[PyObject]) -> i64;
    def PyLong_AsLong(a: ptr[PyObject]) -> i64;
    def PyLong_AsLongAndOverflow(a: ptr[PyObject], overflow: &mut i32) -> i64;
    def PyLong_FromLong(a: i64) -> ptr[PyObject];
    def PyLong_FromSsize_t(a: i64) -> ptr[PyObject];
    def PyTuple_New(n: i64) -> ptr[PyObject];
    def PyTuple_Size(o: ptr[PyObject]) -> i64;
    def _PySequence_IterSearch(seq: ptr[PyObject], item: ptr[PyObject], operation: i32) -> i64;
    def _PyArg_NoKeywords(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def _PyArg_NoKwnames(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def jacpy_is_exact_long(o: ptr[PyObject]) -> i32;
    def jacpy_is_bool(o: ptr[PyObject]) -> i32;
    def jacpy_long_zero() -> ptr[PyObject];
    def jacpy_long_one() -> ptr[PyObject];
    def jacpy_bool_true() -> ptr[PyObject];
    def jacpy_bool_false() -> ptr[PyObject];
    def jacpy_tuple_set_item(t: ptr[PyObject], index: i64, v: ptr[PyObject]) -> None;
    def jacpy_range_alloc(tp: ptr[PyTypeObject_Layout], size: i64) -> ptr[PyObject];
    # The `ranges` / `range_iters` freelists (per-thread interpreter state,
    # reached through pycore_freelist.h's inline helpers).
    def jacpy_range_obj_alloc(tp: ptr[PyTypeObject_Layout]) -> ptr[PyObject];
    def jacpy_range_obj_free(o: ptr[PyObject]) -> None;
    def jacpy_rangeiter_alloc() -> ptr[PyObject];
    def jacpy_rangeiter_free(o: ptr[PyObject]) -> None;
    # Defined natively in sliceobject.jac. Called through its C symbol: `&mut`
    # out-params lower to addresses for C externs, not for Jac `ptr` params.
    def _PySlice_GetLongIndices(
        self_op: ptr[PyObject],
        length: ptr[PyObject],
        start_ptr: &mut ptr[PyObject],
        stop_ptr: &mut ptr[PyObject],
        step_ptr: &mut ptr[PyObject]
    ) -> i32;
    def jacpy_range_index_check(item: ptr[PyObject]) -> i32;
    def jacpy_range_new_too_many(nargs: i64) -> None;
    def jacpy_range_bad_index(item: ptr[PyObject]) -> None;
    def jacpy_range_repr(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject], include_step: i32) -> ptr[PyObject];
    def jacpy_range_reduce(tp: ptr[PyObject], start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_range_iter_reduce(range: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_range_iter_bad_state(state: ptr[PyObject]) -> None;
}

import from jaclang.runtime.python.sliceobject { slice_is_slice }

glob Py_LT: i32 = 0;
glob Py_LE: i32 = 1;
glob Py_EQ: i32 = 2;
glob Py_NE: i32 = 3;
glob Py_GT: i32 = 4;
glob Py_GE: i32 = 5;
glob PY_ITERSEARCH_COUNT: i32 = 1;
glob PY_ITERSEARCH_INDEX: i32 = 2;
glob PY_ITERSEARCH_CONTAINS: i32 = 3;

def range_length_long(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> i64 {
    overflow: i32 = 0;
    long_start = PyLong_AsLongAndOverflow(start, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_start == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return -1;
    }
    long_stop = PyLong_AsLongAndOverflow(stop, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_stop == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return -1;
    }
    long_step = PyLong_AsLongAndOverflow(step, &mut overflow);
    if overflow != 0 {
        return -2;
    }
    if long_step == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return -1;
    }
    count = get_len_of_range(long_start, long_stop, long_step);
    if count > 9223372036854775807 {
        return -2;
    }
    return i64(count);
}

def range_length_value(start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject] {
    fast_length = range_length_long(start, stop, step);
    if fast_length >= 0 {
        return PyLong_FromLong(fast_length);
    }
    if fast_length == -1 {
        return ptr[PyObject]();
    }
    zero = jacpy_long_zero();
    one = jacpy_long_one();
    positive = PyObject_RichCompareBool(step, zero, Py_GT);
    if positive < 0 {
        return ptr[PyObject]();
    }
    lo = start if positive != 0 else stop;
    hi = stop if positive != 0 else start;
    cmp = PyObject_RichCompareBool(lo, hi, Py_GE);
    if cmp < 0 {
        return ptr[PyObject]();
    }
    if cmp != 0 {
        py_incref(zero);
        return zero;
    }
    diff = PyNumber_Subtract(hi, lo);
    if diff == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    numerator = PyNumber_Subtract(diff, one);
    py_decref(diff);
    if numerator == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    divisor = step;
    if positive == 0 {
        divisor = PyNumber_Negative(step);
        if divisor == ptr[PyObject]() {
            py_decref(numerator);
            return ptr[PyObject]();
        }
    } else {
        py_incref(divisor);
    }
    quotient = PyNumber_FloorDivide(numerator, divisor);
    py_decref(numerator);
    py_decref(divisor);
    if quotient == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    result = PyNumber_Add(quotient, one);
    py_decref(quotient);
    return result;
}

def range_make(type_: ptr[PyTypeObject_Layout], start: ptr[PyObject], stop: ptr[PyObject], step: ptr[PyObject]) -> ptr[PyObject] {
    length = range_length_value(start, stop, step);
    if length == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    allocated = jacpy_range_obj_alloc(type_);
    if allocated == ptr[PyObject]() {
        py_decref(length);
        return ptr[PyObject]();
    }
    r = ptr[PyRangeObject_Layout](allocated);
    r.start = start;
    r.stop = stop;
    r.step = step;
    r.length = length;
    return allocated;
}

def range_item_value(r: ptr[PyRangeObject_Layout], index: ptr[PyObject]) -> ptr[PyObject] {
    one = jacpy_long_one();
    if r.step == one {
        return PyNumber_Add(r.start, index);
    }
    product = PyNumber_Multiply(index, r.step);
    if product == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    result = PyNumber_Add(r.start, product);
    py_decref(product);
    return result;
}

def range_index_value(r: ptr[PyRangeObject_Layout], index: ptr[PyObject]) -> ptr[PyObject] {
    zero = jacpy_long_zero();
    normalized = index;
    py_incref(normalized);
    negative = PyObject_RichCompareBool(index, zero, Py_LT);
    if negative < 0 {
        py_decref(normalized);
        return ptr[PyObject]();
    }
    if negative != 0 {
        py_decref(normalized);
        normalized = PyNumber_Add(r.length, index);
        if normalized == ptr[PyObject]() {
            return ptr[PyObject]();
        }
    }
    before = PyObject_RichCompareBool(normalized, zero, Py_LT);
    if before == 0 {
        before = PyObject_RichCompareBool(normalized, r.length, Py_GE);
    }
    if before < 0 {
        py_decref(normalized);
        return ptr[PyObject]();
    }
    if before != 0 {
        py_decref(normalized);
        PyErr_SetString(PyExc_IndexError, "range object index out of range");
        return ptr[PyObject]();
    }
    result = range_item_value(r, normalized);
    py_decref(normalized);
    return result;
}

def range_compute_slice(r: ptr[PyRangeObject_Layout], slice: ptr[PyObject]) -> ptr[PyObject] {
    start: ptr[PyObject] = ptr[PyObject]();
    stop: ptr[PyObject] = ptr[PyObject]();
    step: ptr[PyObject] = ptr[PyObject]();
    if _PySlice_GetLongIndices(slice, r.length, &mut start, &mut stop, &mut step) < 0 {
        return ptr[PyObject]();
    }
    substep = PyNumber_Multiply(r.step, step);
    py_decref(step);
    if substep == ptr[PyObject]() {
        py_decref(start);
        py_decref(stop);
        return ptr[PyObject]();
    }
    substart = range_item_value(r, start);
    py_decref(start);
    if substart == ptr[PyObject]() {
        py_decref(stop);
        py_decref(substep);
        return ptr[PyObject]();
    }
    substop = range_item_value(r, stop);
    py_decref(stop);
    if substop == ptr[PyObject]() {
        py_decref(substart);
        py_decref(substep);
        return ptr[PyObject]();
    }
    result = range_make(ptr[PyTypeObject_Layout](PyRange_Type), substart, substop, substep);
    if result == ptr[PyObject]() {
        py_decref(substart);
        py_decref(substop);
        py_decref(substep);
    }
    return result;
}

def range_contains_long(r: ptr[PyRangeObject_Layout], value: ptr[PyObject]) -> i32 {
    zero = jacpy_long_zero();
    positive = PyObject_RichCompareBool(r.step, zero, Py_GT);
    if positive < 0 {
        return -1;
    }
    if positive != 0 {
        inside_start = PyObject_RichCompareBool(r.start, value, Py_LE);
        inside_stop = PyObject_RichCompareBool(value, r.stop, Py_LT);
    } else {
        inside_start = PyObject_RichCompareBool(value, r.start, Py_LE);
        inside_stop = PyObject_RichCompareBool(r.stop, value, Py_LT);
    }
    if inside_start < 0 or inside_stop < 0 {
        return -1;
    }
    if inside_start == 0 or inside_stop == 0 {
        return 0;
    }
    diff = PyNumber_Subtract(value, r.start);
    if diff == ptr[PyObject]() {
        return -1;
    }
    remainder = PyNumber_Remainder(diff, r.step);
    py_decref(diff);
    if remainder == ptr[PyObject]() {
        return -1;
    }
    result = PyObject_RichCompareBool(remainder, zero, Py_EQ);
    py_decref(remainder);
    return result;
}

def range_contains(self: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    r = ptr[PyRangeObject_Layout](self);
    if jacpy_is_exact_long(value) != 0 or jacpy_is_bool(value) != 0 {
        return range_contains_long(r, value);
    }
    return i32(_PySequence_IterSearch(self, value, PY_ITERSEARCH_CONTAINS));
}

def range_equals(a: ptr[PyRangeObject_Layout], b: ptr[PyRangeObject_Layout]) -> i32 {
    if ptr[PyObject](a) == ptr[PyObject](b) {
        return 1;
    }
    cmp = PyObject_RichCompareBool(a.length, b.length, Py_EQ);
    if cmp != 1 {
        return cmp;
    }
    empty = PyObject_Not(a.length);
    if empty != 0 {
        return empty;
    }
    cmp = PyObject_RichCompareBool(a.start, b.start, Py_EQ);
    if cmp != 1 {
        return cmp;
    }
    one = jacpy_long_one();
    cmp = PyObject_RichCompareBool(a.length, one, Py_EQ);
    if cmp != 0 {
        return cmp;
    }
    return PyObject_RichCompareBool(a.step, b.step, Py_EQ);
}

def range_richcompare(self: ptr[PyObject], other: ptr[PyObject], op: i32) -> ptr[PyObject] {
    notimpl_obj: ptr[PyObject] = _Py_NotImplementedStruct;
    range_type: ptr[PyObject] = PyRange_Type;
    if ptr[PyRangeObject_Layout](other).ob_type != range_type {
        py_incref(notimpl_obj);
        return notimpl_obj;
    }
    if op != Py_EQ and op != Py_NE {
        py_incref(notimpl_obj);
        return notimpl_obj;
    }
    equal = range_equals(ptr[PyRangeObject_Layout](self), ptr[PyRangeObject_Layout](other));
    if equal < 0 {
        return ptr[PyObject]();
    }
    if op == Py_NE {
        equal = 1 - equal;
    }
    return jacpy_bool_true() if equal != 0 else jacpy_bool_false();
}

def range_hash(self: ptr[PyObject]) -> i64 {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    r = ptr[PyRangeObject_Layout](self);
    tuple = PyTuple_New(3);
    if tuple == ptr[PyObject]() {
        return -1;
    }
    py_incref(r.length);
    jacpy_tuple_set_item(tuple, 0, r.length);
    empty = PyObject_Not(r.length);
    if empty < 0 {
        py_decref(tuple);
        return -1;
    }
    if empty != 0 {
        py_incref(none_obj);
        py_incref(none_obj);
        jacpy_tuple_set_item(tuple, 1, none_obj);
        jacpy_tuple_set_item(tuple, 2, none_obj);
    } else {
        py_incref(r.start);
        jacpy_tuple_set_item(tuple, 1, r.start);
        one = jacpy_long_one();
        single = PyObject_RichCompareBool(r.length, one, Py_EQ);
        if single < 0 {
            py_decref(tuple);
            return -1;
        }
        if single != 0 {
            py_incref(none_obj);
            jacpy_tuple_set_item(tuple, 2, none_obj);
        } else {
            py_incref(r.step);
            jacpy_tuple_set_item(tuple, 2, r.step);
        }
    }
    hash = PyObject_Hash(tuple);
    py_decref(tuple);
    return hash;
}

def range_count(self: ptr[PyObject], value: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    if jacpy_is_exact_long(value) != 0 or jacpy_is_bool(value) != 0 {
        found = range_contains_long(r, value);
        if found < 0 {
            return ptr[PyObject]();
        }
        return PyLong_FromLong(i64(found));
    }
    count = _PySequence_IterSearch(self, value, PY_ITERSEARCH_COUNT);
    if count < 0 {
        return ptr[PyObject]();
    }
    return PyLong_FromSsize_t(count);
}

def range_index(self: ptr[PyObject], value: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    if jacpy_is_exact_long(value) == 0 and jacpy_is_bool(value) == 0 {
        index = _PySequence_IterSearch(self, value, PY_ITERSEARCH_INDEX);
        if index < 0 {
            return ptr[PyObject]();
        }
        return PyLong_FromSsize_t(index);
    }
    contains = range_contains_long(r, value);
    if contains < 0 {
        return ptr[PyObject]();
    }
    if contains == 0 {
        PyErr_SetString(PyExc_ValueError, "range.index(x): x not in range");
        return ptr[PyObject]();
    }
    delta = PyNumber_Subtract(value, r.start);
    if delta == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if r.step == jacpy_long_one() {
        return delta;
    }
    index_result = PyNumber_FloorDivide(delta, r.step);
    py_decref(delta);
    return index_result;
}


# _PyIndex_Check (static inline): the type has an nb_index slot.
def range_index_check(v: ptr[PyObject]) -> i32 {
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

def range_subscript(self: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if range_index_check(item) != 0 {
        index = PyNumber_Index(item);
        if index == ptr[PyObject]() {
            return ptr[PyObject]();
        }
        result = range_index_value(ptr[PyRangeObject_Layout](self), index);
        py_decref(index);
        return result;
    }
    if slice_is_slice(item) != 0 {
        return range_compute_slice(ptr[PyRangeObject_Layout](self), item);
    }
    jacpy_range_bad_index(item);
    return ptr[PyObject]();
}
 
def range_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    step = PyNumber_AsSsize_t(r.step, ptr[PyObject]());
    if step == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return ptr[PyObject]();
    }
    return jacpy_range_repr(r.start, r.stop, r.step, i32(1 if step != 1 else 0));
}
 
def range_reduce(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    return jacpy_range_reduce(r.ob_type, r.start, r.stop, r.step);
}

def range_bool(self: ptr[PyObject]) -> i32 {
    return PyObject_IsTrue(ptr[PyRangeObject_Layout](self).length);
}

def range_dealloc(self: ptr[PyObject]) -> None {
    r = ptr[PyRangeObject_Layout](self);
    py_decref(r.start);
    py_decref(r.stop);
    py_decref(r.step);
    py_decref(r.length);
    jacpy_range_obj_free(self);
}

def range_length(self: ptr[PyObject]) -> i64 {
    return PyNumber_AsSsize_t(ptr[PyRangeObject_Layout](self).length, PyExc_OverflowError);
}

def range_item(self: ptr[PyObject], index: i64) -> ptr[PyObject] {
    value = PyLong_FromSsize_t(index);
    if value == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    result = range_index_value(ptr[PyRangeObject_Layout](self), value);
    py_decref(value);
    return result;
}
# _PyLong_IsZero: the sign bits of lv_tag (low two) are 1 for zero.
def range_long_is_zero(o: ptr[PyObject]) -> bool {
    l = ptr[PyLongObject_Layout](o);
    return (l.lv_tag & 3) == 1;
}

# range_from_array: borrowed vectorcall args, owned start/stop/step.
def range_from_args(type_: ptr[PyTypeObject_Layout], args: ptr, nargs: i64) -> ptr[PyObject] {
    argv = ptr[ArgVec3](args);
    start: ptr[PyObject] = ptr[PyObject]();
    stop: ptr[PyObject] = ptr[PyObject]();
    step: ptr[PyObject] = ptr[PyObject]();
    if nargs == 2 or nargs == 3 {
        start = PyNumber_Index(argv.a0);
        if start == ptr[PyObject]() {
            return ptr[PyObject]();
        }
        stop = PyNumber_Index(argv.a1);
        if stop == ptr[PyObject]() {
            py_decref(start);
            return ptr[PyObject]();
        }
        # validate_step
        if nargs == 3 {
            step = PyNumber_Index(argv.a2);
            if step != ptr[PyObject]() and range_long_is_zero(step) {
                PyErr_SetString(PyExc_ValueError, "range() arg 3 must not be zero");
                py_decref(step);
                step = ptr[PyObject]();
            }
        } else {
            step = PyLong_FromLong(1);
        }
        if step == ptr[PyObject]() {
            py_decref(start);
            py_decref(stop);
            return ptr[PyObject]();
        }
    } elif nargs == 1 {
        stop = PyNumber_Index(argv.a0);
        if stop == ptr[PyObject]() {
            return ptr[PyObject]();
        }
        start = jacpy_long_zero();
        step = jacpy_long_one();
    } elif nargs == 0 {
        PyErr_SetString(PyExc_TypeError, "range expected at least 1 argument, got 0");
        return ptr[PyObject]();
    } else {
        jacpy_range_new_too_many(nargs);
        return ptr[PyObject]();
    }
    result = range_make(type_, start, stop, step);
    if result != ptr[PyObject]() {
        return result;
    }
    py_decref(start);
    py_decref(stop);
    py_decref(step);
    return ptr[PyObject]();
}

def range_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if kwargs != ptr[PyObject]() and _PyArg_NoKeywords("range", kwargs) == 0 {
        return ptr[PyObject]();
    }
    return range_from_args(type_, ptr(args), PyTuple_Size(args));
}

def range_vectorcall(
    type_: ptr[PyObject], args: ptr[PyObject], nargsf: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames != ptr[PyObject]() and _PyArg_NoKwnames("range", kwnames) == 0 {
        return ptr[PyObject]();
    }
    nargs = i64(nargsf & 0x7FFFFFFFFFFFFFFF);
    return range_from_args(ptr[PyTypeObject_Layout](type_), ptr(args), nargs);
}

glob range_methods: RangeMethods_Layout = RangeMethods_Layout(
    e0=PyMethodDef_Layout(name="__reversed__", ml_meth=range_reverse_method, ml_flags=4, ml_doc="Return a reverse iterator."),
    e1=PyMethodDef_Layout(name="__reduce__", ml_meth=range_reduce, ml_flags=4),
    e2=PyMethodDef_Layout(name="count", ml_meth=range_count, ml_flags=8, ml_doc="rangeobject.count(value) -> integer -- return number of occurrences of value"),
    e3=PyMethodDef_Layout(name="index", ml_meth=range_index, ml_flags=8, ml_doc="rangeobject.index(value) -> integer -- return index of value.\nRaise ValueError if the value is not present."),
    sentinel=PyMethodDef_Layout()
);

glob range_members: RangeMembers_Layout = RangeMembers_Layout(
    e0=PyMemberDef_Layout(name="start", type=16, offset=16, flags=1),
    e1=PyMemberDef_Layout(name="stop", type=16, offset=24, flags=1),
    e2=PyMemberDef_Layout(name="step", type=16, offset=32, flags=1),
    sentinel=PyMemberDef_Layout()
);

glob range_as_sequence: PySequenceMethods_Layout = PySequenceMethods_Layout(
    sq_length=range_length,
    sq_item=range_item,
    sq_contains=range_contains
);

glob range_as_mapping: PyMappingMethods_Layout = PyMappingMethods_Layout(
    mp_length=range_length,
    mp_subscript=range_subscript
);

glob range_as_number: PyNumberMethods = PyNumberMethods(nb_bool=range_bool);

glob:pub PyRange_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    tp_name="range",
    tp_basicsize=48,
    tp_dealloc=range_dealloc,
    tp_repr=range_repr,
    tp_as_number=range_as_number,
    tp_as_sequence=range_as_sequence,
    tp_as_mapping=range_as_mapping,
    tp_hash=range_hash,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=32,
    tp_doc=(
        "range(stop) -> range object\n"
        "range(start, stop[, step]) -> range object\n"
        "\n"
        "Return an object that produces a sequence of integers from start (inclusive)\n"
        "to stop (exclusive) by step. range(i, j) produces i, i+1, ..., j-1.\n"
        "start defaults to 0, and stop is omitted! range(4) produces 0, 1, 2, 3.\n"
        "These are exactly the valid indices for a list of 4 elements.\n"
        "When step is given, it specifies the increment (or decrement)."
    ),
    tp_richcompare=range_richcompare,
    tp_iter=range_iter,
    tp_methods=range_methods,
    tp_members=range_members,
    tp_new=range_new,
    tp_vectorcall=range_vectorcall
);

def range_reverse_method(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    return range_reverse(self);
}

# C computes these in unsigned long: u64.wrap and the wrapping_* builtins are
# the same modular arithmetic.
def get_len_of_range(lo: i64, hi: i64, step: i64) -> u64 {
    if step > 0 and lo < hi {
        span: u64 = wrapping_sub(wrapping_sub(u64.wrap(hi), u64(1)), u64.wrap(lo));
        return u64(1) + span // u64(step);
    }
    if step < 0 and lo > hi {
        span: u64 = wrapping_sub(wrapping_sub(u64.wrap(lo), u64(1)), u64.wrap(hi));
        return u64(1) + span // wrapping_sub(u64(0), u64.wrap(step));
    }
    return u64(0);
}

def fast_range_iter(start: i64, step: i64, length: i64) -> ptr[PyObject] {
    allocated = jacpy_rangeiter_alloc();
    if allocated == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    it = ptr[PyRangeIterObject_Layout](allocated);
    it.start = start;
    it.step = step;
    it.len = length;
    return allocated;
}

def long_range_iter(start: ptr[PyObject], step: ptr[PyObject], length: ptr[PyObject]) -> ptr[PyObject] {
    allocated = jacpy_range_alloc(ptr[PyTypeObject_Layout](PyLongRangeIter_Type), 40);
    if allocated == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    py_incref(start);
    py_incref(step);
    py_incref(length);
    it = ptr[PyLongRangeIterObject_Layout](allocated);
    it.start = start;
    it.step = step;
    it.len = length;
    return allocated;
}

def range_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    start = PyLong_AsLong(r.start);
    if start == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return long_range_iter(r.start, r.step, r.length);
    }
    stop = PyLong_AsLong(r.stop);
    if stop == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return long_range_iter(r.start, r.step, r.length);
    }
    step = PyLong_AsLong(r.step);
    if step == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return long_range_iter(r.start, r.step, r.length);
    }
    count = get_len_of_range(start, stop, step);
    if count > 9223372036854775807 {
        return long_range_iter(r.start, r.step, r.length);
    }
    if count != 0 {
        if step > 0 and stop > 9223372036854775807 - (step - 1) {
            return long_range_iter(r.start, r.step, r.length);
        }
        if step < 0 and stop < -9223372036854775807 - 1 + (-1 - step) {
            return long_range_iter(r.start, r.step, r.length);
        }
    }
    return fast_range_iter(start, step, i64(count));
}

def range_reverse(self: ptr[PyObject]) -> ptr[PyObject] {
    r = ptr[PyRangeObject_Layout](self);
    start = PyLong_AsLong(r.start);
    if start == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return range_reverse_long(r);
    }
    stop = PyLong_AsLong(r.stop);
    if stop == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return range_reverse_long(r);
    }
    step = PyLong_AsLong(r.step);
    if step == -1 and PyErr_Occurred() != ptr[PyObject]() {
        PyErr_Clear();
        return range_reverse_long(r);
    }
    if step == -9223372036854775807 - 1 {
        return range_reverse_long(r);
    }

    if step > 0 {
        if wrapping_sub(u64.wrap(start), u64.wrap(-9223372036854775807 - 1))
            < u64(step) {
            return range_reverse_long(r);
        }
    } elif wrapping_sub(u64(9223372036854775807), u64.wrap(start))
        < wrapping_sub(u64(0), u64.wrap(step)) {
        return range_reverse_long(r);
    }

    count = get_len_of_range(start, stop, step);
    if count > 9223372036854775807 {
        return range_reverse_long(r);
    }
    new_stop = start - step;
    new_start = i64.wrap(
        wrapping_add(u64.wrap(new_stop), wrapping_mul(count, u64.wrap(step)))
    );
    return fast_range_iter(new_start, -step, i64(count));
}

def range_reverse_long(r: ptr[PyRangeObject_Layout]) -> ptr[PyObject] {
    one = jacpy_long_one();
    n_minus_one = PyNumber_Subtract(r.length, one);
    if n_minus_one == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    offset = PyNumber_Multiply(n_minus_one, r.step);
    py_decref(n_minus_one);
    if offset == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    start = PyNumber_Add(r.start, offset);
    py_decref(offset);
    if start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    step = PyNumber_Negative(r.step);
    if step == ptr[PyObject]() {
        py_decref(start);
        return ptr[PyObject]();
    }
    allocated = jacpy_range_alloc(ptr[PyTypeObject_Layout](PyLongRangeIter_Type), 40);
    if allocated == ptr[PyObject]() {
        py_decref(start);
        py_decref(step);
        return ptr[PyObject]();
    }
    py_incref(r.length);
    it = ptr[PyLongRangeIterObject_Layout](allocated);
    it.start = start;
    it.step = step;
    it.len = r.length;
    return allocated;
}

def rangeiter_next(self: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[PyRangeIterObject_Layout](self);
    if it.len <= 0 {
        return ptr[PyObject]();
    }
    result = it.start;
    # C wraps `start + step` past the last element.
    it.start = wrapping_add(result, it.step);
    it.len = wrapping_sub(it.len, 1);
    return PyLong_FromLong(result);
}

def longrangeiter_next(self: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[PyLongRangeIterObject_Layout](self);
    if PyObject_RichCompareBool(it.len, jacpy_long_zero(), Py_GT) != 1 {
        return ptr[PyObject]();
    }
    next_start = PyNumber_Add(it.start, it.step);
    if next_start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    next_len = PyNumber_Subtract(it.len, jacpy_long_one());
    if next_len == ptr[PyObject]() {
        py_decref(next_start);
        return ptr[PyObject]();
    }
    result = it.start;
    it.start = next_start;
    old_len = it.len;
    it.len = next_len;
    py_decref(old_len);
    return result;
}


def longrangeiter_length(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    length = ptr[PyLongRangeIterObject_Layout](self).len;
    py_incref(length);
    return length;
}
def rangeiter_dealloc(self: ptr[PyObject]) -> None {
    jacpy_rangeiter_free(self);
}

def longrangeiter_dealloc(self: ptr[PyObject]) -> None {
    it = ptr[PyLongRangeIterObject_Layout](self);
    py_decref(it.start);
    py_decref(it.step);
    py_decref(it.len);
    PyObject_Free(ptr(self));
}

def rangeiter_length_hint(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(ptr[PyRangeIterObject_Layout](self).len);
}

def longrangeiter_length_hint(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    return longrangeiter_length(self, ignored, extra);
}

def rangeiter_setstate(self: ptr[PyObject], state: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    it = ptr[PyRangeIterObject_Layout](self);
    index = PyLong_AsLong(state);
    if index == -1 and PyErr_Occurred() != ptr[PyObject]() {
        return ptr[PyObject]();
    }
    if index < 0 {
        index = 0;
    } elif index > it.len {
        index = it.len;
    }
    it.start = it.start + index * it.step;
    it.len = it.len - index;
    py_incref(none_obj);
    return none_obj;
}

def longrangeiter_setstate(self: ptr[PyObject], state: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    none_obj: ptr[PyObject] = _Py_NoneStruct;
    if jacpy_is_exact_long(state) == 0 {
        jacpy_range_iter_bad_state(state);
        return ptr[PyObject]();
    }
    it = ptr[PyLongRangeIterObject_Layout](self);
    zero = jacpy_long_zero();
    negative = PyObject_RichCompareBool(state, zero, Py_LT);
    if negative < 0 {
        return ptr[PyObject]();
    }
    clipped = state;
    if negative != 0 {
        clipped = zero;
    } else {
        too_large = PyObject_RichCompareBool(it.len, state, Py_LT);
        if too_large < 0 {
            return ptr[PyObject]();
        }
        if too_large != 0 {
            clipped = it.len;
        }
    }
    product = PyNumber_Multiply(clipped, it.step);
    if product == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    start = PyNumber_Add(it.start, product);
    py_decref(product);
    if start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    length = PyNumber_Subtract(it.len, clipped);
    if length == ptr[PyObject]() {
        py_decref(start);
        return ptr[PyObject]();
    }
    old_start = it.start;
    old_length = it.len;
    it.start = start;
    it.len = length;
    py_decref(old_start);
    py_decref(old_length);
    py_incref(none_obj);
    return none_obj;
}

def rangeiter_reduce(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[PyRangeIterObject_Layout](self);
    start = PyLong_FromLong(it.start);
    if start == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    length = PyLong_FromLong(it.len);
    if length == ptr[PyObject]() {
        py_decref(start);
        return ptr[PyObject]();
    }
    step = PyLong_FromLong(it.step);
    if step == ptr[PyObject]() {
        py_decref(start);
        py_decref(length);
        return ptr[PyObject]();
    }
    product = PyNumber_Multiply(length, step);
    py_decref(length);
    if product == ptr[PyObject]() {
        py_decref(start);
        py_decref(step);
        return ptr[PyObject]();
    }
    stop = PyNumber_Add(start, product);
    py_decref(product);
    if stop == ptr[PyObject]() {
        py_decref(start);
        py_decref(step);
        return ptr[PyObject]();
    }
    range = range_make(ptr[PyTypeObject_Layout](PyRange_Type), start, stop, step);
    if range == ptr[PyObject]() {
        py_decref(start);
        py_decref(stop);
        py_decref(step);
        return ptr[PyObject]();
    }
    return jacpy_range_iter_reduce(range);
}

def longrangeiter_reduce(self: ptr[PyObject], ignored: ptr[PyObject], extra: ptr[PyObject]) -> ptr[PyObject] {
    it = ptr[PyLongRangeIterObject_Layout](self);
    product = PyNumber_Multiply(it.len, it.step);
    if product == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    stop = PyNumber_Add(it.start, product);
    py_decref(product);
    if stop == ptr[PyObject]() {
        return ptr[PyObject]();
    }
    py_incref(it.start);
    py_incref(it.step);
    range = range_make(ptr[PyTypeObject_Layout](PyRange_Type), it.start, stop, it.step);
    if range == ptr[PyObject]() {
        py_decref(it.start);
        py_decref(stop);
        py_decref(it.step);
        return ptr[PyObject]();
    }
    return jacpy_range_iter_reduce(range);
}

glob rangeiter_methods: RangeIterMethods_Layout = RangeIterMethods_Layout(
    e0=PyMethodDef_Layout(name="__length_hint__", ml_meth=rangeiter_length_hint, ml_flags=4, ml_doc="Private method returning an estimate of len(list(it))."),
    e1=PyMethodDef_Layout(name="__reduce__", ml_meth=rangeiter_reduce, ml_flags=4, ml_doc="Return state information for pickling."),
    e2=PyMethodDef_Layout(name="__setstate__", ml_meth=rangeiter_setstate, ml_flags=8, ml_doc="Set state information for unpickling."),
    sentinel=PyMethodDef_Layout()
);

glob longrangeiter_methods: RangeIterMethods_Layout = RangeIterMethods_Layout(
    e0=PyMethodDef_Layout(name="__length_hint__", ml_meth=longrangeiter_length_hint, ml_flags=4, ml_doc="Private method returning an estimate of len(list(it))."),
    e1=PyMethodDef_Layout(name="__reduce__", ml_meth=longrangeiter_reduce, ml_flags=4, ml_doc="Return state information for pickling."),
    e2=PyMethodDef_Layout(name="__setstate__", ml_meth=longrangeiter_setstate, ml_flags=8, ml_doc="Set state information for unpickling."),
    sentinel=PyMethodDef_Layout()
);

glob:pub PyRangeIter_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    tp_name="range_iterator",
    tp_basicsize=40,
    tp_dealloc=rangeiter_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=0,
    tp_iter=PyObject_SelfIter,
    tp_iternext=rangeiter_next,
    tp_methods=rangeiter_methods
);

glob:pub PyLongRangeIter_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyType_Type,
    tp_name="longrange_iterator",
    tp_basicsize=40,
    tp_dealloc=longrangeiter_dealloc,
    tp_getattro=PyObject_GenericGetAttr,
    tp_flags=0,
    tp_iter=PyObject_SelfIter,
    tp_iternext=longrangeiter_next,
    tp_methods=longrangeiter_methods
);
