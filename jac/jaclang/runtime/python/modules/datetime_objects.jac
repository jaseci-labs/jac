import from c {
    obj PyDateTime_TimeZone {
        has ob_base: _object,
            offset: ptr[PyObject],
            name: ptr[PyObject];
    }  glob PyDateTime_DateType: PyTypeObject,
         PyDateTime_DateTimeType: PyTypeObject,
         PyDateTime_TimeType: PyTypeObject,
         PyDateTime_DeltaType: PyTypeObject,
         PyDateTime_TZInfoType: PyTypeObject,
         PyDateTime_TimeZoneType: PyTypeObject,
         zero_delta: PyDateTime_Delta,
         utc_timezone: PyDateTime_TimeZone;
}

glob Py_LT: Final[int] = 0,
     Py_LE: Final[int] = 1,
     Py_EQ: Final[int] = 2,
     Py_NE: Final[int] = 3,
     Py_GT: Final[int] = 4,
     Py_GE: Final[int] = 5;

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

def date_type -> ptr[PyTypeObject];

def datetime_type -> ptr[PyTypeObject];

def time_type -> ptr[PyTypeObject];

def delta_type -> ptr[PyTypeObject];

def tzinfo_type -> ptr[PyTypeObject];

def timezone_type -> ptr[PyTypeObject];

def utc -> ptr[PyObject];

def type_object(type: ptr[PyTypeObject]) -> ptr[PyObject];

def type_of(op: ptr[PyObject]) -> ptr[PyObject];

def type_name_of(op: ptr[PyObject]) -> ptr[u8];

def date_check(op: ptr[PyObject]) -> bool;

def datetime_check(op: ptr[PyObject]) -> bool;

def time_check(op: ptr[PyObject]) -> bool;

def delta_check(op: ptr[PyObject]) -> bool;

def tzinfo_check(op: ptr[PyObject]) -> bool;

def timezone_check(op: ptr[PyObject]) -> bool;

def not_implemented -> ptr[PyObject];

def type_alloc(type: ptr[PyTypeObject], nitems: int) -> ptr[PyObject];

def type_free(op: ptr[PyObject]);

def get_year(op: ptr[PyObject]) -> int;

def get_month(op: ptr[PyObject]) -> int;

def get_day(op: ptr[PyObject]) -> int;

def date_get_hour(op: ptr[PyObject]) -> int;

def date_get_minute(op: ptr[PyObject]) -> int;

def date_get_second(op: ptr[PyObject]) -> int;

def date_get_microsecond(op: ptr[PyObject]) -> int;

def date_get_fold(op: ptr[PyObject]) -> int;

def time_get_hour(op: ptr[PyObject]) -> int;

def time_get_minute(op: ptr[PyObject]) -> int;

def time_get_second(op: ptr[PyObject]) -> int;

def time_get_microsecond(op: ptr[PyObject]) -> int;

def time_get_fold(op: ptr[PyObject]) -> int;

def has_tzinfo(op: ptr[PyObject]) -> bool;

def datetime_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject];

def time_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject];

def td_days(op: ptr[PyObject]) -> int;

def td_seconds(op: ptr[PyObject]) -> int;

def td_microseconds(op: ptr[PyObject]) -> int;

def set_date_fields(op: ptr[PyObject], year: int, month: int, day: int);

def set_datetime_time_fields(
    op: ptr[PyObject], hour: int, minute: int, second: int, microsecond: int
);

def set_time_fields(
    op: ptr[PyObject], hour: int, minute: int, second: int, microsecond: int
);

def interp_key -> ptr[PyObject];

def get_current_module(interp: ptr[PyInterpreterState]) -> tuple[int, ptr[PyObject]];

def get_current_state -> ptr[PyObject];

def state_value(module: ptr[PyObject], index: int) -> ptr[PyObject];

def current_state_value(index: int) -> ptr[PyObject];

def set_current_module(interp: ptr[PyInterpreterState], module: ptr[PyObject]) -> i32;

def clear_current_module(interp: ptr[PyInterpreterState], expected: ptr[PyObject]);

def check_delta_day_range(days: int) -> int;

def check_date_args(year: int, month: int, day: int) -> int;

def check_time_args(h: int, m: int, s: int, us: int, fold: int) -> int;

def normalize_date(fields: DateTimeFields) -> int;

def check_tzinfo_subclass(p: ptr[PyObject]) -> int;

def diff_to_bool(diff: int, op: int) -> ptr[PyObject];

def new_date_ex(
    year: int, month: int, day: int, type: ptr[PyTypeObject]
) -> ptr[PyObject];

def new_date(year: int, month: int, day: int) -> ptr[PyObject];

def new_date_subclass_ex(
    year: int, month: int, day: int, cls: ptr[PyObject]
) -> ptr[PyObject];

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
) -> ptr[PyObject];

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
) -> ptr[PyObject];

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
) -> ptr[PyObject];

def call_subclass_fold(
    cls: ptr[PyObject], fold: int, args: ptr[PyObject]
) -> ptr[PyObject];

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
) -> ptr[PyObject];

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
) -> ptr[PyObject];

def new_time_ex2(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    type: ptr[PyTypeObject]
) -> ptr[PyObject];

def new_time_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject];

def new_time(
    hour: int, minute: int, second: int, usecond: int, tzinfo: ptr[PyObject], fold: int
) -> ptr[PyObject];

def new_time_subclass_fold_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    cls: ptr[PyObject]
) -> ptr[PyObject];

def look_up_delta(
    days: int, seconds: int, microseconds: int, type: ptr[PyTypeObject]
) -> ptr[PyObject];

def new_delta_ex(
    days: int, seconds: int, microseconds: int, normalize: int, type: ptr[PyTypeObject]
) -> ptr[PyObject];

def new_delta(
    days: int, seconds: int, microseconds: int, normalize: int
) -> ptr[PyObject];

def look_up_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def create_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def offset_out_of_range(offset: ptr[PyObject]) -> bool;

def new_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def get_tzinfo_member(self: ptr[PyObject]) -> ptr[PyObject];

def call_tzinfo_method(
    tzinfo: ptr[PyObject], name: str, tzinfoarg: ptr[PyObject]
) -> ptr[PyObject];

def call_utcoffset(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject];

def call_dst(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject];

def call_tzname(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject];

def datetime_utcoffset(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def datetime_dst(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def append_keyword_tzinfo(repr: ptr[PyObject], tzinfo: ptr[PyObject]) -> ptr[PyObject];

def append_keyword_fold(repr: ptr[PyObject], fold: int) -> ptr[PyObject];

def tzinfo_from_isoformat_results(
    rv: int, tzoffset: int, tz_useconds: int
) -> ptr[PyObject];

def delta_bool(self: ptr[PyObject]) -> i32;

def delta_negative(self: ptr[PyObject]) -> ptr[PyObject];

def delta_subtract(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_cmp(self: ptr[PyObject], other: ptr[PyObject]) -> int;

def delta_to_microseconds(self: ptr[PyObject]) -> ptr[PyObject];

def checked_divmod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def divmod_part(pair: ptr[PyObject], index: int, bound: int) -> int;

def microseconds_to_delta_ex(
    pyus: ptr[PyObject], type: ptr[PyTypeObject]
) -> ptr[PyObject];

def microseconds_to_delta(pymicros: ptr[PyObject]) -> ptr[PyObject];

def divide_timedelta_timedelta(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject];

def add_datetime_timedelta(
    date: ptr[PyObject], delta: ptr[PyObject], factor: int
) -> ptr[PyObject];

def data_bytes(op: ptr[PyObject], size: int) -> ptr[PyObject];

def data_address(op: ptr[PyObject]) -> ptr[u8];

impl date_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DateType);
}

impl datetime_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DateTimeType);
}

impl time_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TimeType);
}

impl delta_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_DeltaType);
}

impl tzinfo_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TZInfoType);
}

impl timezone_type -> ptr[PyTypeObject] {
    return addressof(PyDateTime_TimeZoneType);
}

impl utc -> ptr[PyObject] {
    return ptr[PyObject](addressof(utc_timezone));
}

impl type_object(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    return ptr[PyObject](type);
}

impl type_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](object_type(op));
}

impl type_name_of(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

impl date_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, date_type());
}

impl datetime_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, datetime_type());
}

impl time_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, time_type());
}

impl delta_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, delta_type());
}

impl tzinfo_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, tzinfo_type());
}

impl timezone_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, timezone_type());
}

impl not_implemented -> ptr[PyObject] {
    return Py_NewRef(Py_NotImplemented);
}

impl type_alloc(type: ptr[PyTypeObject], nitems: int) -> ptr[PyObject] {
    return type.view(1)[0].tp_alloc(type, nitems);
}

impl type_free(op: ptr[PyObject]) {
    object_type(op).view(1)[0].tp_free(ptr(op));
}

impl get_year(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_Date](op).view(1);
    return (int(record[0].data) << 8) | int(record[0].data_1);
}

impl get_month(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Date](op).view(1)[0].data_2);
}

impl get_day(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Date](op).view(1)[0].data_3);
}

impl date_get_hour(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_4);
}

impl date_get_minute(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_5);
}

impl date_get_second(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].data_6);
}

impl date_get_microsecond(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_DateTime](op).view(1);
    return (int(record[0].data_7) << 16)
        | (int(record[0].data_8) << 8)
        | int(record[0].data_9);
}

impl date_get_fold(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_DateTime](op).view(1)[0].fold);
}

impl time_get_hour(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data);
}

impl time_get_minute(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data_1);
}

impl time_get_second(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].data_2);
}

impl time_get_microsecond(op: ptr[PyObject]) -> int {
    record = ptr[PyDateTime_Time](op).view(1);
    return (int(record[0].data_3) << 16)
        | (int(record[0].data_4) << 8)
        | int(record[0].data_5);
}

impl time_get_fold(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Time](op).view(1)[0].fold);
}

impl has_tzinfo(op: ptr[PyObject]) -> bool {
    return ptr[_PyDateTime_BaseTZInfo](op).view(1)[0].hastzinfo != 0;
}

impl datetime_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject] {
    if has_tzinfo(op) {
        return ptr[PyDateTime_DateTime](op).view(1)[0].tzinfo;
    }
    return Py_None;
}

impl time_tzinfo_of(op: ptr[PyObject]) -> ptr[PyObject] {
    if has_tzinfo(op) {
        return ptr[PyDateTime_Time](op).view(1)[0].tzinfo;
    }
    return Py_None;
}

impl td_days(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].days);
}

impl td_seconds(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].seconds);
}

impl td_microseconds(op: ptr[PyObject]) -> int {
    return int(ptr[PyDateTime_Delta](op).view(1)[0].microseconds);
}

impl set_date_fields(op: ptr[PyObject], year: int, month: int, day: int) {
    record = ptr[PyDateTime_Date](op).view(1);
    record[0].hashcode = -1;
    record[0].data = u8((year & 0xff00) >> 8);
    record[0].data_1 = u8(year & 0x00ff);
    record[0].data_2 = u8(month);
    record[0].data_3 = u8(day);
}

impl set_datetime_time_fields(
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

impl set_time_fields(
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

impl interp_key -> ptr[PyObject] {
    return PyUnicode_InternFromString(ptr[u8]("cached_datetime_module"));
}

impl get_current_module(interp: ptr[PyInterpreterState]) -> tuple[int, ptr[PyObject]] {
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

impl get_current_state -> ptr[PyObject] {
    interp = PyInterpreterState_Get();
    (status, module) = get_current_module(interp);
    if status < 0 {
        return NULL;
    }
    if not module {
        module = PyImport_ImportModule("_datetime");
    }
    return module;
}

impl state_value(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl current_state_value(index: int) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    value = Py_NewRef(state_value(module, index));
    jacpy_release(module);
    return value;
}

impl set_current_module(interp: ptr[PyInterpreterState], module: ptr[PyObject]) -> i32 {
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

impl clear_current_module(interp: ptr[PyInterpreterState], expected: ptr[PyObject]) {
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
            jacpy_release(current);
            jacpy_release(ref);
            if rc < 0 {
                failed = True;
            } elif current != expected {
                replaced = True;
            }
        }
    }

    if not failed and not replaced and PyDict_SetItem(dict, key, Py_None) < 0 {
        failed = True;
    }
    jacpy_release(key);
    if failed {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while clearing _datetime module")
        );
    }
    PyErr_SetRaisedException(exc);
}

impl check_delta_day_range(days: int) -> int {
    if -MAX_DELTA_DAYS <= days and days <= MAX_DELTA_DAYS {
        return 0;
    }
    PyErr_Format(
        PyExc_OverflowError,
        ptr[u8]("days=%ld; must have magnitude <= %ld"),
        days,
        MAX_DELTA_DAYS
    );
    return -1;
}

impl check_date_args(year: int, month: int, day: int) -> int {
    if year < MINYEAR or year > MAXYEAR {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("year must be in %ld..%ld, not %ld"),
            MINYEAR,
            MAXYEAR,
            year
        );
        return -1;
    }
    if month < 1 or month > 12 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("month must be in 1..12, not %ld"), month
        );
        return -1;
    }
    dim = days_in_month(year, month);
    if day < 1 or day > dim {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("day %ld must be in range 1..%ld for month %ld in year %ld"),
            day,
            dim,
            month,
            year
        );
        return -1;
    }
    return 0;
}

impl check_time_args(h: int, m: int, s: int, us: int, fold: int) -> int {
    if h < 0 or h > 23 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("hour must be in 0..23, not %ld"), h);
        return -1;
    }
    if m < 0 or m > 59 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("minute must be in 0..59, not %ld"), m);
        return -1;
    }
    if s < 0 or s > 59 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("second must be in 0..59, not %ld"), s);
        return -1;
    }
    if us < 0 or us > 999999 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("microsecond must be in 0..999999, not %ld"), us
        );
        return -1;
    }
    if fold != 0 and fold != 1 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("fold must be either 0 or 1, not %ld"), fold
        );
        return -1;
    }
    return 0;
}

impl normalize_date(fields: DateTimeFields) -> int {
    if normalize_y_m_d(fields) {
        return 0;
    }
    PyErr_SetString(PyExc_OverflowError, ptr[u8]("date value out of range"));
    return -1;
}

impl check_tzinfo_subclass(p: ptr[PyObject]) -> int {
    if p == Py_None or tzinfo_check(p) {
        return 0;
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("tzinfo argument must be None or of a tzinfo subclass, not type '%s'"),
        type_name_of(p)
    );
    return -1;
}

impl diff_to_bool(diff: int, op: int) -> ptr[PyObject] {
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

impl new_date_ex(
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

impl new_date(year: int, month: int, day: int) -> ptr[PyObject] {
    return new_date_ex(year, month, day, date_type());
}

impl new_date_subclass_ex(
    year: int, month: int, day: int, cls: ptr[PyObject]
) -> ptr[PyObject] {
    if cls == type_object(date_type()) {
        return new_date_ex(year, month, day, date_type());
    }
    if cls == type_object(datetime_type()) {
        return new_datetime_ex(year, month, day, 0, 0, 0, 0, Py_None, datetime_type());
    }
    return PyObject_CallFunction(cls, "lll", year, month, day);
}

impl new_datetime_ex2(
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

impl new_datetime_ex(
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

impl new_datetime(
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

impl call_subclass_fold(
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
                ready = PyDict_SetItemString(kwargs, ptr[u8]("fold"), value) >= 0;
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

impl new_datetime_subclass_fold_ex(
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
        return new_datetime(
            year, month, day, hour, minute, second, usecond, tzinfo, fold
        );
    }

    return call_subclass_fold(
        cls,
        fold,
        Py_BuildValue(
            ptr[u8]("lllllllO"), year, month, day, hour, minute, second, usecond, tzinfo
        )
    );
}

impl new_datetime_subclass_ex(
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

impl new_time_ex2(
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

impl new_time_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    return new_time_ex2(hour, minute, second, usecond, tzinfo, 0, type);
}

impl new_time(
    hour: int, minute: int, second: int, usecond: int, tzinfo: ptr[PyObject], fold: int
) -> ptr[PyObject] {
    return new_time_ex2(hour, minute, second, usecond, tzinfo, fold, time_type());
}

impl new_time_subclass_fold_ex(
    hour: int,
    minute: int,
    second: int,
    usecond: int,
    tzinfo: ptr[PyObject],
    fold: int,
    cls: ptr[PyObject]
) -> ptr[PyObject] {
    if cls == type_object(time_type()) {
        return new_time(hour, minute, second, usecond, tzinfo, fold);
    }

    return call_subclass_fold(
        cls,
        fold,
        Py_BuildValue(ptr[u8]("llllO"), hour, minute, second, usecond, tzinfo)
    );
}

impl look_up_delta(
    days: int, seconds: int, microseconds: int, type: ptr[PyTypeObject]
) -> ptr[PyObject] {
    zero = ptr[PyObject](addressof(zero_delta));
    if days == 0 and seconds == 0 and microseconds == 0 and type == object_type(zero) {
        return zero;
    }
    return NULL;
}

impl new_delta_ex(
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

impl new_delta(
    days: int, seconds: int, microseconds: int, normalize: int
) -> ptr[PyObject] {
    return new_delta_ex(days, seconds, microseconds, normalize, delta_type());
}

impl look_up_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if offset == addressof(utc_timezone).view(1)[0].offset and not name {
        return utc();
    }
    return NULL;
}

impl create_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
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

impl offset_out_of_range(offset: ptr[PyObject]) -> bool {
    days = td_days(offset);
    return (days == -1 and td_seconds(offset) == 0 and td_microseconds(offset) < 1)
        or days < -1
        or days >= 1;
}

impl new_timezone(offset: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    if not name and delta_bool(offset) == 0 {
        return Py_NewRef(utc());
    }
    if offset_out_of_range(offset) {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8](
                "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not %R"
            ),
            offset
        );
        return NULL;
    }
    return create_timezone(offset, name);
}

impl get_tzinfo_member(self: ptr[PyObject]) -> ptr[PyObject] {
    if datetime_check(self) and has_tzinfo(self) {
        return ptr[PyDateTime_DateTime](self).view(1)[0].tzinfo;
    }
    if time_check(self) and has_tzinfo(self) {
        return ptr[PyDateTime_Time](self).view(1)[0].tzinfo;
    }
    return NULL;
}

impl call_tzinfo_method(
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
                ptr[u8](
                    "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not %R"
                ),
                offset
            );
            jacpy_release(offset);
            return NULL;
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("tzinfo.%s() must return None or timedelta, not '%.200s'"),
            name,
            type_name_of(offset)
        );
        jacpy_release(offset);
        return NULL;
    }
    return offset;
}

impl call_utcoffset(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzinfo_method(tzinfo, "utcoffset", tzinfoarg);
}

impl call_dst(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
    return call_tzinfo_method(tzinfo, "dst", tzinfoarg);
}

impl call_tzname(tzinfo: ptr[PyObject], tzinfoarg: ptr[PyObject]) -> ptr[PyObject] {
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
            ptr[u8]("tzinfo.tzname() must return None or a string, not '%s'"),
            type_name_of(result)
        );
        jacpy_release(result);
        return NULL;
    }
    return result;
}

impl datetime_utcoffset(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_utcoffset(datetime_tzinfo_of(op), op);
}

impl datetime_dst(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return call_dst(datetime_tzinfo_of(op), op);
}

impl append_keyword_tzinfo(
    repr: ptr[PyObject], tzinfo: ptr[PyObject]
) -> ptr[PyObject] {
    if tzinfo == Py_None {
        return repr;
    }

    temp = PyUnicode_Substring(repr, 0, PyUnicode_GetLength(repr) - 1);
    jacpy_release(repr);
    if not temp {
        return NULL;
    }
    result = PyUnicode_FromFormat("%U, tzinfo=%R)", temp, tzinfo);
    jacpy_release(temp);
    return result;
}

impl append_keyword_fold(repr: ptr[PyObject], fold: int) -> ptr[PyObject] {
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

impl tzinfo_from_isoformat_results(
    rv: int, tzoffset: int, tz_useconds: int
) -> ptr[PyObject] {
    if rv != 1 {
        return Py_NewRef(Py_None);
    }

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

impl delta_bool(self: ptr[PyObject]) -> i32 {
    return i32(
        1
            if td_days(self) != 0 or td_seconds(self) != 0 or td_microseconds(self) != 0
            else 0
    );
}

impl delta_negative(self: ptr[PyObject]) -> ptr[PyObject] {
    return new_delta(-td_days(self), -td_seconds(self), -td_microseconds(self), 1);
}

impl delta_subtract(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) and delta_check(right) {
        return new_delta(
            td_days(left) - td_days(right),
            td_seconds(left) - td_seconds(right),
            td_microseconds(left) - td_microseconds(right),
            1
        );
    }
    return not_implemented();
}

impl delta_cmp(self: ptr[PyObject], other: ptr[PyObject]) -> int {
    diff = td_days(self) - td_days(other);
    if diff == 0 {
        diff = td_seconds(self) - td_seconds(other);
        if diff == 0 {
            diff = td_microseconds(self) - td_microseconds(other);
        }
    }
    return diff;
}

impl delta_to_microseconds(self: ptr[PyObject]) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    x1 = PyLong_FromLong(td_days(self));
    x2: ptr[PyObject] = NULL;
    x3: ptr[PyObject] = NULL;
    if x1 {
        x2 = PyNumber_Multiply(x1, state_value(module, STATE_SECONDS_PER_DAY));
    }
    if x2 {
        jacpy_release(x1);
        x1 = PyLong_FromLong(td_seconds(self));
        if x1 {
            x3 = PyNumber_Add(x1, x2);
        }
    }
    if x3 {
        jacpy_release(x1);
        jacpy_release(x2);
        x2 = NULL;

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

impl checked_divmod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    result = PyNumber_Divmod(a, b);
    if result {
        if jacpy_is_tuple(result) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("divmod() returned non-tuple (type %.200s)"),
                type_name_of(result)
            );
            jacpy_release(result);
            return NULL;
        }
        size = PyTuple_Size(result);
        if size != 2 {
            PyErr_Format(
                PyExc_TypeError, ptr[u8]("divmod() returned a tuple of size %zd"), size
            );
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}

impl divmod_part(pair: ptr[PyObject], index: int, bound: int) -> int {
    value = int(PyLong_AsInt(PyTuple_GetItem(pair, i64(index))));
    if value == -1 and PyErr_Occurred() {
        return -1;
    }
    if not (0 <= value and value < bound) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("divmod() returned a value out of range")
        );
        return -1;
    }
    return value;
}

impl microseconds_to_delta_ex(
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
            num = Py_NewRef(PyTuple_GetItem(tuple, 0));
            jacpy_release(tuple);
            tuple = checked_divmod(num, state_value(module, STATE_SECONDS_PER_DAY));
            jacpy_release(num);
            if tuple {
                s = divmod_part(tuple, 1, 24 * 3600);
                if s >= 0 {
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

impl microseconds_to_delta(pymicros: ptr[PyObject]) -> ptr[PyObject] {
    return microseconds_to_delta_ex(pymicros, delta_type());
}

impl divide_timedelta_timedelta(
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

impl add_datetime_timedelta(
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
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("date value out of range"));
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

impl data_bytes(op: ptr[PyObject], size: int) -> ptr[PyObject] {
    return jacpy_bytes_from_memory(ptr(data_address(op)), i64(size));
}

impl data_address(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PY_DATETIME_DATA_OFFSET;
}
