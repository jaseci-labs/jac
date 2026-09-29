"""zoneinfo.ZoneInfo: IANA time zones from TZif data, as a datetime.tzinfo.

Derived from CPython 3.14.6 Modules/_zoneinfo.c; see ../LICENSE.cpython.
zoneinfo._common reads a TZif file into Python values; this module derives the
DST offsets and wall-time transitions from them, parses the POSIX TZ string
that governs times after the last transition, and answers utcoffset(), dst(),
tzname() and fromutc() by bisecting those transitions. Datetime fields are read
through the PyDateTime_DateTime layout, as the datetime.h macros read them.
The module keeps the timedelta cache, the weak cache and an eight-cached
strong LRU cache of the ZoneInfo base class; subclasses keep a weak cache in
their `_weak_cache` attribute.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    PyBytes_AsString,
    PyDict_GetItemRef,
    PyDict_New,
    PyDict_SetDefaultRef,
    PyDict_SetItemString,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_GetRaisedException,
    PyErr_Occurred,
    PyExc_MemoryError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModule,
    PyImport_ImportModuleAttrString,
    PyIter_Next,
    PyLong_AsLong,
    PyLong_AsLongLong,
    PyLong_AsSsize_t,
    PyLong_FromLong,
    PyNumber_Add,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallMethod,
    PyObject_CallMethodObjArgs,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyObject_IsTrue,
    PyObject_Repr,
    PyObject_RichCompareBool,
    PyObject_SetAttrString,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Size,
    PyTuple_Type,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyUnicode_DecodeUTF8Stateful,
    _PyErr_ChainExceptions1,
    _PyType_Name,
    jacpy_is_tuple,
    jacpy_release,
    jacpy_type_check
}
import from jaclang.runtime.python.object_model.capsule { PyCapsule_Import }
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.layouts { PyDateTime_CAPI, PyDateTime_DateTime }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_owner
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.converters { ClassToken }

# The handle of the module definition, which the binding fills in, so a type
# finds its module as PyType_GetModuleByDef() does.
obj DefinitionHandle {
    has handle: ptr = ptr();
}

glob module_definition = DefinitionHandle(),
     ZoneInfo_token = ClassToken();

glob:priv EPOCHORDINAL: i64 = 719163,
     DAYS_IN_MONTH: list[i64] = [-1, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
     DAYS_BEFORE_MONTH: list[i64] = [
         -1,
         0,
         31,
         59,
         90,
         120,
         151,
         181,
         212,
         243,
         273,
         304,
         334
     ],
     SOURCE_NOCACHE: i64 = 0,
     SOURCE_CACHE: i64 = 1,
     SOURCE_FILE: i64 = 2,
     ZONEINFO_STRONG_CACHE_MAX_SIZE: int = 8,
     PY_EQ: i32 = 2;

# _ttinfo: the offsets and abbreviation in effect over some span of time.
obj TTInfo {
    has utcoff: ptr[PyObject] = NULL,
        dstoff: ptr[PyObject] = NULL,
        tzname: ptr[PyObject] = NULL,
        utcoff_seconds: i64 = 0;

    def drop {
        jacpy_release(self.utcoff);
        jacpy_release(self.dstoff);
        jacpy_release(self.tzname);
    }
}

# TransitionRuleType: when, in local standard time, a transition of a POSIX
# TZ rule happens in a given year.
obj TransitionRule {
    def year_to_timestamp(year: i64) -> i64 abst;
}

# Mm.n.d: day `day` (0 = Sunday) of week `week` (5 = the last) of `month`.
obj CalendarRule(TransitionRule) {
    has month: i64 = 0,
        week: i64 = 0,
        day: i64 = 0,
        hour: i64 = 0,
        minute: i64 = 0,
        second: i64 = 0;

    override def year_to_timestamp(year: i64) -> i64 {
        # Week 1 is the first week in which day `day` appears; week 5 is its
        # last occurrence, so the first weekday of the month and the number of
        # days in the month decide it.
        first_day = (ymd_to_ord(year, self.month, 1) + 6) % 7;
        days_in_month = DAYS_IN_MONTH[self.month];
        if self.month == 2 and is_leap_year(year) {
            days_in_month += 1;
        }
        # calendar counts 0 = Monday and POSIX 0 = Sunday, so first_day + 1
        # is the POSIX weekday; the difference mod 7, plus 1 because month
        # days count from 1, is the first occurrence.
        month_day = (self.day - (first_day + 1)) % 7;
        if month_day < 0 {
            month_day += 7;
        }
        month_day += 1;
        month_day += (self.week - 1) * 7;
        # Only week 5 overshoots the month: it means the last occurrence.
        if month_day > days_in_month {
            month_day -= 7;
        }
        ordinal = ymd_to_ord(year, self.month, month_day) - EPOCHORDINAL;
        return ordinal * 86400 + self.hour * 3600 + self.minute * 60 + self.second;
    }
}

# Jn (julian: 1-based, leap days not counted) or n (0-based, leap days
# counted): a day of the year.
obj DayRule(TransitionRule) {
    has julian: bool = False,
        day: i64 = 0,
        hour: i64 = 0,
        minute: i64 = 0,
        second: i64 = 0;

    override def year_to_timestamp(year: i64) -> i64 {
        # Days since 1970-01-01 before January 1st of the year; partial days
        # are the hour, minute and second.
        days_before_year = ymd_to_ord(year, 1, 1) - EPOCHORDINAL - 1;
        # A Julian day skips February 29th: J60 is always March 1st.
        day = self.day;
        if self.julian and day >= 59 and is_leap_year(year) {
            day += 1;
        }
        return (days_before_year + day) * 86400
            + self.hour * 3600
            + self.minute * 60
            + self.second;
    }
}

# _tzrule: standard and daylight time and the rules switching between them.
obj TZRule {
    has std: TTInfo = TTInfo(),
        dst: TTInfo = TTInfo(),
        dst_diff: i64 = 0,
        start: (TransitionRule | None) = None,
        end: (TransitionRule | None) = None,
        std_only: bool = False;
}

# StrongCacheNode: one entry of the base class's LRU cache.
obj StrongCacheNode {
    has key: ptr[PyObject] = NULL,
        zone: ptr[PyObject] = NULL;

    def drop {
        jacpy_release(self.key);
        jacpy_release(self.zone);
    }
}

# zoneinfo_state.
obj ZoneInfoModuleState(NativeState) {
    has zoneinfo_type: ptr[PyObject] = NULL,
        io_open: ptr[PyObject] = NULL,
        tzpath_find_tzfile: ptr[PyObject] = NULL,
        common_mod: ptr[PyObject] = NULL,
        timedelta_cache: ptr[PyObject] = NULL,
        weak_cache: ptr[PyObject] = NULL,
        strong_cache: list[StrongCacheNode] = [],
        no_ttinfo: TTInfo = TTInfo(),
        datetime_api: ptr[PyDateTime_CAPI] = ptr[PyDateTime_CAPI]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        for value in [
            self.zoneinfo_type,
            self.io_open,
            self.tzpath_find_tzfile,
            self.common_mod,
            self.timedelta_cache,
            self.weak_cache
        ] {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        for cached in self.strong_cache {
            status = visit_reference(cached.key, visitor, context);
            if status == 0 {
                status = visit_reference(cached.zone, visitor, context);
            }
            if status != 0 {
                return status;
            }
        }
        for value in [
            self.no_ttinfo.utcoff,
            self.no_ttinfo.dstoff,
            self.no_ttinfo.tzname
        ] {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    def clear {
        references = [
            self.zoneinfo_type,
            self.io_open,
            self.tzpath_find_tzfile,
            self.common_mod,
            self.timedelta_cache,
            self.weak_cache
        ];
        self.zoneinfo_type = NULL;
        self.io_open = NULL;
        self.tzpath_find_tzfile = NULL;
        self.common_mod = NULL;
        self.timedelta_cache = NULL;
        self.weak_cache = NULL;
        self.strong_cache = [];
        self.no_ttinfo = TTInfo();
        for value in references {
            jacpy_release(value);
        }
    }

    def drop {
        self.clear();
    }
}

# PyZoneInfo_ZoneInfo: the transitions and rules of one zone.
obj ZoneInfoState(NativeState) {
    has key: ptr[PyObject] = NULL,
        file_repr: ptr[PyObject] = NULL,
        trans_list_utc: list[i64] = [],
        trans_list_wall: list[list[i64]] = [[], []],
        trans_ttinfos: list[TTInfo] = [],
        ttinfo_before: (TTInfo | None) = None,
        tzrule_after: TZRule = TZRule(),
        ttinfos: list[TTInfo] = [],
        fixed_offset: bool = False,
        source: i64 = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.key, visitor, context);
    }

    def clear {
        key = self.key;
        file_repr = self.file_repr;
        self.key = NULL;
        self.file_repr = NULL;
        jacpy_release(key);
        jacpy_release(file_repr);
    }

    def drop {
        self.clear();
    }
}

def module_state(module: ptr[PyObject]) -> (ZoneInfoModuleState | None) {
    if module and jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, ZoneInfoModuleState) {
            return state;
        }
    }
    if not PyErr_Occurred() {
        object_error(PyExc_SystemError, "_zoneinfo module state is unavailable");
    }
    return None;
}

# zoneinfo_get_state_by_self(): the state of the module that defines `type`
# or the ZoneInfo class it derives from.
def:priv state_by_type(type: ptr[PyObject]) -> (ZoneInfoModuleState | None) {
    return module_state(jacpy_binding_owner(type, module_definition.handle));
}

# zoneinfo_get_state_by_cls(): the state of the defining class's module.
def:priv state_by_class(cls: ptr[PyObject]) -> (ZoneInfoModuleState | None) {
    return state_by_type(cls);
}

def zoneinfo_of(instance: ptr[PyObject]) -> (ZoneInfoState | None) {
    if jacpy_binding_native_present(instance, ZoneInfo_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZoneInfo_token.handle);
        if isinstance(state, ZoneInfoState) {
            return state;
        }
    }
    if not PyErr_Occurred() {
        object_error(PyExc_SystemError, "ZoneInfo state is unavailable");
    }
    return None;
}

# ttinfo_before, which every zone with a transition has.
def:priv before_ttinfo(zone: ZoneInfoState) -> TTInfo {
    before = zone.ttinfo_before;
    if before is None {
        return TTInfo();
    }
    return before;
}

# The datetime.h macros, over the PyDateTime_DateTime layout.
def:priv datetime_year(dt: ptr[PyObject]) -> i64 {
    fields = ptr[PyDateTime_DateTime](dt).view(1);
    return (i64(fields[0].data) << 8) | i64(fields[0].data_1);
}

def:priv datetime_fold(dt: ptr[PyObject]) -> i64 {
    return i64(ptr[PyDateTime_DateTime](dt).view(1)[0].fold);
}

def:priv datetime_tzinfo(dt: ptr[PyObject]) -> ptr[PyObject] {
    fields = ptr[PyDateTime_DateTime](dt).view(1);
    return fields[0].tzinfo if fields[0].hastzinfo != 0 else Py_None;
}

def:priv datetime_type(state: ZoneInfoModuleState) -> ptr[PyObject] {
    return ptr[PyObject](state.datetime_api.view(1)[0].DateTimeType);
}

def:priv is_datetime_exact(state: ZoneInfoModuleState, value: ptr[PyObject]) -> bool {
    return Py_TYPE(value) == datetime_type(state);
}

def:priv is_datetime(state: ZoneInfoModuleState, value: ptr[PyObject]) -> bool {
    return jacpy_type_check(value, datetime_type(state)) != 0;
}

def:priv zoneinfo_new_instance(
    state: ZoneInfoModuleState, type: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    file_obj = NULL;
    file_path = PyObject_CallOneArg(state.tzpath_find_tzfile, key);
    if not file_path {
        return NULL;
    } elif file_path == Py_None {
        file_obj = PyObject_CallMethod(state.common_mod, "load_tzdata", "O", key);
        if not file_obj {
            jacpy_release(file_path);
            return NULL;
        }
    }
    instance = jacpy_binding_allocate(type);
    failed = not instance;
    if not failed and not file_obj {
        file_obj = PyObject_CallFunction(state.io_open, "Os", file_path, "rb");
        failed = not file_obj;
    }
    if not failed {
        zone = ZoneInfoState();
        failed = not load_data(state, zone, file_obj);
        if not failed {
            closed = PyObject_CallMethod(file_obj, "close", "");
            jacpy_release(file_obj);
            file_obj = NULL;
            if closed {
                jacpy_release(closed);
                zone.key = Py_NewRef(key);
                failed = jacpy_binding_native_set(instance, ZoneInfo_token.handle, zone)
                    < 0;
            } else {
                failed = True;
            }
        }
    }
    if failed {
        jacpy_release(instance);
        instance = NULL;
    }
    if file_obj {
        exc = PyErr_GetRaisedException();
        closed = PyObject_CallMethod(file_obj, "close", "");
        _PyErr_ChainExceptions1(exc);
        if not closed {
            jacpy_release(instance);
            instance = NULL;
        }
        jacpy_release(closed);
        jacpy_release(file_obj);
    }
    jacpy_release(file_path);
    return instance;
}

def:priv get_weak_cache(
    state: ZoneInfoModuleState, type: ptr[PyObject]
) -> ptr[PyObject] {
    if type == state.zoneinfo_type {
        return Py_NewRef(state.weak_cache);
    }
    return PyObject_GetAttrString(type, "_weak_cache");
}

def zoneinfo_ZoneInfo_impl(type: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    state = state_by_type(type);
    if state is None {
        return NULL;
    }
    instance = zone_from_strong_cache(state, type, key);
    if instance or PyErr_Occurred() {
        return instance;
    }
    weak_cache = get_weak_cache(state, type);
    if not weak_cache {
        return NULL;
    }
    instance = PyObject_CallMethod(weak_cache, "get", "O", key);
    if not instance {
        jacpy_release(weak_cache);
        return NULL;
    }
    if instance == Py_None {
        jacpy_release(instance);
        created = zoneinfo_new_instance(state, type, key);
        if not created {
            jacpy_release(weak_cache);
            return NULL;
        }
        zone = zoneinfo_of(created);
        if zone is not None {
            zone.source = SOURCE_CACHE;
        }
        instance = PyObject_CallMethod(weak_cache, "setdefault", "OO", key, created);
        jacpy_release(created);
        if not instance {
            jacpy_release(weak_cache);
            return NULL;
        }
    }
    if jacpy_type_check(instance, type) == 0 {
        PyErr_Format(
            PyExc_RuntimeError,
            "Unexpected instance of %T in %s weak cache for key %R",
            instance,
            _PyType_Name(type),
            key
        );
        jacpy_release(instance);
        jacpy_release(weak_cache);
        return NULL;
    }
    update_strong_cache(state, type, key, instance);
    jacpy_release(weak_cache);
    return instance;
}

def zoneinfo_ZoneInfo_from_file_impl(
    type: ptr[PyObject], cls: ptr[PyObject], file_obj: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    file_repr = PyObject_Repr(file_obj);
    if not file_repr {
        jacpy_release(instance);
        return NULL;
    }
    state = state_by_class(cls);
    zone = ZoneInfoState();
    if state is None or not load_data(state, zone, file_obj) {
        jacpy_release(file_repr);
        jacpy_release(instance);
        return NULL;
    }
    zone.source = SOURCE_FILE;
    zone.file_repr = file_repr;
    zone.key = Py_NewRef(key);
    if jacpy_binding_native_set(instance, ZoneInfo_token.handle, zone) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def zoneinfo_ZoneInfo_no_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_class(cls);
    if state is None {
        return NULL;
    }
    out = zoneinfo_new_instance(state, type, key);
    if out {
        zone = zoneinfo_of(out);
        if zone is not None {
            zone.source = SOURCE_NOCACHE;
        }
    }
    return out;
}

def zoneinfo_ZoneInfo_clear_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], only_keys: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_by_class(cls);
    if state is None {
        return NULL;
    }
    weak_cache = get_weak_cache(state, type);
    if not weak_cache {
        return NULL;
    }
    if not only_keys or only_keys == Py_None {
        cleared = PyObject_CallMethod(weak_cache, "clear", "");
        jacpy_release(cleared);
        clear_strong_cache(state, type);
    } else {
        pop = PyUnicode_FromString("pop");
        if not pop {
            jacpy_release(weak_cache);
            return NULL;
        }
        iterator = PyObject_GetIter(only_keys);
        if not iterator {
            jacpy_release(pop);
            jacpy_release(weak_cache);
            return NULL;
        }
        item = PyIter_Next(iterator);
        while item {
            # Remove from the strong cache, then from the weak cache.
            if not eject_from_strong_cache(state, type, item) {
                jacpy_release(item);
                break;
            }
            popped = PyObject_CallMethodObjArgs(weak_cache, pop, item, Py_None, NULL);
            jacpy_release(item);
            if not popped {
                break;
            }
            jacpy_release(popped);
            item = PyIter_Next(iterator);
        }
        jacpy_release(iterator);
        jacpy_release(pop);
    }
    jacpy_release(weak_cache);
    if PyErr_Occurred() {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def:priv ttinfo_method(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject], field: int
) -> ptr[PyObject] {
    state = state_by_class(cls);
    zone = zoneinfo_of(receiver);
    if state is None or zone is None {
        return NULL;
    }
    tti = find_ttinfo(state, zone, dt);
    if tti is None {
        return NULL;
    }
    if field == 0 {
        return Py_NewRef(tti.utcoff);
    }
    return Py_NewRef(tti.dstoff) if field == 1 else Py_NewRef(tti.tzname);
}

def zoneinfo_ZoneInfo_utcoffset_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    return ttinfo_method(receiver, cls, dt, 0);
}

def zoneinfo_ZoneInfo_dst_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    return ttinfo_method(receiver, cls, dt, 1);
}

def zoneinfo_ZoneInfo_tzname_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    return ttinfo_method(receiver, cls, dt, 2);
}

# fromutc(dt): dt, whose wall time is UTC, as local time in this zone.
def zoneinfo_fromutc(receiver: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    state = state_by_type(Py_TYPE(receiver));
    if state is None {
        return NULL;
    }
    if not is_datetime(state, dt) {
        object_error(PyExc_TypeError, "fromutc: argument must be a datetime");
        return NULL;
    }
    if datetime_tzinfo(dt) != receiver {
        object_error(PyExc_ValueError, "fromutc: dt.tzinfo is not self");
        return NULL;
    }
    zone = zoneinfo_of(receiver);
    if zone is None {
        return NULL;
    }
    timestamp = local_timestamp(state, dt);
    if timestamp is None {
        return NULL;
    }
    num_trans = len(zone.trans_list_utc);
    tti = before_ttinfo(zone);
    fold = False;
    if num_trans >= 1 and timestamp < zone.trans_list_utc[0] {
        tti = before_ttinfo(zone);
    } elif num_trans == 0 or timestamp > zone.trans_list_utc[num_trans - 1] {
        found = find_tzrule_ttinfo_fromutc(
            zone.tzrule_after, timestamp, datetime_year(dt)
        );
        tti = found.tti;
        fold = found.fold;
        # Just after the last listed transition the fold or gap is between
        # the ttinfo of that transition's predecessor and the one that
        # applies after it, not between the rule's STD and DST.
        if num_trans {
            tti_prev = before_ttinfo(zone)
                if num_trans == 1
                else zone.trans_ttinfos[num_trans - 2];
            diff = tti_prev.utcoff_seconds - tti.utcoff_seconds;
            if diff > 0 and timestamp < zone.trans_list_utc[num_trans - 1] + diff {
                fold = True;
            }
        }
    } else {
        idx = bisect_right(timestamp, zone.trans_list_utc);
        tti_prev = before_ttinfo(zone);
        if idx >= 2 {
            tti_prev = zone.trans_ttinfos[idx - 2];
            tti = zone.trans_ttinfos[idx - 1];
        } else {
            tti = zone.trans_ttinfos[0];
        }
        # Detect a fold.
        shift = tti_prev.utcoff_seconds - tti.utcoff_seconds;
        if shift > timestamp - zone.trans_list_utc[idx - 1] {
            fold = True;
        }
    }
    shifted = PyNumber_Add(dt, tti.utcoff);
    if not shifted or not fold {
        return shifted;
    }
    if is_datetime_exact(state, shifted) {
        ptr[PyDateTime_DateTime](shifted).view(1)[0].fold = 1;
        return shifted;
    }
    replace = PyObject_GetAttrString(shifted, "replace");
    jacpy_release(shifted);
    if not replace {
        return NULL;
    }
    args = PyTuple_New(0);
    if not args {
        jacpy_release(replace);
        return NULL;
    }
    kwargs = PyDict_New();
    if not kwargs {
        jacpy_release(replace);
        jacpy_release(args);
        return NULL;
    }
    result = NULL;
    one = PyLong_FromLong(1);
    if one and PyDict_SetItemString(kwargs, "fold", one) == 0 {
        result = PyObject_Call(replace, args, kwargs);
    }
    jacpy_release(one);
    jacpy_release(args);
    jacpy_release(kwargs);
    jacpy_release(replace);
    return result;
}

def zoneinfo_repr(receiver: ptr[PyObject]) -> ptr[PyObject] {
    zone = zoneinfo_of(receiver);
    if zone is None {
        return NULL;
    }
    if zone.key != Py_None {
        return PyUnicode_FromFormat("%T(key=%R)", receiver, zone.key);
    }
    return PyUnicode_FromFormat("%T.from_file(%U)", receiver, zone.file_repr);
}

def zoneinfo_str(receiver: ptr[PyObject]) -> ptr[PyObject] {
    zone = zoneinfo_of(receiver);
    if zone is None {
        return NULL;
    }
    if zone.key != Py_None {
        return Py_NewRef(zone.key);
    }
    return zoneinfo_repr(receiver);
}

# ZoneInfo objects pickle by key and source: by reference to the TZif data
# they came from, and whether they came through the cache, since from-cache
# objects hit the unpickling process's cache and no-cache objects bypass it.
# Objects made by ZoneInfo.from_file cannot be pickled.
def zoneinfo_reduce(receiver: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    zone = zoneinfo_of(receiver);
    if zone is None {
        return NULL;
    }
    if zone.source == SOURCE_FILE {
        pickle_error = PyImport_ImportModuleAttrString("pickle", "PicklingError");
        if not pickle_error {
            return NULL;
        }
        object_error(pickle_error, "Cannot pickle a ZoneInfo file from a file stream.");
        jacpy_release(pickle_error);
        return NULL;
    }
    from_cache = 1 if zone.source == SOURCE_CACHE else 0;
    constructor = PyObject_GetAttrString(receiver, "_unpickle");
    if not constructor {
        return NULL;
    }
    result = Py_BuildValue("O(OB)", constructor, zone.key, i32(from_cache));
    jacpy_release(constructor);
    return result;
}

def zoneinfo_ZoneInfo__unpickle_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject], from_cache: u8
) -> ptr[PyObject] {
    if from_cache != 0 {
        return zoneinfo_ZoneInfo_impl(type, key);
    }
    state = state_by_class(cls);
    if state is None {
        return NULL;
    }
    return zoneinfo_new_instance(state, type, key);
}

# __init_subclass__: every subclass gets its own weak cache.
def zoneinfo_init_subclass(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    weak_cache = new_weak_cache();
    if not weak_cache {
        return NULL;
    }
    status = PyObject_SetAttrString(cls, "_weak_cache", weak_cache);
    jacpy_release(weak_cache);
    if status < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

# load_timedelta(): a timedelta of `seconds`, shared through the module's
# cache, since zones reuse a small set of offsets.
def:priv load_timedelta(state: ZoneInfoModuleState, seconds: i64) -> ptr[PyObject] {
    pyoffset = PyLong_FromLong(seconds);
    if not pyoffset {
        return NULL;
    }
    result = NULL;
    if PyDict_GetItemRef(state.timedelta_cache, pyoffset, &mut result) == 0 {
        api = state.datetime_api.view(1);
        created = api[0].Delta_FromDelta(
            i32(0), i32.wrap(seconds), i32(0), i32(1), api[0].DeltaType
        );
        if created {
            PyDict_SetDefaultRef(state.timedelta_cache, pyoffset, created, &mut result);
            jacpy_release(created);
        }
    }
    jacpy_release(pyoffset);
    return result;
}

# build_ttinfo(); None with the exception set on failure.
def:priv build_ttinfo(
    state: ZoneInfoModuleState, utcoffset: i64, dstoffset: i64, tzname: ptr[PyObject]
) -> (TTInfo | None) {
    tti = TTInfo(utcoff_seconds=utcoffset);
    tti.utcoff = load_timedelta(state, utcoffset);
    if not tti.utcoff {
        return None;
    }
    tti.dstoff = load_timedelta(state, dstoffset);
    if not tti.dstoff {
        return None;
    }
    tti.tzname = Py_NewRef(tzname);
    return tti;
}

# ttinfo_eq(): 1 when equal, 0 when not, -1 with the exception set.
def:priv ttinfo_eq(first: TTInfo, second: TTInfo) -> i32 {
    result = PyObject_RichCompareBool(first.utcoff, second.utcoff, PY_EQ);
    if result < 1 {
        return result;
    }
    result = PyObject_RichCompareBool(first.dstoff, second.dstoff, PY_EQ);
    if result < 1 {
        return result;
    }
    return PyObject_RichCompareBool(first.tzname, second.tzname, PY_EQ);
}


# load_data(): fill `zone` from the file object through
# zoneinfo._common.load_data(); False with the exception set on failure.
def:priv load_data(
    state: ZoneInfoModuleState, zone: ZoneInfoState, file_obj: ptr[PyObject]
) -> bool {
    data_tuple = PyObject_CallMethod(state.common_mod, "load_data", "O", file_obj);
    if not data_tuple {
        return False;
    }
    ok = fill_zone(state, zone, data_tuple);
    jacpy_release(data_tuple);
    return ok;
}

def:priv fill_zone(
    state: ZoneInfoModuleState, zone: ZoneInfoState, data_tuple: ptr[PyObject]
) -> bool {
    if Py_TYPE(data_tuple) != addressof(PyTuple_Type) {
        PyErr_Format(PyExc_TypeError, "Invalid data result type: %R", data_tuple);
        return False;
    }
    # Unpack the data tuple.
    trans_idx_list = PyTuple_GetItem(data_tuple, 0);
    if not trans_idx_list {
        return False;
    }
    trans_utc = PyTuple_GetItem(data_tuple, 1);
    if not trans_utc {
        return False;
    }
    utcoff_list = PyTuple_GetItem(data_tuple, 2);
    if not utcoff_list {
        return False;
    }
    isdst_list = PyTuple_GetItem(data_tuple, 3);
    if not isdst_list {
        return False;
    }
    abbr = PyTuple_GetItem(data_tuple, 4);
    if not abbr {
        return False;
    }
    tz_str = PyTuple_GetItem(data_tuple, 5);
    if not tz_str {
        return False;
    }
    num_transitions = PyTuple_Size(trans_utc);
    if num_transitions < 0 {
        return False;
    }
    num_ttinfos = PyTuple_Size(utcoff_list);
    if num_ttinfos < 0 {
        return False;
    }
    # The transition times and the ttinfo index of each.
    trans_list_utc: list[i64] = [];
    trans_idx: list[int] = [];
    for i in range(int(num_transitions)) {
        num = PyTuple_GetItem(trans_utc, i64(i));
        if not num {
            return False;
        }
        utc = PyLong_AsLongLong(num);
        if utc == -1 and PyErr_Occurred() {
            return False;
        }
        trans_list_utc.append(utc);
        num = PyTuple_GetItem(trans_idx_list, i64(i));
        if not num {
            return False;
        }
        cur_trans_idx = PyLong_AsSsize_t(num);
        if cur_trans_idx == -1 {
            return False;
        }
        if cur_trans_idx < 0 or cur_trans_idx >= num_ttinfos {
            object_error(
                PyExc_ValueError,
                f"Invalid transition index found while reading TZif: {cur_trans_idx}"
            );
            return False;
        }
        trans_idx.append(int(cur_trans_idx));
    }
    # The UTC offsets and isdst flags, one per ttinfo.
    utcoff: list[i64] = [];
    isdst: list[bool] = [];
    for i in range(int(num_ttinfos)) {
        num = PyTuple_GetItem(utcoff_list, i64(i));
        if not num {
            return False;
        }
        offset = PyLong_AsLong(num);
        if offset == -1 and PyErr_Occurred() {
            return False;
        }
        utcoff.append(offset);
        num = PyTuple_GetItem(isdst_list, i64(i));
        if not num {
            return False;
        }
        flag = PyObject_IsTrue(num);
        if flag == -1 {
            return False;
        }
        isdst.append(flag != 0);
    }
    # Derive dstoff and the wall-time transitions.
    dstoff: list[i64] = [0 for _ in range(int(num_ttinfos))];
    utcoff_to_dstoff(trans_idx, utcoff, dstoff, isdst);
    wall = ts_to_local(trans_idx, trans_list_utc, utcoff);
    # The ttinfos from utcoff, dstoff and abbr.
    ttinfos: list[TTInfo] = [];
    for i in range(int(num_ttinfos)) {
        tzname = PyTuple_GetItem(abbr, i64(i));
        if not tzname {
            return False;
        }
        tti = build_ttinfo(state, utcoff[i], dstoff[i], tzname);
        if tti is None {
            return False;
        }
        ttinfos.append(tti);
    }
    zone.trans_list_utc = trans_list_utc;
    zone.trans_list_wall = wall;
    zone.ttinfos = ttinfos;
    # The ttinfo each transition switches to.
    zone.trans_ttinfos = [ttinfos[index] for index in trans_idx];
    # ttinfo_before is the first non-DST ttinfo; with only DST ttinfos it is
    # the first one, and with none there is none.
    zone.ttinfo_before = None;
    for i in range(int(num_ttinfos)) {
        if not isdst[i] {
            zone.ttinfo_before = ttinfos[i];
            break;
        }
    }
    if zone.ttinfo_before is None and num_ttinfos > 0 {
        zone.ttinfo_before = ttinfos[0];
    }
    if tz_str != Py_None and PyObject_IsTrue(tz_str) != 0 {
        rule = parse_tz_str(state, tz_str);
        if rule is None {
            return False;
        }
        zone.tzrule_after = rule;
    } else {
        if num_ttinfos == 0 {
            object_error(PyExc_ValueError, "No time zone information found.");
            return False;
        }
        idx = int(num_ttinfos) - 1 if num_transitions == 0 else trans_idx[-1];
        tti = ttinfos[idx];
        rule = build_tzrule(state, tti.tzname, NULL, tti.utcoff_seconds, 0, None, None);
        if rule is None {
            return False;
        }
        # The STD-only rule mimics the last ttinfo, which may be a DST one:
        # then its dstoff is the rule's too.
        truth = PyObject_IsTrue(tti.dstoff);
        if truth != 0 {
            previous = rule.std.dstoff;
            rule.std.dstoff = Py_NewRef(tti.dstoff);
            jacpy_release(previous);
        }
        zone.tzrule_after = rule;
    }
    # A "fixed offset" zone answers utcoffset(), dst() and tzname() the same
    # for every datetime. This assumes that a rule that is not STD-only has
    # transitions that occur, that distinct ttinfos have distinct offsets and
    # that every ttinfo is used; zones violating those should not be used
    # with datetime.time, the only thing this affects.
    if num_ttinfos > 1 or not zone.tzrule_after.std_only {
        zone.fixed_offset = False;
    } elif num_ttinfos == 0 {
        zone.fixed_offset = True;
    } else {
        constant_offset = ttinfo_eq(ttinfos[0], zone.tzrule_after.std);
        if constant_offset < 0 {
            return False;
        }
        zone.fixed_offset = constant_offset != 0;
    }
    return True;
}

# The start and end of a TZ rule's DST in the given year, in local standard
# time.
obj RuleTransitions {
    has start: i64 = 0,
        end: i64 = 0;
}

def:priv tzrule_transitions(rule: TZRule, year: i64) -> RuleTransitions {
    transitions = RuleTransitions();
    start = rule.start;
    end = rule.end;
    if start is not None and end is not None {
        transitions.start = start.year_to_timestamp(year);
        transitions.end = end.year_to_timestamp(year);
    }
    return transitions;
}

# find_tzrule_ttinfo(): the ttinfo of a rule at a local timestamp. The year
# is the datetime's, which the callers already have.
def:priv find_tzrule_ttinfo(rule: TZRule, ts: i64, fold: i64, year: i64) -> TTInfo {
    if rule.std_only {
        return rule.std;
    }
    transitions = tzrule_transitions(rule, year);
    start = transitions.start;
    end = transitions.end;
    # With fold = 0 the period with the smaller offset runs from the end of
    # the gap to the end of the fold; with fold = 1 from the start of the gap
    # to the start of the fold. So the boundaries depend on fold XOR whether
    # DST is positive.
    if fold == (1 if rule.dst_diff >= 0 else 0) {
        end -= rule.dst_diff;
    } else {
        start += rule.dst_diff;
    }
    isdst = (ts >= start and ts < end) if start < end else (ts < end or ts >= start);
    return rule.dst if isdst else rule.std;
}

# The ttinfo of a rule at a UTC timestamp and whether it is in a fold.
obj RuleMatch {
    has tti: TTInfo,
        fold: bool = False;
}

def:priv find_tzrule_ttinfo_fromutc(rule: TZRule, ts: i64, year: i64) -> RuleMatch {
    if rule.std_only {
        return RuleMatch(tti=rule.std, fold=False);
    }
    transitions = tzrule_transitions(rule, year);
    start = transitions.start - rule.std.utcoff_seconds;
    end = transitions.end - rule.dst.utcoff_seconds;
    isdst = (ts >= start and ts < end) if start < end else (ts < end or ts >= start);
    # For positive DST the ambiguous period is one dst_diff after the end of
    # DST; for negative DST, one dst_diff before its start.
    ambig_start = end;
    ambig_end = end + rule.dst_diff;
    if rule.dst_diff <= 0 {
        ambig_start = start;
        ambig_end = start - rule.dst_diff;
    }
    return RuleMatch(
        tti=rule.dst if isdst else rule.std, fold=ts >= ambig_start and ts < ambig_end
    );
}

# A read position in the NUL-terminated buffer of a TZ string's bytes
# object; parsing stops at the first NUL, as C's does.
obj TZCursor {
    has text: ptr[u8],
        pos: int = 0;

    def at(offset: int = 0) -> int {
        return int((self.text + (self.pos + offset)).view(1)[0]);
    }
}

def:priv is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}

def:priv is_alpha(c: int) -> bool {
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122);
}

# parse_tz_str(): a TZ string in the POSIX format
#
#   std offset[dst[offset],start[/time],end[/time]]
#
# where std and dst are 3 or more characters with no leading colon, digits,
# commas or signs, and each offset is [+|-]hh[:mm[:ss]]
# (IEEE Std 1003.1-2018 section 8.3).
def:priv parse_tz_str(
    state: ZoneInfoModuleState, tz_str_obj: ptr[PyObject]
) -> (TZRule | None) {
    tz_str = PyBytes_AsString(tz_str_obj);
    if tz_str.is_null() {
        return None;
    }
    cursor = TZCursor(text=tz_str);
    # Offsets start at an invalid value (more than 24 hours).
    std_offset: i64 = 1 << 20;
    dst_offset: i64 = 1 << 20;
    start: (TransitionRule | None) = None;
    end: (TransitionRule | None) = None;
    # The `std` abbreviation.
    std_abbr = parse_abbr(cursor);
    if not std_abbr {
        if not PyErr_Occurred() {
            PyErr_Format(PyExc_ValueError, "Invalid STD format in %R", tz_str_obj);
        }
        return None;
    }
    dst_abbr = NULL;
    try {
        # The STD offset, which is required.
        parsed = parse_tz_delta(cursor);
        if parsed is None {
            PyErr_Format(PyExc_ValueError, "Invalid STD offset in %R", tz_str_obj);
            return None;
        }
        std_offset = parsed;
        # Without anything after it there is no DST; otherwise the DST
        # abbreviation and the start and end dates and times follow.
        if cursor.at() != 0 {
            dst_abbr = parse_abbr(cursor);
            if not dst_abbr {
                if not PyErr_Occurred() {
                    PyErr_Format(
                        PyExc_ValueError, "Invalid DST format in %R", tz_str_obj
                    );
                }
                return None;
            }
            if cursor.at() == 44 {
                # If no offset follows dst, the alternative time is one hour
                # ahead of standard time.
                dst_offset = std_offset + 3600;
            } else {
                parsed = parse_tz_delta(cursor);
                if parsed is None {
                    PyErr_Format(
                        PyExc_ValueError, "Invalid DST offset in %R", tz_str_obj
                    );
                    return None;
                }
                dst_offset = parsed;
            }
            rules: list[TransitionRule] = [];
            for _ in range(2) {
                if cursor.at() != 44 {
                    PyErr_Format(
                        PyExc_ValueError,
                        "Missing transition rules in TZ string: %R",
                        tz_str_obj
                    );
                    return None;
                }
                cursor.pos += 1;
                rule = parse_transition_rule(cursor);
                if rule is None {
                    if PyErr_ExceptionMatches(PyExc_MemoryError) == 0 {
                        PyErr_Format(
                            PyExc_ValueError,
                            "Malformed transition rule in TZ string: %R",
                            tz_str_obj
                        );
                    }
                    return None;
                }
                rules.append(rule);
            }
            start = rules[0];
            end = rules[1];
            if cursor.at() != 0 {
                PyErr_Format(
                    PyExc_ValueError,
                    "Extraneous characters at end of TZ string: %R",
                    tz_str_obj
                );
                return None;
            }
        }
        return build_tzrule(
            state, std_abbr, dst_abbr, std_offset, dst_offset, start, end
        );
    } finally {
        jacpy_release(std_abbr);
        jacpy_release(dst_abbr);
    }
}

# parse_digits(): between `least` and `most` (at most 3) decimal digits.
def:priv parse_digits(cursor: TZCursor, least: int, most: int) -> (int | None) {
    value = 0;
    for i in range(most) {
        c = cursor.at();
        if not is_digit(c) {
            return None if i < least else value;
        }
        value = value * 10 + (c - 48);
        cursor.pos += 1;
    }
    return value;
}

# parse_abbr(): an STD or DST abbreviation, alphabetic, or in the quoted
# form <...> alphanumeric, '+' and '-'; NULL on failure.
def:priv parse_abbr(cursor: TZCursor) -> ptr[PyObject] {
    start = cursor.pos;
    offset = 0;
    str_start = 0;
    str_end = 0;
    if cursor.at() == 60 {
        offset = 1;
        str_start = offset;
        while True {
            c = cursor.at(offset);
            if c == 62 {
                break;
            }
            # In the quoted form every character is alphanumeric, '+' or '-'.
            if not is_alpha(c) and not is_digit(c) and c != 43 and c != 45 {
                return NULL;
            }
            offset += 1;
        }
        str_end = offset;
        offset += 1;
    } else {
        # In the unquoted form every character is alphabetic.
        while is_alpha(cursor.at(offset)) {
            offset += 1;
        }
        str_end = offset;
        if str_end == str_start {
            return NULL;
        }
    }
    # PyUnicode_FromStringAndSize() of the characters: a strict UTF-8 decode.
    abbr = PyUnicode_DecodeUTF8Stateful(
        cursor.text + (start + str_start), i64(str_end - str_start), ptr[u8](), None
    );
    if not abbr {
        return NULL;
    }
    cursor.pos = start + offset;
    return abbr;
}

# parse_tz_delta(): a UTC offset, hh[:mm[:ss]] with any number of hour
# digits. POSIX limits the hours to 24; RFC 8536 section 3.3.1 lets the
# transition times range from -167 to 167. A negative offset is east of the
# Prime Meridian, a *positive* UTC offset.
def:priv parse_tz_delta(cursor: TZCursor) -> (i64 | None) {
    time = parse_transition_time(cursor, 0);
    if time is None {
        return None;
    }
    if time.hour > 24 or time.hour < -24 {
        return None;
    }
    return -(time.hour * 3600 + time.minute * 60 + time.second);
}

obj TransitionTime {
    has hour: i64 = 0,
        minute: i64 = 0,
        second: i64 = 0;
}

# parse_transition_time(): h[h[h]][:mm[:ss]], optionally signed as RFC 8536
# allows. `hour` is the default before parsing (the minute and second
# default to 0).
def:priv parse_transition_time(cursor: TZCursor, hour: i64) -> (TransitionTime | None) {
    start = cursor.pos;
    sign = 1;
    if cursor.at() == 45 or cursor.at() == 43 {
        if cursor.at() == 45 {
            sign = -1;
        }
        cursor.pos += 1;
    }
    result = TransitionTime(hour=hour);
    # The hour is 1 to 3 digits.
    hours = parse_digits(cursor, 1, 3);
    if hours is None {
        cursor.pos = start;
        return None;
    }
    result.hour = i64(hours * sign);
    # Minutes and seconds are always ":dd".
    if cursor.at() == 58 {
        cursor.pos += 1;
        minutes = parse_digits(cursor, 2, 2);
        if minutes is None {
            cursor.pos = start;
            return None;
        }
        result.minute = i64(minutes * sign);
        if cursor.at() == 58 {
            cursor.pos += 1;
            seconds = parse_digits(cursor, 2, 2);
            if seconds is None {
                cursor.pos = start;
                return None;
            }
            result.second = i64(seconds * sign);
        }
    }
    return result;
}

# parse_transition_rule(): one date[/time] of the rule, Jn (Julian day, no
# leap days), n (0-based day of the year, leap days counted) or Mm.n.d; the
# time defaults to 02:00.
def:priv parse_transition_rule(cursor: TZCursor) -> (TransitionRule | None) {
    start = cursor.pos;
    if cursor.at() == 77 {
        cursor.pos += 1;
        month = parse_digits(cursor, 1, 2);
        if month is None or cursor.at() != 46 {
            cursor.pos = start;
            return None;
        }
        cursor.pos += 1;
        week = parse_digits(cursor, 1, 1);
        if week is None or cursor.at() != 46 {
            cursor.pos = start;
            return None;
        }
        cursor.pos += 1;
        day = parse_digits(cursor, 1, 1);
        if day is None {
            cursor.pos = start;
            return None;
        }
        time = TransitionTime(hour=2);
        if cursor.at() == 47 {
            cursor.pos += 1;
            parsed = parse_transition_time(cursor, 2);
            if parsed is None {
                cursor.pos = start;
                return None;
            }
            time = parsed;
        }
        rule = calendarrule_new(
            i64(month), i64(week), i64(day), time.hour, time.minute, time.second
        );
        if rule is None {
            cursor.pos = start;
        }
        return rule;
    }
    julian = False;
    if cursor.at() == 74 {
        julian = True;
        cursor.pos += 1;
    }
    day = parse_digits(cursor, 1, 3);
    if day is None {
        cursor.pos = start;
        return None;
    }
    time = TransitionTime(hour=2);
    if cursor.at() == 47 {
        cursor.pos += 1;
        parsed = parse_transition_time(cursor, 2);
        if parsed is None {
            cursor.pos = start;
            return None;
        }
        time = parsed;
    }
    rule = dayrule_new(julian, i64(day), time.hour, time.minute, time.second);
    if rule is None {
        cursor.pos = start;
    }
    return rule;
}

# calendarrule_new(), with the POSIX bounds of an Mm.n.d rule: day d
# (0 <= d <= 6, 0 = Sunday) of week n (1 <= n <= 5, 5 = the last) of month m
# (1 <= m <= 12).
def:priv calendarrule_new(
    month: i64, week: i64, day: i64, hour: i64, minute: i64, second: i64
) -> (TransitionRule | None) {
    if month < 1 or month > 12 {
        object_error(PyExc_ValueError, "Month must be in [1, 12]");
        return None;
    }
    if week < 1 or week > 5 {
        object_error(PyExc_ValueError, "Week must be in [1, 5]");
        return None;
    }
    if day < 0 or day > 6 {
        object_error(PyExc_ValueError, "Day must be in [0, 6]");
        return None;
    }
    if hour < -167 or hour > 167 {
        object_error(PyExc_ValueError, "Hour must be in [0, 167]");
        return None;
    }
    return CalendarRule(
        month=month, week=week, day=day, hour=hour, minute=minute, second=second
    );
}

# dayrule_new(): Julian days are 1 <= n <= 365 and 0-based days
# 0 <= n <= 365.
def:priv dayrule_new(
    julian: bool, day: i64, hour: i64, minute: i64, second: i64
) -> (TransitionRule | None) {
    least = 1 if julian else 0;
    if day < least or day > 365 {
        object_error(PyExc_ValueError, f"day must be in [{least}, 365], not: {day}");
        return None;
    }
    if hour < -167 or hour > 167 {
        object_error(PyExc_ValueError, "Hour must be in [0, 167]");
        return None;
    }
    return DayRule(julian=julian, day=day, hour=hour, minute=minute, second=second);
}

# build_tzrule(): without a DST abbreviation the rule is STD-only and
# dst_offset, start and end are unused.
def:priv build_tzrule(
    state: ZoneInfoModuleState,
    std_abbr: ptr[PyObject],
    dst_abbr: ptr[PyObject],
    std_offset: i64,
    dst_offset: i64,
    start: (TransitionRule | None),
    end: (TransitionRule | None)
) -> (TZRule | None) {
    rule = TZRule(start=start, end=end);
    std = build_ttinfo(state, std_offset, 0, std_abbr);
    if std is None {
        return None;
    }
    rule.std = std;
    if dst_abbr {
        rule.dst_diff = dst_offset - std_offset;
        dst = build_ttinfo(state, dst_offset, rule.dst_diff, dst_abbr);
        if dst is None {
            return None;
        }
        rule.dst = dst;
    } else {
        rule.std_only = True;
    }
    return rule;
}

# utcoff_to_dstoff(): the DST offset of each ttinfo. A TZif ttinfo has only
# its UTC offset, abbreviation and isdst flag, so the amount of DST is
# inferred from the transitions around it; one that cannot be inferred is
# taken as one hour rather than zero, so bool(dt.dst()) matches isdst.
def:priv utcoff_to_dstoff(
    trans_idx: list[int], utcoffs: list[i64], dstoffs: list[i64], isdsts: list[bool]
) {
    num_transitions = len(trans_idx);
    num_ttinfos = len(utcoffs);
    dst_count = num_ttinfos;
    dst_found = 0;
    for i in range(1, num_transitions) {
        if dst_count == dst_found {
            break;
        }
        idx = trans_idx[i];
        comp_idx = trans_idx[i - 1];
        # Only DST offsets that have not been assigned already.
        if not isdsts[idx] or dstoffs[idx] != 0 {
            continue;
        }
        dstoff: i64 = 0;
        utcoff = utcoffs[idx];
        if not isdsts[comp_idx] {
            dstoff = utcoff - utcoffs[comp_idx];
        }
        if dstoff == 0 and idx < num_ttinfos - 1 and i + 1 < num_transitions {
            comp_idx = trans_idx[i + 1];
            # With the following transition also DST, this one is left for
            # a later transition to assign.
            if isdsts[comp_idx] {
                continue;
            }
            dstoff = utcoff - utcoffs[comp_idx];
        }
        if dstoff != 0 {
            dst_found += 1;
            dstoffs[idx] = dstoff;
        }
    }
    if dst_found < dst_count {
        for idx in range(num_ttinfos) {
            if isdsts[idx] and dstoffs[idx] == 0 {
                dstoffs[idx] = 3600;
            }
        }
    }
}

# ts_to_local(): each transition in local wall time, the nominal seconds
# since 1970-01-01T00:00:00 local time (not datetime.timestamp()). A
# transition is ambiguous in local time, so there are two lists: element 0
# for fold=0 and element 1 for fold=1.
def:priv ts_to_local(
    trans_idx: list[int], trans_utc: list[i64], utcoff: list[i64]
) -> list[list[i64]] {
    num_transitions = len(trans_utc);
    if num_transitions == 0 {
        return [[], []];
    }
    fold_0 = list(trans_utc);
    fold_1 = list(trans_utc);
    offset_0 = utcoff[0];
    offset_1 = utcoff[0];
    if len(utcoff) > 1 {
        offset_1 = utcoff[trans_idx[0]];
        if offset_1 > offset_0 {
            (offset_0, offset_1) = (offset_1, offset_0);
        }
    }
    fold_0[0] += offset_0;
    fold_1[0] += offset_1;
    for i in range(1, num_transitions) {
        offset_0 = utcoff[trans_idx[i - 1]];
        offset_1 = utcoff[trans_idx[i]];
        if offset_1 > offset_0 {
            (offset_0, offset_1) = (offset_1, offset_0);
        }
        fold_0[i] += offset_0;
        fold_1[i] += offset_1;
    }
    return [fold_0, fold_1];
}

# _bisect(): bisect_right over a sorted list.
def:priv bisect_right(value: i64, values: list[i64]) -> int {
    lo = 0;
    hi = len(values);
    while lo < hi {
        middle = (lo + hi) // 2;
        if values[middle] > value {
            hi = middle;
        } else {
            lo = middle + 1;
        }
    }
    return hi;
}

# find_ttinfo(): the ttinfo in effect at a local datetime. datetime.time
# passes None, which only means something for a fixed-offset zone.
def:priv find_ttinfo(
    state: ZoneInfoModuleState, zone: ZoneInfoState, dt: ptr[PyObject]
) -> (TTInfo | None) {
    if dt == Py_None {
        return zone.tzrule_after.std if zone.fixed_offset else state.no_ttinfo;
    }
    ts = local_timestamp(state, dt);
    if ts is None {
        return None;
    }
    fold = datetime_fold(dt);
    local_transitions = zone.trans_list_wall[1 if fold != 0 else 0];
    num_trans = len(zone.trans_list_utc);
    if num_trans and ts < local_transitions[0] {
        return before_ttinfo(zone);
    } elif not num_trans or ts > local_transitions[num_trans - 1] {
        return find_tzrule_ttinfo(zone.tzrule_after, ts, fold, datetime_year(dt));
    }
    return zone.trans_ttinfos[bisect_right(ts, local_transitions) - 1];
}

def:priv is_leap_year(year: i64) -> bool {
    ayear = year & 0xFFFFFFFF;
    return ayear % 4 == 0 and (ayear % 100 != 0 or ayear % 400 == 0);
}

# ymd_to_ord(): the proleptic Gregorian ordinal of a date.
def:priv ymd_to_ord(y: i64, m: i64, d: i64) -> i64 {
    y -= 1;
    days_before_year = y * 365 + y // 4 - y // 100 + y // 400;
    yearday = DAYS_BEFORE_MONTH[m];
    if m > 2 and is_leap_year(y + 1) {
        yearday += 1;
    }
    return days_before_year + yearday + d;
}

# A datetime attribute read with PyLong_AsLong() into a C int; None on
# failure, and, as in C, for -1.
def:priv int_attribute(dt: ptr[PyObject], name: str) -> (i64 | None) {
    num = PyObject_GetAttrString(dt, name);
    if not num {
        return None;
    }
    value = i64(i32.wrap(PyLong_AsLong(num)));
    jacpy_release(num);
    return None if value == -1 else value;
}

# get_local_timestamp(): the seconds since 1970-01-01 in local time, in the
# units of the wall-time transitions; None with the exception set.
def:priv local_timestamp(
    state: ZoneInfoModuleState, dt: ptr[PyObject]
) -> (i64 | None) {
    hour: i64 = 0;
    minute: i64 = 0;
    second: i64 = 0;
    ordinal: i64 = 0;
    if is_datetime_exact(state, dt) {
        fields = ptr[PyDateTime_DateTime](dt).view(1);
        ordinal = ymd_to_ord(
            datetime_year(dt), i64(fields[0].data_2), i64(fields[0].data_3)
        );
        hour = i64(fields[0].data_4);
        minute = i64(fields[0].data_5);
        second = i64(fields[0].data_6);
    } else {
        num = PyObject_CallMethod(dt, "toordinal", "");
        if not num {
            return None;
        }
        value = i64(i32.wrap(PyLong_AsLong(num)));
        jacpy_release(num);
        if value == -1 and PyErr_Occurred() {
            return None;
        }
        ordinal = value;
        parsed = int_attribute(dt, "hour");
        if parsed is None {
            return None;
        }
        hour = parsed;
        parsed = int_attribute(dt, "minute");
        if parsed is None {
            return None;
        }
        minute = parsed;
        parsed = int_attribute(dt, "second");
        if parsed is None {
            return None;
        }
        second = parsed;
    }
    return (ordinal - EPOCHORDINAL) * 86400 + (hour * 3600 + minute * 60 + second);
}

# The strong cache: an LRU list of the base class's most recently used zones,
# at most ZONEINFO_STRONG_CACHE_MAX_SIZE of them, most recent first. Only the
# base class has one. A failed node allocation is silent, as the cache never
# propagates errors.

# find_in_strong_cache(): the node whose key equals `key`; None when there is
# none or the comparison raised.
def:priv find_in_strong_cache(
    state: ZoneInfoModuleState, key: ptr[PyObject]
) -> (StrongCacheNode | None) {
    for cached in list(state.strong_cache) {
        rv = PyObject_RichCompareBool(key, cached.key, PY_EQ);
        if rv < 0 {
            return None;
        }
        if rv != 0 {
            return cached;
        }
    }
    return None;
}

def:priv remove_from_strong_cache(state: ZoneInfoModuleState, cached: StrongCacheNode) {
    for i in range(len(state.strong_cache)) {
        if state.strong_cache[i] is cached {
            state.strong_cache.pop(i);
            return;
        }
    }
}

def:priv move_strong_cache_node_to_front(
    state: ZoneInfoModuleState, cached: StrongCacheNode
) {
    if state.strong_cache and state.strong_cache[0] is cached {
        return;
    }
    remove_from_strong_cache(state, cached);
    state.strong_cache.insert(0, cached);
}

# eject_from_strong_cache(): drop `key` from the base class's strong cache;
# False with the exception set when a comparison raised.
def:priv eject_from_strong_cache(
    state: ZoneInfoModuleState, type: ptr[PyObject], key: ptr[PyObject]
) -> bool {
    if type != state.zoneinfo_type {
        return True;
    }
    cached = find_in_strong_cache(state, key);
    if cached is not None {
        remove_from_strong_cache(state, cached);
    } elif PyErr_Occurred() {
        return False;
    }
    return True;
}

# zone_from_strong_cache(): a new reference to the cached zone for `key`,
# moved to the front; NULL on a miss.
def:priv zone_from_strong_cache(
    state: ZoneInfoModuleState, type: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    if type != state.zoneinfo_type {
        return NULL;
    }
    cached = find_in_strong_cache(state, key);
    if cached is None {
        return NULL;
    }
    move_strong_cache_node_to_front(state, cached);
    return Py_NewRef(cached.zone);
}

# update_strong_cache(): after a miss, the new zone goes to the front and
# entries past the maximum size are dropped.
def:priv update_strong_cache(
    state: ZoneInfoModuleState,
    type: ptr[PyObject],
    key: ptr[PyObject],
    zone: ptr[PyObject]
) {
    if type != state.zoneinfo_type {
        return;
    }
    cached = StrongCacheNode(key=Py_NewRef(key), zone=Py_NewRef(zone));
    move_strong_cache_node_to_front(state, cached);
    if len(state.strong_cache) > ZONEINFO_STRONG_CACHE_MAX_SIZE {
        state.strong_cache = state.strong_cache[:ZONEINFO_STRONG_CACHE_MAX_SIZE];
    }
}

def:priv clear_strong_cache(state: ZoneInfoModuleState, type: ptr[PyObject]) {
    if type != state.zoneinfo_type {
        return;
    }
    state.strong_cache = [];
}

def:priv new_weak_cache -> ptr[PyObject] {
    weak_value_dictionary = PyImport_ImportModuleAttrString(
        "weakref", "WeakValueDictionary"
    );
    if not weak_value_dictionary {
        return NULL;
    }
    weak_cache = PyObject_CallNoArgs(weak_value_dictionary);
    jacpy_release(weak_value_dictionary);
    return weak_cache;
}

# PyDateTime_IMPORT: the datetime C API capsule, NULL with the exception set.
def datetime_import -> ptr[PyDateTime_CAPI] {
    return ptr[PyDateTime_CAPI](PyCapsule_Import(ptr[u8]("datetime.datetime_CAPI"), 0));
}

# The rest of zoneinfomodule_exec() once the ZoneInfo type exists: the
# imports, NO_TTINFO and the caches. False with the exception set.
def populate_module_state(state: ZoneInfoModuleState) -> bool {
    state.tzpath_find_tzfile = PyImport_ImportModuleAttrString(
        "zoneinfo._tzpath", "find_tzfile"
    );
    if not state.tzpath_find_tzfile {
        return False;
    }
    state.io_open = PyImport_ImportModuleAttrString("io", "open");
    if not state.io_open {
        return False;
    }
    state.common_mod = PyImport_ImportModule("zoneinfo._common");
    if not state.common_mod {
        return False;
    }
    if not state.no_ttinfo.utcoff {
        state.no_ttinfo.utcoff = Py_NewRef(Py_None);
        state.no_ttinfo.dstoff = Py_NewRef(Py_None);
        state.no_ttinfo.tzname = Py_NewRef(Py_None);
    }
    state.timedelta_cache = PyDict_New();
    if not state.timedelta_cache {
        return False;
    }
    state.weak_cache = new_weak_cache();
    return bool(state.weak_cache);
}
