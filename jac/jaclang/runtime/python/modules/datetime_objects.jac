"""Objects and helpers the _datetime types share.

Modules/_datetimemodule.c's field accessors, type checks, module state,
object constructors, tzinfo helpers and the timedelta arithmetic the other
types build on, in native Jac. The objects keep the layouts of
Include/datetime.h (layouts.jac), since C extensions read them through the
datetime C API's macros; the static types and singletons are C data the
type modules define under their C names and are declared here. See
../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    Py_XNewRef,
    PyDict_GetItemRef,
    PyDict_New,
    PyDict_SetItem,
    PyDict_SetItemString,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_GetRaisedException,
    PyErr_Occurred,
    PyErr_SetRaisedException,
    PyErr_SetString,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModule,
    PyInterpreterState,
    PyInterpreterState_Get,
    PyInterpreterState_GetDict,
    PyLong_AsInt,
    PyLong_FromLong,
    PyNumber_Add,
    PyNumber_Divmod,
    PyNumber_FloorDivide,
    PyNumber_Multiply,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyTuple_GetItem,
    PyTuple_Size,
    PyUnicode_FromFormat,
    PyUnicode_GetLength,
    PyUnicode_InternFromString,
    PyUnicode_Substring,
    PyWeakref_GetRef,
    PyWeakref_NewRef,
    jacpy_bytes_from_memory,
    jacpy_is_tuple,
    jacpy_is_unicode
}
import from jaclang.runtime.python.layouts {
    PyDateTime_Date,
    PyDateTime_DateTime,
    PyDateTime_Delta,
    PyDateTime_Time,
    PY_DATETIME_DATA_OFFSET,
    PyTypeObject,
    _PyDateTime_BaseTZInfo,
    _object
}
import from jaclang.runtime.python.object_model.header {
    object_type,
    object_type_check
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.modules.datetime_calendar {
    DateTimeFields,
    MAX_DELTA_DAYS,
    MAXYEAR,
    MINYEAR,
    days_in_month,
    normalize_d_s_us,
    normalize_datetime,
    normalize_y_m_d
}

import from c {
    # The timezone layout, which Modules/_datetimemodule.c defines itself.
    obj PyDateTime_TimeZone {
        has ob_base: _object,
            offset: ptr[PyObject],
            name: ptr[PyObject];
    }
    # The static types and singletons the type modules define.
    glob PyDateTime_DateType: PyTypeObject,
         PyDateTime_DateTimeType: PyTypeObject,
         PyDateTime_TimeType: PyTypeObject,
         PyDateTime_DeltaType: PyTypeObject,
         PyDateTime_TZInfoType: PyTypeObject,
         PyDateTime_TimeZoneType: PyTypeObject,
         zero_delta: PyDateTime_Delta,
         utc_timezone: PyDateTime_TimeZone;
}

# Rich comparison operators.
glob Py_LT: Final[int] = 0,
     Py_LE: Final[int] = 1,
     Py_EQ: Final[int] = 2,
     Py_NE: Final[int] = 3,
     Py_GT: Final[int] = 4,
     Py_GE: Final[int] = 5;

# The module state: the IsoCalendarDate heap type, the conversion factors as
# Python ints, and the interned Unix epoch datetime.
glob STATE_ISOCALENDAR_DATE_TYPE: Final[int] = 0,
     STATE_US_PER_MS: Final[int] = 1,
     STATE_US_PER_SECOND: Final[int] = 2,
     STATE_US_PER_MINUTE: Final[int] = 3,
     STATE_US_PER_HOUR: Final[int] = 4,
     STATE_US_PER_DAY: Final[int] = 5,
     STATE_US_PER_WEEK: Final[int] = 6,
     STATE_SECONDS_PER_DAY: Final[int] = 7,
     STATE_EPOCH: Final[int] = 8,
     STATE_COUNT: Final[int] = 9;

# ---------------------------------------------------------------------------
# Static objects, casts and type checks.

def date_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DateType);
}

def datetime_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DateTimeType);
}

def time_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TimeType);
}

def delta_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DeltaType);
}

def tzinfo_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TZInfoType);
}

def timezone_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TimeZoneType);
}

"""CONST_UTC: the datetime.timezone.utc singleton (borrowed)."""
def utc -> ptr[PyObject] {
    return ptr[PyObject](addressof(utc_timezone));
}

"""A type as the object it is."""
def type_object(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    return ptr[PyObject](type);
}

"""Py_TYPE(op) as an object (borrowed)."""
def type_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](object_type(op));
}

"""Py_TYPE(op)->tp_name."""
def type_name_of(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

def date_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, date_type());
}

def datetime_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, datetime_type());
}

def time_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, time_type());
}

def delta_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, delta_type());
}

def tzinfo_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, tzinfo_type());
}

def timezone_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, timezone_type());
}

"""A new reference to NotImplemented."""
def not_implemented -> ptr[PyObject] {
    return Py_NewRef(Py_NotImplemented);
}

"""The allocator of `type` (tp_alloc), called with C's nitems argument."""
def type_alloc(type: ptr[PyTypeObject], nitems: int) -> ptr[PyObject] {
    return type.view(1)[0].tp_alloc(type, nitems);
}

"""Py_TYPE(op)->tp_free(op)."""
def type_free(op: ptr[PyObject]) {
    object_type(op).view(1)[0].tp_free(ptr(op));
}

# ---------------------------------------------------------------------------
# Field accessors (Include/datetime.h's macros).

def get_year(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_Date](op).view(1);
    return (int(record[0].data) << 8) | int(record[0].data_1);
}

def get_month(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Date](op).view(1)[0].data_2);
}

def get_day(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Date](op).view(1)[0].data_3);
}

def date_get_hour(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_4);
}

def date_get_minute(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_5);
}

def date_get_second(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_6);
}

def date_get_microsecond(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_DateTime](op).view(1);
    return (int(record[0].data_7) << 16)
        | (int(record[0].data_8) << 8)
        | int(record[0].data_9);
}

def date_get_fold(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].fold);
}

def time_get_hour(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data);
}

def time_get_minute(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data_1);
}

def time_get_second(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data_2);
}

def time_get_microsecond(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_Time](op).view(1);
    return (int(record[0].data_3) << 16)
        | (int(record[0].data_4) << 8)
        | int(record[0].data_5);
}

def time_get_fold(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].fold);
}

"""_PyDateTime_HAS_TZINFO: whether a time or datetime has a tzinfo member."""
def has_tzinfo(op: ptr[PyObject]) -> bool {
    return ptr[_PyDateTime_BaseTZInfo](op).view(1)[0].hastzinfo != 0;
}

"""PyDateTime_DATE_GET_TZINFO (borrowed)."""
def datetime_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject] {
    if has_tzinfo(op) {
        return ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo;
    }
    return Py_None;
}

"""PyDateTime_TIME_GET_TZINFO (borrowed)."""
def time_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject] {
    if has_tzinfo(op) {
        return ptr[PyDateTime_Time](op).view(1)[0].tzinfo;
    }
    return Py_None;
}

def td_days(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].days);
}

def td_seconds(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].seconds);
}

def td_microseconds(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].microseconds);
}

"""set_date_fields: for date and datetime."""
def set_date_fields(op: ptr[PyObject], year: int, month: int, day: int) {
    record = ptr[PyDateTime_Date](op).view(1);
    record[0].hashcode = -1;
    record[0].data = u8((year & 0xff00) >> 8);
    record[0].data_1 = u8(year & 0x00ff);
    record[0].data_2 = u8(month);
    record[0].data_3 = u8(day);
}

def set_datetime_time_fields(
    op: ptr[PyObject], hour: int, minute: int, second: int, microsecond: int
) {
    record = ptr[PyDateTime_DateTime](op).view(1);
    record[0].data_4 = u8(hour);
    record[0].data_5 = u8(minute);
    record[0].data_6 = u8(second);
    record[0].data_7 = u8((microsecond & 0xff0000) >> 16);
    record[0].data_8 = u8((microsecond & 0x00ff00) >> 8);
    record[0].data_9 = u8(microsecond & 0x0000ff);
}

def set_time_fields(
    op: ptr[PyObject], hour: int, minute: int, second: int, microsecond: int
) {
    record = ptr[PyDateTime_Time](op).view(1);
    record[0].data = u8(hour);
    record[0].data_1 = u8(minute);
    record[0].data_2 = u8(second);
    record[0].data_3 = u8((microsecond & 0xff0000) >> 16);
    record[0].data_4 = u8((microsecond & 0x00ff00) >> 8);
    record[0].data_5 = u8(microsecond & 0x0000ff);
}

# ---------------------------------------------------------------------------
# Module state. The static types can outlive the module, so the current
# module is found through a weak reference in the interpreter's dict.

"""INTERP_KEY: the interned identifier `cached_datetime_module` (new ref)."""
def interp_key -> ptr[PyObject] {
    return PyUnicode_InternFromString("cached_datetime_module");
}

"""get_current_module: (1, new reference) when a live module is recorded,
(0, NULL) when none is, and (-1, NULL) with an error set."""
def get_current_module(interp: ptr[PyInterpreterState]) -> tuple[int, ptr[PyObject]] {
    dict = PyInterpreterState_GetDict(interp);
    if not dict {
        return (-1, NULL);
    }
    key = interp_key();
    if not key {
        return (-1, NULL);
    }
    ref: ptr[PyObject] = NULL;
    status = PyDict_GetItemRef(dict, key, &mut ref);
    jacpy_release(key);
    if status < 0 {
        return (-1, NULL);
    }
    module: ptr[PyObject] = NULL;
    if ref and ref != Py_None {
        if PyWeakref_GetRef(ref, &mut module) < 0 {
            jacpy_release(ref);
            return (-1, NULL);
        }
        if module == Py_None {
            jacpy_release(module);
            module = NULL;
        }
    }
    jacpy_release(ref);
    return (1 if module else 0, module);
}

"""GET_CURRENT_STATE: a new reference to the current _datetime module, whose
state the caller reads with state_value() before releasing it; NULL with an
error set on failure."""
def get_current_state -> ptr[PyObject] {
    interp = PyInterpreterState_Get();
    (status, module) = get_current_module(interp);
    if status < 0 {
        return NULL;
    }
    if not module {
        # The static types can outlive the module, so we must re-import the
        # module.
        module = PyImport_ImportModule("_datetime");
    }
    return module;
}

"""A module state entry (borrowed)."""
def state_value(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

"""One module state entry of the current module (new reference), or NULL
with an error set."""
def current_state_value(index: int) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    value = Py_NewRef(state_value(module, index));
    jacpy_release(module);
    return value;
}

def set_current_module(interp: ptr[PyInterpreterState], module: ptr[PyObject]) -> i32 {
    dict = PyInterpreterState_GetDict(interp);
    if not dict {
        return i32(-1);
    }
    ref = PyWeakref_NewRef(module, NULL);
    if not ref {
        return i32(-1);
    }
    key = interp_key();
    if not key {
        jacpy_release(ref);
        return i32(-1);
    }
    status = PyDict_SetItem(dict, key, ref);
    jacpy_release(key);
    jacpy_release(ref);
    return status;
}

"""clear_current_module: mark the module as previously loaded (None) unless
another module has replaced `expected` since. Keeps any pending exception."""
def clear_current_module(interp: ptr[PyInterpreterState], expected: ptr[PyObject]) {
    exc = PyErr_GetRaisedException();
    failed = False;
    replaced = False;
    dict = PyInterpreterState_GetDict(interp);
    key = interp_key() if dict else NULL;
    if not key {
        failed = True;
    }
    if not failed and expected {
        ref: ptr[PyObject] = NULL;
        if PyDict_GetItemRef(dict, key, &mut ref) < 0 {
            failed = True;
        } elif ref {
            current: ptr[PyObject] = NULL;
            rc = PyWeakref_GetRef(ref, &mut current);
            # We only need "current" for pointer comparison.
            jacpy_release(current);
            jacpy_release(ref);
            if rc < 0 {
                failed = True;
            } elif current != expected {
                replaced = True;
            }
        }
    }
    # We use None to identify that the module was previously loaded.
    if not failed and not replaced and PyDict_SetItem(dict, key, Py_None) < 0 {
        failed = True;
    }
    jacpy_release(key);
    if failed {
        PyErr_FormatUnraisable("Exception ignored while clearing _datetime module");
    }
    PyErr_SetRaisedException(exc);
}

# ---------------------------------------------------------------------------
# Range checkers.

"""Check that -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS: 0, or -1 with
OverflowError."""
def check_delta_day_range(days: int) -> int {
    if -MAX_DELTA_DAYS <= days and days <= MAX_DELTA_DAYS {
        return 0;
    }
    PyErr_Format(
        PyExc_OverflowError,
        "days=%ld; must have magnitude <= %ld",
        days,
        MAX_DELTA_DAYS
    );
    return -1;
}

"""Check that date arguments are in range: 0, or -1 with ValueError."""
def check_date_args(year: int, month: int, day: int) -> int {
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
    if month < 1 or month > 12 {
        PyErr_Format(PyExc_ValueError, "month must be in 1..12, not %ld", month);
        return -1;
    }
    dim = days_in_month(year, month);
    if day < 1 or day > dim {
        PyErr_Format(
            PyExc_ValueError,
            "day %ld must be in range 1..%ld for month %ld in year %ld",
            day,
            dim,
            month,
            year
        );
        return -1;
    }
    return 0;
}

"""Check that time arguments are in range: 0, or -1 with ValueError."""
def check_time_args(h: int, m: int, s: int, us: int, fold: int) -> int {
    if h < 0 or h > 23 {
        PyErr_Format(PyExc_ValueError, "hour must be in 0..23, not %ld", h);
        return -1;
    }
    if m < 0 or m > 59 {
        PyErr_Format(PyExc_ValueError, "minute must be in 0..59, not %ld", m);
        return -1;
    }
    if s < 0 or s > 59 {
        PyErr_Format(PyExc_ValueError, "second must be in 0..59, not %ld", s);
        return -1;
    }
    if us < 0 or us > 999999 {
        PyErr_Format(PyExc_ValueError, "microsecond must be in 0..999999, not %ld", us);
        return -1;
    }
    if fold != 0 and fold != 1 {
        PyErr_Format(PyExc_ValueError, "fold must be either 0 or 1, not %ld", fold);
        return -1;
    }
    return 0;
}

"""normalize_date for `fields`: 0, or -1 with OverflowError when the
adjusted year is out of bounds."""
def normalize_date(fields: DateTimeFields) -> int {
    if normalize_y_m_d(fields) {
        return 0;
    }
    PyErr_SetString(PyExc_OverflowError, "date value out of range");
    return -1;
}

"""Ensure that p is None or of a tzinfo subclass: 0, or -1 with TypeError."""
def check_tzinfo_subclass(p: ptr[PyObject]) -> int {
    if p == Py_None or tzinfo_check(p) {
        return 0;
    }
    PyErr_Format(
        PyExc_TypeError,
        "tzinfo argument must be None or of a tzinfo subclass, not type '%s'",
        type_name_of(p)
    );
    return -1;
}

"""Py_RETURN_RICHCOMPARE(diff, 0, op)."""
def diff_to_bool(diff: int, op: int) -> ptr[PyObject] {
    result = False;
    if op == Py_LT {
        result = diff < 0;
    } elif op == Py_LE {
        result = diff <= 0;
    } elif op == Py_EQ {
        result = diff == 0;
    } elif op == Py_NE {
        result = diff != 0;
    } elif op == Py_GT {
        result = diff > 0;
    } else {
        result = diff >= 0;
    }
    return PyBool_FromLong(1 if result else 0);
}

# ---------------------------------------------------------------------------
# Create various objects, mostly without range checking.

"""Create a date instance with no range checking."""
def new_date_ex(
    year: int, month: int, day: int, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    if check_date_args(year, month, day) < 0 {
        return NULL;
    }
    self = type_alloc(type, 0);
    if self {
        set_date_fields(self, year, month, day);
    }
    return self;
}

def new_date(year: int, month: int, day: int) -> ptr[PyObject] {
    return new_date_ex(year, month, day, date_type());
}

"""Create date instance with no range checking, or call subclass
constructor."""
def new_date_subclass_ex(
    year: int, month: int, day: int, cls: ptr[PyObject]
) -> ptr[PyObject] {
    # We have "fast path" constructors for two subclasses: date and datetime
    if cls == type_object(date_type()) {
        return new_date_ex(year, month, day, date_type());
    }
    if cls == type_object(datetime_type()) {
        return new_datetime_ex(year, month, day, 0, 0, 0, 0, Py_None, datetime_type());
    }
    return PyObject_CallFunction(cls, "lll", year, month, day);
}

"""Create a datetime instance with no range checking."""
def new_datetime_ex2(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    aware = tzinfo != Py_None;
    if check_date_args(year, month, day) < 0 {
        return NULL;
    }
    if check_time_args(hour, minute, second, usecond, fold) < 0 {
        return NULL;
    }
    if check_tzinfo_subclass(tzinfo) < 0 {
        return NULL;
    }
    self = type_alloc(type, 1 if aware else 0);
    if self {
        record = ptr[PyDateTime_DateTime](self).view(1);
        record[0].hastzinfo = i8(1 if aware else 0);
        set_date_fields(self, year, month, day);
        set_datetime_time_fields(self, hour, minute, second, usecond);
        if aware {
            record[0].tzinfo = Py_NewRef(tzinfo);
        }
        record[0].fold = u8(fold);
    }
    return self;
}

def new_datetime_ex(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_datetime_ex2(
        year, month, day, hour, minute, second, usecond, tzinfo, 0, type
    );
}

def new_datetime(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int
) -> ptr[PyObject] {
    return new_datetime_ex2(
        year, month, day, hour, minute, second, usecond, tzinfo, fold, datetime_type()
    );
}

"""cls(*args), with fold=1 as a keyword argument when `fold` is set. `args`
is a new reference the call consumes."""
def call_subclass_fold(
    cls: ptr[PyObject], fold: int, args: ptr[PyObject]
) -> ptr[PyObject] {
    if not args {
        return NULL;
    }
    kwargs: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    ready = True;
    if fold != 0 {
        ready = False;
        kwargs = PyDict_New();
        if kwargs {
            value = PyLong_FromLong(fold);
            if value {
                ready = PyDict_SetItemString(kwargs, "fold", value) >= 0;
                jacpy_release(value);
            }
        }
    }
    if ready {
        result = PyObject_Call(cls, args, kwargs);
    }
    jacpy_release(args);
    jacpy_release(kwargs);
    return result;
}

def new_datetime_subclass_fold_ex(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    cls: ptr[PyObject]
) -> ptr[PyObject] {
    if cls == type_object(datetime_type()) {
        # Use the fast path constructor
        return new_datetime(
            year, month, day, hour, minute, second, usecond, tzinfo, fold
        );
    }
    # Subclass
    return call_subclass_fold(
        cls,
        fold,
        Py_BuildValue(
            "lllllllO", year, month, day, hour, minute, second, usecond, tzinfo
        )
    );
}

def new_datetime_subclass_ex(
    year: int,
    month: int,
    day: int,
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    cls: ptr[PyObject]
) -> ptr[PyObject] {
    return new_datetime_subclass_fold_ex(
        year, month, day, hour, minute, second, usecond, tzinfo, 0, cls
    );
}

"""Create a time instance with no range checking."""
def new_time_ex2(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    aware = tzinfo != Py_None;
    if check_time_args(hour, minute, second, usecond, fold) < 0 {
        return NULL;
    }
    if check_tzinfo_subclass(tzinfo) < 0 {
        return NULL;
    }
    self = type_alloc(type, 1 if aware else 0);
    if self {
        record = ptr[PyDateTime_Time](self).view(1);
        record[0].hastzinfo = i8(1 if aware else 0);
        record[0].hashcode = -1;
        set_time_fields(self, hour, minute, second, usecond);
        if aware {
            record[0].tzinfo = Py_NewRef(tzinfo);
        }
        record[0].fold = u8(fold);
    }
    return self;
}

def new_time_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_time_ex2(hour, minute, second, usecond, tzinfo, 0, type);
}

def new_time(
    hour: int, minute: int, second: int, usecond: int, tzinfo: ptr[PyObject], fold: int
) -> ptr[PyObject] {
    return new_time_ex2(hour, minute, second, usecond, tzinfo, fold, time_type());
}

def new_time_subclass_fold_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    cls: ptr[PyObject]
) -> ptr[PyObject] {
    if cls == type_object(time_type()) {
        # Use the fast path constructor
        return new_time(hour, minute, second, usecond, tzinfo, fold);
    }
    # Subclass
    return call_subclass_fold(
        cls, fold, Py_BuildValue("llllO", hour, minute, second, usecond, tzinfo)
    );
}

"""The immortal zero timedelta when (days, seconds, microseconds) is zero and
`type` is timedelta itself, else NULL."""
def look_up_delta(
    days: int, seconds: int, microseconds: int, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    zero = ptr[PyObject](addressof(zero_delta));
    if days == 0 and seconds == 0 and microseconds == 0 and type == object_type(zero) {
        return zero;
    }
    return NULL;
}

"""Create a timedelta instance. Normalize the members iff normalize is true;
false is a speed optimization when seconds and microseconds are known to be
in their proper ranges. OverflowError when the normalized days are out of
range."""
def new_delta_ex(
    days: int, seconds: int, microseconds: int, normalize: int, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    if normalize != 0 {
        fixed = normalize_d_s_us(days, seconds, microseconds);
        days = fixed.days;
        seconds = fixed.seconds;
        microseconds = fixed.microseconds;
    }
    if check_delta_day_range(days) < 0 {
        return NULL;
    }
    found = look_up_delta(days, seconds, microseconds, type);
    if found {
        return found;
    }
    self = type_alloc(type, 0);
    if self {
        record = ptr[PyDateTime_Delta](self).view(1);
        record[0].hashcode = -1;
        record[0].days = i32(days);
        record[0].seconds = i32(seconds);
        record[0].microseconds = i32(microseconds);
    }
    return self;
}

def new_delta(
    days: int, seconds: int, microseconds: int, normalize: int
) -> ptr[PyObject] {
    return new_delta_ex(days, seconds, microseconds, normalize, delta_type());
}

"""The UTC singleton for (offset=zero_delta, no name), else NULL."""
def look_up_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if offset == addressof(utc_timezone).view(1)[0].offset and not name {
        return utc();
    }
    return NULL;
}

"""Create new timezone instance checking offset range. The caller assures
that offset is a timedelta and name is NULL or a str."""
def create_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    found = look_up_timezone(offset, name);
    if found {
        return found;
    }
    self = type_alloc(timezone_type(), 0);
    if not self {
        return NULL;
    }
    record = ptr[PyDateTime_TimeZone](self).view(1);
    record[0].offset = Py_NewRef(offset);
    record[0].name = Py_XNewRef(name);
    return self;
}

"""Whether a UTC offset lies outside (-timedelta(hours=24), timedelta(hours=24))."""
def offset_out_of_range(offset: ptr[PyObject]) -> bool {
    days = td_days(offset);
    return (days == -1 and td_seconds(offset) == 0 and td_microseconds(offset) < 1)
        or days < -1
        or days >= 1;
}

def new_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if not name and delta_bool(offset) == 0 {
        return Py_NewRef(utc());
    }
    if offset_out_of_range(offset) {
        PyErr_Format(
            PyExc_ValueError,
            "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not %R",
            offset
        );
        return NULL;
    }
    return create_timezone(offset, name);
}

# ---------------------------------------------------------------------------
# tzinfo helpers.

"""If self has a tzinfo member, a BORROWED reference to it, else NULL (not
an error)."""
def get_tzinfo_member(self: ptr[PyObject]) -> ptr[PyObject] {
    if datetime_check(self) and has_tzinfo(self) {
        return ptr[PyDateTime_DateTime](self).view(1)[0].tzinfo;
    }
    if time_check(self) and has_tzinfo(self) {
        return ptr[PyDateTime_Time](self).view(1)[0].tzinfo;
    }
    return NULL;
}

"""getattr(tzinfo, name)(tzinfoarg), checked: None, a timedelta strictly
within a day, or NULL with TypeError or ValueError."""
def call_tzinfo_method(
    tzinfo: ptr[PyObject], name: str, tzinfoarg: ptr[PyObject]
) -> ptr[PyObject] {
    if tzinfo == Py_None {
        return Py_NewRef(Py_None);
    }
    offset = PyObject_CallMethod(tzinfo, name, "O", tzinfoarg);
    if offset == Py_None or not offset {
        return offset;
    }
    if delta_check(offset) {
        if offset_out_of_range(offset) {
            PyErr_Format(
                PyExc_ValueError,
                "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not %R",
                offset
            );
            jacpy_release(offset);
            return NULL;
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            "tzinfo.%s() must return None or timedelta, not '%.200s'",
            name,
            type_name_of(offset)
        );
        jacpy_release(offset);
        return NULL;
    }
    return offset;
}

"""tzinfo.utcoffset(tzinfoarg), checked."""
def call_utcoffset(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzinfo_method(tzinfo, "utcoffset", tzinfoarg);
}

"""tzinfo.dst(tzinfoarg), checked."""
def call_dst(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzinfo_method(tzinfo, "dst", tzinfoarg);
}

"""tzinfo.tzname(tzinfoarg): None or a str, else NULL with TypeError."""
def call_tzname(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
    if tzinfo == Py_None {
        return Py_NewRef(Py_None);
    }
    result = PyObject_CallMethod(tzinfo, "tzname", "O", tzinfoarg);
    if not result or result == Py_None {
        return result;
    }
    if jacpy_is_unicode(result) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "tzinfo.tzname() must return None or a string, not '%s'",
            type_name_of(result)
        );
        jacpy_release(result);
        return NULL;
    }
    return result;
}

"""datetime.utcoffset(): self.tzinfo.utcoffset(self)."""
def datetime_utcoffset(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_utcoffset(datetime_tzinfo_of(op), op);
}

"""datetime.dst(): self.tzinfo.dst(self)."""
def datetime_dst(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_dst(datetime_tzinfo_of(op), op);
}

"""repr is like "someclass(arg1, arg2)"; when tzinfo isn't None, stuff
", tzinfo=" + repr(tzinfo) before the closing ")". Consumes `repr`."""
def append_keyword_tzinfo(repr: ptr[PyObject], tzinfo: ptr[PyObject]) -> ptr[PyObject] {
    if tzinfo == Py_None {
        return repr;
    }
    # Get rid of the trailing ')'.
    temp = PyUnicode_Substring(repr, 0, PyUnicode_GetLength(repr) - 1);
    jacpy_release(repr);
    if not temp {
        return NULL;
    }
    result = PyUnicode_FromFormat("%U, tzinfo=%R)", temp, tzinfo);
    jacpy_release(temp);
    return result;
}

"""As append_keyword_tzinfo, with ", fold=" + fold when fold isn't 0."""
def append_keyword_fold(repr: ptr[PyObject], fold: int) -> ptr[PyObject] {
    if fold == 0 {
        return repr;
    }
    temp = PyUnicode_Substring(repr, 0, PyUnicode_GetLength(repr) - 1);
    jacpy_release(repr);
    if not temp {
        return NULL;
    }
    result = PyUnicode_FromFormat("%U, fold=%ld)", temp, fold);
    jacpy_release(temp);
    return result;
}

"""The tzinfo of a parsed ISO time: UTC or a fixed timezone when rv is 1,
else None."""
def tzinfo_from_isoformat_results(
    rv: int, tzoffset: int, tz_useconds: int
) -> ptr[PyObject] {
    if rv != 1 {
        return Py_NewRef(Py_None);
    }
    # Create a timezone from offset in seconds (0 returns UTC)
    if tzoffset == 0 {
        return Py_NewRef(utc());
    }
    delta = new_delta(0, tzoffset, tz_useconds, 1);
    if not delta {
        return NULL;
    }
    tzinfo = new_timezone(delta, NULL);
    jacpy_release(delta);
    return tzinfo;
}

# ---------------------------------------------------------------------------
# timedelta arithmetic the other types share.

def delta_bool(self: ptr[PyObject]) -> i32 {
    return i32(
        1
            if td_days(self) != 0 or td_seconds(self) != 0 or td_microseconds(self) != 0
            else 0
    );
}

def delta_negative(self: ptr[PyObject]) -> ptr[PyObject] {
    return new_delta(-td_days(self), -td_seconds(self), -td_microseconds(self), 1);
}

def delta_subtract(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) and delta_check(right) {
        # delta - delta; the additions can't overflow because of the
        # invariant bounds.
        return new_delta(
            td_days(left) - td_days(right),
            td_seconds(left) - td_seconds(right),
            td_microseconds(left) - td_microseconds(right),
            1
        );
    }
    return not_implemented();
}

def delta_cmp(self: ptr[PyObject], other: ptr[PyObject]) -> int {
    diff = td_days(self) - td_days(other);
    if diff == 0 {
        diff = td_seconds(self) - td_seconds(other);
        if diff == 0 {
            diff = td_microseconds(self) - td_microseconds(other);
        }
    }
    return diff;
}

"""Convert a timedelta to a number of microseconds as a Python int:
(24*3600*self.days + self.seconds)*1000000 + self.microseconds."""
def delta_to_microseconds(self: ptr[PyObject]) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    x1 = PyLong_FromLong(td_days(self));
    x2: ptr[PyObject] = NULL;
    x3: ptr[PyObject] = NULL;
    if x1 {
        # days in seconds
        x2 = PyNumber_Multiply(x1, state_value(module, STATE_SECONDS_PER_DAY));
    }
    if x2 {
        jacpy_release(x1);
        x1 = PyLong_FromLong(td_seconds(self));
        if x1 {
            # days and seconds in seconds
            x3 = PyNumber_Add(x1, x2);
        }
    }
    if x3 {
        jacpy_release(x1);
        jacpy_release(x2);
        x2 = NULL;
        # days+seconds in us
        x1 = PyNumber_Multiply(x3, state_value(module, STATE_US_PER_SECOND));
        if x1 {
            jacpy_release(x3);
            x3 = NULL;
            x2 = PyLong_FromLong(td_microseconds(self));
            if x2 {
                result = PyNumber_Add(x1, x2);
            }
        }
    }
    jacpy_release(x1);
    jacpy_release(x2);
    jacpy_release(x3);
    jacpy_release(module);
    return result;
}

"""divmod(a, b) checked to be a 2-tuple."""
def checked_divmod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    result = PyNumber_Divmod(a, b);
    if result {
        if jacpy_is_tuple(result) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "divmod() returned non-tuple (type %.200s)",
                type_name_of(result)
            );
            jacpy_release(result);
            return NULL;
        }
        size = PyTuple_Size(result);
        if size != 2 {
            PyErr_Format(
                PyExc_TypeError, "divmod() returned a tuple of size %zd", size
            );
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

"""The item of a divmod() pair as a C int in [0, bound): the value, or -1
with an error set (TypeError when it is out of range)."""
def divmod_part(pair: ptr[PyObject], index: int, bound: int) -> int {
    value = int(PyLong_AsInt(PyTuple_GetItem(pair, i64(index))));
    if value == -1 and PyErr_Occurred() {
        return -1;
    }
    if not (0 <= value and value < bound) {
        PyErr_SetString(PyExc_TypeError, "divmod() returned a value out of range");
        return -1;
    }
    return value;
}

"""Convert a number of microseconds (as a Python int) to a timedelta."""
def microseconds_to_delta_ex(
    pyus: ptr[PyObject], type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    tuple = checked_divmod(pyus, state_value(module, STATE_US_PER_SECOND));
    if tuple {
        us = divmod_part(tuple, 1, 1000000);
        if us >= 0 {
            # leftover seconds
            num = Py_NewRef(PyTuple_GetItem(tuple, 0));
            jacpy_release(tuple);
            tuple = checked_divmod(num, state_value(module, STATE_SECONDS_PER_DAY));
            jacpy_release(num);
            if tuple {
                s = divmod_part(tuple, 1, 24 * 3600);
                if s >= 0 {
                    # leftover days
                    d = int(PyLong_AsInt(PyTuple_GetItem(tuple, 0)));
                    if not (d == -1 and PyErr_Occurred()) {
                        result = new_delta_ex(d, s, us, 0, type);
                    }
                }
            }
        }
    }
    jacpy_release(tuple);
    jacpy_release(module);
    return result;
}

def microseconds_to_delta(pymicros: ptr[PyObject]) -> ptr[PyObject] {
    return microseconds_to_delta_ex(pymicros, delta_type());
}

def divide_timedelta_timedelta(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject] {
    pyus_left = delta_to_microseconds(left);
    if not pyus_left {
        return NULL;
    }
    pyus_right = delta_to_microseconds(right);
    if not pyus_right {
        jacpy_release(pyus_left);
        return NULL;
    }
    result = PyNumber_FloorDivide(pyus_left, pyus_right);
    jacpy_release(pyus_left);
    jacpy_release(pyus_right);
    return result;
}

"""date/datetime + timedelta with `factor` 1 (add) or -1 (subtract); the
result inherits the tzinfo state of `date`."""
def add_datetime_timedelta(
    date: ptr[PyObject], delta: ptr[PyObject], factor: int
) -> ptr[PyObject] {
    fields = DateTimeFields(
        year=get_year(date),
        month=get_month(date),
        day=get_day(date) + td_days(delta) * factor,
        hour=date_get_hour(date),
        minute=date_get_minute(date),
        second=date_get_second(date) + td_seconds(delta) * factor,
        microsecond=date_get_microsecond(date) + td_microseconds(delta) * factor
    );
    if not normalize_datetime(fields) {
        PyErr_SetString(PyExc_OverflowError, "date value out of range");
        return NULL;
    }
    return new_datetime_subclass_ex(
        fields.year,
        fields.month,
        fields.day,
        fields.hour,
        fields.minute,
        fields.second,
        fields.microsecond,
        datetime_tzinfo_of(date),
        type_of(date)
    );
}

"""A bytes copy of `size` data bytes of a date, time or datetime."""
def data_bytes(op: ptr[PyObject], size: int) -> ptr[PyObject] {
    return jacpy_bytes_from_memory(ptr(data_address(op)), i64(size));
}

"""The address of a date, time or datetime's packed data bytes."""
def data_address(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PY_DATETIME_DATA_OFFSET;
}
