"""Time access and conversions.

Derived from CPython 3.14.6 Modules/timemodule.c; see ../LICENSE.cpython.
Clock arithmetic stays in CPython's Python/pytime.c, called by its _PyTime_*
names. The C records come from time_records.<os>.jac, the clock identifiers
from time_constants.<os>.jac, and clock_nanosleep()/pthread_getcpuclockid(),
which only some systems have, from time_platform.<os>.jac. The C library's
tm_zone and tm_gmtoff fields are always present, so the zone names are read
from localtime() as CPython does without a usable tzname declaration.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_clear_errno,
    jacpy_errno,
    jacpy_is_tuple,
    jacpy_release,
    jacpy_set_errno,
    NULL,
    _Py_clock_info_t,
    _Py_GetTicksPerSecond,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    _PyArg_CheckPositional,
    PyDict_New,
    PyDict_SetItemString,
    PyErr_CheckSignals,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFloat_FromDouble,
    PyImport_ImportModule,
    PyImport_ImportModuleAttrString,
    PyLong_AsInt,
    PyLong_AsLong,
    PyLong_FromLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_Realloc,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyObject_Call,
    PySys_AuditTuple,
    _PyTime_Add,
    _PyTime_AsLong,
    PyTime_AsSecondsDouble,
    _PyTime_AsTimespec,
    _PyTime_FromLong,
    _PyTime_FromSecondsObject,
    _PyTime_FromTimespec,
    _PyTime_FromTimeval,
    _PyTime_gmtime,
    _PyTime_localtime,
    PyTime_Monotonic,
    _PyTime_MonotonicWithInfo,
    _PyTime_ObjectToTime_t,
    PyTime_PerfCounter,
    _PyTime_PerfCounterWithInfo,
    PyTime_Time,
    _PyTime_TimeWithInfo,
    _PyTimeFraction,
    _PyTimeFraction_Mul,
    _PyTimeFraction_Resolution,
    _PyTimeFraction_Set,
    PyTuple_GetItem,
    PyTuple_Size,
    PyUnicode_AsUTF8,
    PyUnicode_DecodeLocale,
    PyUnicode_FromString,
    PyUnicode_FromWideChar,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    PyUnicodeWriter_Create,
    PyUnicodeWriter_Discard,
    PyUnicodeWriter_Finish,
    PyUnicodeWriter_WriteStr,
    PyUnicodeWriter_WriteSubstring
}
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_GetItem,
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_text,
    object_error,
    object_tuple,
    text_value,
    type_name
}
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.time_records { timespec, timeval, tm, tms }
import from jaclang.runtime.python.modules.resource_records { rusage }
import from jaclang.runtime.python.modules.time_constants {
    CLOCK_MONOTONIC,
    CLOCK_PROCESS_CPUTIME_ID,
    CLOCK_THREAD_CPUTIME_ID,
    CLOCKS_PER_SEC,
    TIMER_ABSTIME
}
import from jaclang.runtime.python.modules.time_platform {
    HAS_CLOCK_NANOSLEEP,
    clock_nanosleep,
    pthread_getcpuclockid
}
import from jaclang.runtime.python.modules.errno_constants { EINTR }
import from jaclang.runtime.python.object_model.namespace { _PyNamespace_New }
import from c {
    def clock -> i64;  def clock_gettime(clock: i32, value: &mut timespec) -> i32;  def clock_settime(
        clock: i32, value: &timespec
    ) -> i32;  def clock_getres(clock: i32, value: &mut timespec) -> i32;  def times(
        buffer: &mut tms
    ) -> i64;  def getrusage(who: i32, usage: &mut rusage) -> i32;  def nanosleep(
        request: &timespec, remain: ptr
    ) -> i32;  def mktime(value: &mut tm) -> i64;  def tzset;  def wcsftime(
        output: ptr[i32], size: u64, format: ptr[i32], value: &tm
    ) -> u64;
}
import from c { def time(result: ptr) -> i64;  }

# The error handler tm_zone decodes with, as a C string for the process.

glob:priv SEC_TO_NS: i64 = 1000000000,
     INT_MAX: int = 2147483647,
     INT_MIN: int = -2147483648,
     SSIZE_MAX: int = 0x7FFFFFFFFFFFFFFF,
     ROUND_FLOOR: i32 = 0,
     ROUND_TIMEOUT: i32 = 3,
     RUSAGE_SELF: i32 = 0,
     WCHAR_SIZE: int = 4,
     MAX_TIMEZONE: int = 48 * 3600,
     # A year of 365.25 days: init_timezone() samples January and July.
     YEAR: int = (365 * 24 + 6) * 3600,
     WEEKDAY_NAMES: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     MONTH_NAMES: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

# The times() and clock() tick frequencies, set once by time_exec().
glob:priv times_base: _PyTimeFraction = _PyTimeFraction(),
     clock_base: _PyTimeFraction = _PyTimeFraction();

# The fields of _Py_clock_info_t, as Jac values.
obj ClockInfo {
    has implementation: str = "",
        monotonic: bool = False,
        adjustable: bool = False,
        resolution: f64 = 1.0;
}

def:priv os_error -> ptr[PyObject] {
    PyErr_SetFromErrno(PyExc_OSError);
    return NULL;
}

def:priv float_from_time(t: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(PyTime_AsSecondsDouble(t));
}

def:priv timespec_seconds(value: timespec) -> f64 {
    return f64(value.tv_sec) + f64(value.tv_nsec) * 1e-9;
}

# C's `%`: the remainder takes the dividend's sign.
def:priv c_remainder(value: int, divisor: int) -> int {
    rest = abs(value) % divisor;
    return -rest if value < 0 else rest;
}

def:priv audit(event: str, value: ptr[PyObject]) -> bool {
    arguments = object_tuple([value]);
    status = PySys_AuditTuple(event, arguments);
    jacpy_release(arguments);
    return status >= 0;
}

# The struct_time type of `module`, borrowed from the module state.
def:priv struct_time_type(module: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, 0);
}

def time_time(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_Time(&mut t) < 0 {
        return NULL;
    }
    return float_from_time(t);
}

def time_time_ns(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_Time(&mut t) < 0 {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

# py_clock(): whether clock() works, and its reading.
def:priv py_clock(info: ClockInfo | None) -> tuple[bool, i64] {
    if info is not None {
        info.implementation = "clock()";
        info.resolution = _PyTimeFraction_Resolution(&clock_base);
        info.monotonic = True;
        info.adjustable = False;
    }
    ticks = clock();
    if ticks == -1 {
        object_error(
            PyExc_RuntimeError,
            "the processor time used is not available or its value cannot be represented"
        );
        return (False, 0);
    }
    return (True, _PyTimeFraction_Mul(ticks, &clock_base));
}

# time_clockid_converter(): any int that fits a C int.
def convert_time_clockid_converter(
    value: ptr[PyObject], fname: str, label: str
) -> i32 {
    clk_id = PyLong_AsInt(value);
    if clk_id == -1 and PyErr_Occurred() {
        object_error(
            PyExc_TypeError,
            f"clk_id should be integer, not {type_name(value).rsplit('.', 1)[-1]}"
        );
        raise boundary_failure();
    }
    return clk_id;
}

def time_clock_gettime_impl(module: ptr[PyObject], clk_id: i32) -> ptr[PyObject] {
    tp = timespec();
    if clock_gettime(clk_id, &mut tp) != 0 {
        return os_error();
    }
    return PyFloat_FromDouble(timespec_seconds(tp));
}

def time_clock_gettime_ns_impl(module: ptr[PyObject], clk_id: i32) -> ptr[PyObject] {
    ts = timespec();
    if clock_gettime(clk_id, &mut ts) != 0 {
        return os_error();
    }
    t: i64 = 0;
    if _PyTime_FromTimespec(&mut t, &ts) < 0 {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

def time_clock_settime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="clock_settime").parse(args, "iO");
        clk_id = i32(values[0].signed);
        t: i64 = 0;
        if _PyTime_FromSecondsObject(&mut t, values[1].object, ROUND_FLOOR) < 0 {
            return NULL;
        }
        tp = timespec();
        if _PyTime_AsTimespec(t, &mut tp) == -1 {
            return NULL;
        }
        if clock_settime(clk_id, &tp) != 0 {
            return os_error();
        }
        return Py_NewRef(borrowed_none());
    } except boundary_failure {
        return NULL;
    }
}

def time_clock_settime_ns(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="clock_settime").parse(args, "iO");
        clk_id = i32(values[0].signed);
        t: i64 = 0;
        if _PyTime_FromLong(&mut t, values[1].object) < 0 {
            return NULL;
        }
        ts = timespec();
        if _PyTime_AsTimespec(t, &mut ts) == -1 {
            return NULL;
        }
        if clock_settime(clk_id, &ts) != 0 {
            return os_error();
        }
        return Py_NewRef(borrowed_none());
    } except boundary_failure {
        return NULL;
    }
}

def time_clock_getres(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        clk_id = i32(ArgumentFormat(name="clock_getres").parse(args, "i")[0].signed);
        tp = timespec();
        if clock_getres(clk_id, &mut tp) != 0 {
            return os_error();
        }
        return PyFloat_FromDouble(timespec_seconds(tp));
    } except boundary_failure {
        return NULL;
    }
}

def time_pthread_getcpuclockid(
    module: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        thread_id = ArgumentFormat(name="pthread_getcpuclockid").parse(args, "k")[
            0
        ].unsigned;
        clk_id: i32 = 0;
        err = pthread_getcpuclockid(thread_id, &mut clk_id);
        if err != 0 {
            jacpy_set_errno(i64(err));
            return os_error();
        }
        return PyLong_FromLong(i64(clk_id));
    } except boundary_failure {
        return NULL;
    }
}

# pysleep(): sleep `timeout` nanoseconds, resuming after signal handlers run.
def:priv pysleep(timeout: i64) -> bool {
    monotonic: i64 = 0;
    if PyTime_Monotonic(&mut monotonic) < 0 {
        return False;
    }
    deadline = _PyTime_Add(monotonic, timeout);
    timeout_abs = timespec();
    if HAS_CLOCK_NANOSLEEP and _PyTime_AsTimespec(deadline, &mut timeout_abs) < 0 {
        return False;
    }
    remaining = timeout;
    while True {
        timeout_ts = timespec();
        if not HAS_CLOCK_NANOSLEEP
            and _PyTime_AsTimespec(remaining, &mut timeout_ts) < 0 {
            return False;
        }
        ret: i32 = 0;
        err: i64 = 0;
        thread = PyEval_SaveThread();
        if HAS_CLOCK_NANOSLEEP {
            ret = clock_nanosleep(
                i32(CLOCK_MONOTONIC), i32(TIMER_ABSTIME), &timeout_abs, ptr()
            );
            err = i64(ret);
        } else {
            ret = nanosleep(&timeout_ts, ptr());
            err = jacpy_errno();
        }
        PyEval_RestoreThread(thread);
        if ret == 0 {
            break;
        }
        if err != EINTR {
            jacpy_set_errno(err);
            os_error();
            return False;
        }
        if PyErr_CheckSignals() != 0 {
            return False;
        }
        if not HAS_CLOCK_NANOSLEEP {
            if PyTime_Monotonic(&mut monotonic) < 0 {
                return False;
            }
            remaining = deadline - monotonic;
            if remaining < 0 {
                break;
            }
        }
    }
    return True;
}

def time_sleep(module: ptr[PyObject], timeout_obj: ptr[PyObject]) -> ptr[PyObject] {
    if not audit("time.sleep", timeout_obj) {
        return NULL;
    }
    timeout: i64 = 0;
    if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, ROUND_TIMEOUT) != 0 {
        return NULL;
    }
    if timeout < 0 {
        object_error(PyExc_ValueError, "sleep length must be non-negative");
        return NULL;
    }
    if not pysleep(timeout) {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

# tmtotuple(): a struct_time from a struct tm.
def:priv tmtotuple(module: ptr[PyObject], p: tm) -> ptr[PyObject] {
    v = PyStructSequence_New(struct_time_type(module));
    if not v {
        return NULL;
    }
    items = [
        PyLong_FromLong(i64(p.tm_year) + 1900),
        PyLong_FromLong(i64(p.tm_mon) + 1),
        PyLong_FromLong(i64(p.tm_mday)),
        PyLong_FromLong(i64(p.tm_hour)),
        PyLong_FromLong(i64(p.tm_min)),
        PyLong_FromLong(i64(p.tm_sec)),
        PyLong_FromLong(c_remainder(int(p.tm_wday) + 6, 7)),
        PyLong_FromLong(i64(p.tm_yday) + 1),
        PyLong_FromLong(i64(p.tm_isdst)),
        PyUnicode_DecodeLocale(ptr(p.tm_zone), ptr[u8]("surrogateescape")),
        PyLong_FromLong(p.tm_gmtoff)
    ];
    failed = False;
    for index in range(len(items)) {
        if items[index] {
            PyStructSequence_SetItem(v, i64(index), items[index]);
        } else {
            failed = True;
        }
    }
    if failed {
        jacpy_release(v);
        return NULL;
    }
    return v;
}

# parse_time_t_args(): an optional seconds argument, the current time when
# absent or None.
def:priv parse_time_t_args(args: ptr[PyObject], name: str) -> i64 {
    ot = ArgumentFormat(name=name).parse(args, "|O")[0];
    if not ot.given or ot.object == Py_None {
        return time(ptr());
    }
    whent: i64 = 0;
    if _PyTime_ObjectToTime_t(ot.object, &mut whent, ROUND_FLOOR) == -1 {
        raise boundary_failure();
    }
    return whent;
}

def time_gmtime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        when = parse_time_t_args(args, "gmtime");
        buf = tm();
        jacpy_clear_errno();
        if _PyTime_gmtime(when, &mut buf) != 0 {
            return NULL;
        }
        return tmtotuple(module, buf);
    } except boundary_failure {
        return NULL;
    }
}

def time_localtime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        when = parse_time_t_args(args, "localtime");
        buf = tm();
        if _PyTime_localtime(when, &mut buf) != 0 {
            return NULL;
        }
        return tmtotuple(module, buf);
    } except boundary_failure {
        return NULL;
    }
}

# gettmarg(): a 9-item tuple or struct_time as a struct tm. `message` is the
# text PyArg_ParseTuple() reports for a malformed tuple.
def:priv gettmarg(
    module: ptr[PyObject], args: ptr[PyObject], p: &mut tm, message: str
) {
    if jacpy_is_tuple(args) == 0 {
        object_error(PyExc_TypeError, "Tuple or struct_time argument required");
        raise boundary_failure();
    }
    values = [
        v.signed for v in ArgumentFormat(message=message).parse(args, "iiiiiiiii")
    ];
    y = int(values[0]);
    if y < INT_MIN + 1900 {
        object_error(PyExc_OverflowError, "year out of range");
        raise boundary_failure();
    }
    p.tm_year = i32(y - 1900);
    p.tm_mon = i32.wrap(int(values[1]) - 1);
    p.tm_mday = i32(values[2]);
    p.tm_hour = i32(values[3]);
    p.tm_min = i32(values[4]);
    p.tm_sec = i32(values[5]);
    p.tm_wday = i32(c_remainder(int(i32.wrap(int(values[6]) + 1)), 7));
    p.tm_yday = i32.wrap(int(values[7]) - 1);
    p.tm_isdst = i32(values[8]);
    if Py_TYPE(args) == struct_time_type(module) {
        item = PyStructSequence_GetItem(args, 9);
        if item != Py_None {
            p.tm_zone = PyUnicode_AsUTF8(item);
            if p.tm_zone.is_null() {
                raise boundary_failure();
            }
        }
        item = PyStructSequence_GetItem(args, 10);
        if item != Py_None {
            p.tm_gmtoff = PyLong_AsLong(item);
            if PyErr_Occurred() {
                raise boundary_failure();
            }
        }
    }
}

# checktm(): the field ranges strftime() and asctime() index tables by; a
# zero month, day of month or day of year selects the first.
def:priv checktm(buf: &mut tm) {
    failure = "";
    if buf.tm_mon == -1 {
        buf.tm_mon = 0;
    } elif buf.tm_mon < 0 or buf.tm_mon > 11 {
        failure = "month out of range";
    }
    if not failure {
        if buf.tm_mday == 0 {
            buf.tm_mday = 1;
        } elif buf.tm_mday < 0 or buf.tm_mday > 31 {
            failure = "day of month out of range";
        }
    }
    if not failure and (buf.tm_hour < 0 or buf.tm_hour > 23) {
        failure = "hour out of range";
    }
    if not failure and (buf.tm_min < 0 or buf.tm_min > 59) {
        failure = "minute out of range";
    }
    if not failure and (buf.tm_sec < 0 or buf.tm_sec > 61) {
        failure = "seconds out of range";
    }
    if not failure and buf.tm_wday < 0 {
        failure = "day of week out of range";
    }
    if not failure {
        if buf.tm_yday == -1 {
            buf.tm_yday = 0;
        } elif buf.tm_yday < 0 or buf.tm_yday > 365 {
            failure = "day of year out of range";
        }
    }
    if failure {
        object_error(PyExc_ValueError, failure);
        raise boundary_failure();
    }
}

# time_strftime1(): wcsftime() into a buffer grown until the result fits or
# the buffer is 256 times the format, when an empty result is the answer.
def:priv strftime_chunk(
    output: ptr, size: int, format: ptr[i32], length: int, value: &tm
) -> tuple[ptr[PyObject], ptr, int] {
    while True {
        if size > SSIZE_MAX // WCHAR_SIZE {
            PyErr_NoMemory();
            return (NULL, output, size);
        }
        grown = PyMem_Realloc(output, u64(size * WCHAR_SIZE));
        if not grown {
            PyMem_Free(output);
            PyErr_NoMemory();
            return (NULL, ptr(), size);
        }
        output = grown;
        written = wcsftime(ptr[i32](output), u64(size), format, value);
        if written == 0 and size < 256 * length {
            size += size;
            continue;
        }
        return (PyUnicode_FromWideChar(ptr[i32](output), i64(written)), output, size);
    }
}

def time_strftime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    buf = tm();
    format_arg = NULL;
    try {
        values = ArgumentFormat(name="strftime").parse(args, "U|O");
        format_arg = values[0].object;
        if not values[1].given {
            if _PyTime_localtime(time(ptr()), &mut buf) != 0 {
                return NULL;
            }
        } else {
            gettmarg(
                module,
                values[1].object,
                &mut buf,
                "strftime(): illegal time tuple argument"
            );
            checktm(&mut buf);
        }
    } except boundary_failure {
        return NULL;
    }
    # Normalize tm_isdst in case a C library indexes %Z by it.
    if buf.tm_isdst < -1 {
        buf.tm_isdst = -1;
    } elif buf.tm_isdst > 1 {
        buf.tm_isdst = 1;
    }
    format_size = int(PyUnicode_GetLength(format_arg));
    if format_size > SSIZE_MAX // WCHAR_SIZE - 1 {
        PyErr_NoMemory();
        return NULL;
    }
    format = PyMem_Malloc(u64((format_size + 1) * WCHAR_SIZE));
    if not format {
        PyErr_NoMemory();
        return NULL;
    }
    characters = ptr[i32](format).view(format_size + 1);
    writer = PyUnicodeWriter_Create(0);
    if not writer {
        PyMem_Free(format);
        return NULL;
    }
    output = ptr();
    size = 1024;
    failed = False;
    i = 0;
    # ASCII runs go through wcsftime(); everything else, NUL included, is
    # copied through unchanged.
    while i < format_size and not failed {
        length = 0;
        while i < format_size {
            c = PyUnicode_ReadChar(format_arg, i64(i));
            if c == 0 or c > 127 {
                break;
            }
            characters[length] = i32(c);
            length += 1;
            i += 1;
        }
        if length > 0 {
            characters[length] = i32(0);
            (unicode, output, size) = strftime_chunk(
                output, size, ptr[i32](format), length, &buf
            );
            if not unicode {
                failed = True;
                break;
            }
            status = PyUnicodeWriter_WriteStr(writer, unicode);
            jacpy_release(unicode);
            if status < 0 {
                failed = True;
                break;
            }
        }
        start = i;
        while i < format_size {
            if PyUnicode_ReadChar(format_arg, i64(i)) == 37 {
                break;
            }
            i += 1;
        }
        if PyUnicodeWriter_WriteSubstring(writer, format_arg, i64(start), i64(i)) < 0 {
            failed = True;
        }
    }
    PyMem_Free(output);
    PyMem_Free(format);
    if failed {
        PyUnicodeWriter_Discard(writer);
        return NULL;
    }
    return PyUnicodeWriter_Finish(writer);
}

def time_strptime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    func = PyImport_ImportModuleAttrString("_strptime", "_strptime_time");
    if not func {
        return NULL;
    }
    result = PyObject_Call(func, args, NULL);
    jacpy_release(func);
    return result;
}

# _asctime(): "Sun Jun 20 23:21:05 1993".
def:priv asctime_text(value: tm) -> ptr[PyObject] {
    day = str(value.tm_mday);
    text = (
        f"{WEEKDAY_NAMES[value.tm_wday]} {MONTH_NAMES[value.tm_mon]}"
        + " " * max(0, 3 - len(day))
        + day
        + f" {two_digits(value.tm_hour)}:{two_digits(value.tm_min)}:{two_digits(
            value.tm_sec
        )} {1900 + int(value.tm_year)}"
    );
    return PyUnicode_FromString(text);
}

# printf's "%.2d": at least two digits after any sign.
def:priv two_digits(value: i32) -> str {
    digits = str(abs(int(value)));
    if len(digits) < 2 {
        digits = "0" + digits;
    }
    return "-" + digits if value < 0 else digits;
}

def time_asctime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    buf = tm();
    try {
        count = PyTuple_Size(args);
        if _PyArg_CheckPositional("asctime", count, 0, 1) == 0 {
            return NULL;
        }
        if count == 0 {
            if _PyTime_localtime(time(ptr()), &mut buf) != 0 {
                return NULL;
            }
        } else {
            gettmarg(
                module,
                PyTuple_GetItem(args, 0),
                &mut buf,
                "asctime(): illegal time tuple argument"
            );
            checktm(&mut buf);
        }
    } except boundary_failure {
        return NULL;
    }
    return asctime_text(buf);
}

def time_ctime(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        tt = parse_time_t_args(args, "ctime");
        buf = tm();
        if _PyTime_localtime(tt, &mut buf) != 0 {
            return NULL;
        }
        return asctime_text(buf);
    } except boundary_failure {
        return NULL;
    }
}

def time_mktime(module: ptr[PyObject], tm_tuple: ptr[PyObject]) -> ptr[PyObject] {
    value = tm();
    try {
        gettmarg(module, tm_tuple, &mut value, "mktime(): illegal time tuple argument");
    } except boundary_failure {
        return NULL;
    }
    # tm_wday is a sentinel: mktime() replaces it on success.
    value.tm_wday = -1;
    tt = mktime(&mut value);
    if tt == -1 and value.tm_wday == -1 {
        object_error(PyExc_OverflowError, "mktime argument out of range");
        return NULL;
    }
    return PyFloat_FromDouble(f64(tt));
}

def time_tzset(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    m = PyImport_ImportModule("time");
    if not m {
        return NULL;
    }
    tzset();
    if init_timezone(m) < 0 {
        return NULL;
    }
    jacpy_release(m);
    if PyErr_Occurred() {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

def time_monotonic(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_Monotonic(&mut t) < 0 {
        return NULL;
    }
    return float_from_time(t);
}

def time_monotonic_ns(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_Monotonic(&mut t) < 0 {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

def time_perf_counter(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_PerfCounter(&mut t) < 0 {
        return NULL;
    }
    return float_from_time(t);
}

def time_perf_counter_ns(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    t: i64 = 0;
    if PyTime_PerfCounter(&mut t) < 0 {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

# process_time_times(): times() user and system ticks; False when times() fails.
def:priv process_time_times(info: ClockInfo | None) -> tuple[bool, i64] {
    process = tms();
    if times(&mut process) == -1 {
        return (False, 0);
    }
    if info is not None {
        info.implementation = "times()";
        info.resolution = _PyTimeFraction_Resolution(&times_base);
        info.monotonic = True;
        info.adjustable = False;
    }
    return (
        True,
        _PyTimeFraction_Mul(i64(process.tms_utime), &times_base)
            + _PyTimeFraction_Mul(i64(process.tms_stime), &times_base)
    );
}

# A CPU-time clock read with clock_gettime(); with `info`, its resolution
# comes from clock_getres().
def:priv cpu_clock(
    clk_id: i32, function: str, ts: timespec, info: ClockInfo | None
) -> tuple[bool, i64] {
    if info is not None {
        info.implementation = function;
        info.monotonic = True;
        info.adjustable = False;
        res = timespec();
        if clock_getres(clk_id, &mut res) != 0 {
            os_error();
            return (False, 0);
        }
        info.resolution = timespec_seconds(res);
    }
    t: i64 = 0;
    ok = _PyTime_FromTimespec(&mut t, &ts) >= 0;
    return (ok, t);
}

# py_process_time(): the first of clock_gettime(CLOCK_PROCESS_CPUTIME_ID),
# getrusage(RUSAGE_SELF), times() and clock() that works.
def:priv py_process_time(info: ClockInfo | None) -> tuple[bool, i64] {
    ts = timespec();
    if clock_gettime(i32(CLOCK_PROCESS_CPUTIME_ID), &mut ts) == 0 {
        return cpu_clock(
            i32(CLOCK_PROCESS_CPUTIME_ID),
            "clock_gettime(CLOCK_PROCESS_CPUTIME_ID)",
            ts,
            info
        );
    }
    usage = rusage();
    if getrusage(RUSAGE_SELF, &mut usage) == 0 {
        if info is not None {
            info.implementation = "getrusage(RUSAGE_SELF)";
            info.monotonic = True;
            info.adjustable = False;
            info.resolution = 1e-6;
        }
        # resource_records declares its own timeval; pytime reads this one.
        user = timeval(tv_sec=usage.ru_utime.tv_sec, tv_usec=usage.ru_utime.tv_usec);
        system = timeval(tv_sec=usage.ru_stime.tv_sec, tv_usec=usage.ru_stime.tv_usec);
        utime: i64 = 0;
        stime: i64 = 0;
        if _PyTime_FromTimeval(&mut utime, &mut user) < 0 {
            return (False, 0);
        }
        if _PyTime_FromTimeval(&mut stime, &mut system) < 0 {
            return (False, 0);
        }
        return (True, utime + stime);
    }
    (ok, t) = process_time_times(info);
    if ok {
        return (True, t);
    }
    return py_clock(info);
}

def time_process_time(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    (ok, t) = py_process_time(None);
    if not ok {
        return NULL;
    }
    return float_from_time(t);
}

def time_process_time_ns(
    module: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    (ok, t) = py_process_time(None);
    if not ok {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

# _PyTime_GetThreadTimeWithInfo() over CLOCK_THREAD_CPUTIME_ID.
def:priv thread_time(info: ClockInfo | None) -> tuple[bool, i64] {
    ts = timespec();
    if clock_gettime(i32(CLOCK_THREAD_CPUTIME_ID), &mut ts) != 0 {
        os_error();
        return (False, 0);
    }
    return cpu_clock(
        i32(CLOCK_THREAD_CPUTIME_ID), "clock_gettime(CLOCK_THREAD_CPUTIME_ID)", ts, info
    );
}

def time_thread_time(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    (ok, t) = thread_time(None);
    if not ok {
        return NULL;
    }
    return float_from_time(t);
}

def time_thread_time_ns(module: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    (ok, t) = thread_time(None);
    if not ok {
        return NULL;
    }
    return _PyTime_AsLong(t);
}

# The clock information pytime.c reports through _Py_clock_info_t.
def:priv reported(record: _Py_clock_info_t, info: ClockInfo) -> bool {
    implementation = c_string_text(record.implementation);
    if not implementation {
        return False;
    }
    info.implementation = text_value(implementation);
    jacpy_release(implementation);
    info.monotonic = record.monotonic != 0;
    info.adjustable = record.adjustable != 0;
    info.resolution = record.resolution;
    return True;
}

def:priv set_item(dictionary: ptr[PyObject], key: str, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    status = PyDict_SetItemString(dictionary, key, value);
    jacpy_release(value);
    return status == 0;
}

def time_get_clock_info(module: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    name = "";
    try {
        name = ArgumentFormat(name="get_clock_info").parse(args, "s")[0].text;
    } except boundary_failure {
        return NULL;
    }
    info = ClockInfo();
    record = _Py_clock_info_t();
    t: i64 = 0;
    if name == "time" {
        if _PyTime_TimeWithInfo(&mut t, &mut record) < 0
            or not reported(record, info) {
            return NULL;
        }
    } elif name == "monotonic" {
        if _PyTime_MonotonicWithInfo(&mut t, &mut record) < 0
            or not reported(record, info) {
            return NULL;
        }
    } elif name == "perf_counter" {
        if _PyTime_PerfCounterWithInfo(&mut t, &mut record) < 0
            or not reported(record, info) {
            return NULL;
        }
    } elif name == "process_time" {
        (ok, t) = py_process_time(info);
        if not ok {
            return NULL;
        }
    } elif name == "thread_time" {
        (ok, t) = thread_time(info);
        if not ok {
            return NULL;
        }
    } else {
        object_error(PyExc_ValueError, "unknown clock");
        return NULL;
    }
    dictionary = PyDict_New();
    if not dictionary {
        return NULL;
    }
    if not set_item(
        dictionary, "implementation", PyUnicode_FromString(info.implementation)
    )
        or not set_item(dictionary, "monotonic", PyBool_FromLong(i64(info.monotonic)))
        or not set_item(dictionary, "adjustable", PyBool_FromLong(i64(info.adjustable)))
        or not set_item(
            dictionary, "resolution", PyFloat_FromDouble(info.resolution)
        ) {
        jacpy_release(dictionary);
        return NULL;
    }
    namespace = _PyNamespace_New(dictionary);
    jacpy_release(dictionary);
    return namespace;
}

# The zone name and UTC offset localtime() reports for `t`.
def:priv zone_at(t: int) -> tuple[ptr[PyObject], int] {
    p = tm();
    _PyTime_localtime(t, &mut p);
    # strncpy(zone, p->tm_zone ? p->tm_zone : "   ", 9)
    name = c_string_text(p.tm_zone, 9)
        if not p.tm_zone.is_null()
        else PyUnicode_FromString("   ");
    return (name, -int(p.tm_gmtoff));
}

# init_timezone(): timezone, altzone, daylight and tzname from the offsets
# of January and July, the larger offset being standard time.
def init_timezone(m: ptr[PyObject]) -> i32 {
    t = (int(time(ptr())) // YEAR) * YEAR;
    january = zone_at(t);
    july = zone_at(t + YEAR // 2);
    janname = january[0];
    julyname = july[0];
    janzone = january[1];
    julyzone = july[1];
    if janzone < -MAX_TIMEZONE
        or janzone > MAX_TIMEZONE
        or julyzone < -MAX_TIMEZONE
        or julyzone > MAX_TIMEZONE {
        jacpy_release(janname);
        jacpy_release(julyname);
        object_error(PyExc_RuntimeError, "invalid GMT offset");
        return i32(-1);
    }
    standard = (julyzone, janzone, julyname, janname)
        if janzone < julyzone
        else (janzone, julyzone, janname, julyname);
    if PyModule_AddIntConstant(m, "timezone", i64(standard[0])) < 0
        or PyModule_AddIntConstant(m, "altzone", i64(standard[1])) < 0
        or PyModule_AddIntConstant(m, "daylight", i64(janzone != julyzone)) < 0 {
        jacpy_release(janname);
        jacpy_release(julyname);
        return i32(-1);
    }
    if not janname or not julyname {
        jacpy_release(janname);
        jacpy_release(julyname);
        return i32(-1);
    }
    names = object_tuple([standard[2], standard[3]]);
    jacpy_release(janname);
    jacpy_release(julyname);
    status = PyModule_AddObjectRef(m, "tzname", names);
    jacpy_release(names);
    if status < 0 or PyErr_Occurred() {
        return i32(-1);
    }
    return i32(0);
}

# The times() and clock() frequencies as fractions of a second.
def init_clock_bases -> i32 {
    ticks_per_second: i64 = 0;
    if _Py_GetTicksPerSecond(&mut ticks_per_second) < 0 {
        object_error(PyExc_RuntimeError, "cannot read ticks_per_second");
        return i32(-1);
    }
    if _PyTimeFraction_Set(&mut times_base, SEC_TO_NS, ticks_per_second) < 0 {
        object_error(PyExc_OverflowError, "ticks_per_second is too large");
        return i32(-1);
    }
    if _PyTimeFraction_Set(&mut clock_base, SEC_TO_NS, CLOCKS_PER_SEC) < 0 {
        object_error(PyExc_OverflowError, "CLOCKS_PER_SEC is too large");
        return i32(-1);
    }
    return i32(0);
}
