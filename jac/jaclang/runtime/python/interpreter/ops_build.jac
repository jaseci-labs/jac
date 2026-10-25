import from c {
    def _PyTuple_FromStackRefStealOnSuccess(src: ptr[u64], n: i64) -> ptr[PyObject];  def _PyList_FromStackRefStealOnSuccess(
        src: ptr[u64], n: i64
    ) -> ptr[PyObject];  def _PyList_AppendTakeRefListResize(
        op: ptr[PyObject], newitem: ptr[PyObject]
    ) -> i32;  def _PyList_Extend(
        op: ptr[PyObject], iterable: ptr[PyObject]
    ) -> ptr[PyObject];  def _PySet_AddTakeRef(
        so: ptr[PyObject], key: ptr[PyObject]
    ) -> i32;  def _PySet_Update(so: ptr[PyObject], iterable: ptr[PyObject]) -> i32;  def _PyDict_FromItems(
        keys: ptr[ptr[PyObject]],
        keys_offset: i64,
        values: ptr[ptr[PyObject]],
        values_offset: i64,
        length: i64
    ) -> ptr[PyObject];  def _PyDict_MergeEx(
        a: ptr[PyObject], b: ptr[PyObject], override_mode: i32
    ) -> i32;  def _PyDict_SetItem_Take2(
        mp: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def _PyInterpolation_Build(
        value: ptr[PyObject],
        text: ptr[PyObject],
        conversion: i32,
        format_spec: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyTemplate_Build(
        strings: ptr[PyObject], interpolations: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_ASCII(v: ptr[PyObject]) -> ptr[PyObject];  def PyObject_Format(
        obj_: ptr[PyObject], format_spec: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Length(o: ptr[PyObject]) -> i64;  def _PyEval_MatchClass(
        tstate: ptr[PyThreadState],
        subject: ptr[PyObject],
        type: ptr[PyObject],
        nargs: i64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_MatchKeys(
        tstate: ptr[PyThreadState], map: ptr[PyObject], keys: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_UnpackIterableStackRef(
        tstate: ptr[PyThreadState],
        v: ptr[PyObject],
        argcnt: i32,
        argcntafter: i32,
        sp: ptr[u64]
    ) -> i32;  def _PyEval_FormatKwargsError(
        tstate: ptr[PyThreadState], func: ptr[PyObject], kwargs: ptr[PyObject]
    );  def _Py_Specialize_UnpackSequence(seq: u64, instr: ptr[u16], oparg: i32);  def _PyObjectArray_FromStackRefArray(
        refs: ptr[u64], nargs: i64, scratch: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]];  def _PyObjectArray_Free(
        array: ptr[ptr[PyObject]], scratch: ptr[ptr[PyObject]]
    );  obj BuildScratch {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject](),
            s10: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut BuildScratch) -> int;
}

def build_close_refs(refs: ptr[u64], n: i64);

def build_list_append_take_ref(lst: ptr[PyObject], newitem: ptr[PyObject]) -> i32;

def BUILD_TUPLE(values: ptr[u64], oparg: i32) -> u64;

def BUILD_LIST(values: ptr[u64], oparg: i32) -> u64;

def BUILD_SET(values: ptr[u64], oparg: i32) -> u64;

def BUILD_MAP(values: ptr[u64], oparg: i32) -> u64;

def BUILD_STRING(pieces: ptr[u64], oparg: i32) -> u64;

def BUILD_SLICE(args: ptr[u64], oparg: i32) -> u64;

def BUILD_INTERPOLATION(value: u64, text: u64, fmt: ptr[u64], oparg: i32) -> u64;

def BUILD_TEMPLATE(strings: u64, interpolations: u64) -> u64;

def CONVERT_VALUE(value: u64, oparg: i32) -> u64;

def FORMAT_SIMPLE(value: u64) -> u64;

def FORMAT_WITH_SPEC(value: u64, fmt_spec: u64) -> u64;

def GET_LEN(value: u64) -> u64;

def LIST_APPEND(lst: u64, v: u64) -> i32;

def LIST_EXTEND(lst: u64, iterable: u64) -> i32;

def SET_ADD(st: u64, v: u64) -> i32;

def SET_UPDATE(st: u64, iterable: u64) -> i32;

def DICT_UPDATE(dct: u64, update: u64) -> i32;

def DICT_MERGE(tstate: ptr, callable: u64, dct: u64, update: u64) -> i32;

def MAP_ADD(dct: u64, key: u64, value: u64) -> i32;

def MATCH_CLASS(tstate: ptr, subject: u64, type: u64, names: u64, oparg: i32) -> u64;

def MATCH_KEYS(tstate: ptr, subject: u64, keys: u64) -> u64;

def MATCH_MAPPING(subject: u64) -> u64;

def MATCH_SEQUENCE(subject: u64) -> u64;

def UNPACK_EX(tstate: ptr, seq: u64, oparg: i32, output: ptr[u64]) -> i32;

def _SPECIALIZE_UNPACK_SEQUENCE(
    counter: u16, seq: u64, this_instr: ptr[u16], oparg: i32
) -> i32;

def _UNPACK_SEQUENCE(tstate: ptr, seq: u64, oparg: i32, output: ptr[u64]) -> i32;

def _GUARD_TOS_TUPLE(tos: u64) -> bool;

def _UNPACK_SEQUENCE_TWO_TUPLE(seq: u64, val1: ptr[u64], val0: ptr[u64]) -> i32;

def _UNPACK_SEQUENCE_TUPLE(seq: u64, oparg: i32, values: ptr[u64]) -> i32;

def _UNPACK_SEQUENCE_LIST(seq: u64, oparg: i32, values: ptr[u64]) -> i32;

impl build_close_refs(refs: ptr[u64], n: i64) {
    i = n;
    while i > 0 {
        i = i - 1;
        sr_close((refs + i).view(1)[0]);
    }
}

impl build_list_append_take_ref(lst: ptr[PyObject], newitem: ptr[PyObject]) -> i32 {
    record = ptr[PyListObject](lst);
    n = object_size(lst);
    if record.view(1)[0].allocated > n {
        (record.view(1)[0].ob_item + n).view(1)[0] = newitem;
        ptr[PyVarObject](lst).view(1)[0].ob_size = n + 1;
        return 0;
    }
    return _PyList_AppendTakeRefListResize(lst, newitem);
}

impl BUILD_TUPLE(values: ptr[u64], oparg: i32) -> u64 {
    tup_o = _PyTuple_FromStackRefStealOnSuccess(values, i64(oparg));
    if not tup_o {
        build_close_refs(values, i64(oparg));
        return u64(0);
    }
    return sr_steal_mortal(tup_o);
}

impl BUILD_LIST(values: ptr[u64], oparg: i32) -> u64 {
    list_o = _PyList_FromStackRefStealOnSuccess(values, i64(oparg));
    if not list_o {
        build_close_refs(values, i64(oparg));
        return u64(0);
    }
    return sr_steal_mortal(list_o);
}

impl BUILD_SET(values: ptr[u64], oparg: i32) -> u64 {
    set_o = PySet_New(NULL);
    if not set_o {
        build_close_refs(values, i64(oparg));
        return u64(0);
    }
    err: i32 = 0;
    for i in range(i64(oparg)) {
        slot = values + i;
        value = slot.view(1)[0];
        slot.view(1)[0] = SR_NULL;
        if err == 0 {
            err = _PySet_AddTakeRef(set_o, sr_as_steal(value));
        } else {
            sr_close(value);
        }
    }
    if err != 0 {
        object_decref(set_o);
        return u64(0);
    }
    return sr_steal_mortal(set_o);
}

impl BUILD_MAP(values: ptr[u64], oparg: i32) -> u64 {
    slots: own BuildScratch = BuildScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    values_o = _PyObjectArray_FromStackRefArray(values, i64(oparg) * 2, scratch + 1);
    if not values_o {
        return u64(0);
    }
    map_o = _PyDict_FromItems(values_o, 2, values_o + 1, 2, i64(oparg));
    _PyObjectArray_Free(values_o - 1, scratch);
    if not map_o {
        return u64(0);
    }
    return sr_steal_mortal(map_o);
}

impl BUILD_STRING(pieces: ptr[u64], oparg: i32) -> u64 {
    slots: own BuildScratch = BuildScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    pieces_o = _PyObjectArray_FromStackRefArray(pieces, i64(oparg), scratch + 1);
    if not pieces_o {
        return u64(0);
    }
    str_o = _PyUnicode_JoinArray(unicode_get_empty(), pieces_o, i64(oparg));
    _PyObjectArray_Free(pieces_o - 1, scratch);
    if not str_o {
        return u64(0);
    }
    return sr_steal(str_o);
}

impl BUILD_SLICE(args: ptr[u64], oparg: i32) -> u64 {
    start_o = sr_borrow(args.view(1)[0]);
    stop_o = sr_borrow((args + 1).view(1)[0]);
    step_o = NULL;
    if oparg == 3 {
        step_o = sr_borrow((args + 2).view(1)[0]);
    }
    slice_o = PySlice_New(start_o, stop_o, step_o);
    if not slice_o {
        return u64(0);
    }
    return sr_steal_mortal(slice_o);
}

impl BUILD_INTERPOLATION(value: u64, text: u64, fmt: ptr[u64], oparg: i32) -> u64 {
    format_o = unicode_get_empty();
    if (oparg & 1) != 0 {
        format_o = sr_borrow(fmt.view(1)[0]);
    }
    interpolation_o = _PyInterpolation_Build(
        sr_borrow(value), sr_borrow(text), oparg >> 2, format_o
    );
    if not interpolation_o {
        return u64(0);
    }
    return sr_steal(interpolation_o);
}

impl BUILD_TEMPLATE(strings: u64, interpolations: u64) -> u64 {
    template_o = _PyTemplate_Build(sr_borrow(strings), sr_borrow(interpolations));
    if not template_o {
        return u64(0);
    }
    return sr_steal(template_o);
}

impl CONVERT_VALUE(value: u64, oparg: i32) -> u64 {
    value_o = sr_borrow(value);
    result_o = NULL;
    if oparg == 1 {
        result_o = PyObject_Str(value_o);
    } elif oparg == 2 {
        result_o = PyObject_Repr(value_o);
    } else {
        result_o = PyObject_ASCII(value_o);
    }
    if not result_o {
        return u64(0);
    }
    return sr_steal(result_o);
}

impl FORMAT_SIMPLE(value: u64) -> u64 {
    value_o = sr_borrow(value);
    if object_type(value_o) != ptr[PyTypeObject](addressof(PyUnicode_Type)) {
        res_o = PyObject_Format(value_o, NULL);
        sr_close(value);
        if not res_o {
            return u64(0);
        }
        return sr_steal(res_o);
    }
    return value;
}

impl FORMAT_WITH_SPEC(value: u64, fmt_spec: u64) -> u64 {
    res_o = PyObject_Format(sr_borrow(value), sr_borrow(fmt_spec));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl GET_LEN(value: u64) -> u64 {
    len_i = PyObject_Length(sr_borrow(value));
    if len_i < 0 {
        return u64(0);
    }
    len_o = PyLong_FromSsize_t(len_i);
    if not len_o {
        return u64(0);
    }
    return sr_steal(len_o);
}

impl LIST_APPEND(lst: u64, v: u64) -> i32 {
    if build_list_append_take_ref(sr_borrow(lst), sr_as_steal(v)) < 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl LIST_EXTEND(lst: u64, iterable: u64) -> i32 {
    iterable_o = sr_borrow(iterable);
    none_val = _PyList_Extend(sr_borrow(lst), iterable_o);
    if not none_val {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            tp = object_type(iterable_o);
            if int(tp.view(1)[0].tp_iter) == 0 and PySequence_Check(iterable_o) == 0 {
                PyErr_Clear();
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("Value after * must be an iterable, not %.200s"),
                    tp.view(1)[0].tp_name
                );
            }
        }
        return ST_ERROR;
    }
    return ST_OK;
}

impl SET_ADD(st: u64, v: u64) -> i32 {
    if _PySet_AddTakeRef(sr_borrow(st), sr_as_steal(v)) != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl SET_UPDATE(st: u64, iterable: u64) -> i32 {
    if _PySet_Update(sr_borrow(st), sr_borrow(iterable)) < 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl DICT_UPDATE(dct: u64, update: u64) -> i32 {
    update_o = sr_borrow(update);
    if PyDict_Update(sr_borrow(dct), update_o) < 0 {
        if PyErr_ExceptionMatches(PyExc_AttributeError) != 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.200s' object is not a mapping"),
                object_type(update_o).view(1)[0].tp_name
            );
        }
        return ST_ERROR;
    }
    return ST_OK;
}

impl DICT_MERGE(tstate: ptr, callable: u64, dct: u64, update: u64) -> i32 {
    update_o = sr_borrow(update);
    if _PyDict_MergeEx(sr_borrow(dct), update_o, 2) < 0 {
        _PyEval_FormatKwargsError(
            ptr[PyThreadState](tstate), sr_borrow(callable), update_o
        );
        return ST_ERROR;
    }
    return ST_OK;
}

impl MAP_ADD(dct: u64, key: u64, value: u64) -> i32 {
    if _PyDict_SetItem_Take2(sr_borrow(dct), sr_as_steal(key), sr_as_steal(value))
        != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl MATCH_CLASS(tstate: ptr, subject: u64, type: u64, names: u64, oparg: i32) -> u64 {
    attrs_o = _PyEval_MatchClass(
        ptr[PyThreadState](tstate),
        sr_borrow(subject),
        sr_borrow(type),
        i64(oparg),
        sr_borrow(names)
    );
    if attrs_o {
        return sr_steal(attrs_o);
    }
    if exception_raised(ptr[PyThreadState](tstate)) {
        return u64(0);
    }
    return sr_none();
}

impl MATCH_KEYS(tstate: ptr, subject: u64, keys: u64) -> u64 {
    values_or_none_o = _PyEval_MatchKeys(
        ptr[PyThreadState](tstate), sr_borrow(subject), sr_borrow(keys)
    );
    if not values_or_none_o {
        return u64(0);
    }
    return sr_steal(values_or_none_o);
}

impl MATCH_MAPPING(subject: u64) -> u64 {
    if (sr_type(subject).view(1)[0].tp_flags & Py_TPFLAGS_MAPPING) != 0 {
        return sr_true();
    }
    return sr_false();
}

impl MATCH_SEQUENCE(subject: u64) -> u64 {
    if (sr_type(subject).view(1)[0].tp_flags & Py_TPFLAGS_SEQUENCE) != 0 {
        return sr_true();
    }
    return sr_false();
}

impl UNPACK_EX(tstate: ptr, seq: u64, oparg: i32, output: ptr[u64]) -> i32 {
    seq_o = sr_as_steal(seq);
    before = oparg & 0xFF;
    after = oparg >> 8;
    top = output + (i64(before) + i64(after) + 1);
    res = _PyEval_UnpackIterableStackRef(
        ptr[PyThreadState](tstate), seq_o, before, after, top
    );
    object_decref(seq_o);
    if res == 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _SPECIALIZE_UNPACK_SEQUENCE(
    counter: u16, seq: u64, this_instr: ptr[u16], oparg: i32
) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_UnpackSequence(seq, this_instr, oparg);
        return ST_REDISPATCH;
    }
    (this_instr + 1).view(1)[0] = u16.wrap(i64(counter) - 16);
    return ST_OK;
}

impl _UNPACK_SEQUENCE(tstate: ptr, seq: u64, oparg: i32, output: ptr[u64]) -> i32 {
    seq_o = sr_as_steal(seq);
    res = _PyEval_UnpackIterableStackRef(
        ptr[PyThreadState](tstate), seq_o, oparg, -1, output + i64(oparg)
    );
    object_decref(seq_o);
    if res == 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _GUARD_TOS_TUPLE(tos: u64) -> bool {
    return sr_type(tos) == ptr[PyTypeObject](addressof(PyTuple_Type));
}

impl _UNPACK_SEQUENCE_TWO_TUPLE(seq: u64, val1: ptr[u64], val0: ptr[u64]) -> i32 {
    seq_o = sr_borrow(seq);
    if object_size(seq_o) != 2 {
        return ST_DEOPT;
    }
    val0.view(1)[0] = sr_new(tuple_get_item(seq_o, 0));
    val1.view(1)[0] = sr_new(tuple_get_item(seq_o, 1));
    return ST_OK;
}

impl _UNPACK_SEQUENCE_TUPLE(seq: u64, oparg: i32, values: ptr[u64]) -> i32 {
    seq_o = sr_borrow(seq);
    n = i64(oparg);
    if object_size(seq_o) != n {
        return ST_DEOPT;
    }
    items = tuple_items(seq_o);
    for k in range(n) {
        (values + k).view(1)[0] = sr_new((items + (n - 1 - k)).view(1)[0]);
    }
    return ST_OK;
}

impl _UNPACK_SEQUENCE_LIST(seq: u64, oparg: i32, values: ptr[u64]) -> i32 {
    seq_o = sr_borrow(seq);
    n = i64(oparg);
    if object_size(seq_o) != n {
        return ST_DEOPT;
    }
    items = ptr[PyListObject](seq_o).view(1)[0].ob_item;
    for k in range(n) {
        (values + k).view(1)[0] = sr_new((items + (n - 1 - k)).view(1)[0]);
    }
    return ST_OK;
}
