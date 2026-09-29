"""The datetime.date type and IsoCalendarDate of the _datetime module.

Modules/_datetimemodule.c's PyDateTime_Date implementation in native Jac:
`PyDateTime_DateType` is C data under its C name. The IsoCalendarDate
tuple subclass is a heap type per module; its slots are here and its spec
is in bindings/datetime.jac beside the clinic glue its constructor comes
from. See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_address,
    jacpy_is_bytes,
    jacpy_is_unicode,
    jacpy_release,
    NULL,
    Py_BuildValue,
    Py_HashBuffer,
    Py_NewRef,
    PyBytes_Size,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_SetString,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_UnicodeEncodeError,
    PyExc_ValueError,
    PyImport_ImportModule,
    PyLong_FromLong,
    PyObject,
    PyObject_CallMethod,
    PyObject_GenericGetAttr,
    PyObject_Str,
    PyTuple_GetItem,
    PyTuple_SetItem,
    PyTuple_Size,
    PyType_GetSlot,
    PyUnicode_AsLatin1String,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_FromFormat,
    PyUnicode_GetLength,
    PyUnicode_ReadChar,
    _PyTime_ObjectToTime_t,
    _PyTime_localtime
}
import from jaclang.runtime.python.layouts {
    PY_DATETIME_DATE_SIZE,
    PyDateTime_Date,
    PyGetSetDef,
    PyNumberMethods,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_tp_traverse,
    _PyTime_ROUND_FLOOR,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.bindings.module { visit_reference }
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.modules.time_records { tm }
import from jaclang.runtime.python.modules.datetime_calendar {
    DateTimeFields,
    MAXYEAR,
    MINYEAR,
    YearMonthDay,
    iso_to_ymd,
    iso_week1_monday,
    ord_to_ymd,
    parse_isoformat_date,
    weekday,
    ymd_to_ord
}
import from jaclang.runtime.python.modules.datetime_format {
    build_struct_time,
    format_ctime,
    time_time,
    wrap_strftime
}
import from jaclang.runtime.python.modules.datetime_objects {
    STATE_ISOCALENDAR_DATE_TYPE,
    data_address,
    data_bytes,
    date_check,
    datetime_check,
    delta_check,
    diff_to_bool,
    get_current_state,
    get_day,
    get_month,
    get_year,
    new_date_ex,
    new_date_subclass_ex,
    new_delta,
    normalize_date,
    not_implemented,
    state_value,
    td_days,
    type_alloc,
    type_name_of,
    type_of
}

import from c {
    glob PyType_Type: PyTypeObject,
         PyTuple_Type: PyTypeObject;
    # A tp_traverse slot, called with the visitproc it was given.
    obj TraverseCall {
        has call: Callable[[ptr[PyObject], ptr, ptr], i32] = 0;
    }  glob:priv date_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=date_add, nb_subtract=date_subtract
         ),
         date_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("year"), get=date_year),
             PyGetSetDef(name=ptr[u8]("month"), get=date_month),
             PyGetSetDef(name=ptr[u8]("day"), get=date_day),
             PyGetSetDef()
         ]; glob PyDateTime_DateType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.date"),
             tp_basicsize=PY_DATETIME_DATE_SIZE,
             tp_repr=date_repr,
             tp_as_number=addressof(date_as_number),
             tp_hash=date_hash,
             tp_str=date_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8]("date(year, month, day) --> date object"),
             tp_richcompare=date_richcompare,
             tp_getset=addressof(date_getset),
             tp_new=date_new
         );
}

# _PyDateTime_DATE_DATASIZE: bytes of year, month, and day.
glob DATE_DATASIZE: Final[int] = 4;

# ---------------------------------------------------------------------------
# Accessor properties.

def date_year(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(get_year(op));
}

def date_month(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(get_month(op));
}

def date_day(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromLong(get_day(op));
}

# ---------------------------------------------------------------------------
# Constructors.

"""A date from the 4-byte state of its pickle."""
def date_from_pickle(type: ptr[PyTypeObject], state: ptr[PyObject]) -> ptr[PyObject] {
    me = type_alloc(type, 0);
    if me {
        source = ptr[u8](jacpy_bytes_address(state));
        target = data_address(me);
        for i in range(DATE_DATASIZE) {
            (target + i).view(1)[0] = (source + i).view(1)[0];
        }
        ptr[PyDateTime_Date](me).view(1)[0].hashcode = -1;
    }
    return me;
}

"""MONTH_IS_SANE."""
def month_is_sane(month: int) -> bool {
    return 1 <= month and month <= 12;
}

def date_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    # Check for invocation from pickle with __getstate__ state
    if PyTuple_Size(args) == 1 {
        state = PyTuple_GetItem(args, 0);
        if jacpy_is_bytes(state) != 0 {
            if PyBytes_Size(state) == DATE_DATASIZE
                and month_is_sane(
                    int((ptr[u8](jacpy_bytes_address(state)) + 2).view(1)[0])
                ) {
                return date_from_pickle(type, state);
            }
        } elif jacpy_is_unicode(state) != 0 {
            if PyUnicode_GetLength(state) == DATE_DATASIZE
                and month_is_sane(int(PyUnicode_ReadChar(state, 2))) {
                latin1 = PyUnicode_AsLatin1String(state);
                if not latin1 {
                    if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
                        # More informative error message.
                        PyErr_SetString(
                            PyExc_ValueError,
                            "Failed to encode latin1 string when unpickling a date object. pickle.load(data, encoding='latin1') is assumed."
                        );
                    }
                    return NULL;
                }
                self = date_from_pickle(type, latin1);
                jacpy_release(latin1);
                return self;
            }
        }
    }
    try {
        values = ArgumentFormat().parse_keywords(
            args, kw, "iii", ["year", "month", "day"]
        );
    } except boundary_failure {
        return NULL;
    }
    return new_date_ex(values[0].signed, values[1].signed, values[2].signed, type);
}

"""date.fromtimestamp(timestamp) for the class `cls`: the local date."""
def date_fromtimestamp(cls: ptr[PyObject], timestamp: ptr[PyObject]) -> ptr[PyObject] {
    t: i64 = 0;
    if _PyTime_ObjectToTime_t(timestamp, &mut t, _PyTime_ROUND_FLOOR) == -1 {
        return NULL;
    }
    moment = tm();
    if _PyTime_localtime(t, &mut moment) != 0 {
        return NULL;
    }
    return new_date_subclass_ex(
        int(moment.tm_year) + 1900, int(moment.tm_mon) + 1, int(moment.tm_mday), cls
    );
}

"""Return new date from current time: fromtimestamp(time.time()) of the
class, which may be datetime, so all the accuracy time.time() gives is
kept."""
def date_today(cls: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    time = time_time();
    if not time {
        return NULL;
    }
    result = PyObject_CallMethod(cls, "fromtimestamp", "O", time);
    jacpy_release(time);
    return result;
}

"""Return new date from proleptic Gregorian ordinal; ValueError if the
ordinal is out of range."""
def date_fromordinal(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        ordinal = ArgumentFormat(name="fromordinal").parse(args, "i")[0].signed;
    } except boundary_failure {
        return NULL;
    }
    if ordinal < 1 {
        PyErr_SetString(PyExc_ValueError, "ordinal must be >= 1");
        return NULL;
    }
    found = ord_to_ymd(ordinal);
    return new_date_subclass_ex(found.year, found.month, found.day, cls);
}

"""Return the new date from a string as generated by date.isoformat()."""
def date_fromisoformat(cls: ptr[PyObject], dtstr: ptr[PyObject]) -> ptr[PyObject] {
    if jacpy_is_unicode(dtstr) == 0 {
        PyErr_SetString(PyExc_TypeError, "fromisoformat: argument must be str");
        return NULL;
    }
    length: i64 = 0;
    text = PyUnicode_AsUTF8AndSize(dtstr, &mut length);
    rv = -1;
    found = YearMonthDay();
    if text and (length == 7 or length == 8 or length == 10) {
        rv = parse_isoformat_date(text, int(length), found);
    }
    if rv < 0 {
        PyErr_Format(PyExc_ValueError, "Invalid isoformat string: %R", dtstr);
        return NULL;
    }
    return new_date_subclass_ex(found.year, found.month, found.day, cls);
}

def date_fromisocalendar(
    cls: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="fromisocalendar").parse_keywords(
            args, kw, "iii", ["year", "week", "day"]
        );
    } except boundary_failure {
        if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            PyErr_Format(PyExc_ValueError, "ISO calendar component out of range");
        }
        return NULL;
    }
    year = values[0].signed;
    week = values[1].signed;
    day = values[2].signed;
    found = YearMonthDay();
    rv = iso_to_ymd(year, week, day, found);
    if rv == -4 {
        PyErr_Format(
            PyExc_ValueError,
            "year must be in %ld..%ld, not %ld",
            MINYEAR,
            MAXYEAR,
            year
        );
        return NULL;
    }
    if rv == -2 {
        PyErr_Format(PyExc_ValueError, "Invalid week: %ld", week);
        return NULL;
    }
    if rv == -3 {
        PyErr_Format(PyExc_ValueError, "Invalid weekday: %ld (range is [1, 7])", day);
        return NULL;
    }
    return new_date_subclass_ex(found.year, found.month, found.day, cls);
}

"""Parse `string` with `format` through _strptime's `function` for `cls`."""
def strptime_via(
    cls: ptr[PyObject], args: ptr[PyObject], function: str
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="strptime").parse(args, "UU");
    } except boundary_failure {
        return NULL;
    }
    module = PyImport_ImportModule("_strptime");
    if not module {
        return NULL;
    }
    result = PyObject_CallMethod(
        module, function, "OOO", cls, values[0].object, values[1].object
    );
    jacpy_release(module);
    return result;
}

"""Return new date from _strptime._strptime_datetime_date()."""
def date_strptime(cls: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return strptime_via(cls, args, "_strptime_datetime_date");
}

# ---------------------------------------------------------------------------
# Date arithmetic.

"""date + timedelta -> date; subtract the timedelta instead when negate is
set."""
def add_date_timedelta(
    date: ptr[PyObject], delta: ptr[PyObject], negate: bool
) -> ptr[PyObject] {
    deltadays = td_days(delta);
    fields = DateTimeFields(
        year=get_year(date),
        month=get_month(date),
        day=get_day(date) + (-deltadays if negate else deltadays)
    );
    if normalize_date(fields) < 0 {
        return NULL;
    }
    return new_date_subclass_ex(fields.year, fields.month, fields.day, type_of(date));
}

def date_add(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if datetime_check(left) or datetime_check(right) {
        return not_implemented();
    }
    if date_check(left) {
        # date + delta
        if delta_check(right) {
            return add_date_timedelta(left, right, False);
        }
    } elif delta_check(left) {
        # delta + date; `right` must be one of us, or we wouldn't have been
        # called
        return add_date_timedelta(right, left, False);
    }
    return not_implemented();
}

def date_subtract(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if datetime_check(left) or datetime_check(right) {
        return not_implemented();
    }
    if date_check(left) {
        if date_check(right) {
            # date - date
            left_ord = ymd_to_ord(get_year(left), get_month(left), get_day(left));
            right_ord = ymd_to_ord(get_year(right), get_month(right), get_day(right));
            return new_delta(left_ord - right_ord, 0, 0, 0);
        }
        if delta_check(right) {
            # date - delta
            return add_date_timedelta(left, right, True);
        }
    }
    return not_implemented();
}

# ---------------------------------------------------------------------------
# Various ways to turn a date into a string.

def date_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "%s(%ld, %ld, %ld)", type_name_of(op), get_year(op), get_month(op), get_day(op)
    );
}

def date_isoformat(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "%04ld-%02ld-%02ld", get_year(op), get_month(op), get_day(op)
    );
}

"""str() calls the appropriate isoformat() method."""
def date_str(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_CallMethod(self, "isoformat", "");
}

def date_ctime(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return format_ctime(self, 0, 0, 0);
}

def date_strftime(
    self: ptr[PyObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    # This method can be inherited, and needs to call the timetuple() method
    # appropriate to self's class.
    try {
        values = ArgumentFormat(name="strftime").parse_keywords(
            args, kw, "U", ["format"]
        );
    } except boundary_failure {
        return NULL;
    }
    tuple = PyObject_CallMethod(self, "timetuple", "");
    if not tuple {
        return NULL;
    }
    result = wrap_strftime(self, values[0].object, tuple, self);
    jacpy_release(tuple);
    return result;
}

def date_format(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        format = ArgumentFormat(name="__format__").parse(args, "U")[0].object;
    } except boundary_failure {
        return NULL;
    }
    # if the format is zero length, return str(self)
    if PyUnicode_GetLength(format) == 0 {
        return PyObject_Str(self);
    }
    return PyObject_CallMethod(self, "strftime", "O", format);
}

# ---------------------------------------------------------------------------
# ISO methods.

def date_isoweekday(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    dow = weekday(get_year(self), get_month(self), get_day(self));
    return PyLong_FromLong(dow + 1);
}

# IsoCalendarDate: the result of date.isocalendar() or datetime.isocalendar(),
# a tuple of (year, week, weekday) with those attribute names.

def iso_calendar_date_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    year = PyTuple_GetItem(self, 0);
    if not year {
        return NULL;
    }
    week = PyTuple_GetItem(self, 1);
    if not week {
        return NULL;
    }
    weekday_value = PyTuple_GetItem(self, 2);
    if not weekday_value {
        return NULL;
    }
    return PyUnicode_FromFormat(
        "%.200s(year=%S, week=%S, weekday=%S)",
        type_name_of(self),
        year,
        week,
        weekday_value
    );
}

def iso_calendar_date_reduce(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    # Construct the tuple that this reduces to
    return Py_BuildValue(
        "O((OOO))",
        ptr[PyObject](addressof(PyTuple_Type)),
        PyTuple_GetItem(self, 0),
        PyTuple_GetItem(self, 1),
        PyTuple_GetItem(self, 2)
    );
}

def iso_calendar_date_item(self: ptr[PyObject], index: int) -> ptr[PyObject] {
    item = PyTuple_GetItem(self, i64(index));
    if not item {
        return NULL;
    }
    return Py_NewRef(item);
}

def iso_calendar_date_year(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return iso_calendar_date_item(self, 0);
}

def iso_calendar_date_week(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return iso_calendar_date_item(self, 1);
}

def iso_calendar_date_weekday(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return iso_calendar_date_item(self, 2);
}

"""Py_VISIT(Py_TYPE(self)), then the tuple's own traversal."""
def iso_calendar_date_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(type_of(self), visitor, arg);
    if status != 0 {
        return status;
    }
    tuple_traverse = TraverseCall();
    tuple_traverse.call = int(
        PyType_GetSlot(ptr[PyObject](addressof(PyTuple_Type)), Py_tp_traverse)
    );
    return tuple_traverse.call(self, visitor, arg);
}

def iso_calendar_date_dealloc(self: ptr[PyObject]) {
    tp = type_of(self);
    # delegate GC-untrack as well
    addressof(PyTuple_Type).view(1)[0].tp_dealloc(self);
    jacpy_release(tp);
}

"""IsoCalendarDate(year, week, weekday) of the heap type `type`."""
def new_iso_calendar_date(
    type: ptr[PyTypeObject], year: int, week: int, weekday_number: int
) -> ptr[PyObject] {
    self = type_alloc(type, 3);
    if not self {
        return NULL;
    }
    PyTuple_SetItem(self, 0, PyLong_FromLong(year));
    PyTuple_SetItem(self, 1, PyLong_FromLong(week));
    PyTuple_SetItem(self, 2, PyLong_FromLong(weekday_number));
    return self;
}

def date_isocalendar(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    year = get_year(self);
    week1_monday = iso_week1_monday(year);
    today = ymd_to_ord(year, get_month(self), get_day(self));
    week = (today - week1_monday) // 7;
    day = (today - week1_monday) % 7;
    if week < 0 {
        year -= 1;
        week1_monday = iso_week1_monday(year);
        week = (today - week1_monday) // 7;
        day = (today - week1_monday) % 7;
    } elif week >= 52 and today >= iso_week1_monday(year + 1) {
        year += 1;
        week = 0;
    }
    module = get_current_state();
    if not module {
        return NULL;
    }
    v = new_iso_calendar_date(
        ptr[PyTypeObject](state_value(module, STATE_ISOCALENDAR_DATE_TYPE)),
        year,
        week + 1,
        day + 1
    );
    jacpy_release(module);
    return v;
}

# ---------------------------------------------------------------------------
# Miscellaneous methods.

"""memcmp of the first `size` data bytes of two date-like objects."""
def compare_data(left: ptr[PyObject], right: ptr[PyObject], size: int) -> int {
    a = data_address(left);
    b = data_address(right);
    for i in range(size) {
        diff = int((a + i).view(1)[0]) - int((b + i).view(1)[0]);
        if diff != 0 {
            return diff;
        }
    }
    return 0;
}

def date_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    # Since DateTime is a subclass of Date, comparing a date with a datetime
    # would compare the date part alone, which we don't want; the behavior is
    # as if Date and DateTime were independent classes.
    if date_check(other) and not datetime_check(other) {
        return diff_to_bool(compare_data(self, other, DATE_DATASIZE), int(op));
    }
    return not_implemented();
}

def date_timetuple(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return build_struct_time(
        get_year(self), get_month(self), get_day(self), 0, 0, 0, -1
    );
}

"""Py_HashBuffer over the first `size` data bytes."""
def generic_hash(op: ptr[PyObject], size: int) -> i64 {
    return Py_HashBuffer(ptr(data_address(op)), i64(size));
}

def date_hash(op: ptr[PyObject]) -> i64 {
    record = ptr[PyDateTime_Date](op).view(1);
    hash = record[0].hashcode;
    if hash == -1 {
        hash = generic_hash(op, DATE_DATASIZE);
        record[0].hashcode = hash;
    }
    return hash;
}

def date_toordinal(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(ymd_to_ord(get_year(self), get_month(self), get_day(self)));
}

def date_weekday(self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(weekday(get_year(self), get_month(self), get_day(self)));
}

"""Pickle support, a simple use of __reduce__; __getstate__ isn't exposed."""
def date_getstate(self: ptr[PyObject]) -> ptr[PyObject] {
    field = data_bytes(self, DATE_DATASIZE);
    return Py_BuildValue("(N)", field);
}

def date_reduce(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(ON)", type_of(op), date_getstate(op));
}
