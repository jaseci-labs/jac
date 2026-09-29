"""The datetime.datetime type of the _datetime module.

Modules/_datetimemodule.c's PyDateTime_DateTime implementation in native
Jac: `PyDateTime_DateTimeType`, a subclass of date, is C data under its C
name. Local time conversions go through _PyTime_localtime() and
_PyTime_gmtime() as in C, including the PEP 495 fold detection. See
../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_address,
    jacpy_is_bytes,
    jacpy_is_unicode,
    jacpy_release,
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    PyBytes_Size,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyErr_WarnEx,
    PyExc_DeprecationWarning,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_UnicodeEncodeError,
    PyExc_ValueError,
    PyFloat_FromDouble,
    PyLong_FromLong,
    PyObject,
    PyObject_CallMethod,
    PyObject_GenericGetAttr,
    PyObject_Hash,
    PyObject_Init,
    PyObject_Malloc,
    PyTime_Time,
    PyTuple_GetItem,
    PyTuple_Pack,
    PyTuple_Size,
    PyUnicode_AsLatin1String,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_DecodeLocale,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    PyUnicode_WriteChar,
    _PyLong_AsTime_t,
    _PyTime_AsTimevalTime_t,
    _PyTime_ObjectToTimeval,
    _PyTime_gmtime,
    _PyTime_localtime,
    _PyUnicode_Copy
}
import from jaclang.runtime.python.layouts {
    PY_DATETIME_BASE_DATETIME_SIZE,
    PY_DATETIME_DATETIME_SIZE,
    PyDateTime_DateTime,
    PyGetSetDef,
    PyNumberMethods,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    _PyTime_ROUND_FLOOR,
    _PyTime_ROUND_HALF_EVEN,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.modules.time_records { tm }
import from jaclang.runtime.python.modules.datetime_calendar {
    IsoTime,
    MAXYEAR,
    MINYEAR,
    YearMonthDay,
    days_in_month,
    find_isoformat_datetime_separator,
    parse_isoformat_date,
    parse_isoformat_time,
    ymd_to_ord
}
import from jaclang.runtime.python.modules.datetime_format {
    build_struct_time,
    format_ctime,
    format_utcoffset
}
import from jaclang.runtime.python.modules.datetime_objects {
    Py_EQ,
    Py_NE,
    STATE_EPOCH,
    add_datetime_timedelta,
    append_keyword_fold,
    append_keyword_tzinfo,
    call_dst,
    call_tzname,
    call_utcoffset,
    check_tzinfo_subclass,
    data_address,
    data_bytes,
    date_get_fold,
    date_get_hour,
    date_get_microsecond,
    date_get_minute,
    date_get_second,
    date_type,
    datetime_check,
    datetime_dst,
    datetime_tzinfo_of,
    datetime_utcoffset,
    delta_bool,
    delta_check,
    delta_cmp,
    delta_subtract,
    diff_to_bool,
    divide_timedelta_timedelta,
    get_current_state,
    get_day,
    get_month,
    get_year,
    has_tzinfo,
    new_date,
    new_datetime,
    new_datetime_ex2,
    new_datetime_subclass_ex,
    new_datetime_subclass_fold_ex,
    new_delta,
    new_time,
    new_timezone,
    not_implemented,
    state_value,
    td_days,
    td_microseconds,
    td_seconds,
    time_get_fold,
    time_get_hour,
    time_get_microsecond,
    time_get_minute,
    time_get_second,
    time_type,
    time_tzinfo_of,
    tzinfo_from_isoformat_results,
    type_alloc,
    type_free,
    type_name_of,
    type_object,
    type_of,
    utc
}
import from jaclang.runtime.python.modules.datetime_date {
    PyDateTime_DateType,
    compare_data,
    generic_hash,
    month_is_sane,
    strptime_via
}
import from jaclang.runtime.python.modules.datetime_delta { delta_total_seconds }
import from jaclang.runtime.python.modules.datetime_time {
    append_utcoffset,
    timespec_index
}

import from c {
    glob PyType_Type: PyTypeObject; glob:priv datetime_as_number:
             PyNumberMethods = PyNumberMethods(
             nb_add=datetime_add, nb_subtract=datetime_subtract
         ),
         datetime_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("hour"), get=datetime_hour),
             PyGetSetDef(name=ptr[u8]("minute"), get=datetime_minute),
             PyGetSetDef(name=ptr[u8]("second"), get=datetime_second),
             PyGetSetDef(name=ptr[u8]("microsecond"), get=datetime_microsecond),
             PyGetSetDef(name=ptr[u8]("tzinfo"), get=datetime_tzinfo),
             PyGetSetDef(name=ptr[u8]("fold"), get=datetime_fold),
             PyGetSetDef()
         ]; glob PyDateTime_DateTimeType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.datetime"),
             tp_basicsize=PY_DATETIME_DATETIME_SIZE,
             tp_dealloc=datetime_dealloc,
             tp_repr=datetime_repr,
             tp_as_number=addressof(datetime_as_number),
             tp_hash=datetime_hash,
             tp_str=datetime_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "datetime(year, month, day[, hour[, minute[, second[, microsecond[,tzinfo]]]]])\n"
                 "\n"
                 "The year, month and day arguments are required. tzinfo may be None, or an\n"
                 "instance of a tzinfo subclass. The remaining arguments may be ints.\n"
             ),
             tp_richcompare=datetime_richcompare,
             tp_getset=addressof(datetime_getset),
             tp_base=addressof(PyDateTime_DateType),
             tp_alloc=datetime_alloc,
             tp_new=datetime_new
         );
}

# _PyDateTime_DATETIME_DATASIZE: bytes of year, month, day, hour, minute,
# second, and usecond.
glob DATETIME_DATASIZE: Final[int] = 10,
     # As of version 2015f max fold in IANA database is 23 hours at
     # 1969-09-30 13:00:00 in Kwajalein.
     MAX_FOLD_SECONDS: Final[int] = 24 * 3600,
     # NB: date(1970,1,1).toordinal() == 719163
     EPOCH_SECONDS: Final[int] = 719163 * 24 * 60 * 60;

"""tp_alloc: `aware` (C's nitems) says whether the tzinfo member is needed."""
def datetime_alloc(type: ptr[PyTypeObject], aware: i64) -> ptr[PyObject] {
    size = PY_DATETIME_DATETIME_SIZE if aware != 0 else PY_DATETIME_BASE_DATETIME_SIZE;
    self = PyObject_Malloc(u64(size));
    if not self {
        return PyErr_NoMemory();
    }
    return PyObject_Init(ptr[PyObject](self), ptr[PyObject](type));
}

# ---------------------------------------------------------------------------
# Accessor properties. Properties for day, month, and year are inherited
# from date.

def datetime_hour(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(date_get_hour(op));
}

def datetime_minute(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(date_get_minute(op));
}

def datetime_second(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(date_get_second(op));
}

def datetime_microsecond(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(date_get_microsecond(op));
}

def datetime_tzinfo(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(datetime_tzinfo_of(op));
}

def datetime_fold(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(date_get_fold(op));
}

# ---------------------------------------------------------------------------
# Constructors.

"""A datetime from the 10-byte state of its pickle and its tzinfo; the high
bit of the third byte is the fold."""
def datetime_from_pickle(
    type: ptr[PyTypeObject], state: ptr[PyObject], tzinfo: ptr[PyObject]
) -> ptr[PyObject] {
    aware = tzinfo != Py_None;
    if aware and check_tzinfo_subclass(tzinfo) < 0 {
        PyErr_SetString(PyExc_TypeError, "bad tzinfo state arg");
        return NULL;
    }
    me = type_alloc(type, 1 if aware else 0);
    if me {
        source = ptr[u8](jacpy_bytes_address(state));
        target = data_address(me);
        for i in range(DATETIME_DATASIZE) {
            (target + i).view(1)[0] = (source + i).view(1)[0];
        }
        record = ptr[PyDateTime_DateTime](me).view(1);
        record[0].hashcode = -1;
        record[0].hastzinfo = i8(1 if aware else 0);
        if aware {
            record[0].tzinfo = Py_NewRef(tzinfo);
        }
        if (int((source + 2).view(1)[0]) & (1 << 7)) != 0 {
            record[0].data_2 = record[0].data_2 - u8(128);
            record[0].fold = u8(1);
        } else {
            record[0].fold = u8(0);
        }
    }
    return me;
}

def datetime_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    # Check for invocation from pickle with __getstate__ state
    count = PyTuple_Size(args);
    if count >= 1 and count <= 2 {
        state = PyTuple_GetItem(args, 0);
        tzinfo = PyTuple_GetItem(args, 1) if count == 2 else Py_None;
        if jacpy_is_bytes(state) != 0 {
            if PyBytes_Size(state) == DATETIME_DATASIZE
                and month_is_sane(
                    int((ptr[u8](jacpy_bytes_address(state)) + 2).view(1)[0]) & 0x7F
                ) {
                return datetime_from_pickle(type, state, tzinfo);
            }
        } elif jacpy_is_unicode(state) != 0 {
            if PyUnicode_GetLength(state) == DATETIME_DATASIZE
                and month_is_sane(int(PyUnicode_ReadChar(state, 2)) & 0x7F) {
                latin1 = PyUnicode_AsLatin1String(state);
                if not latin1 {
                    if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
                        # More informative error message.
                        PyErr_SetString(
                            PyExc_ValueError,
                            "Failed to encode latin1 string when unpickling a datetime object. pickle.load(data, encoding='latin1') is assumed."
                        );
                    }
                    return NULL;
                }
                self = datetime_from_pickle(type, latin1, tzinfo);
                jacpy_release(latin1);
                return self;
            }
        }
    }
    try {
        values = ArgumentFormat().parse_keywords(
            args,
            kw,
            "iii|iiiiO$i",
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
            ]
        );
    } except boundary_failure {
        return NULL;
    }
    return new_datetime_ex2(
        values[0].signed,
        values[1].signed,
        values[2].signed,
        values[3].signed,
        values[4].signed,
        values[5].signed,
        values[6].signed,
        values[7].object if values[7].given else Py_None,
        values[8].signed,
        type
    );
}

"""Seconds since 0001-01-01 of a UTC time; -1 with ValueError when the
year is out of range (ymd_to_ord() doesn't support year <= 0)."""
def utc_to_seconds(
    year: int, month: int, day: int, hour: int, minute: int, second: int
) -> int {
    if year < MINYEAR or year > MAXYEAR {
        PyErr_Format(
            PyExc_ValueError,
            "year must be in %ld..%ld, not %ld",
            MINYEAR,
            MAXYEAR,
            year
        );
        return -1;
    }
    ordinal = ymd_to_ord(year, month, day);
    return ((ordinal * 24 + hour) * 60 + minute) * 60 + second;
}

"""localtime() of `seconds` since 0001-01-01 as seconds since 0001-01-01;
-1 on error."""
def local(seconds: int) -> int {
    local_time = tm();
    if _PyTime_localtime(seconds - EPOCH_SECONDS, &mut local_time) != 0 {
        return -1;
    }
    return utc_to_seconds(
        int(local_time.tm_year) + 1900,
        int(local_time.tm_mon) + 1,
        int(local_time.tm_mday),
        int(local_time.tm_hour),
        int(local_time.tm_min),
        int(local_time.tm_sec)
    );
}

"""Build a datetime of class `cls` from a time_t and a distinct count of
microseconds, as local time (`local_time`) or UTC."""
def datetime_from_timet_and_us(
    cls: ptr[PyObject], local_time: bool, timet: i64, us: int, tzinfo: ptr[PyObject]
) -> ptr[PyObject] {
    moment = tm();
    status = _PyTime_localtime(timet, &mut moment)
        if local_time
        else _PyTime_gmtime(timet, &mut moment);
    if status != 0 {
        return NULL;
    }
    year = int(moment.tm_year) + 1900;
    month = int(moment.tm_mon) + 1;
    day = int(moment.tm_mday);
    hour = int(moment.tm_hour);
    minute = int(moment.tm_min);
    # The platform localtime/gmtime may insert leap seconds, indicated by
    # tm.tm_sec > 59; passing them on would raise ValueError for a reason
    # that makes no sense to the user.
    second = min(59, int(moment.tm_sec));
    fold = 0;
    # local timezone requires to compute fold
    if tzinfo == Py_None and local_time {
        result_seconds = utc_to_seconds(year, month, day, hour, minute, second);
        if result_seconds == -1 and PyErr_Occurred() {
            return NULL;
        }
        # Probe max_fold_seconds to detect a fold.
        probe_seconds = local(EPOCH_SECONDS + timet - MAX_FOLD_SECONDS);
        if probe_seconds == -1 {
            return NULL;
        }
        transition = result_seconds - probe_seconds - MAX_FOLD_SECONDS;
        if transition < 0 {
            probe_seconds = local(EPOCH_SECONDS + timet + transition);
            if probe_seconds == -1 {
                return NULL;
            }
            if probe_seconds == result_seconds {
                fold = 1;
            }
        }
    }
    return new_datetime_subclass_fold_ex(
        year, month, day, hour, minute, second, us, tzinfo, fold, cls
    );
}

"""Build a datetime from a Python timestamp, as local time or UTC."""
def datetime_from_timestamp(
    cls: ptr[PyObject],
    local_time: bool,
    timestamp: ptr[PyObject],
    tzinfo: ptr[PyObject]
) -> ptr[PyObject] {
    timet: i64 = 0;
    us: i64 = 0;
    if _PyTime_ObjectToTimeval(timestamp, &mut timet, &mut us, _PyTime_ROUND_HALF_EVEN)
        == -1 {
        return NULL;
    }
    return datetime_from_timet_and_us(cls, local_time, timet, int(us), tzinfo);
}

"""Build the most accurate possible datetime for the current time."""
def datetime_best_possible(
    cls: ptr[PyObject], local_time: bool, tzinfo: ptr[PyObject]
) -> ptr[PyObject] {
    ts: i64 = 0;
    if PyTime_Time(&mut ts) < 0 {
        return NULL;
    }
    secs: i64 = 0;
    us: i32 = 0;
    if _PyTime_AsTimevalTime_t(ts, &mut secs, &mut us, _PyTime_ROUND_FLOOR) < 0 {
        return NULL;
    }
    return datetime_from_timet_and_us(cls, local_time, secs, int(us), tzinfo);
}

"""datetime.now(tz): the current time local to tz, or local time when tz is
None."""
def datetime_now(type: ptr[PyObject], tz: ptr[PyObject]) -> ptr[PyObject] {
    if check_tzinfo_subclass(tz) < 0 {
        return NULL;
    }
    self = datetime_best_possible(type, tz == Py_None, tz);
    if self and tz != Py_None {
        # Convert UTC to tzinfo's zone.
        res = PyObject_CallMethod(tz, "fromutc", "O", self);
        jacpy_release(self);
        return res;
    }
    return self;
}

"""Return best possible UTC time -- this isn't constrained by the precision
of a timestamp."""
def datetime_utcnow(cls: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        "datetime.datetime.utcnow() is deprecated and scheduled for removal in a future version. Use timezone-aware objects to represent datetimes in UTC: datetime.datetime.now(datetime.UTC).",
        1
    )
        != 0 {
        return NULL;
    }
    return datetime_best_possible(cls, False, Py_None);
}

"""Return new local datetime from timestamp (Python timestamp -- a double)."""
def datetime_fromtimestamp(
    cls: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="fromtimestamp").parse_keywords(
            args, kw, "O|O", ["timestamp", "tz"]
        );
    } except boundary_failure {
        return NULL;
    }
    tzinfo = values[1].object if values[1].given else Py_None;
    if check_tzinfo_subclass(tzinfo) < 0 {
        return NULL;
    }
    self = datetime_from_timestamp(cls, tzinfo == Py_None, values[0].object, tzinfo);
    if self and tzinfo != Py_None {
        # Convert UTC to tzinfo's zone.
        res = PyObject_CallMethod(tzinfo, "fromutc", "O", self);
        jacpy_release(self);
        return res;
    }
    return self;
}

"""Return new UTC datetime from timestamp (Python timestamp -- a double)."""
def datetime_utcfromtimestamp(
    cls: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        "datetime.datetime.utcfromtimestamp() is deprecated and scheduled for removal in a future version. Use timezone-aware objects to represent datetimes in UTC: datetime.datetime.fromtimestamp(timestamp, datetime.UTC).",
        1
    )
        != 0 {
        return NULL;
    }
    try {
        timestamp = ArgumentFormat(name="utcfromtimestamp").parse(args, "O")[0].object;
    } except boundary_failure {
        return NULL;
    }
    return datetime_from_timestamp(cls, False, timestamp, Py_None);
}

"""Return new datetime from _strptime._strptime_datetime_datetime()."""
def datetime_strptime(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return strptime_via(cls, args, "_strptime_datetime_datetime");
}

"""Return new datetime from date/datetime and time arguments."""
def datetime_combine(
    cls: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(
            name="combine", types=[type_object(date_type()), type_object(time_type())]
        ).parse_keywords(
            args, kw, "O!O!|O", ["date", "time", "tzinfo"]
        );
    } except boundary_failure {
        return NULL;
    }
    date = values[0].object;
    time = values[1].object;
    tzinfo = values[2].object if values[2].given else time_tzinfo_of(time);
    return new_datetime_subclass_fold_ex(
        get_year(date),
        get_month(date),
        get_day(date),
        time_get_hour(time),
        time_get_minute(time),
        time_get_second(time),
        time_get_microsecond(time),
        tzinfo,
        time_get_fold(time),
        cls
    );
}

"""The string with a surrogate separator (at 7, 8 or 10) replaced by 'T',
so every valid string can be encoded in UTF-8; a new reference, or NULL for
a string too short to be valid (or on error)."""
def sanitize_isoformat_str(dtstr: ptr[PyObject]) -> ptr[PyObject] {
    length = PyUnicode_GetLength(dtstr);
    # All valid ISO 8601 strings are at least 7 characters long
    if length < 7 {
        return NULL;
    }
    surrogate_separator = 0;
    for position in [7, 8, 10] {
        # Past the end is the terminating NUL, which is no surrogate.
        if position >= length {
            break;
        }
        ch = int(PyUnicode_ReadChar(dtstr, i64(position)));
        if 0xD800 <= ch and ch <= 0xDFFF {
            surrogate_separator = position;
            break;
        }
    }
    if surrogate_separator == 0 {
        return Py_NewRef(dtstr);
    }
    str_out = _PyUnicode_Copy(dtstr);
    if not str_out {
        return NULL;
    }
    if PyUnicode_WriteChar(str_out, i64(surrogate_separator), u32(84)) != 0 {
        jacpy_release(str_out);
        return NULL;
    }
    return str_out;
}

def datetime_fromisoformat(cls: ptr[PyObject], dtstr: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(dtstr) == 0 {
        PyErr_SetString(PyExc_TypeError, "fromisoformat: argument must be str");
        return NULL;
    }
    # Only a surrogate separator needs sanitizing; where the separator is
    # ambiguous it is '-' or a digit.
    dtstr_clean = sanitize_isoformat_str(dtstr);
    if not dtstr_clean {
        PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", dtstr);
        return NULL;
    }
    length: i64 = 0;
    text = PyUnicode_AsUTF8AndSize(dtstr_clean, &mut length);
    if not text {
        if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
            # Encoding errors are invalid string errors at this point
            PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", dtstr);
        }
        jacpy_release(dtstr_clean);
        return NULL;
    }
    separator_location = find_isoformat_datetime_separator(text, int(length));
    # C passes the separator position as a size_t, so -1 reads as unbounded.
    date = YearMonthDay();
    rv = parse_isoformat_date(
        text, separator_location if separator_location >= 0 else (1 << 62), date
    );
    parsed = IsoTime();
    if rv == 0 and length > separator_location {
        # In UTF-8, the length of multi-byte characters is encoded in the MSB
        p = text + separator_location;
        lead = int(p.view(1)[0]);
        if (lead & 0x80) == 0 {
            p += 1;
        } elif (lead & 0xf0) == 0xe0 {
            p += 3;
        } elif (lead & 0xf0) == 0xf0 {
            p += 4;
        } else {
            p += 2;
        }
        rv = parse_isoformat_time(p, int(length) - (p - text), parsed);
    }
    if rv < 0 {
        PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", dtstr);
        jacpy_release(dtstr_clean);
        return NULL;
    }
    tzinfo = tzinfo_from_isoformat_results(rv, parsed.tzoffset, parsed.tzmicrosecond);
    if not tzinfo {
        jacpy_release(dtstr_clean);
        return NULL;
    }
    year = date.year;
    month = date.month;
    day = date.day;
    hour = parsed.hour;
    if hour == 24 and month <= 12 {
        d_in_month = days_in_month(year, month);
        if day <= d_in_month {
            if parsed.minute == 0 and parsed.second == 0 and parsed.microsecond == 0 {
                # Calculate midnight of the next day
                hour = 0;
                day += 1;
                if day > d_in_month {
                    day = 1;
                    month += 1;
                    if month > 12 {
                        month = 1;
                        year += 1;
                    }
                }
            } else {
                PyErr_SetString(
                    PyExc_ValueError,
                    "minute, second, and microsecond must be 0 when hour is 24"
                );
                jacpy_release(tzinfo);
                jacpy_release(dtstr_clean);
                return NULL;
            }
        }
    }
    dt = new_datetime_subclass_ex(
        year,
        month,
        day,
        hour,
        parsed.minute,
        parsed.second,
        parsed.microsecond,
        tzinfo,
        cls
    );
    jacpy_release(tzinfo);
    jacpy_release(dtstr_clean);
    return dt;
}

def datetime_dealloc(op: ptr[PyObject]) {
    if has_tzinfo(op) {
        jacpy_release(ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo);
    }
    type_free(op);
}

def datetime_tzname(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzname(datetime_tzinfo_of(op), op);
}

# ---------------------------------------------------------------------------
# datetime arithmetic.

def datetime_add(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if datetime_check(left) {
        # datetime + delta
        if delta_check(right) {
            return add_datetime_timedelta(left, right, 1);
        }
    } elif delta_check(left) {
        # delta + datetime
        return add_datetime_timedelta(right, left, 1);
    }
    return not_implemented();
}

def datetime_subtract(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if not datetime_check(left) {
        return not_implemented();
    }
    if delta_check(right) {
        # datetime - delta
        return add_datetime_timedelta(left, right, -1);
    }
    if not datetime_check(right) {
        return not_implemented();
    }
    # datetime - datetime
    offset1: ptr[PyObject] = NULL;
    offset2: ptr[PyObject] = NULL;
    if datetime_tzinfo_of(left) == datetime_tzinfo_of(right) {
        offset1 = Py_NewRef(Py_None);
        offset2 = Py_NewRef(Py_None);
    } else {
        offset1 = datetime_utcoffset(left, NULL);
        if not offset1 {
            return NULL;
        }
        offset2 = datetime_utcoffset(right, NULL);
        if not offset2 {
            jacpy_release(offset1);
            return NULL;
        }
        if (offset1 != Py_None) != (offset2 != Py_None) {
            PyErr_SetString(
                PyExc_TypeError,
                "can't subtract offset-naive and offset-aware datetimes"
            );
            jacpy_release(offset1);
            jacpy_release(offset2);
            return NULL;
        }
    }
    offdiff: ptr[PyObject] = NULL;
    if offset1 != offset2 and delta_cmp(offset1, offset2) != 0 {
        offdiff = delta_subtract(offset1, offset2);
        if not offdiff {
            jacpy_release(offset1);
            jacpy_release(offset2);
            return NULL;
        }
    }
    jacpy_release(offset1);
    jacpy_release(offset2);
    delta_d = ymd_to_ord(get_year(left), get_month(left), get_day(left))
        - ymd_to_ord(get_year(right), get_month(right), get_day(right));
    # These can't overflow, since the values are normalized. At most this
    # gives the number of seconds in one day.
    delta_s = (date_get_hour(left) - date_get_hour(right)) * 3600
        + (date_get_minute(left) - date_get_minute(right)) * 60
        + (date_get_second(left) - date_get_second(right));
    delta_us = date_get_microsecond(left) - date_get_microsecond(right);
    result = new_delta(delta_d, delta_s, delta_us, 1);
    if not result {
        jacpy_release(offdiff);
        return NULL;
    }
    if offdiff {
        adjusted = delta_subtract(result, offdiff);
        jacpy_release(result);
        jacpy_release(offdiff);
        result = adjusted;
    }
    return result;
}

# ---------------------------------------------------------------------------
# Various ways to turn a datetime into a string.

def datetime_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    type_name = type_name_of(op);
    baserepr: ptr[PyObject] = NULL;
    if date_get_microsecond(op) != 0 {
        baserepr = PyUnicode_FromFormat(
            "%s(%ld, %ld, %ld, %ld, %ld, %ld, %ld)",
            type_name,
            get_year(op),
            get_month(op),
            get_day(op),
            date_get_hour(op),
            date_get_minute(op),
            date_get_second(op),
            date_get_microsecond(op)
        );
    } elif date_get_second(op) != 0 {
        baserepr = PyUnicode_FromFormat(
            "%s(%ld, %ld, %ld, %ld, %ld, %ld)",
            type_name,
            get_year(op),
            get_month(op),
            get_day(op),
            date_get_hour(op),
            date_get_minute(op),
            date_get_second(op)
        );
    } else {
        baserepr = PyUnicode_FromFormat(
            "%s(%ld, %ld, %ld, %ld, %ld)",
            type_name,
            get_year(op),
            get_month(op),
            get_day(op),
            date_get_hour(op),
            date_get_minute(op)
        );
    }
    if baserepr and date_get_fold(op) != 0 {
        baserepr = append_keyword_fold(baserepr, date_get_fold(op));
    }
    if not baserepr or not has_tzinfo(op) {
        return baserepr;
    }
    return append_keyword_tzinfo(
        baserepr, ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo
    );
}

def datetime_str(op: ptr[PyObject]) -> ptr[PyObject] {
    space = PyUnicode_FromString(" ");
    if not space {
        return NULL;
    }
    res = PyObject_CallMethod(op, "isoformat", "O", space);
    jacpy_release(space);
    return res;
}

def datetime_isoformat(
    op: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="isoformat").parse_keywords(
            args, kw, "|Cs", ["sep", "timespec"]
        );
    } except boundary_failure {
        return NULL;
    }
    sep = values[0].signed if values[0].given else 84;
    us = date_get_microsecond(op);
    given_spec = timespec_index(values[1].text, values[1].given, us);
    y = get_year(op);
    mo = get_month(op);
    d = get_day(op);
    h = date_get_hour(op);
    mi = date_get_minute(op);
    s = date_get_second(op);
    result: ptr[PyObject] = NULL;
    if given_spec == 0 {
        result = PyUnicode_FromFormat(
            "%04ld-%02ld-%02ld%c%02ld", y, mo, d, i32(sep), h
        );
    } elif given_spec == 1 {
        result = PyUnicode_FromFormat(
            "%04ld-%02ld-%02ld%c%02ld:%02ld", y, mo, d, i32(sep), h, mi
        );
    } elif given_spec == 2 {
        result = PyUnicode_FromFormat(
            "%04ld-%02ld-%02ld%c%02ld:%02ld:%02ld", y, mo, d, i32(sep), h, mi, s
        );
    } elif given_spec == 3 {
        result = PyUnicode_FromFormat(
            "%04ld-%02ld-%02ld%c%02ld:%02ld:%02ld.%03ld",
            y,
            mo,
            d,
            i32(sep),
            h,
            mi,
            s,
            us // 1000
        );
    } elif given_spec == 4 {
        result = PyUnicode_FromFormat(
            "%04ld-%02ld-%02ld%c%02ld:%02ld:%02ld.%06ld",
            y,
            mo,
            d,
            i32(sep),
            h,
            mi,
            s,
            us
        );
    } else {
        PyErr_Format(PyExc_ValueError, "Unknown timespec value");
        return NULL;
    }
    if not result or not has_tzinfo(op) {
        return result;
    }
    # We need to append the UTC offset.
    return append_utcoffset(result, ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo, op);
}

def datetime_ctime(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return format_ctime(
        op, date_get_hour(op), date_get_minute(op), date_get_second(op)
    );
}

# ---------------------------------------------------------------------------
# Miscellaneous methods.

def flip_fold(dt: ptr[PyObject]) -> ptr[PyObject] {
    return new_datetime_ex2(
        get_year(dt),
        get_month(dt),
        get_day(dt),
        date_get_hour(dt),
        date_get_minute(dt),
        date_get_second(dt),
        date_get_microsecond(dt),
        datetime_tzinfo_of(dt),
        0 if date_get_fold(dt) != 0 else 1,
        ptr[PyTypeObject](type_of(dt))
    );
}

def get_flip_fold_offset(dt: ptr[PyObject]) -> ptr[PyObject] {
    flip_dt = flip_fold(dt);
    if not flip_dt {
        return NULL;
    }
    result = datetime_utcoffset(flip_dt, NULL);
    jacpy_release(flip_dt);
    return result;
}

"""PEP 495 exception: whenever one or both of the operands in inter-zone
comparison is such that its utcoffset() depends on the value of its fold
attribute, the result is False. 1 if the exception applies, 0 if not, -1
on error."""
def pep495_eq_exception(
    self: ptr[PyObject],
    other: ptr[PyObject],
    offset_self: ptr[PyObject],
    offset_other: ptr[PyObject]
) -> int {
    flip_offset = get_flip_fold_offset(self);
    if not flip_offset {
        return -1;
    }
    if flip_offset != offset_self and delta_cmp(flip_offset, offset_self) != 0 {
        jacpy_release(flip_offset);
        return 1;
    }
    jacpy_release(flip_offset);
    flip_offset = get_flip_fold_offset(other);
    if not flip_offset {
        return -1;
    }
    result = 1
        if flip_offset != offset_other and delta_cmp(flip_offset, offset_other) != 0
        else 0;
    jacpy_release(flip_offset);
    return result;
}

def datetime_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not datetime_check(other) {
        return not_implemented();
    }
    if datetime_tzinfo_of(self) == datetime_tzinfo_of(other) {
        return diff_to_bool(compare_data(self, other, DATETIME_DATASIZE), int(op));
    }
    offset1 = datetime_utcoffset(self, NULL);
    if not offset1 {
        return NULL;
    }
    offset2 = datetime_utcoffset(other, NULL);
    result: ptr[PyObject] = NULL;
    equality = int(op) == Py_EQ or int(op) == Py_NE;
    if offset2 {
        # If they're both naive, or both aware and have the same offsets, we
        # get off cheap. Both naive means offset1 == offset2 == None here.
        if offset1 == offset2
            or (
                delta_check(offset1)
                and delta_check(offset2)
                and delta_cmp(offset1, offset2) == 0
            ) {
            diff = compare_data(self, other, DATETIME_DATASIZE);
            ex = 0;
            if equality and diff == 0 {
                ex = pep495_eq_exception(self, other, offset1, offset2);
                if ex == 1 {
                    diff = 1;
                }
            }
            if ex != -1 {
                result = diff_to_bool(diff, int(op));
            }
        } elif offset1 != Py_None and offset2 != Py_None {
            delta = datetime_subtract(self, other);
            if delta {
                diff = td_days(delta);
                if diff == 0 {
                    diff = td_seconds(delta) | td_microseconds(delta);
                }
                jacpy_release(delta);
                ex = 0;
                if equality and diff == 0 {
                    ex = pep495_eq_exception(self, other, offset1, offset2);
                    if ex == 1 {
                        diff = 1;
                    }
                }
                if ex != -1 {
                    result = diff_to_bool(diff, int(op));
                }
            }
        } elif int(op) == Py_EQ {
            result = PyBool_FromLong(0);
        } elif int(op) == Py_NE {
            result = PyBool_FromLong(1);
        } else {
            PyErr_SetString(
                PyExc_TypeError, "can't compare offset-naive and offset-aware datetimes"
            );
        }
    }
    jacpy_release(offset1);
    jacpy_release(offset2);
    return result;
}

def datetime_hash(op: ptr[PyObject]) -> i64 {
    record = ptr[PyDateTime_DateTime](op).view(1);
    hash = record[0].hashcode;
    if hash != -1 {
        return hash;
    }
    self0: ptr[PyObject] = NULL;
    if date_get_fold(op) != 0 {
        self0 = new_datetime_ex2(
            get_year(op),
            get_month(op),
            get_day(op),
            date_get_hour(op),
            date_get_minute(op),
            date_get_second(op),
            date_get_microsecond(op),
            datetime_tzinfo_of(op),
            0,
            ptr[PyTypeObject](type_of(op))
        );
        if not self0 {
            return -1;
        }
    } else {
        self0 = Py_NewRef(op);
    }
    offset = datetime_utcoffset(self0, NULL);
    jacpy_release(self0);
    if not offset {
        return -1;
    }
    # Reduce this to a hash of another object.
    if offset == Py_None {
        hash = generic_hash(op, DATETIME_DATASIZE);
        record[0].hashcode = hash;
    } else {
        days = ymd_to_ord(get_year(op), get_month(op), get_day(op));
        seconds = date_get_hour(op) * 3600
            + date_get_minute(op) * 60
            + date_get_second(op);
        temp1 = new_delta(days, seconds, date_get_microsecond(op), 1);
        if not temp1 {
            jacpy_release(offset);
            return -1;
        }
        temp2 = delta_subtract(temp1, offset);
        jacpy_release(temp1);
        if not temp2 {
            jacpy_release(offset);
            return -1;
        }
        hash = PyObject_Hash(temp2);
        record[0].hashcode = hash;
        jacpy_release(temp2);
    }
    jacpy_release(offset);
    return hash;
}

"""The local timezone at a timestamp: a fixed timezone with the platform's
offset and zone name."""
def local_timezone_from_timestamp(timestamp: i64) -> ptr[PyObject] {
    local_time_tm = tm();
    if _PyTime_localtime(timestamp, &mut local_time_tm) != 0 {
        return NULL;
    }
    zone = local_time_tm.tm_zone;
    delta = new_delta(0, local_time_tm.tm_gmtoff, 0, 1);
    if not delta {
        return NULL;
    }
    nameo: ptr[PyObject] = NULL;
    if zone {
        nameo = PyUnicode_DecodeLocale(ptr(zone), ptr[u8]("surrogateescape"));
        if not nameo {
            jacpy_release(delta);
            return NULL;
        }
    }
    result = new_timezone(delta, nameo);
    jacpy_release(nameo);
    jacpy_release(delta);
    return result;
}

"""The local timezone of an aware UTC datetime."""
def local_timezone(utc_time: ptr[PyObject]) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    delta = datetime_subtract(utc_time, state_value(module, STATE_EPOCH));
    jacpy_release(module);
    if not delta {
        return NULL;
    }
    one_second = new_delta(0, 1, 0, 0);
    if not one_second {
        jacpy_release(delta);
        return NULL;
    }
    seconds = divide_timedelta_timedelta(delta, one_second);
    jacpy_release(one_second);
    jacpy_release(delta);
    if not seconds {
        return NULL;
    }
    timestamp = _PyLong_AsTime_t(seconds);
    jacpy_release(seconds);
    if timestamp == -1 and PyErr_Occurred() {
        return NULL;
    }
    return local_timezone_from_timestamp(timestamp);
}

"""Seconds since 0001-01-01 of the UTC time a local time maps to: solve
t = local(u) for u, the earlier solution for fold 0 and the later for fold
1; in a gap, the later or earlier of the two candidates. -1 on error."""
def local_to_seconds(
    year: int, month: int, day: int, hour: int, minute: int, second: int, fold: int
) -> int {
    t = utc_to_seconds(year, month, day, hour, minute, second);
    # Our goal is to solve t = local(u) for u.
    lt = local(t);
    if lt == -1 {
        return -1;
    }
    a = lt - t;
    u1 = t - a;
    t1 = local(u1);
    if t1 == -1 {
        return -1;
    }
    b = 0;
    if t1 == t {
        # We found one solution, but it may not be the one we need. Look for
        # an earlier solution (if `fold` is 0), or a later one (if `fold` is
        # 1).
        u2 = u1 + MAX_FOLD_SECONDS if fold != 0 else u1 - MAX_FOLD_SECONDS;
        lt = local(u2);
        if lt == -1 {
            return -1;
        }
        b = lt - u2;
        if a == b {
            return u1;
        }
    } else {
        b = t1 - u1;
    }
    u2 = t - b;
    t2 = local(u2);
    if t2 == -1 {
        return -1;
    }
    if t2 == t {
        return u2;
    }
    if t1 == t {
        return u1;
    }
    # We have found both offsets a and b, but neither t - a nor t - b is a
    # solution. This means t is in the gap.
    return min(u1, u2) if fold != 0 else max(u1, u2);
}

"""The local timezone of a naive local datetime."""
def local_timezone_from_local(local_dt: ptr[PyObject]) -> ptr[PyObject] {
    fold = date_get_fold(local_dt);
    seconds = local_to_seconds(
        get_year(local_dt),
        get_month(local_dt),
        get_day(local_dt),
        date_get_hour(local_dt),
        date_get_minute(local_dt),
        date_get_second(local_dt),
        fold
    );
    if seconds == -1 {
        return NULL;
    }
    seconds2 = local_to_seconds(
        get_year(local_dt),
        get_month(local_dt),
        get_day(local_dt),
        date_get_hour(local_dt),
        date_get_minute(local_dt),
        date_get_second(local_dt),
        1 - fold
    );
    if seconds2 == -1 {
        return NULL;
    }
    # Detect gap
    if seconds2 != seconds and (1 if seconds2 > seconds else 0) == fold {
        seconds = seconds2;
    }
    return local_timezone_from_timestamp(seconds - EPOCH_SECONDS);
}

def datetime_astimezone(
    op: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="astimezone").parse_keywords(
            args, kw, "|O", ["tz"]
        );
    } except boundary_failure {
        return NULL;
    }
    tzinfo = values[0].object if values[0].given else Py_None;
    if check_tzinfo_subclass(tzinfo) == -1 {
        return NULL;
    }
    naive = not has_tzinfo(op)
        or ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo == Py_None;
    offset: ptr[PyObject] = NULL;
    while True {
        self_tzinfo: ptr[PyObject] = NULL;
        if naive {
            self_tzinfo = local_timezone_from_local(op);
            if not self_tzinfo {
                return NULL;
            }
        } else {
            self_tzinfo = Py_NewRef(ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo);
        }
        # Conversion to self's own time zone is a NOP.
        if self_tzinfo == tzinfo {
            jacpy_release(self_tzinfo);
            return Py_NewRef(op);
        }
        # Convert self to UTC.
        offset = call_utcoffset(self_tzinfo, op);
        jacpy_release(self_tzinfo);
        if not offset {
            return NULL;
        }
        if offset == Py_None {
            jacpy_release(offset);
            naive = True;
            continue;
        }
        break;
    }
    if not delta_check(offset) {
        PyErr_Format(
            PyExc_TypeError,
            "utcoffset() returned %.200s, expected timedelta or None",
            type_name_of(offset)
        );
        jacpy_release(offset);
        return NULL;
    }
    # result = self - offset
    result = add_datetime_timedelta(op, offset, -1);
    jacpy_release(offset);
    if not result {
        return NULL;
    }
    # Make sure result is aware and UTC.
    if not has_tzinfo(result) {
        temp = result;
        result = new_datetime_ex2(
            get_year(result),
            get_month(result),
            get_day(result),
            date_get_hour(result),
            date_get_minute(result),
            date_get_second(result),
            date_get_microsecond(result),
            utc(),
            date_get_fold(result),
            ptr[PyTypeObject](type_of(result))
        );
        jacpy_release(temp);
        if not result {
            return NULL;
        }
    } else {
        # Result is already aware - just replace tzinfo.
        record = ptr[PyDateTime_DateTime](result).view(1);
        old = record[0].tzinfo;
        record[0].tzinfo = Py_NewRef(utc());
        jacpy_release(old);
    }
    # Attach new tzinfo and let fromutc() do the rest.
    if tzinfo == Py_None {
        tzinfo = local_timezone(result);
        if not tzinfo {
            jacpy_release(result);
            return NULL;
        }
    } else {
        tzinfo = Py_NewRef(tzinfo);
    }
    record = ptr[PyDateTime_DateTime](result).view(1);
    old = record[0].tzinfo;
    record[0].tzinfo = tzinfo;
    jacpy_release(old);
    temp = result;
    result = PyObject_CallMethod(tzinfo, "fromutc", "O", temp);
    jacpy_release(temp);
    return result;
}

def datetime_timetuple(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    dstflag = -1;
    if has_tzinfo(op) and ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo != Py_None {
        dst = call_dst(ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo, op);
        if not dst {
            return NULL;
        }
        if dst != Py_None {
            dstflag = int(delta_bool(dst));
        }
        jacpy_release(dst);
    }
    return build_struct_time(
        get_year(op),
        get_month(op),
        get_day(op),
        date_get_hour(op),
        date_get_minute(op),
        date_get_second(op),
        dstflag
    );
}

def datetime_timestamp(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    if has_tzinfo(op) and ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo != Py_None {
        module = get_current_state();
        if not module {
            return NULL;
        }
        delta = datetime_subtract(op, state_value(module, STATE_EPOCH));
        jacpy_release(module);
        if not delta {
            return NULL;
        }
        result = delta_total_seconds(delta, NULL);
        jacpy_release(delta);
        return result;
    }
    seconds = local_to_seconds(
        get_year(op),
        get_month(op),
        get_day(op),
        date_get_hour(op),
        date_get_minute(op),
        date_get_second(op),
        date_get_fold(op)
    );
    if seconds == -1 {
        return NULL;
    }
    return PyFloat_FromDouble(
        f64(seconds - EPOCH_SECONDS) + f64(date_get_microsecond(op)) / 1e6
    );
}

def datetime_getdate(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return new_date(get_year(op), get_month(op), get_day(op));
}

def datetime_gettime(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return new_time(
        date_get_hour(op),
        date_get_minute(op),
        date_get_second(op),
        date_get_microsecond(op),
        Py_None,
        date_get_fold(op)
    );
}

def datetime_gettimetz(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return new_time(
        date_get_hour(op),
        date_get_minute(op),
        date_get_second(op),
        date_get_microsecond(op),
        datetime_tzinfo_of(op),
        date_get_fold(op)
    );
}

def datetime_utctimetuple(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    tzinfo = datetime_tzinfo_of(op);
    utcself: ptr[PyObject] = NULL;
    if tzinfo == Py_None {
        utcself = Py_NewRef(op);
    } else {
        offset = call_utcoffset(tzinfo, op);
        if not offset {
            return NULL;
        }
        if offset == Py_None {
            jacpy_release(offset);
            utcself = Py_NewRef(op);
        } else {
            utcself = add_datetime_timedelta(op, offset, -1);
            jacpy_release(offset);
            if not utcself {
                return NULL;
            }
        }
    }
    y = get_year(utcself);
    m = get_month(utcself);
    d = get_day(utcself);
    hh = date_get_hour(utcself);
    mm = date_get_minute(utcself);
    ss = date_get_second(utcself);
    jacpy_release(utcself);
    return build_struct_time(y, m, d, hh, mm, ss, 0);
}

# ---------------------------------------------------------------------------
# Pickle support, a simple use of __reduce__.

"""(basestate,) or (basestate, tzinfo), where basestate is the non-tzinfo
data; the fold sets the first bit of the third byte for protocols above 3.
__getstate__ isn't exposed."""
def datetime_getstate(op: ptr[PyObject], proto: int) -> ptr[PyObject] {
    basestate = data_bytes(op, DATETIME_DATASIZE);
    if not basestate {
        return NULL;
    }
    if proto > 3 and date_get_fold(op) != 0 {
        # Set the first bit of the third byte
        third = ptr[u8](jacpy_bytes_address(basestate)) + 2;
        third.view(1)[0] = third.view(1)[0] | u8(128);
    }
    result: ptr[PyObject] = NULL;
    if not has_tzinfo(op)
        or ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo == Py_None {
        result = PyTuple_Pack(1, basestate);
    } else {
        result = PyTuple_Pack(
            2, basestate, ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo
        );
    }
    jacpy_release(basestate);
    return result;
}

def datetime_reduce_ex(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        proto = ArgumentFormat(name="__reduce_ex__").parse(args, "i")[0].signed;
    } except boundary_failure {
        return NULL;
    }
    return Py_BuildValue("(ON)", type_of(op), datetime_getstate(op, proto));
}

def datetime_reduce(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(ON)", type_of(op), datetime_getstate(op, 2));
}
