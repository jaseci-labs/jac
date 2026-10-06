"""The time module: its method table, struct_time, the clock constants and time zone."""

import from jaclang.runtime.python.cpython_api {
    jacpy_struct_sequence_type,
    PyExc_ImportError,
    PyModule_AddIntConstant,
    PyObject
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_state_owned
}
import from jaclang.runtime.python.bindings.clinic.time { module_methods }
import from jaclang.runtime.python.modules.time {
    init_clock_bases,
    init_timezone,
    time_asctime,
    time_clock_getres,
    time_clock_settime,
    time_clock_settime_ns,
    time_ctime,
    time_get_clock_info,
    time_gmtime,
    time_localtime,
    time_mktime,
    time_monotonic,
    time_monotonic_ns,
    time_perf_counter,
    time_perf_counter_ns,
    time_process_time,
    time_process_time_ns,
    time_pthread_getcpuclockid,
    time_sleep,
    time_strftime,
    time_strptime,
    time_thread_time,
    time_thread_time_ns,
    time_time,
    time_time_ns,
    time_tzset
}
import from jaclang.runtime.python.modules.time_constants { PLATFORM, CONSTANTS }
import from jaclang.runtime.python.modules.time_platform { HAS_PTHREAD_GETCPUCLOCKID }

glob:priv METH_VARARGS: i64 = 1,
     METH_NOARGS: i64 = 4,
     METH_O: i64 = 8,
     # Constants the module reads without publishing them.
     INTERNAL: list[str] = ["CLOCKS_PER_SEC", "TIMER_ABSTIME"],
     STRFTIME_FORMAT_CODES: str = "Commonly used format codes:\n\n%Y  Year with century as a decimal number.\n%m  Month as a decimal number [01,12].\n%d  Day of the month as a decimal number [01,31].\n%H  Hour (24-hour clock) as a decimal number [00,23].\n%M  Minute as a decimal number [00,59].\n%S  Second as a decimal number [00,61].\n%z  Time zone offset from UTC.\n%a  Locale's abbreviated weekday name.\n%A  Locale's full weekday name.\n%b  Locale's abbreviated month name.\n%B  Locale's full month name.\n%c  Locale's appropriate date and time representation.\n%I  Hour (12-hour clock) as a decimal number [01,12].\n%p  Locale's equivalent of either AM or PM.\n\nOther codes may be available on your platform.  See documentation for\nthe C library strftime function.\n",
     MODULE_DOC: str = "This module provides various functions to manipulate time values.\n\nThere are two standard representations of time.  One is the number\nof seconds since the Epoch, in UTC (a.k.a. GMT).  It may be an integer\nor a floating-point number (to represent fractions of seconds).\nThe epoch is the point where the time starts, the return value of time.gmtime(0).\nIt is January 1, 1970, 00:00:00 (UTC) on all platforms.\n\nThe other representation is a tuple of 9 integers giving local time.\nThe tuple items are:\n  year (including century, e.g. 1998)\n  month (1-12)\n  day (1-31)\n  hours (0-23)\n  minutes (0-59)\n  seconds (0-59)\n  weekday (0-6, Monday is 0)\n  Julian day (day in the year, 1-366)\n  DST (Daylight Savings Time) flag (-1, 0 or 1)\nIf the DST flag is 0, the time is given in the regular time zone;\nif it is 1, the time is given in the DST time zone;\nif it is -1, mktime() should guess based on the date and time.\n",
     STRUCT_TIME_DOC: str = "The time value as returned by gmtime(), localtime(), and strptime(), and\n accepted by asctime(), mktime() and strftime().  May be considered as a\n sequence of 9 integers.\n\n Note that several fields' values are not the same as those defined by\n the C language standard for struct tm.  For example, the value of the\n field tm_year is the actual year, not year - 1900.  See individual\n fields' descriptions for details.",
     STRUCT_TIME_FIELDS: str = "tm_year\tyear, for example, 1993\ntm_mon\tmonth of year, range [1, 12]\ntm_mday\tday of month, range [1, 31]\ntm_hour\thours, range [0, 23]\ntm_min\tminutes, range [0, 59]\ntm_sec\tseconds, range [0, 61])\ntm_wday\tday of week, range [0, 6], Monday is 0\ntm_yday\tday of year, range [1, 366]\ntm_isdst\t1 if summer time is in effect, 0 if not, and -1 if unknown\ntm_zone\tabbreviation of timezone name\ntm_gmtoff\toffset from UTC in seconds";

def:priv method(
    name: str, callbacks: MethodCallbacks, flags: i64, doc: str
) -> MethodDefinition {
    return MethodDefinition(name, callbacks, doc, flags=flags);
}

# time_methods[] in the C module's order; clinic generates clock_gettime and
# clock_gettime_ns.
def:priv methods -> list[MethodDefinition] {
    table = [
        method(
            "time",
            MethodCallbacks(positional=time_time),
            METH_NOARGS,
            "time() -> floating-point number\n\nReturn the current time in seconds since the Epoch.\nFractions of a second may be present if the system clock provides them."
        ),
        method(
            "time_ns",
            MethodCallbacks(positional=time_time_ns),
            METH_NOARGS,
            "time_ns() -> int\n\nReturn the current time in nanoseconds since the Epoch."
        )
    ]
        + module_methods
        + [
            method(
                "clock_settime",
                MethodCallbacks(positional=time_clock_settime),
                METH_VARARGS,
                "clock_settime(clk_id, time)\n\nSet the time of the specified clock clk_id."
            ),
            method(
                "clock_settime_ns",
                MethodCallbacks(positional=time_clock_settime_ns),
                METH_VARARGS,
                "clock_settime_ns(clk_id, time)\n\nSet the time of the specified clock clk_id with nanoseconds."
            ),
            method(
                "clock_getres",
                MethodCallbacks(positional=time_clock_getres),
                METH_VARARGS,
                "clock_getres(clk_id) -> floating-point number\n\nReturn the resolution (precision) of the specified clock clk_id."
            )
        ];
    if HAS_PTHREAD_GETCPUCLOCKID {
        table.append(
            method(
                "pthread_getcpuclockid",
                MethodCallbacks(positional=time_pthread_getcpuclockid),
                METH_VARARGS,
                "pthread_getcpuclockid(thread_id) -> int\n\nReturn the clk_id of a thread's CPU time clock."
            )
        );
    }
    return table
        + [
            method(
                "sleep",
                MethodCallbacks(positional=time_sleep),
                METH_O,
                "sleep(seconds)\n\nDelay execution for a given number of seconds.  The argument may be\na floating-point number for subsecond precision."
            ),
            method(
                "gmtime",
                MethodCallbacks(positional=time_gmtime),
                METH_VARARGS,
                "gmtime([seconds]) -> (tm_year, tm_mon, tm_mday, tm_hour, tm_min,\n                       tm_sec, tm_wday, tm_yday, tm_isdst)\n\nConvert seconds since the Epoch to a time tuple expressing UTC (a.k.a.\nGMT).  When 'seconds' is not passed in, convert the current time instead.\n\nIf the platform supports the tm_gmtoff and tm_zone, they are available as\nattributes only."
            ),
            method(
                "localtime",
                MethodCallbacks(positional=time_localtime),
                METH_VARARGS,
                "localtime([seconds]) -> (tm_year,tm_mon,tm_mday,tm_hour,tm_min,\n                          tm_sec,tm_wday,tm_yday,tm_isdst)\n\nConvert seconds since the Epoch to a time tuple expressing local time.\nWhen 'seconds' is not passed in, convert the current time instead."
            ),
            method(
                "asctime",
                MethodCallbacks(positional=time_asctime),
                METH_VARARGS,
                "asctime([tuple]) -> string\n\nConvert a time tuple to a string, e.g. 'Sat Jun 06 16:26:11 1998'.\nWhen the time tuple is not present, current time as returned by localtime()\nis used."
            ),
            method(
                "ctime",
                MethodCallbacks(positional=time_ctime),
                METH_VARARGS,
                "ctime(seconds) -> string\n\nConvert a time in seconds since the Epoch to a string in local time.\nThis is equivalent to asctime(localtime(seconds)). When the time tuple is\nnot present, current time as returned by localtime() is used."
            ),
            method(
                "mktime",
                MethodCallbacks(positional=time_mktime),
                METH_O,
                "mktime(tuple) -> floating-point number\n\nConvert a time tuple in local time to seconds since the Epoch.\nNote that mktime(gmtime(0)) will not generally return zero for most\ntime zones; instead the returned value will either be equal to that\nof the timezone or altzone attributes on the time module."
            ),
            method(
                "strftime",
                MethodCallbacks(positional=time_strftime),
                METH_VARARGS,
                "strftime(format[, tuple]) -> string\n\nConvert a time tuple to a string according to a format specification.\nSee the library reference manual for formatting codes. When the time tuple\nis not present, current time as returned by localtime() is used.\n\n"
                    + STRFTIME_FORMAT_CODES
            ),
            method(
                "strptime",
                MethodCallbacks(positional=time_strptime),
                METH_VARARGS,
                "strptime(string, format) -> struct_time\n\nParse a string to a time tuple according to a format specification.\nSee the library reference manual for formatting codes (same as\nstrftime()).\n\n"
                    + STRFTIME_FORMAT_CODES
            ),
            method(
                "tzset",
                MethodCallbacks(positional=time_tzset),
                METH_NOARGS,
                "tzset()\n\nInitialize, or reinitialize, the local timezone to the value stored in\nos.environ['TZ']. The TZ environment variable should be specified in\nstandard Unix timezone format as documented in the tzset man page\n(eg. 'US/Eastern', 'Europe/Amsterdam'). Unknown timezones will silently\nfall back to UTC. If the TZ environment variable is not set, the local\ntimezone is set to the systems best guess of wallclock time.\nChanging the TZ environment variable without calling tzset *may* change\nthe local timezone used by methods such as localtime, but this behaviour\nshould not be relied on."
            ),
            method(
                "monotonic",
                MethodCallbacks(positional=time_monotonic),
                METH_NOARGS,
                "monotonic() -> float\n\nMonotonic clock, cannot go backward."
            ),
            method(
                "monotonic_ns",
                MethodCallbacks(positional=time_monotonic_ns),
                METH_NOARGS,
                "monotonic_ns() -> int\n\nMonotonic clock, cannot go backward, as nanoseconds."
            ),
            method(
                "process_time",
                MethodCallbacks(positional=time_process_time),
                METH_NOARGS,
                "process_time() -> float\n\nProcess time for profiling: sum of the kernel and user-space CPU time."
            ),
            method(
                "process_time_ns",
                MethodCallbacks(positional=time_process_time_ns),
                METH_NOARGS,
                "process_time() -> int\n\nProcess time for profiling as nanoseconds:\nsum of the kernel and user-space CPU time."
            ),
            method(
                "thread_time",
                MethodCallbacks(positional=time_thread_time),
                METH_NOARGS,
                "thread_time() -> float\n\nThread time for profiling: sum of the kernel and user-space CPU time."
            ),
            method(
                "thread_time_ns",
                MethodCallbacks(positional=time_thread_time_ns),
                METH_NOARGS,
                "thread_time() -> int\n\nThread time for profiling as nanoseconds:\nsum of the kernel and user-space CPU time."
            ),
            method(
                "perf_counter",
                MethodCallbacks(positional=time_perf_counter),
                METH_NOARGS,
                "perf_counter() -> float\n\nPerformance counter for benchmarking."
            ),
            method(
                "perf_counter_ns",
                MethodCallbacks(positional=time_perf_counter_ns),
                METH_NOARGS,
                "perf_counter_ns() -> int\n\nPerformance counter for benchmarking as nanoseconds."
            ),
            method(
                "get_clock_info",
                MethodCallbacks(positional=time_get_clock_info),
                METH_VARARGS,
                "get_clock_info(name: str) -> dict\n\nGet information of the specified clock."
            )
        ];
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "time has no time_constants.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    if init_timezone(module) < 0 {
        return i32(-1);
    }
    for (name, value) in CONSTANTS {
        if name not in INTERNAL and PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    if PyModule_AddIntConstant(module, "_STRUCT_TM_ITEMS", 11) < 0 {
        return i32(-1);
    }
    struct_time = jacpy_struct_sequence_type(
        "time.struct_time", STRUCT_TIME_DOC, STRUCT_TIME_FIELDS, 9
    );
    if not add_state_owned(module, 0, "struct_time", struct_time) {
        return i32(-1);
    }
    return init_clock_bases();
}

glob:priv definition = ModuleDefinition(
         "time", MODULE_DOC, methods(), ModuleHooks(execute=execute), 1
     );

def:pub PyInit_time -> ptr[PyObject] {
    return definition.initialize();
}
