import from c {
    glob PySuper_Type: PyTypeObject,
         _PyInstrumentation_MISSING: PyObject,
         _Py_SpecialMethods: u8; def _Py_Specialize_LoadAttr(
        owner: u64, instr: ptr[u16], name: ptr[PyObject]
    );  def _Py_Specialize_StoreAttr(
        owner: u64, instr: ptr[u16], name: ptr[PyObject]
    );  def _Py_Specialize_LoadSuperAttr(
        global_super: u64, cls: u64, instr: ptr[u16], load_method: i32
    );  def _Py_LoadAttr_StackRefSteal(
        tstate: ptr[PyThreadState],
        owner: u64,
        name: ptr[PyObject],
        self_or_null: ptr[u64]
    ) -> u64;  def PyObject_DelAttr(v: ptr[PyObject], name: ptr[PyObject]) -> i32;  def _PySuper_Lookup(
        su_type: ptr[PyTypeObject],
        su_obj: ptr[PyObject],
        name: ptr[PyObject],
        method: ptr[i32]
    ) -> ptr[PyObject];  def _Py_call_instrumentation_2args(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    ) -> i32;  def _Py_call_instrumentation_exc2(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    );  def _PyObject_LookupSpecialMethod(
        attr: ptr[PyObject], method_and_self: ptr[u64]
    ) -> i32;  def _PyEval_SpecialMethodCanSuggest(
        self_: ptr[PyObject], oparg: i32
    ) -> i32;  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  obj AttrStack {
        has s0: u64 = u64(0),
            s1: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut AttrStack) -> int;
}

glob:priv ATTR_MANAGED_DICT_OFFSET: Final[i64] = -24,
     ATTR_UNICODE_ENTRY_SIZE: Final[i64] = 16,
     ATTR_DICT_KEYS_GENERAL: Final[u8] = u8(0),
     ATTR_DICT_KEYS_UNICODE: Final[u8] = u8(1),
     ATTR_DICT_EVENT_MODIFIED: Final[i32] = 1,
     ATTR_VALUES_VALID: Final[i64] = 3,
     ATTR_UNREACHABLE_BACKOFF: Final[u16] = u16(15),
     ATTR_BACKOFF_STEP: Final[i64] = 16,
     ATTR_EVENT_CALL: Final[i32] = 4,
     ATTR_EVENT_C_RETURN: Final[i32] = 16,
     ATTR_EVENT_C_RAISE: Final[i32] = 17;

def attr_name(frame: ptr[u8], index: i32) -> ptr[PyObject];

def attr_advance_counter(this_instr: ptr[u16], counter: u16);

def attr_inline_values(owner: ptr[PyObject]) -> ptr[u8];

def attr_values_valid(owner: ptr[PyObject]) -> bool;

def attr_slot(owner: ptr[PyObject], offset: u16) -> ptr[ptr[PyObject]];

def attr_dict_keys(dict: ptr[PyObject]) -> ptr[u8];

def attr_keys_nentries(keys: ptr[u8]) -> i64;

def attr_keys_kind(keys: ptr[u8]) -> u8;

def attr_keys_version(keys: ptr[u8]) -> u32;

def attr_unicode_entry(keys: ptr[u8], index: i64) -> ptr[ptr[PyObject]];

def attr_is_type(op: ptr[PyObject]) -> bool;

def attr_code_i32(code: ptr[u8], offset: i64) -> i32;

def attr_has_stack_space(tstate: ptr, size: i32) -> bool;

def attr_push_frame(
    tstate: ptr, func: u64, null_locals_from: i64, previous: ptr[u8]
) -> ptr[u8];

def attr_super_lookup_method(
    cls: ptr[PyTypeObject], self_: ptr[PyObject], name: ptr[PyObject], generic: bool
) -> tuple[ptr[PyObject], i32];

def _SPECIALIZE_LOAD_ATTR(
    counter: u16, owner: u64, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32;

def _LOAD_ATTR(
    owner: u64, self_or_null: ptr[u64], tstate: ptr, frame: ptr[u8], oparg: i32
) -> u64;

def _CHECK_MANAGED_OBJECT_HAS_VALUES(owner: u64) -> bool;

def _LOAD_ATTR_INSTANCE_VALUE(offset: u16, owner: u64, attr: ptr[u64]) -> i32;

def _LOAD_ATTR_MODULE(
    dict_version: u32, index: u16, owner: u64, attr: ptr[u64]
) -> i32;

def _LOAD_ATTR_WITH_HINT(
    hint: u16, owner: u64, frame: ptr[u8], oparg: i32, attr: ptr[u64]
) -> i32;

def _LOAD_ATTR_SLOT(index: u16, owner: u64, attr: ptr[u64]) -> i32;

def _CHECK_ATTR_CLASS(type_version: u32, owner: u64) -> bool;

def _LOAD_ATTR_CLASS(descr: u64) -> u64;

def _LOAD_ATTR_PROPERTY_FRAME(
    fget: u64, owner: u64, tstate: ptr, frame: ptr[u8], new_frame: ptr[u64]
) -> i32;

def LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN(
    type_version: u32,
    func_version: u32,
    getattribute: u64,
    owner: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    next_instr: ptr[u16]
) -> i32;

def _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT(owner: u64) -> bool;

def _GUARD_KEYS_VERSION(keys_version: u32, owner: u64) -> bool;

def _LOAD_ATTR_METHOD_WITH_VALUES(descr: u64, owner: u64, self_: ptr[u64]) -> u64;

def _LOAD_ATTR_METHOD_NO_DICT(descr: u64, owner: u64, self_: ptr[u64]) -> u64;

def _CHECK_ATTR_METHOD_LAZY_DICT(dictoffset: u16, owner: u64) -> bool;

def _LOAD_ATTR_METHOD_LAZY_DICT(descr: u64, owner: u64, self_: ptr[u64]) -> u64;

def _LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES(descr: u64) -> u64;

def _LOAD_ATTR_NONDESCRIPTOR_NO_DICT(descr: u64) -> u64;

def _SPECIALIZE_LOAD_SUPER_ATTR(
    counter: u16, global_super_st: u64, class_st: u64, oparg: i32, this_instr: ptr[u16]
) -> i32;

def _LOAD_SUPER_ATTR(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16]
) -> u64;

def _LOAD_SUPER_ATTR_INSTRUMENTED(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16]
) -> u64;

def attr_load_super_attr(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    instrumented: bool
) -> u64;

def LOAD_SUPER_ATTR_ATTR(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    frame: ptr[u8],
    oparg: i32,
    attr_st: ptr[u64]
) -> i32;

def LOAD_SUPER_ATTR_METHOD(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    frame: ptr[u8],
    oparg: i32,
    attr: ptr[u64],
    self_or_null: ptr[u64]
) -> i32;

def _INSERT_NULL(self_: u64, method_and_self: ptr[u64]);

def _LOAD_SPECIAL(method_and_self: ptr[u64], tstate: ptr, oparg: i32) -> i32;

def _SPECIALIZE_STORE_ATTR(
    counter: u16, owner: u64, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32;

def _STORE_ATTR(v: u64, owner: u64, frame: ptr[u8], oparg: i32) -> i32;

def DELETE_ATTR(owner: u64, frame: ptr[u8], oparg: i32) -> i32;

def _GUARD_TYPE_VERSION_AND_LOCK(type_version: u32, owner: u64) -> bool;

def _GUARD_DORV_NO_DICT(owner: u64) -> bool;

def _STORE_ATTR_INSTANCE_VALUE(offset: u16, value: u64, owner: u64);

def _STORE_ATTR_WITH_HINT(
    hint: u16, value: u64, owner: u64, frame: ptr[u8], oparg: i32
) -> i32;

def _STORE_ATTR_SLOT(index: u16, value: u64, owner: u64);

impl attr_name(frame: ptr[u8], index: i32) -> ptr[PyObject] {
    names = ptr[ptr[PyObject]](frame_code(frame) + PyCodeObject_NAMES).view(1)[0];
    return tuple_get_item(names, i64(index));
}

impl attr_advance_counter(this_instr: ptr[u16], counter: u16) {
    (this_instr + 1).view(1)[0] = u16.wrap(i64(counter) - ATTR_BACKOFF_STEP);
}

impl attr_inline_values(owner: ptr[PyObject]) -> ptr[u8] {
    tp = ptr[_object](owner).view(1)[0].ob_type;
    return ptr[u8](owner) + tp.view(1)[0].tp_basicsize;
}

impl attr_values_valid(owner: ptr[PyObject]) -> bool {
    return (attr_inline_values(owner) + ATTR_VALUES_VALID).view(1)[0] != u8(0);
}

impl attr_slot(owner: ptr[PyObject], offset: u16) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](owner) + i64(offset));
}

impl attr_dict_keys(dict: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](ptr[PyDictObject](dict).view(1)[0].ma_keys);
}

impl attr_keys_nentries(keys: ptr[u8]) -> i64 {
    return ptr[i64](keys + PyDictKeysObject_NENTRIES).view(1)[0];
}

impl attr_keys_kind(keys: ptr[u8]) -> u8 {
    return (keys + PyDictKeysObject_KIND).view(1)[0];
}

impl attr_keys_version(keys: ptr[u8]) -> u32 {
    return ptr[u32](keys + PyDictKeysObject_VERSION).view(1)[0];
}

impl attr_unicode_entry(keys: ptr[u8], index: i64) -> ptr[ptr[PyObject]] {
    log2 = i64((keys + PyDictKeysObject_LOG2_INDEX_BYTES).view(1)[0]);
    return ptr[ptr[PyObject]](
        keys
            + PyDictKeysObject_INDICES
            + (i64(1) << log2)
            + index * ATTR_UNICODE_ENTRY_SIZE
    );
}

impl attr_is_type(op: ptr[PyObject]) -> bool {
    tp = ptr[_object](op).view(1)[0].ob_type;
    return (tp.view(1)[0].tp_flags & Py_TPFLAGS_TYPE_SUBCLASS) != u64(0);
}

impl attr_code_i32(code: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](code + offset).view(1)[0];
}

impl attr_has_stack_space(tstate: ptr, size: i32) -> bool {
    top = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP).view(1)[0];
    if not top {
        return False;
    }
    limit = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_LIMIT).view(1)[0];
    return i64(size) < i64((int(limit) - int(top)) // 8);
}

impl attr_push_frame(
    tstate: ptr, func: u64, null_locals_from: i64, previous: ptr[u8]
) -> ptr[u8] {
    func_obj = sr_borrow(func);
    code = ptr[ptr[PyObject]](ptr[u8](func_obj) + PyFunctionObject_CODE).view(1)[0];
    top = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP);
    pushed = top.view(1)[0];
    size = i64(attr_code_i32(ptr[u8](code), PyCodeObject_FRAMESIZE));
    top.view(1)[0] = pushed + size * 8;
    frame_initialize(pushed, func, NULL, code, null_locals_from, previous);
    return pushed;
}

impl _SPECIALIZE_LOAD_ATTR(
    counter: u16, owner: u64, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32 {
    if counter < ATTR_UNREACHABLE_BACKOFF {
        _Py_Specialize_LoadAttr(owner, this_instr, attr_name(frame, oparg >> 1));
        return ST_REDISPATCH;
    }
    attr_advance_counter(this_instr, counter);
    return ST_OK;
}

impl _LOAD_ATTR(
    owner: u64, self_or_null: ptr[u64], tstate: ptr, frame: ptr[u8], oparg: i32
) -> u64 {
    name = attr_name(frame, oparg >> 1);
    if (oparg & 1) != 0 {
        attr = _Py_LoadAttr_StackRefSteal(
            ptr[PyThreadState](tstate), owner, name, self_or_null
        );
        if sr_is_null(attr) {
            return u64(0);
        }
        return attr;
    }
    attr_o = PyObject_GetAttr(sr_borrow(owner), name);
    sr_close(owner);
    if not attr_o {
        return u64(0);
    }
    return sr_steal(attr_o);
}

impl _CHECK_MANAGED_OBJECT_HAS_VALUES(owner: u64) -> bool {
    return attr_values_valid(sr_borrow(owner));
}

impl _LOAD_ATTR_INSTANCE_VALUE(offset: u16, owner: u64, attr: ptr[u64]) -> i32 {
    attr_o = attr_slot(sr_borrow(owner), offset).view(1)[0];
    if not attr_o {
        return ST_DEOPT;
    }
    attr.view(1)[0] = sr_new(attr_o);
    return ST_OK;
}

impl _LOAD_ATTR_MODULE(
    dict_version: u32, index: u16, owner: u64, attr: ptr[u64]
) -> i32 {
    owner_o = sr_borrow(owner);
    module_type = ptr[PyTypeObject](addressof(PyModule_Type));
    if int(sr_type(owner).view(1)[0].tp_getattro)
        != int(module_type.view(1)[0].tp_getattro) {
        return ST_DEOPT;
    }
    keys = attr_dict_keys(ptr[PyModuleObject](owner_o).view(1)[0].md_dict);
    if attr_keys_version(keys) != dict_version {
        return ST_DEOPT;
    }
    attr_o = attr_unicode_entry(keys, i64(index)).view(2)[1];
    if not attr_o {
        return ST_DEOPT;
    }
    attr.view(1)[0] = sr_new(attr_o);
    return ST_OK;
}

impl _LOAD_ATTR_WITH_HINT(
    hint: u16, owner: u64, frame: ptr[u8], oparg: i32, attr: ptr[u64]
) -> i32 {
    dict = managed_dict(sr_borrow(owner));
    if not dict {
        return ST_DEOPT;
    }
    keys = attr_dict_keys(dict);
    if i64(hint) >= attr_keys_nentries(keys) {
        return ST_DEOPT;
    }
    name = attr_name(frame, oparg >> 1);
    if attr_keys_kind(keys) != ATTR_DICT_KEYS_UNICODE {
        return ST_DEOPT;
    }
    slot_entry = attr_unicode_entry(keys, i64(hint));
    if slot_entry.view(2)[0] != name {
        return ST_DEOPT;
    }
    attr_o = slot_entry.view(2)[1];
    if not attr_o {
        return ST_DEOPT;
    }
    attr.view(1)[0] = sr_new(attr_o);
    return ST_OK;
}

impl _LOAD_ATTR_SLOT(index: u16, owner: u64, attr: ptr[u64]) -> i32 {
    attr_o = attr_slot(sr_borrow(owner), index).view(1)[0];
    if not attr_o {
        return ST_DEOPT;
    }
    attr.view(1)[0] = sr_new(attr_o);
    return ST_OK;
}

impl _CHECK_ATTR_CLASS(type_version: u32, owner: u64) -> bool {
    owner_o = sr_borrow(owner);
    if not attr_is_type(owner_o) {
        return False;
    }
    return ptr[PyTypeObject](owner_o).view(1)[0].tp_version_tag == type_version;
}

impl _LOAD_ATTR_CLASS(descr: u64) -> u64 {
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _LOAD_ATTR_PROPERTY_FRAME(
    fget: u64, owner: u64, tstate: ptr, frame: ptr[u8], new_frame: ptr[u64]
) -> i32 {
    func = ptr[PyObject](i64.wrap(fget));
    code = ptr[ptr[u8]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
    flags = attr_code_i32(code, PyCodeObject_FLAGS);
    if (flags & (CO_VARKEYWORDS | CO_VARARGS | CO_OPTIMIZED)) != CO_OPTIMIZED {
        return ST_DEOPT;
    }
    if attr_code_i32(code, PyCodeObject_KWONLYARGCOUNT) != 0 {
        return ST_DEOPT;
    }
    if attr_code_i32(code, PyCodeObject_ARGCOUNT) != 1 {
        return ST_DEOPT;
    }
    if not attr_has_stack_space(tstate, attr_code_i32(code, PyCodeObject_FRAMESIZE)) {
        return ST_DEOPT;
    }
    pushed = attr_push_frame(tstate, sr_new(func), 1, frame);
    ptr[u64](pushed + _PyInterpreterFrame_LOCALSPLUS).view(1)[0] = owner;
    new_frame.view(1)[0] = u64(int(pushed));
    return ST_OK;
}

impl LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN(
    type_version: u32,
    func_version: u32,
    getattribute: u64,
    owner: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    next_instr: ptr[u16]
) -> i32 {
    if ptr[ptr[u8]](tstate_interp(tstate) + PyInterpreterState_EVAL_FRAME).view(1)[0] {
        return ST_DEOPT;
    }
    if sr_type(owner).view(1)[0].tp_version_tag != type_version {
        return ST_DEOPT;
    }
    func = ptr[PyObject](i64.wrap(getattribute));
    if ptr[u32](ptr[u8](func) + PyFunctionObject_VERSION).view(1)[0] != func_version {
        return ST_DEOPT;
    }
    code = ptr[ptr[u8]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
    if not attr_has_stack_space(tstate, attr_code_i32(code, PyCodeObject_FRAMESIZE)) {
        return ST_DEOPT;
    }
    name = attr_name(frame, oparg >> 1);
    pushed = attr_push_frame(tstate, sr_new(func), 2, frame);
    locals = ptr[u64](pushed + _PyInterpreterFrame_LOCALSPLUS);
    locals.view(1)[0] = owner;
    (locals + 1).view(1)[0] = sr_new(name);
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16.wrap(
        (int(next_instr) - int(this_instr)) // 2
    );
    ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0] = pushed;
    return ST_INLINED;
}

impl _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT(owner: u64) -> bool {
    return attr_values_valid(sr_borrow(owner));
}

impl _GUARD_KEYS_VERSION(keys_version: u32, owner: u64) -> bool {
    heap_type = ptr[PyHeapTypeObject](sr_type(owner));
    keys = ptr[u8](heap_type.view(1)[0].ht_cached_keys);
    return attr_keys_version(keys) == keys_version;
}

impl _LOAD_ATTR_METHOD_WITH_VALUES(descr: u64, owner: u64, self_: ptr[u64]) -> u64 {
    self_.view(1)[0] = owner;
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _LOAD_ATTR_METHOD_NO_DICT(descr: u64, owner: u64, self_: ptr[u64]) -> u64 {
    self_.view(1)[0] = owner;
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _CHECK_ATTR_METHOD_LAZY_DICT(dictoffset: u16, owner: u64) -> bool {
    at = ptr[u8](sr_borrow(owner)) + ATTR_MANAGED_DICT_OFFSET + i64(dictoffset);
    if ptr[ptr[PyObject]](at).view(1)[0] {
        return False;
    }
    return True;
}

impl _LOAD_ATTR_METHOD_LAZY_DICT(descr: u64, owner: u64, self_: ptr[u64]) -> u64 {
    self_.view(1)[0] = owner;
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES(descr: u64) -> u64 {
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _LOAD_ATTR_NONDESCRIPTOR_NO_DICT(descr: u64) -> u64 {
    return sr_new(ptr[PyObject](i64.wrap(descr)));
}

impl _SPECIALIZE_LOAD_SUPER_ATTR(
    counter: u16, global_super_st: u64, class_st: u64, oparg: i32, this_instr: ptr[u16]
) -> i32 {
    if counter < ATTR_UNREACHABLE_BACKOFF {
        _Py_Specialize_LoadSuperAttr(global_super_st, class_st, this_instr, oparg & 1);
        return ST_REDISPATCH;
    }
    attr_advance_counter(this_instr, counter);
    return ST_OK;
}

impl _LOAD_SUPER_ATTR(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16]
) -> u64 {
    return attr_load_super_attr(
        global_super_st, class_st, self_st, tstate, frame, oparg, this_instr, False
    );
}

impl _LOAD_SUPER_ATTR_INSTRUMENTED(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16]
) -> u64 {
    return attr_load_super_attr(
        global_super_st, class_st, self_st, tstate, frame, oparg, this_instr, True
    );
}

impl attr_load_super_attr(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    instrumented: bool
) -> u64 {
    global_super = sr_borrow(global_super_st);
    class_ = sr_borrow(class_st);
    self_ = sr_borrow(self_st);
    ts = ptr[PyThreadState](tstate);
    arg: ptr[PyObject] = addressof(_PyInstrumentation_MISSING);
    if (oparg & 2) != 0 {
        arg = class_;
    }
    if instrumented {
        if _Py_call_instrumentation_2args(
            ts, ATTR_EVENT_CALL, frame, this_instr, global_super, arg
        )
            != 0 {
            return u64(0);
        }
    }
    slots: own AttrStack = AttrStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = class_;
    stack.view(2)[1] = self_;
    su = PyObject_Vectorcall(global_super, stack, u64(oparg & 2), NULL);
    if instrumented {
        if not su {
            _Py_call_instrumentation_exc2(
                ts, ATTR_EVENT_C_RAISE, frame, this_instr, global_super, arg
            );
        } elif _Py_call_instrumentation_2args(
            ts, ATTR_EVENT_C_RETURN, frame, this_instr, global_super, arg
        )
            < 0 {
            held = su;
            su = NULL;
            object_decref(held);
        }
    }
    if not su {
        return u64(0);
    }
    attr_o = PyObject_GetAttr(su, attr_name(frame, oparg >> 2));
    object_decref(su);
    if not attr_o {
        return u64(0);
    }
    return sr_steal(attr_o);
}

impl LOAD_SUPER_ATTR_ATTR(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    frame: ptr[u8],
    oparg: i32,
    attr_st: ptr[u64]
) -> i32 {
    global_super = sr_borrow(global_super_st);
    class_ = sr_borrow(class_st);
    if global_super != ptr[PyObject](addressof(PySuper_Type)) {
        return ST_DEOPT;
    }
    if not attr_is_type(class_) {
        return ST_DEOPT;
    }
    attr = _PySuper_Lookup(
        ptr[PyTypeObject](class_),
        sr_borrow(self_st),
        attr_name(frame, oparg >> 2),
        ptr[i32]()
    );
    if not attr {
        return ST_ERROR;
    }
    attr_st.view(1)[0] = sr_steal(attr);
    return ST_OK;
}

impl LOAD_SUPER_ATTR_METHOD(
    global_super_st: u64,
    class_st: u64,
    self_st: u64,
    frame: ptr[u8],
    oparg: i32,
    attr: ptr[u64],
    self_or_null: ptr[u64]
) -> i32 {
    global_super = sr_borrow(global_super_st);
    class_ = sr_borrow(class_st);
    self_ = sr_borrow(self_st);
    if global_super != ptr[PyObject](addressof(PySuper_Type)) {
        return ST_DEOPT;
    }
    if not attr_is_type(class_) {
        return ST_DEOPT;
    }
    self_type = sr_type(self_st);
    generic = int(self_type.view(1)[0].tp_getattro)
        == int(ptr(PyObject_GenericGetAttr));
    (attr_o, method_found) = attr_super_lookup_method(
        ptr[PyTypeObject](class_), self_, attr_name(frame, oparg >> 2), generic
    );
    if not attr_o {
        sr_close(self_st);
        return ST_ERROR;
    }
    if method_found != 0 {
        self_or_null.view(1)[0] = self_st;
    } else {
        sr_close(self_st);
        self_or_null.view(1)[0] = SR_NULL;
    }
    attr.view(1)[0] = sr_steal(attr_o);
    return ST_OK;
}

impl _INSERT_NULL(self_: u64, method_and_self: ptr[u64]) {
    (method_and_self + 1).view(1)[0] = self_;
    method_and_self.view(1)[0] = SR_NULL;
}

impl _LOAD_SPECIAL(method_and_self: ptr[u64], tstate: ptr, oparg: i32) -> i32 {
    slot_entry = ptr[ptr[u8]](addressof(_Py_SpecialMethods)) + i64(oparg) * 3;
    err = _PyObject_LookupSpecialMethod(
        ptr[PyObject](slot_entry.view(1)[0]), method_and_self
    );
    if err <= 0 {
        if err == 0 {
            owner = sr_borrow((method_and_self + 1).view(1)[0]);
            errfmt = slot_entry.view(3)[1];
            if _PyEval_SpecialMethodCanSuggest(owner, oparg) != 0 {
                errfmt = slot_entry.view(3)[2];
            }
            _PyErr_Format(ptr[PyThreadState](tstate), PyExc_TypeError, errfmt, owner);
        }
        return ST_ERROR;
    }
    return ST_OK;
}

impl _SPECIALIZE_STORE_ATTR(
    counter: u16, owner: u64, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32 {
    if counter < ATTR_UNREACHABLE_BACKOFF {
        _Py_Specialize_StoreAttr(owner, this_instr, attr_name(frame, oparg));
        return ST_REDISPATCH;
    }
    attr_advance_counter(this_instr, counter);
    return ST_OK;
}

impl _STORE_ATTR(v: u64, owner: u64, frame: ptr[u8], oparg: i32) -> i32 {
    err = PyObject_SetAttr(sr_borrow(owner), attr_name(frame, oparg), sr_borrow(v));
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl DELETE_ATTR(owner: u64, frame: ptr[u8], oparg: i32) -> i32 {
    err = PyObject_DelAttr(sr_borrow(owner), attr_name(frame, oparg));
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _GUARD_TYPE_VERSION_AND_LOCK(type_version: u32, owner: u64) -> bool {
    return sr_type(owner).view(1)[0].tp_version_tag == type_version;
}

impl _GUARD_DORV_NO_DICT(owner: u64) -> bool {
    owner_o = sr_borrow(owner);
    if managed_dict(owner_o) {
        return False;
    }
    return attr_values_valid(owner_o);
}

impl _STORE_ATTR_INSTANCE_VALUE(offset: u16, value: u64, owner: u64) {
    owner_o = sr_borrow(owner);
    value_ptr = attr_slot(owner_o, offset);
    old_value = value_ptr.view(1)[0];
    value_ptr.view(1)[0] = sr_as_steal(value);
    if not old_value {
        values = attr_inline_values(owner_o);
        index = i64((int(value_ptr) - int(values + PyDictValues_VALUES)) // 8);
        add_to_insertion_order(values, index);
    }
    sr_close(owner);
    object_xdecref(old_value);
}

impl _STORE_ATTR_WITH_HINT(
    hint: u16, value: u64, owner: u64, frame: ptr[u8], oparg: i32
) -> i32 {
    dict = managed_dict(sr_borrow(owner));
    if not dict {
        return ST_DEOPT;
    }
    name = attr_name(frame, oparg);
    keys = attr_dict_keys(dict);
    if i64(hint) >= attr_keys_nentries(keys)
        or attr_keys_kind(keys) == ATTR_DICT_KEYS_GENERAL {
        return ST_DEOPT;
    }
    slot_entry = attr_unicode_entry(keys, i64(hint));
    if slot_entry.view(2)[0] != name {
        return ST_DEOPT;
    }
    old_value = slot_entry.view(2)[1];
    if not old_value {
        return ST_DEOPT;
    }
    notify_event(ATTR_DICT_EVENT_MODIFIED, dict, name, sr_borrow(value));
    slot_entry.view(2)[1] = sr_as_steal(value);
    sr_close(owner);
    object_xdecref(old_value);
    return ST_OK;
}

impl _STORE_ATTR_SLOT(index: u16, value: u64, owner: u64) {
    addr = attr_slot(sr_borrow(owner), index);
    old_value = addr.view(1)[0];
    addr.view(1)[0] = sr_as_steal(value);
    sr_close(owner);
    object_xdecref(old_value);
}

impl attr_super_lookup_method(
    cls: ptr[PyTypeObject], self_: ptr[PyObject], name: ptr[PyObject], generic: bool
) -> tuple[ptr[PyObject], i32] {
    slots: own AttrStack = AttrStack();
    found = ptr[i32](jacpy_stack_address(&mut slots));
    found_at = ptr[i32]();
    if generic {
        found_at = found;
    }
    attr_o = _PySuper_Lookup(cls, self_, name, found_at);
    return (attr_o, found.view(1)[0]);
}
