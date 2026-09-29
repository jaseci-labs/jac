"""The _datetime module: fast implementation of the datetime module.

Modules/_datetimemodule.c's module definition in native Jac: the module
state and exec hook, `_PyDateTime_InitTypes()` (which pylifecycle.c calls to
ready the static types for each interpreter), the method tables of the
static types, the IsoCalendarDate heap type spec and the datetime C API
capsule, whose PyDateTime_CAPI record keeps Include/datetime.h's layout
for C extensions such as _zoneinfo. The types are in modules/datetime_*.jac.
See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    PyDict_SetItemString,
    PyInterpreterState,
    PyInterpreterState_Get,
    PyLong_FromDouble,
    PyLong_FromLong,
    PyMemberDef,
    PyMethodDef,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyType_FromModuleAndSpec,
    PyType_Slot,
    PyType_Spec,
    Py_NewRef,
    Py_None,
    _PyStaticType_InitForExtension,
    _PyType_GetDict
}
import from jaclang.runtime.python.object_model.capsule { PyCapsule_New }
import from jaclang.runtime.python.layouts {
    METH_CLASS,
    METH_FASTCALL,
    METH_KEYWORDS,
    METH_NOARGS,
    METH_O,
    METH_VARARGS,
    PY_TUPLE_OBJECT_SIZE,
    PyDateTime_CAPI,
    PyGetSetDef,
    PyStatus,
    PyTypeObject,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_getset,
    Py_tp_methods,
    Py_tp_new,
    Py_tp_repr,
    Py_tp_traverse,
    _PyStatus_TYPE_ERROR,
    _PyStatus_TYPE_OK
}
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    clear_state,
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    method_table,
    traverse_state
}
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    PARSE_KEYWORDS,
    invoke_vector
}
import from jaclang.runtime.python.bindings.converters { convert_int }
import from jaclang.runtime.python.bindings.clinic.datetime {
    date_methods,
    datetime_methods,
    iso_calendar_date_new_new
}
import from jaclang.runtime.python.modules.datetime_calendar {
    MAX_DELTA_DAYS,
    MAXYEAR,
    MINYEAR
}
import from jaclang.runtime.python.modules.datetime_objects {
    STATE_COUNT,
    STATE_EPOCH,
    STATE_ISOCALENDAR_DATE_TYPE,
    STATE_SECONDS_PER_DAY,
    STATE_US_PER_DAY,
    STATE_US_PER_HOUR,
    STATE_US_PER_MINUTE,
    STATE_US_PER_MS,
    STATE_US_PER_SECOND,
    STATE_US_PER_WEEK,
    clear_current_module,
    create_timezone,
    date_get_fold,
    date_get_hour,
    date_get_microsecond,
    date_get_minute,
    date_get_second,
    datetime_dst,
    datetime_tzinfo_of,
    datetime_utcoffset,
    get_current_module,
    get_day,
    get_month,
    get_year,
    new_date,
    new_datetime,
    new_delta,
    new_time,
    new_timezone,
    set_current_module,
    time_get_fold,
    time_get_hour,
    time_get_microsecond,
    time_get_minute,
    time_get_second,
    time_tzinfo_of,
    utc,
    utc_timezone
}
import from jaclang.runtime.python.modules.datetime_delta {
    PyDateTime_DeltaType,
    delta_reduce,
    delta_total_seconds
}
import from jaclang.runtime.python.modules.datetime_date {
    PyDateTime_DateType,
    date_ctime,
    date_format,
    date_fromisocalendar,
    date_fromisoformat,
    date_fromordinal,
    date_isocalendar,
    date_isoformat,
    date_isoweekday,
    date_reduce,
    date_strftime,
    date_strptime,
    date_timetuple,
    date_today,
    date_toordinal,
    date_weekday,
    iso_calendar_date_dealloc,
    iso_calendar_date_reduce,
    iso_calendar_date_repr,
    iso_calendar_date_traverse,
    iso_calendar_date_week,
    iso_calendar_date_weekday,
    iso_calendar_date_year
}
import from jaclang.runtime.python.modules.datetime_tzinfo {
    PyDateTime_TZInfoType,
    PyDateTime_TimeZoneType,
    timezone_dst,
    timezone_fromutc,
    timezone_getinitargs,
    timezone_tzname,
    timezone_utcoffset,
    tzinfo_dst,
    tzinfo_fromutc,
    tzinfo_reduce,
    tzinfo_tzname,
    tzinfo_utcoffset
}
import from jaclang.runtime.python.modules.datetime_time {
    PyDateTime_TimeType,
    time_dst,
    time_fromisoformat,
    time_isoformat,
    time_reduce,
    time_reduce_ex,
    time_strftime,
    time_strptime,
    time_tzname,
    time_utcoffset
}
import from jaclang.runtime.python.modules.datetime_datetime {
    PyDateTime_DateTimeType,
    datetime_astimezone,
    datetime_combine,
    datetime_ctime,
    datetime_fromisoformat,
    datetime_fromtimestamp,
    datetime_getdate,
    datetime_gettime,
    datetime_gettimetz,
    datetime_isoformat,
    datetime_reduce,
    datetime_reduce_ex,
    datetime_strptime,
    datetime_timestamp,
    datetime_timetuple,
    datetime_tzname,
    datetime_utcfromtimestamp,
    datetime_utcnow,
    datetime_utctimetuple
}
import from jaclang.runtime.python.modules.datetime {
    capi_date_from_date,
    capi_datetime_from_date_and_time,
    capi_datetime_from_date_and_time_and_fold,
    capi_delta_from_delta,
    capi_time_from_time,
    capi_time_from_time_and_fold,
    datetime_date_fromtimestamp_capi,
    datetime_date_replace_impl,
    datetime_datetime_replace_impl,
    datetime_time_replace_impl
}

import from c {
    glob PyTuple_Type: PyTypeObject; glob:priv iso_calendar_date_methods:
             list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(iso_calendar_date_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("__reduce__() -> (cls, state)")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         iso_calendar_date_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("year"), get=iso_calendar_date_year),
             PyGetSetDef(name=ptr[u8]("week"), get=iso_calendar_date_week),
             PyGetSetDef(name=ptr[u8]("weekday"), get=iso_calendar_date_weekday),
             PyGetSetDef()
         ],
         isocal_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(iso_calendar_date_repr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "The result of date.isocalendar() or datetime.isocalendar()\n\n"
                     "This object may be accessed either as a tuple of\n"
                     "  ((year, week, weekday)\n"
                     "or via the object attributes as named in the above tuple."
                 )
             ),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(iso_calendar_date_methods))
             ),
             PyType_Slot(
                 slot=Py_tp_getset, pfunc=ptr(addressof(iso_calendar_date_getset))
             ),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(iso_calendar_date_new_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(iso_calendar_date_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(iso_calendar_date_traverse)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         isocal_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("datetime.IsoCalendarDate"),
             basicsize=i32(PY_TUPLE_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(isocal_slots)
         ),
         # The C API is process-global, as in C: the static types, the UTC
         # singleton and the constructors, with Include/datetime.h's layout.
         capi: PyDateTime_CAPI = PyDateTime_CAPI(
             DateType=addressof(PyDateTime_DateType),
             DateTimeType=addressof(PyDateTime_DateTimeType),
             TimeType=addressof(PyDateTime_TimeType),
             DeltaType=addressof(PyDateTime_DeltaType),
             TZInfoType=addressof(PyDateTime_TZInfoType),
             TimeZone_UTC=ptr[PyObject](addressof(utc_timezone)),
             Date_FromDate=capi_date_from_date,
             DateTime_FromDateAndTime=capi_datetime_from_date_and_time,
             Time_FromTime=capi_time_from_time,
             Delta_FromDelta=capi_delta_from_delta,
             TimeZone_FromTimeZone=new_timezone,
             DateTime_FromTimestamp=datetime_fromtimestamp,
             Date_FromTimestamp=datetime_date_fromtimestamp_capi,
             DateTime_FromDateAndTimeAndFold=capi_datetime_from_date_and_time_and_fold,
             Time_FromTimeAndFold=capi_time_from_time_and_fold
         ),
         # PyDateTime_CAPSULE_NAME, which the capsule keeps pointing at.
         capsule_name: ptr[u8] = ptr[u8]("datetime.datetime_CAPI");
}

# ---------------------------------------------------------------------------
# replace() and __replace__(), parsed as Argument Clinic parses them; the
# defaults are the fields of self.

glob:priv date_replace_signature = CallSignature(
         "replace", ["year", "month", "day"], 0, 3, 0, parser=PARSE_KEYWORDS
     ),
     time_replace_signature = CallSignature(
         "replace",
         ["hour", "minute", "second", "microsecond", "tzinfo", "fold"],
         0,
         5,
         0,
         parser=PARSE_KEYWORDS
     ),
     datetime_replace_signature = CallSignature(
         "replace",
         [
             "year",
             "month",
             "day",
             "hour",
             "minute",
             "second",
             "microsecond",
             "tzinfo",
             "fold"
         ],
         0,
         8,
         0,
         parser=PARSE_KEYWORDS
     );

"""An int argument of replace(), or `unchanged` when it was not given."""
def:priv int_argument(args: BoundArguments, index: int, unchanged: int) -> i32 {
    if args.values[index] != NULL {
        return convert_int(args.values[index]);
    }
    return i32(unchanged);
}

"""The tzinfo argument of replace(), or `unchanged` when it was not given."""
def:priv object_argument(
    args: BoundArguments, index: int, unchanged: ptr[PyObject]
) -> ptr[PyObject] {
    if args.values[index] != NULL {
        return args.values[index];
    }
    return unchanged;
}

def:priv date_replace_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    return datetime_date_replace_impl(
        self,
        int_argument(args, 0, get_year(self)),
        int_argument(args, 1, get_month(self)),
        int_argument(args, 2, get_day(self))
    );
}

def date_replace(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        date_replace_signature, args, nargs, kwnames, date_replace_bound, self
    );
}

def:priv time_replace_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    return datetime_time_replace_impl(
        self,
        int_argument(args, 0, time_get_hour(self)),
        int_argument(args, 1, time_get_minute(self)),
        int_argument(args, 2, time_get_second(self)),
        int_argument(args, 3, time_get_microsecond(self)),
        object_argument(args, 4, time_tzinfo_of(self)),
        int_argument(args, 5, time_get_fold(self))
    );
}

def time_replace(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        time_replace_signature, args, nargs, kwnames, time_replace_bound, self
    );
}

def:priv datetime_replace_bound(args: BoundArguments) -> ptr[PyObject] {
    self = args.context;
    return datetime_datetime_replace_impl(
        self,
        int_argument(args, 0, get_year(self)),
        int_argument(args, 1, get_month(self)),
        int_argument(args, 2, get_day(self)),
        int_argument(args, 3, date_get_hour(self)),
        int_argument(args, 4, date_get_minute(self)),
        int_argument(args, 5, date_get_second(self)),
        int_argument(args, 6, date_get_microsecond(self)),
        object_argument(args, 7, datetime_tzinfo_of(self)),
        int_argument(args, 8, date_get_fold(self))
    );
}

def datetime_replace(
    self: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_vector(
        datetime_replace_signature, args, nargs, kwnames, datetime_replace_bound, self
    );
}

# ---------------------------------------------------------------------------
# Method tables of the static types, in the C tables' order.

glob:priv date_method_list: list[MethodDefinition] = date_methods
         + [
             MethodDefinition(
                 "fromordinal",
                 MethodCallbacks(positional=date_fromordinal),
                 "int -> date corresponding to a proleptic Gregorian ordinal.",
                 i64(METH_VARARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "fromisoformat",
                 MethodCallbacks(positional=date_fromisoformat),
                 "str -> Construct a date from a string in ISO 8601 format.",
                 i64(METH_O | METH_CLASS)
             ),
             MethodDefinition(
                 "fromisocalendar",
                 MethodCallbacks(keywords=date_fromisocalendar),
                 "int, int, int -> Construct a date from the ISO year, week number and weekday.\n\nThis is the inverse of the date.isocalendar() function",
                 i64(METH_VARARGS | METH_KEYWORDS | METH_CLASS)
             ),
             MethodDefinition(
                 "strptime",
                 MethodCallbacks(positional=date_strptime),
                 "string, format -> new date parsed from a string (like time.strptime()).",
                 i64(METH_VARARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "today",
                 MethodCallbacks(positional=date_today),
                 "Current date or datetime:  same as self.__class__.fromtimestamp(time.time()).",
                 i64(METH_NOARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "ctime",
                 MethodCallbacks(positional=date_ctime),
                 "Return ctime() style string.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "strftime",
                 MethodCallbacks(keywords=date_strftime),
                 "format -> strftime() style string.",
                 i64(METH_VARARGS | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "__format__",
                 MethodCallbacks(positional=date_format),
                 "Formats self with strftime.",
                 i64(METH_VARARGS)
             ),
             MethodDefinition(
                 "timetuple",
                 MethodCallbacks(positional=date_timetuple),
                 "Return time tuple, compatible with time.localtime().",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "isocalendar",
                 MethodCallbacks(positional=date_isocalendar),
                 "Return a named tuple containing ISO year, week number, and weekday.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "isoformat",
                 MethodCallbacks(positional=date_isoformat),
                 "Return string in ISO 8601 format, YYYY-MM-DD.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "isoweekday",
                 MethodCallbacks(positional=date_isoweekday),
                 "Return the day of the week represented by the date.\nMonday == 1 ... Sunday == 7",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "toordinal",
                 MethodCallbacks(positional=date_toordinal),
                 "Return proleptic Gregorian ordinal.  January 1 of year 1 is day 1.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "weekday",
                 MethodCallbacks(positional=date_weekday),
                 "Return the day of the week represented by the date.\nMonday == 0 ... Sunday == 6",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "replace",
                 MethodCallbacks(fast_keywords=date_replace),
                 "replace($self, /, year=unchanged, month=unchanged, day=unchanged)\n--\n\nReturn date with new specified fields.",
                 i64(METH_FASTCALL | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "__replace__",
                 MethodCallbacks(fast_keywords=date_replace),
                 "__replace__($self, /, **changes)\n--\n\nThe same as replace().",
                 i64(METH_FASTCALL | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=date_reduce),
                 "__reduce__() -> (cls, state)",
                 i64(METH_NOARGS)
             )
         ],
     tzinfo_method_list: list[MethodDefinition] = [
         MethodDefinition(
             "tzname",
             MethodCallbacks(positional=tzinfo_tzname),
             "datetime -> string name of time zone.",
             i64(METH_O)
         ),
         MethodDefinition(
             "utcoffset",
             MethodCallbacks(positional=tzinfo_utcoffset),
             "datetime -> timedelta showing offset from UTC, negative values indicating West of UTC",
             i64(METH_O)
         ),
         MethodDefinition(
             "dst",
             MethodCallbacks(positional=tzinfo_dst),
             "datetime -> DST offset as timedelta positive east of UTC.",
             i64(METH_O)
         ),
         MethodDefinition(
             "fromutc",
             MethodCallbacks(positional=tzinfo_fromutc),
             "datetime in UTC -> datetime in local time.",
             i64(METH_O)
         ),
         MethodDefinition(
             "__reduce__",
             MethodCallbacks(positional=tzinfo_reduce),
             "-> (cls, state)",
             i64(METH_NOARGS)
         )
     ],
     timezone_method_list: list[MethodDefinition] = [
         MethodDefinition(
             "tzname",
             MethodCallbacks(positional=timezone_tzname),
             "If name is specified when timezone is created, returns the name.  Otherwise returns offset as 'UTC(+|-)HH:MM'.",
             i64(METH_O)
         ),
         MethodDefinition(
             "utcoffset",
             MethodCallbacks(positional=timezone_utcoffset),
             "Return fixed offset.",
             i64(METH_O)
         ),
         MethodDefinition(
             "dst",
             MethodCallbacks(positional=timezone_dst),
             "Return None.",
             i64(METH_O)
         ),
         MethodDefinition(
             "fromutc",
             MethodCallbacks(positional=timezone_fromutc),
             "datetime in UTC -> datetime in local time.",
             i64(METH_O)
         ),
         MethodDefinition(
             "__getinitargs__",
             MethodCallbacks(positional=timezone_getinitargs),
             "pickle support",
             i64(METH_NOARGS)
         )
     ],
     time_method_list: list[MethodDefinition] = [
         MethodDefinition(
             "strptime",
             MethodCallbacks(positional=time_strptime),
             "string, format -> new time parsed from a string (like time.strptime()).",
             i64(METH_VARARGS | METH_CLASS)
         ),
         MethodDefinition(
             "isoformat",
             MethodCallbacks(keywords=time_isoformat),
             "Return string in ISO 8601 format, [HH[:MM[:SS[.mmm[uuu]]]]][+HH:MM].\n\nThe optional argument timespec specifies the number of additional terms\nof the time to include. Valid options are 'auto', 'hours', 'minutes',\n'seconds', 'milliseconds' and 'microseconds'.\n",
             i64(METH_VARARGS | METH_KEYWORDS)
         ),
         MethodDefinition(
             "strftime",
             MethodCallbacks(keywords=time_strftime),
             "format -> strftime() style string.",
             i64(METH_VARARGS | METH_KEYWORDS)
         ),
         MethodDefinition(
             "__format__",
             MethodCallbacks(positional=date_format),
             "Formats self with strftime.",
             i64(METH_VARARGS)
         ),
         MethodDefinition(
             "utcoffset",
             MethodCallbacks(positional=time_utcoffset),
             "Return self.tzinfo.utcoffset(self).",
             i64(METH_NOARGS)
         ),
         MethodDefinition(
             "tzname",
             MethodCallbacks(positional=time_tzname),
             "Return self.tzinfo.tzname(self).",
             i64(METH_NOARGS)
         ),
         MethodDefinition(
             "dst",
             MethodCallbacks(positional=time_dst),
             "Return self.tzinfo.dst(self).",
             i64(METH_NOARGS)
         ),
         MethodDefinition(
             "replace",
             MethodCallbacks(fast_keywords=time_replace),
             "replace($self, /, hour=unchanged, minute=unchanged, second=unchanged,\n        microsecond=unchanged, tzinfo=unchanged, *, fold=unchanged)\n--\n\nReturn time with new specified fields.",
             i64(METH_FASTCALL | METH_KEYWORDS)
         ),
         MethodDefinition(
             "__replace__",
             MethodCallbacks(fast_keywords=time_replace),
             "__replace__($self, /, **changes)\n--\n\nThe same as replace().",
             i64(METH_FASTCALL | METH_KEYWORDS)
         ),
         MethodDefinition(
             "fromisoformat",
             MethodCallbacks(positional=time_fromisoformat),
             "string -> time from a string in ISO 8601 format",
             i64(METH_O | METH_CLASS)
         ),
         MethodDefinition(
             "__reduce_ex__",
             MethodCallbacks(positional=time_reduce_ex),
             "__reduce_ex__(proto) -> (cls, state)",
             i64(METH_VARARGS)
         ),
         MethodDefinition(
             "__reduce__",
             MethodCallbacks(positional=time_reduce),
             "__reduce__() -> (cls, state)",
             i64(METH_NOARGS)
         )
     ],
     datetime_method_list: list[MethodDefinition] = datetime_methods
         + [
             MethodDefinition(
                 "utcnow",
                 MethodCallbacks(positional=datetime_utcnow),
                 "Return a new datetime representing UTC day and time.",
                 i64(METH_NOARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "fromtimestamp",
                 MethodCallbacks(keywords=datetime_fromtimestamp),
                 "timestamp[, tz] -> tz's local time from POSIX timestamp.",
                 i64(METH_VARARGS | METH_KEYWORDS | METH_CLASS)
             ),
             MethodDefinition(
                 "utcfromtimestamp",
                 MethodCallbacks(positional=datetime_utcfromtimestamp),
                 "Construct a naive UTC datetime from a POSIX timestamp.",
                 i64(METH_VARARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "strptime",
                 MethodCallbacks(positional=datetime_strptime),
                 "string, format -> new datetime parsed from a string (like time.strptime()).",
                 i64(METH_VARARGS | METH_CLASS)
             ),
             MethodDefinition(
                 "combine",
                 MethodCallbacks(keywords=datetime_combine),
                 "date, time -> datetime with same date and time fields",
                 i64(METH_VARARGS | METH_KEYWORDS | METH_CLASS)
             ),
             MethodDefinition(
                 "fromisoformat",
                 MethodCallbacks(positional=datetime_fromisoformat),
                 "string -> datetime from a string in most ISO 8601 formats",
                 i64(METH_O | METH_CLASS)
             ),
             MethodDefinition(
                 "date",
                 MethodCallbacks(positional=datetime_getdate),
                 "Return date object with same year, month and day.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "time",
                 MethodCallbacks(positional=datetime_gettime),
                 "Return time object with same time but with tzinfo=None.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "timetz",
                 MethodCallbacks(positional=datetime_gettimetz),
                 "Return time object with same time and tzinfo.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "ctime",
                 MethodCallbacks(positional=datetime_ctime),
                 "Return ctime() style string.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "timetuple",
                 MethodCallbacks(positional=datetime_timetuple),
                 "Return time tuple, compatible with time.localtime().",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "timestamp",
                 MethodCallbacks(positional=datetime_timestamp),
                 "Return POSIX timestamp as float.",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "utctimetuple",
                 MethodCallbacks(positional=datetime_utctimetuple),
                 "Return UTC time tuple, compatible with time.localtime().",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "isoformat",
                 MethodCallbacks(keywords=datetime_isoformat),
                 "[sep] -> string in ISO 8601 format, YYYY-MM-DDT[HH[:MM[:SS[.mmm[uuu]]]]][+HH:MM].\nsep is used to separate the year from the time, and defaults to 'T'.\nThe optional argument timespec specifies the number of additional terms\nof the time to include. Valid options are 'auto', 'hours', 'minutes',\n'seconds', 'milliseconds' and 'microseconds'.\n",
                 i64(METH_VARARGS | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "utcoffset",
                 MethodCallbacks(positional=datetime_utcoffset),
                 "Return self.tzinfo.utcoffset(self).",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "tzname",
                 MethodCallbacks(positional=datetime_tzname),
                 "Return self.tzinfo.tzname(self).",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "dst",
                 MethodCallbacks(positional=datetime_dst),
                 "Return self.tzinfo.dst(self).",
                 i64(METH_NOARGS)
             ),
             MethodDefinition(
                 "replace",
                 MethodCallbacks(fast_keywords=datetime_replace),
                 "replace($self, /, year=unchanged, month=unchanged, day=unchanged,\n        hour=unchanged, minute=unchanged, second=unchanged,\n        microsecond=unchanged, tzinfo=unchanged, *, fold=unchanged)\n--\n\nReturn datetime with new specified fields.",
                 i64(METH_FASTCALL | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "__replace__",
                 MethodCallbacks(fast_keywords=datetime_replace),
                 "__replace__($self, /, **changes)\n--\n\nThe same as replace().",
                 i64(METH_FASTCALL | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "astimezone",
                 MethodCallbacks(keywords=datetime_astimezone),
                 "tz -> convert to local time in new timezone tz\n",
                 i64(METH_VARARGS | METH_KEYWORDS)
             ),
             MethodDefinition(
                 "__reduce_ex__",
                 MethodCallbacks(positional=datetime_reduce_ex),
                 "__reduce_ex__(proto) -> (cls, state)",
                 i64(METH_VARARGS)
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=datetime_reduce),
                 "__reduce__() -> (cls, state)",
                 i64(METH_NOARGS)
             )
         ],
     delta_method_list: list[MethodDefinition] = [
         MethodDefinition(
             "total_seconds",
             MethodCallbacks(positional=delta_total_seconds),
             "Total seconds in the duration.",
             i64(METH_NOARGS)
         ),
         MethodDefinition(
             "__reduce__",
             MethodCallbacks(positional=delta_reduce),
             "__reduce__() -> (cls, state)",
             i64(METH_NOARGS)
         )
     ];

# ---------------------------------------------------------------------------
# The static types (the datetime C API's five, and timezone through the UTC
# singleton): readied bases first, then added to the module under their
# names.

def:priv capi_types -> list[ptr[PyTypeObject]] {
    return [
        addressof(PyDateTime_DateType),
        addressof(PyDateTime_DateTimeType),
        addressof(PyDateTime_TimeType),
        addressof(PyDateTime_DeltaType),
        addressof(PyDateTime_TZInfoType),
        addressof(PyDateTime_TimeZoneType)
    ];
}

glob:priv CAPI_TYPE_NAMES: list[str] = [
         "date",
         "datetime",
         "time",
         "timedelta",
         "tzinfo",
         "timezone"
     ];

def:priv capi_method_lists -> list[list[MethodDefinition]] {
    return [
        date_method_list,
        datetime_method_list,
        time_method_list,
        delta_method_list,
        tzinfo_method_list,
        timezone_method_list
    ];
}

"""Fill each static type's tp_methods, once per process: the tables outlive
every interpreter, as the C module's static tables do."""
def:priv install_method_tables -> bool {
    types = capi_types();
    lists = capi_method_lists();
    for index in range(len(types)) {
        record = types[index].view(1);
        if record[0].tp_methods.is_null() {
            table = method_table(lists[index]);
            if table.is_null() {
                return False;
            }
            record[0].tp_methods = table;
        }
    }
    return True;
}

"""Store `value` (a new reference, consumed) as a class attribute of a
static type; False when it is NULL or the store fails."""
def:priv add_type_attribute(
    type: ptr[PyTypeObject], name: str, value: ptr[PyObject]
) -> bool {
    if not value {
        return False;
    }
    status = PyDict_SetItemString(_PyType_GetDict(ptr[PyObject](type)), name, value);
    jacpy_release(value);
    return status >= 0;
}

def:priv create_timezone_from_delta(
    days: int, sec: int, ms: int, normalize: int
) -> ptr[PyObject] {
    delta = new_delta(days, sec, ms, normalize);
    if not delta {
        return NULL;
    }
    tz = create_timezone(delta, NULL);
    jacpy_release(delta);
    return tz;
}

"""The class attributes: resolution, min and max of each type, and
timezone.utc."""
def:priv add_type_attributes -> bool {
    delta = addressof(PyDateTime_DeltaType);
    date = addressof(PyDateTime_DateType);
    time = addressof(PyDateTime_TimeType);
    datetime = addressof(PyDateTime_DateTimeType);
    timezone = addressof(PyDateTime_TimeZoneType);
    return add_type_attribute(delta, "resolution", new_delta(0, 0, 1, 0))
        and add_type_attribute(delta, "min", new_delta(-MAX_DELTA_DAYS, 0, 0, 0))
        and add_type_attribute(
            delta, "max", new_delta(MAX_DELTA_DAYS, 24 * 3600 - 1, 1000000 - 1, 0)
        )
        and add_type_attribute(date, "min", new_date(1, 1, 1))
        and add_type_attribute(date, "max", new_date(MAXYEAR, 12, 31))
        and add_type_attribute(date, "resolution", new_delta(1, 0, 0, 0))
        and add_type_attribute(time, "min", new_time(0, 0, 0, 0, Py_None, 0))
        and add_type_attribute(time, "max", new_time(23, 59, 59, 999999, Py_None, 0))
        and add_type_attribute(time, "resolution", new_delta(0, 0, 1, 0))
        and add_type_attribute(
            datetime, "min", new_datetime(1, 1, 1, 0, 0, 0, 0, Py_None, 0)
        )
        and add_type_attribute(
            datetime,
            "max",
            new_datetime(MAXYEAR, 12, 31, 23, 59, 59, 999999, Py_None, 0)
        )
        and add_type_attribute(datetime, "resolution", new_delta(0, 0, 1, 0))
        and add_type_attribute(timezone, "utc", Py_NewRef(utc()))
        and
        # bpo-37642: These attributes are rounded to the nearest minute for
        # backwards compatibility, even though the constructor will accept a
        # wider range of values. This may change in the future.
        add_type_attribute(timezone, "min", create_timezone_from_delta(-1, 60, 0, 1))
        and add_type_attribute(
            timezone, "max", create_timezone_from_delta(0, (23 * 60 + 59) * 60, 0, 0)
        );
}

import from c {
    # Ready the static types for `interp` (bases first) and set their class
    # attributes; pylifecycle.c calls this while initializing the core types.
    def _PyDateTime_InitTypes(interp: ptr[PyInterpreterState]) -> PyStatus {
        if not install_method_tables() {
            # _PyStatus_NO_MEMORY()
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyDateTime_InitTypes"),
                err_msg=ptr[u8]("memory allocation failed"),
                exitcode=0
            );
        }
        for type in capi_types() {
            if _PyStaticType_InitForExtension(interp, ptr[PyObject](type)) < 0 {
                return PyStatus(
                    _type=_PyStatus_TYPE_ERROR,
                    func=ptr[u8]("_PyDateTime_InitTypes"),
                    err_msg=ptr[u8]("could not initialize static types"),
                    exitcode=0
                );
            }
        }
        if not add_type_attributes() {
            return PyStatus(
                _type=_PyStatus_TYPE_ERROR,
                func=ptr[u8]("_PyDateTime_InitTypes"),
                err_msg=ptr[u8]("memory allocation failed"),
                exitcode=0
            );
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }
}

# ---------------------------------------------------------------------------
# Module state lifecycle.

"""Store a new reference (consumed) in the module state; False when NULL."""
def:priv set_state(module: ptr[PyObject], index: int, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    jacpy_release(value);
    return True;
}

"""Each module gets its own IsoCalendarDate heap type; the conversion
factors and the epoch are shared with a previously loaded module."""
def:priv init_state(module: ptr[PyObject], old_module: ptr[PyObject]) -> int {
    isocal = PyType_FromModuleAndSpec(
        module, addressof(isocal_spec), ptr[PyObject](addressof(PyTuple_Type))
    );
    if not set_state(module, STATE_ISOCALENDAR_DATE_TYPE, isocal) {
        return -1;
    }
    if old_module {
        for index in range(STATE_US_PER_MS, STATE_COUNT) {
            jacpy_binding_state_set(
                module, i64(index), jacpy_binding_state_get(old_module, i64(index))
            );
        }
        return 0;
    }
    # us_per_hour, us_per_day and us_per_week are too big for 32-bit ints,
    # but even us_per_week fits in 40 bits, so doubles are exact.
    if set_state(module, STATE_US_PER_MS, PyLong_FromLong(1000))
        and set_state(module, STATE_US_PER_SECOND, PyLong_FromLong(1000000))
        and set_state(module, STATE_US_PER_MINUTE, PyLong_FromLong(60000000))
        and set_state(module, STATE_SECONDS_PER_DAY, PyLong_FromLong(24 * 3600))
        and set_state(module, STATE_US_PER_HOUR, PyLong_FromDouble(3600000000.0))
        and set_state(module, STATE_US_PER_DAY, PyLong_FromDouble(86400000000.0))
        and set_state(module, STATE_US_PER_WEEK, PyLong_FromDouble(604800000000.0))
        and
        # The interned Unix epoch datetime instance
        set_state(
            module, STATE_EPOCH, new_datetime(1970, 1, 1, 0, 0, 0, 0, utc(), 0)
        ) {
        return 0;
    }
    return -1;
}

def:priv add_capi_types(module: ptr[PyObject]) -> bool {
    types = capi_types();
    for index in range(len(types)) {
        if PyModule_AddObjectRef(
            module, CAPI_TYPE_NAMES[index], ptr[PyObject](types[index])
        )
            < 0 {
            return False;
        }
    }
    return True;
}

def:priv datetime_exec(module: ptr[PyObject]) -> i32 {
    interp = PyInterpreterState_Get();
    (status, old_module) = get_current_module(interp);
    # The "current" module is set right before a successful return.
    ready = status >= 0
        and add_capi_types(module)
        and init_state(module, old_module) >= 0
        and PyModule_AddIntConstant(module, "MINYEAR", MINYEAR) >= 0
        and PyModule_AddIntConstant(module, "MAXYEAR", MAXYEAR) >= 0
        and PyModule_AddObjectRef(module, "UTC", utc()) >= 0
        and
        # At last, set up and add the encapsulated C API
        PyModule_Add(
            module,
            "datetime_CAPI",
            PyCapsule_New(ptr(addressof(capi)), capsule_name, ptr())
        )
            >= 0
        and set_current_module(interp, module) >= 0;
    if not ready {
        clear_state(module);
    }
    jacpy_release(old_module);
    return i32(0 if ready else -1);
}

def:priv module_clear(module: ptr[PyObject]) -> i32 {
    clear_state(module);
    clear_current_module(PyInterpreterState_Get(), module);
    # The runtime takes care of the static types for us.
    return i32(0);
}

def:priv module_free(module: ptr[PyObject]) {
    module_clear(module);
}

glob:priv definition = ModuleDefinition(
         "_datetime",
         "Fast implementation of the datetime module.",
         [],
         ModuleHooks(
             execute=datetime_exec,
             traverse=traverse_state,
             clear=module_clear,
             free=module_free
         ),
         STATE_COUNT,
         True
     );

def:pub PyInit__datetime -> ptr[PyObject] {
    return definition.initialize();
}
