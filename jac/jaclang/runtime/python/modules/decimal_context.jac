"""The decimal.Context, SignalDictMixin and ContextManager types of _decimal.

Modules/_decimal/_decimal.c's context objects in native Jac: the signal
dictionaries that view a context's traps and status words, the Context
attributes, constructor, representation and pickling, the Context arithmetic
methods, the context manager of localcontext(), and the module functions
getcontext(), setcontext(), localcontext() and IEEEContext(). See
../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_is_list,
    jacpy_release,
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    PyErr_Clear,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyExc_AttributeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CallObject,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GenericGetAttr,
    PyObject_GenericSetAttr,
    PyObject_GetIter,
    PyObject_IsTrue,
    PyTuple_Pack,
    PyType_GetModule,
    PyUnicode_CompareWithASCIIString,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    _PyObject_GC_New,
    jacpy_is_dict,
    jacpy_is_unicode
}
import from jaclang.runtime.python.layouts { PyTypeObject }
import from jaclang.runtime.python.capi { c_string_text }
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.bindings.module { visit_reference }
import from jaclang.runtime.python.modules.mpdecimal {
    MPD_Clamped,
    MPD_Division_by_zero,
    MPD_IEEE_CONTEXT_MAX_BITS,
    MPD_IEEE_Invalid_operation,
    MPD_MAX_SIGNAL_LIST,
    MPD_Malloc_error,
    MPD_Overflow,
    MPD_ROUND_HALF_EVEN,
    MPD_ROUND_HALF_UP,
    MPD_Underflow,
    mpd_class,
    mpd_context_t,
    mpd_etiny,
    mpd_etop,
    mpd_free_memory,
    mpd_getclamp,
    mpd_getemax,
    mpd_getemin,
    mpd_getprec,
    mpd_getround,
    mpd_iscanonical,
    mpd_ieee_context,
    mpd_lsnprint_signals,
    mpd_qcopy_abs,
    mpd_qcopy_negate,
    mpd_qcopy_sign,
    mpd_qsetclamp,
    mpd_qsetemax,
    mpd_qsetemin,
    mpd_qsetprec,
    mpd_qsetround,
    mpd_qsetstatus,
    mpd_qsettraps,
    mpd_round_string,
    mpd_same_quantum,
    mpd_to_eng_size,
    mpd_to_sci_size
}
import from jaclang.runtime.python.modules.decimal_ops {
    binary_op,
    bool_op,
    fma_op,
    total_op,
    unary_op
}
import from jaclang.runtime.python.modules.decimal_objects {
    CONTEXT_STATUS_OFFSET,
    CONTEXT_TRAPS_OFFSET,
    DEC_ERRORS,
    INVALID_SIGNALDICT_ERROR_MSG,
    PyDecContextManagerObject,
    PyDecContextObject,
    PyDecSignalDictObject,
    Py_EQ_OP,
    Py_NE_OP,
    SIGNAL_FLAGS,
    SIGNAL_MAP_LEN,
    SIGNAL_NAMES,
    STATE_CONTEXT_MANAGER_TYPE,
    STATE_DEFAULT_CONTEXT_TEMPLATE,
    STATE_ROUND_MAP,
    STATE_SIGNAL_DICT_TYPE,
    STATE_SIGNAL_TUPLE,
    bool_object,
    context_check,
    context_copy,
    context_record,
    context_type,
    copy_mpd_context,
    ctx_caps,
    ctx_of,
    current_context,
    current_context_borrowed,
    dec_addstatus,
    dec_alloc,
    dec_check,
    dec_type,
    dict_as_flags,
    exception_as_flag,
    flags_as_dict,
    getround,
    internal_error_int,
    internal_error_ptr,
    list_as_flags,
    module_of_context,
    module_of_type,
    mpd,
    set_current_context,
    signal_dict_check,
    signal_dict_flags,
    signals_as_list,
    state_value,
    value_error_int,
    value_error_ptr
}
import from jaclang.runtime.python.modules.decimal_convert {
    convert_op,
    dec_apply,
    dec_from_object,
    dec_type_from_float
}
import from jaclang.runtime.python.modules.decimal_number {
    dec_mpd_radix_of,
    divmod_operands,
    parse_keywords,
    parse_tuple,
    power_operands,
    unicode_fromascii
}

import from c {
    # The condition names libmpdec's mpd_lsnprint_signals() prints for each
    # status flag, in flag order.
    glob:priv dec_signal_string: list[ptr[u8]] = [
             ptr[u8]("Clamped"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("DivisionByZero"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("Inexact"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("InvalidOperation"),
             ptr[u8]("FloatOperation"),
             ptr[u8]("Overflow"),
             ptr[u8]("Rounded"),
             ptr[u8]("Subnormal"),
             ptr[u8]("Underflow")
         ];
    # The default context: prec=28, Emax=999999, Emin=-999999, traps on
    # InvalidOperation, DivisionByZero and Overflow, ROUND_HALF_EVEN.
    glob dflt_ctx: mpd_context_t = mpd_context_t(
             prec=28,
             emax=999999,
             emin=-999999,
             traps=MPD_IEEE_Invalid_operation | MPD_Division_by_zero | MPD_Overflow,
             status=0,
             newtrap=0,
             round=MPD_ROUND_HALF_EVEN,
             clamp=0,
             allcr=1
         );
}

glob:priv INT_MIN: Final[int] = -2147483648,
     INT_MAX: Final[int] = 2147483647;

# ---------------------------------------------------------------------------
# SignalDict: a MutableMapping over a context's traps or status word. When a
# context is created, context.traps and context.flags are new SignalDicts
# tied to it; they cannot be deleted.

def signaldict_init(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> i32 {
    ptr[PyDecSignalDictObject](self).view(1)[0].flags = ptr[u32]();
    return i32(0);
}

def signaldict_len(self: ptr[PyObject]) -> i64 {
    if not signal_dict_flags(self) {
        return i64(value_error_int(INVALID_SIGNALDICT_ERROR_MSG));
    }
    return i64(SIGNAL_MAP_LEN);
}

def signaldict_iter(self: ptr[PyObject]) -> ptr[PyObject] {
    if not signal_dict_flags(self) {
        return value_error_ptr(INVALID_SIGNALDICT_ERROR_MSG);
    }
    module = module_of_type(ptr[PyObject](object_type(self)));
    return PyObject_GetIter(state_value(module, STATE_SIGNAL_TUPLE));
}

def signaldict_getitem(self: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    if not signal_dict_flags(self) {
        return value_error_ptr(INVALID_SIGNALDICT_ERROR_MSG);
    }
    module = module_of_type(ptr[PyObject](object_type(self)));
    flag = exception_as_flag(module, key);
    if (flag & DEC_ERRORS) != u32(0) {
        return NULL;
    }
    return bool_object((signal_dict_flags(self).view(1)[0] & flag) != u32(0));
}

def signaldict_setitem(
    self: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not signal_dict_flags(self) {
        return value_error_int(INVALID_SIGNALDICT_ERROR_MSG);
    }
    if not value {
        return value_error_int("signal keys cannot be deleted");
    }
    module = module_of_type(ptr[PyObject](object_type(self)));
    flag = exception_as_flag(module, key);
    if (flag & DEC_ERRORS) != u32(0) {
        return i32(-1);
    }
    x = PyObject_IsTrue(value);
    if x < 0 {
        return i32(-1);
    }
    word = signal_dict_flags(self).view(1);
    if x == 1 {
        word[0] = word[0] | flag;
    } else {
        word[0] = word[0] & ~flag;
    }
    return i32(0);
}

def signaldict_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
}

def signaldict_dealloc(self: ptr[PyObject]) {
    tp = object_type(self);
    PyObject_GC_UnTrack(ptr(self));
    tp.view(1)[0].tp_free(ptr(self));
    jacpy_release(ptr[PyObject](tp));
}

def signaldict_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    if not signal_dict_flags(self) {
        return value_error_ptr(INVALID_SIGNALDICT_ERROR_MSG);
    }
    flags = signal_dict_flags(self).view(1)[0];
    parts: list[str] = [];
    for index in range(SIGNAL_MAP_LEN) {
        value = "True" if (flags & SIGNAL_FLAGS[index]) != u32(0) else "False";
        parts.append(f"<class 'decimal.{SIGNAL_NAMES[index]}'>:{value}");
    }
    return PyUnicode_FromString("{" + ", ".join(parts) + "}");
}

def signaldict_richcompare(
    v: ptr[PyObject], w: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    module = module_of_type(ptr[PyObject](object_type(v)));
    if not signal_dict_flags(v) or not signal_dict_flags(w) {
        return value_error_ptr(INVALID_SIGNALDICT_ERROR_MSG);
    }
    res = Py_NotImplemented;
    if int(op) == Py_EQ_OP or int(op) == Py_NE_OP {
        ne = int(op) == Py_NE_OP;
        if signal_dict_check(module, w) {
            equal = signal_dict_flags(v).view(1)[0] == signal_dict_flags(w).view(1)[0];
            return bool_object(equal != ne);
        } elif jacpy_is_dict(w) != 0 {
            flags = dict_as_flags(module, w);
            if (flags & DEC_ERRORS) != u32(0) {
                if (flags & u32(0x8000)) != u32(0) {
                    # non-comparable: NotImplemented
                    PyErr_Clear();
                } else {
                    return NULL;
                }
            } else {
                return bool_object((signal_dict_flags(v).view(1)[0] == flags) != ne);
            }
        }
    }
    return Py_NewRef(res);
}

def signaldict_copy(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if not signal_dict_flags(self) {
        return value_error_ptr(INVALID_SIGNALDICT_ERROR_MSG);
    }
    module = module_of_type(ptr[PyObject](object_type(self)));
    return flags_as_dict(module, signal_dict_flags(self).view(1)[0]);
}

# ---------------------------------------------------------------------------
# Context attributes.

def context_getprec(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromSsize_t(mpd_getprec(ctx_of(self)));
}

def context_getemax(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromSsize_t(mpd_getemax(ctx_of(self)));
}

def context_getemin(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromSsize_t(mpd_getemin(ctx_of(self)));
}

def context_getclamp(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromSsize_t(i64(mpd_getclamp(ctx_of(self))));
}

def context_getround(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    i = int(mpd_getround(ctx_of(self)));
    return Py_NewRef(state_value(module_of_context(self), STATE_ROUND_MAP + i));
}

def context_getcapitals(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(i64(ctx_caps(self)));
}

def context_getetiny(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(mpd_etiny(ctx_of(self)));
}

def context_getetop(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(mpd_etop(ctx_of(self)));
}

"""A Py_ssize_t attribute value; `ok` False with the error set."""
obj SsizeValue {
    has value: i64 = 0,
        ok: bool = True;
}

def ssize_value(value: ptr[PyObject]) -> SsizeValue {
    x = PyLong_AsSsize_t(value);
    if x == -1 and PyErr_Occurred() {
        return SsizeValue(ok=False);
    }
    return SsizeValue(value=x);
}

def context_setprec(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    x = ssize_value(value);
    if not x.ok {
        return i32(-1);
    }
    if mpd_qsetprec(ctx_of(self), x.value) == 0 {
        return value_error_int("valid range for prec is [1, MAX_PREC]");
    }
    return i32(0);
}

def context_setemin(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    x = ssize_value(value);
    if not x.ok {
        return i32(-1);
    }
    if mpd_qsetemin(ctx_of(self), x.value) == 0 {
        return value_error_int("valid range for Emin is [MIN_EMIN, 0]");
    }
    return i32(0);
}

def context_setemax(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    x = ssize_value(value);
    if not x.ok {
        return i32(-1);
    }
    if mpd_qsetemax(ctx_of(self), x.value) == 0 {
        return value_error_int("valid range for Emax is [0, MAX_EMAX]");
    }
    return i32(0);
}

def context_setround(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    x = getround(module_of_context(self), value);
    if x == -1 {
        return i32(-1);
    }
    if mpd_qsetround(ctx_of(self), x) == 0 {
        return internal_error_int("context_setround");
    }
    return i32(0);
}

def context_setcapitals(
    self: ptr[PyObject], value: ptr[PyObject], closure: ptr
) -> i32 {
    x = ssize_value(value);
    if not x.ok {
        return i32(-1);
    }
    if x.value != 0 and x.value != 1 {
        return value_error_int("valid values for capitals are 0 or 1");
    }
    context_record(self).view(1)[0].capitals = i32(x.value);
    return i32(0);
}

def context_settraps_list(self: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    flags = list_as_flags(module_of_context(self), value);
    if (flags & DEC_ERRORS) != u32(0) {
        return i32(-1);
    }
    if mpd_qsettraps(ctx_of(self), flags) == 0 {
        return internal_error_int("context_settraps_list");
    }
    return i32(0);
}

def context_settraps_dict(self: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    module = module_of_context(self);
    flags: u32 = 0;
    if signal_dict_check(module, value) {
        flags = signal_dict_flags(value).view(1)[0];
    } else {
        flags = dict_as_flags(module, value);
        if (flags & DEC_ERRORS) != u32(0) {
            return i32(-1);
        }
    }
    if mpd_qsettraps(ctx_of(self), flags) == 0 {
        return internal_error_int("context_settraps_dict");
    }
    return i32(0);
}

def context_setstatus_list(self: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    flags = list_as_flags(module_of_context(self), value);
    if (flags & DEC_ERRORS) != u32(0) {
        return i32(-1);
    }
    if mpd_qsetstatus(ctx_of(self), flags) == 0 {
        return internal_error_int("context_setstatus_list");
    }
    return i32(0);
}

def context_setstatus_dict(self: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    module = module_of_context(self);
    flags: u32 = 0;
    if signal_dict_check(module, value) {
        flags = signal_dict_flags(value).view(1)[0];
    } else {
        flags = dict_as_flags(module, value);
        if (flags & DEC_ERRORS) != u32(0) {
            return i32(-1);
        }
    }
    if mpd_qsetstatus(ctx_of(self), flags) == 0 {
        return internal_error_int("context_setstatus_dict");
    }
    return i32(0);
}

def context_setclamp(self: ptr[PyObject], value: ptr[PyObject], closure: ptr) -> i32 {
    x = ssize_value(value);
    if not x.ok {
        return i32(-1);
    }
    clamp = x.value;
    # BOUNDS_CHECK(x, INT_MIN, INT_MAX)
    if clamp < INT_MIN or INT_MAX < clamp {
        clamp = INT_MAX;
    }
    if mpd_qsetclamp(ctx_of(self), i32(clamp)) == 0 {
        return value_error_int("valid values for clamp are 0 or 1");
    }
    return i32(0);
}

def context_getattr(self: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(name) != 0 {
        if PyUnicode_CompareWithASCIIString(name, "traps") == 0 {
            return Py_NewRef(context_record(self).view(1)[0].traps);
        }
        if PyUnicode_CompareWithASCIIString(name, "flags") == 0 {
            return Py_NewRef(context_record(self).view(1)[0].flags);
        }
    }
    return PyObject_GenericGetAttr(self, name);
}

def context_setattr(
    self: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        PyErr_SetString(PyExc_AttributeError, "context attributes cannot be deleted");
        return i32(-1);
    }
    if jacpy_is_unicode(name) != 0 {
        if PyUnicode_CompareWithASCIIString(name, "traps") == 0 {
            return context_settraps_dict(self, value);
        }
        if PyUnicode_CompareWithASCIIString(name, "flags") == 0 {
            return context_setstatus_dict(self, value);
        }
    }
    return PyObject_GenericSetAttr(self, name, value);
}

"""Set the given attributes (None leaves one unchanged)."""
def context_setattrs(
    self: ptr[PyObject],
    prec: ptr[PyObject],
    rounding: ptr[PyObject],
    emin: ptr[PyObject],
    emax: ptr[PyObject],
    capitals: ptr[PyObject],
    clamp: ptr[PyObject],
    status: ptr[PyObject],
    traps: ptr[PyObject]
) -> i32 {
    if prec != Py_None and context_setprec(self, prec, ptr()) < 0 {
        return i32(-1);
    }
    if rounding != Py_None and context_setround(self, rounding, ptr()) < 0 {
        return i32(-1);
    }
    if emin != Py_None and context_setemin(self, emin, ptr()) < 0 {
        return i32(-1);
    }
    if emax != Py_None and context_setemax(self, emax, ptr()) < 0 {
        return i32(-1);
    }
    if capitals != Py_None and context_setcapitals(self, capitals, ptr()) < 0 {
        return i32(-1);
    }
    if clamp != Py_None and context_setclamp(self, clamp, ptr()) < 0 {
        return i32(-1);
    }
    if traps != Py_None {
        ret = context_settraps_list(self, traps)
            if jacpy_is_list(traps) != 0
            else context_settraps_dict(self, traps);
        if ret < 0 {
            return ret;
        }
    }
    if status != Py_None {
        ret = context_setstatus_list(self, status)
            if jacpy_is_list(status) != 0
            else context_setstatus_dict(self, status);
        if ret < 0 {
            return ret;
        }
    }
    return i32(0);
}

def context_clear_traps(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    ctx_of(self).view(1)[0].traps = 0;
    return Py_NewRef(Py_None);
}

def context_clear_flags(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    ctx_of(self).view(1)[0].status = 0;
    return Py_NewRef(Py_None);
}

# ---------------------------------------------------------------------------
# Context lifecycle.

def context_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_type(ptr[PyObject](type));
    exact = ptr[PyObject](type) == context_type(module);
    self: ptr[PyObject] = NULL;
    if exact {
        self = _PyObject_GC_New(ptr[PyObject](type));
    } else {
        self = type.view(1)[0].tp_alloc(type, 0);
    }
    if not self {
        return NULL;
    }
    record = context_record(self).view(1);
    record[0].traps = PyObject_CallObject(
        state_value(module, STATE_SIGNAL_DICT_TYPE), NULL
    );
    if not record[0].traps {
        record[0].flags = NULL;
        jacpy_release(self);
        return NULL;
    }
    record[0].flags = PyObject_CallObject(
        state_value(module, STATE_SIGNAL_DICT_TYPE), NULL
    );
    if not record[0].flags {
        jacpy_release(self);
        return NULL;
    }
    template = state_value(module, STATE_DEFAULT_CONTEXT_TEMPLATE);
    if template {
        copy_mpd_context(ctx_of(self), ctx_of(template));
    } else {
        copy_mpd_context(ctx_of(self), addressof(dflt_ctx));
    }
    ptr[PyDecSignalDictObject](record[0].traps).view(1)[0].flags = ptr[u32](
        ptr[u8](self) + CONTEXT_TRAPS_OFFSET
    );
    ptr[PyDecSignalDictObject](record[0].flags).view(1)[0].flags = ptr[u32](
        ptr[u8](self) + CONTEXT_STATUS_OFFSET
    );
    record[0].capitals = 1;
    record[0].tstate = ptr();
    record[0].modstate = module;
    if exact {
        PyObject_GC_Track(ptr(self));
    }
    return self;
}

def context_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    record = context_record(op).view(1);
    status = visit_reference(record[0].traps, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(record[0].flags, visitor, arg);
}

def context_clear(op: ptr[PyObject]) -> i32 {
    record = context_record(op).view(1);
    traps = record[0].traps;
    record[0].traps = NULL;
    jacpy_release(traps);
    flags = record[0].flags;
    record[0].flags = NULL;
    jacpy_release(flags);
    return i32(0);
}

def context_dealloc(self: ptr[PyObject]) {
    tp = object_type(self);
    PyObject_GC_UnTrack(ptr(self));
    context_clear(self);
    tp.view(1)[0].tp_free(ptr(self));
    jacpy_release(ptr[PyObject](tp));
}

def context_init(self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]) -> i32 {
    values = parse_keywords(
        args,
        kwds,
        "|OOOOOOOO",
        ["prec", "rounding", "Emin", "Emax", "capitals", "clamp", "flags", "traps"]
    );
    if values is None {
        return i32(-1);
    }
    given: list[ptr[PyObject]] = [];
    for value in values {
        given.append(value.object if value.given else Py_None);
    }
    return context_setattrs(
        self,
        given[0],
        given[1],
        given[2],
        given[3],
        given[4],
        given[5],
        given[6],
        given[7]
    );
}

"""The rounding name of mode `round` (mpd_round_string)."""
def round_string(round: i32) -> ptr[u8] {
    return (ptr[ptr[u8]](addressof(mpd_round_string)) + int(round)).view(1)[0];
}

"""The flags in `flags` as "[Inexact, Rounded]", or NULL with an error."""
def signal_list_text(flags: u32) -> ptr[u8] {
    buffer = ptr[u8](PyMem_Malloc(u64(MPD_MAX_SIGNAL_LIST)));
    if not buffer {
        PyErr_NoMemory();
        return buffer;
    }
    n = mpd_lsnprint_signals(
        buffer,
        i32(MPD_MAX_SIGNAL_LIST),
        flags,
        ptr[ptr[u8]](addressof(dec_signal_string))
    );
    if n < 0 or n >= i32(MPD_MAX_SIGNAL_LIST) {
        PyMem_Free(ptr(buffer));
        internal_error_ptr("context_repr");
        return ptr[u8]();
    }
    return buffer;
}

def context_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    ctx = ctx_of(self).view(1);
    flags = signal_list_text(ctx[0].status);
    if not flags {
        return NULL;
    }
    traps = signal_list_text(ctx[0].traps);
    if not traps {
        PyMem_Free(ptr(flags));
        return NULL;
    }
    result = PyUnicode_FromFormat(
        "Context(prec=%zd, rounding=%s, Emin=%zd, Emax=%zd, capitals=%d, clamp=%d, flags=%s, traps=%s)",
        ctx[0].prec,
        round_string(ctx[0].round),
        ctx[0].emin,
        ctx[0].emax,
        ctx_caps(self),
        ctx[0].clamp,
        flags,
        traps
    );
    PyMem_Free(ptr(flags));
    PyMem_Free(ptr(traps));
    return result;
}

"""BasicContext: prec=9, ROUND_HALF_UP, Underflow and Clamped trapped too."""
def init_basic_context(v: ptr[PyObject]) {
    copy_mpd_context(ctx_of(v), addressof(dflt_ctx));
    ctx = ctx_of(v).view(1);
    ctx[0].prec = 9;
    ctx[0].traps = ctx[0].traps | MPD_Underflow | MPD_Clamped;
    ctx[0].round = MPD_ROUND_HALF_UP;
    context_record(v).view(1)[0].capitals = 1;
}

"""ExtendedContext: prec=9 and no traps."""
def init_extended_context(v: ptr[PyObject]) {
    copy_mpd_context(ctx_of(v), addressof(dflt_ctx));
    ctx = ctx_of(v).view(1);
    ctx[0].prec = 9;
    ctx[0].traps = 0;
    context_record(v).view(1)[0].capitals = 1;
}

"""IEEEContext(bits): a context for an IEEE interchange format."""
def ieee_context(module: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    bits = PyLong_AsSsize_t(v);
    if bits == -1 and PyErr_Occurred() {
        return NULL;
    }
    ctx = ptr[mpd_context_t](PyMem_Malloc(48));
    if not ctx {
        PyErr_NoMemory();
        return NULL;
    }
    if bits <= 0 or bits > INT_MAX or mpd_ieee_context(ctx, i32(bits)) < 0 {
        PyMem_Free(ptr(ctx));
        PyErr_Format(
            PyExc_ValueError,
            "argument must be a multiple of 32, with a maximum of %d",
            i32(MPD_IEEE_CONTEXT_MAX_BITS)
        );
        return NULL;
    }
    context = PyObject_CallObject(context_type(module), NULL);
    if context {
        copy_mpd_context(ctx_of(context), ctx);
    }
    PyMem_Free(ptr(ctx));
    return context;
}

def context_reduce(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of_context(self);
    ctx = ctx_of(self).view(1);
    flags = signals_as_list(module, ctx[0].status);
    if not flags {
        return NULL;
    }
    traps = signals_as_list(module, ctx[0].traps);
    if not traps {
        jacpy_release(flags);
        return NULL;
    }
    result = Py_BuildValue(
        "O(nsnniiOO)",
        ptr[PyObject](object_type(self)),
        ctx[0].prec,
        round_string(ctx[0].round),
        ctx[0].emin,
        ctx[0].emax,
        ctx_caps(self),
        ctx[0].clamp,
        flags,
        traps
    );
    jacpy_release(flags);
    jacpy_release(traps);
    return result;
}

# ---------------------------------------------------------------------------
# Context arithmetic: the operands are converted, raising TypeError.

"""DecCtx_UnaryFunc."""
def ctx_unary(context: ptr[PyObject], v: ptr[PyObject], op: int) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(a);
        return NULL;
    }
    status = unary_op(op, mpd(result), mpd(a), ctx_of(context));
    jacpy_release(a);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""The two operands of a binary Context method (positional only), or `ok`
False with the error set."""
obj ContextOperands {
    has a: ptr[PyObject] = NULL,
        b: ptr[PyObject] = NULL,
        ok: bool = False;
}

def context_operands(context: ptr[PyObject], args: ptr[PyObject]) -> ContextOperands {
    operands = ContextOperands();
    values = parse_tuple(args, "OO");
    if values is None {
        return operands;
    }
    a = convert_op(True, values[0].object, context);
    if not a {
        return operands;
    }
    b = convert_op(True, values[1].object, context);
    if not b {
        jacpy_release(a);
        return operands;
    }
    operands.a = a;
    operands.b = b;
    operands.ok = True;
    return operands;
}

"""DecCtx_BinaryFunc."""
def ctx_binary(context: ptr[PyObject], args: ptr[PyObject], op: int) -> ptr[PyObject] {
    operands = context_operands(context, args);
    if not operands.ok {
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    status = binary_op(
        op, mpd(result), mpd(operands.a), mpd(operands.b), ctx_of(context)
    );
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""DecCtx_BinaryFunc_NO_CTX: the context is only used for conversion."""
def ctx_total(context: ptr[PyObject], args: ptr[PyObject], op: int) -> ptr[PyObject] {
    operands = context_operands(context, args);
    if not operands.ok {
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    total_op(op, mpd(result), mpd(operands.a), mpd(operands.b));
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    return result;
}

"""DecCtx_BoolFunc and DecCtx_BoolFunc_NO_CTX."""
def ctx_bool(context: ptr[PyObject], v: ptr[PyObject], op: int) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    ret = bool_object(bool_op(op, mpd(a), ctx_of(context)));
    jacpy_release(a);
    return ret;
}

def ctx_mpd_qdivmod(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    operands = context_operands(context, args);
    if not operands.ok {
        return NULL;
    }
    return divmod_operands(module_of_context(context), operands.a, operands.b, context);
}

"""power(a, b, modulo=None)."""
def ctx_mpd_qpow(
    context: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    values = parse_keywords(args, kwds, "OO|O", ["a", "b", "modulo"]);
    if values is None {
        return NULL;
    }
    a = convert_op(True, values[0].object, context);
    if not a {
        return NULL;
    }
    b = convert_op(True, values[1].object, context);
    if not b {
        jacpy_release(a);
        return NULL;
    }
    c: ptr[PyObject] = NULL;
    modulo = values[2].object if values[2].given else Py_None;
    if modulo != Py_None {
        c = convert_op(True, modulo, context);
        if not c {
            jacpy_release(a);
            jacpy_release(b);
            return NULL;
        }
    }
    return power_operands(module_of_context(context), a, b, c, context);
}

def ctx_mpd_qfma(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    values = parse_tuple(args, "OOO");
    if values is None {
        return NULL;
    }
    a = convert_op(True, values[0].object, context);
    if not a {
        return NULL;
    }
    b = convert_op(True, values[1].object, context);
    if not b {
        jacpy_release(a);
        return NULL;
    }
    c = convert_op(True, values[2].object, context);
    if not c {
        jacpy_release(a);
        jacpy_release(b);
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(a);
        jacpy_release(b);
        jacpy_release(c);
        return NULL;
    }
    status = fma_op(mpd(result), mpd(a), mpd(b), mpd(c), ctx_of(context));
    jacpy_release(a);
    jacpy_release(b);
    jacpy_release(c);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def ctx_mpd_radix(context: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return dec_mpd_radix_of(module_of_context(context));
}

def ctx_iscanonical(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    if not dec_check(module_of_context(context), v) {
        PyErr_SetString(PyExc_TypeError, "argument must be a Decimal");
        return NULL;
    }
    return bool_object(mpd_iscanonical(mpd(v)) != 0);
}

"""_apply(v): v converted and rounded to the context."""
def ctx_apply(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    result = dec_apply(a, context);
    jacpy_release(a);
    return result;
}

def ctx_canonical(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    if not dec_check(module_of_context(context), v) {
        PyErr_SetString(PyExc_TypeError, "argument must be a Decimal");
        return NULL;
    }
    return Py_NewRef(v);
}

"""copy_abs and copy_negate."""
def ctx_copy_with(
    context: ptr[PyObject], v: ptr[PyObject], negate: bool
) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(a);
        return NULL;
    }
    status: u32 = 0;
    if negate {
        mpd_qcopy_negate(mpd(result), mpd(a), &mut status);
    } else {
        mpd_qcopy_abs(mpd(result), mpd(a), &mut status);
    }
    jacpy_release(a);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def ctx_mpd_qcopy_abs(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_copy_with(context, v, False);
}

def ctx_mpd_qcopy_negate(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_copy_with(context, v, True);
}

def ctx_copy_decimal(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return convert_op(True, v, context);
}

def ctx_mpd_class(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    cp = mpd_class(mpd(a), ctx_of(context));
    jacpy_release(a);
    return c_string_text(cp);
}

"""to_sci_string and to_eng_string."""
def ctx_to_string(
    context: ptr[PyObject], v: ptr[PyObject], engineering: bool
) -> ptr[PyObject] {
    a = convert_op(True, v, context);
    if not a {
        return NULL;
    }
    s = ptr[u8]();
    size: i64 = 0;
    if engineering {
        size = mpd_to_eng_size(&mut s, mpd(a), ctx_caps(context));
    } else {
        size = mpd_to_sci_size(&mut s, mpd(a), ctx_caps(context));
    }
    jacpy_release(a);
    if size < 0 {
        PyErr_NoMemory();
        return NULL;
    }
    result = unicode_fromascii(s, size);
    mpd_free_memory(ptr(s));
    return result;
}

def ctx_mpd_to_sci(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_to_string(context, v, False);
}

def ctx_mpd_to_eng(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return ctx_to_string(context, v, True);
}

def ctx_mpd_qcopy_sign(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    operands = context_operands(context, args);
    if not operands.ok {
        return NULL;
    }
    result = dec_alloc(module_of_context(context));
    if not result {
        jacpy_release(operands.a);
        jacpy_release(operands.b);
        return NULL;
    }
    status: u32 = 0;
    mpd_qcopy_sign(mpd(result), mpd(operands.a), mpd(operands.b), &mut status);
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    if dec_addstatus(context, status) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def ctx_mpd_same_quantum(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    operands = context_operands(context, args);
    if not operands.ok {
        return NULL;
    }
    result = bool_object(mpd_same_quantum(mpd(operands.a), mpd(operands.b)) != 0);
    jacpy_release(operands.a);
    jacpy_release(operands.b);
    return result;
}

"""create_decimal(num="0"): num rounded to the context."""
def ctx_create_decimal(context: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    values = parse_tuple(args, "|O");
    if values is None {
        return NULL;
    }
    return dec_from_object(values[0].object if values[0].given else NULL, context);
}

"""create_decimal_from_float(f)."""
def ctx_from_float(context: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return dec_type_from_float(dec_type(module_of_context(context)), v, context);
}

# ---------------------------------------------------------------------------
# Module functions and the context manager.

"""getcontext(): the current context."""
def dec_getcontext(module: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return current_context(module);
}

"""setcontext(context)."""
def dec_setcontext(module: ptr[PyObject], v: ptr[PyObject]) -> ptr[PyObject] {
    return set_current_context(module, v);
}

"""localcontext(ctx=None, **kwargs): a context manager that owns one
reference to the global (outer) context and one to the local (inner)
copy."""
def ctxmanager_new(
    module: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    outer = current_context_borrowed(module);
    if not outer {
        return NULL;
    }
    values = parse_keywords(
        args,
        kwds,
        "|OOOOOOOOO",
        [
            "ctx",
            "prec",
            "rounding",
            "Emin",
            "Emax",
            "capitals",
            "clamp",
            "flags",
            "traps"
        ]
    );
    if values is None {
        return NULL;
    }
    given: list[ptr[PyObject]] = [];
    for value in values {
        given.append(value.object if value.given else Py_None);
    }
    inner = given[0];
    if inner == Py_None {
        inner = outer;
    } elif not context_check(module, inner) {
        PyErr_SetString(PyExc_TypeError, "optional argument must be a context");
        return NULL;
    }
    local_copy = context_copy(inner, NULL);
    if not local_copy {
        return NULL;
    }
    if context_setattrs(
        local_copy,
        given[1],
        given[2],
        given[3],
        given[4],
        given[5],
        given[6],
        given[7],
        given[8]
    )
        < 0 {
        jacpy_release(local_copy);
        return NULL;
    }
    self = _PyObject_GC_New(state_value(module, STATE_CONTEXT_MANAGER_TYPE));
    if not self {
        jacpy_release(local_copy);
        return NULL;
    }
    record = ptr[PyDecContextManagerObject](self).view(1);
    record[0].inner = local_copy;
    record[0].outer = Py_NewRef(outer);
    PyObject_GC_Track(ptr(self));
    return self;
}

def ctxmanager_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    record = ptr[PyDecContextManagerObject](op).view(1);
    status = visit_reference(record[0].inner, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(record[0].outer, visitor, arg);
}

def ctxmanager_clear(op: ptr[PyObject]) -> i32 {
    record = ptr[PyDecContextManagerObject](op).view(1);
    inner = record[0].inner;
    record[0].inner = NULL;
    jacpy_release(inner);
    outer = record[0].outer;
    record[0].outer = NULL;
    jacpy_release(outer);
    return i32(0);
}

def ctxmanager_dealloc(self: ptr[PyObject]) {
    tp = object_type(self);
    PyObject_GC_UnTrack(ptr(self));
    ctxmanager_clear(self);
    tp.view(1)[0].tp_free(ptr(self));
    jacpy_release(ptr[PyObject](tp));
}

"""__enter__: install the local context and return it."""
def ctxmanager_set_local(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    inner = ptr[PyDecContextManagerObject](op).view(1)[0].inner;
    ret = set_current_context(PyType_GetModule(ptr[PyObject](object_type(op))), inner);
    if not ret {
        return NULL;
    }
    jacpy_release(ret);
    return Py_NewRef(inner);
}

"""__exit__: put the global context back."""
def ctxmanager_restore_global(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    outer = ptr[PyDecContextManagerObject](op).view(1)[0].outer;
    ret = set_current_context(PyType_GetModule(ptr[PyObject](object_type(op))), outer);
    if not ret {
        return NULL;
    }
    jacpy_release(ret);
    return Py_NewRef(Py_None);
}
