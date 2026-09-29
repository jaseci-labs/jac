"""Object layouts, module state, signals and contexts of the _decimal module.

Modules/_decimal/_decimal.c's object structs, module state lookup, signal and
condition maps, status and flag conversions, and the current-context
handling, in native Jac. A Decimal keeps its mpd_t and a small static
coefficient inside the object, and a Context its mpd_context_t, exactly as the
C structs lay them out, so libmpdec works on them in place. The module state
is the binding layer's reference slots, indexed by the STATE_* constants.
The current context is a contextvar (WITH_DECIMAL_CONTEXTVAR, which every
build defines). See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_is_dict,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_release,
    NULL,
    Py_NewRef,
    Py_None,
    PyContextVar_Get,
    PyContextVar_Set,
    PyDict_GetItemWithError,
    PyDict_New,
    PyDict_SetItem,
    PyDict_Size,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetObject,
    PyErr_SetString,
    PyExc_KeyError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_Size,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CallObject,
    PyObject_IsTrue,
    PyType_GetBaseByToken,
    PyType_GetModule,
    PyType_IsSubtype,
    PyType_Spec,
    PyUnicode_Compare,
    _PyObject_GC_New,
    PyObject_GC_Track
}
import from jaclang.runtime.python.layouts { PyTypeObject, _object }
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.bindings.type { jacpy_binding_owner }
import from jaclang.runtime.python.modules.mpdecimal {
    MPD_CONTEXT_SIZE,
    MPD_Clamped,
    MPD_Conversion_syntax,
    MPD_Division_by_zero,
    MPD_Division_impossible,
    MPD_Division_undefined,
    MPD_IEEE_Invalid_operation,
    MPD_Inexact,
    MPD_Invalid_context,
    MPD_Invalid_operation,
    MPD_Malloc_error,
    MPD_Max_status,
    MPD_Not_implemented,
    MPD_Overflow,
    MPD_ROUND_GUARD,
    MPD_Rounded,
    MPD_STATIC,
    MPD_STATIC_DATA,
    MPD_Subnormal,
    MPD_Underflow,
    mpd_context_t,
    mpd_t
}

import from c {
    # PyDecObject: the hash, the mpd_t and its _Py_DEC_MINALLOC-word
    # static coefficient.
    obj PyDecObject {
        has ob_base: _object,
            hash: i64,
            dec: mpd_t,
            data_0: u64,
            data_1: u64,
            data_2: u64,
            data_3: u64;
    }
    # PyDecSignalDictObject: the address of the context's traps or status.
    obj PyDecSignalDictObject {
        has ob_base: _object,
            flags: ptr[u32];
    }
    # PyDecContextObject; `modstate` is the module whose state it uses.
    obj PyDecContextObject {
        has ob_base: _object,
            ctx: mpd_context_t,
            traps: ptr[PyObject],
            flags: ptr[PyObject],
            capitals: i32,
            tstate: ptr,
            modstate: ptr[PyObject];
    }
    # PyDecContextManagerObject: the local (inner) and global (outer)
    # contexts.
    obj PyDecContextManagerObject {
        has ob_base: _object,
            inner: ptr[PyObject],
            outer: ptr[PyObject];
    }
    # The Decimal and Context type specs, which are the types' tokens.
    glob dec_spec: PyType_Spec,
         context_spec: PyType_Spec;
    # The METH_NOARGS methods float.as_integer_ratio and int.bit_length,
    # which _decimal calls directly (the "external C-API functions" of the
    # C module state); the module sets them from the types' method tables.
    obj BuiltinMethods {
        has float_as_integer_ratio:
            Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            long_bit_length:
                Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  glob builtin_methods: BuiltinMethods = BuiltinMethods(),
         # mpd_maxcontext(): the exact-conversion context, set by the module.
         max_context: mpd_context_t = mpd_context_t(),
         # The maximal context with 21 extra digits and exponent range that
         # the hash computation uses.
         hash_context: mpd_context_t = mpd_context_t(); glob PyType_Type:
             PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyFloat_Type: PyTypeObject,
         PyComplex_Type: PyTypeObject;
}

# Offsets inside the objects above: the mpd_t and static coefficient of a
# PyDecObject, the mpd_context_t of a PyDecContextObject and its traps and
# status words.
glob DEC_MPD_OFFSET: Final[int] = 24,
     DEC_DATA_OFFSET: Final[int] = 72,
     CONTEXT_CTX_OFFSET: Final[int] = 16,
     CONTEXT_TRAPS_OFFSET: Final[int] = 40,
     CONTEXT_STATUS_OFFSET: Final[int] = 44,
     # The sizes of PyDecObject, PyDecSignalDictObject, PyDecContextObject and
     # PyDecContextManagerObject.
     DEC_OBJECT_SIZE: Final[int] = 104,
     SIGNAL_DICT_OBJECT_SIZE: Final[int] = 24,
     CONTEXT_OBJECT_SIZE: Final[int] = 104,
     CONTEXT_MANAGER_OBJECT_SIZE: Final[int] = 32,
     # _Py_DEC_MINALLOC >= MPD_MINALLOC
     PY_DEC_MINALLOC: Final[int] = 4,
     # _PY_DEC_ROUND_GUARD: the rounding modes Python names.
     PY_DEC_ROUND_GUARD: Final[int] = 8;

# The module state slots.
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
     # round_map: the interned rounding mode names, one per mode.
     STATE_ROUND_MAP: Final[int] = 11,
     STATE_RATIONAL: Final[int] = 19,
     # _pydecimal.Decimal, imported on first use by format().
     STATE_PYDECIMAL: Final[int] = 20,
     STATE_SIGNAL_TUPLE: Final[int] = 21,
     # The exception of each signal, in signal map order.
     STATE_SIGNAL_EXCEPTIONS: Final[int] = 22,
     # The exceptions of conditions 1.. of the condition map; condition 0 is
     # InvalidOperation, the first signal.
     STATE_CONDITION_EXCEPTIONS: Final[int] = 31,
     STATE_COUNT: Final[int] = 35;

# Rich comparison operators.
glob Py_LT_OP: Final[int] = 0,
     Py_LE_OP: Final[int] = 1,
     Py_EQ_OP: Final[int] = 2,
     Py_NE_OP: Final[int] = 3,
     Py_GT_OP: Final[int] = 4,
     Py_GE_OP: Final[int] = 5;

# Error codes for functions that return signals or conditions.
glob DEC_INVALID_SIGNALS: Final[u32] = 0x8000,
     DEC_ERR_OCCURRED: Final[u32] = 0x10000,
     DEC_ERRORS: Final[u32] = 0x18000,
     # MPD_Float_operation is libmpdec's MPD_Not_implemented flag.
     MPD_Float_operation: Final[u32] = 0x00000400;

# The exceptions that correspond to IEEE signals, and the conditions that
# inherit from InvalidOperation: name and libmpdec flag.
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

"""The _decimal module definition, for finding a type's module: the binding
layer's handle, set when the module is created."""
obj ModuleToken {
    has handle: ptr = ptr();
}

glob decimal_module_token: ModuleToken = ModuleToken();

# ---------------------------------------------------------------------------
# Object access.

"""MPD(v): the mpd_t of a Decimal."""
def mpd(v: ptr[PyObject]) -> ptr[mpd_t] {
    return ptr[mpd_t](ptr[u8](v) + DEC_MPD_OFFSET);
}

"""CTX(v): the mpd_context_t of a Context."""
def ctx_of(v: ptr[PyObject]) -> ptr[mpd_context_t] {
    return ptr[mpd_context_t](ptr[u8](v) + CONTEXT_CTX_OFFSET);
}

def context_record(v: ptr[PyObject]) -> ptr[PyDecContextObject] {
    return ptr[PyDecContextObject](v);
}

"""CtxCaps(v)."""
def ctx_caps(v: ptr[PyObject]) -> i32 {
    return context_record(v).view(1)[0].capitals;
}

"""SdFlagAddr(v)."""
def signal_dict_flags(v: ptr[PyObject]) -> ptr[u32] {
    return ptr[PyDecSignalDictObject](v).view(1)[0].flags;
}

"""*CTX(target) = *CTX(source): copy a whole mpd_context_t."""
def copy_mpd_context(target: ptr[mpd_context_t], source: ptr[mpd_context_t]) {
    jacpy_memory_copy(ptr(target), ptr(source), i64(MPD_CONTEXT_SIZE));
}

"""A malloc'd copy of *CTX(context), for an operation that changes its
rounding; NULL with MemoryError."""
def work_context(context: ptr[PyObject]) -> ptr[mpd_context_t] {
    work = ptr[mpd_context_t](PyMem_Malloc(u64(MPD_CONTEXT_SIZE)));
    if not work {
        PyErr_NoMemory();
        return work;
    }
    copy_mpd_context(work, ctx_of(context));
    return work;
}

def free_work_context(work: ptr[mpd_context_t]) {
    PyMem_Free(ptr(work));
}

"""A new reference to True or False."""
def bool_object(value: bool) -> ptr[PyObject] {
    return PyBool_FromLong(1 if value else 0);
}

# ---------------------------------------------------------------------------
# Module state.

"""A module state entry (borrowed)."""
def state_value(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

"""get_module_state_by_def: the _decimal module of `type` or its bases
(borrowed)."""
def module_of_type(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, decimal_module_token.handle);
}

"""The module of `op`'s type (borrowed)."""
def module_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return module_of_type(ptr[PyObject](object_type(op)));
}

"""get_module_state_from_ctx: the module whose state a Context uses."""
def module_of_context(context: ptr[PyObject]) -> ptr[PyObject] {
    return context_record(context).view(1)[0].modstate;
}

"""The module of the Decimal base of `op`'s type, or NULL when it has none."""
def module_by_token(op: ptr[PyObject]) -> ptr[PyObject] {
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

"""find_state_left_or_right: the module of the operand that is a Decimal."""
def module_of_left_or_right(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_by_token(left);
    if module {
        return module;
    }
    return module_by_token(right);
}

"""find_state_ternary."""
def module_of_ternary(
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

def dec_type(module: ptr[PyObject]) -> ptr[PyObject] {
    return state_value(module, STATE_DEC_TYPE);
}

def context_type(module: ptr[PyObject]) -> ptr[PyObject] {
    return state_value(module, STATE_CONTEXT_TYPE);
}

"""PyObject_TypeCheck(v, type)."""
def type_check(v: ptr[PyObject], type: ptr[PyObject]) -> bool {
    actual = ptr[PyObject](object_type(v));
    return actual == type or PyType_IsSubtype(actual, type) != 0;
}

"""PyDec_Check."""
def dec_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return type_check(v, dec_type(module));
}

"""PyDec_CheckExact."""
def dec_check_exact(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(v)) == dec_type(module);
}

"""PyDecContext_Check."""
def context_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return type_check(v, context_type(module));
}

"""PyDecSignalDict_Check."""
def signal_dict_check(module: ptr[PyObject], v: ptr[PyObject]) -> bool {
    return ptr[PyObject](object_type(v)) == state_value(module, STATE_SIGNAL_DICT_TYPE);
}

"""The exception of signal `index` (borrowed)."""
def signal_exception(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return state_value(module, STATE_SIGNAL_EXCEPTIONS + index);
}

"""The exception of condition `index` (borrowed)."""
def condition_exception(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    if index == 0 {
        return signal_exception(module, 0);
    }
    return state_value(module, STATE_CONDITION_EXCEPTIONS + index - 1);
}

# ---------------------------------------------------------------------------
# Errors.

def value_error_int(message: str) -> i32 {
    PyErr_SetString(PyExc_ValueError, message);
    return i32(-1);
}

def value_error_ptr(message: str) -> ptr[PyObject] {
    PyErr_SetString(PyExc_ValueError, message);
    return NULL;
}

def type_error_int(message: str) -> i32 {
    PyErr_SetString(PyExc_TypeError, message);
    return i32(-1);
}

"""INTERNAL_ERROR_INT."""
def internal_error_int(funcname: str) -> i32 {
    PyErr_SetString(PyExc_RuntimeError, "internal error in " + funcname);
    return i32(-1);
}

"""INTERNAL_ERROR_PTR."""
def internal_error_ptr(funcname: str) -> ptr[PyObject] {
    PyErr_SetString(PyExc_RuntimeError, "internal error in " + funcname);
    return NULL;
}

# ---------------------------------------------------------------------------
# Flags and signals.

"""The exception of the first signal in `flags` (borrowed)."""
def flags_as_exception(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
    for index in range(SIGNAL_MAP_LEN) {
        if (flags & SIGNAL_FLAGS[index]) != u32(0) {
            return signal_exception(module, index);
        }
    }
    return internal_error_ptr("flags_as_exception");
}

"""The flag of signal exception `ex`, or DEC_INVALID_SIGNALS with KeyError."""
def exception_as_flag(module: ptr[PyObject], ex: ptr[PyObject]) -> u32 {
    for index in range(SIGNAL_MAP_LEN) {
        if signal_exception(module, index) == ex {
            return SIGNAL_FLAGS[index];
        }
    }
    PyErr_SetString(PyExc_KeyError, INVALID_SIGNALS_ERR);
    return DEC_INVALID_SIGNALS;
}

"""The conditions, then the signals other than InvalidOperation, in `flags`
as a list of exceptions."""
def flags_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
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

"""The signals in `flags` as a list of exceptions."""
def signals_as_list(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
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

"""The flags of a list of signal exceptions, or an error code."""
def list_as_flags(module: ptr[PyObject], items: ptr[PyObject]) -> u32 {
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

"""A dict of each signal exception to whether it is in `flags`."""
def flags_as_dict(module: ptr[PyObject], flags: u32) -> ptr[PyObject] {
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

"""The flags of a dict of all signals to truth values, or an error code."""
def dict_as_flags(module: ptr[PyObject], value: ptr[PyObject]) -> u32 {
    if jacpy_is_dict(value) == 0 {
        PyErr_SetString(PyExc_TypeError, "argument must be a signal dict");
        return DEC_INVALID_SIGNALS;
    }
    if PyDict_Size(value) != i64(SIGNAL_MAP_LEN) {
        PyErr_SetString(PyExc_KeyError, "invalid signal dict");
        return DEC_INVALID_SIGNALS;
    }
    flags: u32 = 0;
    for index in range(SIGNAL_MAP_LEN) {
        b = PyDict_GetItemWithError(value, signal_exception(module, index));
        if not b {
            if PyErr_Occurred() {
                return DEC_ERR_OCCURRED;
            }
            PyErr_SetString(PyExc_KeyError, "invalid signal dict");
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

"""Record `status` in the context; when a trapped signal is set, raise its
exception with the list of conditions and return True."""
def dec_addstatus(context: ptr[PyObject], status: u32) -> bool {
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

"""The rounding mode a rounding name stands for, or -1 with TypeError."""
def getround(module: ptr[PyObject], v: ptr[PyObject]) -> i32 {
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

# ---------------------------------------------------------------------------
# Decimal objects.

"""PyDecType_New: a new zero Decimal of `type` whose mpd_t uses the object's
static coefficient."""
def dec_type_new(module: ptr[PyObject], type: ptr[PyObject]) -> ptr[PyObject] {
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

"""dec_alloc: a new zero Decimal."""
def dec_alloc(module: ptr[PyObject]) -> ptr[PyObject] {
    return dec_type_new(module, dec_type(module));
}

# ---------------------------------------------------------------------------
# Contexts.

"""A copy of a Context (its type, mpd_context_t and capitals), newtrap
cleared: context_copy."""
def context_copy(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
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

"""A fresh copy of the default context template, installed as the current
context (new reference)."""
def init_current_context(module: ptr[PyObject]) -> ptr[PyObject] {
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

"""The current context (new reference), or NULL with an error set."""
def current_context(module: ptr[PyObject]) -> ptr[PyObject] {
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

"""CURRENT_CONTEXT: the current context, borrowed from the contextvar that
keeps it; NULL with an error set."""
def current_context_borrowed(module: ptr[PyObject]) -> ptr[PyObject] {
    context = current_context(module);
    if context {
        jacpy_release(context);
    }
    return context;
}

"""CONTEXT_CHECK_VA: None means the current context (borrowed); anything
else must be a Context. NULL with an error set."""
def context_or_current(module: ptr[PyObject], context: ptr[PyObject]) -> ptr[PyObject] {
    if context == Py_None {
        return current_context_borrowed(module);
    }
    if not context_check(module, context) {
        PyErr_SetString(PyExc_TypeError, "optional argument must be a context");
        return NULL;
    }
    return context;
}

"""Set the current context: a copy when `v` is one of the templates, as
decimal.py does."""
def set_current_context(module: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    if not context_check(module, v) {
        PyErr_SetString(PyExc_TypeError, "argument must be a context");
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
