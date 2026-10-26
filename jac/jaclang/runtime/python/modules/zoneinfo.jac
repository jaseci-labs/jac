import from c {
    def PyModule_GetState(m: ptr[PyObject]) -> ptr;  def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], mod_def: ptr[PyModuleDef]
    ) -> ptr[PyObject];  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  obj ZoneInfoStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0;
    }  def jacpy_stack_address(slots: &mut ZoneInfoStack) -> int;  obj _ttinfo {
        has utcoff: ptr[PyObject],
            dstoff: ptr[PyObject],
            tzname: ptr[PyObject],
            utcoff_seconds: i64;
    }  obj TransitionRuleType {
        has year_to_timestamp: Callable[[ptr[TransitionRuleType], i32], i64];
    }  obj _tzrule {
        has std: _ttinfo,
            dst: _ttinfo,
            dst_diff: i32,
            start: ptr[TransitionRuleType],
            end: ptr[TransitionRuleType],
            std_only: u8;
    }  obj PyZoneInfo_ZoneInfo {
        has ob_base: _object,
            key: ptr[PyObject],
            file_repr: ptr[PyObject],
            weakreflist: ptr[PyObject],
            num_transitions: u64,
            num_ttinfos: u64,
            trans_list_utc: ptr[i64],
            trans_list_wall_0: ptr[i64],
            trans_list_wall_1: ptr[i64],
            trans_ttinfos: ptr[ptr[_ttinfo]],
            ttinfo_before: ptr[_ttinfo],
            tzrule_after: _tzrule,
            _ttinfos: ptr[_ttinfo],
            fixed_offset: u8,
            source: u8;
    }  obj CalendarRule {
        has base: TransitionRuleType,
            month: u8,
            week: u8,
            day: u8,
            hour: i16,
            minute: i8,
            second: i8;
    }  obj DayRule {
        has base: TransitionRuleType,
            julian: u8,
            day: u16,
            hour: i16,
            minute: i8,
            second: i8;
    }  obj StrongCacheNode {
        has next: ptr[StrongCacheNode],
            prev: ptr[StrongCacheNode],
            key: ptr[PyObject],
            zone: ptr[PyObject];
    }  obj zoneinfo_state {
        has ZoneInfoType: ptr[PyTypeObject],
            io_open: ptr[PyObject],
            _tzpath_find_tzfile: ptr[PyObject],
            _common_mod: ptr[PyObject],
            TIMEDELTA_CACHE: ptr[PyObject],
            ZONEINFO_WEAK_CACHE: ptr[PyObject],
            ZONEINFO_STRONG_CACHE: ptr[StrongCacheNode],
            NO_TTINFO: _ttinfo;
    }  obj LoadScratch {
        has utcoff: ptr[i64],
            dstoff: ptr[i64],
            trans_idx: ptr[i64],
            isdst: ptr[u8],
            ttinfos_allocated: i64;
    }  obj ZoneInfoModuleDef {
        has m_base: PyModuleDef_Base,
            m_name: ptr[u8],
            m_doc: ptr[u8],
            m_size: i64,
            m_methods: ptr[PyMethodDef],
            m_slots: ptr[PyModuleDef_Slot],
            m_traverse: ptr,
            m_clear: ptr,
            m_free: ptr;
    }  glob:priv PyDateTimeAPI: ptr[PyDateTime_CAPI] = ptr[PyDateTime_CAPI](),
         DAYS_IN_MONTH: list[i32] = [
             i32(-1),
             i32(31),
             i32(28),
             i32(31),
             i32(30),
             i32(31),
             i32(30),
             i32(31),
             i32(31),
             i32(30),
             i32(31),
             i32(30),
             i32(31)
         ],
         DAYS_BEFORE_MONTH: list[i32] = [
             i32(-1),
             i32(0),
             i32(31),
             i32(59),
             i32(90),
             i32(120),
             i32(151),
             i32(181),
             i32(212),
             i32(243),
             i32(273),
             i32(304),
             i32(334)
         ];
}

glob EPOCHORDINAL: Final[i64] = 719163,
     SOURCE_NOCACHE: Final[u8] = 0,
     SOURCE_CACHE: Final[u8] = 1,
     SOURCE_FILE: Final[u8] = 2,
     ZONEINFO_STRONG_CACHE_MAX_SIZE: Final[i64] = 8,
     TTINFO_SIZE: Final[i64] = 32,
     TZRULE_SIZE: Final[i64] = 96,
     TZRULE_DST: Final[i64] = 32,
     CALENDARRULE_SIZE: Final[i64] = 16,
     DAYRULE_SIZE: Final[i64] = 16,
     STRONGCACHENODE_SIZE: Final[i64] = 32,
     ZONEINFO_SIZE: Final[i64] = 208,
     ZONEINFO_KEY: Final[i64] = 16,
     ZONEINFO_WEAKREFLIST: Final[i64] = 32,
     ZONEINFO_TRANS_LIST_WALL: Final[i64] = 64,
     ZONEINFO_TZRULE_AFTER: Final[i64] = 96,
     ZONEINFO_STATE_SIZE: Final[i64] = 88,
     ZONEINFO_STATE_STRONG_CACHE: Final[i64] = 48,
     ZONEINFO_STATE_NO_TTINFO: Final[i64] = 56,
     ZONEINFO_METHODS_SLOT: Final[i64] = 0;

glob ZoneInfo_token = ClassToken();

def zoneinfo_record(op: ptr[PyObject]) -> ptr[PyZoneInfo_ZoneInfo];

def trans_list_wall_of(self_: ptr[PyZoneInfo_ZoneInfo]) -> ptr[ptr[i64]];

def tzrule_after_of(self_: ptr[PyZoneInfo_ZoneInfo]) -> ptr[_tzrule];

def tzrule_std(rule: ptr[_tzrule]) -> ptr[_ttinfo];

def tzrule_dst(rule: ptr[_tzrule]) -> ptr[_ttinfo];

def no_ttinfo_of(state: ptr[zoneinfo_state]) -> ptr[_ttinfo];

def strong_cache_root(state: ptr[zoneinfo_state]) -> ptr[ptr[StrongCacheNode]];

def datetime_record(dt: ptr[PyObject]) -> ptr[PyDateTime_DateTime];

def datetime_get_year(dt: ptr[PyObject]) -> i32;

def datetime_get_tzinfo(dt: ptr[PyObject]) -> ptr[PyObject];

def py_isdigit(c: u8) -> bool;

def py_isalpha(c: u8) -> bool;

def zoneinfo_get_state(mod: ptr[PyObject]) -> ptr[zoneinfo_state];

def zoneinfo_get_state_by_cls(cls: ptr[PyObject]) -> ptr[zoneinfo_state];

def zoneinfo_get_state_by_self(self_: ptr[PyObject]) -> ptr[zoneinfo_state];

def zoneinfo_new_instance(
    state: ptr[zoneinfo_state], type: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject];

def get_weak_cache(state: ptr[zoneinfo_state], type: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_ZoneInfo_impl(type: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def zoneinfo_clear(op: ptr[PyObject]) -> i32;

def zoneinfo_dealloc(obj_self: ptr[PyObject]);

def zoneinfo_ZoneInfo_from_file_impl(
    type: ptr[PyObject], cls: ptr[PyObject], file_obj: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_ZoneInfo_no_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_ZoneInfo_clear_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], only_keys: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_ZoneInfo_utcoffset_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_ZoneInfo_dst_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_ZoneInfo_tzname_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject];

def zoneinfo_fromutc(obj_self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_repr(op: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_str(op: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_reduce(obj_self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def zoneinfo_ZoneInfo__unpickle_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject], from_cache: u8
) -> ptr[PyObject];

def load_timedelta(state: ptr[zoneinfo_state], seconds: i64) -> ptr[PyObject];

def build_ttinfo(
    state: ptr[zoneinfo_state],
    utcoffset: i64,
    dstoffset: i64,
    tzname: ptr[PyObject],
    out: ptr[_ttinfo]
) -> i32;

def xdecref_ttinfo(ttinfo: ptr[_ttinfo]);

def ttinfo_eq(tti0: ptr[_ttinfo], tti1: ptr[_ttinfo]) -> i32;

def load_data(
    state: ptr[zoneinfo_state], self_: ptr[PyZoneInfo_ZoneInfo], file_obj: ptr[PyObject]
) -> i32;

def load_data_error(self_: ptr[PyZoneInfo_ZoneInfo], ttinfos_allocated: i64);

def load_data_tuple(
    state: ptr[zoneinfo_state],
    self_: ptr[PyZoneInfo_ZoneInfo],
    data_tuple: ptr[PyObject],
    scratch: ptr[LoadScratch]
) -> i32;

import from c {
    def calendarrule_year_to_timestamp(
        base_self: ptr[TransitionRuleType], year: i32
    ) -> i64 {
        rule = ptr[CalendarRule](base_self).view(1);
        month = i32(rule[0].month);

        first_day = (ymd_to_ord(year, month, 1) + 6) % 7;
        days_in_month = (addressof(DAYS_IN_MONTH) + i64(month)).view(1)[0];
        if month == 2 and is_leap_year(year) {
            days_in_month += 1;
        }

        month_day = (i32(rule[0].day) - (first_day + 1)) % 7;
        if month_day < 0 {
            month_day += 7;
        }
        month_day += 1;

        month_day += (i32(rule[0].week) - 1) * 7;

        if month_day > days_in_month {
            month_day -= 7;
        }

        ordinal = i64(ymd_to_ord(year, month, month_day)) - EPOCHORDINAL;
        return ordinal * 86400
            + i64(rule[0].hour) * 3600
            + i64(rule[0].minute) * 60
            + i64(rule[0].second);
    }  def calendarrule_new(
        month: i32,
        week: i32,
        day: i32,
        hour: i32,
        minute: i32,
        second: i32,
        out: ptr[CalendarRule]
    ) -> i32 {
        if month < 1 or month > 12 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Month must be in [1, 12]"));
            return -1;
        }

        if week < 1 or week > 5 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Week must be in [1, 5]"));
            return -1;
        }

        if day < 0 or day > 6 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Day must be in [0, 6]"));
            return -1;
        }

        if hour < -167 or hour > 167 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("Hour must be in [0, 167]"));
            return -1;
        }

        ptr[TransitionRuleType](out).view(1)[0].year_to_timestamp = calendarrule_year_to_timestamp;
        o = out.view(1);
        o[0].month = u8.wrap(month);
        o[0].week = u8.wrap(week);
        o[0].day = u8.wrap(day);
        o[0].hour = i16.wrap(hour);
        o[0].minute = i8.wrap(minute);
        o[0].second = i8.wrap(second);
        return 0;
    }  def dayrule_year_to_timestamp(
        base_self: ptr[TransitionRuleType], year: i32
    ) -> i64 {
        rule = ptr[DayRule](base_self).view(1);

        days_before_year = i64(ymd_to_ord(year, 1, 1)) - EPOCHORDINAL - 1;

        day = i64(rule[0].day);
        if rule[0].julian != 0 and day >= 59 and is_leap_year(year) {
            day += 1;
        }

        return (days_before_year + day) * 86400
            + i64(rule[0].hour) * 3600
            + i64(rule[0].minute) * 60
            + i64(rule[0].second);
    }
}

def dayrule_new(
    julian: i32, day: i32, hour: i32, minute: i32, second: i32, out: ptr[DayRule]
) -> i32;

def tzrule_transitions(rule: ptr[_tzrule], year: i32) -> tuple[i64, i64];

def find_tzrule_ttinfo(
    rule: ptr[_tzrule], ts: i64, fold: u8, year: i32
) -> ptr[_ttinfo];

def find_tzrule_ttinfo_fromutc(
    rule: ptr[_tzrule], ts: i64, year: i32
) -> tuple[ptr[_ttinfo], u8];

def parse_tz_str_error(
    std_abbr: ptr[PyObject],
    dst_abbr: ptr[PyObject],
    start: ptr[TransitionRuleType],
    end: ptr[TransitionRuleType]
) -> i32;

def parse_tz_str(
    state: ptr[zoneinfo_state], tz_str_obj: ptr[PyObject], out: ptr[_tzrule]
) -> i32;

def parse_digits(p: ptr[u8], least: i32, most: i32) -> tuple[i32, ptr[u8], i32];

def parse_abbr(p: ptr[u8]) -> tuple[i32, ptr[u8], ptr[PyObject]];

def parse_tz_delta(p: ptr[u8], total_seconds: i64) -> tuple[i32, ptr[u8], i64];

def parse_transition_rule(p: ptr[u8]) -> tuple[i32, ptr[u8], ptr[TransitionRuleType]];

def parse_transition_time(
    p: ptr[u8], hour: i32, minute: i32, second: i32
) -> tuple[i32, ptr[u8], i32, i32, i32];

def build_tzrule(
    state: ptr[zoneinfo_state],
    std_abbr: ptr[PyObject],
    dst_abbr: ptr[PyObject],
    std_offset: i64,
    dst_offset: i64,
    start: ptr[TransitionRuleType],
    end: ptr[TransitionRuleType],
    out: ptr[_tzrule]
) -> i32;

def free_tzrule(tzrule: ptr[_tzrule]);

def utcoff_to_dstoff(
    trans_idx: ptr[i64],
    utcoffs: ptr[i64],
    dstoffs: ptr[i64],
    isdsts: ptr[u8],
    num_transitions: i64,
    num_ttinfos: i64
);

def ts_to_local(
    trans_idx: ptr[i64],
    trans_utc: ptr[i64],
    utcoff: ptr[i64],
    trans_local: ptr[ptr[i64]],
    num_ttinfos: i64,
    num_transitions: i64
) -> i32;

def _bisect(value: i64, arr: ptr[i64], size: i64) -> i64;

def find_ttinfo(
    state: ptr[zoneinfo_state], self_: ptr[PyZoneInfo_ZoneInfo], dt: ptr[PyObject]
) -> ptr[_ttinfo];

def is_leap_year(year: i32) -> bool;

def ymd_to_ord(y: i32, m: i32, d: i32) -> i32;

def get_local_timestamp(dt: ptr[PyObject]) -> tuple[i32, i64];

def strong_cache_node_new(
    key: ptr[PyObject], zone: ptr[PyObject]
) -> ptr[StrongCacheNode];

import from c {
    def strong_cache_node_free(cache_node: ptr[StrongCacheNode]) {
        n = cache_node.view(1);
        object_xdecref(n[0].key);
        object_xdecref(n[0].zone);

        PyMem_Free(cache_node);
    }  def strong_cache_free(top: ptr[StrongCacheNode]) {
        cache_node = top;
        while cache_node {
            next_node = cache_node.view(1)[0].next;
            strong_cache_node_free(cache_node);

            cache_node = next_node;
        }
    }  def clear_strong_cache(state: ptr[zoneinfo_state], type: ptr[PyTypeObject]) {
        s = state.view(1);
        if type != s[0].ZoneInfoType {
            return;
        }

        strong_cache_free(s[0].ZONEINFO_STRONG_CACHE);
        s[0].ZONEINFO_STRONG_CACHE = ptr[StrongCacheNode]();
    }
}

def remove_from_strong_cache(
    state: ptr[zoneinfo_state], cache_node: ptr[StrongCacheNode]
);

def find_in_strong_cache(
    top: ptr[StrongCacheNode], key: ptr[PyObject]
) -> ptr[StrongCacheNode];

def eject_from_strong_cache(
    state: ptr[zoneinfo_state], type: ptr[PyTypeObject], key: ptr[PyObject]
) -> i32;

def move_strong_cache_node_to_front(
    state: ptr[zoneinfo_state],
    top: ptr[ptr[StrongCacheNode]],
    cache_node: ptr[StrongCacheNode]
);

def zone_from_strong_cache(
    state: ptr[zoneinfo_state], type: ptr[PyTypeObject], key: ptr[PyObject]
) -> ptr[PyObject];

def update_strong_cache(
    state: ptr[zoneinfo_state],
    type: ptr[PyTypeObject],
    key: ptr[PyObject],
    zone: ptr[PyObject]
);

def new_weak_cache -> ptr[PyObject];

def initialize_caches(state: ptr[zoneinfo_state]) -> i32;

def zoneinfo_init_subclass(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv zoneinfo_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("key"),
                 type_=Py_T_OBJECT_EX,
                 offset=ZONEINFO_KEY,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=ZONEINFO_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         zoneinfo_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(zoneinfo_repr)),
             PyType_Slot(slot=Py_tp_str, pfunc=ptr(zoneinfo_str)),
             PyType_Slot(slot=Py_tp_getattro, pfunc=ptr(PyObject_GenericGetAttr)),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(zoneinfo_members))),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(zoneinfo_ZoneInfo_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(zoneinfo_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(zoneinfo_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(zoneinfo_clear)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob:priv zoneinfo_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("zoneinfo.ZoneInfo"),
             basicsize=i32(ZONEINFO_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(zoneinfo_slots)
         ); glob:priv zoneinfo_module_methods: list[PyMethodDef] = [
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         zoneinfomodule_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(zoneinfomodule_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob zoneinfomodule: ZoneInfoModuleDef = ZoneInfoModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_zoneinfo"),
             m_doc=ptr[u8]("C implementation of the zoneinfo module"),
             m_size=ZONEINFO_STATE_SIZE,
             m_methods=addressof(zoneinfo_module_methods),
             m_slots=addressof(zoneinfomodule_slots),
             m_traverse=ptr(module_traverse),
             m_clear=ptr(module_clear),
             m_free=ptr(module_free)
         );
}

def install_zoneinfo_methods -> bool;

def module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def module_clear(mod: ptr[PyObject]) -> i32;

def module_free(mod: ptr);

def zoneinfomodule_exec(m: ptr[PyObject]) -> i32;

impl zoneinfo_record(op: ptr[PyObject]) -> ptr[PyZoneInfo_ZoneInfo] {
    return ptr[PyZoneInfo_ZoneInfo](op);
}

impl trans_list_wall_of(self_: ptr[PyZoneInfo_ZoneInfo]) -> ptr[ptr[i64]] {
    return ptr[ptr[i64]](ptr[u8](self_) + ZONEINFO_TRANS_LIST_WALL);
}

impl tzrule_after_of(self_: ptr[PyZoneInfo_ZoneInfo]) -> ptr[_tzrule] {
    return ptr[_tzrule](ptr[u8](self_) + ZONEINFO_TZRULE_AFTER);
}

impl tzrule_std(rule: ptr[_tzrule]) -> ptr[_ttinfo] {
    return ptr[_ttinfo](rule);
}

impl tzrule_dst(rule: ptr[_tzrule]) -> ptr[_ttinfo] {
    return ptr[_ttinfo](ptr[u8](rule) + TZRULE_DST);
}

impl no_ttinfo_of(state: ptr[zoneinfo_state]) -> ptr[_ttinfo] {
    return ptr[_ttinfo](ptr[u8](state) + ZONEINFO_STATE_NO_TTINFO);
}

impl strong_cache_root(state: ptr[zoneinfo_state]) -> ptr[ptr[StrongCacheNode]] {
    return ptr[ptr[StrongCacheNode]](ptr[u8](state) + ZONEINFO_STATE_STRONG_CACHE);
}

impl datetime_record(dt: ptr[PyObject]) -> ptr[PyDateTime_DateTime] {
    return ptr[PyDateTime_DateTime](dt);
}

impl datetime_get_year(dt: ptr[PyObject]) -> i32 {
    d = datetime_record(dt).view(1);
    return (i32(d[0].data) << 8) | i32(d[0].data_1);
}

impl datetime_get_tzinfo(dt: ptr[PyObject]) -> ptr[PyObject] {
    d = datetime_record(dt).view(1);
    if d[0].hastzinfo != 0 {
        return d[0].tzinfo;
    }
    return Py_None;
}

impl py_isdigit(c: u8) -> bool {
    return c >= 48 and c <= 57;
}

impl py_isalpha(c: u8) -> bool {
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122);
}

impl zoneinfo_get_state(mod: ptr[PyObject]) -> ptr[zoneinfo_state] {
    return ptr[zoneinfo_state](PyModule_GetState(mod));
}

impl zoneinfo_get_state_by_cls(cls: ptr[PyObject]) -> ptr[zoneinfo_state] {
    module = ptr[PyHeapTypeObject](cls).view(1)[0].ht_module;
    return ptr[zoneinfo_state](ptr[PyModuleObject](module).view(1)[0].md_state);
}

impl zoneinfo_get_state_by_self(self_: ptr[PyObject]) -> ptr[zoneinfo_state] {
    mod = PyType_GetModuleByDef(
        ptr[PyTypeObject](self_), ptr[PyModuleDef](addressof(zoneinfomodule))
    );
    return zoneinfo_get_state(mod);
}

impl zoneinfo_new_instance(
    state: ptr[zoneinfo_state], type: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    s = state.view(1);
    file_obj = NULL;
    file_path = PyObject_CallFunctionObjArgs(s[0]._tzpath_find_tzfile, key, NULL);
    if not file_path {
        return NULL;
    } elif file_path == Py_None {
        meth = s[0]._common_mod;
        file_obj = PyObject_CallMethod(meth, "load_tzdata", "O", key);
        if not file_obj {
            object_decref(file_path);
            return NULL;
        }
    }

    tp = ptr[PyTypeObject](type);
    self_ = tp.view(1)[0].tp_alloc(tp, 0);
    ok = True;
    if not self_ {
        ok = False;
    }

    if ok and not file_obj {
        func = s[0].io_open;
        file_obj = PyObject_CallFunction(func, "Os", file_path, ptr[u8]("rb"));
        if not file_obj {
            ok = False;
        }
    }

    self_zinfo = zoneinfo_record(self_);
    if ok and load_data(state, self_zinfo, file_obj) != 0 {
        ok = False;
    }

    if ok {
        rv = PyObject_CallMethod(file_obj, "close", "");
        old_file = file_obj;
        file_obj = NULL;
        object_decref(old_file);
        if not rv {
            ok = False;
        } else {
            object_decref(rv);
            self_zinfo.view(1)[0].key = object_new_ref(key);
        }
    }

    if not ok and self_ {
        failed = self_;
        self_ = NULL;
        object_decref(failed);
    }
    if file_obj {
        exc = PyErr_GetRaisedException();
        tmp = PyObject_CallMethod(file_obj, "close", "");
        _PyErr_ChainExceptions1(exc);
        if not tmp and self_ {
            failed = self_;
            self_ = NULL;
            object_decref(failed);
        }
        object_xdecref(tmp);
        object_decref(file_obj);
    }
    object_decref(file_path);
    return self_;
}

impl get_weak_cache(state: ptr[zoneinfo_state], type: ptr[PyObject]) -> ptr[PyObject] {
    s = state.view(1);
    if ptr[PyTypeObject](type) == s[0].ZoneInfoType {
        object_incref(s[0].ZONEINFO_WEAK_CACHE);
        return s[0].ZONEINFO_WEAK_CACHE;
    }
    return PyObject_GetAttrString(type, ptr[u8]("_weak_cache"));
}

impl zoneinfo_ZoneInfo_impl(type: ptr[PyObject], key: ptr[PyObject]) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_self(type);
    tp = ptr[PyTypeObject](type);
    instance = zone_from_strong_cache(state, tp, key);
    if instance or PyErr_Occurred() {
        return instance;
    }

    weak_cache = get_weak_cache(state, type);
    if not weak_cache {
        return NULL;
    }
    instance = PyObject_CallMethod(weak_cache, "get", "O", key, Py_None);
    if not instance {
        object_decref(weak_cache);
        return NULL;
    }

    if instance == Py_None {
        object_decref(instance);
        tmp = zoneinfo_new_instance(state, type, key);
        if not tmp {
            object_decref(weak_cache);
            return NULL;
        }

        zoneinfo_record(tmp).view(1)[0].source = SOURCE_CACHE;
        instance = PyObject_CallMethod(weak_cache, "setdefault", "OO", key, tmp);
        object_decref(tmp);
        if not instance {
            object_decref(weak_cache);
            return NULL;
        }
    }

    if not object_type_check(instance, tp) {
        PyErr_Format(
            PyExc_RuntimeError,
            ptr[u8]("Unexpected instance of %T in %s weak cache for key %R"),
            instance,
            _PyType_Name(type),
            key
        );
        object_decref(instance);
        object_decref(weak_cache);
        return NULL;
    }

    update_strong_cache(state, tp, key, instance);
    object_decref(weak_cache);
    return instance;
}

impl zoneinfo_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    vret = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(zoneinfo_record(op).view(1)[0].key, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl zoneinfo_clear(op: ptr[PyObject]) -> i32 {
    z = zoneinfo_record(op).view(1);
    key = z[0].key;
    if key {
        z[0].key = NULL;
        object_decref(key);
    }
    file_repr = z[0].file_repr;
    if file_repr {
        z[0].file_repr = NULL;
        object_decref(file_repr);
    }
    return 0;
}

impl zoneinfo_dealloc(obj_self: ptr[PyObject]) {
    self_ = zoneinfo_record(obj_self);
    z = self_.view(1);
    tp = object_type(obj_self);
    PyObject_GC_UnTrack(ptr(obj_self));

    if z[0].weakreflist {
        PyObject_ClearWeakRefs(obj_self);
    }

    if z[0].trans_list_utc {
        PyMem_Free(z[0].trans_list_utc);
    }

    wall = trans_list_wall_of(self_);
    i: i64 = 0;
    while i < 2 {
        if (wall + i).view(1)[0] {
            PyMem_Free((wall + i).view(1)[0]);
        }
        i += 1;
    }

    if z[0]._ttinfos {
        num_ttinfos = i64(z[0].num_ttinfos);
        i = 0;
        while i < num_ttinfos {
            xdecref_ttinfo(z[0]._ttinfos + i);
            i += 1;
        }
        PyMem_Free(z[0]._ttinfos);
    }

    if z[0].trans_ttinfos {
        PyMem_Free(z[0].trans_ttinfos);
    }

    free_tzrule(tzrule_after_of(self_));

    zoneinfo_clear(obj_self);
    tp.view(1)[0].tp_free(ptr(obj_self));
    object_decref(ptr[PyObject](tp));
}

impl zoneinfo_ZoneInfo_from_file_impl(
    type: ptr[PyObject], cls: ptr[PyObject], file_obj: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    tp = ptr[PyTypeObject](type);
    obj_self = tp.view(1)[0].tp_alloc(tp, 0);
    if not obj_self {
        return NULL;
    }
    self_ = zoneinfo_record(obj_self);

    file_repr = PyObject_Repr(file_obj);
    if not file_repr {
        object_decref(obj_self);
        return NULL;
    }

    state = zoneinfo_get_state_by_cls(cls);
    if load_data(state, self_, file_obj) != 0 {
        object_decref(file_repr);
        object_decref(obj_self);
        return NULL;
    }

    z = self_.view(1);
    z[0].source = SOURCE_FILE;
    z[0].file_repr = file_repr;
    z[0].key = object_new_ref(key);
    return obj_self;
}

impl zoneinfo_ZoneInfo_no_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_cls(cls);
    out = zoneinfo_new_instance(state, type, key);
    if out {
        zoneinfo_record(out).view(1)[0].source = SOURCE_NOCACHE;
    }
    return out;
}

impl zoneinfo_ZoneInfo_clear_cache_impl(
    type: ptr[PyObject], cls: ptr[PyObject], only_keys: ptr[PyObject]
) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_cls(cls);
    tp = ptr[PyTypeObject](type);
    weak_cache = get_weak_cache(state, type);
    if not weak_cache {
        return NULL;
    }

    if not only_keys or only_keys == Py_None {
        rv = PyObject_CallMethod(weak_cache, "clear", "");
        if rv {
            object_decref(rv);
        }

        clear_strong_cache(state, tp);
    } else {
        pop = PyUnicode_FromString(ptr[u8]("pop"));
        if not pop {
            object_decref(weak_cache);
            return NULL;
        }
        it = PyObject_GetIter(only_keys);
        if not it {
            object_decref(pop);
            object_decref(weak_cache);
            return NULL;
        }
        item = PyIter_Next(it);
        while item {
            if eject_from_strong_cache(state, tp, item) < 0 {
                object_decref(item);
                break;
            }

            tmp = PyObject_CallMethodObjArgs(weak_cache, pop, item, Py_None, NULL);

            object_decref(item);
            if not tmp {
                break;
            }
            object_decref(tmp);
            item = PyIter_Next(it);
        }
        object_decref(it);
        object_decref(pop);
    }

    object_decref(weak_cache);
    if PyErr_Occurred() {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl zoneinfo_ZoneInfo_utcoffset_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_cls(cls);
    tti = find_ttinfo(state, zoneinfo_record(receiver), dt);
    if not tti {
        return NULL;
    }
    return object_new_ref(tti.view(1)[0].utcoff);
}

impl zoneinfo_ZoneInfo_dst_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_cls(cls);
    tti = find_ttinfo(state, zoneinfo_record(receiver), dt);
    if not tti {
        return NULL;
    }
    return object_new_ref(tti.view(1)[0].dstoff);
}

impl zoneinfo_ZoneInfo_tzname_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], dt: ptr[PyObject]
) -> ptr[PyObject] {
    state = zoneinfo_get_state_by_cls(cls);
    tti = find_ttinfo(state, zoneinfo_record(receiver), dt);
    if not tti {
        return NULL;
    }
    return object_new_ref(tti.view(1)[0].tzname);
}

impl zoneinfo_fromutc(obj_self: ptr[PyObject], dt: ptr[PyObject]) -> ptr[PyObject] {
    api = PyDateTimeAPI.view(1);
    if not object_type_check(dt, api[0].DateTimeType) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("fromutc: argument must be a datetime")
        );
        return NULL;
    }
    if datetime_get_tzinfo(dt) != obj_self {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("fromutc: dt.tzinfo is not self"));
        return NULL;
    }

    self_ = zoneinfo_record(obj_self);
    z = self_.view(1);

    (status, timestamp) = get_local_timestamp(dt);
    if status != 0 {
        return NULL;
    }
    num_trans = i64(z[0].num_transitions);
    utc = z[0].trans_list_utc;

    tti = ptr[_ttinfo]();
    fold: u8 = 0;

    if num_trans >= 1 and timestamp < utc.view(1)[0] {
        tti = z[0].ttinfo_before;
    } elif num_trans == 0 or timestamp > (utc + (num_trans - 1)).view(1)[0] {
        (rule_tti, rule_fold) = find_tzrule_ttinfo_fromutc(
            tzrule_after_of(self_), timestamp, datetime_get_year(dt)
        );
        tti = rule_tti;
        fold = rule_fold;
        if num_trans != 0 {
            tti_prev = z[0].ttinfo_before;
            if num_trans != 1 {
                tti_prev = (z[0].trans_ttinfos + (num_trans - 2)).view(1)[0];
            }
            diff = wrapping_sub(
                tti_prev.view(1)[0].utcoff_seconds, tti.view(1)[0].utcoff_seconds
            );
            if diff > 0
                and timestamp
                    < wrapping_add((utc + (num_trans - 1)).view(1)[0], diff) {
                fold = 1;
            }
        }
    } else {
        idx = _bisect(timestamp, utc, num_trans);
        prev_tti = z[0].ttinfo_before;
        if idx >= 2 {
            prev_tti = (z[0].trans_ttinfos + (idx - 2)).view(1)[0];
            tti = (z[0].trans_ttinfos + (idx - 1)).view(1)[0];
        } else {
            tti = z[0].trans_ttinfos.view(1)[0];
        }
        shift = wrapping_sub(
            prev_tti.view(1)[0].utcoff_seconds, tti.view(1)[0].utcoff_seconds
        );
        if shift > wrapping_sub(timestamp, (utc + (idx - 1)).view(1)[0]) {
            fold = 1;
        }
    }

    tmp = PyNumber_Add(dt, tti.view(1)[0].utcoff);
    if not tmp {
        return NULL;
    }

    if fold != 0 {
        if object_type(tmp) == api[0].DateTimeType {
            datetime_record(tmp).view(1)[0].fold = 1;
            return tmp;
        }
        replace = PyObject_GetAttrString(tmp, ptr[u8]("replace"));
        object_decref(tmp);
        if not replace {
            return NULL;
        }
        args = PyTuple_New(0);
        if not args {
            object_decref(replace);
            return NULL;
        }
        kwargs = PyDict_New();
        if not kwargs {
            object_decref(replace);
            object_decref(args);
            return NULL;
        }

        result = NULL;
        if PyDict_SetItemString(kwargs, ptr[u8]("fold"), long_one()) == 0 {
            result = PyObject_Call(replace, args, kwargs);
        }

        object_decref(args);
        object_decref(kwargs);
        object_decref(replace);
        return result;
    }
    return tmp;
}

impl zoneinfo_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    z = zoneinfo_record(op).view(1);
    if z[0].key != Py_None {
        return PyUnicode_FromFormat("%T(key=%R)", op, z[0].key);
    }
    return PyUnicode_FromFormat("%T.from_file(%U)", op, z[0].file_repr);
}

impl zoneinfo_str(op: ptr[PyObject]) -> ptr[PyObject] {
    z = zoneinfo_record(op).view(1);
    if z[0].key != Py_None {
        return object_new_ref(z[0].key);
    }
    return zoneinfo_repr(op);
}

impl zoneinfo_reduce(obj_self: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    z = zoneinfo_record(obj_self).view(1);
    if z[0].source == SOURCE_FILE {
        pickle_error = PyImport_ImportModuleAttrString(
            ptr[u8]("pickle"), ptr[u8]("PicklingError")
        );
        if not pickle_error {
            return NULL;
        }

        PyErr_Format(
            pickle_error, ptr[u8]("Cannot pickle a ZoneInfo file from a file stream.")
        );
        object_decref(pickle_error);
        return NULL;
    }

    from_cache: i32 = 0;
    if z[0].source == SOURCE_CACHE {
        from_cache = 1;
    }
    constructor = PyObject_GetAttrString(obj_self, ptr[u8]("_unpickle"));

    if not constructor {
        return NULL;
    }

    rv = Py_BuildValue(ptr[u8]("O(OB)"), constructor, z[0].key, from_cache);
    object_decref(constructor);
    return rv;
}

impl zoneinfo_ZoneInfo__unpickle_impl(
    type: ptr[PyObject], cls: ptr[PyObject], key: ptr[PyObject], from_cache: u8
) -> ptr[PyObject] {
    if from_cache != 0 {
        return zoneinfo_ZoneInfo_impl(type, key);
    }
    state = zoneinfo_get_state_by_cls(cls);
    return zoneinfo_new_instance(state, type, key);
}

impl load_timedelta(state: ptr[zoneinfo_state], seconds: i64) -> ptr[PyObject] {
    rv = NULL;
    pyoffset = PyLong_FromLong(seconds);
    if not pyoffset {
        return NULL;
    }
    cache = state.view(1)[0].TIMEDELTA_CACHE;
    if PyDict_GetItemRef(cache, pyoffset, &mut rv) == 0 {
        api = PyDateTimeAPI.view(1);
        tmp = api[0].Delta_FromDelta(
            i32(0), i32.wrap(seconds), i32(0), i32(1), api[0].DeltaType
        );

        if tmp {
            PyDict_SetDefaultRef(cache, pyoffset, tmp, &mut rv);
            object_decref(tmp);
        }
    }

    object_decref(pyoffset);
    return rv;
}

impl build_ttinfo(
    state: ptr[zoneinfo_state],
    utcoffset: i64,
    dstoffset: i64,
    tzname: ptr[PyObject],
    out: ptr[_ttinfo]
) -> i32 {
    o = out.view(1);
    o[0].utcoff = NULL;
    o[0].dstoff = NULL;
    o[0].tzname = NULL;

    o[0].utcoff_seconds = utcoffset;
    o[0].utcoff = load_timedelta(state, utcoffset);
    if not o[0].utcoff {
        return -1;
    }

    o[0].dstoff = load_timedelta(state, dstoffset);
    if not o[0].dstoff {
        return -1;
    }

    o[0].tzname = object_new_ref(tzname);

    return 0;
}

impl xdecref_ttinfo(ttinfo: ptr[_ttinfo]) {
    if ttinfo {
        t = ttinfo.view(1);
        object_xdecref(t[0].utcoff);
        object_xdecref(t[0].dstoff);
        object_xdecref(t[0].tzname);
    }
}

impl ttinfo_eq(tti0: ptr[_ttinfo], tti1: ptr[_ttinfo]) -> i32 {
    a = tti0.view(1);
    b = tti1.view(1);
    rv = PyObject_RichCompareBool(a[0].utcoff, b[0].utcoff, Py_EQ);
    if rv < 1 {
        return rv;
    }
    rv = PyObject_RichCompareBool(a[0].dstoff, b[0].dstoff, Py_EQ);
    if rv < 1 {
        return rv;
    }
    return PyObject_RichCompareBool(a[0].tzname, b[0].tzname, Py_EQ);
}

impl load_data(
    state: ptr[zoneinfo_state], self_: ptr[PyZoneInfo_ZoneInfo], file_obj: ptr[PyObject]
) -> i32 {
    rv: i32 = 0;
    z = self_.view(1);
    wall = trans_list_wall_of(self_);

    z[0].trans_list_utc = ptr[i64]();
    wall.view(1)[0] = ptr[i64]();
    (wall + 1).view(1)[0] = ptr[i64]();
    z[0].trans_ttinfos = ptr[ptr[_ttinfo]]();
    z[0]._ttinfos = ptr[_ttinfo]();
    z[0].file_repr = NULL;

    stack: own ZoneInfoStack = ZoneInfoStack();
    scratch = ptr[LoadScratch](jacpy_stack_address(&mut stack));
    sc = scratch.view(1);

    data_tuple = PyObject_CallMethod(
        state.view(1)[0]._common_mod, "load_data", "O", file_obj
    );

    if not data_tuple or load_data_tuple(state, self_, data_tuple, scratch) != 0 {
        load_data_error(self_, sc[0].ttinfos_allocated);
        rv = -1;
    }

    object_xdecref(data_tuple);

    if sc[0].utcoff {
        PyMem_Free(sc[0].utcoff);
    }

    if sc[0].dstoff {
        PyMem_Free(sc[0].dstoff);
    }

    if sc[0].isdst {
        PyMem_Free(sc[0].isdst);
    }

    if sc[0].trans_idx {
        PyMem_Free(sc[0].trans_idx);
    }

    return rv;
}

impl load_data_error(self_: ptr[PyZoneInfo_ZoneInfo], ttinfos_allocated: i64) {
    z = self_.view(1);
    if z[0].trans_list_utc {
        PyMem_Free(z[0].trans_list_utc);
        z[0].trans_list_utc = ptr[i64]();
    }

    wall = trans_list_wall_of(self_);
    i: i64 = 0;
    while i < 2 {
        if (wall + i).view(1)[0] {
            PyMem_Free((wall + i).view(1)[0]);
            (wall + i).view(1)[0] = ptr[i64]();
        }
        i += 1;
    }

    if z[0]._ttinfos {
        i = 0;
        while i < ttinfos_allocated {
            xdecref_ttinfo(z[0]._ttinfos + i);
            i += 1;
        }
        PyMem_Free(z[0]._ttinfos);
        z[0]._ttinfos = ptr[_ttinfo]();
    }

    if z[0].trans_ttinfos {
        PyMem_Free(z[0].trans_ttinfos);
        z[0].trans_ttinfos = ptr[ptr[_ttinfo]]();
    }
}

impl load_data_tuple(
    state: ptr[zoneinfo_state],
    self_: ptr[PyZoneInfo_ZoneInfo],
    data_tuple: ptr[PyObject],
    scratch: ptr[LoadScratch]
) -> i32 {
    z = self_.view(1);
    sc = scratch.view(1);

    if object_type(data_tuple) != addressof(PyTuple_Type) {
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("Invalid data result type: %R"), data_tuple
        );
        return -1;
    }

    trans_idx_list = PyTuple_GetItem(data_tuple, 0);
    if not trans_idx_list {
        return -1;
    }

    trans_utc = PyTuple_GetItem(data_tuple, 1);
    if not trans_utc {
        return -1;
    }

    utcoff_list = PyTuple_GetItem(data_tuple, 2);
    if not utcoff_list {
        return -1;
    }

    isdst_list = PyTuple_GetItem(data_tuple, 3);
    if not isdst_list {
        return -1;
    }

    abbr = PyTuple_GetItem(data_tuple, 4);
    if not abbr {
        return -1;
    }

    tz_str = PyTuple_GetItem(data_tuple, 5);
    if not tz_str {
        return -1;
    }

    num_transitions = PyTuple_Size(trans_utc);
    if num_transitions < 0 {
        return -1;
    }

    num_ttinfos = PyTuple_Size(utcoff_list);
    if num_ttinfos < 0 {
        return -1;
    }

    z[0].num_transitions = u64(num_transitions);
    z[0].num_ttinfos = u64(num_ttinfos);

    utc = ptr[i64](PyMem_Malloc(u64(num_transitions) * 8));
    z[0].trans_list_utc = utc;
    if not utc {
        PyErr_NoMemory();
        return -1;
    }
    trans_idx = ptr[i64](PyMem_Malloc(u64(num_transitions) * 8));
    sc[0].trans_idx = trans_idx;
    if not trans_idx {
        PyErr_NoMemory();
        return -1;
    }

    i: i64 = 0;
    while i < num_transitions {
        num = PyTuple_GetItem(trans_utc, i);
        if not num {
            return -1;
        }
        value = PyLong_AsLongLong(num);
        (utc + i).view(1)[0] = value;
        if value == -1 and PyErr_Occurred() {
            return -1;
        }

        num = PyTuple_GetItem(trans_idx_list, i);
        if not num {
            return -1;
        }

        cur_trans_idx = PyLong_AsSsize_t(num);
        if cur_trans_idx == -1 {
            return -1;
        }

        (trans_idx + i).view(1)[0] = cur_trans_idx;
        if cur_trans_idx < 0 or cur_trans_idx >= num_ttinfos {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("Invalid transition index found while reading TZif: %zd"),
                cur_trans_idx
            );

            return -1;
        }
        i += 1;
    }

    utcoff = ptr[i64](PyMem_Malloc(u64(num_ttinfos) * 8));
    sc[0].utcoff = utcoff;
    isdst = ptr[u8](PyMem_Malloc(u64(num_ttinfos)));
    sc[0].isdst = isdst;

    if not utcoff or not isdst {
        PyErr_NoMemory();
        return -1;
    }
    i = 0;
    while i < num_ttinfos {
        num = PyTuple_GetItem(utcoff_list, i);
        if not num {
            return -1;
        }

        offset = PyLong_AsLong(num);
        (utcoff + i).view(1)[0] = offset;
        if offset == -1 and PyErr_Occurred() {
            return -1;
        }

        num = PyTuple_GetItem(isdst_list, i);
        if not num {
            return -1;
        }

        isdst_with_error = PyObject_IsTrue(num);
        if isdst_with_error == -1 {
            return -1;
        }
        (isdst + i).view(1)[0] = u8.wrap(isdst_with_error);
        i += 1;
    }

    dstoff = ptr[i64](PyMem_Calloc(u64(num_ttinfos), 8));
    sc[0].dstoff = dstoff;
    if not dstoff {
        PyErr_NoMemory();
        return -1;
    }

    utcoff_to_dstoff(trans_idx, utcoff, dstoff, isdst, num_transitions, num_ttinfos);

    if ts_to_local(
        trans_idx, utc, utcoff, trans_list_wall_of(self_), num_ttinfos, num_transitions
    )
        != 0 {
        return -1;
    }

    ttinfos = ptr[_ttinfo](PyMem_Malloc(u64(num_ttinfos) * u64(TTINFO_SIZE)));
    z[0]._ttinfos = ttinfos;
    if not ttinfos {
        PyErr_NoMemory();
        return -1;
    }
    i = 0;
    while i < num_ttinfos {
        tzname = PyTuple_GetItem(abbr, i);
        if not tzname {
            return -1;
        }

        sc[0].ttinfos_allocated += 1;
        rc = build_ttinfo(
            state, (utcoff + i).view(1)[0], (dstoff + i).view(1)[0], tzname, ttinfos + i
        );
        if rc != 0 {
            return -1;
        }
        i += 1;
    }

    trans_ttinfos = ptr[ptr[_ttinfo]](PyMem_Calloc(u64(num_transitions), 8));
    z[0].trans_ttinfos = trans_ttinfos;
    if not trans_ttinfos {
        PyErr_NoMemory();
        return -1;
    }
    i = 0;
    while i < num_transitions {
        ttinfo_idx = (trans_idx + i).view(1)[0];
        (trans_ttinfos + i).view(1)[0] = ttinfos + ttinfo_idx;
        i += 1;
    }

    i = 0;
    while i < num_ttinfos {
        if (isdst + i).view(1)[0] == 0 {
            z[0].ttinfo_before = ttinfos + i;
            break;
        }
        i += 1;
    }

    if not z[0].ttinfo_before and num_ttinfos > 0 {
        z[0].ttinfo_before = ttinfos;
    }

    rule_after = tzrule_after_of(self_);
    if tz_str != Py_None and PyObject_IsTrue(tz_str) != 0 {
        if parse_tz_str(state, tz_str, rule_after) != 0 {
            return -1;
        }
    } else {
        if num_ttinfos == 0 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("No time zone information found."));
            return -1;
        }
        idx = num_ttinfos - 1;
        if num_transitions != 0 {
            idx = (trans_idx + (num_transitions - 1)).view(1)[0];
        }
        tti = ttinfos + idx;
        build_tzrule(
            state,
            tti.view(1)[0].tzname,
            NULL,
            tti.view(1)[0].utcoff_seconds,
            0,
            ptr[TransitionRuleType](),
            ptr[TransitionRuleType](),
            rule_after
        );
        if PyObject_IsTrue(tti.view(1)[0].dstoff) != 0 {
            tti_after = tzrule_std(rule_after).view(1);
            old_dstoff = tti_after[0].dstoff;
            tti_after[0].dstoff = object_new_ref(tti.view(1)[0].dstoff);
            object_xdecref(old_dstoff);
        }
    }

    if num_ttinfos > 1 or rule_after.view(1)[0].std_only == 0 {
        z[0].fixed_offset = 0;
    } elif num_ttinfos == 0 {
        z[0].fixed_offset = 1;
    } else {
        constant_offset = ttinfo_eq(ttinfos, tzrule_std(rule_after));
        if constant_offset < 0 {
            return -1;
        }
        z[0].fixed_offset = u8.wrap(constant_offset);
    }

    return 0;
}

impl dayrule_new(
    julian: i32, day: i32, hour: i32, minute: i32, second: i32, out: ptr[DayRule]
) -> i32 {
    if day < julian or day > 365 {
        PyErr_Format(
            PyExc_ValueError, ptr[u8]("day must be in [%d, 365], not: %d"), julian, day
        );
        return -1;
    }

    if hour < -167 or hour > 167 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("Hour must be in [0, 167]"));
        return -1;
    }

    ptr[TransitionRuleType](out).view(1)[0].year_to_timestamp = dayrule_year_to_timestamp;
    o = out.view(1);
    o[0].julian = u8.wrap(julian);
    o[0].day = u16.wrap(day);
    o[0].hour = i16.wrap(hour);
    o[0].minute = i8.wrap(minute);
    o[0].second = i8.wrap(second);

    return 0;
}

impl tzrule_transitions(rule: ptr[_tzrule], year: i32) -> tuple[i64, i64] {
    r = rule.view(1);
    start = r[0].start;
    end = r[0].end;
    return (
        start.view(1)[0].year_to_timestamp(start, year),
        end.view(1)[0].year_to_timestamp(end, year)
    );
}

impl find_tzrule_ttinfo(
    rule: ptr[_tzrule], ts: i64, fold: u8, year: i32
) -> ptr[_ttinfo] {
    r = rule.view(1);
    if r[0].std_only != 0 {
        return tzrule_std(rule);
    }

    (start, end) = tzrule_transitions(rule, year);

    dst_diff = i64(r[0].dst_diff);
    positive: u8 = 0;
    if r[0].dst_diff >= 0 {
        positive = 1;
    }
    if fold == positive {
        end = end - dst_diff;
    } else {
        start = start + dst_diff;
    }

    isdst = False;
    if start < end {
        isdst = ts >= start and ts < end;
    } else {
        isdst = ts < end or ts >= start;
    }

    if isdst {
        return tzrule_dst(rule);
    }
    return tzrule_std(rule);
}

impl find_tzrule_ttinfo_fromutc(
    rule: ptr[_tzrule], ts: i64, year: i32
) -> tuple[ptr[_ttinfo], u8] {
    r = rule.view(1);
    if r[0].std_only != 0 {
        return (tzrule_std(rule), u8(0));
    }

    (start, end) = tzrule_transitions(rule, year);
    start = start - r[0].std.utcoff_seconds;
    end = end - r[0].dst.utcoff_seconds;

    isdst = False;
    if start < end {
        isdst = ts >= start and ts < end;
    } else {
        isdst = ts < end or ts >= start;
    }

    dst_diff = i64(r[0].dst_diff);
    ambig_start: i64 = 0;
    ambig_end: i64 = 0;
    if dst_diff > 0 {
        ambig_start = end;
        ambig_end = end + dst_diff;
    } else {
        ambig_start = start;
        ambig_end = start - dst_diff;
    }

    fold: u8 = 0;
    if ts >= ambig_start and ts < ambig_end {
        fold = 1;
    }

    if isdst {
        return (tzrule_dst(rule), fold);
    }
    return (tzrule_std(rule), fold);
}

impl parse_tz_str_error(
    std_abbr: ptr[PyObject],
    dst_abbr: ptr[PyObject],
    start: ptr[TransitionRuleType],
    end: ptr[TransitionRuleType]
) -> i32 {
    object_xdecref(std_abbr);
    if dst_abbr and dst_abbr != Py_None {
        object_decref(dst_abbr);
    }

    if start {
        PyMem_Free(start);
    }

    if end {
        PyMem_Free(end);
    }

    return -1;
}

impl parse_tz_str(
    state: ptr[zoneinfo_state], tz_str_obj: ptr[PyObject], out: ptr[_tzrule]
) -> i32 {
    std_abbr = NULL;
    dst_abbr = NULL;
    start = ptr[TransitionRuleType]();
    end = ptr[TransitionRuleType]();
    std_offset: i64 = 1 << 20;
    dst_offset: i64 = 1 << 20;

    tz_str = PyBytes_AsString(tz_str_obj);
    if not tz_str {
        return -1;
    }
    p = tz_str;

    (rc, p, std_abbr) = parse_abbr(p);
    if rc != 0 {
        if not PyErr_Occurred() {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("Invalid STD format in %R"), tz_str_obj
            );
        }
        return parse_tz_str_error(std_abbr, dst_abbr, start, end);
    }

    (rc, p, std_offset) = parse_tz_delta(p, std_offset);
    if rc != 0 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("Invalid STD offset in %R"), tz_str_obj);
        return parse_tz_str_error(std_abbr, dst_abbr, start, end);
    }

    if p.view(1)[0] != 0 {
        (rc, p, dst_abbr) = parse_abbr(p);
        if rc != 0 {
            if not PyErr_Occurred() {
                PyErr_Format(
                    PyExc_ValueError, ptr[u8]("Invalid DST format in %R"), tz_str_obj
                );
            }
            return parse_tz_str_error(std_abbr, dst_abbr, start, end);
        }

        if p.view(1)[0] == 44 {
            dst_offset = std_offset + 3600;
        } else {
            (rc, p, dst_offset) = parse_tz_delta(p, dst_offset);
            if rc != 0 {
                PyErr_Format(
                    PyExc_ValueError, ptr[u8]("Invalid DST offset in %R"), tz_str_obj
                );
                return parse_tz_str_error(std_abbr, dst_abbr, start, end);
            }
        }

        i: i64 = 0;
        while i < 2 {
            if p.view(1)[0] != 44 {
                PyErr_Format(
                    PyExc_ValueError,
                    ptr[u8]("Missing transition rules in TZ string: %R"),
                    tz_str_obj
                );
                return parse_tz_str_error(std_abbr, dst_abbr, start, end);
            }
            p = p + 1;

            (rc, p, transition) = parse_transition_rule(p);
            if rc != 0 {
                if PyErr_ExceptionMatches(PyExc_MemoryError) == 0 {
                    PyErr_Format(
                        PyExc_ValueError,
                        ptr[u8]("Malformed transition rule in TZ string: %R"),
                        tz_str_obj
                    );
                }
                return parse_tz_str_error(std_abbr, dst_abbr, start, end);
            }
            if i == 0 {
                start = transition;
            } else {
                end = transition;
            }
            i += 1;
        }

        if p.view(1)[0] != 0 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("Extraneous characters at end of TZ string: %R"),
                tz_str_obj
            );
            return parse_tz_str_error(std_abbr, dst_abbr, start, end);
        }
    }

    build_tzrule(state, std_abbr, dst_abbr, std_offset, dst_offset, start, end, out);
    object_decref(std_abbr);
    object_xdecref(dst_abbr);

    return 0;
}

impl parse_digits(p: ptr[u8], least: i32, most: i32) -> tuple[i32, ptr[u8], i32] {
    value: i32 = 0;
    q = p;
    i: i32 = 0;
    while i < most {
        c = q.view(1)[0];
        if not py_isdigit(c) {
            if i < least {
                return (i32(-1), q, value);
            }
            return (i32(0), q, value);
        }
        value = value * 10 + (i32(c) - 48);
        i += 1;
        q = q + 1;
    }
    return (i32(0), q, value);
}

impl parse_abbr(p: ptr[u8]) -> tuple[i32, ptr[u8], ptr[PyObject]] {
    q = p;
    str_start = q;
    str_end = q;

    if q.view(1)[0] == 60 {
        q = q + 1;
        str_start = q;
        buff = q.view(1)[0];
        while buff != 62 {
            if not py_isalpha(buff)
                and not py_isdigit(buff)
                and buff != 43
                and buff != 45 {
                return (i32(-1), p, NULL);
            }
            q = q + 1;
            buff = q.view(1)[0];
        }
        str_end = q;
        q = q + 1;
    } else {
        str_start = q;
        while py_isalpha(q.view(1)[0]) {
            q = q + 1;
        }
        str_end = q;
        if str_end == str_start {
            return (i32(-1), p, NULL);
        }
    }

    abbr = PyUnicode_FromStringAndSize(str_start, i64(int(str_end) - int(str_start)));
    if not abbr {
        return (i32(-1), p, NULL);
    }

    return (i32(0), q, abbr);
}

impl parse_tz_delta(p: ptr[u8], total_seconds: i64) -> tuple[i32, ptr[u8], i64] {
    (rc, q, hours, minutes, seconds) = parse_transition_time(p, 0, 0, 0);
    if rc != 0 {
        return (i32(-1), p, total_seconds);
    }

    if hours > 24 or hours < -24 {
        return (i32(-1), p, total_seconds);
    }

    total = -((i64(hours) * 3600) + i64(minutes * 60) + i64(seconds));
    return (i32(0), q, total);
}

impl parse_transition_rule(p: ptr[u8]) -> tuple[i32, ptr[u8], ptr[TransitionRuleType]] {
    q = p;
    hour: i32 = 2;
    minute: i32 = 0;
    second: i32 = 0;
    failed = ptr[TransitionRuleType]();
    out = ptr[TransitionRuleType]();

    if q.view(1)[0] == 77 {
        q = q + 1;

        (rc, q, month) = parse_digits(q, 1, 2);
        if rc != 0 {
            return (i32(-1), p, failed);
        }
        c = q.view(1)[0];
        q = q + 1;
        if c != 46 {
            return (i32(-1), p, failed);
        }
        (rc, q, week) = parse_digits(q, 1, 1);
        if rc != 0 {
            return (i32(-1), p, failed);
        }
        c = q.view(1)[0];
        q = q + 1;
        if c != 46 {
            return (i32(-1), p, failed);
        }
        (rc, q, day) = parse_digits(q, 1, 1);
        if rc != 0 {
            return (i32(-1), p, failed);
        }

        if q.view(1)[0] == 47 {
            q = q + 1;
            (rc, q, hour, minute, second) = parse_transition_time(
                q, hour, minute, second
            );
            if rc != 0 {
                return (i32(-1), p, failed);
            }
        }

        calendar_rule = ptr[CalendarRule](PyMem_Calloc(1, u64(CALENDARRULE_SIZE)));
        if not calendar_rule {
            PyErr_NoMemory();
            return (i32(-1), p, failed);
        }

        if calendarrule_new(month, week, day, hour, minute, second, calendar_rule)
            != 0 {
            PyMem_Free(calendar_rule);
            return (i32(-1), p, failed);
        }

        out = ptr[TransitionRuleType](calendar_rule);
    } else {
        julian: i32 = 0;
        if q.view(1)[0] == 74 {
            julian = 1;
            q = q + 1;
        }
        (rc, q, day) = parse_digits(q, 1, 3);
        if rc != 0 {
            return (i32(-1), p, failed);
        }
        if q.view(1)[0] == 47 {
            q = q + 1;
            (rc, q, hour, minute, second) = parse_transition_time(
                q, hour, minute, second
            );
            if rc != 0 {
                return (i32(-1), p, failed);
            }
        }
        day_rule = ptr[DayRule](PyMem_Calloc(1, u64(DAYRULE_SIZE)));
        if not day_rule {
            PyErr_NoMemory();
            return (i32(-1), p, failed);
        }
        if dayrule_new(julian, day, hour, minute, second, day_rule) != 0 {
            PyMem_Free(day_rule);
            return (i32(-1), p, failed);
        }
        out = ptr[TransitionRuleType](day_rule);
    }

    return (i32(0), q, out);
}

impl parse_transition_time(
    p: ptr[u8], hour: i32, minute: i32, second: i32
) -> tuple[i32, ptr[u8], i32, i32, i32] {
    q = p;
    sign: i32 = 1;

    if q.view(1)[0] == 45 or q.view(1)[0] == 43 {
        if q.view(1)[0] == 45 {
            sign = -1;
        }
        q = q + 1;
    }

    (rc, q, hours) = parse_digits(q, 1, 3);
    if rc != 0 {
        return (i32(-1), p, hours, minute, second);
    }
    hours = hours * sign;
    minutes = minute;
    seconds = second;

    if q.view(1)[0] == 58 {
        q = q + 1;
        (rc, q, minutes) = parse_digits(q, 2, 2);
        if rc != 0 {
            return (i32(-1), p, hours, minutes, seconds);
        }
        minutes = minutes * sign;

        if q.view(1)[0] == 58 {
            q = q + 1;
            (rc, q, seconds) = parse_digits(q, 2, 2);
            if rc != 0 {
                return (i32(-1), p, hours, minutes, seconds);
            }
            seconds = seconds * sign;
        }
    }

    return (i32(0), q, hours, minutes, seconds);
}

impl build_tzrule(
    state: ptr[zoneinfo_state],
    std_abbr: ptr[PyObject],
    dst_abbr: ptr[PyObject],
    std_offset: i64,
    dst_offset: i64,
    start: ptr[TransitionRuleType],
    end: ptr[TransitionRuleType],
    out: ptr[_tzrule]
) -> i32 {
    stack: own ZoneInfoStack = ZoneInfoStack();
    rv = ptr[_tzrule](jacpy_stack_address(&mut stack));
    r = rv.view(1);

    r[0].start = start;
    r[0].end = end;

    if build_ttinfo(state, std_offset, 0, std_abbr, tzrule_std(rv)) != 0 {
        xdecref_ttinfo(tzrule_std(rv));
        xdecref_ttinfo(tzrule_dst(rv));
        return -1;
    }

    if dst_abbr {
        r[0].dst_diff = i32.wrap(dst_offset - std_offset);
        if build_ttinfo(state, dst_offset, i64(r[0].dst_diff), dst_abbr, tzrule_dst(rv))
            != 0 {
            xdecref_ttinfo(tzrule_std(rv));
            xdecref_ttinfo(tzrule_dst(rv));
            return -1;
        }
    } else {
        r[0].std_only = 1;
    }

    memcpy(out, rv, u64(TZRULE_SIZE));

    return 0;
}

impl free_tzrule(tzrule: ptr[_tzrule]) {
    t = tzrule.view(1);
    xdecref_ttinfo(tzrule_std(tzrule));
    if t[0].std_only == 0 {
        xdecref_ttinfo(tzrule_dst(tzrule));
    }

    if t[0].start {
        PyMem_Free(t[0].start);
    }

    if t[0].end {
        PyMem_Free(t[0].end);
    }
}

impl utcoff_to_dstoff(
    trans_idx: ptr[i64],
    utcoffs: ptr[i64],
    dstoffs: ptr[i64],
    isdsts: ptr[u8],
    num_transitions: i64,
    num_ttinfos: i64
) {
    dst_count: i64 = 0;
    dst_found: i64 = 0;
    i: i64 = 0;
    while i < num_ttinfos {
        dst_count += 1;
        i += 1;
    }

    i = 0;
    while i + 1 < num_transitions {
        i += 1;
        if dst_count == dst_found {
            break;
        }

        idx = (trans_idx + i).view(1)[0];
        comp_idx = (trans_idx + (i - 1)).view(1)[0];

        if (isdsts + idx).view(1)[0] == 0 or (dstoffs + idx).view(1)[0] != 0 {
            continue;
        }

        dstoff: i64 = 0;
        utcoff = (utcoffs + idx).view(1)[0];

        if (isdsts + comp_idx).view(1)[0] == 0 {
            dstoff = wrapping_sub(utcoff, (utcoffs + comp_idx).view(1)[0]);
        }

        if dstoff == 0 and idx < (num_ttinfos - 1) and i + 1 < num_transitions {
            comp_idx = (trans_idx + (i + 1)).view(1)[0];

            if (isdsts + comp_idx).view(1)[0] != 0 {
                continue;
            }

            dstoff = wrapping_sub(utcoff, (utcoffs + comp_idx).view(1)[0]);
        }

        if dstoff != 0 {
            dst_found += 1;
            (dstoffs + idx).view(1)[0] = dstoff;
        }
    }

    if dst_found < dst_count {
        idx2: i64 = 0;
        while idx2 < num_ttinfos {
            if (isdsts + idx2).view(1)[0] != 0 and (dstoffs + idx2).view(1)[0] == 0 {
                (dstoffs + idx2).view(1)[0] = 3600;
            }
            idx2 += 1;
        }
    }
}

impl ts_to_local(
    trans_idx: ptr[i64],
    trans_utc: ptr[i64],
    utcoff: ptr[i64],
    trans_local: ptr[ptr[i64]],
    num_ttinfos: i64,
    num_transitions: i64
) -> i32 {
    if num_transitions == 0 {
        return 0;
    }

    i: i64 = 0;
    while i < 2 {
        block = ptr[i64](PyMem_Malloc(u64(num_transitions) * 8));
        (trans_local + i).view(1)[0] = block;
        if not block {
            PyErr_NoMemory();
            return -1;
        }

        memcpy(block, trans_utc, u64(num_transitions) * 8);
        i += 1;
    }

    local_0 = trans_local.view(1)[0];
    local_1 = (trans_local + 1).view(1)[0];

    offset_0: i64 = 0;
    offset_1: i64 = 0;
    buff: i64 = 0;
    if num_ttinfos > 1 {
        offset_0 = utcoff.view(1)[0];
        offset_1 = (utcoff + trans_idx.view(1)[0]).view(1)[0];

        if offset_1 > offset_0 {
            buff = offset_0;
            offset_0 = offset_1;
            offset_1 = buff;
        }
    } else {
        offset_0 = utcoff.view(1)[0];
        offset_1 = utcoff.view(1)[0];
    }

    local_0.view(1)[0] = wrapping_add(local_0.view(1)[0], offset_0);
    local_1.view(1)[0] = wrapping_add(local_1.view(1)[0], offset_1);

    i = 1;
    while i < num_transitions {
        offset_0 = (utcoff + (trans_idx + (i - 1)).view(1)[0]).view(1)[0];
        offset_1 = (utcoff + (trans_idx + i).view(1)[0]).view(1)[0];

        if offset_1 > offset_0 {
            buff = offset_1;
            offset_1 = offset_0;
            offset_0 = buff;
        }

        (local_0 + i).view(1)[0] = wrapping_add((local_0 + i).view(1)[0], offset_0);
        (local_1 + i).view(1)[0] = wrapping_add((local_1 + i).view(1)[0], offset_1);
        i += 1;
    }

    return 0;
}

impl _bisect(value: i64, arr: ptr[i64], size: i64) -> i64 {
    lo: i64 = 0;
    hi = size;

    while lo < hi {
        m = (lo + hi) >> 1;
        if (arr + m).view(1)[0] > value {
            hi = m;
        } else {
            lo = m + 1;
        }
    }

    return hi;
}

impl find_ttinfo(
    state: ptr[zoneinfo_state], self_: ptr[PyZoneInfo_ZoneInfo], dt: ptr[PyObject]
) -> ptr[_ttinfo] {
    z = self_.view(1);
    if dt == Py_None {
        if z[0].fixed_offset != 0 {
            return tzrule_std(tzrule_after_of(self_));
        }
        return no_ttinfo_of(state);
    }

    (status, ts) = get_local_timestamp(dt);
    if status != 0 {
        return ptr[_ttinfo]();
    }

    fold = datetime_record(dt).view(1)[0].fold;
    local_transitions = (trans_list_wall_of(self_) + i64(fold)).view(1)[0];
    num_trans = i64(z[0].num_transitions);

    if num_trans != 0 and ts < local_transitions.view(1)[0] {
        return z[0].ttinfo_before;
    } elif num_trans == 0 or ts > (local_transitions + (num_trans - 1)).view(1)[0] {
        return find_tzrule_ttinfo(
            tzrule_after_of(self_), ts, fold, datetime_get_year(dt)
        );
    }
    idx = _bisect(ts, local_transitions, num_trans) - 1;
    return (z[0].trans_ttinfos + idx).view(1)[0];
}

impl is_leap_year(year: i32) -> bool {
    ayear = u32.wrap(year);
    return ayear % 4 == 0 and (ayear % 100 != 0 or ayear % 400 == 0);
}

impl ymd_to_ord(y: i32, m: i32, d: i32) -> i32 {
    yy = y - 1;
    days_before_year = (yy * 365) + (yy // 4) - (yy // 100) + (yy // 400);
    yearday = (addressof(DAYS_BEFORE_MONTH) + i64(m)).view(1)[0];
    if m > 2 and is_leap_year(yy + 1) {
        yearday += 1;
    }

    return days_before_year + yearday + d;
}

impl get_local_timestamp(dt: ptr[PyObject]) -> tuple[i32, i64] {
    hour: i32 = 0;
    minute: i32 = 0;
    second: i32 = 0;
    ordinal: i32 = 0;
    if object_type(dt) == PyDateTimeAPI.view(1)[0].DateTimeType {
        d = datetime_record(dt).view(1);
        y = (i32(d[0].data) << 8) | i32(d[0].data_1);
        m = i32(d[0].data_2);
        day = i32(d[0].data_3);
        hour = i32(d[0].data_4);
        minute = i32(d[0].data_5);
        second = i32(d[0].data_6);

        ordinal = ymd_to_ord(y, m, day);
    } else {
        num = PyObject_CallMethod(dt, "toordinal", "");
        if not num {
            return (i32(-1), i64(0));
        }
        ordinal = i32.wrap(PyLong_AsLong(num));
        object_decref(num);
        if ordinal == -1 and PyErr_Occurred() {
            return (i32(-1), i64(0));
        }
        num = PyObject_GetAttrString(dt, ptr[u8]("hour"));
        if not num {
            return (i32(-1), i64(0));
        }
        hour = i32.wrap(PyLong_AsLong(num));
        object_decref(num);
        if hour == -1 {
            return (i32(-1), i64(0));
        }
        num = PyObject_GetAttrString(dt, ptr[u8]("minute"));
        if not num {
            return (i32(-1), i64(0));
        }
        minute = i32.wrap(PyLong_AsLong(num));
        object_decref(num);
        if minute == -1 {
            return (i32(-1), i64(0));
        }
        num = PyObject_GetAttrString(dt, ptr[u8]("second"));
        if not num {
            return (i32(-1), i64(0));
        }
        second = i32.wrap(PyLong_AsLong(num));
        object_decref(num);
        if second == -1 {
            return (i32(-1), i64(0));
        }
    }

    return (
        i32(0),
        (i64(ordinal) - EPOCHORDINAL) * 86400
            + (i64(hour) * 3600 + i64(minute) * 60 + i64(second))
    );
}

impl strong_cache_node_new(
    key: ptr[PyObject], zone: ptr[PyObject]
) -> ptr[StrongCacheNode] {
    cache_node = ptr[StrongCacheNode](PyMem_Malloc(u64(STRONGCACHENODE_SIZE)));
    if not cache_node {
        return cache_node;
    }

    n = cache_node.view(1);
    n[0].next = ptr[StrongCacheNode]();
    n[0].prev = ptr[StrongCacheNode]();
    n[0].key = object_new_ref(key);
    n[0].zone = object_new_ref(zone);

    return cache_node;
}

impl remove_from_strong_cache(
    state: ptr[zoneinfo_state], cache_node: ptr[StrongCacheNode]
) {
    s = state.view(1);
    n = cache_node.view(1);
    if s[0].ZONEINFO_STRONG_CACHE == cache_node {
        s[0].ZONEINFO_STRONG_CACHE = n[0].next;
    }

    prev = n[0].prev;
    if prev {
        prev.view(1)[0].next = n[0].next;
    }

    next_node = n[0].next;
    if next_node {
        next_node.view(1)[0].prev = n[0].prev;
    }

    n[0].next = ptr[StrongCacheNode]();
    n[0].prev = ptr[StrongCacheNode]();
}

impl find_in_strong_cache(
    top: ptr[StrongCacheNode], key: ptr[PyObject]
) -> ptr[StrongCacheNode] {
    cache_node = top;
    while cache_node {
        rv = PyObject_RichCompareBool(key, cache_node.view(1)[0].key, Py_EQ);
        if rv < 0 {
            return ptr[StrongCacheNode]();
        }
        if rv != 0 {
            return cache_node;
        }

        cache_node = cache_node.view(1)[0].next;
    }

    return ptr[StrongCacheNode]();
}

impl eject_from_strong_cache(
    state: ptr[zoneinfo_state], type: ptr[PyTypeObject], key: ptr[PyObject]
) -> i32 {
    s = state.view(1);
    if type != s[0].ZoneInfoType {
        return 0;
    }

    cache = s[0].ZONEINFO_STRONG_CACHE;
    cache_node = find_in_strong_cache(cache, key);
    if cache_node {
        remove_from_strong_cache(state, cache_node);

        strong_cache_node_free(cache_node);
    } elif PyErr_Occurred() {
        return -1;
    }
    return 0;
}

impl move_strong_cache_node_to_front(
    state: ptr[zoneinfo_state],
    top: ptr[ptr[StrongCacheNode]],
    cache_node: ptr[StrongCacheNode]
) {
    root_p = top.view(1)[0];
    if root_p == cache_node {
        return;
    }

    remove_from_strong_cache(state, cache_node);

    n = cache_node.view(1);
    n[0].prev = ptr[StrongCacheNode]();
    n[0].next = root_p;

    if root_p {
        root_p.view(1)[0].prev = cache_node;
    }

    top.view(1)[0] = cache_node;
}

impl zone_from_strong_cache(
    state: ptr[zoneinfo_state], type: ptr[PyTypeObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    s = state.view(1);
    if type != s[0].ZoneInfoType {
        return NULL;
    }

    cache = s[0].ZONEINFO_STRONG_CACHE;
    cache_node = find_in_strong_cache(cache, key);

    if cache_node {
        move_strong_cache_node_to_front(state, strong_cache_root(state), cache_node);
        return object_new_ref(cache_node.view(1)[0].zone);
    }

    return NULL;
}

impl update_strong_cache(
    state: ptr[zoneinfo_state],
    type: ptr[PyTypeObject],
    key: ptr[PyObject],
    zone: ptr[PyObject]
) {
    s = state.view(1);
    if type != s[0].ZoneInfoType {
        return;
    }

    new_node = strong_cache_node_new(key, zone);
    if not new_node {
        return;
    }
    move_strong_cache_node_to_front(state, strong_cache_root(state), new_node);

    cache_node = new_node.view(1)[0].next;
    i: i64 = 1;
    while i < ZONEINFO_STRONG_CACHE_MAX_SIZE {
        if not cache_node {
            return;
        }
        cache_node = cache_node.view(1)[0].next;
        i += 1;
    }

    if cache_node {
        prev = cache_node.view(1)[0].prev;
        if prev {
            prev.view(1)[0].next = ptr[StrongCacheNode]();
        }
        strong_cache_free(cache_node);
    }
}

impl new_weak_cache -> ptr[PyObject] {
    weak_value_dictionary = PyImport_ImportModuleAttrString(
        ptr[u8]("weakref"), ptr[u8]("WeakValueDictionary")
    );
    if not weak_value_dictionary {
        return NULL;
    }
    weak_cache = PyObject_CallNoArgs(weak_value_dictionary);
    object_decref(weak_value_dictionary);
    return weak_cache;
}

impl initialize_caches(state: ptr[zoneinfo_state]) -> i32 {
    s = state.view(1);
    s[0].TIMEDELTA_CACHE = PyDict_New();
    if not s[0].TIMEDELTA_CACHE {
        return -1;
    }

    s[0].ZONEINFO_WEAK_CACHE = new_weak_cache();
    if not s[0].ZONEINFO_WEAK_CACHE {
        return -1;
    }

    return 0;
}

impl zoneinfo_init_subclass(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    weak_cache = new_weak_cache();
    if not weak_cache {
        return NULL;
    }

    if PyObject_SetAttrString(cls, ptr[u8]("_weak_cache"), weak_cache) < 0 {
        object_decref(weak_cache);
        return NULL;
    }
    object_decref(weak_cache);
    return object_new_ref(Py_None);
}

impl install_zoneinfo_methods -> bool {
    slot = ptr[PyType_Slot](addressof(zoneinfo_slots)) + ZONEINFO_METHODS_SLOT;
    if slot.view(1)[0].pfunc {
        return True;
    }
    methods: list[MethodDefinition] = list(ZoneInfo_methods);
    methods.append(
        MethodDefinition(
            "fromutc",
            MethodCallbacks(positional=zoneinfo_fromutc),
            "Given a datetime with local time in UTC, retrieve an adjusted datetime in local time.",
            i64(METH_O)
        )
    );
    methods.append(
        MethodDefinition(
            "__reduce__",
            MethodCallbacks(positional=zoneinfo_reduce),
            "Function for serialization with the pickle protocol.",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "__init_subclass__",
            MethodCallbacks(keywords=zoneinfo_init_subclass),
            "Function to initialize subclasses.",
            i64(METH_VARARGS | METH_KEYWORDS | METH_CLASS)
        )
    );
    table = method_table(methods);
    if not table {
        return False;
    }
    slot.view(1)[0].pfunc = ptr(table);
    return True;
}

impl module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = zoneinfo_get_state(mod);
    s = state.view(1);

    vret = visit_reference(ptr[PyObject](s[0].ZoneInfoType), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(s[0].io_open, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(s[0]._tzpath_find_tzfile, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(s[0]._common_mod, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(s[0].TIMEDELTA_CACHE, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(s[0].ZONEINFO_WEAK_CACHE, visitor, arg);
    if vret != 0 {
        return vret;
    }

    cache_node = s[0].ZONEINFO_STRONG_CACHE;
    while cache_node {
        next_node = cache_node.view(1)[0].next;
        vret = visit_reference(cache_node.view(1)[0].key, visitor, arg);
        if vret != 0 {
            return vret;
        }
        vret = visit_reference(cache_node.view(1)[0].zone, visitor, arg);
        if vret != 0 {
            return vret;
        }
        cache_node = next_node;
    }

    no = no_ttinfo_of(state).view(1);
    vret = visit_reference(no[0].utcoff, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(no[0].dstoff, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(no[0].tzname, visitor, arg);
    if vret != 0 {
        return vret;
    }

    return 0;
}

impl module_clear(mod: ptr[PyObject]) -> i32 {
    state = zoneinfo_get_state(mod);
    s = state.view(1);

    zone_type = ptr[PyObject](s[0].ZoneInfoType);
    s[0].ZoneInfoType = ptr[PyTypeObject]();
    object_xdecref(zone_type);
    old = s[0].io_open;
    s[0].io_open = NULL;
    object_xdecref(old);
    old = s[0]._tzpath_find_tzfile;
    s[0]._tzpath_find_tzfile = NULL;
    object_xdecref(old);
    old = s[0]._common_mod;
    s[0]._common_mod = NULL;
    object_xdecref(old);
    old = s[0].TIMEDELTA_CACHE;
    s[0].TIMEDELTA_CACHE = NULL;
    object_xdecref(old);
    old = s[0].ZONEINFO_WEAK_CACHE;
    s[0].ZONEINFO_WEAK_CACHE = NULL;
    object_xdecref(old);
    clear_strong_cache(state, s[0].ZoneInfoType);
    no = no_ttinfo_of(state).view(1);
    old = no[0].utcoff;
    no[0].utcoff = NULL;
    object_xdecref(old);
    old = no[0].dstoff;
    no[0].dstoff = NULL;
    object_xdecref(old);
    old = no[0].tzname;
    no[0].tzname = NULL;
    object_xdecref(old);

    return 0;
}

impl module_free(mod: ptr) {
    module_clear(ptr[PyObject](mod));
}

impl zoneinfomodule_exec(m: ptr[PyObject]) -> i32 {
    PyDateTimeAPI = ptr[PyDateTime_CAPI](
        PyCapsule_Import(ptr[u8]("datetime.datetime_CAPI"), 0)
    );
    if not PyDateTimeAPI {
        return -1;
    }

    if not install_zoneinfo_methods() {
        return -1;
    }
    ZoneInfo_token.handle = ptr(addressof(zoneinfo_spec));

    state = zoneinfo_get_state(m);
    s = state.view(1);
    base = ptr[PyObject](PyDateTimeAPI.view(1)[0].TZInfoType);
    s[0].ZoneInfoType = ptr[PyTypeObject](
        PyType_FromModuleAndSpec(m, addressof(zoneinfo_spec), base)
    );
    if not s[0].ZoneInfoType {
        return -1;
    }

    rc = PyModule_AddObjectRef(
        m, ptr[u8]("ZoneInfo"), ptr[PyObject](s[0].ZoneInfoType)
    );
    if rc < 0 {
        return -1;
    }

    s[0]._tzpath_find_tzfile = PyImport_ImportModuleAttrString(
        ptr[u8]("zoneinfo._tzpath"), ptr[u8]("find_tzfile")
    );
    if not s[0]._tzpath_find_tzfile {
        return -1;
    }

    s[0].io_open = PyImport_ImportModuleAttrString(ptr[u8]("io"), ptr[u8]("open"));
    if not s[0].io_open {
        return -1;
    }

    s[0]._common_mod = PyImport_ImportModule(ptr[u8]("zoneinfo._common"));
    if not s[0]._common_mod {
        return -1;
    }

    no = no_ttinfo_of(state).view(1);
    if not no[0].utcoff {
        no[0].utcoff = object_new_ref(Py_None);
        no[0].dstoff = object_new_ref(Py_None);
        no[0].tzname = object_new_ref(Py_None);
    }

    if initialize_caches(state) != 0 {
        return -1;
    }

    return 0;
}
