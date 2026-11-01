import from c {
    glob PySuper_Type: PyTypeObject,
         PyMemberDescr_Type: PyTypeObject,
         PyProperty_Type: PyTypeObject,
         PyClassMethodDescr_Type: PyTypeObject,
         PyClassMethod_Type: PyTypeObject,
         PyBaseObject_Type: PyTypeObject,
         PyFunction_Type: PyTypeObject,
         PyModule_Type: PyTypeObject,
         PyType_Type: PyTypeObject,
         PyUnicode_Type: PyTypeObject,
         PyTuple_Type: PyTypeObject,
         PyList_Type: PyTypeObject,
         PyDict_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyFloat_Type: PyTypeObject,
         PyBool_Type: PyTypeObject,
         PySlice_Type: PyTypeObject,
         PySet_Type: PyTypeObject,
         PyFrozenSet_Type: PyTypeObject,
         PyMethodDescr_Type: PyTypeObject,
         PyMethod_Type: PyTypeObject,
         PyCFunction_Type: PyTypeObject,
         PyListIter_Type: PyTypeObject,
         PyTupleIter_Type: PyTypeObject,
         PyRangeIter_Type: PyTypeObject,
         PyGen_Type: PyTypeObject,
         PyCoro_Type: PyTypeObject,
         PyCode_Type: PyTypeObject,
         PyBytes_Type: PyTypeObject,
         _Py_NoneStruct: PyObject,
         _PyOpcode_Caches: u8,
         _PyOpcode_Deopt: u8; obj SpecializeStack {
        has s0: u64 = u64(0),
            s1: u64 = u64(0);
    }  obj _PyBinaryOpSpecializationDescr {
        has oparg: i32 = 0,
            guard: Callable[[ptr[PyObject], ptr[PyObject]], i32] = 0,
            action: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  obj _PyCode8 {
        has ob_base: PyVarObject,
            co_consts: ptr[PyObject],
            co_names: ptr[PyObject],
            co_exceptiontable: ptr[PyObject],
            co_flags: i32,
            co_argcount: i32,
            co_posonlyargcount: i32,
            co_kwonlyargcount: i32,
            co_stacksize: i32,
            co_firstlineno: i32,
            co_nlocalsplus: i32,
            co_framesize: i32,
            co_nlocals: i32,
            co_ncellvars: i32,
            co_nfreevars: i32,
            co_version: u32,
            co_localsplusnames: ptr[PyObject],
            co_localspluskinds: ptr[PyObject],
            co_filename: ptr[PyObject],
            co_name: ptr[PyObject],
            co_qualname: ptr[PyObject],
            co_linetable: ptr[PyBytesObject],
            co_weakreflist: ptr[PyObject],
            co_executors: ptr,
            _co_cached: ptr,
            _co_instrumentation_version: u64,
            _co_monitoring: ptr,
            _co_unique_id: i64,
            _co_firsttraceable: i32,
            co_extra: ptr,
            co_code_adaptive0: u16,
            co_code_adaptive1: u16,
            co_code_adaptive2: u16,
            co_code_adaptive3: u16;
    }  def jacpy_stack_address(slots: &mut SpecializeStack) -> int;  def _PyDict_LookupIndex(
        mp: ptr[PyObject], key: ptr[PyObject]
    ) -> i64;  def _PyDictKeys_StringLookup(k: ptr[u8], key: ptr[PyObject]) -> i64;  def _PyDictKeys_StringLookupSplit(
        k: ptr[u8], key: ptr[PyObject]
    ) -> i64;  def _PyDictKeys_StringLookupAndVersion(
        k: ptr[u8], key: ptr[PyObject], version: ptr[u32]
    ) -> i64;  def _PyDict_GetKeysVersionForCurrentState(
        interp: ptr, dict: ptr[PyObject]
    ) -> u32;  def _PyType_LookupRefAndVersion(
        type: ptr[PyTypeObject], name: ptr[PyObject], version: ptr[u32]
    ) -> ptr[PyObject];  def _PyType_Lookup(
        type: ptr[PyTypeObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyType_CacheInitForSpecialization(
        type: ptr[PyHeapTypeObject], init_fn: ptr[PyObject], tp_version: u32
    ) -> i32;  def _PyType_CacheGetItemForSpecialization(
        ht: ptr[PyHeapTypeObject], descriptor: ptr[PyObject], tp_version: u32
    ) -> i32;  def _PyType_Validate(
        ty: ptr[PyTypeObject], validate: ptr, tp_version: ptr[u32]
    ) -> i32;  def _PyFunction_GetVersionForCurrentState(func: ptr[PyObject]) -> u32;  def _Py_slot_tp_getattr_hook(
        self_: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_slot_tp_getattro(
        self_: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_type_getattro(
        tp: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_Vectorcall(
        func: ptr[PyObject],
        stack: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject];
}

glob:priv SIMPLE_FUNCTION: Final[i32] = 0,
     SPEC_FAIL_CODE_COMPLEX_PARAMETERS: Final[i32] = 7,
     SPEC_FAIL_CODE_NOT_OPTIMIZED: Final[i32] = 8,
     SPEC_FAIL_TO_BOOL_MAPPING: Final[i32] = 13,
     SPEC_FAIL_TO_BOOL_NUMBER: Final[i32] = 15,
     SPEC_FAIL_TO_BOOL_SEQUENCE: Final[i32] = 16,
     OVERRIDING: Final[i32] = 0,
     METHOD: Final[i32] = 1,
     PROPERTY: Final[i32] = 2,
     OBJECT_SLOT: Final[i32] = 3,
     OTHER_SLOT: Final[i32] = 4,
     NON_OVERRIDING: Final[i32] = 5,
     BUILTIN_CLASSMETHOD: Final[i32] = 6,
     PYTHON_CLASSMETHOD: Final[i32] = 7,
     NON_DESCRIPTOR: Final[i32] = 8,
     MUTABLE: Final[i32] = 9,
     ABSENT: Final[i32] = 10,
     DUNDER_CLASS: Final[i32] = 11,
     GETSET_OVERRIDDEN: Final[i32] = 12,
     GETATTRIBUTE_IS_PYTHON_FUNCTION: Final[i32] = 13,
     PYOBJECT_OB_TYPE: Final[i64] = 8,
     INT16_MAX: Final[i64] = 32767,
     UINT16_MAX: Final[i64] = 65535,
     SHRT_MAX: Final[i32] = 32767;

import from c {
    glob:priv no_location: PyBytesObject = PyBytesObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyBytes_Type)
                 ),
                 ob_size=1
             ),
             ob_sval=-5
         ); glob _Py_InitCleanup: _PyCode8 = _PyCode8(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyCode_Type)
                 ),
                 ob_size=3
             ),
             co_flags=CO_OPTIMIZED | CO_NO_MONITORING_EVENTS,
             co_linetable=addressof(no_location),
             _co_firsttraceable=4,
             co_stacksize=2,
             co_framesize=2 + FRAME_SPECIALS_SIZE,
             co_code_adaptive0=u16(EXIT_INIT_CHECK),
             co_code_adaptive1=u16(RETURN_VALUE),
             co_code_adaptive2=u16(RESUME | (RESUME_AT_FUNC_START << 8)),
             co_code_adaptive3=u16(0)
         );
}

def init_cleanup_ready;

def instr_opcode(instr: ptr[u16]) -> i32;

def instr_oparg(instr: ptr[u16]) -> i32;

def cache_at(instr: ptr[u16], offset: i64) -> ptr[u16];

def write_u32(p: ptr[u16], val: u32);

def write_ptr(p: ptr[u16], val: ptr);

def make_backoff_counter(value: i64, backoff: i64) -> u16;

def restart_backoff_counter(counter: u16) -> u16;

def adaptive_counter_warmup -> u16;

def adaptive_counter_cooldown -> u16;

def initial_jump_backoff_counter -> u16;

def initial_unreachable_backoff_counter -> u16;

def set_opcode(instr: ptr[u16], opcode: i32) -> i32;

def set_counter(counter: ptr[u16], value: u16);

def load_counter(counter: ptr[u16]) -> u16;

def specialize(instr: ptr[u16], specialized_opcode: i32);

def unspecialize(instr: ptr[u16]);

def same_type(a: ptr[PyObject], b: ptr[PyObject]) -> bool;

def is_type_object(op: ptr[PyObject]) -> bool;

def eval_frame_active -> bool;

def interp_callable(offset: i64) -> ptr[PyObject];

def func_code(func: ptr[PyObject]) -> ptr[PyObject];

def code_i32(code: ptr[PyObject], offset: i64) -> i32;

def as_long(op: ptr[PyObject]) -> ptr[PyLongObject];

def specialize_module_load_attr_lock_held(
    dict: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32;

def specialize_module_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32;

def classify_descriptor(descriptor: ptr[PyObject], has_getattr: bool) -> i32;

def descriptor_is_class(descriptor: ptr[PyObject], name: ptr[PyObject]) -> bool;

def analyze_descriptor_load(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32];

def analyze_descriptor_store(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32];

def specialize_dict_access_inline(
    owner: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    values_op: i32
) -> i32;

def specialize_dict_access_hint(
    dict: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    hint_op: i32
) -> i32;

def specialize_dict_access(
    owner: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    kind: i32,
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    values_op: i32,
    hint_op: i32
) -> i32;

def instance_has_key(obj_: ptr[PyObject], name: ptr[PyObject]) -> tuple[bool, u32];

def do_specialize_instance_load_attr(
    owner: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject],
    shadow: bool,
    shared_keys_version: u32,
    kind: i32,
    descr: ptr[PyObject],
    tp_version: u32
) -> i32;

def specialize_instance_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32;

def specialize_class_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32;

def specialize_attr_loadclassattr(
    owner: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject],
    descr: ptr[PyObject],
    tp_version: u32,
    kind: i32,
    is_method: bool,
    shared_keys_version: u32
) -> i32;

def specialize_load_global_lock_held(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject]
);

def function_kind(code: ptr[PyObject]) -> i32;

def function_check_args(o: ptr[PyObject], expected_argcount: i32, opcode: i32) -> bool;

def function_get_version(o: ptr[PyObject], opcode: i32) -> u32;

def get_init_for_simple_managed_python_class(
    tp: ptr[PyTypeObject]
) -> tuple[ptr[PyObject], u32];

def specialize_class_call(callable: ptr[PyObject], instr: ptr[u16], nargs: i32) -> i32;

def specialize_method_descriptor(
    descr: ptr[PyObject], instr: ptr[u16], nargs: i32
) -> i32;

def func_has_default_vectorcall(func: ptr[PyObject]) -> bool;

def specialize_py_call(
    func: ptr[PyObject], instr: ptr[u16], nargs: i32, bound_method: bool
) -> i32;

def specialize_py_call_kw(
    func: ptr[PyObject], instr: ptr[u16], nargs: i32, bound_method: bool
) -> i32;

def specialize_c_call(callable: ptr[PyObject], instr: ptr[u16], nargs: i32) -> i32;

def is_compactlong(v: ptr[PyObject]) -> bool;

def compactlongs_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32;

def compactlongs_or(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject];

def compactlongs_and(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject];

def compactlongs_xor(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject];

def float_is_nan(op: ptr[PyObject]) -> bool;

def float_compactlong_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32;

def nonzero_float_compactlong_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32;

def float_compactlong_add(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject];

def float_compactlong_subtract(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

def float_compactlong_multiply(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

def float_compactlong_true_div(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

def compactlong_float_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32;

def nonzero_compactlong_float_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32;

def compactlong_float_add(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject];

def compactlong_float_subtract(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

def compactlong_float_multiply(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

def compactlong_float_true_div(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv binaryop_extend_descrs: list[_PyBinaryOpSpecializationDescr] = [
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_OR, guard=compactlongs_guard, action=compactlongs_or
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_AND, guard=compactlongs_guard, action=compactlongs_and
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_XOR, guard=compactlongs_guard, action=compactlongs_xor
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_INPLACE_OR, guard=compactlongs_guard, action=compactlongs_or
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_INPLACE_AND, guard=compactlongs_guard, action=compactlongs_and
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_INPLACE_XOR, guard=compactlongs_guard, action=compactlongs_xor
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_ADD,
                 guard=float_compactlong_guard,
                 action=float_compactlong_add
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_SUBTRACT,
                 guard=float_compactlong_guard,
                 action=float_compactlong_subtract
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_TRUE_DIVIDE,
                 guard=nonzero_float_compactlong_guard,
                 action=float_compactlong_true_div
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_MULTIPLY,
                 guard=float_compactlong_guard,
                 action=float_compactlong_multiply
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_ADD,
                 guard=compactlong_float_guard,
                 action=compactlong_float_add
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_SUBTRACT,
                 guard=compactlong_float_guard,
                 action=compactlong_float_subtract
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_TRUE_DIVIDE,
                 guard=nonzero_compactlong_float_guard,
                 action=compactlong_float_true_div
             ),
             _PyBinaryOpSpecializationDescr(
                 oparg=NB_MULTIPLY,
                 guard=compactlong_float_guard,
                 action=compactlong_float_multiply
             )
         ];
}

glob:priv BINARYOP_EXTEND_DESCRS_COUNT: Final[i64] = 14;

def binary_op_extended_specialization(
    lhs: ptr[PyObject], rhs: ptr[PyObject], oparg: i32
) -> ptr[_PyBinaryOpSpecializationDescr];

def specialize_binary_op_typed(
    lhs: ptr[PyObject],
    rhs: ptr[PyObject],
    instr: ptr[u16],
    oparg: i32,
    locals: ptr[u64]
) -> bool;

def check_type_always_true(ty: ptr[PyTypeObject]) -> i32;

import from c {
    def _PyCode_Quicken(instructions: ptr[u16], size: i64, enable_counters: i32) {
        jump_counter: u16 = 0;
        adaptive_counter: u16 = 0;
        if enable_counters != 0 {
            jump_counter = initial_jump_backoff_counter();
            adaptive_counter = adaptive_counter_warmup();
        } else {
            jump_counter = initial_unreachable_backoff_counter();
            adaptive_counter = initial_unreachable_backoff_counter();
        }
        i: i64 = 0;
        while i < size - 1 {
            opcode = instr_opcode(instructions + i);
            caches = i64((addressof(_PyOpcode_Caches) + i64(opcode)).view(1)[0]);
            if caches != 0 {
                if opcode == JUMP_BACKWARD {
                    (instructions + (i + 1)).view(1)[0] = jump_counter;
                } elif opcode == POP_JUMP_IF_FALSE
                    or opcode == POP_JUMP_IF_TRUE
                    or opcode == POP_JUMP_IF_NONE
                    or opcode == POP_JUMP_IF_NOT_NONE {
                    (instructions + (i + 1)).view(1)[0] = u16(0x5555);
                } else {
                    (instructions + (i + 1)).view(1)[0] = adaptive_counter;
                }
                i += caches;
            }
            i += 1;
        }
    }  def _Py_Specialize_LoadSuperAttr(
        global_super_st: u64, cls_st: u64, instr: ptr[u16], load_method: i32
    ) {
        global_super = sr_borrow(global_super_st);
        cls = sr_borrow(cls_st);
        if global_super != ptr[PyObject](addressof(PySuper_Type)) {
            unspecialize(instr);
            return;
        }
        if not is_type_object(cls) {
            unspecialize(instr);
            return;
        }
        if load_method != 0 {
            specialize(instr, LOAD_SUPER_ATTR_METHOD);
        } else {
            specialize(instr, LOAD_SUPER_ATTR_ATTR);
        }
    }  def _Py_Specialize_LoadAttr(
        owner_st: u64, instr: ptr[u16], name: ptr[PyObject]
    ) {
        owner = sr_borrow(owner_st);
        type = object_type(owner);
        fail: i32 = 0;
        if not type_is_ready(type) {
            fail = 1;
        } elif int(type.view(1)[0].tp_getattro)
            == int(addressof(PyModule_Type).view(1)[0].tp_getattro) {
            fail = specialize_module_load_attr(owner, instr, name);
        } elif is_type_object(owner) {
            fail = specialize_class_load_attr(owner, instr, name);
        } else {
            fail = specialize_instance_load_attr(owner, instr, name);
        }
        if fail != 0 {
            unspecialize(instr);
        }
    }  def _Py_Specialize_StoreAttr(
        owner_st: u64, instr: ptr[u16], name: ptr[PyObject]
    ) {
        owner = sr_borrow(owner_st);
        type = object_type(owner);
        if not type_is_ready(type) {
            unspecialize(instr);
            return;
        }
        if object_is_type(owner, addressof(PyModule_Type)) {
            unspecialize(instr);
            return;
        }
        (kind, descr, tp_version) = analyze_descriptor_store(type, name);
        success = False;
        if tp_version != u32(0) {
            if kind == OBJECT_SLOT {
                dmem = ptr[ptr[PyMemberDef]](
                    ptr[u8](descr) + PyMemberDescrObject_MEMBER
                ).view(
                    1
                )[0];
                offset = dmem.view(1)[0].offset;
                d_type = ptr[PyDescrObject](descr).view(1)[0].d_type;
                if object_type_check(owner, d_type)
                    and (dmem.view(1)[0].flags & Py_READONLY) == 0
                    and offset >= 0
                    and offset <= UINT16_MAX {
                    cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(offset);
                    write_u32(cache_at(instr, _PyAttrCache_VERSION), tp_version);
                    specialize(instr, STORE_ATTR_SLOT);
                    success = True;
                }
            } elif kind == ABSENT {
                if specialize_dict_access(
                    owner,
                    instr,
                    type,
                    kind,
                    name,
                    tp_version,
                    STORE_ATTR,
                    STORE_ATTR_INSTANCE_VALUE,
                    STORE_ATTR_WITH_HINT
                )
                    != 0 {
                    success = True;
                }
            }
        }
        object_xdecref(descr);
        if not success {
            unspecialize(instr);
        }
    }  def _Py_Specialize_LoadGlobal(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        instr: ptr[u16],
        name: ptr[PyObject]
    ) {
        specialize_load_global_lock_held(globals, builtins, instr, name);
    }  def _Py_Specialize_StoreSubscr(container_st: u64, sub_st: u64, instr: ptr[u16]) {
        container = sr_borrow(container_st);
        sub = sr_borrow(sub_st);
        container_type = object_type(container);
        if container_type == addressof(PyList_Type) {
            if object_is_type(sub, addressof(PyLong_Type)) {
                if long_is_nonnegative_compact(as_long(sub))
                    and i64(as_long(sub).view(1)[0].long_value.ob_digit)
                        < object_size(container) {
                    specialize(instr, STORE_SUBSCR_LIST_INT);
                    return;
                }
                unspecialize(instr);
                return;
            }
            unspecialize(instr);
            return;
        }
        if container_type == addressof(PyDict_Type) {
            specialize(instr, STORE_SUBSCR_DICT);
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_Call(callable_st: u64, instr: ptr[u16], nargs: i32) {
        callable = sr_borrow(callable_st);
        fail: i32 = 0;
        if object_is_type(callable, addressof(PyCFunction_Type)) {
            fail = specialize_c_call(callable, instr, nargs);
        } elif object_is_type(callable, addressof(PyFunction_Type)) {
            fail = specialize_py_call(callable, instr, nargs, False);
        } elif is_type_object(callable) {
            fail = specialize_class_call(callable, instr, nargs);
        } elif object_is_type(callable, addressof(PyMethodDescr_Type)) {
            fail = specialize_method_descriptor(callable, instr, nargs);
        } elif object_is_type(callable, addressof(PyMethod_Type)) {
            func = ptr[PyMethodObject](callable).view(1)[0].im_func;
            if object_is_type(func, addressof(PyFunction_Type)) {
                fail = specialize_py_call(func, instr, nargs, True);
            } else {
                fail = -1;
            }
        } else {
            specialize(instr, CALL_NON_PY_GENERAL);
            fail = 0;
        }
        if fail != 0 {
            unspecialize(instr);
        }
    }  def _Py_Specialize_CallKw(callable_st: u64, instr: ptr[u16], nargs: i32) {
        callable = sr_borrow(callable_st);
        fail: i32 = 0;
        if object_is_type(callable, addressof(PyFunction_Type)) {
            fail = specialize_py_call_kw(callable, instr, nargs, False);
        } elif object_is_type(callable, addressof(PyMethod_Type)) {
            func = ptr[PyMethodObject](callable).view(1)[0].im_func;
            if object_is_type(func, addressof(PyFunction_Type)) {
                fail = specialize_py_call_kw(func, instr, nargs, True);
            } else {
                fail = -1;
            }
        } else {
            specialize(instr, CALL_KW_NON_PY);
            fail = 0;
        }
        if fail != 0 {
            unspecialize(instr);
        }
    }  def _Py_Specialize_BinaryOp(
        lhs_st: u64, rhs_st: u64, instr: ptr[u16], oparg: i32, locals: ptr[u64]
    ) {
        lhs = sr_borrow(lhs_st);
        rhs = sr_borrow(rhs_st);
        if instr_opcode(instr) == BINARY_OP_EXTEND {
            write_ptr(cache_at(instr, _PyBinaryOpCache_EXTERNAL_CACHE), ptr());
        }
        if specialize_binary_op_typed(lhs, rhs, instr, oparg, locals) {
            return;
        }
        descr = binary_op_extended_specialization(lhs, rhs, oparg);
        if descr {
            specialize(instr, BINARY_OP_EXTEND);
            write_ptr(cache_at(instr, _PyBinaryOpCache_EXTERNAL_CACHE), ptr(descr));
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_CompareOp(
        lhs_st: u64, rhs_st: u64, instr: ptr[u16], oparg: i32
    ) {
        lhs = sr_borrow(lhs_st);
        rhs = sr_borrow(rhs_st);
        if not same_type(lhs, rhs) {
            unspecialize(instr);
            return;
        }
        if object_is_type(lhs, addressof(PyFloat_Type)) {
            specialize(instr, COMPARE_OP_FLOAT);
            return;
        }
        if object_is_type(lhs, addressof(PyLong_Type)) {
            if long_is_compact(as_long(lhs)) and long_is_compact(as_long(rhs)) {
                specialize(instr, COMPARE_OP_INT);
                return;
            }
            unspecialize(instr);
            return;
        }
        if object_is_type(lhs, addressof(PyUnicode_Type)) {
            cmp = oparg >> 5;
            if cmp != Py_EQ and cmp != Py_NE {
                unspecialize(instr);
                return;
            }
            specialize(instr, COMPARE_OP_STR);
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_UnpackSequence(seq_st: u64, instr: ptr[u16], oparg: i32) {
        seq = sr_borrow(seq_st);
        if object_is_type(seq, addressof(PyTuple_Type)) {
            if object_size(seq) != i64(oparg) {
                unspecialize(instr);
                return;
            }
            if object_size(seq) == 2 {
                specialize(instr, UNPACK_SEQUENCE_TWO_TUPLE);
                return;
            }
            specialize(instr, UNPACK_SEQUENCE_TUPLE);
            return;
        }
        if object_is_type(seq, addressof(PyList_Type)) {
            if object_size(seq) != i64(oparg) {
                unspecialize(instr);
                return;
            }
            specialize(instr, UNPACK_SEQUENCE_LIST);
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_ForIter(iter_: u64, instr: ptr[u16], oparg: i32) {
        iter_o = sr_borrow(iter_);
        tp = object_type(iter_o);
        if tp == addressof(PyListIter_Type) {
            specialize(instr, FOR_ITER_LIST);
            return;
        } elif tp == addressof(PyTupleIter_Type) {
            specialize(instr, FOR_ITER_TUPLE);
            return;
        } elif tp == addressof(PyRangeIter_Type) {
            specialize(instr, FOR_ITER_RANGE);
            return;
        } elif tp == addressof(PyGen_Type) and oparg <= SHRT_MAX {
            if not eval_frame_active() {
                specialize(instr, FOR_ITER_GEN);
                return;
            }
        }
        unspecialize(instr);
    }  def _Py_Specialize_Send(receiver_st: u64, instr: ptr[u16]) {
        receiver = sr_borrow(receiver_st);
        tp = object_type(receiver);
        if tp == addressof(PyGen_Type) or tp == addressof(PyCoro_Type) {
            if eval_frame_active() {
                unspecialize(instr);
                return;
            }
            specialize(instr, SEND_GEN);
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_ToBool(value_o: u64, instr: ptr[u16]) {
        value = sr_borrow(value_o);
        tp = object_type(value);
        if tp == addressof(PyBool_Type) {
            specialize(instr, TO_BOOL_BOOL);
            return;
        }
        if tp == addressof(PyLong_Type) {
            specialize(instr, TO_BOOL_INT);
            return;
        }
        if tp == addressof(PyList_Type) {
            specialize(instr, TO_BOOL_LIST);
            return;
        }
        if value == addressof(_Py_NoneStruct) {
            specialize(instr, TO_BOOL_NONE);
            return;
        }
        if tp == addressof(PyUnicode_Type) {
            specialize(instr, TO_BOOL_STR);
            return;
        }
        if type_has_feature(tp, Py_TPFLAGS_HEAPTYPE) {
            slots: own SpecializeStack = SpecializeStack();
            version_out = ptr[u32](jacpy_stack_address(&mut slots));
            version_out.view(1)[0] = u32(0);
            err = _PyType_Validate(tp, ptr(check_type_always_true), version_out);
            if err != 0 {
                unspecialize(instr);
                return;
            }
            write_u32(cache_at(instr, _PyToBoolCache_VERSION), version_out.view(1)[0]);
            specialize(instr, TO_BOOL_ALWAYS_TRUE);
            return;
        }
        unspecialize(instr);
    }  def _Py_Specialize_ContainsOp(value_st: u64, instr: ptr[u16]) {
        value = sr_borrow(value_st);
        if object_is_type(value, addressof(PyDict_Type)) {
            specialize(instr, CONTAINS_OP_DICT);
            return;
        }
        if object_is_type(value, addressof(PySet_Type))
            or object_is_type(value, addressof(PyFrozenSet_Type)) {
            specialize(instr, CONTAINS_OP_SET);
            return;
        }
        unspecialize(instr);
    }
}

impl init_cleanup_ready {
    code = addressof(_Py_InitCleanup);
    if code.view(1)[0].co_consts {
        return;
    }
    runtime = ptr[u8](addressof(_PyRuntime));
    tuple_empty = ptr[PyObject](runtime + _PyRuntimeState_TUPLE_EMPTY);
    bytes_empty = ptr[PyObject](runtime + _PyRuntimeState_BYTES_EMPTY);
    init_name = py_id(_Py_ID___init__);
    code.view(1)[0].co_names = tuple_empty;
    code.view(1)[0].co_exceptiontable = bytes_empty;
    code.view(1)[0].co_localsplusnames = tuple_empty;
    code.view(1)[0].co_localspluskinds = bytes_empty;
    code.view(1)[0].co_filename = init_name;
    code.view(1)[0].co_name = init_name;
    code.view(1)[0].co_qualname = init_name;
    code.view(1)[0].co_consts = tuple_empty;
}

impl instr_opcode(instr: ptr[u16]) -> i32 {
    return i32(ptr[u8](instr).view(1)[0]);
}

impl instr_oparg(instr: ptr[u16]) -> i32 {
    return i32((ptr[u8](instr) + 1).view(1)[0]);
}

impl cache_at(instr: ptr[u16], offset: i64) -> ptr[u16] {
    return ptr[u16](ptr[u8](instr + 1) + offset);
}

impl write_u32(p: ptr[u16], val: u32) {
    p.view(2)[0] = u16.wrap(val);
    p.view(2)[1] = u16.wrap(val >> u32(16));
}

impl write_ptr(p: ptr[u16], val: ptr) {
    bits = u64.wrap(int(val));
    p.view(4)[0] = u16.wrap(bits);
    p.view(4)[1] = u16.wrap(bits >> u64(16));
    p.view(4)[2] = u16.wrap(bits >> u64(32));
    p.view(4)[3] = u16.wrap(bits >> u64(48));
}

impl make_backoff_counter(value: i64, backoff: i64) -> u16 {
    return u16((value << BACKOFF_BITS) | backoff);
}

impl restart_backoff_counter(counter: u16) -> u16 {
    backoff = i64(counter) & 15;
    if backoff < MAX_BACKOFF {
        return make_backoff_counter((1 << (backoff + 1)) - 1, backoff + 1);
    }
    return make_backoff_counter((1 << MAX_BACKOFF) - 1, MAX_BACKOFF);
}

impl adaptive_counter_warmup -> u16 {
    return make_backoff_counter(ADAPTIVE_WARMUP_VALUE, ADAPTIVE_WARMUP_BACKOFF);
}

impl adaptive_counter_cooldown -> u16 {
    return make_backoff_counter(ADAPTIVE_COOLDOWN_VALUE, ADAPTIVE_COOLDOWN_BACKOFF);
}

impl initial_jump_backoff_counter -> u16 {
    return make_backoff_counter(
        JUMP_BACKWARD_INITIAL_VALUE, JUMP_BACKWARD_INITIAL_BACKOFF
    );
}

impl initial_unreachable_backoff_counter -> u16 {
    return make_backoff_counter(0, UNREACHABLE_BACKOFF);
}

impl set_opcode(instr: ptr[u16], opcode: i32) -> i32 {
    ptr[u8](instr).view(1)[0] = u8(opcode);
    return 1;
}

impl set_counter(counter: ptr[u16], value: u16) {
    counter.view(1)[0] = value;
}

impl load_counter(counter: ptr[u16]) -> u16 {
    return counter.view(1)[0];
}

impl specialize(instr: ptr[u16], specialized_opcode: i32) {
    if set_opcode(instr, specialized_opcode) == 0 {
        return;
    }
    set_counter(instr + 1, adaptive_counter_cooldown());
}

impl unspecialize(instr: ptr[u16]) {
    opcode = instr_opcode(instr);
    generic_opcode = i32((addressof(_PyOpcode_Deopt) + i64(opcode)).view(1)[0]);
    if set_opcode(instr, generic_opcode) == 0 {
        return;
    }
    counter = instr + 1;
    cur = load_counter(counter);
    set_counter(counter, restart_backoff_counter(cur));
}

impl same_type(a: ptr[PyObject], b: ptr[PyObject]) -> bool {
    return object_type(a) == object_type(b);
}

impl is_type_object(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS);
}

impl eval_frame_active -> bool {
    return bool(
        ptr[ptr[u8]](current_interp() + PyInterpreterState_EVAL_FRAME).view(1)[0]
    );
}

impl interp_callable(offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](current_interp() + offset).view(1)[0];
}

impl func_code(func: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
}

impl code_i32(code: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](code) + offset).view(1)[0];
}

impl as_long(op: ptr[PyObject]) -> ptr[PyLongObject] {
    return ptr[PyLongObject](op);
}

impl specialize_module_load_attr_lock_held(
    dict: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32 {
    keys = ptr[u8](ptr[PyDictObject](dict).view(1)[0].ma_keys);
    if dk_kind(keys) != DICT_KEYS_UNICODE {
        return -1;
    }
    index = _PyDict_LookupIndex(dict, py_id(_Py_ID___getattr__));
    if index != DKIX_EMPTY {
        return -1;
    }
    index = _PyDict_LookupIndex(dict, name);
    if index < 0 or index > UINT16_MAX {
        return -1;
    }
    keys_version = _PyDict_GetKeysVersionForCurrentState(ptr(current_interp()), dict);
    if keys_version == u32(0) {
        return -1;
    }
    write_u32(cache_at(instr, _PyAttrCache_VERSION), keys_version);
    cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(index);
    specialize(instr, LOAD_ATTR_MODULE);
    return 0;
}

impl specialize_module_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32 {
    dict = ptr[PyModuleObject](owner).view(1)[0].md_dict;
    if not dict {
        return -1;
    }
    return specialize_module_load_attr_lock_held(dict, instr, name);
}

impl classify_descriptor(descriptor: ptr[PyObject], has_getattr: bool) -> i32 {
    if not descriptor {
        return ABSENT;
    }
    desc_cls = object_type(descriptor);
    if not type_has_feature(desc_cls, Py_TPFLAGS_IMMUTABLETYPE) {
        return MUTABLE;
    }
    if int(desc_cls.view(1)[0].tp_descr_set) != 0 {
        if desc_cls == addressof(PyMemberDescr_Type) {
            dmem = ptr[ptr[PyMemberDef]](
                ptr[u8](descriptor) + PyMemberDescrObject_MEMBER
            ).view(
                1
            )[0];
            member_type = dmem.view(1)[0].type_;
            if member_type == Py_T_OBJECT_EX or member_type == _Py_T_OBJECT {
                return OBJECT_SLOT;
            }
            return OTHER_SLOT;
        }
        if desc_cls == addressof(PyProperty_Type) {
            if has_getattr {
                return GETSET_OVERRIDDEN;
            }
            return PROPERTY;
        }
        return OVERRIDING;
    }
    if int(desc_cls.view(1)[0].tp_descr_get) != 0 {
        if type_has_feature(desc_cls, Py_TPFLAGS_METHOD_DESCRIPTOR) {
            return METHOD;
        }
        if object_is_type(descriptor, addressof(PyClassMethodDescr_Type)) {
            return BUILTIN_CLASSMETHOD;
        }
        if object_is_type(descriptor, addressof(PyClassMethod_Type)) {
            return PYTHON_CLASSMETHOD;
        }
        return NON_OVERRIDING;
    }
    return NON_DESCRIPTOR;
}

impl descriptor_is_class(descriptor: ptr[PyObject], name: ptr[PyObject]) -> bool {
    return PyUnicode_CompareWithASCIIString(name, ptr[u8]("__class__")) == 0
        and descriptor == _PyType_Lookup(addressof(PyBaseObject_Type), name);
}

impl analyze_descriptor_load(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32] {
    has_getattr = False;
    have_ga_version = False;
    ga_version: u32 = 0;
    slots: own SpecializeStack = SpecializeStack();
    version_out = ptr[u32](jacpy_stack_address(&mut slots));
    getattro_slot = int(type.view(1)[0].tp_getattro);
    if getattro_slot == int(ptr(PyObject_GenericGetAttr)) {
        has_getattr = False;
    } elif getattro_slot == int(ptr(_Py_slot_tp_getattr_hook))
        or getattro_slot == int(ptr(_Py_slot_tp_getattro)) {
        version_out.view(1)[0] = u32(0);
        getattribute = _PyType_LookupRefAndVersion(
            type, py_id(_Py_ID___getattribute__), version_out
        );
        ga_version = version_out.view(1)[0];
        have_ga_version = True;
        has_custom_getattribute = bool(getattribute)
            and getattribute
                != interp_callable(
                    PyInterpreterState_CALLABLE_CACHE_OBJECT_GETATTRIBUTE
                );
        getattr_fn = _PyType_Lookup(type, py_id(_Py_ID___getattr__));
        has_getattr = bool(getattr_fn);
        if has_custom_getattribute {
            if not has_getattr
                and object_is_type(getattribute, addressof(PyFunction_Type)) {
                return (GETATTRIBUTE_IS_PYTHON_FUNCTION, getattribute, ga_version);
            }
            object_decref(getattribute);
            return (GETSET_OVERRIDDEN, NULL, ga_version);
        }
        object_xdecref(getattribute);
    } else {
        return (GETSET_OVERRIDDEN, NULL, type.view(1)[0].tp_version_tag);
    }
    version_out.view(1)[0] = u32(0);
    descriptor = _PyType_LookupRefAndVersion(type, name, version_out);
    descr_version = version_out.view(1)[0];
    tp_version = ga_version if have_ga_version else descr_version;
    if descriptor_is_class(descriptor, name) {
        return (DUNDER_CLASS, descriptor, tp_version);
    }
    return (classify_descriptor(descriptor, has_getattr), descriptor, tp_version);
}

impl analyze_descriptor_store(
    type: ptr[PyTypeObject], name: ptr[PyObject]
) -> tuple[i32, ptr[PyObject], u32] {
    if int(type.view(1)[0].tp_setattro) != int(ptr(PyObject_GenericSetAttr)) {
        return (GETSET_OVERRIDDEN, NULL, u32(0));
    }
    slots: own SpecializeStack = SpecializeStack();
    version_out = ptr[u32](jacpy_stack_address(&mut slots));
    version_out.view(1)[0] = u32(0);
    descriptor = _PyType_LookupRefAndVersion(type, name, version_out);
    tp_version = version_out.view(1)[0];
    if descriptor_is_class(descriptor, name) {
        return (DUNDER_CLASS, descriptor, tp_version);
    }
    return (classify_descriptor(descriptor, False), descriptor, tp_version);
}

impl specialize_dict_access_inline(
    owner: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    values_op: i32
) -> i32 {
    keys = ptr[u8](ptr[PyHeapTypeObject](type).view(1)[0].ht_cached_keys);
    index = _PyDictKeys_StringLookupSplit(keys, name);
    if index == DKIX_EMPTY {
        return 0;
    }
    value_addr = inline_values(owner) + PyDictValues_VALUES + index * 8;
    offset = int(value_addr) - int(owner);
    if offset < 0 or offset > UINT16_MAX {
        return 0;
    }
    cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(offset);
    write_u32(cache_at(instr, _PyAttrCache_VERSION), tp_version);
    specialize(instr, values_op);
    return 1;
}

impl specialize_dict_access_hint(
    dict: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    hint_op: i32
) -> i32 {
    if has_split_table(dict) {
        return 0;
    }
    index = _PyDict_LookupIndex(dict, name);
    if index < 0 or index > UINT16_MAX {
        return 0;
    }
    cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(index);
    write_u32(cache_at(instr, _PyAttrCache_VERSION), tp_version);
    specialize(instr, hint_op);
    return 1;
}

impl specialize_dict_access(
    owner: ptr[PyObject],
    instr: ptr[u16],
    type: ptr[PyTypeObject],
    kind: i32,
    name: ptr[PyObject],
    tp_version: u32,
    base_op: i32,
    values_op: i32,
    hint_op: i32
) -> i32 {
    if not type_has_feature(type, Py_TPFLAGS_MANAGED_DICT) {
        return 0;
    }
    if type_has_feature(type, Py_TPFLAGS_INLINE_VALUES)
        and (inline_values(owner) + PyDictValues_VALID).view(1)[0] != u8(0)
        and not (base_op == STORE_ATTR and bool(managed_dict(owner))) {
        dict = managed_dict(owner);
        if not dict {
            return specialize_dict_access_inline(
                owner, instr, type, name, tp_version, base_op, values_op
            );
        }
        return 0;
    }
    dict = managed_dict(owner);
    if not dict or not object_is_type(dict, addressof(PyDict_Type)) {
        return 0;
    }
    return specialize_dict_access_hint(
        dict, instr, type, name, tp_version, base_op, hint_op
    );
}

impl instance_has_key(obj_: ptr[PyObject], name: ptr[PyObject]) -> tuple[bool, u32] {
    cls = object_type(obj_);
    if not type_has_feature(cls, Py_TPFLAGS_MANAGED_DICT) {
        return (False, u32(0));
    }
    if type_has_feature(cls, Py_TPFLAGS_INLINE_VALUES) {
        keys = ptr[u8](ptr[PyHeapTypeObject](cls).view(1)[0].ht_cached_keys);
        slots: own SpecializeStack = SpecializeStack();
        version_out = ptr[u32](jacpy_stack_address(&mut slots));
        index = _PyDictKeys_StringLookupAndVersion(keys, name, version_out);
        return (index >= 0, version_out.view(1)[0]);
    }
    dict = managed_dict(obj_);
    if not dict or not object_is_type(dict, addressof(PyDict_Type)) {
        return (False, u32(0));
    }
    if ptr[PyDictObject](dict).view(1)[0].ma_values {
        return (False, u32(0));
    }
    return (_PyDict_LookupIndex(dict, name) >= 0, u32(0));
}

impl do_specialize_instance_load_attr(
    owner: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject],
    shadow: bool,
    shared_keys_version: u32,
    kind: i32,
    descr: ptr[PyObject],
    tp_version: u32
) -> i32 {
    type = object_type(owner);
    if tp_version == u32(0) {
        return -1;
    }
    oparg = instr_oparg(instr);
    try_instance = False;
    if kind == OVERRIDING {
        return -1;
    } elif kind == METHOD {
        if shadow {
            try_instance = True;
        } elif (oparg & 1) != 0 {
            if specialize_attr_loadclassattr(
                owner, instr, name, descr, tp_version, kind, True, shared_keys_version
            )
                != 0 {
                return 0;
            }
            return -1;
        } else {
            return -1;
        }
    } elif kind == PROPERTY {
        fget = ptr[propertyobject](descr).view(1)[0].prop_get;
        if not fget {
            return -1;
        }
        if not object_is_type(fget, addressof(PyFunction_Type)) {
            return -1;
        }
        if not function_check_args(fget, 1, LOAD_ATTR) {
            return -1;
        }
        if (oparg & 1) != 0 {
            return -1;
        }
        if eval_frame_active() {
            return -1;
        }
        write_u32(cache_at(instr, _PyLoadMethodCache_TYPE_VERSION), tp_version);
        write_ptr(cache_at(instr, _PyLoadMethodCache_DESCR), ptr(fget));
        specialize(instr, LOAD_ATTR_PROPERTY);
        return 0;
    } elif kind == OBJECT_SLOT {
        dmem = ptr[ptr[PyMemberDef]](ptr[u8](descr) + PyMemberDescrObject_MEMBER).view(
            1
        )[0];
        offset = dmem.view(1)[0].offset;
        d_type = ptr[PyDescrObject](descr).view(1)[0].d_type;
        if not object_type_check(owner, d_type) {
            return -1;
        }
        if (dmem.view(1)[0].flags & Py_AUDIT_READ) != 0 {
            return -1;
        }
        if offset < 0 or offset > UINT16_MAX {
            return -1;
        }
        cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(offset);
        write_u32(cache_at(instr, _PyAttrCache_VERSION), tp_version);
        specialize(instr, LOAD_ATTR_SLOT);
        return 0;
    } elif kind == DUNDER_CLASS {
        cache_at(instr, _PyAttrCache_INDEX).view(1)[0] = u16(PYOBJECT_OB_TYPE);
        write_u32(cache_at(instr, _PyAttrCache_VERSION), tp_version);
        specialize(instr, LOAD_ATTR_SLOT);
        return 0;
    } elif kind == OTHER_SLOT or kind == MUTABLE or kind == GETSET_OVERRIDDEN {
        return -1;
    } elif kind == GETATTRIBUTE_IS_PYTHON_FUNCTION {
        if not function_check_args(descr, 2, LOAD_ATTR) {
            return -1;
        }
        if (oparg & 1) != 0 {
            return -1;
        }
        version = function_get_version(descr, LOAD_ATTR);
        if version == u32(0) {
            return -1;
        }
        if eval_frame_active() {
            return -1;
        }
        write_u32(cache_at(instr, _PyLoadMethodCache_KEYS_VERSION), version);
        write_ptr(cache_at(instr, _PyLoadMethodCache_DESCR), ptr(descr));
        write_u32(cache_at(instr, _PyLoadMethodCache_TYPE_VERSION), tp_version);
        specialize(instr, LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN);
        return 0;
    } elif kind == BUILTIN_CLASSMETHOD
        or kind == PYTHON_CLASSMETHOD
        or kind == NON_OVERRIDING {
        if shadow {
            try_instance = True;
        } else {
            return -1;
        }
    } elif kind == NON_DESCRIPTOR {
        if shadow {
            try_instance = True;
        } else {
            if (oparg & 1) == 0 {
                if specialize_attr_loadclassattr(
                    owner,
                    instr,
                    name,
                    descr,
                    tp_version,
                    kind,
                    False,
                    shared_keys_version
                )
                    != 0 {
                    return 0;
                }
            }
            return -1;
        }
    } elif kind == ABSENT {
        if shadow {
            try_instance = True;
        } else {
            set_counter(instr + 1, adaptive_counter_cooldown());
            return 0;
        }
    }
    if try_instance {
        if specialize_dict_access(
            owner,
            instr,
            type,
            kind,
            name,
            tp_version,
            LOAD_ATTR,
            LOAD_ATTR_INSTANCE_VALUE,
            LOAD_ATTR_WITH_HINT
        )
            != 0 {
            return 0;
        }
    }
    return -1;
}

impl specialize_instance_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32 {
    (shadow, shared_keys_version) = instance_has_key(owner, name);
    type = object_type(owner);
    (kind, descr, tp_version) = analyze_descriptor_load(type, name);
    result = do_specialize_instance_load_attr(
        owner, instr, name, shadow, shared_keys_version, kind, descr, tp_version
    );
    object_xdecref(descr);
    return result;
}

impl specialize_class_load_attr(
    owner: ptr[PyObject], instr: ptr[u16], name: ptr[PyObject]
) -> i32 {
    cls = ptr[PyTypeObject](owner);
    metatype = object_type(owner);
    if int(metatype.view(1)[0].tp_getattro) != int(ptr(_Py_type_getattro)) {
        return -1;
    }
    slots: own SpecializeStack = SpecializeStack();
    version_out = ptr[u32](jacpy_stack_address(&mut slots));
    version_out.view(1)[0] = u32(0);
    metadescriptor = _PyType_LookupRefAndVersion(metatype, name, version_out);
    meta_version = version_out.view(1)[0];
    metakind = classify_descriptor(metadescriptor, False);
    object_xdecref(metadescriptor);
    if metakind != METHOD
        and metakind != NON_DESCRIPTOR
        and metakind != NON_OVERRIDING
        and metakind != BUILTIN_CLASSMETHOD
        and metakind != PYTHON_CLASSMETHOD
        and metakind != ABSENT {
        return -1;
    }
    (kind, descr, tp_version) = analyze_descriptor_load(cls, name);
    if tp_version == u32(0) {
        object_xdecref(descr);
        return -1;
    }
    metaclass_check = False;
    if not type_has_feature(metatype, Py_TPFLAGS_IMMUTABLETYPE) {
        metaclass_check = True;
        if meta_version == u32(0) {
            object_xdecref(descr);
            return -1;
        }
    }
    if kind == METHOD or kind == NON_DESCRIPTOR {
        write_u32(cache_at(instr, _PyLoadMethodCache_TYPE_VERSION), tp_version);
        write_ptr(cache_at(instr, _PyLoadMethodCache_DESCR), ptr(descr));
        if metaclass_check {
            write_u32(cache_at(instr, _PyLoadMethodCache_KEYS_VERSION), meta_version);
            specialize(instr, LOAD_ATTR_CLASS_WITH_METACLASS_CHECK);
        } else {
            specialize(instr, LOAD_ATTR_CLASS);
        }
        object_xdecref(descr);
        return 0;
    }
    object_xdecref(descr);
    return -1;
}

impl specialize_attr_loadclassattr(
    owner: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject],
    descr: ptr[PyObject],
    tp_version: u32,
    kind: i32,
    is_method: bool,
    shared_keys_version: u32
) -> i32 {
    owner_cls = object_type(owner);
    tp_flags = owner_cls.view(1)[0].tp_flags;
    if (tp_flags & Py_TPFLAGS_INLINE_VALUES) != u64(0) {
        if shared_keys_version == u32(0) {
            return 0;
        }
        write_u32(
            cache_at(instr, _PyLoadMethodCache_KEYS_VERSION), shared_keys_version
        );
        if is_method {
            specialize(instr, LOAD_ATTR_METHOD_WITH_VALUES);
        } else {
            specialize(instr, LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES);
        }
    } else {
        dictoffset: i64 = 0;
        if (tp_flags & Py_TPFLAGS_MANAGED_DICT) != u64(0) {
            dictoffset = MANAGED_DICT_OFFSET;
        } else {
            dictoffset = owner_cls.view(1)[0].tp_dictoffset;
            if dictoffset < 0 or dictoffset > INT16_MAX + MANAGED_DICT_OFFSET {
                return 0;
            }
        }
        if dictoffset == 0 {
            if is_method {
                specialize(instr, LOAD_ATTR_METHOD_NO_DICT);
            } else {
                specialize(instr, LOAD_ATTR_NONDESCRIPTOR_NO_DICT);
            }
        } elif is_method {
            dict = ptr[ptr[PyObject]](ptr[u8](owner) + dictoffset).view(1)[0];
            if dict {
                return 0;
            }
            dictoffset = dictoffset - MANAGED_DICT_OFFSET;
            cache_at(instr, _PyLoadMethodCache_DICT_OFFSET).view(1)[0] = u16.wrap(
                dictoffset
            );
            specialize(instr, LOAD_ATTR_METHOD_LAZY_DICT);
        } else {
            return 0;
        }
    }
    write_u32(cache_at(instr, _PyLoadMethodCache_TYPE_VERSION), tp_version);
    write_ptr(cache_at(instr, _PyLoadMethodCache_DESCR), ptr(descr));
    return 1;
}

impl specialize_load_global_lock_held(
    globals: ptr[PyObject],
    builtins: ptr[PyObject],
    instr: ptr[u16],
    name: ptr[PyObject]
) {
    if not object_is_type(globals, addressof(PyDict_Type)) {
        unspecialize(instr);
        return;
    }
    globals_keys = ptr[u8](ptr[PyDictObject](globals).view(1)[0].ma_keys);
    if not dk_is_unicode(globals_keys) {
        unspecialize(instr);
        return;
    }
    index = _PyDictKeys_StringLookup(globals_keys, name);
    if index == DKIX_ERROR {
        unspecialize(instr);
        return;
    }
    interp = ptr(current_interp());
    if index != DKIX_EMPTY {
        if index < 0 or index > UINT16_MAX {
            unspecialize(instr);
            return;
        }
        keys_version = _PyDict_GetKeysVersionForCurrentState(interp, globals);
        if keys_version == u32(0) {
            unspecialize(instr);
            return;
        }
        if i64(keys_version) > UINT16_MAX {
            unspecialize(instr);
            return;
        }
        cache_at(instr, _PyLoadGlobalCache_INDEX).view(1)[0] = u16(index);
        cache_at(instr, _PyLoadGlobalCache_MODULE_KEYS_VERSION).view(1)[0] = u16(
            keys_version
        );
        specialize(instr, LOAD_GLOBAL_MODULE);
        return;
    }
    if not object_is_type(builtins, addressof(PyDict_Type)) {
        unspecialize(instr);
        return;
    }
    builtin_keys = ptr[u8](ptr[PyDictObject](builtins).view(1)[0].ma_keys);
    if not dk_is_unicode(builtin_keys) {
        unspecialize(instr);
        return;
    }
    index = _PyDictKeys_StringLookup(builtin_keys, name);
    if index == DKIX_ERROR {
        unspecialize(instr);
        return;
    }
    if index < 0 or index > UINT16_MAX {
        unspecialize(instr);
        return;
    }
    globals_version = _PyDict_GetKeysVersionForCurrentState(interp, globals);
    if globals_version == u32(0) {
        unspecialize(instr);
        return;
    }
    if i64(globals_version) > UINT16_MAX {
        unspecialize(instr);
        return;
    }
    builtins_version = _PyDict_GetKeysVersionForCurrentState(interp, builtins);
    if builtins_version == u32(0) {
        unspecialize(instr);
        return;
    }
    if i64(builtins_version) > UINT16_MAX {
        unspecialize(instr);
        return;
    }
    cache_at(instr, _PyLoadGlobalCache_INDEX).view(1)[0] = u16(index);
    cache_at(instr, _PyLoadGlobalCache_MODULE_KEYS_VERSION).view(1)[0] = u16(
        globals_version
    );
    cache_at(instr, _PyLoadGlobalCache_BUILTIN_KEYS_VERSION).view(1)[0] = u16(
        builtins_version
    );
    specialize(instr, LOAD_GLOBAL_BUILTIN);
}

impl function_kind(code: ptr[PyObject]) -> i32 {
    flags = code_i32(code, PyCodeObject_FLAGS);
    if (flags & (CO_VARKEYWORDS | CO_VARARGS)) != 0
        or code_i32(code, PyCodeObject_KWONLYARGCOUNT) != 0 {
        return SPEC_FAIL_CODE_COMPLEX_PARAMETERS;
    }
    if (flags & CO_OPTIMIZED) == 0 {
        return SPEC_FAIL_CODE_NOT_OPTIMIZED;
    }
    return SIMPLE_FUNCTION;
}

impl function_check_args(
    o: ptr[PyObject], expected_argcount: i32, opcode: i32
) -> bool {
    fcode = func_code(o);
    kind = function_kind(fcode);
    if kind != SIMPLE_FUNCTION {
        return False;
    }
    if code_i32(fcode, PyCodeObject_ARGCOUNT) != expected_argcount {
        return False;
    }
    return True;
}

impl function_get_version(o: ptr[PyObject], opcode: i32) -> u32 {
    version = _PyFunction_GetVersionForCurrentState(o);
    if version < FUNC_VERSION_FIRST_VALID {
        return u32(0);
    }
    return version;
}

impl get_init_for_simple_managed_python_class(
    tp: ptr[PyTypeObject]
) -> tuple[ptr[PyObject], u32] {
    if int(tp.view(1)[0].tp_alloc) != int(ptr(PyType_GenericAlloc)) {
        return (NULL, u32(0));
    }
    if (tp.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) == u64(0) {
        return (NULL, u32(0));
    }
    slots: own SpecializeStack = SpecializeStack();
    version_out = ptr[u32](jacpy_stack_address(&mut slots));
    version_out.view(1)[0] = u32(0);
    init_fn = _PyType_LookupRefAndVersion(tp, py_id(_Py_ID___init__), version_out);
    tp_version = version_out.view(1)[0];
    if not init_fn or not object_is_type(init_fn, addressof(PyFunction_Type)) {
        object_xdecref(init_fn);
        return (NULL, tp_version);
    }
    kind = function_kind(func_code(init_fn));
    if kind != SIMPLE_FUNCTION {
        object_decref(init_fn);
        return (NULL, tp_version);
    }
    return (init_fn, tp_version);
}

impl specialize_class_call(
    callable: ptr[PyObject], instr: ptr[u16], nargs: i32
) -> i32 {
    tp = ptr[PyTypeObject](callable);
    if type_has_feature(tp, Py_TPFLAGS_IMMUTABLETYPE) {
        oparg = instr_oparg(instr);
        if nargs == 1 and oparg == 1 {
            if tp == addressof(PyUnicode_Type) {
                specialize(instr, CALL_STR_1);
                return 0;
            } elif tp == addressof(PyType_Type) {
                specialize(instr, CALL_TYPE_1);
                return 0;
            } elif tp == addressof(PyTuple_Type) {
                specialize(instr, CALL_TUPLE_1);
                return 0;
            }
        }
        if int(tp.view(1)[0].tp_vectorcall) != 0 {
            specialize(instr, CALL_BUILTIN_CLASS);
            return 0;
        }
        specialize(instr, CALL_NON_PY_GENERAL);
        return 0;
    }
    if object_type(callable) != addressof(PyType_Type) {
        specialize(instr, CALL_NON_PY_GENERAL);
        return 0;
    }
    if int(tp.view(1)[0].tp_new)
        == int(addressof(PyBaseObject_Type).view(1)[0].tp_new) {
        (init_fn, tp_version) = get_init_for_simple_managed_python_class(tp);
        if tp_version == u32(0) {
            object_xdecref(init_fn);
            return -1;
        }
        if init_fn
            and _PyType_CacheInitForSpecialization(
                ptr[PyHeapTypeObject](tp), init_fn, tp_version
            )
                != 0 {
            write_u32(cache_at(instr, _PyCallCache_FUNC_VERSION), tp_version);
            init_cleanup_ready();
            specialize(instr, CALL_ALLOC_AND_ENTER_INIT);
            object_decref(init_fn);
            return 0;
        }
        object_xdecref(init_fn);
    }
    specialize(instr, CALL_NON_PY_GENERAL);
    return 0;
}

impl specialize_method_descriptor(
    descr: ptr[PyObject], instr: ptr[u16], nargs: i32
) -> i32 {
    method = ptr[ptr[PyMethodDef]](ptr[u8](descr) + PyMethodDescrObject_METHOD).view(1)[
        0
    ];
    flags = method.view(1)[0].ml_flags
        & (
            METH_VARARGS
            | METH_FASTCALL
            | METH_NOARGS
            | METH_O
            | METH_KEYWORDS
            | METH_METHOD
        );
    if flags == METH_NOARGS {
        if nargs != 1 {
            return -1;
        }
        specialize(instr, CALL_METHOD_DESCRIPTOR_NOARGS);
        return 0;
    } elif flags == METH_O {
        if nargs != 2 {
            return -1;
        }
        list_append = interp_callable(PyInterpreterState_CALLABLE_CACHE_LIST_APPEND);
        pop = instr_opcode(instr + (INLINE_CACHE_ENTRIES_CALL + 1)) == POP_TOP;
        oparg = instr_oparg(instr);
        if descr == list_append and oparg == 1 and pop {
            specialize(instr, CALL_LIST_APPEND);
            return 0;
        }
        specialize(instr, CALL_METHOD_DESCRIPTOR_O);
        return 0;
    } elif flags == METH_FASTCALL {
        specialize(instr, CALL_METHOD_DESCRIPTOR_FAST);
        return 0;
    } elif flags == (METH_FASTCALL | METH_KEYWORDS) {
        specialize(instr, CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS);
        return 0;
    }
    specialize(instr, CALL_NON_PY_GENERAL);
    return 0;
}

impl func_has_default_vectorcall(func: ptr[PyObject]) -> bool {
    vectorcall = ptr[ptr[u8]](ptr[u8](func) + PyFunctionObject_VECTORCALL).view(1)[0];
    return int(vectorcall) == int(ptr(_PyFunction_Vectorcall));
}

impl specialize_py_call(
    func: ptr[PyObject], instr: ptr[u16], nargs: i32, bound_method: bool
) -> i32 {
    code = func_code(func);
    kind = function_kind(code);
    if eval_frame_active() {
        return -1;
    }
    if not func_has_default_vectorcall(func) {
        return -1;
    }
    argcount: i32 = -1;
    if kind == SPEC_FAIL_CODE_NOT_OPTIMIZED {
        return -1;
    }
    if kind == SIMPLE_FUNCTION {
        argcount = code_i32(code, PyCodeObject_ARGCOUNT);
    }
    version = _PyFunction_GetVersionForCurrentState(func);
    if version < FUNC_VERSION_FIRST_VALID {
        return -1;
    }
    write_u32(cache_at(instr, _PyCallCache_FUNC_VERSION), version);
    bound: i32 = i32(1) if bound_method else i32(0);
    if argcount == nargs + bound {
        if bound_method {
            specialize(instr, CALL_BOUND_METHOD_EXACT_ARGS);
        } else {
            specialize(instr, CALL_PY_EXACT_ARGS);
        }
    } elif bound_method {
        specialize(instr, CALL_BOUND_METHOD_GENERAL);
    } else {
        specialize(instr, CALL_PY_GENERAL);
    }
    return 0;
}

impl specialize_py_call_kw(
    func: ptr[PyObject], instr: ptr[u16], nargs: i32, bound_method: bool
) -> i32 {
    code = func_code(func);
    kind = function_kind(code);
    if eval_frame_active() {
        return -1;
    }
    if not func_has_default_vectorcall(func) {
        return -1;
    }
    if kind == SPEC_FAIL_CODE_NOT_OPTIMIZED {
        return -1;
    }
    version = _PyFunction_GetVersionForCurrentState(func);
    if version < FUNC_VERSION_FIRST_VALID {
        return -1;
    }
    write_u32(cache_at(instr, _PyCallCache_FUNC_VERSION), version);
    if bound_method {
        specialize(instr, CALL_KW_BOUND_METHOD);
    } else {
        specialize(instr, CALL_KW_PY);
    }
    return 0;
}

impl specialize_c_call(callable: ptr[PyObject], instr: ptr[u16], nargs: i32) -> i32 {
    ml = ptr[PyCFunctionObject](callable).view(1)[0].m_ml;
    if int(ml.view(1)[0].ml_meth) == 0 {
        return 1;
    }
    flags = ml.view(1)[0].ml_flags
        & (
            METH_VARARGS
            | METH_FASTCALL
            | METH_NOARGS
            | METH_O
            | METH_KEYWORDS
            | METH_METHOD
        );
    if flags == METH_O {
        if nargs != 1 {
            return 1;
        }
        if callable == interp_callable(PyInterpreterState_CALLABLE_CACHE_LEN)
            and instr_oparg(instr) == 1 {
            specialize(instr, CALL_LEN);
            return 0;
        }
        specialize(instr, CALL_BUILTIN_O);
        return 0;
    } elif flags == METH_FASTCALL {
        if nargs == 2 {
            if callable
                == interp_callable(PyInterpreterState_CALLABLE_CACHE_ISINSTANCE) {
                specialize(instr, CALL_ISINSTANCE);
                return 0;
            }
        }
        specialize(instr, CALL_BUILTIN_FAST);
        return 0;
    } elif flags == (METH_FASTCALL | METH_KEYWORDS) {
        specialize(instr, CALL_BUILTIN_FAST_WITH_KEYWORDS);
        return 0;
    }
    specialize(instr, CALL_NON_PY_GENERAL);
    return 0;
}

impl is_compactlong(v: ptr[PyObject]) -> bool {
    return object_is_type(v, addressof(PyLong_Type)) and long_is_compact(as_long(v));
}

impl compactlongs_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32 {
    return i32(1) if is_compactlong(lhs) and is_compactlong(rhs) else i32(0);
}

impl compactlongs_or(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject] {
    rhs_val = compact_value(as_long(rhs));
    lhs_val = compact_value(as_long(lhs));
    return PyLong_FromSsize_t(lhs_val | rhs_val);
}

impl compactlongs_and(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject] {
    rhs_val = compact_value(as_long(rhs));
    lhs_val = compact_value(as_long(lhs));
    return PyLong_FromSsize_t(lhs_val & rhs_val);
}

impl compactlongs_xor(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject] {
    rhs_val = compact_value(as_long(rhs));
    lhs_val = compact_value(as_long(lhs));
    return PyLong_FromSsize_t(lhs_val ^ rhs_val);
}

impl float_is_nan(op: ptr[PyObject]) -> bool {
    value = PyFloat_AsDouble(op);
    return value != value;
}

impl float_compactlong_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32 {
    ok = object_is_type(lhs, addressof(PyFloat_Type))
        and not float_is_nan(lhs)
        and object_is_type(rhs, addressof(PyLong_Type))
        and long_is_compact(as_long(rhs));
    return i32(1) if ok else i32(0);
}

impl nonzero_float_compactlong_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32 {
    ok = float_compactlong_guard(lhs, rhs) != 0 and not long_is_zero(as_long(rhs));
    return i32(1) if ok else i32(0);
}

impl float_compactlong_add(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject] {
    lhs_val = PyFloat_AsDouble(lhs);
    rhs_val = compact_value(as_long(rhs));
    return PyFloat_FromDouble(lhs_val + f64(rhs_val));
}

impl float_compactlong_subtract(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    lhs_val = PyFloat_AsDouble(lhs);
    rhs_val = compact_value(as_long(rhs));
    return PyFloat_FromDouble(lhs_val - f64(rhs_val));
}

impl float_compactlong_multiply(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    lhs_val = PyFloat_AsDouble(lhs);
    rhs_val = compact_value(as_long(rhs));
    return PyFloat_FromDouble(lhs_val * f64(rhs_val));
}

impl float_compactlong_true_div(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    lhs_val = PyFloat_AsDouble(lhs);
    rhs_val = compact_value(as_long(rhs));
    return PyFloat_FromDouble(lhs_val / f64(rhs_val));
}

impl compactlong_float_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32 {
    ok = object_is_type(lhs, addressof(PyLong_Type))
        and long_is_compact(as_long(lhs))
        and object_is_type(rhs, addressof(PyFloat_Type))
        and not float_is_nan(rhs);
    return i32(1) if ok else i32(0);
}

impl nonzero_compactlong_float_guard(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> i32 {
    ok = compactlong_float_guard(lhs, rhs) != 0 and PyFloat_AsDouble(rhs) != 0.0;
    return i32(1) if ok else i32(0);
}

impl compactlong_float_add(lhs: ptr[PyObject], rhs: ptr[PyObject]) -> ptr[PyObject] {
    rhs_val = PyFloat_AsDouble(rhs);
    lhs_val = compact_value(as_long(lhs));
    return PyFloat_FromDouble(f64(lhs_val) + rhs_val);
}

impl compactlong_float_subtract(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    rhs_val = PyFloat_AsDouble(rhs);
    lhs_val = compact_value(as_long(lhs));
    return PyFloat_FromDouble(f64(lhs_val) - rhs_val);
}

impl compactlong_float_multiply(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    rhs_val = PyFloat_AsDouble(rhs);
    lhs_val = compact_value(as_long(lhs));
    return PyFloat_FromDouble(f64(lhs_val) * rhs_val);
}

impl compactlong_float_true_div(
    lhs: ptr[PyObject], rhs: ptr[PyObject]
) -> ptr[PyObject] {
    rhs_val = PyFloat_AsDouble(rhs);
    lhs_val = compact_value(as_long(lhs));
    return PyFloat_FromDouble(f64(lhs_val) / rhs_val);
}

impl binary_op_extended_specialization(
    lhs: ptr[PyObject], rhs: ptr[PyObject], oparg: i32
) -> ptr[_PyBinaryOpSpecializationDescr] {
    table = ptr[_PyBinaryOpSpecializationDescr](addressof(binaryop_extend_descrs));
    i: i64 = 0;
    while i < BINARYOP_EXTEND_DESCRS_COUNT {
        d = table + i;
        if d.view(1)[0].oparg == oparg and d.view(1)[0].guard(lhs, rhs) != 0 {
            return d;
        }
        i += 1;
    }
    return ptr[_PyBinaryOpSpecializationDescr]();
}

impl specialize_binary_op_typed(
    lhs: ptr[PyObject],
    rhs: ptr[PyObject],
    instr: ptr[u16],
    oparg: i32,
    locals: ptr[u64]
) -> bool {
    if oparg == NB_ADD or oparg == NB_INPLACE_ADD {
        if not same_type(lhs, rhs) {
            return False;
        }
        if object_is_type(lhs, addressof(PyUnicode_Type)) {
            next_unit = instr + (INLINE_CACHE_ENTRIES_BINARY_OP + 1);
            to_store = instr_opcode(next_unit) == STORE_FAST;
            if to_store
                and sr_borrow((locals + i64(instr_oparg(next_unit))).view(1)[0])
                    == lhs {
                specialize(instr, BINARY_OP_INPLACE_ADD_UNICODE);
                return True;
            }
            specialize(instr, BINARY_OP_ADD_UNICODE);
            return True;
        }
        if object_is_type(lhs, addressof(PyLong_Type)) {
            specialize(instr, BINARY_OP_ADD_INT);
            return True;
        }
        if object_is_type(lhs, addressof(PyFloat_Type)) {
            specialize(instr, BINARY_OP_ADD_FLOAT);
            return True;
        }
        return False;
    }
    if oparg == NB_MULTIPLY or oparg == NB_INPLACE_MULTIPLY {
        if not same_type(lhs, rhs) {
            return False;
        }
        if object_is_type(lhs, addressof(PyLong_Type)) {
            specialize(instr, BINARY_OP_MULTIPLY_INT);
            return True;
        }
        if object_is_type(lhs, addressof(PyFloat_Type)) {
            specialize(instr, BINARY_OP_MULTIPLY_FLOAT);
            return True;
        }
        return False;
    }
    if oparg == NB_SUBTRACT or oparg == NB_INPLACE_SUBTRACT {
        if not same_type(lhs, rhs) {
            return False;
        }
        if object_is_type(lhs, addressof(PyLong_Type)) {
            specialize(instr, BINARY_OP_SUBTRACT_INT);
            return True;
        }
        if object_is_type(lhs, addressof(PyFloat_Type)) {
            specialize(instr, BINARY_OP_SUBTRACT_FLOAT);
            return True;
        }
        return False;
    }
    if oparg == NB_SUBSCR {
        if object_is_type(rhs, addressof(PyLong_Type))
            and long_is_nonnegative_compact(as_long(rhs)) {
            if object_is_type(lhs, addressof(PyList_Type)) {
                specialize(instr, BINARY_OP_SUBSCR_LIST_INT);
                return True;
            }
            if object_is_type(lhs, addressof(PyTuple_Type)) {
                specialize(instr, BINARY_OP_SUBSCR_TUPLE_INT);
                return True;
            }
            if object_is_type(lhs, addressof(PyUnicode_Type)) {
                specialize(instr, BINARY_OP_SUBSCR_STR_INT);
                return True;
            }
        }
        if object_is_type(lhs, addressof(PyDict_Type)) {
            specialize(instr, BINARY_OP_SUBSCR_DICT);
            return True;
        }
        if object_is_type(lhs, addressof(PyList_Type))
            and object_is_type(rhs, addressof(PySlice_Type)) {
            specialize(instr, BINARY_OP_SUBSCR_LIST_SLICE);
            return True;
        }
        container_type = object_type(lhs);
        slots: own SpecializeStack = SpecializeStack();
        version_out = ptr[u32](jacpy_stack_address(&mut slots));
        descriptor = _PyType_LookupRefAndVersion(
            container_type, py_id(_Py_ID___getitem__), version_out
        );
        tp_version = version_out.view(1)[0];
        if descriptor
            and object_is_type(descriptor, addressof(PyFunction_Type))
            and type_has_feature(container_type, Py_TPFLAGS_HEAPTYPE) {
            fcode = func_code(descriptor);
            kind = function_kind(fcode);
            if kind == SIMPLE_FUNCTION
                and code_i32(fcode, PyCodeObject_ARGCOUNT) == 2
                and not eval_frame_active()
                and _PyType_CacheGetItemForSpecialization(
                    ptr[PyHeapTypeObject](container_type), descriptor, tp_version
                )
                    != 0 {
                specialize(instr, BINARY_OP_SUBSCR_GETITEM);
                object_decref(descriptor);
                return True;
            }
        }
        object_xdecref(descriptor);
        return False;
    }
    return False;
}

impl check_type_always_true(ty: ptr[PyTypeObject]) -> i32 {
    nb = ty.view(1)[0].tp_as_number;
    if nb and int(nb.view(1)[0].nb_bool) != 0 {
        return SPEC_FAIL_TO_BOOL_NUMBER;
    }
    mp = ty.view(1)[0].tp_as_mapping;
    if mp and int(mp.view(1)[0].mp_length) != 0 {
        return SPEC_FAIL_TO_BOOL_MAPPING;
    }
    sq = ty.view(1)[0].tp_as_sequence;
    if sq and int(sq.view(1)[0].sq_length) != 0 {
        return SPEC_FAIL_TO_BOOL_SEQUENCE;
    }
    return 0;
}
