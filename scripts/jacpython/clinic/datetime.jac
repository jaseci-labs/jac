"""The Argument Clinic signatures of _datetime.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/datetime.jac from them. Taken from
CPython 3.14.6 Modules/_datetimemodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_datetime",
         version="3.14.6",
         sources=["Modules/_datetimemodule.c"],
         classes={
             "datetime": "PyDateTime_DateTime *",
             "date": "PyDateTime_Date *",
             "time": "PyDateTime_Time *",
             "IsoCalendarDate": "PyDateTime_IsoCalendarDate *"
         },
         functions=[
             Function(
                 name="now",
                 full_name="datetime.datetime.now",
                 c_basename="datetime_datetime_now",
                 kind="CLASS_METHOD",
                 cls="datetime",
                 docstring="now($type, /, tz=None)\n"
                 "--\n"
                 "\n"
                 "Returns new datetime object representing current time local to tz.\n"
                 "\n"
                 "  tz\n"
                 "    Timezone object.\n"
                 "\n"
                 "If no tz is specified, uses local timezone.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="tz",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS|METH_CLASS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="replace",
                 full_name="datetime.datetime.replace",
                 c_basename="datetime_datetime_replace",
                 cls="datetime",
                 docstring="replace($self, /, year=unchanged, month=unchanged, day=unchanged,\n"
                 "        hour=unchanged, minute=unchanged, second=unchanged,\n"
                 "        microsecond=unchanged, tzinfo=unchanged, *, fold=unchanged)\n"
                 "--\n"
                 "\n"
                 "Return datetime with new specified fields.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="year",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_YEAR(self)"
                     ),
                     Parameter(
                         name="month",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_MONTH(self)"
                     ),
                     Parameter(
                         name="day",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_DAY(self)"
                     ),
                     Parameter(
                         name="hour",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DATE_GET_HOUR(self)"
                     ),
                     Parameter(
                         name="minute",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DATE_GET_MINUTE(self)"
                     ),
                     Parameter(
                         name="second",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DATE_GET_SECOND(self)"
                     ),
                     Parameter(
                         name="microsecond",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DATE_GET_MICROSECOND(self)"
                     ),
                     Parameter(
                         name="tzinfo",
                         format_unit="O",
                         default_kind="unknown",
                         c_default="HASTZINFO(self) ? ((PyDateTime_DateTime *)self)->tzinfo : Py_None"
                     ),
                     Parameter(
                         name="fold",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DATE_GET_FOLD(self)"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=8
             ),
             Function(
                 name="fromtimestamp",
                 full_name="datetime.date.fromtimestamp",
                 c_basename="datetime_date_fromtimestamp",
                 kind="CLASS_METHOD",
                 cls="date",
                 docstring="fromtimestamp($type, timestamp, /)\n"
                 "--\n"
                 "\n"
                 "Create a date from a POSIX timestamp.\n"
                 "\n"
                 "The timestamp is a number, e.g. created via time.time(), that is\n"
                 "interpreted as local time.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="timestamp", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_O|METH_CLASS",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="replace",
                 full_name="datetime.date.replace",
                 c_basename="datetime_date_replace",
                 cls="date",
                 docstring="replace($self, /, year=unchanged, month=unchanged, day=unchanged)\n"
                 "--\n"
                 "\n"
                 "Return date with new specified fields.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="year",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_YEAR(self)"
                     ),
                     Parameter(
                         name="month",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_MONTH(self)"
                     ),
                     Parameter(
                         name="day",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="GET_DAY(self)"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             ),
             Function(
                 name="replace",
                 full_name="datetime.time.replace",
                 c_basename="datetime_time_replace",
                 cls="time",
                 docstring="replace($self, /, hour=unchanged, minute=unchanged, second=unchanged,\n"
                 "        microsecond=unchanged, tzinfo=unchanged, *, fold=unchanged)\n"
                 "--\n"
                 "\n"
                 "Return time with new specified fields.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="hour",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="TIME_GET_HOUR(self)"
                     ),
                     Parameter(
                         name="minute",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="TIME_GET_MINUTE(self)"
                     ),
                     Parameter(
                         name="second",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="TIME_GET_SECOND(self)"
                     ),
                     Parameter(
                         name="microsecond",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="TIME_GET_MICROSECOND(self)"
                     ),
                     Parameter(
                         name="tzinfo",
                         format_unit="O",
                         default_kind="unknown",
                         c_default="HASTZINFO(self) ? ((PyDateTime_Time *)self)->tzinfo : Py_None"
                     ),
                     Parameter(
                         name="fold",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="TIME_GET_FOLD(self)"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=5
             ),
             Function(
                 name="__new__",
                 full_name="datetime.IsoCalendarDate.__new__",
                 c_basename="iso_calendar_date_new",
                 kind="METHOD_NEW",
                 cls="IsoCalendarDate",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="year", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="week", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="weekday", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             )
         ],
         docs={
             "iso_calendar_date__doc__": "The result of date.isocalendar() or datetime.isocalendar()\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  ((year, week, weekday)\n"
             "or via the object attributes as named in the above tuple.",
             "delta_members_days_doc": "Number of days.",
             "delta_members_seconds_doc": "Number of seconds (>= 0 and less than 1 day).",
             "delta_members_microseconds_doc": "Number of microseconds (>= 0 and less than 1 second).",
             "delta_methods_total_seconds_doc": "Total seconds in the duration.",
             "delta_methods___reduce___doc": "__reduce__() -> (cls, state)",
             "iso_calendar_date_methods___reduce___doc": "__reduce__() -> (cls, state)",
             "date_methods_fromordinal_doc": "int -> date corresponding to a proleptic Gregorian ordinal.",
             "date_methods_fromisoformat_doc": "str -> Construct a date from a string in ISO 8601 format.",
             "date_methods_fromisocalendar_doc": "int, int, int -> Construct a date from the ISO year, week number and weekday.\n"
             "\n"
             "This is the inverse of the date.isocalendar() function",
             "date_methods_strptime_doc": "string, format -> new date parsed from a string (like time.strptime()).",
             "date_methods_today_doc": "Current date or datetime:  same as self.__class__.fromtimestamp(time.time()).",
             "date_methods_ctime_doc": "Return ctime() style string.",
             "date_methods_strftime_doc": "format -> strftime() style string.",
             "date_methods___format___doc": "Formats self with strftime.",
             "date_methods_timetuple_doc": "Return time tuple, compatible with time.localtime().",
             "date_methods_isocalendar_doc": "Return a named tuple containing ISO year, week number, and weekday.",
             "date_methods_isoformat_doc": "Return string in ISO 8601 format, YYYY-MM-DD.",
             "date_methods_isoweekday_doc": "Return the day of the week represented by the date.\n"
             "Monday == 1 ... Sunday == 7",
             "date_methods_toordinal_doc": "Return proleptic Gregorian ordinal.  January 1 of year 1 is day 1.",
             "date_methods_weekday_doc": "Return the day of the week represented by the date.\n"
             "Monday == 0 ... Sunday == 6",
             "date_methods___replace___doc": "__replace__($self, /, **changes)\n"
             "--\n"
             "\n"
             "The same as replace().",
             "date_methods___reduce___doc": "__reduce__() -> (cls, state)",
             "tzinfo_methods_tzname_doc": "datetime -> string name of time zone.",
             "tzinfo_methods_utcoffset_doc": "datetime -> timedelta showing offset from UTC, negative values indicating West of UTC",
             "tzinfo_methods_dst_doc": "datetime -> DST offset as timedelta positive east of UTC.",
             "tzinfo_methods_fromutc_doc": "datetime in UTC -> datetime in local time.",
             "tzinfo_methods___reduce___doc": "-> (cls, state)",
             "timezone_methods_tzname_doc": "If name is specified when timezone is created, returns the name.  Otherwise returns offset as 'UTC(+|-)HH:MM'.",
             "timezone_methods_utcoffset_doc": "Return fixed offset.",
             "timezone_methods_dst_doc": "Return None.",
             "timezone_methods_fromutc_doc": "datetime in UTC -> datetime in local time.",
             "timezone_methods___getinitargs___doc": "pickle support",
             "time_methods_strptime_doc": "string, format -> new time parsed from a string (like time.strptime()).",
             "time_methods_isoformat_doc": "Return string in ISO 8601 format, [HH[:MM[:SS[.mmm[uuu]]]]][+HH:MM].\n"
             "\n"
             "The optional argument timespec specifies the number of additional terms\n"
             "of the time to include. Valid options are 'auto', 'hours', 'minutes',\n"
             "'seconds', 'milliseconds' and 'microseconds'.\n",
             "time_methods_strftime_doc": "format -> strftime() style string.",
             "time_methods___format___doc": "Formats self with strftime.",
             "time_methods_utcoffset_doc": "Return self.tzinfo.utcoffset(self).",
             "time_methods_tzname_doc": "Return self.tzinfo.tzname(self).",
             "time_methods_dst_doc": "Return self.tzinfo.dst(self).",
             "time_methods___replace___doc": "__replace__($self, /, **changes)\n"
             "--\n"
             "\n"
             "The same as replace().",
             "time_methods_fromisoformat_doc": "string -> time from a string in ISO 8601 format",
             "time_methods___reduce_ex___doc": "__reduce_ex__(proto) -> (cls, state)",
             "time_methods___reduce___doc": "__reduce__() -> (cls, state)",
             "datetime_methods_utcnow_doc": "Return a new datetime representing UTC day and time.",
             "datetime_methods_fromtimestamp_doc": "timestamp[, tz] -> tz's local time from POSIX timestamp.",
             "datetime_methods_utcfromtimestamp_doc": "Construct a naive UTC datetime from a POSIX timestamp.",
             "datetime_methods_strptime_doc": "string, format -> new datetime parsed from a string (like time.strptime()).",
             "datetime_methods_combine_doc": "date, time -> datetime with same date and time fields",
             "datetime_methods_fromisoformat_doc": "string -> datetime from a string in most ISO 8601 formats",
             "datetime_methods_date_doc": "Return date object with same year, month and day.",
             "datetime_methods_time_doc": "Return time object with same time but with tzinfo=None.",
             "datetime_methods_timetz_doc": "Return time object with same time and tzinfo.",
             "datetime_methods_ctime_doc": "Return ctime() style string.",
             "datetime_methods_timetuple_doc": "Return time tuple, compatible with time.localtime().",
             "datetime_methods_timestamp_doc": "Return POSIX timestamp as float.",
             "datetime_methods_utctimetuple_doc": "Return UTC time tuple, compatible with time.localtime().",
             "datetime_methods_isoformat_doc": "[sep] -> string in ISO 8601 format, YYYY-MM-DDT[HH[:MM[:SS[.mmm[uuu]]]]][+HH:MM].\n"
             "sep is used to separate the year from the time, and defaults to 'T'.\n"
             "The optional argument timespec specifies the number of additional terms\n"
             "of the time to include. Valid options are 'auto', 'hours', 'minutes',\n"
             "'seconds', 'milliseconds' and 'microseconds'.\n",
             "datetime_methods_utcoffset_doc": "Return self.tzinfo.utcoffset(self).",
             "datetime_methods_tzname_doc": "Return self.tzinfo.tzname(self).",
             "datetime_methods_dst_doc": "Return self.tzinfo.dst(self).",
             "datetime_methods___replace___doc": "__replace__($self, /, **changes)\n"
             "--\n"
             "\n"
             "The same as replace().",
             "datetime_methods_astimezone_doc": "tz -> convert to local time in new timezone tz\n",
             "datetime_methods___reduce_ex___doc": "__reduce_ex__(proto) -> (cls, state)",
             "datetime_methods___reduce___doc": "__reduce__() -> (cls, state)"
         }
     );
