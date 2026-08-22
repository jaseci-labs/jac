# c2jac: 1 best-effort site lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L525 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob ptrdiff_t = int,
     size_t = int,
     ssize_t = int,
     intptr_t = int,
     uintptr_t = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     intmax_t = int,
     uintmax_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     Py_ssize_t = int,
     Py_hash_t = int;

@__jac_value__
obj PyVarObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0;
}

glob digit = int,
     stwodigits = int,
     sdigit = int,
     _Pyuintptr_t = int,
     Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj unaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj binaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj inquiry {
    def call -> int {
        ;
    }
}

@__jac_value__
obj vectorcallfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj hashfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj richcmpfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj getiterfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj iternextfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj ssizeargfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc(),
        sq_item: ssizeargfunc = ssizeargfunc(),
        sq_contains: inquiry = inquiry();
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc(),
        nb_subtract: binaryfunc = binaryfunc(),
        nb_multiply: binaryfunc = binaryfunc(),
        nb_remainder: binaryfunc = binaryfunc(),
        nb_divmod: binaryfunc = binaryfunc(),
        nb_power: binaryfunc = binaryfunc(),
        nb_negative: binaryfunc = binaryfunc(),
        nb_positive: binaryfunc = binaryfunc(),
        nb_absolute: binaryfunc = binaryfunc(),
        nb_bool: inquiry = inquiry(),
        nb_invert: unaryfunc = unaryfunc(),
        nb_lshift: binaryfunc = binaryfunc(),
        nb_rshift: binaryfunc = binaryfunc(),
        nb_and: binaryfunc = binaryfunc(),
        nb_xor: binaryfunc = binaryfunc(),
        nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        tp_name: str = str(),
        tp_basicsize: int = 0,
        tp_itemsize: int = 0,
        tp_dealloc: object = object(),
        tp_repr: unaryfunc = unaryfunc(),
        tp_as_number: PyNumberMethods = PyNumberMethods(),
        tp_as_sequence: PySequenceMethods = PySequenceMethods(),
        tp_hash: hashfunc = hashfunc(),
        tp_richcompare: richcmpfunc = richcmpfunc(),
        tp_iter: getiterfunc = getiterfunc(),
        tp_iternext: iternextfunc = iternextfunc(),
        tp_flags: int = 0,
        tp_doc: str = str(),
        tp_base: PyTypeObject = PyTypeObject(),
        tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0,
        ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject(),
        long_value: _PyLongValue = _PyLongValue();
}


glob Py_UCS1 = int;

@__jac_value__
obj PyHeapTypeObject {
    has ht_type: PyTypeObject = PyTypeObject(),
        ht_name: PyObj = PyObj(),
        ht_qualname: PyObj = PyObj();
}

glob size_t = int,
     __builtin_va_list = int,
     __gnuc_va_list = int,
     va_list = int,
     __int8_t = int,
     __uint8_t = int,
     __int16_t = int,
     __uint16_t = int,
     __int_least16_t = int,
     __uint_least16_t = int,
     __int32_t = int,
     __uint32_t = int,
     __int64_t = int,
     __uint64_t = int,
     __int_least32_t = int,
     __uint_least32_t = int,
     __s8 = int,
     __u8 = int,
     __s16 = int,
     __u16 = int,
     __s32 = int,
     __u32 = int,
     __s64 = int,
     __u64 = int,
     _LOCK_T = int,
     _LOCK_RECURSIVE_T = int,
     _off_t = int,
     __dev_t = int,
     __uid_t = int,
     __gid_t = int,
     _off64_t = int,
     _fpos_t = int,
     _ssize_t = int,
     wint_t = int,
     _mbstate_t = int,
     _flock_t = int,
     _iconv_t = int,
     __ULong = int,
     __FILE = int,
     ptrdiff_t = int,
     wchar_t = int,
     char16_t = int,
     char32_t = int,
     __off_t = int,
     __pid_t = int,
     __loff_t = int,
     u_char = int,
     u_short = int,
     u_int = int,
     u_long = int,
     ushort = int,
     uint = int,
     clock_t = int,
     time_t = int,
     daddr_t = int,
     caddr_t = int,
     ino_t = int,
     off_t = int,
     dev_t = int,
     uid_t = int,
     gid_t = int,
     pid_t = int,
     key_t = int,
     ssize_t = int,
     mode_t = int,
     nlink_t = int,
     fd_mask = int,
     _types_fd_set = int,
     clockid_t = int,
     timer_t = int,
     useconds_t = int,
     suseconds_t = int,
     FILE = int,
     fpos_t = int,
     cookie_read_function_t = int,
     cookie_write_function_t = int,
     cookie_seek_function_t = int,
     cookie_close_function_t = int,
     cookie_io_functions_t = int,
     div_t = int,
     ldiv_t = int,
     lldiv_t = int,
     sigset_t = int,
     __sigset_t = int,
     _sig_func_ptr = int,
     sig_atomic_t = int,
     __tzrule_type = int,
     __tzinfo_type = int,
     mbstate_t = int,
     sem_t = int,
     pthread_t = int,
     pthread_attr_t = int,
     pthread_mutex_t = int,
     pthread_mutexattr_t = int,
     pthread_cond_t = int,
     pthread_condattr_t = int,
     pthread_key_t = int,
     pthread_once_t = int,
     pthread_rwlock_t = int,
     pthread_rwlockattr_t = int,
     pthread_spinlock_t = int,
     pthread_barrier_t = int,
     pthread_barrierattr_t = int,
     jmp_buf = int,
     rlim_t = int,
     sa_family_t = int,
     sigjmp_buf = int,
     stack_t = int,
     siginfo_t = int,
     z_stream = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     intptr_t = int,
     uintptr_t = int,
     intmax_t = int,
     uintmax_t = int,
     `bool = int,
     MirEGLNativeWindowType = object,
     MirEGLNativeDisplayType = object,
     xcb_window_t = int,
     xcb_visualid_t = int,
     DIR = object,
     __socklen_t = int,
     socklen_t = int,
     __kernel_sa_family_t = int,
     atomic_bool = int,
     atomic_char = int,
     atomic_schar = int,
     atomic_uchar = int,
     atomic_short = int,
     atomic_ushort = int,
     atomic_int = int,
     atomic_uint = int,
     atomic_long = int,
     atomic_ulong = int,
     atomic_llong = int,
     atomic_ullong = int,
     atomic_char16_t = int,
     atomic_char32_t = int,
     atomic_wchar_t = int,
     atomic_int_least8_t = int,
     atomic_uint_least8_t = int,
     atomic_int_least16_t = int,
     atomic_uint_least16_t = int,
     atomic_int_least32_t = int,
     atomic_uint_least32_t = int,
     atomic_int_least64_t = int,
     atomic_uint_least64_t = int,
     atomic_int_fast8_t = int,
     atomic_uint_fast8_t = int,
     atomic_int_fast16_t = int,
     atomic_uint_fast16_t = int,
     atomic_int_fast32_t = int,
     atomic_uint_fast32_t = int,
     atomic_int_fast64_t = int,
     atomic_uint_fast64_t = int,
     atomic_intptr_t = int,
     atomic_uintptr_t = int,
     atomic_size_t = int,
     atomic_ptrdiff_t = int,
     atomic_intmax_t = int,
     atomic_uintmax_t = int;

@__jac_value__
obj atomic_flag {
    has _Value: atomic_bool = atomic_bool();
}

glob memory_order = int;

def _PyType_Name(`type: PyTypeObject) -> str {
    s: str = str();

    if (`type.tp_name == 0) {
        return "";
    }

    s = strrchr(`type.tp_name, 46);
    if (s == 0) {
        return `type.tp_name;
    }

    return s[1:];
}

def type_name(tp: PyObj) -> PyObj {
    `type: PyTypeObject = tp;

    if (`type.tp_flags & (1 << 9)) {
        et: PyHeapTypeObject = `type;
        if (et.ht_name != 0) {
            return et.ht_name;
        }
    }

    return PyUnicode_FromString(_PyType_Name(`type));
}

def type_repr(`self: PyObj) -> PyObj {
    `type: PyTypeObject = `self;

    if (`type.tp_name == 0) {
        return PyUnicode_FromFormat("<class at %p>", `type);
    }

    return PyUnicode_FromFormat("<class '%s'>", `type.tp_name);
}

def type_hash(`self: PyObj) -> int {
    `self;
    return PyObject_HashNotImplemented(`self);
}

def type_richcompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    while True {
        if (not (v.ob_type == PyType_Type) or not (w.ob_type == PyType_Type)) {
            return Py_NotImplemented;
        }
        if not 0 {
            break;
        }
    }
    if (v == w) {
        if (op == 2) {
            return Py_True;
        }

        if (op == 3) {
            return Py_False;
        }

        return Py_NotImplemented;
    }

    if (op == 2) {
        return Py_False;
    }

    if (op == 3) {
        return Py_True;
    }

    return Py_NotImplemented;
}

def PyType_Ready(`type: PyTypeObject) -> int {
    if (`type.tp_flags & (1 << 12)) {
        return 0;
    }

    if (`type.tp_flags & (1 << 13)) {
        raise TypeError("type is being readied recursively");
    }

    `type.tp_flags |= 1 << 13;

    `type.tp_flags &= ~(1 << 13);
    `type.tp_flags |= 1 << 12;
    return 0;
}
