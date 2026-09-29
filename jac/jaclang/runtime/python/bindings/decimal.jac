"""The _decimal module: the C decimal arithmetic module over libmpdec.

Modules/_decimal/_decimal.c's module definition in native Jac: the Decimal,
Context, SignalDictMixin and ContextManager type specs and their method,
attribute and slot tables (heap types, each spec its type's token), the
module functions, and the exec hook that sets libmpdec's allocator hooks,
creates the types, the signal and condition exception hierarchy, the
context templates and the constants. The implementation is in
modules/decimal_*.jac and the libmpdec interface in modules/mpdecimal.jac;
the docstrings are Modules/_decimal/docstrings.h's. See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    Py_NewRef,
    Py_None,
    PyContextVar_New,
    PyDict_SetItemString,
    PyErr_Format,
    PyErr_NewException,
    PyErr_SetString,
    PyExc_ArithmeticError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ZeroDivisionError,
    PyImport_ImportModule,
    PyLong_FromSsize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    PyMethodDef,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddStringConstant,
    PyModule_AddType,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_CallObject,
    PyObject_GenericGetAttr,
    PyObject_GetAttrString,
    PyObject_HashNotImplemented,
    PyTuple_New,
    PyTuple_Pack,
    PyTuple_SetItem,
    PyType_FromMetaclass,
    PyType_GetDict,
    PyType_Slot,
    PyType_Spec,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    jacpy_is_type
}
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_KEYWORDS,
    METH_NOARGS,
    METH_O,
    METH_VARARGS,
    PyGetSetDef,
    PyTypeObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_DISALLOW_INSTANTIATION,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_mp_ass_subscript,
    Py_mp_length,
    Py_mp_subscript,
    Py_nb_absolute,
    Py_nb_add,
    Py_nb_bool,
    Py_nb_divmod,
    Py_nb_float,
    Py_nb_floor_divide,
    Py_nb_int,
    Py_nb_multiply,
    Py_nb_negative,
    Py_nb_positive,
    Py_nb_power,
    Py_nb_remainder,
    Py_nb_subtract,
    Py_nb_true_divide,
    Py_tp_clear,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_getattro,
    Py_tp_getset,
    Py_tp_hash,
    Py_tp_init,
    Py_tp_iter,
    Py_tp_methods,
    Py_tp_new,
    Py_tp_repr,
    Py_tp_richcompare,
    Py_tp_setattro,
    Py_tp_str,
    Py_tp_token,
    Py_tp_traverse
}
import from jaclang.runtime.python.object_model.bool { py_true }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_state_get,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.modules.mpdecimal {
    MPD_Division_by_zero,
    MPD_Division_undefined,
    MPD_IEEE_CONTEXT_MAX_BITS,
    MPD_MAX_EMAX,
    MPD_MAX_PREC,
    MPD_MIN_EMIN,
    MPD_MIN_ETINY,
    MPD_Overflow,
    MPD_Underflow,
    mpd_callocfunc,
    mpd_callocfunc_em,
    mpd_context_t,
    mpd_free,
    mpd_mallocfunc,
    mpd_maxcontext,
    mpd_reallocfunc,
    mpd_round_string,
    mpd_setminalloc,
    mpd_traphandler,
    mpd_version
}
import from jaclang.runtime.python.modules.decimal_ops {
    OP_ABS,
    OP_ADD,
    OP_AND,
    OP_COMPARE,
    OP_COMPARE_SIGNAL,
    OP_COMPARE_TOTAL,
    OP_COMPARE_TOTAL_MAG,
    OP_DIV,
    OP_DIVINT,
    OP_EXP,
    OP_INVERT,
    OP_IS_CANONICAL,
    OP_IS_FINITE,
    OP_IS_INFINITE,
    OP_IS_NAN,
    OP_IS_NORMAL,
    OP_IS_QNAN,
    OP_IS_SIGNED,
    OP_IS_SNAN,
    OP_IS_SUBNORMAL,
    OP_IS_ZERO,
    OP_LN,
    OP_LOG10,
    OP_LOGB,
    OP_MAX,
    OP_MAX_MAG,
    OP_MIN,
    OP_MINUS,
    OP_MIN_MAG,
    OP_MUL,
    OP_NEXT_MINUS,
    OP_NEXT_PLUS,
    OP_NEXT_TOWARD,
    OP_OR,
    OP_PLUS,
    OP_QUANTIZE,
    OP_REDUCE,
    OP_REM,
    OP_REM_NEAR,
    OP_ROTATE,
    OP_ROUND_TO_INT,
    OP_ROUND_TO_INTX,
    OP_SCALEB,
    OP_SHIFT,
    OP_SQRT,
    OP_SUB,
    OP_XOR
}
import from jaclang.runtime.python.modules.decimal_objects {
    CONDITION_FLAGS,
    CONDITION_NAMES,
    CONTEXT_MANAGER_OBJECT_SIZE,
    CONTEXT_OBJECT_SIZE,
    DEC_OBJECT_SIZE,
    INEXACT,
    MPD_Float_operation,
    PY_DEC_MINALLOC,
    PY_DEC_ROUND_GUARD,
    PyFloat_Type,
    PyLong_Type,
    PyType_Type,
    ROUNDED,
    SIGNAL_DICT_OBJECT_SIZE,
    SIGNAL_FLAGS,
    SIGNAL_MAP_LEN,
    SIGNAL_NAMES,
    STATE_BASIC_CONTEXT_TEMPLATE,
    STATE_CONDITION_EXCEPTIONS,
    STATE_CONTEXT_MANAGER_TYPE,
    STATE_CONTEXT_TYPE,
    STATE_COUNT,
    STATE_CURRENT_CONTEXT_VAR,
    STATE_DEC_TYPE,
    STATE_DECIMAL_EXCEPTION,
    STATE_DECIMAL_TUPLE,
    STATE_DEFAULT_CONTEXT_TEMPLATE,
    STATE_EXTENDED_CONTEXT_TEMPLATE,
    STATE_RATIONAL,
    STATE_ROUND_MAP,
    STATE_SIGNAL_DICT_MIXIN_TYPE,
    STATE_SIGNAL_DICT_TYPE,
    STATE_SIGNAL_EXCEPTIONS,
    STATE_SIGNAL_TUPLE,
    SUBNORMAL,
    builtin_methods,
    context_copy,
    decimal_module_token,
    hash_context,
    max_context,
    signal_exception
}
import from jaclang.runtime.python.modules.decimal_number {
    dec_as_float,
    dec_as_integer_ratio,
    dec_as_tuple,
    dec_binary_va,
    dec_bool,
    dec_bool_va,
    dec_canonical,
    dec_ceil,
    dec_complex,
    dec_conjugate,
    dec_copy,
    dec_dealloc,
    dec_floor,
    dec_format,
    dec_from_float,
    dec_from_number,
    dec_hash,
    dec_imag,
    dec_mpd_adjexp,
    dec_mpd_class,
    dec_mpd_qcopy_abs,
    dec_mpd_qcopy_negate,
    dec_mpd_qcopy_sign,
    dec_mpd_qfma,
    dec_mpd_qquantize,
    dec_mpd_radix,
    dec_mpd_same_quantum,
    dec_mpd_to_eng,
    dec_new,
    dec_real,
    dec_reduce,
    dec_repr,
    dec_richcompare,
    dec_round,
    dec_sizeof,
    dec_str,
    dec_to_integral_exact,
    dec_to_integral_value,
    dec_total_va,
    dec_traverse,
    dec_trunc,
    dec_unary_va,
    nm_dec_as_long,
    nm_mpd_qabs,
    nm_mpd_qadd,
    nm_mpd_qdiv,
    nm_mpd_qdivint,
    nm_mpd_qdivmod,
    nm_mpd_qminus,
    nm_mpd_qmul,
    nm_mpd_qplus,
    nm_mpd_qpow,
    nm_mpd_qrem,
    nm_mpd_qsub,
    nm_nonzero
}
import from jaclang.runtime.python.modules.decimal_context {
    context_clear,
    context_clear_flags,
    context_clear_traps,
    context_dealloc,
    context_getattr,
    context_getcapitals,
    context_getclamp,
    context_getemax,
    context_getemin,
    context_getetiny,
    context_getetop,
    context_getprec,
    context_getround,
    context_init,
    context_new,
    context_reduce,
    context_repr,
    context_setattr,
    context_setcapitals,
    context_setclamp,
    context_setemax,
    context_setemin,
    context_setprec,
    context_setround,
    context_traverse,
    ctx_apply,
    ctx_binary,
    ctx_bool,
    ctx_canonical,
    ctx_copy_decimal,
    ctx_create_decimal,
    ctx_from_float,
    ctx_iscanonical,
    ctx_mpd_class,
    ctx_mpd_qcopy_abs,
    ctx_mpd_qcopy_negate,
    ctx_mpd_qcopy_sign,
    ctx_mpd_qdivmod,
    ctx_mpd_qfma,
    ctx_mpd_qpow,
    ctx_mpd_radix,
    ctx_mpd_same_quantum,
    ctx_mpd_to_eng,
    ctx_mpd_to_sci,
    ctx_total,
    ctx_unary,
    ctxmanager_clear,
    ctxmanager_dealloc,
    ctxmanager_new,
    ctxmanager_restore_global,
    ctxmanager_set_local,
    ctxmanager_traverse,
    dec_getcontext,
    dec_setcontext,
    ieee_context,
    init_basic_context,
    init_extended_context,
    signaldict_copy,
    signaldict_dealloc,
    signaldict_getitem,
    signaldict_init,
    signaldict_iter,
    signaldict_len,
    signaldict_repr,
    signaldict_richcompare,
    signaldict_setitem,
    signaldict_traverse
}

# ---------------------------------------------------------------------------
# Method wrappers: each binds a libmpdec operation to its method family.

def dec_mpd_qexp(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_EXP);
}

def dec_mpd_qln(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_LN);
}

def dec_mpd_qlog10(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_LOG10);
}

def dec_mpd_qnext_minus(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_NEXT_MINUS);
}

def dec_mpd_qnext_plus(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_NEXT_PLUS);
}

def dec_mpd_qreduce(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_REDUCE);
}

def dec_mpd_qsqrt(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_SQRT);
}

def dec_mpd_qcompare(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_COMPARE);
}

def dec_mpd_qcompare_signal(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_COMPARE_SIGNAL);
}

def dec_mpd_qmax(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_MAX);
}

def dec_mpd_qmax_mag(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_MAX_MAG);
}

def dec_mpd_qmin(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_MIN);
}

def dec_mpd_qmin_mag(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_MIN_MAG);
}

def dec_mpd_qnext_toward(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_NEXT_TOWARD);
}

def dec_mpd_qrem_near(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_REM_NEAR);
}

def dec_mpd_iscanonical(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_CANONICAL);
}

def dec_mpd_isfinite(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_FINITE);
}

def dec_mpd_isinfinite(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_INFINITE);
}

def dec_mpd_isnan(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_NAN);
}

def dec_mpd_isqnan(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_QNAN);
}

def dec_mpd_issnan(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_SNAN);
}

def dec_mpd_issigned(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_SIGNED);
}

def dec_mpd_iszero(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_bool(self, OP_IS_ZERO);
}

def dec_mpd_isnormal(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_bool_va(self, args, kwds, OP_IS_NORMAL);
}

def dec_mpd_issubnormal(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_bool_va(self, args, kwds, OP_IS_SUBNORMAL);
}

def dec_mpd_qlogb(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_LOGB);
}

def dec_mpd_qinvert(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_unary_va(self, args, kwds, OP_INVERT);
}

def dec_mpd_compare_total(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_total_va(self, args, kwds, OP_COMPARE_TOTAL);
}

def dec_mpd_compare_total_mag(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_total_va(self, args, kwds, OP_COMPARE_TOTAL_MAG);
}

def dec_mpd_qand(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_AND);
}

def dec_mpd_qor(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_OR);
}

def dec_mpd_qxor(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_XOR);
}

def dec_mpd_qrotate(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_ROTATE);
}

def dec_mpd_qscaleb(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_SCALEB);
}

def dec_mpd_qshift(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return dec_binary_va(self, args, kwds, OP_SHIFT);
}

def ctx_mpd_qabs(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_ABS);
}

def ctx_mpd_qexp(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_EXP);
}

def ctx_mpd_qln(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_LN);
}

def ctx_mpd_qlog10(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_LOG10);
}

def ctx_mpd_qminus(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_MINUS);
}

def ctx_mpd_qnext_minus(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_NEXT_MINUS);
}

def ctx_mpd_qnext_plus(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_NEXT_PLUS);
}

def ctx_mpd_qreduce(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_REDUCE);
}

def ctx_mpd_qplus(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_PLUS);
}

def ctx_mpd_qround_to_int(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_ROUND_TO_INT);
}

def ctx_mpd_qround_to_intx(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_ROUND_TO_INTX);
}

def ctx_mpd_qsqrt(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_SQRT);
}

def ctx_mpd_qadd(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_ADD);
}

def ctx_mpd_qcompare(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_COMPARE);
}

def ctx_mpd_qcompare_signal(
    context: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_COMPARE_SIGNAL);
}

def ctx_mpd_qdiv(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_DIV);
}

def ctx_mpd_qdivint(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_DIVINT);
}

def ctx_mpd_qmax(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_MAX);
}

def ctx_mpd_qmax_mag(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_MAX_MAG);
}

def ctx_mpd_qmin(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_MIN);
}

def ctx_mpd_qmin_mag(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_MIN_MAG);
}

def ctx_mpd_qmul(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_MUL);
}

def ctx_mpd_qnext_toward(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_NEXT_TOWARD);
}

def ctx_mpd_qquantize(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_QUANTIZE);
}

def ctx_mpd_qrem(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_REM);
}

def ctx_mpd_qrem_near(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_REM_NEAR);
}

def ctx_mpd_qsub(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_SUB);
}

def ctx_mpd_isfinite(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_FINITE);
}

def ctx_mpd_isinfinite(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_INFINITE);
}

def ctx_mpd_isnan(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_NAN);
}

def ctx_mpd_isnormal(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_NORMAL);
}

def ctx_mpd_isqnan(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_QNAN);
}

def ctx_mpd_issigned(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_SIGNED);
}

def ctx_mpd_issnan(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_SNAN);
}

def ctx_mpd_issubnormal(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_SUBNORMAL);
}

def ctx_mpd_iszero(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_bool(context, v, OP_IS_ZERO);
}

def ctx_mpd_qlogb(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_LOGB);
}

def ctx_mpd_qinvert(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_unary(context, v, OP_INVERT);
}

def ctx_mpd_compare_total(
    context: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return ctx_total(context, args, OP_COMPARE_TOTAL);
}

def ctx_mpd_compare_total_mag(
    context: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    return ctx_total(context, args, OP_COMPARE_TOTAL_MAG);
}

def ctx_mpd_qand(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_AND);
}

def ctx_mpd_qor(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_OR);
}

def ctx_mpd_qxor(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_XOR);
}

def ctx_mpd_qrotate(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_ROTATE);
}

def ctx_mpd_qscaleb(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_SCALEB);
}

def ctx_mpd_qshift(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_binary(context, args, OP_SHIFT);
}

# ---------------------------------------------------------------------------
# Type specs.

import from c {
    glob:priv dec_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("exp"),
                 ml_meth=ptr(dec_mpd_qexp),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "exp($self, /, context=None)\n--\n\nReturn the value of the (natural) exponential function e**x at the given\nnumber.  The function always uses the ROUND_HALF_EVEN mode and the result\nis correctly rounded.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ln"),
                 ml_meth=ptr(dec_mpd_qln),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "ln($self, /, context=None)\n--\n\nReturn the natural (base e) logarithm of the operand. The function always\nuses the ROUND_HALF_EVEN mode and the result is correctly rounded.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("log10"),
                 ml_meth=ptr(dec_mpd_qlog10),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "log10($self, /, context=None)\n--\n\nReturn the base ten logarithm of the operand. The function always uses the\nROUND_HALF_EVEN mode and the result is correctly rounded.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_minus"),
                 ml_meth=ptr(dec_mpd_qnext_minus),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "next_minus($self, /, context=None)\n--\n\nReturn the largest number representable in the given context (or in the\ncurrent default context if no context is given) that is smaller than the\ngiven operand.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_plus"),
                 ml_meth=ptr(dec_mpd_qnext_plus),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "next_plus($self, /, context=None)\n--\n\nReturn the smallest number representable in the given context (or in the\ncurrent default context if no context is given) that is larger than the\ngiven operand.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("normalize"),
                 ml_meth=ptr(dec_mpd_qreduce),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "normalize($self, /, context=None)\n--\n\nNormalize the number by stripping the rightmost trailing zeros and\nconverting any result equal to Decimal('0') to Decimal('0e0').  Used\nfor producing canonical values for members of an equivalence class.\nFor example, Decimal('32.100') and Decimal('0.321000e+2') both normalize\nto the equivalent value Decimal('32.1').\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral"),
                 ml_meth=ptr(dec_to_integral_value),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "to_integral($self, /, rounding=None, context=None)\n--\n\nIdentical to the to_integral_value() method.  The to_integral() name has been\nkept for compatibility with older versions.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral_exact"),
                 ml_meth=ptr(dec_to_integral_exact),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "to_integral_exact($self, /, rounding=None, context=None)\n--\n\nRound to the nearest integer, signaling Inexact or Rounded as appropriate if\nrounding occurs.  The rounding mode is determined by the rounding parameter\nif given, else by the given context. If neither parameter is given, then the\nrounding mode of the current default context is used.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral_value"),
                 ml_meth=ptr(dec_to_integral_value),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "to_integral_value($self, /, rounding=None, context=None)\n--\n\nRound to the nearest integer without signaling Inexact or Rounded.  The\nrounding mode is determined by the rounding parameter if given, else by\nthe given context. If neither parameter is given, then the rounding mode\nof the current default context is used.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sqrt"),
                 ml_meth=ptr(dec_mpd_qsqrt),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "sqrt($self, /, context=None)\n--\n\nReturn the square root of the argument to full precision. The result is\ncorrectly rounded using the ROUND_HALF_EVEN rounding mode.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare"),
                 ml_meth=ptr(dec_mpd_qcompare),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "compare($self, /, other, context=None)\n--\n\nCompare self to other.  Return a decimal value:\n\n    a or b is a NaN ==> Decimal('NaN')\n    a < b           ==> Decimal('-1')\n    a == b          ==> Decimal('0')\n    a > b           ==> Decimal('1')\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_signal"),
                 ml_meth=ptr(dec_mpd_qcompare_signal),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "compare_signal($self, /, other, context=None)\n--\n\nIdentical to compare, except that all NaNs signal.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("max"),
                 ml_meth=ptr(dec_mpd_qmax),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "max($self, /, other, context=None)\n--\n\nMaximum of self and other.  If one operand is a quiet NaN and the other is\nnumeric, the numeric operand is returned.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("max_mag"),
                 ml_meth=ptr(dec_mpd_qmax_mag),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "max_mag($self, /, other, context=None)\n--\n\nSimilar to the max() method, but the comparison is done using the absolute\nvalues of the operands.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("min"),
                 ml_meth=ptr(dec_mpd_qmin),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "min($self, /, other, context=None)\n--\n\nMinimum of self and other. If one operand is a quiet NaN and the other is\nnumeric, the numeric operand is returned.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("min_mag"),
                 ml_meth=ptr(dec_mpd_qmin_mag),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "min_mag($self, /, other, context=None)\n--\n\nSimilar to the min() method, but the comparison is done using the absolute\nvalues of the operands.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_toward"),
                 ml_meth=ptr(dec_mpd_qnext_toward),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "next_toward($self, /, other, context=None)\n--\n\nIf the two operands are unequal, return the number closest to the first\noperand in the direction of the second operand.  If both operands are\nnumerically equal, return a copy of the first operand with the sign set\nto be the same as the sign of the second operand.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("quantize"),
                 ml_meth=ptr(dec_mpd_qquantize),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "quantize($self, /, exp, rounding=None, context=None)\n--\n\nReturn a value equal to the first operand after rounding and having the\nexponent of the second operand.\n\n    >>> Decimal('1.41421356').quantize(Decimal('1.000'))\n    Decimal('1.414')\n\nUnlike other operations, if the length of the coefficient after the quantize\noperation would be greater than precision, then an InvalidOperation is signaled.\nThis guarantees that, unless there is an error condition, the quantized exponent\nis always equal to that of the right-hand operand.\n\nAlso unlike other operations, quantize never signals Underflow, even if the\nresult is subnormal and inexact.\n\nIf the exponent of the second operand is larger than that of the first, then\nrounding may be necessary. In this case, the rounding mode is determined by the\nrounding argument if given, else by the given context argument; if neither\nargument is given, the rounding mode of the current thread's context is used.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("remainder_near"),
                 ml_meth=ptr(dec_mpd_qrem_near),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "remainder_near($self, /, other, context=None)\n--\n\nReturn the remainder from dividing self by other.  This differs from\nself % other in that the sign of the remainder is chosen so as to minimize\nits absolute value. More precisely, the return value is self - n * other\nwhere n is the integer nearest to the exact value of self / other, and\nif two integers are equally near then the even one is chosen.\n\nIf the result is zero then its sign will be the sign of self.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fma"),
                 ml_meth=ptr(dec_mpd_qfma),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "fma($self, /, other, third, context=None)\n--\n\nFused multiply-add.  Return self*other+third with no rounding of the\nintermediate product self*other.\n\n    >>> Decimal(2).fma(3, 5)\n    Decimal('11')\n\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_canonical"),
                 ml_meth=ptr(dec_mpd_iscanonical),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_canonical($self, /)\n--\n\nReturn True if the argument is canonical and False otherwise.  Currently,\na Decimal instance is always canonical, so this operation always returns\nTrue.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_finite"),
                 ml_meth=ptr(dec_mpd_isfinite),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_finite($self, /)\n--\n\nReturn True if the argument is a finite number, and False if the argument\nis infinite or a NaN.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_infinite"),
                 ml_meth=ptr(dec_mpd_isinfinite),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_infinite($self, /)\n--\n\nReturn True if the argument is either positive or negative infinity and\nFalse otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_nan"),
                 ml_meth=ptr(dec_mpd_isnan),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_nan($self, /)\n--\n\nReturn True if the argument is a (quiet or signaling) NaN and False\notherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_qnan"),
                 ml_meth=ptr(dec_mpd_isqnan),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_qnan($self, /)\n--\n\nReturn True if the argument is a quiet NaN, and False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_snan"),
                 ml_meth=ptr(dec_mpd_issnan),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_snan($self, /)\n--\n\nReturn True if the argument is a signaling NaN and False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_signed"),
                 ml_meth=ptr(dec_mpd_issigned),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_signed($self, /)\n--\n\nReturn True if the argument has a negative sign and False otherwise.\nNote that both zeros and NaNs can carry signs.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_zero"),
                 ml_meth=ptr(dec_mpd_iszero),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "is_zero($self, /)\n--\n\nReturn True if the argument is a (positive or negative) zero and False\notherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_normal"),
                 ml_meth=ptr(dec_mpd_isnormal),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "is_normal($self, /, context=None)\n--\n\nReturn True if the argument is a normal finite non-zero number with an\nadjusted exponent greater than or equal to Emin. Return False if the\nargument is zero, subnormal, infinite or a NaN.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_subnormal"),
                 ml_meth=ptr(dec_mpd_issubnormal),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "is_subnormal($self, /, context=None)\n--\n\nReturn True if the argument is subnormal, and False otherwise. A number is\nsubnormal if it is non-zero, finite, and has an adjusted exponent less\nthan Emin.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("adjusted"),
                 ml_meth=ptr(dec_mpd_adjexp),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "adjusted($self, /)\n--\n\nReturn the adjusted exponent of the number.  Defined as exp + digits - 1.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("canonical"),
                 ml_meth=ptr(dec_canonical),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "canonical($self, /)\n--\n\nReturn the canonical encoding of the argument.  Currently, the encoding\nof a Decimal instance is always canonical, so this operation returns its\nargument unchanged.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("conjugate"),
                 ml_meth=ptr(dec_conjugate),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("conjugate($self, /)\n--\n\nReturn self.\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("radix"),
                 ml_meth=ptr(dec_mpd_radix),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "radix($self, /)\n--\n\nReturn Decimal(10), the radix (base) in which the Decimal class does\nall its arithmetic. Included for compatibility with the specification.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_abs"),
                 ml_meth=ptr(dec_mpd_qcopy_abs),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy_abs($self, /)\n--\n\nReturn the absolute value of the argument.  This operation is unaffected by\ncontext and is quiet: no flags are changed and no rounding is performed.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_negate"),
                 ml_meth=ptr(dec_mpd_qcopy_negate),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy_negate($self, /)\n--\n\nReturn the negation of the argument.  This operation is unaffected by context\nand is quiet: no flags are changed and no rounding is performed.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logb"),
                 ml_meth=ptr(dec_mpd_qlogb),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "logb($self, /, context=None)\n--\n\nFor a non-zero number, return the adjusted exponent of the operand as a\nDecimal instance.  If the operand is a zero, then Decimal('-Infinity') is\nreturned and the DivisionByZero condition is raised. If the operand is\nan infinity then Decimal('Infinity') is returned.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_invert"),
                 ml_meth=ptr(dec_mpd_qinvert),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "logical_invert($self, /, context=None)\n--\n\nInvert all its digits.\n\nThe self must be logical number.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("number_class"),
                 ml_meth=ptr(dec_mpd_class),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "number_class($self, /, context=None)\n--\n\nReturn a string describing the class of the operand.  The returned value\nis one of the following ten strings:\n\n    * '-Infinity', indicating that the operand is negative infinity.\n    * '-Normal', indicating that the operand is a negative normal number.\n    * '-Subnormal', indicating that the operand is negative and subnormal.\n    * '-Zero', indicating that the operand is a negative zero.\n    * '+Zero', indicating that the operand is a positive zero.\n    * '+Subnormal', indicating that the operand is positive and subnormal.\n    * '+Normal', indicating that the operand is a positive normal number.\n    * '+Infinity', indicating that the operand is positive infinity.\n    * 'NaN', indicating that the operand is a quiet NaN (Not a Number).\n    * 'sNaN', indicating that the operand is a signaling NaN.\n\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_eng_string"),
                 ml_meth=ptr(dec_mpd_to_eng),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "to_eng_string($self, /, context=None)\n--\n\nConvert to an engineering-type string.  Engineering notation has an exponent\nwhich is a multiple of 3, so there are up to 3 digits left of the decimal\nplace. For example, Decimal('123E+1') is converted to Decimal('1.23E+3').\n\nThe value of context.capitals determines whether the exponent sign is lower\nor upper case. Otherwise, the context does not affect the operation.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_total"),
                 ml_meth=ptr(dec_mpd_compare_total),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "compare_total($self, /, other, context=None)\n--\n\nCompare two operands using their abstract representation rather than\ntheir numerical value.  Similar to the compare() method, but the result\ngives a total ordering on Decimal instances.  Two Decimal instances with\nthe same numeric value but different representations compare unequal\nin this ordering:\n\n    >>> Decimal('12.0').compare_total(Decimal('12'))\n    Decimal('-1')\n\nQuiet and signaling NaNs are also included in the total ordering. The result\nof this function is Decimal('0') if both operands have the same representation,\nDecimal('-1') if the first operand is lower in the total order than the second,\nand Decimal('1') if the first operand is higher in the total order than the\nsecond operand. See the specification for details of the total order.\n\nThis operation is unaffected by context and is quiet: no flags are changed\nand no rounding is performed. As an exception, the C version may raise\nInvalidOperation if the second operand cannot be converted exactly.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_total_mag"),
                 ml_meth=ptr(dec_mpd_compare_total_mag),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "compare_total_mag($self, /, other, context=None)\n--\n\nCompare two operands using their abstract representation rather than their\nvalue as in compare_total(), but ignoring the sign of each operand.\n\nx.compare_total_mag(y) is equivalent to x.copy_abs().compare_total(y.copy_abs()).\n\nThis operation is unaffected by context and is quiet: no flags are changed\nand no rounding is performed. As an exception, the C version may raise\nInvalidOperation if the second operand cannot be converted exactly.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_sign"),
                 ml_meth=ptr(dec_mpd_qcopy_sign),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "copy_sign($self, /, other, context=None)\n--\n\nReturn a copy of the first operand with the sign set to be the same as the\nsign of the second operand. For example:\n\n    >>> Decimal('2.3').copy_sign(Decimal('-1.5'))\n    Decimal('-2.3')\n\nThis operation is unaffected by context and is quiet: no flags are changed\nand no rounding is performed. As an exception, the C version may raise\nInvalidOperation if the second operand cannot be converted exactly.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("same_quantum"),
                 ml_meth=ptr(dec_mpd_same_quantum),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "same_quantum($self, /, other, context=None)\n--\n\nTest whether self and other have the same exponent or whether both are NaN.\n\nThis operation is unaffected by context and is quiet: no flags are changed\nand no rounding is performed. As an exception, the C version may raise\nInvalidOperation if the second operand cannot be converted exactly.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_and"),
                 ml_meth=ptr(dec_mpd_qand),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "logical_and($self, /, other, context=None)\n--\n\nApplies an 'and' operation between self and other's digits.\n\nBoth self and other must be logical numbers.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_or"),
                 ml_meth=ptr(dec_mpd_qor),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "logical_or($self, /, other, context=None)\n--\n\nApplies an 'or' operation between self and other's digits.\n\nBoth self and other must be logical numbers. \n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_xor"),
                 ml_meth=ptr(dec_mpd_qxor),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "logical_xor($self, /, other, context=None)\n--\n\nApplies an 'xor' operation between self and other's digits.\n\nBoth self and other must be logical numbers.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rotate"),
                 ml_meth=ptr(dec_mpd_qrotate),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "rotate($self, /, other, context=None)\n--\n\nReturn the result of rotating the digits of the first operand by an amount\nspecified by the second operand.  The second operand must be an integer in\nthe range -precision through precision. The absolute value of the second\noperand gives the number of places to rotate. If the second operand is\npositive then rotation is to the left; otherwise rotation is to the right.\nThe coefficient of the first operand is padded on the left with zeros to\nlength precision if necessary. The sign and exponent of the first operand are\nunchanged.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("scaleb"),
                 ml_meth=ptr(dec_mpd_qscaleb),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "scaleb($self, /, other, context=None)\n--\n\nReturn the first operand with the exponent adjusted the second.  Equivalently,\nreturn the first operand multiplied by 10**other. The second operand must be\nan integer.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("shift"),
                 ml_meth=ptr(dec_mpd_qshift),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "shift($self, /, other, context=None)\n--\n\nReturn the result of shifting the digits of the first operand by an amount\nspecified by the second operand.  The second operand must be an integer in\nthe range -precision through precision. The absolute value of the second\noperand gives the number of places to shift. If the second operand is\npositive, then the shift is to the left; otherwise the shift is to the\nright. Digits shifted into the coefficient are zeros. The sign and exponent\nof the first operand are unchanged.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("from_float"),
                 ml_meth=ptr(dec_from_float),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "from_float($type, f, /)\n--\n\nClass method that converts a float to a decimal number, exactly.\nSince 0.1 is not exactly representable in binary floating point,\nDecimal.from_float(0.1) is not the same as Decimal('0.1').\n\n    >>> Decimal.from_float(0.1)\n    Decimal('0.1000000000000000055511151231257827021181583404541015625')\n    >>> Decimal.from_float(float('nan'))\n    Decimal('NaN')\n    >>> Decimal.from_float(float('inf'))\n    Decimal('Infinity')\n    >>> Decimal.from_float(float('-inf'))\n    Decimal('-Infinity')\n\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("from_number"),
                 ml_meth=ptr(dec_from_number),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "from_number($type, number, /)\n--\n\nClass method that converts a real number to a decimal number, exactly.\n\n    >>> Decimal.from_number(314)              # int\n    Decimal('314')\n    >>> Decimal.from_number(0.1)              # float\n    Decimal('0.1000000000000000055511151231257827021181583404541015625')\n    >>> Decimal.from_number(Decimal('3.14'))  # another decimal instance\n    Decimal('3.14')\n\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("as_tuple"),
                 ml_meth=ptr(dec_as_tuple),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "as_tuple($self, /)\n--\n\nReturn a tuple representation of the number.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("as_integer_ratio"),
                 ml_meth=ptr(dec_as_integer_ratio),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "as_integer_ratio($self, /)\n--\n\nDecimal.as_integer_ratio() -> (int, int)\n\nReturn a pair of integers, whose ratio is exactly equal to the original\nDecimal and with a positive denominator. The ratio is in lowest terms.\nRaise OverflowError on infinities and a ValueError on NaNs.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__copy__"),
                 ml_meth=ptr(dec_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__deepcopy__"),
                 ml_meth=ptr(dec_copy),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__format__"),
                 ml_meth=ptr(dec_format),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(dec_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__round__"),
                 ml_meth=ptr(dec_round),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__ceil__"),
                 ml_meth=ptr(dec_ceil),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__floor__"),
                 ml_meth=ptr(dec_floor),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__trunc__"),
                 ml_meth=ptr(dec_trunc),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__complex__"),
                 ml_meth=ptr(dec_complex),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__sizeof__"),
                 ml_meth=ptr(dec_sizeof),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         dec_getsets: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("real"), get=dec_real),
             PyGetSetDef(name=ptr[u8]("imag"), get=dec_imag),
             PyGetSetDef()
         ],
         dec_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(dec_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(dec_traverse)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(dec_repr)),
             PyType_Slot(slot=Py_tp_hash, pfunc=ptr(dec_hash)),
             PyType_Slot(slot=Py_tp_str, pfunc=ptr(dec_str)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Decimal(value=\"0\", context=None)\n--\n\nConstruct a new Decimal object. 'value' can be an integer, string, tuple,\nor another Decimal object. If no value is given, return Decimal('0'). The\ncontext does not affect the conversion and is only passed to determine if\nthe InvalidOperation trap is active.\n\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(dec_richcompare)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(dec_methods))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(dec_getsets))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(dec_new)),
             PyType_Slot(slot=Py_nb_add, pfunc=ptr(nm_mpd_qadd)),
             PyType_Slot(slot=Py_nb_subtract, pfunc=ptr(nm_mpd_qsub)),
             PyType_Slot(slot=Py_nb_multiply, pfunc=ptr(nm_mpd_qmul)),
             PyType_Slot(slot=Py_nb_remainder, pfunc=ptr(nm_mpd_qrem)),
             PyType_Slot(slot=Py_nb_divmod, pfunc=ptr(nm_mpd_qdivmod)),
             PyType_Slot(slot=Py_nb_power, pfunc=ptr(nm_mpd_qpow)),
             PyType_Slot(slot=Py_nb_negative, pfunc=ptr(nm_mpd_qminus)),
             PyType_Slot(slot=Py_nb_positive, pfunc=ptr(nm_mpd_qplus)),
             PyType_Slot(slot=Py_nb_absolute, pfunc=ptr(nm_mpd_qabs)),
             PyType_Slot(slot=Py_nb_bool, pfunc=ptr(nm_nonzero)),
             PyType_Slot(slot=Py_nb_int, pfunc=ptr(nm_dec_as_long)),
             PyType_Slot(slot=Py_nb_float, pfunc=ptr(dec_as_float)),
             PyType_Slot(slot=Py_nb_floor_divide, pfunc=ptr(nm_mpd_qdivint)),
             PyType_Slot(slot=Py_nb_true_divide, pfunc=ptr(nm_mpd_qdiv)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob dec_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("decimal.Decimal"),
             basicsize=i32(DEC_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(dec_slots)
         ); glob:priv context_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("abs"),
                 ml_meth=ptr(ctx_mpd_qabs),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "abs($self, x, /)\n--\n\nReturn the absolute value of x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("exp"),
                 ml_meth=ptr(ctx_mpd_qexp),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("exp($self, x, /)\n--\n\nReturn e ** x.\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ln"),
                 ml_meth=ptr(ctx_mpd_qln),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "ln($self, x, /)\n--\n\nReturn the natural (base e) logarithm of x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("log10"),
                 ml_meth=ptr(ctx_mpd_qlog10),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "log10($self, x, /)\n--\n\nReturn the base 10 logarithm of x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("minus"),
                 ml_meth=ptr(ctx_mpd_qminus),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "minus($self, x, /)\n--\n\nMinus corresponds to the unary prefix minus operator in Python, but applies\nthe context to the result.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_minus"),
                 ml_meth=ptr(ctx_mpd_qnext_minus),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "next_minus($self, x, /)\n--\n\nReturn the largest representable number smaller than x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_plus"),
                 ml_meth=ptr(ctx_mpd_qnext_plus),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "next_plus($self, x, /)\n--\n\nReturn the smallest representable number larger than x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("normalize"),
                 ml_meth=ptr(ctx_mpd_qreduce),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "normalize($self, x, /)\n--\n\nReduce x to its simplest form. Alias for reduce(x).\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("plus"),
                 ml_meth=ptr(ctx_mpd_qplus),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "plus($self, x, /)\n--\n\nPlus corresponds to the unary prefix plus operator in Python, but applies\nthe context to the result.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral"),
                 ml_meth=ptr(ctx_mpd_qround_to_int),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "to_integral($self, x, /)\n--\n\nIdentical to to_integral_value(x).\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral_exact"),
                 ml_meth=ptr(ctx_mpd_qround_to_intx),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "to_integral_exact($self, x, /)\n--\n\nRound to an integer. Signal if the result is rounded or inexact.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_integral_value"),
                 ml_meth=ptr(ctx_mpd_qround_to_int),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "to_integral_value($self, x, /)\n--\n\nRound to an integer.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("sqrt"),
                 ml_meth=ptr(ctx_mpd_qsqrt),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "sqrt($self, x, /)\n--\n\nSquare root of a non-negative number to context precision.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("add"),
                 ml_meth=ptr(ctx_mpd_qadd),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "add($self, x, y, /)\n--\n\nReturn the sum of x and y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare"),
                 ml_meth=ptr(ctx_mpd_qcompare),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "compare($self, x, y, /)\n--\n\nCompare x and y numerically.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_signal"),
                 ml_meth=ptr(ctx_mpd_qcompare_signal),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "compare_signal($self, x, y, /)\n--\n\nCompare x and y numerically.  All NaNs signal.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("divide"),
                 ml_meth=ptr(ctx_mpd_qdiv),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "divide($self, x, y, /)\n--\n\nReturn x divided by y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("divide_int"),
                 ml_meth=ptr(ctx_mpd_qdivint),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "divide_int($self, x, y, /)\n--\n\nReturn x divided by y, truncated to an integer.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("divmod"),
                 ml_meth=ptr(ctx_mpd_qdivmod),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "divmod($self, x, y, /)\n--\n\nReturn quotient and remainder of the division x / y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("max"),
                 ml_meth=ptr(ctx_mpd_qmax),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "max($self, x, y, /)\n--\n\nCompare the values numerically and return the maximum.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("max_mag"),
                 ml_meth=ptr(ctx_mpd_qmax_mag),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "max_mag($self, x, y, /)\n--\n\nCompare the values numerically with their sign ignored.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("min"),
                 ml_meth=ptr(ctx_mpd_qmin),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "min($self, x, y, /)\n--\n\nCompare the values numerically and return the minimum.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("min_mag"),
                 ml_meth=ptr(ctx_mpd_qmin_mag),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "min_mag($self, x, y, /)\n--\n\nCompare the values numerically with their sign ignored.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("multiply"),
                 ml_meth=ptr(ctx_mpd_qmul),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "multiply($self, x, y, /)\n--\n\nReturn the product of x and y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("next_toward"),
                 ml_meth=ptr(ctx_mpd_qnext_toward),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "next_toward($self, x, y, /)\n--\n\nReturn the number closest to x, in the direction towards y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("quantize"),
                 ml_meth=ptr(ctx_mpd_qquantize),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "quantize($self, x, y, /)\n--\n\nReturn a value equal to x (rounded), having the exponent of y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("remainder"),
                 ml_meth=ptr(ctx_mpd_qrem),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "remainder($self, x, y, /)\n--\n\nReturn the remainder from integer division.  The sign of the result,\nif non-zero, is the same as that of the original dividend.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("remainder_near"),
                 ml_meth=ptr(ctx_mpd_qrem_near),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "remainder_near($self, x, y, /)\n--\n\nReturn x - y * n, where n is the integer nearest the exact value of x / y\n(if the result is 0 then its sign will be the sign of x).\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("subtract"),
                 ml_meth=ptr(ctx_mpd_qsub),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "subtract($self, x, y, /)\n--\n\nReturn the difference between x and y.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("power"),
                 ml_meth=ptr(ctx_mpd_qpow),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "power($self, /, a, b, modulo=None)\n--\n\nCompute a**b. If 'a' is negative, then 'b' must be integral. The result\nwill be inexact unless 'a' is integral and the result is finite and can\nbe expressed exactly in 'precision' digits.  In the Python version the\nresult is always correctly rounded, in the C version the result is almost\nalways correctly rounded.\n\nIf modulo is given, compute (a**b) % modulo. The following restrictions\nhold:\n\n    * all three arguments must be integral\n    * 'b' must be nonnegative\n    * at least one of 'a' or 'b' must be nonzero\n    * modulo must be nonzero and less than 10**prec in absolute value\n\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fma"),
                 ml_meth=ptr(ctx_mpd_qfma),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "fma($self, x, y, z, /)\n--\n\nReturn x multiplied by y, plus z.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("Etiny"),
                 ml_meth=ptr(context_getetiny),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Etiny($self, /)\n--\n\nReturn a value equal to Emin - prec + 1, which is the minimum exponent value\nfor subnormal results.  When underflow occurs, the exponent is set to Etiny.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("Etop"),
                 ml_meth=ptr(context_getetop),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Etop($self, /)\n--\n\nReturn a value equal to Emax - prec + 1.  This is the maximum exponent\nif the _clamp field of the context is set to 1 (IEEE clamp mode).  Etop()\nmust not be negative.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("radix"),
                 ml_meth=ptr(ctx_mpd_radix),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("radix($self, /)\n--\n\nReturn 10.\n\n")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_canonical"),
                 ml_meth=ptr(ctx_iscanonical),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_canonical($self, x, /)\n--\n\nReturn True if x is canonical, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_finite"),
                 ml_meth=ptr(ctx_mpd_isfinite),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_finite($self, x, /)\n--\n\nReturn True if x is finite, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_infinite"),
                 ml_meth=ptr(ctx_mpd_isinfinite),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_infinite($self, x, /)\n--\n\nReturn True if x is infinite, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_nan"),
                 ml_meth=ptr(ctx_mpd_isnan),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_nan($self, x, /)\n--\n\nReturn True if x is a qNaN or sNaN, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_normal"),
                 ml_meth=ptr(ctx_mpd_isnormal),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_normal($self, x, /)\n--\n\nReturn True if x is a normal number, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_qnan"),
                 ml_meth=ptr(ctx_mpd_isqnan),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_qnan($self, x, /)\n--\n\nReturn True if x is a quiet NaN, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_signed"),
                 ml_meth=ptr(ctx_mpd_issigned),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_signed($self, x, /)\n--\n\nReturn True if x is negative, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_snan"),
                 ml_meth=ptr(ctx_mpd_issnan),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_snan($self, x, /)\n--\n\nReturn True if x is a signaling NaN, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_subnormal"),
                 ml_meth=ptr(ctx_mpd_issubnormal),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_subnormal($self, x, /)\n--\n\nReturn True if x is subnormal, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("is_zero"),
                 ml_meth=ptr(ctx_mpd_iszero),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "is_zero($self, x, /)\n--\n\nReturn True if x is a zero, False otherwise.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_apply"),
                 ml_meth=ptr(ctx_apply),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("canonical"),
                 ml_meth=ptr(ctx_canonical),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "canonical($self, x, /)\n--\n\nReturn a new instance of x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_abs"),
                 ml_meth=ptr(ctx_mpd_qcopy_abs),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "copy_abs($self, x, /)\n--\n\nReturn a copy of x with the sign set to 0.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_decimal"),
                 ml_meth=ptr(ctx_copy_decimal),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "copy_decimal($self, x, /)\n--\n\nReturn a copy of Decimal x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_negate"),
                 ml_meth=ptr(ctx_mpd_qcopy_negate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "copy_negate($self, x, /)\n--\n\nReturn a copy of x with the sign inverted.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logb"),
                 ml_meth=ptr(ctx_mpd_qlogb),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "logb($self, x, /)\n--\n\nReturn the exponent of the magnitude of the operand's MSD.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_invert"),
                 ml_meth=ptr(ctx_mpd_qinvert),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "logical_invert($self, x, /)\n--\n\nInvert all the digits in the operand.\n\nThe operand must be a logical number.\n\n    >>> ExtendedContext.logical_invert(Decimal('0'))\n    Decimal('111111111')\n    >>> ExtendedContext.logical_invert(Decimal('1'))\n    Decimal('111111110')\n    >>> ExtendedContext.logical_invert(Decimal('111111111'))\n    Decimal('0')\n    >>> ExtendedContext.logical_invert(Decimal('101010101'))\n    Decimal('10101010')\n    >>> ExtendedContext.logical_invert(1101)\n    Decimal('111110010')\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("number_class"),
                 ml_meth=ptr(ctx_mpd_class),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "number_class($self, x, /)\n--\n\nReturn an indication of the class of x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_sci_string"),
                 ml_meth=ptr(ctx_mpd_to_sci),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "to_sci_string($self, x, /)\n--\n\nConvert a number to a string using scientific notation.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("to_eng_string"),
                 ml_meth=ptr(ctx_mpd_to_eng),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "to_eng_string($self, x, /)\n--\n\nConvert a number to a string, using engineering notation.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_total"),
                 ml_meth=ptr(ctx_mpd_compare_total),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "compare_total($self, x, y, /)\n--\n\nCompare x and y using their abstract representation.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("compare_total_mag"),
                 ml_meth=ptr(ctx_mpd_compare_total_mag),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "compare_total_mag($self, x, y, /)\n--\n\nCompare x and y using their abstract representation, ignoring sign.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy_sign"),
                 ml_meth=ptr(ctx_mpd_qcopy_sign),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "copy_sign($self, x, y, /)\n--\n\nCopy the sign from y to x.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_and"),
                 ml_meth=ptr(ctx_mpd_qand),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "logical_and($self, x, y, /)\n--\n\nApplies the logical operation 'and' between each operand's digits.\n\nThe operands must be both logical numbers.\n\n    >>> ExtendedContext.logical_and(Decimal('0'), Decimal('0'))\n    Decimal('0')\n    >>> ExtendedContext.logical_and(Decimal('0'), Decimal('1'))\n    Decimal('0')\n    >>> ExtendedContext.logical_and(Decimal('1'), Decimal('0'))\n    Decimal('0')\n    >>> ExtendedContext.logical_and(Decimal('1'), Decimal('1'))\n    Decimal('1')\n    >>> ExtendedContext.logical_and(Decimal('1100'), Decimal('1010'))\n    Decimal('1000')\n    >>> ExtendedContext.logical_and(Decimal('1111'), Decimal('10'))\n    Decimal('10')\n    >>> ExtendedContext.logical_and(110, 1101)\n    Decimal('100')\n    >>> ExtendedContext.logical_and(Decimal(110), 1101)\n    Decimal('100')\n    >>> ExtendedContext.logical_and(110, Decimal(1101))\n    Decimal('100')\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_or"),
                 ml_meth=ptr(ctx_mpd_qor),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "logical_or($self, x, y, /)\n--\n\nApplies the logical operation 'or' between each operand's digits.\n\nThe operands must be both logical numbers.\n\n    >>> ExtendedContext.logical_or(Decimal('0'), Decimal('0'))\n    Decimal('0')\n    >>> ExtendedContext.logical_or(Decimal('0'), Decimal('1'))\n    Decimal('1')\n    >>> ExtendedContext.logical_or(Decimal('1'), Decimal('0'))\n    Decimal('1')\n    >>> ExtendedContext.logical_or(Decimal('1'), Decimal('1'))\n    Decimal('1')\n    >>> ExtendedContext.logical_or(Decimal('1100'), Decimal('1010'))\n    Decimal('1110')\n    >>> ExtendedContext.logical_or(Decimal('1110'), Decimal('10'))\n    Decimal('1110')\n    >>> ExtendedContext.logical_or(110, 1101)\n    Decimal('1111')\n    >>> ExtendedContext.logical_or(Decimal(110), 1101)\n    Decimal('1111')\n    >>> ExtendedContext.logical_or(110, Decimal(1101))\n    Decimal('1111')\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("logical_xor"),
                 ml_meth=ptr(ctx_mpd_qxor),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "logical_xor($self, x, y, /)\n--\n\nApplies the logical operation 'xor' between each operand's digits.\n\nThe operands must be both logical numbers.\n\n    >>> ExtendedContext.logical_xor(Decimal('0'), Decimal('0'))\n    Decimal('0')\n    >>> ExtendedContext.logical_xor(Decimal('0'), Decimal('1'))\n    Decimal('1')\n    >>> ExtendedContext.logical_xor(Decimal('1'), Decimal('0'))\n    Decimal('1')\n    >>> ExtendedContext.logical_xor(Decimal('1'), Decimal('1'))\n    Decimal('0')\n    >>> ExtendedContext.logical_xor(Decimal('1100'), Decimal('1010'))\n    Decimal('110')\n    >>> ExtendedContext.logical_xor(Decimal('1111'), Decimal('10'))\n    Decimal('1101')\n    >>> ExtendedContext.logical_xor(110, 1101)\n    Decimal('1011')\n    >>> ExtendedContext.logical_xor(Decimal(110), 1101)\n    Decimal('1011')\n    >>> ExtendedContext.logical_xor(110, Decimal(1101))\n    Decimal('1011')\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rotate"),
                 ml_meth=ptr(ctx_mpd_qrotate),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "rotate($self, x, y, /)\n--\n\nReturn a copy of x, rotated by y places.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("same_quantum"),
                 ml_meth=ptr(ctx_mpd_same_quantum),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "same_quantum($self, x, y, /)\n--\n\nReturn True if the two operands have the same exponent.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("scaleb"),
                 ml_meth=ptr(ctx_mpd_qscaleb),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "scaleb($self, x, y, /)\n--\n\nReturn the first operand after adding the second value to its exp.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("shift"),
                 ml_meth=ptr(ctx_mpd_qshift),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "shift($self, x, y, /)\n--\n\nReturn a copy of x, shifted by y places.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear_flags"),
                 ml_meth=ptr(context_clear_flags),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "clear_flags($self, /)\n--\n\nReset all flags to False.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("clear_traps"),
                 ml_meth=ptr(context_clear_traps),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "clear_traps($self, /)\n--\n\nSet all traps to False.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__copy__"),
                 ml_meth=ptr(context_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(context_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(context_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "copy($self, /)\n--\n\nReturn a duplicate of the context with all flags cleared.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("create_decimal"),
                 ml_meth=ptr(ctx_create_decimal),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8](
                     "create_decimal($self, num=\"0\", /)\n--\n\nCreate a new Decimal instance from num, using self as the context. Unlike the\nDecimal constructor, this function observes the context limits.\n\n"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("create_decimal_from_float"),
                 ml_meth=ptr(ctx_from_float),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "create_decimal_from_float($self, f, /)\n--\n\nCreate a new Decimal instance from float f.  Unlike the Decimal.from_float()\nclass method, this function observes the context limits.\n\n"
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         context_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("prec"), get=context_getprec, set=context_setprec
             ),
             PyGetSetDef(
                 name=ptr[u8]("Emax"), get=context_getemax, set=context_setemax
             ),
             PyGetSetDef(
                 name=ptr[u8]("Emin"), get=context_getemin, set=context_setemin
             ),
             PyGetSetDef(
                 name=ptr[u8]("rounding"), get=context_getround, set=context_setround
             ),
             PyGetSetDef(
                 name=ptr[u8]("capitals"),
                 get=context_getcapitals,
                 set=context_setcapitals
             ),
             PyGetSetDef(
                 name=ptr[u8]("clamp"), get=context_getclamp, set=context_setclamp
             ),
             PyGetSetDef()
         ],
         context_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(context_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(context_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(context_clear)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(context_repr)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(context_getattr)),
             PyType_Slot(slot=Py_tp_setattro, pfunc=ptr(context_setattr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "Context(prec=None, rounding=None, Emin=None, Emax=None, capitals=None, clamp=None, flags=None, traps=None)\n--\n\nThe context affects almost all operations and controls rounding,\nOver/Underflow, raising of exceptions and much more.  A new context\ncan be constructed as follows:\n\n    >>> c = Context(prec=28, Emin=-425000000, Emax=425000000,\n    ...             rounding=ROUND_HALF_EVEN, capitals=1, clamp=1,\n    ...             traps=[InvalidOperation, DivisionByZero, Overflow],\n    ...             flags=[])\n    >>>\n\n\n"
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(context_methods))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(context_getsets))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(context_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(context_new)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob context_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("decimal.Context"),
             basicsize=i32(CONTEXT_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(context_slots)
         ); glob:priv signaldict_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("copy"),
                 ml_meth=ptr(signaldict_copy),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         signaldict_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(signaldict_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(signaldict_traverse)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(signaldict_repr)),
             PyType_Slot(slot=Py_tp_hash, pfunc=ptr(PyObject_HashNotImplemented)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(signaldict_richcompare)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(signaldict_iter)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(signaldict_methods))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(signaldict_init)),
             PyType_Slot(slot=Py_mp_length, pfunc=ptr(signaldict_len)),
             PyType_Slot(slot=Py_mp_subscript, pfunc=ptr(signaldict_getitem)),
             PyType_Slot(slot=Py_mp_ass_subscript, pfunc=ptr(signaldict_setitem)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         signaldict_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("decimal.SignalDictMixin"),
             basicsize=i32(SIGNAL_DICT_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(signaldict_slots)
         ),
         ctxmanager_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__enter__"),
                 ml_meth=ptr(ctxmanager_set_local),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__exit__"),
                 ml_meth=ptr(ctxmanager_restore_global),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         ctxmanager_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(ctxmanager_dealloc)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(ctxmanager_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(ctxmanager_clear)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr(addressof(ctxmanager_methods))),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         ctxmanager_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("decimal.ContextManager"),
             basicsize=i32(CONTEXT_MANAGER_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(ctxmanager_slots)
         ),
         # libmpdec's allocator and trap handler hooks: Python's allocator,
         # libmpdec's own calloc on top of it, and a trap handler that does
         # nothing (the module raises from the status instead).
         mpd_hooks: list[ptr] = [
             ptr(PyMem_Malloc),
             ptr(PyMem_Realloc),
             ptr(mpd_callocfunc_em),
             ptr(PyMem_Free),
             ptr(dec_traphandler)
         ];
}

"""The trap handler libmpdec calls on a trapped condition: nothing, since the
module raises the exception from the status."""
def dec_traphandler(ctx: ptr[mpd_context_t]) {
    return;
}

# ---------------------------------------------------------------------------
# Module initialization.

import from c {
    # libmpdec keeps its minimum allocation process-wide; it is set once.
    glob:priv minalloc_is_set: i32 = 0;
}

"""cfunc_noargs: the METH_NOARGS C function of method `name` in `type`'s
method table, as an address; 0 with RuntimeError when there is none."""
def:priv cfunc_noargs(type: ptr[PyTypeObject], name: str) -> int {
    methods = type.view(1)[0].tp_methods;
    if methods {
        index = 0;
        while True {
            method = (methods + index).view(1)[0];
            if not method.ml_name {
                break;
            }
            if c_string_equals(method.ml_name, name) {
                if (method.ml_flags & METH_NOARGS) == 0 {
                    break;
                }
                return int(method.ml_meth);
            }
            index += 1;
        }
    }
    PyErr_Format(PyExc_RuntimeError, "internal error: could not find method %s", name);
    return 0;
}

"""Whether the NUL-terminated C string at `text` is `name`."""
def:priv c_string_equals(text: ptr[u8], name: str) -> bool {
    encoded = name.encode("utf-8");
    for i in range(len(encoded)) {
        if int((text + i).view(1)[0]) != encoded[i] {
            return False;
        }
    }
    return (text + len(encoded)).view(1)[0] == u8(0);
}

"""Install libmpdec's hooks and the process-wide constants the module uses."""
def:priv init_libmpdec -> bool {
    hooks = ptr[ptr](addressof(mpd_hooks)).view(5);
    mpd_mallocfunc = hooks[0];
    mpd_reallocfunc = hooks[1];
    mpd_callocfunc = hooks[2];
    mpd_free = hooks[3];
    mpd_traphandler = hooks[4];
    # Suppress the warning caused by multi-phase initialization
    if minalloc_is_set == 0 {
        mpd_setminalloc(i64(PY_DEC_MINALLOC));
        minalloc_is_set = 1;
    }
    mpd_maxcontext(addressof(max_context));
    mpd_maxcontext(addressof(hash_context));
    work = addressof(hash_context).view(1);
    work[0].prec = MPD_MAX_PREC + 21;
    work[0].emax = MPD_MAX_EMAX + 21;
    work[0].emin = MPD_MIN_EMIN - 21;
    float_ratio = cfunc_noargs(addressof(PyFloat_Type), "as_integer_ratio");
    if float_ratio == 0 {
        return False;
    }
    bit_length = cfunc_noargs(addressof(PyLong_Type), "bit_length");
    if bit_length == 0 {
        return False;
    }
    methods = addressof(builtin_methods).view(1);
    methods[0].float_as_integer_ratio = float_ratio;
    methods[0].long_bit_length = bit_length;
    return True;
}

"""Store a new reference (consumed) in state slot `index`."""
def:priv set_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

def:priv state(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

"""PyType_FromMetaclass(NULL, module, spec, NULL) into state slot `index`."""
def:priv create_type(
    module: ptr[PyObject], index: int, spec: ptr[PyType_Spec]
) -> bool {
    return set_state(module, index, PyType_FromMetaclass(NULL, module, spec, NULL));
}

"""type.__module__ = "decimal"."""
def:priv set_module_name(type: ptr[PyObject]) -> bool {
    name = PyUnicode_FromString("decimal");
    if not name {
        return False;
    }
    status = PyDict_SetItemString(PyType_GetDict(type), "__module__", name);
    jacpy_release(name);
    return status >= 0;
}

"""Decimal is a numbers.Number; numbers.Rational is kept for comparisons."""
def:priv register_numbers(module: ptr[PyObject]) -> bool {
    numbers = PyImport_ImportModule("numbers");
    if not numbers {
        return False;
    }
    number = PyObject_GetAttrString(numbers, "Number");
    ok = bool(number);
    if ok {
        registered = PyObject_CallMethod(
            number, "register", "(O)", state(module, STATE_DEC_TYPE)
        );
        ok = bool(registered);
        jacpy_release(registered);
        jacpy_release(number);
    }
    ok = ok
        and set_state(
            module, STATE_RATIONAL, PyObject_GetAttrString(numbers, "Rational")
        );
    jacpy_release(numbers);
    return ok;
}

"""DecimalTuple = collections.namedtuple("DecimalTuple", "sign digits
exponent"), in module decimal."""
def:priv create_decimal_tuple(module: ptr[PyObject]) -> bool {
    collections = PyImport_ImportModule("collections");
    if not collections {
        return False;
    }
    tuple_type = PyObject_CallMethod(
        collections, "namedtuple", "(ss)", "DecimalTuple", "sign digits exponent"
    );
    jacpy_release(collections);
    if not tuple_type {
        return False;
    }
    if jacpy_is_type(tuple_type) == 0 {
        jacpy_release(tuple_type);
        PyErr_SetString(PyExc_TypeError, "type is expected from namedtuple call");
        return False;
    }
    return set_state(module, STATE_DECIMAL_TUPLE, tuple_type)
        and set_module_name(state(module, STATE_DECIMAL_TUPLE));
}

"""SignalDict = type("SignalDict", (SignalDictMixin, MutableMapping), {})."""
def:priv create_signal_dict(module: ptr[PyObject]) -> bool {
    collections_abc = PyImport_ImportModule("collections.abc");
    if not collections_abc {
        return False;
    }
    mutable_mapping = PyObject_GetAttrString(collections_abc, "MutableMapping");
    jacpy_release(collections_abc);
    if not mutable_mapping {
        return False;
    }
    signal_dict = PyObject_CallFunction(
        ptr[PyObject](addressof(PyType_Type)),
        "s(OO){}",
        "SignalDict",
        state(module, STATE_SIGNAL_DICT_MIXIN_TYPE),
        mutable_mapping
    );
    jacpy_release(mutable_mapping);
    return set_state(module, STATE_SIGNAL_DICT_TYPE, signal_dict);
}

"""The bases of the exception of signal `index`."""
def:priv signal_bases(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    flag = SIGNAL_FLAGS[index];
    decimal_exception = state(module, STATE_DECIMAL_EXCEPTION);
    if flag == MPD_Float_operation {
        return PyTuple_Pack(2, decimal_exception, PyExc_TypeError);
    }
    if flag == MPD_Division_by_zero {
        return PyTuple_Pack(2, decimal_exception, PyExc_ZeroDivisionError);
    }
    if flag == MPD_Overflow {
        return PyTuple_Pack(
            2, signal_exception(module, INEXACT), signal_exception(module, ROUNDED)
        );
    }
    if flag == MPD_Underflow {
        return PyTuple_Pack(
            3,
            signal_exception(module, INEXACT),
            signal_exception(module, ROUNDED),
            signal_exception(module, SUBNORMAL)
        );
    }
    return PyTuple_Pack(1, decimal_exception);
}

"""The exception hierarchy: DecimalException, the signals (created last to
first, since Overflow and Underflow derive from later ones) and the
conditions that derive from InvalidOperation."""
def:priv create_exceptions(module: ptr[PyObject]) -> bool {
    if not set_state(
        module,
        STATE_DECIMAL_EXCEPTION,
        PyErr_NewException("decimal.DecimalException", PyExc_ArithmeticError, NULL)
    )
        or PyModule_AddType(module, state(module, STATE_DECIMAL_EXCEPTION)) < 0 {
        return False;
    }
    signal_tuple = PyTuple_New(i64(SIGNAL_MAP_LEN));
    if not set_state(module, STATE_SIGNAL_TUPLE, signal_tuple) {
        return False;
    }
    signal_tuple = state(module, STATE_SIGNAL_TUPLE);
    index = SIGNAL_MAP_LEN - 1;
    while index >= 0 {
        base = signal_bases(module, index);
        if not base {
            return False;
        }
        ex = PyErr_NewException("decimal." + SIGNAL_NAMES[index], base, NULL);
        jacpy_release(base);
        if not set_state(module, STATE_SIGNAL_EXCEPTIONS + index, ex) {
            return False;
        }
        ex = state(module, STATE_SIGNAL_EXCEPTIONS + index);
        if PyModule_AddObjectRef(module, SIGNAL_NAMES[index], ex) < 0 {
            return False;
        }
        PyTuple_SetItem(signal_tuple, i64(index), Py_NewRef(ex));
        index -= 1;
    }
    # InvalidOperation is a signal that comprises several conditions,
    # including InvalidOperation; the other conditions inherit from it.
    invalid_operation = signal_exception(module, 0);
    for index in range(1, len(CONDITION_NAMES)) {
        base: ptr[PyObject] = NULL;
        if CONDITION_FLAGS[index] == MPD_Division_undefined {
            base = PyTuple_Pack(2, invalid_operation, PyExc_ZeroDivisionError);
        } else {
            base = PyTuple_Pack(1, invalid_operation);
        }
        if not base {
            return False;
        }
        ex = PyErr_NewException("decimal." + CONDITION_NAMES[index], base, NULL);
        jacpy_release(base);
        if not set_state(module, STATE_CONDITION_EXCEPTIONS + index - 1, ex)
            or PyModule_AddObjectRef(
                module,
                CONDITION_NAMES[index],
                state(module, STATE_CONDITION_EXCEPTIONS + index - 1)
            )
                < 0 {
            return False;
        }
    }
    return True;
}

"""A new Context from Context() into state slot `index`, added to the
module as `name`."""
def:priv create_context_template(module: ptr[PyObject], index: int, name: str) -> bool {
    return set_state(
        module, index, PyObject_CallObject(state(module, STATE_CONTEXT_TYPE), NULL)
    )
        and PyModule_AddObjectRef(module, name, state(module, index)) >= 0;
}

"""The contexts: DefaultContext (the template of new threads' contexts and of
Context()), the contextvar, BasicContext and ExtendedContext."""
def:priv create_contexts(module: ptr[PyObject]) -> bool {
    if not create_context_template(
        module, STATE_DEFAULT_CONTEXT_TEMPLATE, "DefaultContext"
    ) {
        return False;
    }
    if not set_state(
        module, STATE_CURRENT_CONTEXT_VAR, PyContextVar_New("decimal_context", NULL)
    )
        or PyModule_AddObjectRef(module, "HAVE_CONTEXTVAR", py_true()) < 0
        or PyModule_AddObjectRef(module, "HAVE_THREADS", py_true()) < 0 {
        return False;
    }
    if not create_context_template(
        module, STATE_BASIC_CONTEXT_TEMPLATE, "BasicContext"
    ) {
        return False;
    }
    init_basic_context(state(module, STATE_BASIC_CONTEXT_TEMPLATE));
    if not create_context_template(
        module, STATE_EXTENDED_CONTEXT_TEMPLATE, "ExtendedContext"
    ) {
        return False;
    }
    init_extended_context(state(module, STATE_EXTENDED_CONTEXT_TEMPLATE));
    return True;
}

"""The constants: the limits, IEEE_CONTEXT_MAX_BITS, the rounding names,
__version__ and __libmpdec_version__."""
def:priv add_constants(module: ptr[PyObject]) -> bool {
    if PyModule_Add(module, "MAX_PREC", PyLong_FromSsize_t(MPD_MAX_PREC)) < 0
        or PyModule_Add(module, "MAX_EMAX", PyLong_FromSsize_t(MPD_MAX_EMAX)) < 0
        or PyModule_Add(module, "MIN_EMIN", PyLong_FromSsize_t(MPD_MIN_EMIN)) < 0
        or PyModule_Add(module, "MIN_ETINY", PyLong_FromSsize_t(MPD_MIN_ETINY)) < 0
        or PyModule_AddIntConstant(
            module, "IEEE_CONTEXT_MAX_BITS", i64(MPD_IEEE_CONTEXT_MAX_BITS)
        )
            < 0 {
        return False;
    }
    names = ptr[ptr[u8]](addressof(mpd_round_string));
    for i in range(PY_DEC_ROUND_GUARD) {
        name = (names + i).view(1)[0];
        if not set_state(
            module, STATE_ROUND_MAP + i, PyUnicode_InternFromString(name)
        ) {
            return False;
        }
        if PyModule_AddObjectRef(module, name, state(module, STATE_ROUND_MAP + i))
            < 0 {
            return False;
        }
    }
    return PyModule_AddStringConstant(module, "__version__", "1.70") >= 0
        and PyModule_AddStringConstant(module, "__libmpdec_version__", mpd_version())
            >= 0;
}

def:priv decimal_exec(module: ptr[PyObject]) -> i32 {
    decimal_module_token.handle = definition.handle;
    ok = init_libmpdec()
        and create_type(module, STATE_DEC_TYPE, addressof(dec_spec))
        and create_type(module, STATE_CONTEXT_TYPE, addressof(context_spec))
        and create_type(module, STATE_CONTEXT_MANAGER_TYPE, addressof(ctxmanager_spec))
        and create_type(
            module, STATE_SIGNAL_DICT_MIXIN_TYPE, addressof(signaldict_spec)
        )
        and set_module_name(state(module, STATE_DEC_TYPE))
        and set_module_name(state(module, STATE_CONTEXT_TYPE))
        and register_numbers(module)
        and create_decimal_tuple(module)
        and create_signal_dict(module)
        and PyModule_AddType(module, state(module, STATE_DEC_TYPE)) >= 0
        and PyModule_AddType(module, state(module, STATE_CONTEXT_TYPE)) >= 0
        and PyModule_AddType(module, state(module, STATE_DECIMAL_TUPLE)) >= 0
        and create_exceptions(module)
        and create_contexts(module)
        and add_constants(module);
    return i32(0 if ok else -1);
}

glob:priv METHOD_NOARGS: i64 = 4,
     METHOD_O: i64 = 8,
     METHOD_VARARGS_KEYWORDS: i64 = 3;

glob:priv definition = ModuleDefinition(
         "decimal",
         "C decimal arithmetic module",
         [
             MethodDefinition(
                 "getcontext",
                 MethodCallbacks(positional=dec_getcontext),
                 "getcontext($module, /)\n--\n\nGet the current default context.\n\n",
                 METHOD_NOARGS
             ),
             MethodDefinition(
                 "setcontext",
                 MethodCallbacks(positional=dec_setcontext),
                 "setcontext($module, context, /)\n--\n\nSet a new default context.\n\n",
                 METHOD_O
             ),
             MethodDefinition(
                 "localcontext",
                 MethodCallbacks(keywords=ctxmanager_new),
                 "localcontext($module, /, ctx=None, **kwargs)\n--\n\nReturn a context manager that will set the default context to a copy of ctx\non entry to the with-statement and restore the previous default context when\nexiting the with-statement. If no context is specified, a copy of the current\ndefault context is used.\n\n",
                 METHOD_VARARGS_KEYWORDS
             ),
             MethodDefinition(
                 "IEEEContext",
                 MethodCallbacks(positional=ieee_context),
                 "IEEEContext($module, bits, /)\n--\n\nReturn a context object initialized to the proper values for one of the\nIEEE interchange formats.  The argument must be a multiple of 32 and less\nthan IEEE_CONTEXT_MAX_BITS.\n\n",
                 METHOD_O
             )
         ],
         ModuleHooks(execute=decimal_exec),
         STATE_COUNT
     );

def:pub PyInit__decimal -> ptr[PyObject] {
    return definition.initialize();
}
