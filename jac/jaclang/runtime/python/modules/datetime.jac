"""The Argument Clinic functions and C API entry points of _datetime.

Modules/_datetimemodule.c's `_impl` functions, which the generated glue in
bindings/clinic/datetime.jac calls with their C parameter lists, and the
constructors the datetime C API capsule exports with the exact signatures
of Include/datetime.h's PyDateTime_CAPI. The types themselves are in the
datetime_*.jac modules. See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.cpython_api { NULL, PyArg_UnpackTuple, PyObject }
import from jaclang.runtime.python.layouts { PyTypeObject }
import from jaclang.runtime.python.modules.datetime_objects {
    STATE_ISOCALENDAR_DATE_TYPE,
    new_date_ex,
    new_date_subclass_ex,
    new_datetime_ex,
    new_datetime_ex2,
    new_datetime_subclass_fold_ex,
    new_delta_ex,
    new_time_ex,
    new_time_ex2,
    new_time_subclass_fold_ex,
    type_of
}
import from jaclang.runtime.python.modules.datetime_date {
    date_fromtimestamp,
    new_iso_calendar_date
}
import from jaclang.runtime.python.modules.datetime_datetime { datetime_now }

"""date.fromtimestamp(timestamp): a date from a POSIX timestamp, interpreted
as local time."""
def datetime_date_fromtimestamp_impl(
    type: ptr[PyObject], timestamp: ptr[PyObject]
) -> ptr[PyObject] {
    return date_fromtimestamp(type, timestamp);
}

"""IsoCalendarDate(year, week, weekday)."""
def iso_calendar_date_new_impl(
    type: ptr[PyObject], year: i32, week: i32, weekday: i32
) -> ptr[PyObject] {
    return new_iso_calendar_date(
        ptr[PyTypeObject](type), int(year), int(week), int(weekday)
    );
}

"""date.replace(): the date with new specified fields."""
def datetime_date_replace_impl(
    self: ptr[PyObject], year: i32, month: i32, day: i32
) -> ptr[PyObject] {
    return new_date_subclass_ex(int(year), int(month), int(day), type_of(self));
}

"""time.replace(): the time with new specified fields."""
def datetime_time_replace_impl(
    self: ptr[PyObject],
    hour: i32,
    minute: i32,
    second: i32,
    microsecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32
) -> ptr[PyObject] {
    return new_time_subclass_fold_ex(
        int(hour),
        int(minute),
        int(second),
        int(microsecond),
        tzinfo,
        int(fold),
        type_of(self)
    );
}

"""datetime.now(tz=None): the current time local to tz, or local time."""
def datetime_datetime_now_impl(
    type: ptr[PyObject], tz: ptr[PyObject]
) -> ptr[PyObject] {
    return datetime_now(type, tz);
}

"""datetime.replace(): the datetime with new specified fields."""
def datetime_datetime_replace_impl(
    self: ptr[PyObject],
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    minute: i32,
    second: i32,
    microsecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32
) -> ptr[PyObject] {
    return new_datetime_subclass_fold_ex(
        int(year),
        int(month),
        int(day),
        int(hour),
        int(minute),
        int(second),
        int(microsecond),
        tzinfo,
        int(fold),
        type_of(self)
    );
}

# ---------------------------------------------------------------------------
# PyDateTime_CAPI entry points, with Include/datetime.h's C signatures.

def capi_date_from_date(
    year: i32, month: i32, day: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_date_ex(int(year), int(month), int(day), type);
}

def capi_datetime_from_date_and_time(
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_datetime_ex(
        int(year),
        int(month),
        int(day),
        int(hour),
        int(minute),
        int(second),
        int(usecond),
        tzinfo,
        type
    );
}

def capi_time_from_time(
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_time_ex(int(hour), int(minute), int(second), int(usecond), tzinfo, type);
}

def capi_delta_from_delta(
    days: i32, seconds: i32, microseconds: i32, normalize: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_delta_ex(
        int(days), int(seconds), int(microseconds), int(normalize), type
    );
}

"""bpo-36025: date.fromtimestamp taking an *args tuple, as the C API
expects, where the clinic function takes METH_O."""
def datetime_date_fromtimestamp_capi(
    cls: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    timestamp: ptr[PyObject] = NULL;
    if PyArg_UnpackTuple(args, "fromtimestamp", 1, 1, &mut timestamp) == 0 {
        return NULL;
    }
    return date_fromtimestamp(cls, timestamp);
}

def capi_datetime_from_date_and_time_and_fold(
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32,
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_datetime_ex2(
        int(year),
        int(month),
        int(day),
        int(hour),
        int(minute),
        int(second),
        int(usecond),
        tzinfo,
        int(fold),
        type
    );
}

def capi_time_from_time_and_fold(
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32,
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_time_ex2(
        int(hour), int(minute), int(second), int(usecond), tzinfo, int(fold), type
    );
}
