import from c {
    obj ArithBinaryFuncSlot {
        has func: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  obj _PyBinaryOpSpecializationDescr {
        has oparg: i32 = 0,
            guard: Callable[[ptr[PyObject], ptr[PyObject]], i32] = 0,
            action: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  glob _PyEval_BinaryOps: ArithBinaryFuncSlot; def _Py_Specialize_BinaryOp(
        lhs: u64, rhs: u64, instr: ptr[u16], oparg: i32, locals: ptr[u64]
    );  def _Py_Specialize_CompareOp(lhs: u64, rhs: u64, instr: ptr[u16], oparg: i32);  def _Py_Specialize_ContainsOp(
        value: u64, instr: ptr[u16]
    );  def _Py_Specialize_StoreSubscr(container: u64, sub: u64, instr: ptr[u16]);  def _Py_Specialize_ToBool(
        value: u64, instr: ptr[u16]
    );  def _PyFloat_FromDouble_ConsumeInputs(
        left: u64, right: u64, value: f64
    ) -> u64;  def _PyFloat_ExactDealloc(ob: ptr[PyObject]);  def _PyUnicode_ExactDealloc(
        op: ptr[PyObject]
    );  def _PyUnicode_Equal(str1: ptr[PyObject], str2: ptr[PyObject]) -> i32;  def _PySet_Contains(
        so: ptr[PyObject], key: ptr[PyObject]
    ) -> i32;  def _PyList_SliceSubscript(
        op: ptr[PyObject], item: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyBuildSlice_ConsumeRefs(
        start: ptr[PyObject], stop: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyDict_SetItem_Take2(
        mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def _PyErr_SetKeyError(key: ptr[PyObject]);
}

def arith_close_float(ref: u64);

def arith_close_unicode(ref: u64);

def arith_bool(flag: bool) -> u64;

def arith_float_value(ref: u64) -> f64;

def arith_long_tag(ref: u64) -> u64;

def arith_long_digit0(ref: u64) -> i64;

def arith_long_compact_value(ref: u64) -> i64;

def arith_unicode_read_char(op: ptr[PyObject], index: i64) -> u32;

def arith_counter_advance(this_instr: ptr[u16], counter: u16);

def arith_has_stack_space(tstate: ptr, size: i32) -> bool;

def arith_heap_getitem(tp: ptr[PyTypeObject]) -> ptr[PyObject];

def UNARY_NEGATIVE(value: u64) -> u64;

def UNARY_INVERT(value: u64) -> u64;

def _SPECIALIZE_TO_BOOL(counter: u16, value: u64, this_instr: ptr[u16]) -> i32;

def _TO_BOOL(value: u64) -> u64;

def TO_BOOL_BOOL(value: u64) -> bool;

def TO_BOOL_INT(value: u64, res: ptr[u64]) -> i32;

def _GUARD_NOS_LIST(nos: u64) -> bool;

def _GUARD_TOS_SLICE(tos: u64) -> bool;

def _TO_BOOL_LIST(value: u64) -> u64;

def TO_BOOL_NONE(value: u64, res: ptr[u64]) -> i32;

def _GUARD_NOS_UNICODE(nos: u64) -> bool;

def _GUARD_TOS_UNICODE(value: u64) -> bool;

def _TO_BOOL_STR(value: u64) -> u64;

def _REPLACE_WITH_TRUE -> u64;

def _GUARD_NOS_FLOAT(left: u64) -> bool;

def _GUARD_TOS_FLOAT(value: u64) -> bool;

def _BINARY_OP_MULTIPLY_FLOAT(left: u64, right: u64) -> u64;

def _BINARY_OP_ADD_FLOAT(left: u64, right: u64) -> u64;

def _BINARY_OP_SUBTRACT_FLOAT(left: u64, right: u64) -> u64;

def _BINARY_OP_ADD_UNICODE(left: u64, right: u64) -> u64;

def _BINARY_OP_INPLACE_ADD_UNICODE(
    frame: ptr[u8], next_instr: ptr[u16], left: u64, right: u64
) -> i32;

def _SKIP_STORE_FAST -> i64;

def _GUARD_BINARY_OP_EXTEND(descr: u64, left: u64, right: u64) -> bool;

def _BINARY_OP_EXTEND(this_instr: ptr[u16], left: u64, right: u64) -> u64;

def _BINARY_SLICE(container: u64, start: u64, stop: u64) -> u64;

def _STORE_SLICE(v: u64, container: u64, start: u64, stop: u64) -> i32;

def _BINARY_OP_SUBSCR_LIST_INT(list_st: u64, sub_st: u64, res: ptr[u64]) -> i32;

def _BINARY_OP_SUBSCR_LIST_SLICE(list_st: u64, sub_st: u64) -> u64;

def _BINARY_OP_SUBSCR_STR_INT(str_st: u64, sub_st: u64, res: ptr[u64]) -> i32;

def _GUARD_NOS_TUPLE(nos: u64) -> bool;

def _BINARY_OP_SUBSCR_TUPLE_INT(tuple_st: u64, sub_st: u64, res: ptr[u64]) -> i32;

def _GUARD_NOS_DICT(nos: u64) -> bool;

def _GUARD_TOS_DICT(tos: u64) -> bool;

def _BINARY_OP_SUBSCR_DICT(dict_st: u64, sub_st: u64) -> u64;

def _BINARY_OP_SUBSCR_CHECK_FUNC(tstate: ptr, container: u64) -> bool;

def _BINARY_OP_SUBSCR_INIT_CALL(
    tstate: ptr, frame: ptr[u8], container: u64, sub: u64
) -> u64;

def _SPECIALIZE_STORE_SUBSCR(
    counter: u16, container: u64, sub: u64, this_instr: ptr[u16]
) -> i32;

def _STORE_SUBSCR(v: u64, container: u64, sub: u64) -> i32;

def _STORE_SUBSCR_LIST_INT(value: u64, list_st: u64, sub_st: u64) -> i32;

def _STORE_SUBSCR_DICT(value: u64, dict_st: u64, sub: u64) -> i32;

def DELETE_SUBSCR(container: u64, sub: u64) -> i32;

def _SPECIALIZE_COMPARE_OP(
    counter: u16, left: u64, right: u64, this_instr: ptr[u16], oparg: i32
) -> i32;

def _COMPARE_OP(oparg: i32, left: u64, right: u64) -> u64;

def _COMPARE_OP_FLOAT(oparg: i32, left: u64, right: u64) -> u64;

def _COMPARE_OP_INT(oparg: i32, left: u64, right: u64, res: ptr[u64]) -> i32;

def _COMPARE_OP_STR(oparg: i32, left: u64, right: u64) -> u64;

def IS_OP(oparg: i32, left: u64, right: u64) -> u64;

def _CONTAINS_OP(oparg: i32, left: u64, right: u64) -> u64;

def _SPECIALIZE_CONTAINS_OP(counter: u16, right: u64, this_instr: ptr[u16]) -> i32;

def _GUARD_TOS_ANY_SET(tos: u64) -> bool;

def _CONTAINS_OP_SET(oparg: i32, left: u64, right: u64) -> u64;

def _CONTAINS_OP_DICT(oparg: i32, left: u64, right: u64) -> u64;

def _SPECIALIZE_BINARY_OP(
    counter: u16, lhs: u64, rhs: u64, frame: ptr[u8], this_instr: ptr[u16], oparg: i32
) -> i32;

def _BINARY_OP(oparg: i32, lhs: u64, rhs: u64) -> u64;

impl arith_close_float(ref: u64) {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        op = ptr[PyObject](i64.wrap(ref));
        header = ptr[_object](op);
        full = header.view(1)[0].ob_refcnt_full - 1;
        header.view(1)[0].ob_refcnt_full = full;
        if (full & 0xFFFFFFFF) == 0 {
            reftracer_track(op, 1);
            _PyFloat_ExactDealloc(op);
        }
    }
}

impl arith_close_unicode(ref: u64) {
    if (ref & SR_TAG_REFCNT) == u64(0) {
        op = ptr[PyObject](i64.wrap(ref));
        header = ptr[_object](op);
        full = header.view(1)[0].ob_refcnt_full - 1;
        header.view(1)[0].ob_refcnt_full = full;
        if (full & 0xFFFFFFFF) == 0 {
            reftracer_track(op, 1);
            _PyUnicode_ExactDealloc(op);
        }
    }
}

impl arith_bool(flag: bool) -> u64 {
    if flag {
        return sr_true();
    }
    return sr_false();
}

impl arith_float_value(ref: u64) -> f64 {
    return ptr[PyFloatObject](sr_borrow(ref)).view(1)[0].ob_fval;
}

impl arith_long_tag(ref: u64) -> u64 {
    return ptr[PyLongObject](sr_borrow(ref)).view(1)[0].long_value.lv_tag;
}

impl arith_long_digit0(ref: u64) -> i64 {
    return i64(ptr[PyLongObject](sr_borrow(ref)).view(1)[0].long_value.ob_digit);
}

impl arith_long_compact_value(ref: u64) -> i64 {
    sign = 1 - i64(arith_long_tag(ref) & u64(3));
    return sign * arith_long_digit0(ref);
}

impl arith_unicode_read_char(op: ptr[PyObject], index: i64) -> u32 {
    state = ptr[u32](ptr[u8](op) + PyASCIIObject_STATE).view(1)[0];
    kind = (state >> u32(2)) & u32(7);
    data = ptr[u8]();
    if (state & u32(0x20)) != u32(0) {
        if (state & u32(0x40)) != u32(0) {
            data = ptr[u8](op) + PyASCIIObject_SIZE;
        } else {
            data = ptr[u8](op) + PyCompactUnicodeObject_SIZE;
        }
    } else {
        data = ptr[ptr[u8]](ptr[u8](op) + PyUnicodeObject_DATA).view(1)[0];
    }
    if kind == u32(1) {
        return u32((data + index).view(1)[0]);
    }
    if kind == u32(2) {
        return u32((ptr[u16](data) + index).view(1)[0]);
    }
    return (ptr[u32](data) + index).view(1)[0];
}

impl arith_counter_advance(this_instr: ptr[u16], counter: u16) {
    (this_instr + 1).view(1)[0] = u16.wrap(i64(counter) - 16);
}

impl arith_has_stack_space(tstate: ptr, size: i32) -> bool {
    top = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP).view(1)[0];
    if not top {
        return False;
    }
    limit = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_LIMIT).view(1)[0];
    return i64(size) < i64((int(limit) - int(top)) // 8);
}

impl UNARY_NEGATIVE(value: u64) -> u64 {
    res_o = PyNumber_Negative(sr_borrow(value));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl UNARY_INVERT(value: u64) -> u64 {
    res_o = PyNumber_Invert(sr_borrow(value));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _SPECIALIZE_TO_BOOL(counter: u16, value: u64, this_instr: ptr[u16]) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_ToBool(value, this_instr);
        return ST_REDISPATCH;
    }
    arith_counter_advance(this_instr, counter);
    return ST_OK;
}

impl _TO_BOOL(value: u64) -> u64 {
    err = PyObject_IsTrue(sr_borrow(value));
    if err < 0 {
        return u64(0);
    }
    return arith_bool(err != 0);
}

impl TO_BOOL_BOOL(value: u64) -> bool {
    return sr_type(value) == ptr[PyTypeObject](addressof(PyBool_Type));
}

impl TO_BOOL_INT(value: u64, res: ptr[u64]) -> i32 {
    if sr_type(value) != ptr[PyTypeObject](addressof(PyLong_Type)) {
        return ST_DEOPT;
    }
    res.view(1)[0] = arith_bool((arith_long_tag(value) & u64(3)) != u64(1));
    return ST_OK;
}

impl _GUARD_NOS_LIST(nos: u64) -> bool {
    return sr_type(nos) == ptr[PyTypeObject](addressof(PyList_Type));
}

impl _GUARD_TOS_SLICE(tos: u64) -> bool {
    return sr_type(tos) == ptr[PyTypeObject](addressof(PySlice_Type));
}

impl _TO_BOOL_LIST(value: u64) -> u64 {
    return arith_bool(ptr[PyVarObject](sr_borrow(value)).view(1)[0].ob_size != 0);
}

impl TO_BOOL_NONE(value: u64, res: ptr[u64]) -> i32 {
    if not sr_is_none(value) {
        return ST_DEOPT;
    }
    res.view(1)[0] = sr_false();
    return ST_OK;
}

impl _GUARD_NOS_UNICODE(nos: u64) -> bool {
    return sr_type(nos) == ptr[PyTypeObject](addressof(PyUnicode_Type));
}

impl _GUARD_TOS_UNICODE(value: u64) -> bool {
    return sr_type(value) == ptr[PyTypeObject](addressof(PyUnicode_Type));
}

impl _TO_BOOL_STR(value: u64) -> u64 {
    empty = ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_STR_EMPTY;
    return arith_bool(ptr[u8](sr_borrow(value)) != empty);
}

impl _REPLACE_WITH_TRUE -> u64 {
    return sr_true();
}

impl _GUARD_NOS_FLOAT(left: u64) -> bool {
    return sr_type(left) == ptr[PyTypeObject](addressof(PyFloat_Type));
}

impl _GUARD_TOS_FLOAT(value: u64) -> bool {
    return sr_type(value) == ptr[PyTypeObject](addressof(PyFloat_Type));
}

impl _BINARY_OP_MULTIPLY_FLOAT(left: u64, right: u64) -> u64 {
    dres = arith_float_value(left) * arith_float_value(right);
    res = _PyFloat_FromDouble_ConsumeInputs(left, right, dres);
    if res == SR_NULL {
        return u64(0);
    }
    return res;
}

impl _BINARY_OP_ADD_FLOAT(left: u64, right: u64) -> u64 {
    dres = arith_float_value(left) + arith_float_value(right);
    res = _PyFloat_FromDouble_ConsumeInputs(left, right, dres);
    if res == SR_NULL {
        return u64(0);
    }
    return res;
}

impl _BINARY_OP_SUBTRACT_FLOAT(left: u64, right: u64) -> u64 {
    dres = arith_float_value(left) - arith_float_value(right);
    res = _PyFloat_FromDouble_ConsumeInputs(left, right, dres);
    if res == SR_NULL {
        return u64(0);
    }
    return res;
}

impl _BINARY_OP_ADD_UNICODE(left: u64, right: u64) -> u64 {
    res_o = PyUnicode_Concat(sr_borrow(left), sr_borrow(right));
    arith_close_unicode(right);
    arith_close_unicode(left);
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _BINARY_OP_INPLACE_ADD_UNICODE(
    frame: ptr[u8], next_instr: ptr[u16], left: u64, right: u64
) -> i32 {
    target_local = frame_local(frame, next_oparg(next_instr));
    if not sr_is(target_local.view(1)[0], left) {
        return ST_DEOPT;
    }
    arith_close_unicode(left);
    temp: ptr[PyObject] = sr_as_steal(target_local.view(1)[0]);
    PyUnicode_Append(&mut temp, sr_borrow(right));
    sr_close(right);
    if not temp {
        target_local.view(1)[0] = SR_NULL;
        return ST_ERROR;
    }
    target_local.view(1)[0] = sr_steal(temp);
    return ST_OK;
}

impl _SKIP_STORE_FAST -> i64 {
    return 1;
}

impl _GUARD_BINARY_OP_EXTEND(descr: u64, left: u64, right: u64) -> bool {
    d = ptr[_PyBinaryOpSpecializationDescr](i64.wrap(descr));
    return d.view(1)[0].guard(sr_borrow(left), sr_borrow(right)) != 0;
}

impl _BINARY_OP_EXTEND(this_instr: ptr[u16], left: u64, right: u64) -> u64 {
    descr = ptr[u64](this_instr + 2).view(1)[0];
    d = ptr[_PyBinaryOpSpecializationDescr](i64.wrap(descr));
    res_o = d.view(1)[0].action(sr_borrow(left), sr_borrow(right));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _BINARY_SLICE(container: u64, start: u64, stop: u64) -> u64 {
    slice = _PyBuildSlice_ConsumeRefs(sr_as_steal(start), sr_as_steal(stop));
    res_o: ptr[PyObject] = NULL;
    if slice {
        res_o = PyObject_GetItem(sr_borrow(container), slice);
        object_decref(slice);
    }
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _STORE_SLICE(v: u64, container: u64, start: u64, stop: u64) -> i32 {
    slice = _PyBuildSlice_ConsumeRefs(sr_as_steal(start), sr_as_steal(stop));
    err: i32 = 1;
    if slice {
        err = PyObject_SetItem(sr_borrow(container), slice, sr_borrow(v));
        object_decref(slice);
    }
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _BINARY_OP_SUBSCR_LIST_INT(list_st: u64, sub_st: u64, res: ptr[u64]) -> i32 {
    if arith_long_tag(sub_st) > u64(8) {
        return ST_DEOPT;
    }
    index = arith_long_digit0(sub_st);
    lst = ptr[PyListObject](sr_borrow(list_st));
    if index >= lst.view(1)[0].ob_base.ob_size {
        return ST_DEOPT;
    }
    res.view(1)[0] = sr_new((lst.view(1)[0].ob_item + index).view(1)[0]);
    return ST_OK;
}

impl _BINARY_OP_SUBSCR_LIST_SLICE(list_st: u64, sub_st: u64) -> u64 {
    res_o = _PyList_SliceSubscript(sr_borrow(list_st), sr_borrow(sub_st));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _BINARY_OP_SUBSCR_STR_INT(str_st: u64, sub_st: u64, res: ptr[u64]) -> i32 {
    if arith_long_tag(sub_st) > u64(8) {
        return ST_DEOPT;
    }
    index = arith_long_digit0(sub_st);
    s = sr_borrow(str_st);
    if ptr[i64](ptr[u8](s) + PyASCIIObject_LENGTH).view(1)[0] <= index {
        return ST_DEOPT;
    }
    c = arith_unicode_read_char(s, index);
    if c >= u32(128) {
        return ST_DEOPT;
    }
    res_o = ptr[PyObject](
        ptr[u8](addressof(_PyRuntime))
            + _PyRuntimeState_STRINGS_ASCII
            + i64(c) * _PyRuntimeState_STRINGS_ASCII_SIZE
    );
    sr_close_long(sub_st);
    sr_close(str_st);
    res.view(1)[0] = sr_immortal(res_o);
    return ST_OK;
}

impl _GUARD_NOS_TUPLE(nos: u64) -> bool {
    return sr_type(nos) == ptr[PyTypeObject](addressof(PyTuple_Type));
}

impl _BINARY_OP_SUBSCR_TUPLE_INT(tuple_st: u64, sub_st: u64, res: ptr[u64]) -> i32 {
    if arith_long_tag(sub_st) > u64(8) {
        return ST_DEOPT;
    }
    index = arith_long_digit0(sub_st);
    tup = ptr[PyTupleObject](sr_borrow(tuple_st));
    if index >= tup.view(1)[0].ob_base.ob_size {
        return ST_DEOPT;
    }
    item = (ptr[ptr[PyObject]](ptr[u8](tup) + PyTupleObject_ITEMS) + index).view(1)[0];
    sr_close_long(sub_st);
    res.view(1)[0] = sr_new(item);
    return ST_OK;
}

impl _GUARD_NOS_DICT(nos: u64) -> bool {
    return sr_type(nos) == ptr[PyTypeObject](addressof(PyDict_Type));
}

impl _GUARD_TOS_DICT(tos: u64) -> bool {
    return sr_type(tos) == ptr[PyTypeObject](addressof(PyDict_Type));
}

impl _BINARY_OP_SUBSCR_DICT(dict_st: u64, sub_st: u64) -> u64 {
    sub = sr_borrow(sub_st);
    res_o: ptr[PyObject] = NULL;
    rc = PyDict_GetItemRef(sr_borrow(dict_st), sub, &mut res_o);
    if rc == 0 {
        _PyErr_SetKeyError(sub);
    }
    if rc <= 0 {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl arith_heap_getitem(tp: ptr[PyTypeObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](tp) + PyHeapTypeObject_SPEC_CACHE_GETITEM).view(1)[
        0
    ];
}

impl _BINARY_OP_SUBSCR_CHECK_FUNC(tstate: ptr, container: u64) -> bool {
    tp = sr_type(container);
    if (tp.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) == u64(0) {
        return False;
    }
    getitem_o = arith_heap_getitem(tp);
    if not getitem_o {
        return False;
    }
    cached_version = ptr[u32](
        ptr[u8](tp) + PyHeapTypeObject_SPEC_CACHE_GETITEM_VERSION
    ).view(
        1
    )[0];
    if ptr[u32](ptr[u8](getitem_o) + PyFunctionObject_VERSION).view(1)[0]
        != cached_version {
        return False;
    }
    code = ptr[ptr[u8]](ptr[u8](getitem_o) + PyFunctionObject_CODE).view(1)[0];
    return arith_has_stack_space(
        tstate, ptr[i32](code + PyCodeObject_FRAMESIZE).view(1)[0]
    );
}

impl _BINARY_OP_SUBSCR_INIT_CALL(
    tstate: ptr, frame: ptr[u8], container: u64, sub: u64
) -> u64 {
    getitem = sr_new(arith_heap_getitem(sr_type(container)));
    func_o = sr_borrow(getitem);
    code = ptr[ptr[PyObject]](ptr[u8](func_o) + PyFunctionObject_CODE).view(1)[0];
    top_slot = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP);
    new_frame = top_slot.view(1)[0];
    framesize = ptr[i32](ptr[u8](code) + PyCodeObject_FRAMESIZE).view(1)[0];
    top_slot.view(1)[0] = new_frame + i64(framesize) * 8;
    frame_initialize(new_frame, getitem, NULL, code, 2, frame);
    frame_local(new_frame, 0).view(1)[0] = container;
    frame_local(new_frame, 1).view(1)[0] = sub;
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(6);
    return u64(int(new_frame));
}

impl _SPECIALIZE_STORE_SUBSCR(
    counter: u16, container: u64, sub: u64, this_instr: ptr[u16]
) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_StoreSubscr(container, sub, this_instr);
        return ST_REDISPATCH;
    }
    arith_counter_advance(this_instr, counter);
    return ST_OK;
}

impl _STORE_SUBSCR(v: u64, container: u64, sub: u64) -> i32 {
    err = PyObject_SetItem(sr_borrow(container), sr_borrow(sub), sr_borrow(v));
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _STORE_SUBSCR_LIST_INT(value: u64, list_st: u64, sub_st: u64) -> i32 {
    if arith_long_tag(sub_st) > u64(8) {
        return ST_DEOPT;
    }
    index = arith_long_digit0(sub_st);
    lst = ptr[PyListObject](sr_borrow(list_st));
    if index >= lst.view(1)[0].ob_base.ob_size {
        return ST_DEOPT;
    }
    slot = lst.view(1)[0].ob_item + index;
    old_value = slot.view(1)[0];
    slot.view(1)[0] = sr_as_steal(value);
    sr_close_long(sub_st);
    sr_close(list_st);
    object_decref(old_value);
    return ST_OK;
}

impl _STORE_SUBSCR_DICT(value: u64, dict_st: u64, sub: u64) -> i32 {
    err = _PyDict_SetItem_Take2(
        sr_borrow(dict_st), sr_as_steal(sub), sr_as_steal(value)
    );
    sr_close(dict_st);
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl DELETE_SUBSCR(container: u64, sub: u64) -> i32 {
    err = PyObject_DelItem(sr_borrow(container), sr_borrow(sub));
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _SPECIALIZE_COMPARE_OP(
    counter: u16, left: u64, right: u64, this_instr: ptr[u16], oparg: i32
) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_CompareOp(left, right, this_instr, oparg);
        return ST_REDISPATCH;
    }
    arith_counter_advance(this_instr, counter);
    return ST_OK;
}

impl _COMPARE_OP(oparg: i32, left: u64, right: u64) -> u64 {
    res_o = PyObject_RichCompare(sr_borrow(left), sr_borrow(right), oparg >> 5);
    sr_close(right);
    sr_close(left);
    if not res_o {
        return u64(0);
    }
    if (oparg & 16) != 0 {
        res_bool = PyObject_IsTrue(res_o);
        object_decref(res_o);
        if res_bool < 0 {
            return u64(0);
        }
        return arith_bool(res_bool != 0);
    }
    return sr_steal(res_o);
}

impl _COMPARE_OP_FLOAT(oparg: i32, left: u64, right: u64) -> u64 {
    dleft = arith_float_value(left);
    dright = arith_float_value(right);
    sign_ish: i32 = 1;
    if dleft < dright {
        sign_ish = 2;
    } elif dleft > dright {
        sign_ish = 4;
    } elif dleft == dright {
        sign_ish = 8;
    }
    arith_close_float(left);
    arith_close_float(right);
    return arith_bool((sign_ish & oparg) != 0);
}

impl _COMPARE_OP_INT(oparg: i32, left: u64, right: u64, res: ptr[u64]) -> i32 {
    if arith_long_tag(left) >= u64(16) {
        return ST_DEOPT;
    }
    if arith_long_tag(right) >= u64(16) {
        return ST_DEOPT;
    }
    ileft = arith_long_compact_value(left);
    iright = arith_long_compact_value(right);
    sign_ish: i32 = 8;
    if ileft < iright {
        sign_ish = 2;
    } elif ileft > iright {
        sign_ish = 4;
    }
    sr_close_long(left);
    sr_close_long(right);
    res.view(1)[0] = arith_bool((sign_ish & oparg) != 0);
    return ST_OK;
}

impl _COMPARE_OP_STR(oparg: i32, left: u64, right: u64) -> u64 {
    eq = _PyUnicode_Equal(sr_borrow(left), sr_borrow(right));
    arith_close_unicode(left);
    arith_close_unicode(right);
    return arith_bool(((7 + eq) & oparg) != 0);
}

impl IS_OP(oparg: i32, left: u64, right: u64) -> u64 {
    same: i32 = 0;
    if sr_is(left, right) {
        same = 1;
    }
    return arith_bool((same ^ oparg) != 0);
}

impl _CONTAINS_OP(oparg: i32, left: u64, right: u64) -> u64 {
    res = PySequence_Contains(sr_borrow(right), sr_borrow(left));
    if res < 0 {
        return u64(0);
    }
    return arith_bool((res ^ oparg) != 0);
}

impl _SPECIALIZE_CONTAINS_OP(counter: u16, right: u64, this_instr: ptr[u16]) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_ContainsOp(right, this_instr);
        return ST_REDISPATCH;
    }
    arith_counter_advance(this_instr, counter);
    return ST_OK;
}

impl _GUARD_TOS_ANY_SET(tos: u64) -> bool {
    tp = sr_type(tos);
    return (
        tp == ptr[PyTypeObject](addressof(PySet_Type))
        or tp == ptr[PyTypeObject](addressof(PyFrozenSet_Type))
    );
}

impl _CONTAINS_OP_SET(oparg: i32, left: u64, right: u64) -> u64 {
    res = _PySet_Contains(sr_borrow(right), sr_borrow(left));
    if res < 0 {
        return u64(0);
    }
    return arith_bool((res ^ oparg) != 0);
}

impl _CONTAINS_OP_DICT(oparg: i32, left: u64, right: u64) -> u64 {
    res = PyDict_Contains(sr_borrow(right), sr_borrow(left));
    if res < 0 {
        return u64(0);
    }
    return arith_bool((res ^ oparg) != 0);
}

impl _SPECIALIZE_BINARY_OP(
    counter: u16, lhs: u64, rhs: u64, frame: ptr[u8], this_instr: ptr[u16], oparg: i32
) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_BinaryOp(lhs, rhs, this_instr, oparg, frame_local(frame, 0));
        return ST_REDISPATCH;
    }
    arith_counter_advance(this_instr, counter);
    return ST_OK;
}

impl _BINARY_OP(oparg: i32, lhs: u64, rhs: u64) -> u64 {
    slot = ptr[ArithBinaryFuncSlot](addressof(_PyEval_BinaryOps)) + i64(oparg);
    res_o = slot.view(1)[0].func(sr_borrow(lhs), sr_borrow(rhs));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}
