def datetime_date_fromtimestamp_impl(
    type: ptr[PyObject], timestamp: ptr[PyObject]
) -> ptr[PyObject];

def iso_calendar_date_new_impl(
    type: ptr[PyObject], year: i32, week: i32, weekday: i32
) -> ptr[PyObject];

def datetime_date_replace_impl(
    self: ptr[PyObject], year: i32, month: i32, day: i32
) -> ptr[PyObject];

def datetime_time_replace_impl(
    self: ptr[PyObject],
    hour: i32,
    minute: i32,
    second: i32,
    microsecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32
) -> ptr[PyObject];

def datetime_datetime_now_impl(
    type: ptr[PyObject], tz: ptr[PyObject]
) -> ptr[PyObject];

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
) -> ptr[PyObject];

def capi_date_from_date(
    year: i32, month: i32, day: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject];

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
) -> ptr[PyObject];

def capi_time_from_time(
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject];

def capi_delta_from_delta(
    days: i32, seconds: i32, microseconds: i32, normalize: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject];

def datetime_date_fromtimestamp_capi(
    cls: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

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
) -> ptr[PyObject];

def capi_time_from_time_and_fold(
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    fold: i32,
    type: ptr[PyTypeObject]
) -> ptr[PyObject];

impl datetime_date_fromtimestamp_impl(
    type: ptr[PyObject], timestamp: ptr[PyObject]
) -> ptr[PyObject] {
    return date_fromtimestamp(type, timestamp);
}

impl iso_calendar_date_new_impl(
    type: ptr[PyObject], year: i32, week: i32, weekday: i32
) -> ptr[PyObject] {
    return new_iso_calendar_date(
        ptr[PyTypeObject](type), int(year), int(week), int(weekday)
    );
}

impl datetime_date_replace_impl(
    self: ptr[PyObject], year: i32, month: i32, day: i32
) -> ptr[PyObject] {
    return new_date_subclass_ex(int(year), int(month), int(day), type_of(self));
}

impl datetime_time_replace_impl(
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

impl datetime_datetime_now_impl(
    type: ptr[PyObject], tz: ptr[PyObject]
) -> ptr[PyObject] {
    return datetime_now(type, tz);
}

impl datetime_datetime_replace_impl(
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

impl capi_date_from_date(
    year: i32, month: i32, day: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_date_ex(int(year), int(month), int(day), type);
}

impl capi_datetime_from_date_and_time(
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

impl capi_time_from_time(
    hour: i32,
    minute: i32,
    second: i32,
    usecond: i32,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_time_ex(int(hour), int(minute), int(second), int(usecond), tzinfo, type);
}

impl capi_delta_from_delta(
    days: i32, seconds: i32, microseconds: i32, normalize: i32, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_delta_ex(
        int(days), int(seconds), int(microseconds), int(normalize), type
    );
}

impl datetime_date_fromtimestamp_capi(
    cls: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    timestamp: ptr[PyObject] = NULL;
    if PyArg_UnpackTuple(args, ptr[u8]("fromtimestamp"), 1, 1, &mut timestamp) == 0 {
        return NULL;
    }
    return date_fromtimestamp(cls, timestamp);
}

impl capi_datetime_from_date_and_time_and_fold(
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

impl capi_time_from_time_and_fold(
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
