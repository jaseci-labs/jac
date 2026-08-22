# c2jac: 2 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L574 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L574 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

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
obj PyBytesObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        ob_hash: int = 0,
        ob_sval: list = list();
}


def set_ob_shash(a: PyBytesObject, hash: int) {
    a.ob_hash = hash;
}

def get_ob_shash(a: PyBytesObject) -> int {
    return a.ob_hash;
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

def bytes_compare_eq(a: PyBytesObject, b: PyBytesObject) -> int {
    cmp: int = 0;
    len: int = 0;

    len = a.ob_size;
    if (b.ob_size != len) {
        return 0;
    }

    if (a.ob_sval[0] != b.ob_sval[0]) {
        return 0;
    }

    cmp = memcmp(a.ob_sval, b.ob_sval, len);
    return (cmp == 0);
}

def _Py_bytes_contains(`str: str, len: int, arg: PyObj) -> int {
    ival: int = PyNumber_AsSsize_t(arg, 0);
    if ((ival == -1) and PyErr_Occurred()) {
        PyErr_Clear();
        return -1;
    }

    if ((ival < 0) or (ival >= 256)) {
        raise ValueError("byte must be in range(0, 256)");
    }

    return (memchr(`str, ival, len) != 0);
}

def bytes_contains(`self: PyObj, arg: PyObj) -> int {
    a: PyBytesObject = `self;
    return _Py_bytes_contains(a.ob_sval, a.ob_size, arg);
}

def bytes_richcompare(aa: PyObj, bb: PyObj, op: int) -> PyObj {
    if not ((aa.ob_type == PyBytes_Type) and (bb.ob_type == PyBytes_Type)) {
        return Py_NotImplemented;
    }

    a: PyBytesObject = aa;
    b: PyBytesObject = bb;
    if (a == b) {
        if op == 2 or op == 1 or op == 5 {
            return Py_True;
        } elif op == 3 or op == 0 or op == 4 {
            return Py_False;
        } else {
            PyErr_BadInternalCall();
            return 0;
        }
    } elif ((op == 2) or (op == 3)) {
        eq: int = bytes_compare_eq(a, b);
        eq ^= op == 3;
        return PyBool_FromLong(eq);
    } else {
        len_a: int = a.ob_size;
        len_b: int = b.ob_size;
        min_len: int = len_a if (len_a < len_b) else len_b;
        c: int = 0;
        if (min_len > 0) {
            c = a.ob_sval - b.ob_sval;
            if (c == 0) {
                c = memcmp(a.ob_sval, b.ob_sval, min_len);
            }
        } else {
            c = 0;
        }
        if (c != 0) {
            while True {
                if op == 2 {
                    if (c == 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 3 {
                    if (c != 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 0 {
                    if (c < 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 4 {
                    if (c > 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 1 {
                    if (c <= 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 5 {
                    if (c >= 0) {
                        return Py_True;
                    }
                    return Py_False;
                } else {
                    PyErr_BadInternalCall();
                    return 0;
                }
                if not 0 {
                    break;
                }
            }
        }
        while True {
            if op == 2 {
                if (len_a == len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 3 {
                if (len_a != len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 0 {
                if (len_a < len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 4 {
                if (len_a > len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 1 {
                if (len_a <= len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 5 {
                if (len_a >= len_b) {
                    return Py_True;
                }
                return Py_False;
            } else {
                PyErr_BadInternalCall();
                return 0;
            }
            if not 0 {
                break;
            }
        }
    }
}

def bytes_hash(`self: PyObj) -> int {
    a: PyBytesObject = `self;
    hash: int = get_ob_shash(a);
    if (hash == -1) {
        hash = Py_HashBuffer(a.ob_sval, a.ob_size);
        set_ob_shash(a, hash);
    }

    return hash;
}
