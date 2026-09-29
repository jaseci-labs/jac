"""The datetime.time type of the _datetime module.

Modules/_datetimemodule.c's PyDateTime_Time implementation in native Jac:
`PyDateTime_TimeType` is C data under its C name. A time is allocated
with or without room for its tzinfo member, as the C tp_alloc does. See
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
    PyErr_SetString,
    PyExc_TypeError,
    PyExc_UnicodeEncodeError,
    PyExc_ValueError,
    PyLong_FromLong,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_GenericGetAttr,
    PyObject_Hash,
    PyObject_Init,
    PyObject_Malloc,
    PyTuple_GetItem,
    PyTuple_Pack,
    PyTuple_Size,
    PyUnicode_AppendAndDel,
    PyUnicode_AsLatin1String,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_FromFormat,
    PyUnicode_GetLength,
    PyUnicode_ReadChar
}
import from jaclang.runtime.python.layouts {
    PY_DATETIME_BASE_TIME_SIZE,
    PY_DATETIME_TIME_SIZE,
    PyDateTime_Time,
    PyGetSetDef,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.modules.datetime_calendar {
    IsoTime,
    parse_isoformat_time
}
import from jaclang.runtime.python.modules.datetime_format {
    format_utcoffset,
    wrap_strftime
}
import from jaclang.runtime.python.modules.datetime_objects {
    Py_EQ,
    Py_NE,
    append_keyword_fold,
    append_keyword_tzinfo,
    call_dst,
    call_tzname,
    call_utcoffset,
    check_tzinfo_subclass,
    data_address,
    data_bytes,
    delta_check,
    delta_cmp,
    delta_subtract,
    diff_to_bool,
    has_tzinfo,
    new_delta,
    new_time,
    new_time_ex2,
    not_implemented,
    td_days,
    td_seconds,
    time_check,
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
    type_of
}
import from jaclang.runtime.python.modules.datetime_date {
    compare_data,
    generic_hash,
    strptime_via
}

import from c {
    glob PyType_Type: PyTypeObject; glob:priv time_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("hour"), get=time_hour),
             PyGetSetDef(name=ptr[u8]("minute"), get=time_minute),
             PyGetSetDef(name=ptr[u8]("second"), get=py_time_second),
             PyGetSetDef(name=ptr[u8]("microsecond"), get=time_microsecond),
             PyGetSetDef(name=ptr[u8]("tzinfo"), get=time_tzinfo),
             PyGetSetDef(name=ptr[u8]("fold"), get=time_fold),
             PyGetSetDef()
         ]; glob PyDateTime_TimeType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.time"),
             tp_basicsize=PY_DATETIME_TIME_SIZE,
             tp_dealloc=time_dealloc,
             tp_repr=time_repr,
             tp_hash=time_hash,
             tp_str=time_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "time([hour[, minute[, second[, microsecond[, tzinfo]]]]]) --> a time object\n"
                 "\n"
                 "All arguments are optional. tzinfo may be None, or an instance of\n"
                 "a tzinfo subclass. The remaining arguments may be ints.\n"
             ),
             tp_richcompare=time_richcompare,
             tp_getset=addressof(time_getset),
             tp_alloc=time_alloc,
             tp_new=time_new
         );
}

# _PyDateTime_TIME_DATASIZE: bytes of hour, minute, second, and usecond.
glob TIME_DATASIZE: Final[int] = 6;

"""tp_alloc: `aware` (C's nitems) says whether the tzinfo member is needed,
so a naive time takes less memory. Subclasses allocate the full size."""
def time_alloc(type: ptr[PyTypeObject], aware: i64) -> ptr[PyObject] {
    size = PY_DATETIME_TIME_SIZE if aware != 0 else PY_DATETIME_BASE_TIME_SIZE;
    self = PyObject_Malloc(u64(size));
    if not self {
        return PyErr_NoMemory();
    }
    return PyObject_Init(ptr[PyObject](self), ptr[PyObject](type));
}

# ---------------------------------------------------------------------------
# Accessor properties.

def time_hour(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(time_get_hour(op));
}

def time_minute(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(time_get_minute(op));
}

"""The name time_second conflicted with some platform header file."""
def py_time_second(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(time_get_second(op));
}

def time_microsecond(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(time_get_microsecond(op));
}

def time_tzinfo(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(time_tzinfo_of(op));
}

def time_fold(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(time_get_fold(op));
}

# ---------------------------------------------------------------------------
# Constructors.

"""A time from the 6-byte state of its pickle and its tzinfo; the high bit
of the first byte is the fold."""
def time_from_pickle(
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
        for i in range(TIME_DATASIZE) {
            (target + i).view(1)[0] = (source + i).view(1)[0];
        }
        record = ptr[PyDateTime_Time](me).view(1);
        record[0].hashcode = -1;
        record[0].hastzinfo = i8(1 if aware else 0);
        if aware {
            record[0].tzinfo = Py_NewRef(tzinfo);
        }
        if (int(source.view(1)[0]) & (1 << 7)) != 0 {
            record[0].data = record[0].data - u8(128);
            record[0].fold = u8(1);
        } else {
            record[0].fold = u8(0);
        }
    }
    return me;
}

def time_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    # Check for invocation from pickle with __getstate__ state
    count = PyTuple_Size(args);
    if count >= 1 and count <= 2 {
        state = PyTuple_GetItem(args, 0);
        tzinfo = PyTuple_GetItem(args, 1) if count == 2 else Py_None;
        if jacpy_is_bytes(state) != 0 {
            if PyBytes_Size(state) == TIME_DATASIZE
                and (0x7F & int(ptr[u8](jacpy_bytes_address(state)).view(1)[0])) < 24 {
                return time_from_pickle(type, state, tzinfo);
            }
        } elif jacpy_is_unicode(state) != 0 {
            if PyUnicode_GetLength(state) == TIME_DATASIZE
                and (0x7F & int(PyUnicode_ReadChar(state, 0))) < 24 {
                latin1 = PyUnicode_AsLatin1String(state);
                if not latin1 {
                    if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
                        # More informative error message.
                        PyErr_SetString(
                            PyExc_ValueError,
                            "Failed to encode latin1 string when unpickling a time object. pickle.load(data, encoding='latin1') is assumed."
                        );
                    }
                    return NULL;
                }
                self = time_from_pickle(type, latin1, tzinfo);
                jacpy_release(latin1);
                return self;
            }
        }
    }
    try {
        values = ArgumentFormat().parse_keywords(
            args,
            kw,
            "|iiiiO$i",
            ["hour", "minute", "second", "microsecond", "tzinfo", "fold"]
        );
    } except boundary_failure {
        return NULL;
    }
    return new_time_ex2(
        values[0].signed,
        values[1].signed,
        values[2].signed,
        values[3].signed,
        values[4].object if values[4].given else Py_None,
        values[5].signed,
        type
    );
}

"""Return new time from _strptime._strptime_datetime_time()."""
def time_strptime(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return strptime_via(cls, args, "_strptime_datetime_time");
}

def time_dealloc(op: ptr[PyObject]) {
    if has_tzinfo(op) {
        jacpy_release(ptr[PyDateTime_Time](op).view(1)[0].tzinfo);
    }
    type_free(op);
}

# ---------------------------------------------------------------------------
# Indirect access to tzinfo methods.

def time_utcoffset(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_utcoffset(time_tzinfo_of(op), Py_None);
}

def time_dst(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_dst(time_tzinfo_of(op), Py_None);
}

def time_tzname(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzname(time_tzinfo_of(op), Py_None);
}

# ---------------------------------------------------------------------------
# Various ways to turn a time into a string.

def time_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    type_name = type_name_of(op);
    h = time_get_hour(op);
    m = time_get_minute(op);
    s = time_get_second(op);
    us = time_get_microsecond(op);
    fold = time_get_fold(op);
    result: ptr[PyObject] = NULL;
    if us != 0 {
        result = PyUnicode_FromFormat("%s(%ld, %ld, %ld, %ld)", type_name, h, m, s, us);
    } elif s != 0 {
        result = PyUnicode_FromFormat("%s(%ld, %ld, %ld)", type_name, h, m, s);
    } else {
        result = PyUnicode_FromFormat("%s(%ld, %ld)", type_name, h, m);
    }
    if result and has_tzinfo(op) {
        result = append_keyword_tzinfo(
            result, ptr[PyDateTime_Time](op).view(1)[0].tzinfo
        );
    }
    if result and fold != 0 {
        result = append_keyword_fold(result, fold);
    }
    return result;
}

def time_str(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_CallMethod(op, "isoformat", "");
}

# The timespec names isoformat() takes, in C's table order.
glob TIMESPECS: list[str] = [
         "hours",
         "minutes",
         "seconds",
         "milliseconds",
         "microseconds"
     ];

"""The index of `timespec` in TIMESPECS, choosing seconds or microseconds
for "auto" (or none given) by whether there are microseconds; the length of
TIMESPECS for an unknown name."""
def timespec_index(timespec: str, given: bool, us: int) -> int {
    if not given or timespec == "auto" {
        return 4 if us != 0 else 2;
    }
    for index in range(len(TIMESPECS)) {
        if timespec == TIMESPECS[index] {
            return index;
        }
    }
    return len(TIMESPECS);
}

"""Append the UTC offset of `tzinfo` (called with `tzinfoarg`) to
`result`, which this consumes."""
def append_utcoffset(
    result: ptr[PyObject], tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    offset = format_utcoffset(":", tzinfo, tzinfoarg);
    if not offset {
        jacpy_release(result);
        return NULL;
    }
    joined = result;
    PyUnicode_AppendAndDel(&mut joined, offset);
    return joined;
}

def time_isoformat(
    op: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="isoformat").parse_keywords(
            args, kw, "|s", ["timespec"]
        );
    } except boundary_failure {
        return NULL;
    }
    us = time_get_microsecond(op);
    given_spec = timespec_index(values[0].text, values[0].given, us);
    h = time_get_hour(op);
    m = time_get_minute(op);
    s = time_get_second(op);
    result: ptr[PyObject] = NULL;
    if given_spec == 0 {
        result = PyUnicode_FromFormat("%02ld", h);
    } elif given_spec == 1 {
        result = PyUnicode_FromFormat("%02ld:%02ld", h, m);
    } elif given_spec == 2 {
        result = PyUnicode_FromFormat("%02ld:%02ld:%02ld", h, m, s);
    } elif given_spec == 3 {
        # milliseconds
        result = PyUnicode_FromFormat("%02ld:%02ld:%02ld.%03ld", h, m, s, us // 1000);
    } elif given_spec == 4 {
        result = PyUnicode_FromFormat("%02ld:%02ld:%02ld.%06ld", h, m, s, us);
    } else {
        PyErr_Format(PyExc_ValueError, "Unknown timespec value");
        return NULL;
    }
    if not result
        or not has_tzinfo(op)
        or ptr[PyDateTime_Time](op).view(1)[0].tzinfo == Py_None {
        return result;
    }
    # We need to append the UTC offset.
    return append_utcoffset(
        result, ptr[PyDateTime_Time](op).view(1)[0].tzinfo, Py_None
    );
}

def time_strftime(
    op: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="strftime").parse_keywords(
            args, kw, "U", ["format"]
        );
    } except boundary_failure {
        return NULL;
    }
    # Python's strftime does insane things with the year part of the
    # timetuple. The year is forced to (the otherwise nonsensical) 1900 to
    # work around that.
    tuple = Py_BuildValue(
        "lllllllll",
        1900,
        1,
        1,
        time_get_hour(op),
        time_get_minute(op),
        time_get_second(op),
        0,
        1,
        -1
    );
    if not tuple {
        return NULL;
    }
    result = wrap_strftime(op, values[0].object, tuple, Py_None);
    jacpy_release(tuple);
    return result;
}

# ---------------------------------------------------------------------------
# Miscellaneous methods.

def time_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not time_check(other) {
        return not_implemented();
    }
    if time_tzinfo_of(self) == time_tzinfo_of(other) {
        return diff_to_bool(compare_data(self, other, TIME_DATASIZE), int(op));
    }
    offset1 = time_utcoffset(self, NULL);
    if not offset1 {
        return NULL;
    }
    offset2 = time_utcoffset(other, NULL);
    result: ptr[PyObject] = NULL;
    if offset2 {
        # If they're both naive, or both aware and have the same offsets, we
        # get off cheap. Both naive means offset1 == offset2 == None here.
        if offset1 == offset2
            or (
                delta_check(offset1)
                and delta_check(offset2)
                and delta_cmp(offset1, offset2) == 0
            ) {
            result = diff_to_bool(compare_data(self, other, TIME_DATASIZE), int(op));
        } elif offset1 != Py_None and offset2 != Py_None {
            # The hard case: both aware with different UTC offsets
            offsecs1 = time_get_hour(self) * 3600
                + time_get_minute(self) * 60
                + time_get_second(self)
                - td_days(offset1) * 86400
                - td_seconds(offset1);
            offsecs2 = time_get_hour(other) * 3600
                + time_get_minute(other) * 60
                + time_get_second(other)
                - td_days(offset2) * 86400
                - td_seconds(offset2);
            diff = offsecs1 - offsecs2;
            if diff == 0 {
                diff = time_get_microsecond(self) - time_get_microsecond(other);
            }
            result = diff_to_bool(diff, int(op));
        } elif int(op) == Py_EQ {
            result = PyBool_FromLong(0);
        } elif int(op) == Py_NE {
            result = PyBool_FromLong(1);
        } else {
            PyErr_SetString(
                PyExc_TypeError, "can't compare offset-naive and offset-aware times"
            );
        }
    }
    jacpy_release(offset1);
    jacpy_release(offset2);
    return result;
}

def time_hash(op: ptr[PyObject]) -> i64 {
    record = ptr[PyDateTime_Time](op).view(1);
    hash = record[0].hashcode;
    if hash != -1 {
        return hash;
    }
    self0: ptr[PyObject] = NULL;
    if time_get_fold(op) != 0 {
        self0 = new_time_ex2(
            time_get_hour(op),
            time_get_minute(op),
            time_get_second(op),
            time_get_microsecond(op),
            time_tzinfo_of(op),
            0,
            ptr[PyTypeObject](type_of(op))
        );
        if not self0 {
            return -1;
        }
    } else {
        self0 = Py_NewRef(op);
    }
    offset = time_utcoffset(self0, NULL);
    jacpy_release(self0);
    if not offset {
        return -1;
    }
    # Reduce this to a hash of another object.
    if offset == Py_None {
        hash = generic_hash(op, TIME_DATASIZE);
        record[0].hashcode = hash;
    } else {
        seconds = time_get_hour(op) * 3600
            + time_get_minute(op) * 60
            + time_get_second(op);
        temp1 = new_delta(0, seconds, time_get_microsecond(op), 1);
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

def time_fromisoformat(cls: ptr[PyObject], tstr: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(tstr) == 0 {
        PyErr_SetString(PyExc_TypeError, "fromisoformat: argument must be str");
        return NULL;
    }
    length: i64 = 0;
    text = PyUnicode_AsUTF8AndSize(tstr, &mut length);
    if not text {
        PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", tstr);
        return NULL;
    }
    # The spec actually requires that time-only ISO 8601 strings start with
    # T, but the extended format allows this to be omitted as long as there
    # is no ambiguity with date strings.
    if text.view(1)[0] == 84 {
        text += 1;
        length -= 1;
    }
    parsed = IsoTime();
    rv = parse_isoformat_time(text, int(length), parsed);
    if rv < 0 {
        PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", tstr);
        return NULL;
    }
    if parsed.hour == 24 {
        if parsed.minute == 0 and parsed.second == 0 and parsed.microsecond == 0 {
            parsed.hour = 0;
        } else {
            PyErr_SetString(
                PyExc_ValueError,
                "minute, second, and microsecond must be 0 when hour is 24"
            );
            return NULL;
        }
    }
    tzinfo = tzinfo_from_isoformat_results(rv, parsed.tzoffset, parsed.tzmicrosecond);
    if not tzinfo {
        return NULL;
    }
    t: ptr[PyObject] = NULL;
    if cls == type_object(time_type()) {
        t = new_time(
            parsed.hour, parsed.minute, parsed.second, parsed.microsecond, tzinfo, 0
        );
    } else {
        t = PyObject_CallFunction(
            cls,
            "llllO",
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.microsecond,
            tzinfo
        );
    }
    jacpy_release(tzinfo);
    return t;
}

# ---------------------------------------------------------------------------
# Pickle support, a simple use of __reduce__.

"""(basestate,) or (basestate, tzinfo), where basestate is the non-tzinfo
data; the fold sets the first bit of the first byte for protocols above 3.
__getstate__ isn't exposed."""
def time_getstate(op: ptr[PyObject], proto: int) -> ptr[PyObject] {
    basestate = data_bytes(op, TIME_DATASIZE);
    if not basestate {
        return NULL;
    }
    if proto > 3 and time_get_fold(op) != 0 {
        # Set the first bit of the first byte
        first = ptr[u8](jacpy_bytes_address(basestate));
        first.view(1)[0] = first.view(1)[0] | u8(128);
    }
    result: ptr[PyObject] = NULL;
    if not has_tzinfo(op) or ptr[PyDateTime_Time](op).view(1)[0].tzinfo == Py_None {
        result = PyTuple_Pack(1, basestate);
    } else {
        result = PyTuple_Pack(2, basestate, ptr[PyDateTime_Time](op).view(1)[0].tzinfo);
    }
    jacpy_release(basestate);
    return result;
}

def time_reduce_ex(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        proto = ArgumentFormat(name="__reduce_ex__").parse(args, "i")[0].signed;
    } except boundary_failure {
        return NULL;
    }
    return Py_BuildValue("(ON)", type_of(op), time_getstate(op, proto));
}

def time_reduce(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(ON)", type_of(op), time_getstate(op, 2));
}
