import from c {
    obj PyDecObject {
        has ob_base: _object,
            hash: i64,
            dec: mpd_t,
            data_0: u64,
            data_1: u64,
            data_2: u64,
            data_3: u64;
    }  obj PyDecSignalDictObject {
        has ob_base: _object,
            flags: ptr[u32];
    }  obj PyDecContextObject {
        has ob_base: _object,
            ctx: mpd_context_t,
            traps: ptr[PyObject],
            flags: ptr[PyObject],
            capitals: i32,
            tstate: ptr,
            modstate: ptr[PyObject];
    }  obj PyDecContextManagerObject {
        has ob_base: _object,
            inner: ptr[PyObject],
            outer: ptr[PyObject];
    }  glob dec_spec: PyType_Spec,
         context_spec: PyType_Spec; obj BuiltinMethods {
        has float_as_integer_ratio:
            Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            long_bit_length:
                Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  glob builtin_methods: BuiltinMethods = BuiltinMethods(),
         max_context: mpd_context_t = mpd_context_t(),
         hash_context: mpd_context_t = mpd_context_t(); glob PyType_Type:
             PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyFloat_Type: PyTypeObject,
         PyComplex_Type: PyTypeObject;
}

glob DEC_MPD_OFFSET: Final[int] = 24,
     DEC_DATA_OFFSET: Final[int] = 72,
     CONTEXT_CTX_OFFSET: Final[int] = 16,
     CONTEXT_TRAPS_OFFSET: Final[int] = 40,
     CONTEXT_STATUS_OFFSET: Final[int] = 44,
     DEC_OBJECT_SIZE: Final[int] = 104,
     SIGNAL_DICT_OBJECT_SIZE: Final[int] = 24,
     CONTEXT_OBJECT_SIZE: Final[int] = 104,
     CONTEXT_MANAGER_OBJECT_SIZE: Final[int] = 32,
     PY_DEC_MINALLOC: Final[int] = 4,
     PY_DEC_ROUND_GUARD: Final[int] = 8;

glob STATE_CONTEXT_MANAGER_TYPE: Final[int] = 0,
     STATE_CONTEXT_TYPE: Final[int] = 1,
     STATE_SIGNAL_DICT_MIXIN_TYPE: Final[int] = 2,
     STATE_DEC_TYPE: Final[int] = 3,
     STATE_SIGNAL_DICT_TYPE: Final[int] = 4,
     STATE_DECIMAL_TUPLE: Final[int] = 5,
     STATE_DECIMAL_EXCEPTION: Final[int] = 6,
     STATE_CURRENT_CONTEXT_VAR: Final[int] = 7,
     STATE_DEFAULT_CONTEXT_TEMPLATE: Final[int] = 8,
     STATE_BASIC_CONTEXT_TEMPLATE: Final[int] = 9,
     STATE_EXTENDED_CONTEXT_TEMPLATE: Final[int] = 10,
     STATE_ROUND_MAP: Final[int] = 11,
     STATE_RATIONAL: Final[int] = 19,
     STATE_PYDECIMAL: Final[int] = 20,
     STATE_SIGNAL_TUPLE: Final[int] = 21,
     STATE_SIGNAL_EXCEPTIONS: Final[int] = 22,
     STATE_CONDITION_EXCEPTIONS: Final[int] = 31,
     STATE_COUNT: Final[int] = 35;

glob Py_LT_OP: Final[int] = 0,
     Py_LE_OP: Final[int] = 1,
     Py_EQ_OP: Final[int] = 2,
     Py_NE_OP: Final[int] = 3,
     Py_GT_OP: Final[int] = 4,
     Py_GE_OP: Final[int] = 5;

glob DEC_INVALID_SIGNALS: Final[u32] = 0x8000,
     DEC_ERR_OCCURRED: Final[u32] = 0x10000,
     DEC_ERRORS: Final[u32] = 0x18000,
     MPD_Float_operation: Final[u32] = 0x00000400;

glob SIGNAL_NAMES: list[str] = [
         "InvalidOperation",
         "FloatOperation",
         "DivisionByZero",
         "Overflow",
         "Underflow",
         "Subnormal",
         "Inexact",
         "Rounded",
         "Clamped"
     ],
     SIGNAL_FLAGS: list[u32] = [
         MPD_IEEE_Invalid_operation,
         MPD_Not_implemented,
         MPD_Division_by_zero,
         MPD_Overflow,
         MPD_Underflow,
         MPD_Subnormal,
         MPD_Inexact,
         MPD_Rounded,
         MPD_Clamped
     ],
     CONDITION_NAMES: list[str] = [
         "InvalidOperation",
         "ConversionSyntax",
         "DivisionImpossible",
         "DivisionUndefined",
         "InvalidContext"
     ],
     CONDITION_FLAGS: list[u32] = [
         MPD_Invalid_operation,
         MPD_Conversion_syntax,
         MPD_Division_impossible,
         MPD_Division_undefined,
         MPD_Invalid_context
     ],
     SIGNAL_MAP_LEN: Final[int] = 9,
     SUBNORMAL: Final[int] = 5,
     INEXACT: Final[int] = 6,
     ROUNDED: Final[int] = 7;

glob INVALID_ROUNDING_ERR: str = "valid values for rounding are:\n  [ROUND_CEILING, ROUND_FLOOR, ROUND_UP, ROUND_DOWN,\n   ROUND_HALF_UP, ROUND_HALF_DOWN, ROUND_HALF_EVEN,\n   ROUND_05UP]",
     INVALID_SIGNALS_ERR: str = "valid values for signals are:\n  [InvalidOperation, FloatOperation, DivisionByZero,\n   Overflow, Underflow, Subnormal, Inexact, Rounded,\n   Clamped]",
     INVALID_SIGNALDICT_ERROR_MSG: str = "invalid signal dict";

obj ModuleToken {
    has handle: ptr = ptr();
}

glob decimal_module_token: ModuleToken = ModuleToken();

def mpd(v: ptr[PyObject]) -> ptr[mpd_t];

def ctx_of(v: ptr[PyObject]) -> ptr[mpd_context_t];

def context_record(v: ptr[PyObject]) -> ptr[PyDecContextObject];

def ctx_caps(v: ptr[PyObject]) -> i32;

def signal_dict_flags(v: ptr[PyObject]) -> ptr[u32];

def copy_mpd_context(target: ptr[mpd_context_t], source: ptr[mpd_context_t]);

def work_context(context: ptr[PyObject]) -> ptr[mpd_context_t];

def free_work_context(work: ptr[mpd_context_t]);

def bool_object(value: bool) -> ptr[PyObject];

def state_value(module: ptr[PyObject], index: int) -> ptr[PyObject];

def module_of_type(type: ptr[PyObject]) -> ptr[PyObject];

def module_of(op: ptr[PyObject]) -> ptr[PyObject];

def module_of_context(context: ptr[PyObject]) -> ptr[PyObject];

def module_by_token(op: ptr[PyObject]) -> ptr[PyObject];

def module_of_left_or_right(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject];

def module_of_ternary(
    left: ptr[PyObject], right: ptr[PyObject], modulus: ptr[PyObject]
) -> ptr[PyObject];

def dec_type(module: ptr[PyObject]) -> ptr[PyObject];

def context_type(module: ptr[PyObject]) -> ptr[PyObject];

def type_check(v: ptr[PyObject], type: ptr[PyObject]) -> bool;

def dec_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool;

def dec_check_exact(module: ptr[PyObject], v: ptr[PyObject]) -> bool;

def context_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool;

def signal_dict_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool;

def signal_exception(module: ptr[PyObject], index: int) -> ptr[PyObject];

def condition_exception(module: ptr[PyObject], index: int) -> ptr[PyObject];

def value_error_int(message: str) -> i32;

def value_error_ptr(message: str) -> ptr[PyObject];

def type_error_int(message: str) -> i32;

def internal_error_int(funcname: str) -> i32;

def internal_error_ptr(funcname: str) -> ptr[PyObject];

def flags_as_exception(module: ptr[PyObject], flags: u32) -> ptr[PyObject];

def exception_as_flag(module: ptr[PyObject], ex: ptr[PyObject]) -> u32;

def flags_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject];

def signals_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject];

def list_as_flags(module: ptr[PyObject], items: ptr[PyObject]) -> u32;

def flags_as_dict(module: ptr[PyObject], flags: u32) -> ptr[PyObject];

def dict_as_flags(module: ptr[PyObject], value: ptr[PyObject]) -> u32;

def dec_addstatus(context: ptr[PyObject], status: u32) -> bool;

def getround(module: ptr[PyObject], v: ptr[PyObject]) -> i32;

def dec_type_new(module: ptr[PyObject], type: ptr[PyObject]) -> ptr[PyObject];

def dec_alloc(module: ptr[PyObject]) -> ptr[PyObject];

def context_copy(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def init_current_context(module: ptr[PyObject]) -> ptr[PyObject];

def current_context(module: ptr[PyObject]) -> ptr[PyObject];

def current_context_borrowed(module: ptr[PyObject]) -> ptr[PyObject];

def context_or_current(module: ptr[PyObject], context: ptr[PyObject]) -> ptr[PyObject];

def set_current_context(module: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject];

impl mpd(v: ptr[PyObject]) -> ptr[mpd_t] {
    return ptr[mpd_t](ptr[u8](v) + DEC_MPD_OFFSET);
}

impl ctx_of(v: ptr[PyObject]) -> ptr[mpd_context_t] {
    return ptr[mpd_context_t](ptr[u8](v) + CONTEXT_CTX_OFFSET);
}

impl context_record(v: ptr[PyObject]) -> ptr[PyDecContextObject] {
    return ptr[PyDecContextObject](v);
}

impl ctx_caps(v: ptr[PyObject]) -> i32 {
    return context_record(v).view(1)[0].capitals;
}

impl signal_dict_flags(v: ptr[PyObject]) -> ptr[u32] {
    return ptr[PyDecSignalDictObject](v).view(1)[0].flags;
}

impl copy_mpd_context(target: ptr[mpd_context_t], source: ptr[mpd_context_t]) {
    jacpy_memory_copy(ptr(target), ptr(source), i64(MPD_CONTEXT_SIZE));
}

impl work_context(context: ptr[PyObject]) -> ptr[mpd_context_t] {
    work = ptr[mpd_context_t](PyMem_Malloc(u64(MPD_CONTEXT_SIZE)));
    if not work {
        PyErr_NoMemory();
        return work;
    }
    copy_mpd_context(work, ctx_of(context));
    return work;
}

impl free_work_context(work: ptr[mpd_context_t]) {
    PyMem_Free(ptr(work));
}

impl bool_object(value: bool) -> ptr[PyObject] {
    return PyBool_FromLong(1 if value else 0);
}

impl state_value(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl module_of_type(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, decimal_module_token.handle);
}

impl module_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return module_of_type(ptr[PyObject](object_type(op)));
}

impl module_of_context(context: ptr[PyObject]) -> ptr[PyObject] {
    return context_record(context).view(1)[0].modstate;
}

impl module_by_token(op: ptr[PyObject]) -> ptr[PyObject] {
    base: ptr[PyObject] = NULL;
    if PyType_GetBaseByToken(
        ptr[PyObject](object_type(op)), ptr(addressof(dec_spec)), &mut base
    )
        != 1 {
        return NULL;
    }
    module = PyType_GetModule(base);
    jacpy_release(base);
    return module;
}

impl module_of_left_or_right(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_by_token(left);
    if module {
        return module;
    }
    return module_by_token(right);
}

impl module_of_ternary(
    left: ptr[PyObject], right: ptr[PyObject], modulus: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_by_token(left);
    if module {
        return module;
    }
    module = module_by_token(right);
    if module {
        return module;
    }
    return module_by_token(modulus);
}

impl dec_type(module: ptr[PyObject]) -> ptr[PyObject] {
    return state_value(module, STATE_DEC_TYPE);
}

impl context_type(module: ptr[PyObject]) -> ptr[PyObject] {
    return state_value(module, STATE_CONTEXT_TYPE);
}

impl type_check(v: ptr[PyObject], type: ptr[PyObject]) -> bool {
    actual = ptr[PyObject](object_type(v));
    return actual == type or PyType_IsSubtype(actual, type) != 0;
}

impl dec_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return type_check(v, dec_type(module));
}

impl dec_check_exact(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(v)) == dec_type(module);
}

impl context_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return type_check(v, context_type(module));
}

impl signal_dict_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(v)) == state_value(module, STATE_SIGNAL_DICT_TYPE);
}

impl signal_exception(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return state_value(module, STATE_SIGNAL_EXCEPTIONS + index);
}

impl condition_exception(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    if index == 0 {
        return signal_exception(module, 0);
    }
    return state_value(module, STATE_CONDITION_EXCEPTIONS + index - 1);
}

impl value_error_int(message: str) -> i32 {
    object_error(PyExc_ValueError, message);
    return i32(-1);
}

impl value_error_ptr(message: str) -> ptr[PyObject] {
    object_error(PyExc_ValueError, message);
    return NULL;
}

impl type_error_int(message: str) -> i32 {
    object_error(PyExc_TypeError, message);
    return i32(-1);
}

impl internal_error_int(funcname: str) -> i32 {
    object_error(PyExc_RuntimeError, "internal error in " + funcname);
    return i32(-1);
}

impl internal_error_ptr(funcname: str) -> ptr[PyObject] {
    object_error(PyExc_RuntimeError, "internal error in " + funcname);
    return NULL;
}

impl flags_as_exception(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
    for index in range(SIGNAL_MAP_LEN) {
        if (flags & SIGNAL_FLAGS[index]) != u32(0) {
            return signal_exception(module, index);
        }
    }
    return internal_error_ptr("flags_as_exception");
}

impl exception_as_flag(module: ptr[PyObject], ex: ptr[PyObject]) -> u32 {
    for index in range(SIGNAL_MAP_LEN) {
        if signal_exception(module, index) == ex {
            return SIGNAL_FLAGS[index];
        }
    }
    object_error(PyExc_KeyError, INVALID_SIGNALS_ERR);
    return DEC_INVALID_SIGNALS;
}

impl flags_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
    result = PyList_New(0);
    if not result {
        return NULL;
    }
    for index in range(len(CONDITION_FLAGS)) {
        if (flags & CONDITION_FLAGS[index]) != u32(0)
            and PyList_Append(result, condition_exception(module, index)) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    for index in range(1, SIGNAL_MAP_LEN) {
        if (flags & SIGNAL_FLAGS[index]) != u32(0)
            and PyList_Append(result, signal_exception(module, index)) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

impl signals_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
    result = PyList_New(0);
    if not result {
        return NULL;
    }
    for index in range(SIGNAL_MAP_LEN) {
        if (flags & SIGNAL_FLAGS[index]) != u32(0)
            and PyList_Append(result, signal_exception(module, index)) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

impl list_as_flags(module: ptr[PyObject], items: ptr[PyObject]) -> u32 {
    flags: u32 = 0;
    count = PyList_Size(items);
    for j in range(int(count)) {
        x = exception_as_flag(module, PyList_GetItem(items, i64(j)));
        if (x & DEC_ERRORS) != u32(0) {
            return x;
        }
        flags = flags | x;
    }
    return flags;
}

impl flags_as_dict(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
    result = PyDict_New();
    if not result {
        return NULL;
    }
    for index in range(SIGNAL_MAP_LEN) {
        value = bool_object((flags & SIGNAL_FLAGS[index]) != u32(0));
        status = PyDict_SetItem(result, signal_exception(module, index), value);
        jacpy_release(value);
        if status < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

impl dict_as_flags(module: ptr[PyObject], value: ptr[PyObject]) -> u32 {
    if jacpy_is_dict(value) == 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("argument must be a signal dict"));
        return DEC_INVALID_SIGNALS;
    }
    if PyDict_Size(value) != i64(SIGNAL_MAP_LEN) {
        PyErr_SetString(PyExc_KeyError, ptr[u8]("invalid signal dict"));
        return DEC_INVALID_SIGNALS;
    }
    flags: u32 = 0;
    for index in range(SIGNAL_MAP_LEN) {
        b = PyDict_GetItemWithError(value, signal_exception(module, index));
        if not b {
            if PyErr_Occurred() {
                return DEC_ERR_OCCURRED;
            }
            PyErr_SetString(PyExc_KeyError, ptr[u8]("invalid signal dict"));
            return DEC_INVALID_SIGNALS;
        }
        x = PyObject_IsTrue(b);
        if x < 0 {
            return DEC_ERR_OCCURRED;
        }
        if x == 1 {
            flags = flags | SIGNAL_FLAGS[index];
        }
    }
    return flags;
}

impl dec_addstatus(context: ptr[PyObject], status: u32) -> bool {
    ctx = ctx_of(context);
    module = module_of_context(context);
    record = ctx.view(1);
    record[0].status = record[0].status | status;
    if (status & (record[0].traps | MPD_Malloc_error)) != u32(0) {
        if (status & MPD_Malloc_error) != u32(0) {
            PyErr_NoMemory();
            return True;
        }
        ex = flags_as_exception(module, record[0].traps & status);
        if not ex {
            return True;
        }
        siglist = flags_as_list(module, record[0].traps & status);
        if not siglist {
            return True;
        }
        PyErr_SetObject(ex, siglist);
        jacpy_release(siglist);
        return True;
    }
    return False;
}

impl getround(module: ptr[PyObject], v: ptr[PyObject]) -> i32 {
    if jacpy_is_unicode(v) != 0 {
        for i in range(PY_DEC_ROUND_GUARD) {
            if v == state_value(module, STATE_ROUND_MAP + i) {
                return i32(i);
            }
        }
        for i in range(PY_DEC_ROUND_GUARD) {
            if PyUnicode_Compare(v, state_value(module, STATE_ROUND_MAP + i)) == 0 {
                return i32(i);
            }
        }
    }
    return type_error_int(INVALID_ROUNDING_ERR);
}

impl dec_type_new(module: ptr[PyObject], type: ptr[PyObject]) -> ptr[PyObject] {
    exact = type == dec_type(module);
    dec: ptr[PyObject] = NULL;
    if exact {
        dec = _PyObject_GC_New(type);
    } else {
        tp = ptr[PyTypeObject](type);
        dec = tp.view(1)[0].tp_alloc(tp, 0);
    }
    if not dec {
        return NULL;
    }
    ptr[PyDecObject](dec).view(1)[0].hash = -1;
    record = mpd(dec).view(1);
    record[0].flags = MPD_STATIC | MPD_STATIC_DATA;
    record[0].exp = 0;
    record[0].digits = 0;
    record[0].len = 0;
    record[0].alloc = PY_DEC_MINALLOC;
    record[0].data = ptr[u64](ptr[u8](dec) + DEC_DATA_OFFSET);
    if exact {
        PyObject_GC_Track(ptr(dec));
    }
    return dec;
}

impl dec_alloc(module: ptr[PyObject]) -> ptr[PyObject] {
    return dec_type_new(module, dec_type(module));
}

impl context_copy(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_context(self);
    copy = PyObject_CallObject(context_type(module), NULL);
    if not copy {
        return NULL;
    }
    copy_mpd_context(ctx_of(copy), ctx_of(self));
    ctx_of(copy).view(1)[0].newtrap = 0;
    context_record(copy).view(1)[0].capitals = ctx_caps(self);
    return copy;
}

impl init_current_context(module: ptr[PyObject]) -> ptr[PyObject] {
    tl_context = context_copy(
        state_value(module, STATE_DEFAULT_CONTEXT_TEMPLATE), NULL
    );
    if not tl_context {
        return NULL;
    }
    ctx_of(tl_context).view(1)[0].status = 0;
    token = PyContextVar_Set(
        state_value(module, STATE_CURRENT_CONTEXT_VAR), tl_context
    );
    if not token {
        jacpy_release(tl_context);
        return NULL;
    }
    jacpy_release(token);
    return tl_context;
}

impl current_context(module: ptr[PyObject]) -> ptr[PyObject] {
    tl_context: ptr[PyObject] = NULL;
    if PyContextVar_Get(
        state_value(module, STATE_CURRENT_CONTEXT_VAR), NULL, &mut tl_context
    )
        < 0 {
        return NULL;
    }
    if tl_context {
        return tl_context;
    }
    return init_current_context(module);
}

impl current_context_borrowed(module: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context(module);
    if context {
        jacpy_release(context);
    }
    return context;
}

impl context_or_current(
    module: ptr[PyObject], context: ptr[PyObject]
) -> ptr[PyObject] {
    if context == Py_None {
        return current_context_borrowed(module);
    }
    if not context_check(module, context) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("optional argument must be a context")
        );
        return NULL;
    }
    return context;
}

impl set_current_context(module: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    if not context_check(module, v) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("argument must be a context"));
        return NULL;
    }
    if v == state_value(module, STATE_DEFAULT_CONTEXT_TEMPLATE)
        or v == state_value(module, STATE_BASIC_CONTEXT_TEMPLATE)
        or v == state_value(module, STATE_EXTENDED_CONTEXT_TEMPLATE) {
        v = context_copy(v, NULL);
        if not v {
            return NULL;
        }
        ctx_of(v).view(1)[0].status = 0;
    } else {
        v = Py_NewRef(v);
    }
    token = PyContextVar_Set(state_value(module, STATE_CURRENT_CONTEXT_VAR), v);
    jacpy_release(v);
    if not token {
        return NULL;
    }
    jacpy_release(token);
    return Py_NewRef(Py_None);
}
