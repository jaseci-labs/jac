"""The Argument Clinic signatures of time.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/time.jac from them. Taken from
the C sources it replaces (Modules/timemodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="time",
         version="3.14.6",
         sources=["Modules/timemodule.c"],
         functions=[
             Function(
                 name="clock_gettime",
                 full_name="time.clock_gettime",
                 c_basename="time_clock_gettime",
                 docstring="clock_gettime($module, clk_id, /)\n"
                 "--\n"
                 "\n"
                 "Return the time of the specified clock clk_id as a float.",
                 condition="defined(HAVE_CLOCK_GETTIME)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="clk_id",
                         kind="POSITIONAL_ONLY",
                         converter="clockid_t",
                         type="clockid_t",
                         format_unit="O&",
                         convert_with="time_clockid_converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="clock_gettime_ns",
                 full_name="time.clock_gettime_ns",
                 c_basename="time_clock_gettime_ns",
                 docstring="clock_gettime_ns($module, clk_id, /)\n"
                 "--\n"
                 "\n"
                 "Return the time of the specified clock clk_id as nanoseconds (int).",
                 condition="defined(HAVE_CLOCK_GETTIME)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="clk_id",
                         kind="POSITIONAL_ONLY",
                         converter="clockid_t",
                         type="clockid_t",
                         format_unit="O&",
                         convert_with="time_clockid_converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "time_doc": "time() -> floating-point number\n"
             "\n"
             "Return the current time in seconds since the Epoch.\n"
             "Fractions of a second may be present if the system clock provides them.",
             "time_ns_doc": "time_ns() -> int\n"
             "\n"
             "Return the current time in nanoseconds since the Epoch.",
             "clock_settime_doc": "clock_settime(clk_id, time)\n"
             "\n"
             "Set the time of the specified clock clk_id.",
             "clock_settime_ns_doc": "clock_settime_ns(clk_id, time)\n"
             "\n"
             "Set the time of the specified clock clk_id with nanoseconds.",
             "clock_getres_doc": "clock_getres(clk_id) -> floating-point number\n"
             "\n"
             "Return the resolution (precision) of the specified clock clk_id.",
             "pthread_getcpuclockid_doc": "pthread_getcpuclockid(thread_id) -> int\n"
             "\n"
             "Return the clk_id of a thread's CPU time clock.",
             "sleep_doc": "sleep(seconds)\n"
             "\n"
             "Delay execution for a given number of seconds.  The argument may be\n"
             "a floating-point number for subsecond precision.",
             "gmtime_doc": "gmtime([seconds]) -> (tm_year, tm_mon, tm_mday, tm_hour, tm_min,\n"
             "                       tm_sec, tm_wday, tm_yday, tm_isdst)\n"
             "\n"
             "Convert seconds since the Epoch to a time tuple expressing UTC (a.k.a.\n"
             "GMT).  When 'seconds' is not passed in, convert the current time instead.\n"
             "\n"
             "If the platform supports the tm_gmtoff and tm_zone, they are available as\n"
             "attributes only.",
             "localtime_doc": "localtime([seconds]) -> (tm_year,tm_mon,tm_mday,tm_hour,tm_min,\n"
             "                          tm_sec,tm_wday,tm_yday,tm_isdst)\n"
             "\n"
             "Convert seconds since the Epoch to a time tuple expressing local time.\n"
             "When 'seconds' is not passed in, convert the current time instead.",
             "strftime_doc": "strftime(format[, tuple]) -> string\n"
             "\n"
             "Convert a time tuple to a string according to a format specification.\n"
             "See the library reference manual for formatting codes. When the time tuple\n"
             "is not present, current time as returned by localtime() is used.\n"
             "\n",
             "strptime_doc": "strptime(string, format) -> struct_time\n"
             "\n"
             "Parse a string to a time tuple according to a format specification.\n"
             "See the library reference manual for formatting codes (same as\n"
             "strftime()).\n"
             "\n",
             "asctime_doc": "asctime([tuple]) -> string\n"
             "\n"
             "Convert a time tuple to a string, e.g. 'Sat Jun 06 16:26:11 1998'.\n"
             "When the time tuple is not present, current time as returned by localtime()\n"
             "is used.",
             "ctime_doc": "ctime(seconds) -> string\n"
             "\n"
             "Convert a time in seconds since the Epoch to a string in local time.\n"
             "This is equivalent to asctime(localtime(seconds)). When the time tuple is\n"
             "not present, current time as returned by localtime() is used.",
             "mktime_doc": "mktime(tuple) -> floating-point number\n"
             "\n"
             "Convert a time tuple in local time to seconds since the Epoch.\n"
             "Note that mktime(gmtime(0)) will not generally return zero for most\n"
             "time zones; instead the returned value will either be equal to that\n"
             "of the timezone or altzone attributes on the time module.",
             "tzset_doc": "tzset()\n"
             "\n"
             "Initialize, or reinitialize, the local timezone to the value stored in\n"
             "os.environ['TZ']. The TZ environment variable should be specified in\n"
             "standard Unix timezone format as documented in the tzset man page\n"
             "(eg. 'US/Eastern', 'Europe/Amsterdam'). Unknown timezones will silently\n"
             "fall back to UTC. If the TZ environment variable is not set, the local\n"
             "timezone is set to the systems best guess of wallclock time.\n"
             "Changing the TZ environment variable without calling tzset *may* change\n"
             "the local timezone used by methods such as localtime, but this behaviour\n"
             "should not be relied on.",
             "monotonic_doc": "monotonic() -> float\n"
             "\n"
             "Monotonic clock, cannot go backward.",
             "monotonic_ns_doc": "monotonic_ns() -> int\n"
             "\n"
             "Monotonic clock, cannot go backward, as nanoseconds.",
             "perf_counter_doc": "perf_counter() -> float\n"
             "\n"
             "Performance counter for benchmarking.",
             "perf_counter_ns_doc": "perf_counter_ns() -> int\n"
             "\n"
             "Performance counter for benchmarking as nanoseconds.",
             "process_time_doc": "process_time() -> float\n"
             "\n"
             "Process time for profiling: sum of the kernel and user-space CPU time.",
             "process_time_ns_doc": "process_time() -> int\n"
             "\n"
             "Process time for profiling as nanoseconds:\n"
             "sum of the kernel and user-space CPU time.",
             "thread_time_doc": "thread_time() -> float\n"
             "\n"
             "Thread time for profiling: sum of the kernel and user-space CPU time.",
             "thread_time_ns_doc": "thread_time() -> int\n"
             "\n"
             "Thread time for profiling as nanoseconds:\n"
             "sum of the kernel and user-space CPU time.",
             "get_clock_info_doc": "get_clock_info(name: str) -> dict\n"
             "\n"
             "Get information of the specified clock.",
             "module_doc": "This module provides various functions to manipulate time values.\n"
             "\n"
             "There are two standard representations of time.  One is the number\n"
             "of seconds since the Epoch, in UTC (a.k.a. GMT).  It may be an integer\n"
             "or a floating-point number (to represent fractions of seconds).\n"
             "The epoch is the point where the time starts, the return value of time.gmtime(0).\n"
             "It is January 1, 1970, 00:00:00 (UTC) on all platforms.\n"
             "\n"
             "The other representation is a tuple of 9 integers giving local time.\n"
             "The tuple items are:\n"
             "  year (including century, e.g. 1998)\n"
             "  month (1-12)\n"
             "  day (1-31)\n"
             "  hours (0-23)\n"
             "  minutes (0-59)\n"
             "  seconds (0-59)\n"
             "  weekday (0-6, Monday is 0)\n"
             "  Julian day (day in the year, 1-366)\n"
             "  DST (Daylight Savings Time) flag (-1, 0 or 1)\n"
             "If the DST flag is 0, the time is given in the regular time zone;\n"
             "if it is 1, the time is given in the DST time zone;\n"
             "if it is -1, mktime() should guess based on the date and time.\n"
         }
     );
