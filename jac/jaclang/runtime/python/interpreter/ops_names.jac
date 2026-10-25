import from c {
    glob PyExc_NameError: ptr[PyObject],
         PyExc_UnboundLocalError: ptr[PyObject]; obj NamesUnicodeEntry {
        has me_key: ptr[PyObject],
            me_value: ptr[PyObject];
    }  def _PyEval_LoadGlobalStackRef(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        name: ptr[PyObject],
        writeto: ptr[u64]
    );  def _PyEval_LoadName(
        tstate: ptr[PyThreadState], frame: ptr[u8], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_ImportName(
        tstate: ptr[PyThreadState],
        frame: ptr[u8],
        name: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_ImportFrom(
        tstate: ptr[PyThreadState], v: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_FormatExcCheckArg(
        tstate: ptr[PyThreadState],
        exc: ptr[PyObject],
        format_str: ptr[u8],
        obj_: ptr[PyObject]
    );  def _PyEval_FormatExcUnbound(
        tstate: ptr[PyThreadState], co: ptr[PyCodeObject], oparg: i32
    );  def _Py_Specialize_LoadGlobal(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        instr: ptr[u16],
        name: ptr[PyObject]
    );  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def _PyDict_LoadGlobal(
        globals: ptr[PyObject], builtins: ptr[PyObject], key: ptr[PyObject]
    ) -> ptr[PyObject];  def PyCell_New(obj_: ptr[PyObject]) -> ptr[PyObject];
}

glob ST_OK: Final[i32] = 0,
     ST_ERROR: Final[i32] = 1,
     ST_DEOPT: Final[i32] = 2,
     ST_REDISPATCH: Final[i32] = 3;

def names_frame_local(frame: ptr[u8], index: i32) -> ptr[u64];

def names_frame_code(frame: ptr[u8]) -> ptr[u8];

def names_tstate_interp(tstate: ptr) -> ptr[u8];

def names_frame_object(frame: ptr[u8], offset: i64) -> ptr[PyObject];

def names_code_name(frame: ptr[u8], index: i32) -> ptr[PyObject];

def names_localsplusnames(frame: ptr[u8]) -> ptr[PyObject];

def names_dict_check_exact(op: ptr[PyObject]) -> bool;

def names_dict_keys(dict_: ptr[PyObject]) -> ptr[u8];

def names_keys_version(keys: ptr[u8]) -> u32;

def names_unicode_value(keys: ptr[u8], index: u16) -> ptr[PyObject];

def names_cell(frame: ptr[u8], oparg: i32) -> ptr[PyCellObject];

def names_format_unbound_local(tstate: ptr, frame: ptr[u8], oparg: i32);

def names_format_name_error(tstate: ptr, name: ptr[PyObject]);

def LOAD_FAST_CHECK(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64;

def DELETE_FAST(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32;

def LOAD_COMMON_CONSTANT(tstate: ptr, oparg: i32) -> u64;

def STORE_NAME(frame: ptr[u8], oparg: i32, v: u64) -> i32;

def DELETE_NAME(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32;

def STORE_GLOBAL(frame: ptr[u8], oparg: i32, v: u64) -> i32;

def DELETE_GLOBAL(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32;

def LOAD_LOCALS(frame: ptr[u8]) -> u64;

def LOAD_FROM_DICT_OR_GLOBALS(
    frame: ptr[u8], tstate: ptr, oparg: i32, mod_or_class_dict: u64
) -> u64;

def LOAD_NAME(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64;

def _SPECIALIZE_LOAD_GLOBAL(
    frame: ptr[u8], oparg: i32, this_instr: ptr[u16], counter: u16
) -> i32;

def _LOAD_GLOBAL(frame: ptr[u8], oparg: i32, res: ptr[u64]) -> i32;

def _GUARD_GLOBALS_VERSION(frame: ptr[u8], version: u16) -> bool;

def _LOAD_GLOBAL_MODULE(
    frame: ptr[u8], version: u16, index: u16, res: ptr[u64]
) -> i32;

def _LOAD_GLOBAL_BUILTINS(
    frame: ptr[u8], version: u16, index: u16, res: ptr[u64]
) -> i32;

def MAKE_CELL(frame: ptr[u8], oparg: i32) -> i32;

def DELETE_DEREF(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32;

def LOAD_FROM_DICT_OR_DEREF(
    frame: ptr[u8], tstate: ptr, oparg: i32, class_dict_st: u64
) -> u64;

def LOAD_DEREF(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64;

def STORE_DEREF(frame: ptr[u8], oparg: i32, v: u64);

def COPY_FREE_VARS(frame: ptr[u8], oparg: i32);

def SETUP_ANNOTATIONS(frame: ptr[u8]) -> i32;

def IMPORT_NAME(
    frame: ptr[u8], tstate: ptr, oparg: i32, level: u64, fromlist: u64
) -> u64;

def IMPORT_FROM(frame: ptr[u8], tstate: ptr, oparg: i32, from_: u64) -> u64;

impl names_frame_object(frame: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](frame + offset).view(1)[0];
}

impl names_code_name(frame: ptr[u8], index: i32) -> ptr[PyObject] {
    names = ptr[ptr[PyObject]](names_frame_code(frame) + PyCodeObject_NAMES).view(1)[0];
    return tuple_get_item(names, i64(index));
}

impl names_localsplusnames(frame: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](
        names_frame_code(frame) + PyCodeObject_LOCALSPLUSNAMES
    ).view(
        1
    )[0];
}

impl names_dict_check_exact(op: ptr[PyObject]) -> bool {
    return ptr[_object](op).view(1)[0].ob_type
        == ptr[PyTypeObject](addressof(PyDict_Type));
}

impl names_dict_keys(dict_: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](ptr[PyDictObject](dict_).view(1)[0].ma_keys);
}

impl names_keys_version(keys: ptr[u8]) -> u32 {
    return ptr[u32](keys + PyDictKeysObject_VERSION).view(1)[0];
}

impl names_unicode_value(keys: ptr[u8], index: u16) -> ptr[PyObject] {
    log2_index_bytes = (keys + PyDictKeysObject_LOG2_INDEX_BYTES).view(1)[0];
    entries = ptr[NamesUnicodeEntry](
        keys + PyDictKeysObject_INDICES + (i64(1) << i64(log2_index_bytes))
    );
    return (entries + i64(index)).view(1)[0].me_value;
}

impl names_cell(frame: ptr[u8], oparg: i32) -> ptr[PyCellObject] {
    return ptr[PyCellObject](sr_borrow(names_frame_local(frame, oparg).view(1)[0]));
}

impl names_format_unbound_local(tstate: ptr, frame: ptr[u8], oparg: i32) {
    _PyEval_FormatExcCheckArg(
        ptr[PyThreadState](tstate),
        PyExc_UnboundLocalError,
        ptr[u8](
            "cannot access local variable '%s' where it is not associated with a value"
        ),
        PyTuple_GetItem(names_localsplusnames(frame), i64(oparg))
    );
}

impl names_format_name_error(tstate: ptr, name: ptr[PyObject]) {
    _PyEval_FormatExcCheckArg(
        ptr[PyThreadState](tstate),
        PyExc_NameError,
        ptr[u8]("name '%.200s' is not defined"),
        name
    );
}

impl LOAD_FAST_CHECK(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64 {
    value_s = names_frame_local(frame, oparg).view(1)[0];
    if sr_is_null(value_s) {
        names_format_unbound_local(tstate, frame, oparg);
        return u64(0);
    }
    return sr_dup(value_s);
}

impl DELETE_FAST(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32 {
    slot = names_frame_local(frame, oparg);
    if sr_is_null(slot.view(1)[0]) {
        names_format_unbound_local(tstate, frame, oparg);
        return ST_ERROR;
    }
    tmp = slot.view(1)[0];
    slot.view(1)[0] = SR_NULL;
    sr_xclose(tmp);
    return ST_OK;
}

impl LOAD_COMMON_CONSTANT(tstate: ptr, oparg: i32) -> u64 {
    consts = ptr[ptr[PyObject]](
        names_tstate_interp(tstate) + PyInterpreterState_COMMON_CONSTS
    );
    return sr_new((consts + i64(oparg)).view(1)[0]);
}

impl STORE_NAME(frame: ptr[u8], oparg: i32, v: u64) -> i32 {
    name = names_code_name(frame, oparg);
    ns = names_frame_object(frame, _PyInterpreterFrame_F_LOCALS);
    if not ns {
        PyErr_Format(
            PyExc_SystemError, ptr[u8]("no locals found when storing %R"), name
        );
        return ST_ERROR;
    }
    err: i32 = 0;
    if names_dict_check_exact(ns) {
        err = PyDict_SetItem(ns, name, sr_borrow(v));
    } else {
        err = PyObject_SetItem(ns, name, sr_borrow(v));
    }
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl DELETE_NAME(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32 {
    name = names_code_name(frame, oparg);
    ns = names_frame_object(frame, _PyInterpreterFrame_F_LOCALS);
    if not ns {
        PyErr_Format(PyExc_SystemError, ptr[u8]("no locals when deleting %R"), name);
        return ST_ERROR;
    }
    err = PyObject_DelItem(ns, name);
    if err != 0 {
        names_format_name_error(tstate, name);
        return ST_ERROR;
    }
    return ST_OK;
}

impl STORE_GLOBAL(frame: ptr[u8], oparg: i32, v: u64) -> i32 {
    name = names_code_name(frame, oparg);
    err = PyDict_SetItem(
        names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS), name, sr_borrow(v)
    );
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl DELETE_GLOBAL(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32 {
    name = names_code_name(frame, oparg);
    err = PyDict_Pop(
        names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS), name, None
    );
    if err < 0 {
        return ST_ERROR;
    }
    if err == 0 {
        names_format_name_error(tstate, name);
        return ST_ERROR;
    }
    return ST_OK;
}

impl LOAD_LOCALS(frame: ptr[u8]) -> u64 {
    l = names_frame_object(frame, _PyInterpreterFrame_F_LOCALS);
    if not l {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("no locals found"));
        return u64(0);
    }
    return sr_new(l);
}

impl LOAD_FROM_DICT_OR_GLOBALS(
    frame: ptr[u8], tstate: ptr, oparg: i32, mod_or_class_dict: u64
) -> u64 {
    name = names_code_name(frame, oparg);
    v_o: ptr[PyObject] = NULL;
    err = PyMapping_GetOptionalItem(sr_borrow(mod_or_class_dict), name, &mut v_o);
    sr_close(mod_or_class_dict);
    if err < 0 {
        return u64(0);
    }
    if not v_o {
        globals = names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS);
        builtins = names_frame_object(frame, _PyInterpreterFrame_F_BUILTINS);
        if names_dict_check_exact(globals) and names_dict_check_exact(builtins) {
            v_o = _PyDict_LoadGlobal(globals, builtins, name);
            if not v_o {
                if not PyErr_Occurred() {
                    names_format_name_error(tstate, name);
                }
                return u64(0);
            }
        } else {
            err = PyMapping_GetOptionalItem(globals, name, &mut v_o);
            if err < 0 {
                return u64(0);
            }
            if not v_o {
                err = PyMapping_GetOptionalItem(builtins, name, &mut v_o);
                if err < 0 {
                    return u64(0);
                }
                if not v_o {
                    names_format_name_error(tstate, name);
                    return u64(0);
                }
            }
        }
    }
    return sr_steal(v_o);
}

impl LOAD_NAME(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64 {
    v_o = _PyEval_LoadName(
        ptr[PyThreadState](tstate), frame, names_code_name(frame, oparg)
    );
    if not v_o {
        return u64(0);
    }
    return sr_steal(v_o);
}

impl _SPECIALIZE_LOAD_GLOBAL(
    frame: ptr[u8], oparg: i32, this_instr: ptr[u16], counter: u16
) -> i32 {
    if counter < u16(15) {
        _Py_Specialize_LoadGlobal(
            names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS),
            names_frame_object(frame, _PyInterpreterFrame_F_BUILTINS),
            this_instr,
            names_code_name(frame, oparg >> 1)
        );
        return ST_REDISPATCH;
    }
    cache = this_instr + 1;
    cache.view(1)[0] = u16.wrap(i64(cache.view(1)[0]) - 16);
    return ST_OK;
}

impl _LOAD_GLOBAL(frame: ptr[u8], oparg: i32, res: ptr[u64]) -> i32 {
    _PyEval_LoadGlobalStackRef(
        names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS),
        names_frame_object(frame, _PyInterpreterFrame_F_BUILTINS),
        names_code_name(frame, oparg >> 1),
        res
    );
    if sr_is_null(res.view(1)[0]) {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _GUARD_GLOBALS_VERSION(frame: ptr[u8], version: u16) -> bool {
    dict_ = names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS);
    if not names_dict_check_exact(dict_) {
        return False;
    }
    return names_keys_version(names_dict_keys(dict_)) == u32(version);
}

impl _LOAD_GLOBAL_MODULE(
    frame: ptr[u8], version: u16, index: u16, res: ptr[u64]
) -> i32 {
    dict_ = names_frame_object(frame, _PyInterpreterFrame_F_GLOBALS);
    if not names_dict_check_exact(dict_) {
        return ST_DEOPT;
    }
    keys = names_dict_keys(dict_);
    if names_keys_version(keys) != u32(version) {
        return ST_DEOPT;
    }
    res_o = names_unicode_value(keys, index);
    if not res_o {
        return ST_DEOPT;
    }
    res.view(1)[0] = sr_new(res_o);
    return ST_OK;
}

impl _LOAD_GLOBAL_BUILTINS(
    frame: ptr[u8], version: u16, index: u16, res: ptr[u64]
) -> i32 {
    dict_ = names_frame_object(frame, _PyInterpreterFrame_F_BUILTINS);
    if not names_dict_check_exact(dict_) {
        return ST_DEOPT;
    }
    keys = names_dict_keys(dict_);
    if names_keys_version(keys) != u32(version) {
        return ST_DEOPT;
    }
    res_o = names_unicode_value(keys, index);
    if not res_o {
        return ST_DEOPT;
    }
    res.view(1)[0] = sr_new(res_o);
    return ST_OK;
}

impl MAKE_CELL(frame: ptr[u8], oparg: i32) -> i32 {
    slot = names_frame_local(frame, oparg);
    cell = PyCell_New(sr_borrow(slot.view(1)[0]));
    if not cell {
        return ST_ERROR;
    }
    tmp = slot.view(1)[0];
    slot.view(1)[0] = sr_steal(cell);
    sr_xclose(tmp);
    return ST_OK;
}

impl DELETE_DEREF(frame: ptr[u8], tstate: ptr, oparg: i32) -> i32 {
    cell = names_cell(frame, oparg);
    oldobj = cell.view(1)[0].ob_ref;
    cell.view(1)[0].ob_ref = NULL;
    if not oldobj {
        _PyEval_FormatExcUnbound(
            ptr[PyThreadState](tstate),
            ptr[PyCodeObject](names_frame_code(frame)),
            oparg
        );
        return ST_ERROR;
    }
    object_decref(oldobj);
    return ST_OK;
}

impl LOAD_FROM_DICT_OR_DEREF(
    frame: ptr[u8], tstate: ptr, oparg: i32, class_dict_st: u64
) -> u64 {
    name = tuple_get_item(names_localsplusnames(frame), i64(oparg));
    value_o: ptr[PyObject] = NULL;
    err = PyMapping_GetOptionalItem(sr_borrow(class_dict_st), name, &mut value_o);
    if err < 0 {
        return u64(0);
    }
    if not value_o {
        value_o = names_cell(frame, oparg).view(1)[0].ob_ref;
        if not value_o {
            _PyEval_FormatExcUnbound(
                ptr[PyThreadState](tstate),
                ptr[PyCodeObject](names_frame_code(frame)),
                oparg
            );
            return u64(0);
        }
        object_incref(value_o);
    }
    return sr_steal(value_o);
}

impl LOAD_DEREF(frame: ptr[u8], tstate: ptr, oparg: i32) -> u64 {
    value_o = names_cell(frame, oparg).view(1)[0].ob_ref;
    if not value_o {
        _PyEval_FormatExcUnbound(
            ptr[PyThreadState](tstate),
            ptr[PyCodeObject](names_frame_code(frame)),
            oparg
        );
        return u64(0);
    }
    return sr_new(value_o);
}

impl STORE_DEREF(frame: ptr[u8], oparg: i32, v: u64) {
    cell = names_cell(frame, oparg);
    value = sr_as_steal(v);
    old_value = cell.view(1)[0].ob_ref;
    cell.view(1)[0].ob_ref = value;
    object_xdecref(old_value);
}

impl COPY_FREE_VARS(frame: ptr[u8], oparg: i32) {
    co = names_frame_code(frame);
    func = sr_borrow(ptr[u64](frame + _PyInterpreterFrame_F_FUNCOBJ).view(1)[0]);
    closure = ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_CLOSURE).view(1)[0];
    offset = ptr[i32](co + PyCodeObject_NLOCALSPLUS).view(1)[0] - oparg;
    i: i32 = 0;
    while i < oparg {
        o = tuple_get_item(closure, i64(i));
        names_frame_local(frame, offset + i).view(1)[0] = sr_new(o);
        i += 1;
    }
}

impl SETUP_ANNOTATIONS(frame: ptr[u8]) -> i32 {
    ns = names_frame_object(frame, _PyInterpreterFrame_F_LOCALS);
    if not ns {
        PyErr_Format(
            PyExc_SystemError, ptr[u8]("no locals found when setting up annotations")
        );
        return ST_ERROR;
    }
    key = ptr[PyObject](
        ptr[u8](addressof(_PyRuntime))
            + _PyRuntimeState_GLOBAL_STRINGS
            + _Py_ID___annotations__
    );
    ann_dict: ptr[PyObject] = NULL;
    err = PyMapping_GetOptionalItem(ns, key, &mut ann_dict);
    if err < 0 {
        return ST_ERROR;
    }
    if not ann_dict {
        ann_dict = PyDict_New();
        if not ann_dict {
            return ST_ERROR;
        }
        err = PyObject_SetItem(ns, key, ann_dict);
        object_decref(ann_dict);
        if err != 0 {
            return ST_ERROR;
        }
    } else {
        object_decref(ann_dict);
    }
    return ST_OK;
}

impl IMPORT_NAME(
    frame: ptr[u8], tstate: ptr, oparg: i32, level: u64, fromlist: u64
) -> u64 {
    res_o = _PyEval_ImportName(
        ptr[PyThreadState](tstate),
        frame,
        names_code_name(frame, oparg),
        sr_borrow(fromlist),
        sr_borrow(level)
    );
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl IMPORT_FROM(frame: ptr[u8], tstate: ptr, oparg: i32, from_: u64) -> u64 {
    res_o = _PyEval_ImportFrom(
        ptr[PyThreadState](tstate), sr_borrow(from_), names_code_name(frame, oparg)
    );
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl names_frame_local(frame: ptr[u8], index: i32) -> ptr[u64] {
    return ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS) + i64(index);
}

impl names_frame_code(frame: ptr[u8]) -> ptr[u8] {
    bits = ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0];
    return ptr[u8](i64.wrap(bits & SR_PTR_MASK));
}

impl names_tstate_interp(tstate: ptr) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}
