import from c {
    def ceil(value: f64) -> f64;  def floor(value: f64) -> f64;  def round(
        value: f64
    ) -> f64;  def fabs(value: f64) -> f64;  def modf(
        value: f64, whole: &mut f64
    ) -> f64;  def clock_gettime(clock: i32, value: &mut timespec) -> i32;  def clock_getres(
        clock: i32, value: &mut timespec
    ) -> i32;  def localtime_r(timep: &mut i64, result: ptr[tm]) -> ptr[tm];  def gmtime_r(
        timep: &mut i64, result: ptr[tm]
    ) -> ptr[tm];
}

glob:priv SEC_TO_MS: Final[i64] = 1000,
     MS_TO_US: Final[i64] = 1000,
     SEC_TO_US: Final[i64] = 1000000,
     US_TO_NS: Final[i64] = 1000,
     MS_TO_NS: Final[i64] = 1000000,
     SEC_TO_NS: Final[i64] = 1000000000,
     NS_TO_MS: Final[i64] = 1000000,
     NS_TO_US: Final[i64] = 1000,
     PyTime_MAX: Final[i64] = 9223372036854775807,
     PyTime_MIN: Final[i64] = -9223372036854775807 - 1,
     PY_TIME_T_MAX: Final[i64] = 9223372036854775807,
     PY_TIME_T_MIN: Final[i64] = -9223372036854775807 - 1,
     _PyTime_ROUND_UP: Final[i32] = 3;

def pytime_div(a: i64, b: i64) -> i64;

def pytime_rem(a: i64, b: i64) -> i64;

def _PyTime_GCD(x: i64, y: i64) -> i64;

def pytime_time_t_overflow;

def pytime_overflow;

def pytime_add(t1: i64, t2: i64) -> tuple[i32, i64];

def pytime_mul_check_overflow(a: i64, b: i64) -> bool;

def pytime_mul(t: i64, k: i64) -> tuple[i32, i64];

def _PyTime_Mul(t: i64, k: i64) -> i64;

def _PyTime_AsTime_t(t: i64) -> tuple[i32, i64];

def pytime_round_half_even(x: f64) -> f64;

def pytime_round(x: f64, rounding: i32) -> f64;

def pytime_double_in_range(intpart: f64) -> bool;

def pytime_double_to_denominator(
    d: f64, idenominator: i64, rounding: i32
) -> tuple[i32, i64, i64];

def float_check(op: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def pytime_object_to_denominator(
    obj_: ptr[PyObject],
    sec: ptr[i64],
    numerator: ptr[i64],
    denominator: i64,
    rounding: i32
) -> i32;

def pytime_fromtimespec(tv_sec: i64, tv_nsec: i64, raise_exc: i32) -> tuple[i32, i64];

def pytime_fromtimeval(tv_sec: i64, tv_usec: i64, raise_exc: i32) -> tuple[i32, i64];

def pytime_from_double(
    tp: ptr[i64], value: f64, rounding: i32, unit_to_ns: i64
) -> i32;

def pytime_from_object(
    tp: ptr[i64], obj_: ptr[PyObject], rounding: i32, unit_to_ns: i64
) -> i32;

def pytime_divide_round_up(t: i64, k: i64) -> i64;

def pytime_divide(t: i64, k: i64, rounding: i32) -> i64;

def pytime_divmod(t: i64, k: i64) -> tuple[i32, i64, i64];

def pytime_as_timeval(ns: i64, rounding: i32) -> tuple[i32, i64, i32];

def pytime_as_timeval_struct(
    t: i64, tv: ptr[timeval], rounding: i32, raise_exc: i32
) -> i32;

def pytime_as_timespec(ns: i64, ts: ptr[timespec], raise_exc: i32) -> i32;

def runtime_time_base -> ptr[_PyTimeFraction];

def py_get_system_clock(
    info: ptr[_Py_clock_info_t], raise_exc: i32
) -> tuple[i32, i64, bool];

def pytime_system(raise_exc: i32) -> tuple[i32, i64];

def pytime_time(result: ptr[i64], raise_exc: i32) -> i32;

def py_get_monotonic_clock(
    info: ptr[_Py_clock_info_t], raise_exc: i32
) -> tuple[i32, i64, bool];

def pytime_monotonic(raise_exc: i32) -> tuple[i32, i64];

def pytime_monotonic_into(result: ptr[i64], raise_exc: i32) -> i32;

def pytime_clock_with_info(
    tp: ptr[i64], info: ptr[_Py_clock_info_t], monotonic: bool
) -> i32;

def pytime_fraction_resolution(frac: ptr[_PyTimeFraction]) -> f64;

def pytime_fraction_mul(ticks: i64, frac: ptr[_PyTimeFraction]) -> i64;

def pytime_deadline_init(timeout: i64) -> i64;

def pytime_deadline_get(deadline: i64) -> i64;

def pytime_from_microseconds_clamp(us: i64) -> i64;

def pytime_as_microseconds(ns: i64, rounding: i32) -> i64;

import from c {
    def _PyTimeFraction_Set(frac: ptr[_PyTimeFraction], numer: i64, denom: i64) -> i32 {
        if numer < 1 or denom < 1 {
            return -1;
        }
        gcd = _PyTime_GCD(numer, denom);
        frac.view(1)[0].numer = numer // gcd;
        frac.view(1)[0].denom = denom // gcd;
        return 0;
    }  def _PyTimeFraction_Resolution(frac: ptr[_PyTimeFraction]) -> f64 {
        return pytime_fraction_resolution(frac);
    }  def _PyTime_Add(t1: i64, t2: i64) -> i64 {
        (status, total) = pytime_add(t1, t2);
        return total;
    }  def _PyTimeFraction_Mul(ticks: i64, frac: ptr[_PyTimeFraction]) -> i64 {
        return pytime_fraction_mul(ticks, frac);
    }  def _PyLong_AsTime_t(obj_: ptr[PyObject]) -> i64 {
        val = PyLong_AsLongLong(obj_);
        if val == -1 and PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_OverflowError) {
                pytime_time_t_overflow();
            }
            return -1;
        }
        return val;
    }  def _PyLong_FromTime_t(t: i64) -> ptr[PyObject] {
        return PyLong_FromLongLong(t);
    }  def _PyTime_ObjectToTime_t(
        obj_: ptr[PyObject], sec: ptr[i64], rounding: i32
    ) -> i32 {
        if float_check(obj_) {
            d = PyFloat_AsDouble(obj_);
            if d != d {
                PyErr_SetString(
                    PyExc_ValueError, ptr[u8]("Invalid value NaN (not a number)")
                );
                return -1;
            }

            d = pytime_round(d, rounding);
            intpart: f64 = 0.0;
            modf(d, &mut intpart);

            if not pytime_double_in_range(intpart) {
                pytime_time_t_overflow();
                return -1;
            }
            sec.view(1)[0] = i64(intpart);
            return 0;
        }
        value = _PyLong_AsTime_t(obj_);
        sec.view(1)[0] = value;
        if value == -1 and PyErr_Occurred() {
            return -1;
        }
        return 0;
    }  def _PyTime_ObjectToTimespec(
        obj_: ptr[PyObject], sec: ptr[i64], nsec: ptr[i64], rounding: i32
    ) -> i32 {
        return pytime_object_to_denominator(obj_, sec, nsec, SEC_TO_NS, rounding);
    }  def _PyTime_ObjectToTimeval(
        obj_: ptr[PyObject], sec: ptr[i64], usec: ptr[i64], rounding: i32
    ) -> i32 {
        return pytime_object_to_denominator(obj_, sec, usec, SEC_TO_US, rounding);
    }  def _PyTime_FromSeconds(seconds: i32) -> i64 {
        return i64(seconds) * SEC_TO_NS;
    }  def _PyTime_FromMicrosecondsClamp(us: i64) -> i64 {
        return pytime_from_microseconds_clamp(us);
    }  def _PyTime_FromLong(tp: ptr[i64], obj_: ptr[PyObject]) -> i32 {
        if not long_check(obj_) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("expect int, got %s"),
                object_type(obj_).view(1)[0].tp_name
            );
            return -1;
        }

        nsec = PyLong_AsLongLong(obj_);
        if nsec == -1 and PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_OverflowError) {
                pytime_overflow();
            }
            return -1;
        }
        tp.view(1)[0] = nsec;
        return 0;
    }  def _PyTime_FromTimespec(tp: ptr[i64], ts: ptr[timespec]) -> i32 {
        (status, value) = pytime_fromtimespec(
            ts.view(1)[0].tv_sec, ts.view(1)[0].tv_nsec, 1
        );
        tp.view(1)[0] = value;
        return status;
    }  def _PyTime_FromTimeval(tp: ptr[i64], tv: ptr[timeval]) -> i32 {
        (status, value) = pytime_fromtimeval(
            tv.view(1)[0].tv_sec, i64(tv.view(1)[0].tv_usec), 1
        );
        tp.view(1)[0] = value;
        return status;
    }  def _PyTime_FromSecondsObject(
        tp: ptr[i64], obj_: ptr[PyObject], rounding: i32
    ) -> i32 {
        return pytime_from_object(tp, obj_, rounding, SEC_TO_NS);
    }  def _PyTime_FromMillisecondsObject(
        tp: ptr[i64], obj_: ptr[PyObject], rounding: i32
    ) -> i32 {
        return pytime_from_object(tp, obj_, rounding, MS_TO_NS);
    }  def PyTime_AsSecondsDouble(ns: i64) -> f64 {
        d: f64 = 0.0;
        if ns % SEC_TO_NS == 0 {
            secs = pytime_div(ns, SEC_TO_NS);
            d = f64(secs);
        } else {
            d = f64(ns);
            d = d / 1e9;
        }
        return d;
    }  def _PyTime_AsLong(ns: i64) -> ptr[PyObject] {
        return PyLong_FromLongLong(ns);
    }  def _PyTime_FromSecondsDouble(
        seconds: f64, rounding: i32, result: ptr[i64]
    ) -> i32 {
        return pytime_from_double(result, seconds, rounding, SEC_TO_NS);
    }  def _PyTime_AsMicroseconds(ns: i64, rounding: i32) -> i64 {
        return pytime_as_microseconds(ns, rounding);
    }  def _PyTime_AsMilliseconds(ns: i64, rounding: i32) -> i64 {
        return pytime_divide(ns, NS_TO_MS, rounding);
    }  def _PyTime_AsTimeval(t: i64, tv: ptr[timeval], rounding: i32) -> i32 {
        return pytime_as_timeval_struct(t, tv, rounding, 1);
    }  def _PyTime_AsTimeval_clamp(t: i64, tv: ptr[timeval], rounding: i32) {
        pytime_as_timeval_struct(t, tv, rounding, 0);
    }  def _PyTime_AsTimevalTime_t(
        t: i64, p_secs: ptr[i64], us: ptr[i32], rounding: i32
    ) -> i32 {
        (res, secs, usec) = pytime_as_timeval(t, rounding);
        us.view(1)[0] = usec;
        if res < 0 {
            pytime_time_t_overflow();
            return -1;
        }

        (res2, value) = _PyTime_AsTime_t(secs);
        p_secs.view(1)[0] = value;
        if res2 < 0 {
            pytime_time_t_overflow();
            return -1;
        }
        return 0;
    }  def _PyTime_AsTimespec_clamp(t: i64, ts: ptr[timespec]) {
        pytime_as_timespec(t, ts, 0);
    }  def _PyTime_AsTimespec(t: i64, ts: ptr[timespec]) -> i32 {
        return pytime_as_timespec(t, ts, 1);
    }  def PyTime_Time(result: ptr[i64]) -> i32 {
        return pytime_time(result, 1);
    }  def PyTime_TimeRaw(result: ptr[i64]) -> i32 {
        return pytime_time(result, 0);
    }  def _PyTime_TimeWithInfo(t: ptr[i64], info: ptr[_Py_clock_info_t]) -> i32 {
        return pytime_clock_with_info(t, info, False);
    }  def _PyTime_Init(state: ptr[u8]) -> PyStatus {
        if PYTIME_MACH_CLOCK != 0 {
            (numer, denom) = mach_timebase();
            if numer < 1 or denom < 1 {
                return PyStatus(
                    _type=_PyStatus_TYPE_ERROR,
                    func=ptr[u8]("_PyTime_Init"),
                    err_msg=ptr[u8]("invalid mach_timebase_info"),
                    exitcode=0
                );
            }
            base = ptr[_PyTimeFraction](state);
            gcd = _PyTime_GCD(numer, denom);
            base.view(1)[0].numer = numer // gcd;
            base.view(1)[0].denom = denom // gcd;
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def PyTime_Monotonic(result: ptr[i64]) -> i32 {
        return pytime_monotonic_into(result, 1);
    }  def PyTime_MonotonicRaw(result: ptr[i64]) -> i32 {
        return pytime_monotonic_into(result, 0);
    }  def _PyTime_MonotonicWithInfo(tp: ptr[i64], info: ptr[_Py_clock_info_t]) -> i32 {
        return pytime_clock_with_info(tp, info, True);
    }  def _PyTime_PerfCounterWithInfo(
        t: ptr[i64], info: ptr[_Py_clock_info_t]
    ) -> i32 {
        return pytime_clock_with_info(t, info, True);
    }  def PyTime_PerfCounter(result: ptr[i64]) -> i32 {
        return pytime_monotonic_into(result, 1);
    }  def PyTime_PerfCounterRaw(result: ptr[i64]) -> i32 {
        return pytime_monotonic_into(result, 0);
    }  def _PyTime_localtime(t: i64, tm_: ptr[tm]) -> i32 {
        when = t;
        jacpy_set_errno(0);
        if not localtime_r(&mut when, tm_) {
            if jacpy_errno() == 0 {
                jacpy_set_errno(i64(EINVAL));
            }
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        return 0;
    }  def _PyTime_gmtime(t: i64, tm_: ptr[tm]) -> i32 {
        when = t;
        if not gmtime_r(&mut when, tm_) {
            if jacpy_errno() == 0 {
                jacpy_set_errno(i64(EINVAL));
            }
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        return 0;
    }  def _PyDeadline_Init(timeout: i64) -> i64 {
        return pytime_deadline_init(timeout);
    }  def _PyDeadline_Get(deadline: i64) -> i64 {
        return pytime_deadline_get(deadline);
    }
}

impl pytime_div(a: i64, b: i64) -> i64 {
    q = a // b;
    if (a % b) != 0 and ((a < 0) != (b < 0)) {
        q = q + 1;
    }
    return q;
}

impl pytime_rem(a: i64, b: i64) -> i64 {
    r = a % b;
    if r != 0 and ((a < 0) != (b < 0)) {
        r = r - b;
    }
    return r;
}

impl _PyTime_GCD(x: i64, y: i64) -> i64 {
    while y != 0 {
        tmp = y;
        y = x % y;
        x = tmp;
    }
    return x;
}

impl pytime_time_t_overflow {
    PyErr_SetString(
        PyExc_OverflowError, ptr[u8]("timestamp out of range for platform time_t")
    );
}

impl pytime_overflow {
    PyErr_SetString(
        PyExc_OverflowError, ptr[u8]("timestamp too large to convert to C PyTime_t")
    );
}

impl pytime_add(t1: i64, t2: i64) -> tuple[i32, i64] {
    if t2 > 0 and t1 > PyTime_MAX - t2 {
        return (i32(-1), PyTime_MAX);
    } elif t2 < 0 and t1 < PyTime_MIN - t2 {
        return (i32(-1), PyTime_MIN);
    }
    return (i32(0), t1 + t2);
}

impl pytime_mul_check_overflow(a: i64, b: i64) -> bool {
    if b != 0 {
        return a < pytime_div(PyTime_MIN, b) or pytime_div(PyTime_MAX, b) < a;
    }
    return False;
}

impl pytime_mul(t: i64, k: i64) -> tuple[i32, i64] {
    if pytime_mul_check_overflow(t, k) {
        if t >= 0 {
            return (i32(-1), PyTime_MAX);
        }
        return (i32(-1), PyTime_MIN);
    }
    return (i32(0), t * k);
}

impl _PyTime_Mul(t: i64, k: i64) -> i64 {
    (status, product) = pytime_mul(t, k);
    return product;
}

impl _PyTime_AsTime_t(t: i64) -> tuple[i32, i64] {
    return (i32(0), t);
}

impl pytime_round_half_even(x: f64) -> f64 {
    rounded = round(x);
    if fabs(x - rounded) == 0.5 {
        rounded = 2.0 * round(x / 2.0);
    }
    return rounded;
}

impl pytime_round(x: f64, rounding: i32) -> f64 {
    d = x;
    if rounding == _PyTime_ROUND_HALF_EVEN {
        d = pytime_round_half_even(d);
    } elif rounding == _PyTime_ROUND_CEILING {
        d = ceil(d);
    } elif rounding == _PyTime_ROUND_FLOOR {
        d = floor(d);
    } else {
        if d >= 0.0 {
            d = ceil(d);
        } else {
            d = floor(d);
        }
    }
    return d;
}

impl pytime_double_in_range(intpart: f64) -> bool {
    lowest = f64(PY_TIME_T_MIN);
    return lowest <= intpart and intpart < -lowest;
}

impl pytime_double_to_denominator(
    d: f64, idenominator: i64, rounding: i32
) -> tuple[i32, i64, i64] {
    denominator = f64(idenominator);
    intpart: f64 = 0.0;
    floatpart = modf(d, &mut intpart);

    floatpart = floatpart * denominator;
    floatpart = pytime_round(floatpart, rounding);
    if floatpart >= denominator {
        floatpart = floatpart - denominator;
        intpart = intpart + 1.0;
    } elif floatpart < 0.0 {
        floatpart = floatpart + denominator;
        intpart = intpart - 1.0;
    }

    if not pytime_double_in_range(intpart) {
        pytime_time_t_overflow();
        return (i32(-1), i64(0), i64(0));
    }
    return (i32(0), i64(intpart), i64(floatpart));
}

impl float_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyFloat_Type)));
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl pytime_object_to_denominator(
    obj_: ptr[PyObject],
    sec: ptr[i64],
    numerator: ptr[i64],
    denominator: i64,
    rounding: i32
) -> i32 {
    if float_check(obj_) {
        d = PyFloat_AsDouble(obj_);
        if d != d {
            numerator.view(1)[0] = 0;
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Invalid value NaN (not a number)")
            );
            return -1;
        }
        (status, whole, part) = pytime_double_to_denominator(d, denominator, rounding);
        if status < 0 {
            return -1;
        }
        sec.view(1)[0] = whole;
        numerator.view(1)[0] = part;
        return 0;
    }
    value = _PyLong_AsTime_t(obj_);
    sec.view(1)[0] = value;
    numerator.view(1)[0] = 0;
    if value == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_TypeError) {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("argument must be int or float, not %T"), obj_
            );
        }
        return -1;
    }
    return 0;
}

impl pytime_fromtimespec(tv_sec: i64, tv_nsec: i64, raise_exc: i32) -> tuple[i32, i64] {
    (res1, t) = pytime_mul(tv_sec, SEC_TO_NS);
    (res2, total) = pytime_add(t, tv_nsec);
    if raise_exc != 0 and (res1 < 0 or res2 < 0) {
        pytime_overflow();
        return (i32(-1), total);
    }
    return (i32(0), total);
}

impl pytime_fromtimeval(tv_sec: i64, tv_usec: i64, raise_exc: i32) -> tuple[i32, i64] {
    (res1, t) = pytime_mul(tv_sec, SEC_TO_NS);
    usec = tv_usec * US_TO_NS;
    (res2, total) = pytime_add(t, usec);
    if raise_exc != 0 and (res1 < 0 or res2 < 0) {
        pytime_overflow();
        return (i32(-1), total);
    }
    return (i32(0), total);
}

impl pytime_from_double(
    tp: ptr[i64], value: f64, rounding: i32, unit_to_ns: i64
) -> i32 {
    d = value;
    d = d * f64(unit_to_ns);
    d = pytime_round(d, rounding);

    lowest = f64(PyTime_MIN);
    if not (lowest <= d and d < -lowest) {
        pytime_time_t_overflow();
        tp.view(1)[0] = 0;
        return -1;
    }
    tp.view(1)[0] = i64(d);
    return 0;
}

impl pytime_from_object(
    tp: ptr[i64], obj_: ptr[PyObject], rounding: i32, unit_to_ns: i64
) -> i32 {
    if float_check(obj_) {
        d = PyFloat_AsDouble(obj_);
        if d != d {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("Invalid value NaN (not a number)")
            );
            return -1;
        }
        return pytime_from_double(tp, d, rounding, unit_to_ns);
    }

    sec = PyLong_AsLongLong(obj_);
    if sec == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_OverflowError) {
            pytime_overflow();
        } elif PyErr_ExceptionMatches(PyExc_TypeError) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%T' object cannot be interpreted as an integer or float"),
                obj_
            );
        }
        return -1;
    }

    (status, ns) = pytime_mul(sec, unit_to_ns);
    if status < 0 {
        pytime_overflow();
        return -1;
    }
    tp.view(1)[0] = ns;
    return 0;
}

impl pytime_divide_round_up(t: i64, k: i64) -> i64 {
    if t >= 0 {
        q = pytime_div(t, k);
        if pytime_rem(t, k) != 0 {
            q = q + 1;
        }
        return q;
    }
    q = pytime_div(t, k);
    if pytime_rem(t, k) != 0 {
        q = q - 1;
    }
    return q;
}

impl pytime_divide(t: i64, k: i64, rounding: i32) -> i64 {
    if rounding == _PyTime_ROUND_HALF_EVEN {
        x = pytime_div(t, k);
        r = pytime_rem(t, k);
        abs_r = r;
        if abs_r < 0 {
            abs_r = -abs_r;
        }
        abs_x = x;
        if abs_x < 0 {
            abs_x = -abs_x;
        }
        half = pytime_div(k, 2);
        if abs_r > half or (abs_r == half and (abs_x & 1) != 0) {
            if t >= 0 {
                x = x + 1;
            } else {
                x = x - 1;
            }
        }
        return x;
    } elif rounding == _PyTime_ROUND_CEILING {
        if t >= 0 {
            return pytime_divide_round_up(t, k);
        }
        return pytime_div(t, k);
    } elif rounding == _PyTime_ROUND_FLOOR {
        if t >= 0 {
            return pytime_div(t, k);
        }
        return pytime_divide_round_up(t, k);
    }
    return pytime_divide_round_up(t, k);
}

impl pytime_divmod(t: i64, k: i64) -> tuple[i32, i64, i64] {
    q = pytime_div(t, k);
    r = pytime_rem(t, k);
    if r < 0 {
        if q == PyTime_MIN {
            return (i32(-1), PyTime_MIN, i64(0));
        }
        r = r + k;
        q = q - 1;
    }
    return (i32(0), q, r);
}

impl pytime_as_timeval(ns: i64, rounding: i32) -> tuple[i32, i64, i32] {
    us = pytime_divide(ns, US_TO_NS, rounding);
    (res, tv_sec, tv_usec) = pytime_divmod(us, SEC_TO_US);
    return (res, tv_sec, i32(tv_usec));
}

impl pytime_as_timeval_struct(
    t: i64, tv: ptr[timeval], rounding: i32, raise_exc: i32
) -> i32 {
    (res, tv_sec, tv_usec) = pytime_as_timeval(t, rounding);
    (res2, secs) = _PyTime_AsTime_t(tv_sec);
    if res2 < 0 {
        tv_usec = 0;
    }
    timeval_store(tv, secs, i64(tv_usec));

    if raise_exc != 0 and (res < 0 or res2 < 0) {
        pytime_time_t_overflow();
        return -1;
    }
    return 0;
}

impl pytime_as_timespec(ns: i64, ts: ptr[timespec], raise_exc: i32) -> i32 {
    (res, tv_sec, tv_nsec) = pytime_divmod(ns, SEC_TO_NS);
    (res2, secs) = _PyTime_AsTime_t(tv_sec);
    ts.view(1)[0].tv_sec = secs;
    if res2 < 0 {
        tv_nsec = 0;
    }
    ts.view(1)[0].tv_nsec = tv_nsec;

    if raise_exc != 0 and (res < 0 or res2 < 0) {
        pytime_time_t_overflow();
        return -1;
    }
    return 0;
}

impl runtime_time_base -> ptr[_PyTimeFraction] {
    return ptr[_PyTimeFraction](ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_TIME);
}

impl py_get_system_clock(
    info: ptr[_Py_clock_info_t], raise_exc: i32
) -> tuple[i32, i64, bool] {
    ts: own timespec = timespec();
    err = clock_gettime(CLOCK_REALTIME, &mut ts);
    if err != 0 {
        if raise_exc != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
        }
        return (i32(-1), i64(0), False);
    }
    (status, value) = pytime_fromtimespec(ts.tv_sec, ts.tv_nsec, raise_exc);
    if status < 0 {
        return (i32(-1), value, True);
    }

    if info {
        res: own timespec = timespec();
        info.view(1)[0].implementation = ptr[u8]("clock_gettime(CLOCK_REALTIME)");
        info.view(1)[0].monotonic = 0;
        info.view(1)[0].adjustable = 1;
        if clock_getres(CLOCK_REALTIME, &mut res) == 0 {
            info.view(1)[0].resolution = f64(res.tv_sec) + f64(res.tv_nsec) * 1e-9;
        } else {
            info.view(1)[0].resolution = 1e-9;
        }
    }
    return (i32(0), value, True);
}

impl pytime_system(raise_exc: i32) -> tuple[i32, i64] {
    (status, value, written) = py_get_system_clock(ptr[_Py_clock_info_t](), raise_exc);
    if status < 0 {
        return (i32(-1), i64(0));
    }
    return (i32(0), value);
}

impl pytime_time(result: ptr[i64], raise_exc: i32) -> i32 {
    (status, value) = pytime_system(raise_exc);
    result.view(1)[0] = value;
    return status;
}

impl py_get_monotonic_clock(
    info: ptr[_Py_clock_info_t], raise_exc: i32
) -> tuple[i32, i64, bool] {
    if PYTIME_MACH_CLOCK != 0 {
        if info {
            info.view(1)[0].implementation = ptr[u8]("mach_absolute_time()");
            info.view(1)[0].resolution = pytime_fraction_resolution(
                runtime_time_base()
            );
            info.view(1)[0].monotonic = 1;
            info.view(1)[0].adjustable = 0;
        }
        ticks = i64(mach_ticks());
        return (i32(0), pytime_fraction_mul(ticks, runtime_time_base()), True);
    }

    ts: own timespec = timespec();
    if clock_gettime(CLOCK_MONOTONIC, &mut ts) != 0 {
        if raise_exc != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            return (i32(-1), i64(0), False);
        }
        return (i32(-1), i64(0), False);
    }

    (status, value) = pytime_fromtimespec(ts.tv_sec, ts.tv_nsec, raise_exc);
    if status < 0 {
        return (i32(-1), value, True);
    }

    if info {
        info.view(1)[0].monotonic = 1;
        info.view(1)[0].implementation = ptr[u8]("clock_gettime(CLOCK_MONOTONIC)");
        info.view(1)[0].adjustable = 0;
        res: own timespec = timespec();
        if clock_getres(CLOCK_MONOTONIC, &mut res) != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            return (i32(-1), value, True);
        }
        info.view(1)[0].resolution = f64(res.tv_sec) + f64(res.tv_nsec) * 1e-9;
    }
    return (i32(0), value, True);
}

impl pytime_monotonic(raise_exc: i32) -> tuple[i32, i64] {
    (status, value, written) = py_get_monotonic_clock(
        ptr[_Py_clock_info_t](), raise_exc
    );
    if status < 0 {
        return (i32(-1), i64(0));
    }
    return (i32(0), value);
}

impl pytime_monotonic_into(result: ptr[i64], raise_exc: i32) -> i32 {
    (status, value) = pytime_monotonic(raise_exc);
    result.view(1)[0] = value;
    return status;
}

impl pytime_clock_with_info(
    tp: ptr[i64], info: ptr[_Py_clock_info_t], monotonic: bool
) -> i32 {
    if monotonic {
        (status, value, written) = py_get_monotonic_clock(info, 1);
        if written {
            tp.view(1)[0] = value;
        }
        return status;
    }
    (sys_status, sys_value, sys_written) = py_get_system_clock(info, 1);
    if sys_written {
        tp.view(1)[0] = sys_value;
    }
    return sys_status;
}

impl pytime_fraction_resolution(frac: ptr[_PyTimeFraction]) -> f64 {
    return f64(frac.view(1)[0].numer) / f64(frac.view(1)[0].denom) / 1e9;
}

impl pytime_fraction_mul(ticks: i64, frac: ptr[_PyTimeFraction]) -> i64 {
    mul = frac.view(1)[0].numer;
    div = frac.view(1)[0].denom;

    if div == 1 {
        return _PyTime_Mul(ticks, mul);
    }

    intpart = pytime_div(ticks, div);
    rest = pytime_rem(ticks, div);
    remaining = pytime_div(_PyTime_Mul(rest, mul), div);
    (status, total) = pytime_add(_PyTime_Mul(intpart, mul), remaining);
    return total;
}

impl pytime_deadline_init(timeout: i64) -> i64 {
    (status, now) = pytime_monotonic(0);
    (overflow, deadline) = pytime_add(now, timeout);
    return deadline;
}

impl pytime_deadline_get(deadline: i64) -> i64 {
    (status, now) = pytime_monotonic(0);
    return deadline - now;
}

impl pytime_from_microseconds_clamp(us: i64) -> i64 {
    return _PyTime_Mul(us, US_TO_NS);
}

impl pytime_as_microseconds(ns: i64, rounding: i32) -> i64 {
    return pytime_divide(ns, NS_TO_US, rounding);
}
