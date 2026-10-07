"""Temporal shared infrastructure — branding, slots, options, conversions."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    js_number,
    js_boolean,
    jsv_from_string_id,
    jsv_from_bool,
    jsv_from_cell_kind,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_bigint_cell,
    jsv_is_symbol,
    jsv_is_any_object,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    jsv_to_bool,
    JS_CELL_KIND_BIGINT,
    MATH_INF
}
import from engine.src.runtime.jsstring { str_intern, str_heap, str_from_id }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_has_own
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_to_number_observable,
    js_to_string_observable
}
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.ffi.tz {
    tz_load_zone,
    tz_get_offset,
    tz_unload,
    tz_get_possible_offsets,
    tz_write_offset,
    tz_get_next_transition
}
import from engine.src.runtime.mem { io_alloc, read_i32 }
import from engine.src.runtime.temporal_parse {
    parse_iso_date_time,
    parse_duration,
    parse_empty_result,
    PR_OK,
    PR_YEAR,
    PR_MONTH,
    PR_DAY,
    PR_HOUR,
    PR_MINUTE,
    PR_SECOND,
    PR_NANOSECOND,
    PR_CALENDAR,
    PR_HAS_DATE,
    PR_HAS_TIME,
    PR_HAS_OFFSET,
    PR_OFFSET_S,
    PR_IS_DURATION,
    PR_TZ_ANNOTATION,
    PR_IS_Z,
    PR_S_TZ_ANNOTATION,
    PR_S_CALENDAR,
    PR_DUR_YEARS,
    PR_DUR_MONTHS,
    PR_DUR_WEEKS,
    PR_DUR_DAYS,
    PR_DUR_HOURS,
    PR_DUR_MINUTES,
    PR_DUR_SECONDS,
    PR_IS_NEGATIVE,
    is_valid_iso_date,
    is_valid_iso_time,
    calendar_id_from_string,
    iso_string_is_calendar_identifier,
    extract_calendar_annotation,
    parse_temporal_time_zone_string,
    parse_temporal_time_zone_id,
    parse_month_code,
    parse_utc_offset_string,
    offset_string_has_subminute,
    offset_string_to_seconds,
    _is_offset_only_tz_string
}
import from engine.src.runtime.jsstring { str_substr }
import from engine.src.runtime.temporal_iso {
    iso_validate_ymd,
    iso_validate_time,
    iso_validate_relativeto_ymd,
    iso_validate_relativeto_instant,
    iso_validate_datetime_within_limits,
    iso_validate_year_month,
    iso_balance_date,
    iso_add_days,
    iso_add_months,
    iso_compare,
    iso_format_date,
    iso_format_time,
    iso_format_time_precision,
    iso_day_of_week,
    iso_day_of_year,
    iso_week_of_year,
    iso_month_code,
    iso_days_in_month,
    iso_days_in_year,
    iso_is_leap_year,
    iso_add_time,
    iso_total_nanoseconds,
    iso_days_from_ymd,
    iso_ymd_from_days,
    iso_nanoseconds_to_time
}
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_add,
    dur_subtract,
    dur_negate,
    dur_balance,
    dur_compare,
    dur_to_string,
    dur_to_string_with_options,
    dur_total,
    dur_round,
    dur_round_preserve_calendar,
    dur_round_with_anchor,
    dur_round_difference,
    dur_limit_largest_unit,
    dur_empty,
    dur_sign,
    DUR_YEARS,
    DUR_MONTHS,
    DUR_WEEKS,
    DUR_DAYS,
    DUR_HOURS,
    DUR_MINUTES,
    DUR_SECONDS,
    DUR_NANOSECONDS,
    DUR_SIGN,
    rounding_mode_from_string,
    rounding_mode_to_string,
    ROUND_TRUNC,
    _dur_pow10,
    ROUND_HALF_EXPAND,
    ROUND_HALF_TRUNC,
    ROUND_HALF_EVEN,
    ROUND_CEIL,
    ROUND_FLOOR,
    ROUND_EXPAND,
    ROUND_HALF_CEIL,
    ROUND_HALF_FLOOR,
    dur_max_rounding_increment,
    dur_validate_rounding_increment,
    dur_reject_out_of_range,
    _dur_no_subunit_remainder
}
import from engine.src.runtime.bignat {
    bn_zero,
    bn_from_int,
    bn_parse_decimal,
    bn_to_string,
    bn_add,
    bn_sub,
    bn_cmp,
    bn_sign,
    bn_is_zero,
    bn_mul_small,
    bn_divmod,
    bn_neg,
    _BN_DIV_REM
}
import from engine.src.builtins.calendars.calendar_dispatch {
    calendar_iso_to_fields,
    calendar_fields_to_iso,
    calendar_is_known,
    calendar_id_normalize,
    calendar_field_month_code,
    calendar_field_era,
    calendar_field_era_year,
    calendar_field_days_in_month,
    calendar_field_days_in_year,
    calendar_field_in_leap_year,
    calendar_field_months_in_year,
    calendar_field_day_of_year,
    calendar_months_in_year,
    CF_YEAR,
    CF_MONTH,
    CF_DAY,
    CF_ERA,
    CF_ERA_YEAR
}
import from engine.src.builtins.calendars.calendar_arithmetic { calendar_regulate }
import from engine.src.builtins.calendars.calendar_chinese { chinese_leap_month }
import from engine.src.builtins.calendars.calendar_era {
    calendar_era_id_from_name,
    ERA_NONE,
    ERA_BCE,
    ERA_AA,
    ERA_BH,
    ERA_BROC,
    ERA_MEIJI,
    ERA_TAISHO,
    ERA_SHOWA,
    ERA_HEISEI,
    ERA_REIWA
}
import from engine.src.builtins.markers {
    _KEY_IS_TEMPORAL_PLAIN_DATE,
    _KEY_IS_TEMPORAL_PLAIN_TIME,
    _KEY_IS_TEMPORAL_PLAIN_DATETIME,
    _KEY_IS_TEMPORAL_PLAIN_YEAR_MONTH,
    _KEY_IS_TEMPORAL_PLAIN_MONTH_DAY,
    _KEY_IS_TEMPORAL_DURATION,
    _KEY_IS_TEMPORAL_INSTANT,
    _KEY_IS_TEMPORAL_ZONED_DATETIME
}
import from engine.src.builtins.native_registry { get_native_name, is_native_val }
import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value }
import from engine.src.builtins.string { js_coerce_to_string }

glob KEY_ISO_YEAR: int = 0,
     KEY_ISO_MONTH: int = 0,
     KEY_ISO_DAY: int = 0,
     KEY_ISO_HOUR: int = 0,
     KEY_ISO_MINUTE: int = 0,
     KEY_ISO_SECOND: int = 0,
     KEY_ISO_NANOSECOND: int = 0,
     KEY_CALENDAR: int = 0,
     KEY_REF_YEAR: int = 0,
     KEY_NANOSECONDS: int = 0,
     KEY_TIMEZONE: int = 0,
     KEY_OFFSET_NS: int = 0,
     KEY_GETTER_NAME: int = 0,
     _PD_PROTO: JSValue = js_undefined(),
     _PT_PROTO: JSValue = js_undefined(),
     _PDT_PROTO: JSValue = js_undefined(),
     _PYM_PROTO: JSValue = js_undefined(),
     _PMD_PROTO: JSValue = js_undefined(),
     _DUR_PROTO: JSValue = js_undefined(),
     _INS_PROTO: JSValue = js_undefined(),
     _ZDT_PROTO: JSValue = js_undefined(),
     _TEMPORAL_NATIVE_CALLEE: JSValue = js_undefined();

def:pub temporal_init_keys {
    KEY_ISO_YEAR = str_intern("__isoYear");
    KEY_ISO_MONTH = str_intern("__isoMonth");
    KEY_ISO_DAY = str_intern("__isoDay");
    KEY_ISO_HOUR = str_intern("__isoHour");
    KEY_ISO_MINUTE = str_intern("__isoMinute");
    KEY_ISO_SECOND = str_intern("__isoSecond");
    KEY_ISO_NANOSECOND = str_intern("__isoNanosecond");
    KEY_CALENDAR = str_intern("__calendar");
    KEY_REF_YEAR = str_intern("__refYear");
    KEY_NANOSECONDS = str_intern("__nanoseconds");
    KEY_TIMEZONE = str_intern("__timeZone");
    KEY_OFFSET_NS = str_intern("__offsetNanoseconds");
    KEY_GETTER_NAME = str_intern("__getter");
}

def _js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));
}  # G1.5: temporal value string

def:pub temporal_str_copy(s: str) -> str {
    out: str = "";
    i: int = 0;
    while i < len(s) {
        out = out + s[i:i + 1];
        i = i + 1;
    }
    return out;
}

def:pub temporal_set_plain_date_proto(p: JSValue) {
    _PD_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_plain_time_proto(p: JSValue) {
    _PT_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_plain_datetime_proto(p: JSValue) {
    _PDT_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_plain_year_month_proto(p: JSValue) {
    _PYM_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_plain_month_day_proto(p: JSValue) {
    _PMD_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_duration_proto(p: JSValue) {
    _DUR_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_instant_proto(p: JSValue) {
    _INS_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_zoned_datetime_proto(p: JSValue) {
    _ZDT_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

def:pub temporal_set_callee(fn: JSValue) {
    # churning glob root — invisible to the GC root walk; unpin old, pin new
    gc_unpin_value(_TEMPORAL_NATIVE_CALLEE);
    _TEMPORAL_NATIVE_CALLEE = fn;
    gc_pin_value(fn);
}

def:pub temporal_callee_name -> str {
    if is_native_val(_TEMPORAL_NATIVE_CALLEE) {
        return get_native_name(_TEMPORAL_NATIVE_CALLEE);
    }
    return "";
}

def:pub js_is_plain_date(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_PLAIN_DATE);
}

def:pub js_is_plain_time(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_PLAIN_TIME);
}

def:pub js_is_plain_datetime(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_PLAIN_DATETIME);
}

def:pub js_is_plain_year_month(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_PLAIN_YEAR_MONTH);
}

def:pub js_is_plain_month_day(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_PLAIN_MONTH_DAY);
}

def:pub js_is_duration(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_DURATION);
}

def:pub js_is_instant(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_INSTANT);
}

def:pub js_is_zoned_datetime(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_TEMPORAL_ZONED_DATETIME);
}

"""True if `v` carries ANY Temporal brand (PlainDate/Time/DateTime/YearMonth/MonthDay,
Instant, ZonedDateTime, Duration). RejectObjectWithCalendarOrTimeZone uses this to
reject a Temporal object passed where a plain fields bag is required (.with())."""
def:pub js_is_any_temporal_object(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_is_plain_date(v)
        or js_is_plain_time(v)
        or js_is_plain_datetime(v)
        or js_is_plain_year_month(v)
        or js_is_plain_month_day(v)
        or js_is_instant(v)
        or js_is_zoned_datetime(v)
        or js_is_duration(v);
}

def _get_int_slot(o: JSValue, key: int) -> int {
    v: JSValue = js_object_get(o, key);
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _get_str_slot(o: JSValue, key: int) -> str {
    v: JSValue = js_object_get(o, key);
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "iso8601";
}

def _set_iso_date(o: JSValue, y: int, m: int, d: int) {
    js_object_set(o, KEY_ISO_YEAR, js_int(y));
    js_object_set(o, KEY_ISO_MONTH, js_int(m));
    js_object_set(o, KEY_ISO_DAY, js_int(d));
}

def _set_iso_time(o: JSValue, h: int, mi: int, s: int, ns: int) {
    js_object_set(o, KEY_ISO_HOUR, js_int(h));
    js_object_set(o, KEY_ISO_MINUTE, js_int(mi));
    js_object_set(o, KEY_ISO_SECOND, js_int(s));
    js_object_set(o, KEY_ISO_NANOSECOND, js_int(ns));
}

def:pub js_plain_date_init(o: JSValue, y: int, m: int, d: int, cal: str) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_DATE, js_true());
    _set_iso_date(o, y, m, d);
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_plain_date_create(y: int, m: int, d: int, cal: str) -> JSValue {
    o: JSValue = js_object_create(_PD_PROTO)
        if jsv_is_object_cell(_PD_PROTO)
        else js_object_create_null();
    return js_plain_date_init(o, y, m, d, cal);
}

def:pub js_plain_date_slots(o: JSValue) -> list[int] {
    return [
        _get_int_slot(o, KEY_ISO_YEAR),
        _get_int_slot(o, KEY_ISO_MONTH),
        _get_int_slot(o, KEY_ISO_DAY)
    ];
}

def:pub js_plain_time_create(h: int, mi: int, s: int, ns: int, cal: str) -> JSValue {
    o: JSValue = js_object_create(_PT_PROTO)
        if jsv_is_object_cell(_PT_PROTO)
        else js_object_create_null();
    return js_plain_time_init(o, h, mi, s, ns, cal);
}

def:pub js_plain_datetime_create(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, cal: str
) -> JSValue {
    o: JSValue = js_object_create(_PDT_PROTO)
        if jsv_is_object_cell(_PDT_PROTO)
        else js_object_create_null();
    return js_plain_datetime_init(o, y, m, d, h, mi, s, ns, cal);
}

def:pub js_plain_year_month_create(y: int, m: int, cal: str) -> JSValue {
    o: JSValue = js_object_create(_PYM_PROTO)
        if jsv_is_object_cell(_PYM_PROTO)
        else js_object_create_null();
    return js_plain_year_month_init(o, y, m, cal);
}

# Create a PlainYearMonth with an explicit referenceISODay (the constructor's 4th
# argument). The reference day defaults to 1 in the ordinary path.
def:pub js_plain_year_month_create_ref(y: int, m: int, d: int, cal: str) -> JSValue {
    o: JSValue = js_object_create(_PYM_PROTO)
        if jsv_is_object_cell(_PYM_PROTO)
        else js_object_create_null();
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_YEAR_MONTH, js_true());
    _set_iso_date(o, y, m, d);
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_plain_month_day_create(m: int, d: int, ref_y: int, cal: str) -> JSValue {
    o: JSValue = js_object_create(_PMD_PROTO)
        if jsv_is_object_cell(_PMD_PROTO)
        else js_object_create_null();
    return js_plain_month_day_init(o, m, d, ref_y, cal);
}

def:pub js_instant_create(ns: list[int]) -> JSValue {
    o: JSValue = js_object_create(_INS_PROTO)
        if jsv_is_object_cell(_INS_PROTO)
        else js_object_create_null();
    return js_instant_init(o, ns);
}

def:pub js_instant_read_ns(o: JSValue) -> list[int] {
    return bn_parse_decimal(_get_str_slot(o, KEY_NANOSECONDS));
}

def:pub js_zoned_datetime_init(
    o: JSValue,
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    tz: str,
    offset_s: int,
    cal: str
) -> JSValue {
    tz_box: list[any] = [temporal_str_copy(tz)];
    cal_box: list[any] = [temporal_str_copy(cal)];
    js_object_set(o, _KEY_IS_TEMPORAL_ZONED_DATETIME, js_true());
    _set_iso_date(o, y, m, d);
    _set_iso_time(o, h, mi, s, ns);
    js_object_set(o, KEY_TIMEZONE, _js_str(tz_box[0]));
    js_object_set(o, KEY_OFFSET_NS, js_int(offset_s));
    js_object_set(o, KEY_CALENDAR, _js_str(cal_box[0]));
    days: int = iso_days_from_ymd(y, m, d);
    local_s: int = days * 86400 + h * 3600 + mi * 60 + s;
    local_ns_bn: list[int] = bn_add(
        bn_mul_small(bn_from_int(local_s), 1000000000), bn_from_int(ns)
    );
    off_ns_bn: list[int] = bn_mul_small(bn_from_int(offset_s), 1000000000);
    epoch_bn: list[int] = bn_sub(local_ns_bn, off_ns_bn);
    js_object_set(o, KEY_NANOSECONDS, _js_str(bn_to_string(epoch_bn, 10)));
    return o;
}

def:pub js_zoned_datetime_create(
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    tz: str,
    offset_s: int,
    cal: str
) -> JSValue {
    o: JSValue = js_object_create(_ZDT_PROTO)
        if jsv_is_object_cell(_ZDT_PROTO)
        else js_object_create_null();
    return js_zoned_datetime_init(o, y, m, d, h, mi, s, ns, tz, offset_s, cal);
}

# IsValidEpochNanoseconds — the representable Instant/ZonedDateTime range is
# ±8.64e21 ns (±10^8 days from the epoch). Throws RangeError otherwise. Used where a
# local wall-clock + offset can land outside the range (PlainDate.toZonedDateTime near
# the ISO date limits).
def:pub temporal_reject_epoch_ns_out_of_range(ns: list[int]) {
    limit: list[int] = bn_parse_decimal("8640000000000000000000");
    if bn_cmp(ns, limit) > 0 or bn_cmp(ns, bn_neg(limit)) < 0 {
        vm_throw_native(make_range_error("date-time value is outside the valid range"));
    }
}

# Epoch nanoseconds for a local wall-clock at a fixed UTC offset (offset in NANOSECONDS).
def:pub temporal_local_epoch_ns(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, offset_ns: int
) -> list[int] {
    days: int = iso_days_from_ymd(y, m, d);
    local_s: int = days * 86400 + h * 3600 + mi * 60 + s;
    local_ns_bn: list[int] = bn_add(
        bn_mul_small(bn_from_int(local_s), 1000000000), bn_from_int(ns)
    );
    return bn_sub(local_ns_bn, bn_from_int(offset_ns));
}

def:pub _dur_split_subsecond(sub: float) -> list[float] {
    an: float = sub;
    if an < 0.0 {
        an = -an;
    }
    ms: float = float(int(an // 1000000.0));
    rem: float = an - ms * 1000000.0;
    us: float = float(int(rem // 1000.0));
    nss: float = rem - us * 1000.0;
    return [ms, us, nss];
}

def:pub js_duration_init(o: JSValue, d: list[float]) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_DURATION, js_true());
    js_object_set(o, str_intern("__y"), js_number(d[DUR_YEARS]));
    js_object_set(o, str_intern("__mo"), js_number(d[DUR_MONTHS]));
    js_object_set(o, str_intern("__w"), js_number(d[DUR_WEEKS]));
    js_object_set(o, str_intern("__d"), js_number(d[DUR_DAYS]));
    js_object_set(o, str_intern("__h"), js_number(d[DUR_HOURS]));
    js_object_set(o, str_intern("__mi"), js_number(d[DUR_MINUTES]));
    js_object_set(o, str_intern("__s"), js_number(d[DUR_SECONDS]));
    sub: list[float] = _dur_split_subsecond(d[DUR_NANOSECONDS]);
    js_object_set(o, str_intern("__ms"), js_number(sub[0]));
    js_object_set(o, str_intern("__us"), js_number(sub[1]));
    js_object_set(o, str_intern("__ns"), js_number(sub[2]));
    js_object_set(o, str_intern("__sgn"), js_number(d[DUR_SIGN]));
    return o;
}

def:pub js_duration_init_explicit(
    o: JSValue,
    y: float,
    mo: float,
    w: float,
    d: float,
    h: float,
    mi: float,
    s: float,
    ms: float,
    us: float,
    ns: float,
    sign: float
) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_DURATION, js_true());
    js_object_set(o, str_intern("__y"), js_number(y));
    js_object_set(o, str_intern("__mo"), js_number(mo));
    js_object_set(o, str_intern("__w"), js_number(w));
    js_object_set(o, str_intern("__d"), js_number(d));
    js_object_set(o, str_intern("__h"), js_number(h));
    js_object_set(o, str_intern("__mi"), js_number(mi));
    js_object_set(o, str_intern("__s"), js_number(s));
    js_object_set(o, str_intern("__ms"), js_number(ms));
    js_object_set(o, str_intern("__us"), js_number(us));
    js_object_set(o, str_intern("__ns"), js_number(ns));
    js_object_set(o, str_intern("__sgn"), js_number(sign));
    return o;
}

def:pub js_instant_init(o: JSValue, ns: list[int]) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_INSTANT, js_true());
    js_object_set(o, KEY_NANOSECONDS, _js_str(bn_to_string(ns, 10)));
    return o;
}

def:pub js_plain_time_init(
    o: JSValue, h: int, mi: int, s: int, ns: int, cal: str
) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_TIME, js_true());
    _set_iso_time(o, h, mi, s, ns);
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_plain_datetime_init(
    o: JSValue, y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, cal: str
) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_DATETIME, js_true());
    _set_iso_date(o, y, m, d);
    _set_iso_time(o, h, mi, s, ns);
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_plain_year_month_init(o: JSValue, y: int, m: int, cal: str) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_YEAR_MONTH, js_true());
    _set_iso_date(o, y, m, 1);
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_plain_month_day_init(
    o: JSValue, m: int, d: int, ref_y: int, cal: str
) -> JSValue {
    js_object_set(o, _KEY_IS_TEMPORAL_PLAIN_MONTH_DAY, js_true());
    _set_iso_date(o, ref_y, m, d);
    js_object_set(o, KEY_REF_YEAR, js_int(ref_y));
    js_object_set(o, KEY_CALENDAR, _js_str(cal));
    return o;
}

def:pub js_zoned_read_ns(o: JSValue) -> list[int] {
    return bn_parse_decimal(_get_str_slot(o, KEY_NANOSECONDS));
}

def:pub js_this_plain_date(v: JSValue) -> JSValue {
    if js_is_plain_date(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.PlainDate method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_this_plain_time(v: JSValue) -> JSValue {
    if js_is_plain_time(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.PlainTime method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_this_plain_datetime(v: JSValue) -> JSValue {
    if js_is_plain_datetime(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.PlainDateTime method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_this_plain_year_month(v: JSValue) -> JSValue {
    if js_is_plain_year_month(v) {
        return v;
    }
    vm_throw_native(
        make_type_error(
            "Temporal.PlainYearMonth method called on incompatible receiver"
        )
    );
    return js_undefined();
}

def:pub js_this_plain_month_day(v: JSValue) -> JSValue {
    if js_is_plain_month_day(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.PlainMonthDay method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_this_instant(v: JSValue) -> JSValue {
    if js_is_instant(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.Instant method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_this_zoned_datetime(v: JSValue) -> JSValue {
    if js_is_zoned_datetime(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.ZonedDateTime method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub js_duration_create(d: list[float]) -> JSValue {
    o: JSValue = js_object_create(_DUR_PROTO)
        if jsv_is_object_cell(_DUR_PROTO)
        else js_object_create_null();
    return js_duration_init(o, d);
}

"""
Create a Duration keeping sub-second fields unbalanced per largestUnit.
Temporal allows milliseconds/microseconds/nanoseconds > 999 when that unit
is the largestUnit of a round/balance result.
"""
def:pub js_duration_create_unbalanced_subseconds(
    d: list[float], largest: str
) -> JSValue {
    o: JSValue = js_object_create(_DUR_PROTO)
        if jsv_is_object_cell(_DUR_PROTO)
        else js_object_create_null();
    # Rebuild total ns from time fields with integer math (seconds may hold the
    # high part so DUR_NANOSECONDS stays < 1e9 and float-exact).
    sgn: float = d[DUR_SIGN];
    sec_i: int = int(d[DUR_SECONDS]);
    if sec_i < 0 {
        sec_i = -sec_i;
    }
    # The nanosecond field can far exceed i64 (a Duration built with a huge millisecond
    # field, e.g. 1.8e19 ns). int() of such a float overflows the native int and
    # crashes, so keep the bulk in FLOAT and int() only the small (< 1e6) remainder.
    ns_f: float = d[DUR_NANOSECONDS];
    if ns_f < 0.0 {
        ns_f = -ns_f;
    }
    # Also fold hours/minutes/days if present.
    h_i: int = int(d[DUR_HOURS]);
    if h_i < 0 {
        h_i = -h_i;
    }
    mi_i: int = int(d[DUR_MINUTES]);
    if mi_i < 0 {
        mi_i = -mi_i;
    }
    d_i: int = int(d[DUR_DAYS]);
    if d_i < 0 {
        d_i = -d_i;
    }
    total_sec: int = d_i * 86400 + h_i * 3600 + mi_i * 60 + sec_i;
    ms: float = 0.0;
    us: float = 0.0;
    nss: float = 0.0;
    if largest == "millisecond" or largest == "milliseconds" {
        # ms = total_sec*1000 + floor(ns/1e6); the ns remainder (< 1e6) splits into µs/ns.
        ns_ms_hi: float = float(int(ns_f / 1000000.0));
        rem_f: float = ns_f - ns_ms_hi * 1000000.0;
        rem: int = int(rem_f);
        ms = float(total_sec) * 1000.0 + ns_ms_hi;
        us = float(rem // 1000);
        nss = float(rem % 1000);
    } elif largest == "microsecond" or largest == "microseconds" {
        # us = total_sec*1e6 + floor(ns/1000); the ns remainder (< 1000) is nanoseconds.
        ns_us_hi: float = float(int(ns_f / 1000.0));
        rem_us_f: float = ns_f - ns_us_hi * 1000.0;
        us = float(total_sec) * 1000000.0 + ns_us_hi;
        nss = float(int(rem_us_f));
    } elif largest == "nanosecond" or largest == "nanoseconds" {
        # Float throughout — seconds*1e9 already loses exactness for huge spans, and
        # int(ns_f) would overflow the native int for an out-of-safe-range duration.
        nss = float(total_sec) * 1000000000.0 + ns_f;
    } else {
        return js_duration_init(o, d);
    }
    return js_duration_init_explicit(
        o, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ms, us, nss, sgn
    );
}

def:pub js_duration_read(o: JSValue) -> list[float] {
    sgn: float = 1.0;
    sg_v: JSValue = js_object_get(o, str_intern("__sgn"));
    if jsv_is_double(sg_v) {
        sgn = jsv_to_double(sg_v);
    } elif jsv_is_int32(sg_v) {
        sgn = float(jsv_to_int32(sg_v));
    }
    ms: float = jsv_to_double(js_object_get(o, str_intern("__ms")));
    us: float = jsv_to_double(js_object_get(o, str_intern("__us")));
    nss: float = jsv_to_double(js_object_get(o, str_intern("__ns")));
    ms_v: JSValue = js_object_get(o, str_intern("__ms"));
    sub_ns: float = nss;
    if not jsv_is_undefined(ms_v) {
        sub_ns = ms * 1000000.0 + us * 1000.0 + nss;
    } else {
        sub_ns = jsv_to_double(js_object_get(o, str_intern("__ns")));
    }
    out: list[float] = dur_from_components(
        jsv_to_double(js_object_get(o, str_intern("__y"))),
        jsv_to_double(js_object_get(o, str_intern("__mo"))),
        jsv_to_double(js_object_get(o, str_intern("__w"))),
        jsv_to_double(js_object_get(o, str_intern("__d"))),
        jsv_to_double(js_object_get(o, str_intern("__h"))),
        jsv_to_double(js_object_get(o, str_intern("__mi"))),
        jsv_to_double(js_object_get(o, str_intern("__s"))),
        sub_ns
    );
    out[DUR_SIGN] = sgn;
    return out;
}

def:pub js_this_duration(v: JSValue) -> JSValue {
    if js_is_duration(v) {
        return v;
    }
    vm_throw_native(
        make_type_error("Temporal.Duration method called on incompatible receiver")
    );
    return js_undefined();
}

def:pub temporal_get_calendar(o: JSValue) -> str {
    return _get_str_slot(o, KEY_CALENDAR);
}

def:pub temporal_to_string(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_bigint_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return str(jsv_to_double(v));
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        }
        return "false";
    }
    return "";
}

def:priv _temporal_unit_normalize(s: str) -> str {
    if s == "years" {
        return "year";
    }
    if s == "months" {
        return "month";
    }
    if s == "weeks" {
        return "week";
    }
    if s == "days" {
        return "day";
    }
    if s == "hours" {
        return "hour";
    }
    if s == "minutes" {
        return "minute";
    }
    if s == "seconds" {
        return "second";
    }
    if s == "milliseconds" {
        return "millisecond";
    }
    if s == "microseconds" {
        return "microsecond";
    }
    if s == "nanoseconds" {
        return "nanosecond";
    }
    return s;
}

def:priv _temporal_unit_valid(s: str, allow_auto: bool) -> bool {
    s = _temporal_unit_normalize(s);
    if len(s) == 0 {
        return False;
    }
    if s == "era" {
        return False;
    }
    if allow_auto and s == "auto" {
        return True;
    }
    if s == "year" or s == "month" or s == "week" or s == "day" {
        return True;
    }
    if s == "hour" or s == "minute" or s == "second" {
        return True;
    }
    if s == "millisecond" or s == "microsecond" or s == "nanosecond" {
        return True;
    }
    return False;
}

def:priv _temporal_options_is_valid(options: JSValue) -> bool {
    if jsv_is_undefined(options) {
        return True;
    }
    return jsv_is_any_object(options);
}

def:pub temporal_get_overflow(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "constrain";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "constrain";
    }
    # Read overflow observably — a getter on options.overflow must fire, in the spec
    # position (after all field reads), for the order-of-operations traces.
    ov: JSValue = js_object_get_observable(options, str_intern("overflow"), options);
    if vm_has_native_exc() {
        return "constrain";
    }
    if jsv_is_undefined(ov) {
        return "constrain";
    }
    # GetOption type "string": ToString a Symbol → TypeError; everything else
    # coerces to a string that must be "constrain"/"reject" or it is a RangeError.
    s: str = js_to_string_observable(ov);
    if vm_has_native_exc() {
        return "constrain";
    }
    if s == "reject" or s == "constrain" {
        return s;
    }
    vm_throw_native(make_range_error("invalid overflow"));
    return "constrain";
}

def:pub temporal_get_total_unit(options: JSValue) -> str {
    if jsv_is_undefined(options) or jsv_is_null(options) {
        vm_throw_native(make_type_error("options required"));
        return "seconds";
    }
    if not jsv_is_any_object(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "seconds";
    }
    uv: JSValue = js_object_get(options, str_intern("unit"));
    if jsv_is_undefined(uv) {
        vm_throw_native(make_range_error("unit is required"));
        return "seconds";
    }
    uv_raw: str = js_to_string_observable(uv);
    if vm_has_native_exc() {
        return "seconds";
    }
    s: str = _temporal_unit_normalize(uv_raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error('"' + uv_raw + '" is not a valid value for unit')
        );
        return "seconds";
    }
    return s;
}

def:pub temporal_get_total_unit_observable(options: JSValue) -> str {
    if jsv_is_undefined(options) or jsv_is_null(options) {
        vm_throw_native(make_type_error("options required"));
        return "seconds";
    }
    if not jsv_is_any_object(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "seconds";
    }
    uv: JSValue = js_object_get_observable(options, str_intern("unit"), options);
    if vm_has_native_exc() {
        return "seconds";
    }
    if jsv_is_undefined(uv) {
        vm_throw_native(make_range_error("unit is required"));
        return "seconds";
    }
    raw: str = js_to_string_observable(uv);
    if vm_has_native_exc() {
        return "seconds";
    }
    if len(raw) == 0 {
        vm_throw_native(make_range_error("invalid unit"));
        return "seconds";
    }
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error(
                '"' + temporal_to_string(uv) + '" is not a valid value for unit'
            )
        );
        return "seconds";
    }
    return s;
}

def:pub temporal_get_unit_from_string_arg(v: JSValue) -> str {
    if not jsv_is_string_cell(v) {
        vm_throw_native(make_type_error("invalid options"));
        return "second";
    }
    raw: str = temporal_to_string(v);
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for unit')
        );
        return "second";
    }
    return s;
}

def:pub temporal_require_options_object(options: JSValue) -> None {
    if jsv_is_undefined(options) {
        return;
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
    }
}

"""Normalize a `round(roundTo)` argument: the Temporal `.round()` methods accept a
STRING shorthand for smallestUnit — `instant.round("hour")` is equivalent to
`instant.round({ smallestUnit: "hour" })` (e.g. Temporal.Instant.prototype.round
step 3: "If roundTo is a String, ... CreateDataPropertyOrThrow(roundTo, 'smallestUnit',
paramString)"). Wrapping into a real object (rather than special-casing every reader)
also avoids touching Object.prototype getters for roundingIncrement/roundingMode
(string-shorthand-no-object-prototype-pollution). Returns `options` unchanged when it
is not a string."""
def:pub temporal_round_options_from_arg(options: JSValue) -> JSValue {
    if not jsv_is_string_cell(options) {
        return options;
    }
    wrapped: JSValue = js_object_create_null();
    js_object_set(wrapped, str_intern("smallestUnit"), options);
    return wrapped;
}

"""GetRoundingModeOption(options, default) — reads roundingMode (ToString-coerced,
so a Symbol is a TypeError) and validates it against the 9 modes. Returns `default`
(a ROUND_* constant) when absent: the `.round()` methods pass ROUND_HALF_EXPAND, the
`.toString()` methods pass ROUND_TRUNC (spec §—: differing defaults per method)."""
def:pub temporal_get_rounding_mode_default(options: JSValue, default_mode: int) -> int {
    if jsv_is_undefined(options) {
        return default_mode;
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return default_mode;
    }
    rm: JSValue = js_object_get_observable(
        options, str_intern("roundingMode"), options
    );
    if vm_has_native_exc() {
        return default_mode;
    }
    if jsv_is_undefined(rm) {
        return default_mode;
    }
    s: str = js_to_string_observable(rm);
    if vm_has_native_exc() {
        return default_mode;
    }
    if s != "trunc"
        and s != "halfExpand"
        and s != "halfTrunc"
        and s != "halfEven"
        and s != "halfCeil"
        and s != "halfFloor"
        and s != "ceil"
        and s != "floor"
        and s != "expand" {
        vm_throw_native(make_range_error("invalid roundingMode"));
        return default_mode;
    }
    return rounding_mode_from_string(s);
}

def:pub temporal_get_rounding_mode(options: JSValue) -> int {
    return temporal_get_rounding_mode_default(options, ROUND_TRUNC);
}

"""roundingMode for the `.round()` methods — default halfExpand (§Temporal.*.round)."""
def:pub temporal_get_round_rounding_mode(options: JSValue) -> int {
    return temporal_get_rounding_mode_default(options, ROUND_HALF_EXPAND);
}

def:pub temporal_get_largest_unit(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "auto";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "auto";
    }
    lu: JSValue = js_object_get_observable(options, str_intern("largestUnit"), options);
    if vm_has_native_exc() {
        return "auto";
    }
    if jsv_is_undefined(lu) {
        return "auto";
    }
    raw: str = js_to_string_observable(lu);
    if vm_has_native_exc() {
        return "auto";
    }
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, True) {
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for largestUnit')
        );
        return "auto";
    }
    return s;
}

def:pub temporal_get_smallest_unit(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "nanosecond";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "nanosecond";
    }
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return "nanosecond";
    }
    if jsv_is_undefined(su) {
        return "nanosecond";
    }
    raw: str = js_to_string_observable(su);
    if vm_has_native_exc() {
        return "nanosecond";
    }
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for smallest unit')
        );
        return "nanosecond";
    }
    return s;
}

# Like temporal_get_smallest_unit but smallestUnit is REQUIRED (round): an absent
# smallestUnit is a RangeError rather than defaulting.
def:pub temporal_get_smallest_unit_required(options: JSValue) -> str {
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "nanosecond";
    }
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return "nanosecond";
    }
    if jsv_is_undefined(su) {
        vm_throw_native(make_range_error("smallestUnit is required"));
        return "nanosecond";
    }
    raw: str = js_to_string_observable(su);
    if vm_has_native_exc() {
        return "nanosecond";
    }
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for smallest unit')
        );
        return "nanosecond";
    }
    return s;
}

def:pub temporal_get_smallest_unit_default(options: JSValue, default_unit: str) -> str {
    if jsv_is_undefined(options) {
        return default_unit;
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return default_unit;
    }
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return default_unit;
    }
    if jsv_is_undefined(su) {
        return default_unit;
    }
    raw: str = js_to_string_observable(su);
    if vm_has_native_exc() {
        return default_unit;
    }
    s: str = _temporal_unit_normalize(raw);
    if not _temporal_unit_valid(s, False) {
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for smallest unit')
        );
        return default_unit;
    }
    return s;
}

def:pub temporal_get_rounding_increment(options: JSValue) -> int {
    increment: int = 1;
    if jsv_is_undefined(options) {
        return increment;
    }
    if not _temporal_options_is_valid(options) {
        return increment;
    }
    ri: JSValue = js_object_get_observable(
        options, str_intern("roundingIncrement"), options
    );
    if vm_has_native_exc() {
        return increment;
    }
    if jsv_is_undefined(ri) {
        return increment;
    }
    # GetRoundingIncrementOption (ES §): ToNumber(value) — a Symbol throws TypeError,
    # an object runs valueOf; then require finite, TRUNCATE toward zero (2.5 → 2), and
    # RangeError if < 1 or > 1e9. (null → 0 → RangeError; true → 1.)
    n: float = js_to_number_observable(ri);
    if vm_has_native_exc() {
        return 1;
    }
    if n != n or n == MATH_INF or n == -MATH_INF {
        vm_throw_native(make_range_error("invalid roundingIncrement"));
        return 1;
    }
    increment = int(n);  # truncate toward zero
    if increment < 1 or increment > 1000000000 {
        vm_throw_native(make_range_error("invalid roundingIncrement"));
        return 1;
    }
    return increment;
}

def:pub temporal_get_fractional_second_digits(options: JSValue) -> int {
    if jsv_is_undefined(options) {
        return -1;
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return -1;
    }
    fd: JSValue = js_object_get_observable(
        options, str_intern("fractionalSecondDigits"), options
    );
    if vm_has_native_exc() {
        return -1;
    }
    if jsv_is_undefined(fd) {
        return -1;
    }
    # GetTemporalFractionalSecondDigitsOption: a Number is floored and range-checked
    # [0,9]; ANY non-Number value is ToString-coerced and must equal "auto" (else
    # RangeError). The ToString is observable (order-of-operations).
    if jsv_is_int32(fd) {
        n: int = jsv_to_int32(fd);
        if n < 0 or n > 9 {
            vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
            return -1;
        }
        return n;
    }
    if jsv_is_double(fd) {
        nd: float = jsv_to_double(fd);
        if _is_non_finite(nd) {
            vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
            return -1;
        }
        fl: int = int(nd);
        if float(fl) > nd {
            fl = fl - 1;
        }
        if fl < 0 or fl > 9 {
            vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
            return -1;
        }
        return fl;
    }
    s: str = js_to_string_observable(fd);
    if vm_has_native_exc() {
        return -1;
    }
    if s == "auto" {
        return -1;
    }
    vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
    return -1;
}

# ToSecondsStringPrecisionRecord (precision half): returns the fractional-digit code
# for iso_format_time_precision — -2 (minute, omit seconds), 0..9 (that many digits),
# or -1 (auto). smallestUnit, when present, takes precedence over fractionalSecondDigits
# and forbids "hour"/date units. Reads smallestUnit once, then fractionalSecondDigits.
def:pub temporal_time_precision_digits(options: JSValue) -> int {
    if jsv_is_undefined(options) {
        return -1;
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return -1;
    }
    su: JSValue = js_object_get(options, str_intern("smallestUnit"));
    if not jsv_is_undefined(su) {
        raw: str = js_to_string_observable(su);
        if vm_has_native_exc() {
            return -1;
        }
        u: str = _temporal_unit_normalize(raw);
        if u == "minute" {
            return -2;
        }
        if u == "second" {
            return 0;
        }
        if u == "millisecond" {
            return 3;
        }
        if u == "microsecond" {
            return 6;
        }
        if u == "nanosecond" {
            return 9;
        }
        vm_throw_native(
            make_range_error('"' + raw + '" is not a valid value for smallestUnit')
        );
        return -1;
    }
    return temporal_get_fractional_second_digits(options);
}

# Unified toString options read for Instant/PlainDateTime/PlainTime/ZonedDateTime. Reads
# fractionalSecondDigits, then roundingMode, then smallestUnit — the exact observable
# order the order-of-operations tests assert — each exactly ONCE, via the observable
# getters. Returns [precision_digits, round_unit_ns, increment, mode]:
#   precision_digits: -2 minute (omit seconds) / 0..9 / -1 auto  (for iso_format_time_precision)
#   round_unit_ns * increment: the RoundTime step in ns (0 = no rounding)
# smallestUnit overrides fractionalSecondDigits for BOTH precision and rounding, but
# fractionalSecondDigits is still read (and ToString-coerced) first.
def:pub temporal_read_tostring_precision(options: JSValue) -> list[int] {
    if jsv_is_undefined(options) or not jsv_is_any_object(options) {
        return [-1, 0, 1, ROUND_TRUNC];
    }
    # 1. fractionalSecondDigits (read + validated even when smallestUnit overrides).
    frac: int = temporal_get_fractional_second_digits(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC];
    }
    # 2. roundingMode.
    mode: int = temporal_get_rounding_mode(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC];
    }
    # 3. smallestUnit (overrides frac when present).
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC];
    }
    digits: int = frac;
    unit_ns: int = 0;
    increment: int = 1;
    if not jsv_is_undefined(su) {
        raw: str = js_to_string_observable(su);
        if vm_has_native_exc() {
            return [-1, 0, 1, ROUND_TRUNC];
        }
        u: str = _temporal_unit_normalize(raw);
        if u == "minute" {
            digits = -2;
            unit_ns = 60000000000;
        } elif u == "second" {
            digits = 0;
            unit_ns = 1000000000;
        } elif u == "millisecond" {
            digits = 3;
            unit_ns = 1000000;
        } elif u == "microsecond" {
            digits = 6;
            unit_ns = 1000;
        } elif u == "nanosecond" {
            digits = 9;
            unit_ns = 1;
        } else {
            vm_throw_native(
                make_range_error('"' + raw + '" is not a valid value for smallestUnit')
            );
            return [-1, 0, 1, ROUND_TRUNC];
        }
    } elif frac >= 0 {
        # fractionalSecondDigits drives rounding: N digits → round to 10^(9-N) ns.
        if frac == 0 {
            unit_ns = 1000000000;
        } else {
            unit_ns = _dur_pow10(9 - frac);
        }
    }
    return [digits, unit_ns * increment, increment, mode];
}

"""Read the SIX ZonedDateTime.toString options in alphabetical key order — calendarName,
fractionalSecondDigits, offset, roundingMode, smallestUnit, timeZoneName — and return
[precision_digits, step_ns, increment, mode, calName, showOffset, showTz]. The three
string show-options are returned as their raw strings via the parallel out-list
(see the *_str returns). Encapsulated here so the read ORDER stays correct: offset sits
between fractionalSecondDigits and roundingMode, which a plain precision reader can't
express."""
def:pub temporal_read_zdt_tostring(options: JSValue) -> list[any] {
    cal_name: str = "auto";
    show_offset: str = "auto";
    show_tz: str = "auto";
    if jsv_is_undefined(options) {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # 1. calendarName.
    cal_name = temporal_get_calendar_name(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # 2. fractionalSecondDigits.
    frac: int = temporal_get_fractional_second_digits(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # 3. offset.
    show_offset = temporal_get_show_offset(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # 4. roundingMode (default trunc for toString).
    mode: int = temporal_get_rounding_mode(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # 5. smallestUnit — read its raw string now, but DEFER the unit-validity check until
    # after timeZoneName is read (an invalid smallestUnit must not skip that read;
    # options-read-before-algorithmic-validation).
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    su_raw: str = "";
    if not jsv_is_undefined(su) {
        su_raw = js_to_string_observable(su);
        if vm_has_native_exc() {
            return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
        }
    }
    # 6. timeZoneName.
    show_tz = temporal_get_time_zone_name(options);
    if vm_has_native_exc() {
        return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
    }
    # Now resolve/validate the smallestUnit precision.
    digits: int = frac;
    unit_ns: int = 0;
    if len(su_raw) != 0 {
        u: str = _temporal_unit_normalize(su_raw);
        if u == "minute" {
            digits = -2;
            unit_ns = 60000000000;
        } elif u == "second" {
            digits = 0;
            unit_ns = 1000000000;
        } elif u == "millisecond" {
            digits = 3;
            unit_ns = 1000000;
        } elif u == "microsecond" {
            digits = 6;
            unit_ns = 1000;
        } elif u == "nanosecond" {
            digits = 9;
            unit_ns = 1;
        } else {
            vm_throw_native(
                make_range_error(
                    '"' + su_raw + '" is not a valid value for smallestUnit'
                )
            );
            return [-1, 0, 1, ROUND_TRUNC, "auto", "auto", "auto"];
        }
    } elif frac >= 0 {
        if frac == 0 {
            unit_ns = 1000000000;
        } else {
            unit_ns = _dur_pow10(9 - frac);
        }
    }
    return [digits, unit_ns, 1, mode, cal_name, show_offset, show_tz];
}

def:pub temporal_format_duration_to_string(d: list[float], options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return dur_to_string(d);
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "";
    }
    fd: JSValue = js_object_get_observable(
        options, str_intern("fractionalSecondDigits"), options
    );
    if vm_has_native_exc() {
        return "";
    }
    rm: JSValue = js_object_get_observable(
        options, str_intern("roundingMode"), options
    );
    if vm_has_native_exc() {
        return "";
    }
    su: JSValue = js_object_get_observable(
        options, str_intern("smallestUnit"), options
    );
    if vm_has_native_exc() {
        return "";
    }
    frac_digits: int = -1;
    if not jsv_is_undefined(fd) {
        if jsv_is_string_cell(fd) {
            fs: str = temporal_to_string(fd);
            if fs != "auto" {
                vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
                return "";
            }
        } elif jsv_is_int32(fd) {
            frac_digits = jsv_to_int32(fd);
            if frac_digits < 0 or frac_digits > 9 {
                vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
                return "";
            }
        } else {
            # Non-string, non-"auto": GetOption type Number → ToNumber (fires an object's
            # valueOf), then require an integer in [0,9] (floor). NaN/±∞ also reject.
            fn: float = js_to_number_observable(fd);
            if vm_has_native_exc() {
                return "";
            }
            if fn != fn
                or fn == fn + 1.0
                or fn != float(int(fn))
                or fn < 0.0
                or fn > 9.0 {
                vm_throw_native(make_range_error("invalid fractionalSecondDigits"));
                return "";
            }
            frac_digits = int(fn);
        }
    }
    mode: int = ROUND_TRUNC;
    if not jsv_is_undefined(rm) {
        rms: str = js_to_string_observable(rm);
        if vm_has_native_exc() {
            return "";
        }
        if rms != "trunc"
            and rms != "halfExpand"
            and rms != "halfTrunc"
            and rms != "halfEven"
            and rms != "halfCeil"
            and rms != "halfFloor"
            and rms != "ceil"
            and rms != "floor"
            and rms != "expand" {
            vm_throw_native(make_range_error("invalid roundingMode"));
            return "";
        }
        mode = rounding_mode_from_string(rms);
    }
    has_smallest: bool = not jsv_is_undefined(su);
    smallest: str = "nanosecond";
    if has_smallest {
        raw: str = js_to_string_observable(su);
        if vm_has_native_exc() {
            return "";
        }
        smallest = _temporal_unit_normalize(raw);
        if not _temporal_unit_valid(smallest, False) {
            vm_throw_native(
                make_range_error('"' + raw + '" is not a valid value for smallest unit')
            );
            return "";
        }
        # Duration.toString's smallestUnit is restricted to second and below — a
        # calendar/hour/minute unit is a RangeError (only fractional-second precision
        # is expressible in the ISO 8601 duration string).
        if smallest != "second"
            and smallest != "millisecond"
            and smallest != "microsecond"
            and smallest != "nanosecond" {
            vm_throw_native(
                make_range_error('"' + raw + '" is not a valid value for smallestUnit')
            );
            return "";
        }
    }
    round_unit: str = smallest;
    increment: int = 1;
    if not has_smallest {
        if frac_digits == 0 {
            round_unit = "second";
        } elif frac_digits > 0 {
            round_unit = "nanosecond";
            increment = _dur_pow10(9 - frac_digits);
        }
    }
    rounded: list[float] = dur_round_preserve_calendar(d, round_unit, increment, mode);
    # When smallestUnit is absent the precision is driven by fractionalSecondDigits — pass
    # format_unit "" (auto) so the formatter trims trailing zeros instead of padding to a
    # fixed unit width (a bare toString/toJSON shows "…7S", not "…7.000000000S").
    format_unit: str = "";
    format_digits: int = frac_digits;
    if has_smallest {
        format_unit = smallest;
        format_digits = -1;
    }
    return dur_to_string_with_options(
        rounded, format_unit, format_digits, has_smallest
    );
}

def:pub temporal_apply_time_rounding(
    h: int, mi: int, s: int, ns: int, options: JSValue
) -> list[int] {
    r: list[int] = temporal_apply_time_rounding_carry(h, mi, s, ns, options);
    return [r[0], r[1], r[2], r[3]];
}

# RoundTime for toString. Rounds the wall-clock to the unit implied by smallestUnit OR
# (when smallestUnit absent) fractionalSecondDigits — the latter ALSO rounds, at a
# nanosecond increment of 10^(9-digits) (e.g. 6 digits → round to microsecond). Returns
# [h, mi, s, ns, day_carry]; a rounding that reaches the next day (23:59:59.9…→next 00:00)
# reports day_carry = 1 so the caller can advance the date (rounding-cross-midnight).
def:pub temporal_apply_time_rounding_carry(
    h: int, mi: int, s: int, ns: int, options: JSValue
) -> list[int] {
    if jsv_is_undefined(options) or not jsv_is_any_object(options) {
        return [h, mi, s, ns, 0];
    }
    su: JSValue = js_object_get(options, str_intern("smallestUnit"));
    has_su: bool = not jsv_is_undefined(su);
    round_unit: str = "nanosecond";
    increment: int = 1;
    if has_su {
        round_unit = temporal_get_smallest_unit(options);
        if vm_has_native_exc() {
            return [h, mi, s, ns, 0];
        }
    } else {
        frac: int = temporal_get_fractional_second_digits(options);
        if vm_has_native_exc() {
            return [h, mi, s, ns, 0];
        }
        if frac < 0 {
            return [h, mi, s, ns, 0];
        }
        if frac == 0 {
            round_unit = "second";
        } else {
            round_unit = "nanosecond";
            increment = _dur_pow10(9 - frac);
        }
    }
    mode: int = temporal_get_rounding_mode(options);
    if vm_has_native_exc() {
        return [h, mi, s, ns, 0];
    }
    # Round the whole-day nanosecond total to the increment, then re-decompose; a total
    # that reaches 86400e9 is one full day of carry.
    unit_ns: int = _temporal_time_unit_ns(round_unit) * increment;
    if unit_ns <= 0 {
        return [h, mi, s, ns, 0];
    }
    total: int = iso_total_nanoseconds(h, mi, s, ns);
    rounded_total: int = _temporal_round_int_to_increment(total, unit_ns, mode);
    day_carry: int = 0;
    if rounded_total >= 86400000000000 {
        day_carry = rounded_total // 86400000000000;
        rounded_total = rounded_total - day_carry * 86400000000000;
    }
    t: list[int] = iso_nanoseconds_to_time(rounded_total);
    return [t[0], t[1], t[2], t[3], day_carry];
}

def:priv _temporal_time_unit_ns(unit: str) -> int {
    if unit == "hour" {
        return 3600000000000;
    }
    if unit == "minute" {
        return 60000000000;
    }
    if unit == "second" {
        return 1000000000;
    }
    if unit == "millisecond" {
        return 1000000;
    }
    if unit == "microsecond" {
        return 1000;
    }
    if unit == "nanosecond" {
        return 1;
    }
    return 0;
}

# Round a non-negative integer to a multiple of `inc` per the given rounding mode
# (subset used by RoundTime: trunc/expand/ceil/floor/half*).
def:priv _temporal_round_int_to_increment(v: int, inc: int, mode: int) -> int {
    q: int = v // inc;
    r: int = v - q * inc;
    if r == 0 {
        return v;
    }
    lo: int = q * inc;
    hi: int = lo + inc;
    if mode == ROUND_TRUNC or mode == ROUND_FLOOR {
        return lo;
    }
    if mode == ROUND_EXPAND or mode == ROUND_CEIL {
        return hi;
    }
    # half-* modes: compare the remainder to half the increment.
    twice: int = r * 2;
    if twice < inc {
        return lo;
    }
    if twice > inc {
        return hi;
    }
    # Exactly halfway.
    if mode == ROUND_HALF_TRUNC or mode == ROUND_HALF_FLOOR {
        return lo;
    }
    if mode == ROUND_HALF_EVEN {
        if (q % 2) == 0 {
            return lo;
        }
        return hi;
    }
    return hi;
}

def:pub temporal_epoch_ns_to_utc_parts(ns: list[int]) -> list[int] {
    neg: bool = False;
    if bn_sign(ns) < 0 {
        neg = True;
    }
    abs_ns: list[int] = ns;
    if neg {
        abs_ns = bn_neg(ns);
    }
    q: list[int] = bn_divmod(abs_ns, bn_from_int(1000000000));
    abs_epoch_s: int = int(bn_to_string(q, 10));
    abs_rem_ns: int = int(bn_to_string(_BN_DIV_REM, 10));
    # Convert |ns| = abs_epoch_s*1e9 + abs_rem_ns into FLOOR-division (epoch_s, rem_ns)
    # with rem_ns in [0, 1e9). For a negative instant the true value is -(|ns|); flooring
    # borrows a whole second when there is a sub-second remainder (the previous code
    # mis-normalized this, rendering pre-1970 instants as their positive mirror — e.g.
    # -161 days showed as 1970-06-12 instead of 1969-07-24).
    epoch_s: int = abs_epoch_s;
    rem_ns: int = abs_rem_ns;
    if neg {
        epoch_s = -abs_epoch_s;
        rem_ns = -abs_rem_ns;
        if rem_ns < 0 {
            rem_ns = rem_ns + 1000000000;
            epoch_s = epoch_s - 1;
        }
    }
    # Jac `//` is floor division and `%` is non-negative for a positive divisor
    # (verified native: -217000000//86400 == -2512, %==36800), so epoch_s//86400
    # is ALREADY the floored day index. The old `if epoch_s<0 ... days=days-1`
    # correction assumed truncation-toward-zero and double-borrowed, rendering
    # every pre-1970 instant one day early (1963-02-15 → 1963-02-14).
    days: int = epoch_s // 86400;
    sec_in_day: int = epoch_s - days * 86400;
    ymd: list[int] = iso_ymd_from_days(days);
    day_ns: int = sec_in_day * 1000000000 + rem_ns;
    t: list[int] = iso_nanoseconds_to_time(day_ns);
    return [ymd[0], ymd[1], ymd[2], t[0], t[1], t[2], t[3]];
}

def:pub temporal_dur_from_ns_diff(diff: list[int]) -> list[float] {
    neg: int = 0;
    if bn_sign(diff) < 0 {
        neg = 1;
    }
    abs_ns: list[int] = diff;
    if neg != 0 {
        abs_ns = bn_neg(diff);
    }
    q: list[int] = bn_divmod(abs_ns, bn_from_int(86400000000000));
    days: int = int(bn_to_string(q, 10));
    rem_ns: int = int(bn_to_string(_BN_DIV_REM, 10));
    h: int = rem_ns // 3600000000000;
    rem2: int = rem_ns % 3600000000000;
    mi: int = rem2 // 60000000000;
    rem3: int = rem2 % 60000000000;
    sc: int = rem3 // 1000000000;
    n: int = rem3 % 1000000000;
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, float(days), float(h), float(mi), float(sc), float(n)
    );
    if neg != 0 {
        dur[DUR_SIGN] = -1.0;
    }
    return dur_balance(dur);
}

def:pub temporal_epoch_ns_from_duration(d: list[float]) -> list[int] {
    sgn: int = dur_sign(d);
    total: list[int] = bn_zero();
    total = bn_add(total, bn_mul_small(bn_from_int(int(d[DUR_DAYS])), 86400000000000));
    total = bn_add(total, bn_mul_small(bn_from_int(int(d[DUR_HOURS])), 3600000000000));
    total = bn_add(total, bn_mul_small(bn_from_int(int(d[DUR_MINUTES])), 60000000000));
    total = bn_add(total, bn_mul_small(bn_from_int(int(d[DUR_SECONDS])), 1000000000));
    total = bn_add(total, bn_from_int(int(d[DUR_NANOSECONDS])));
    if sgn < 0 {
        return bn_neg(total);
    }
    return total;
}

"""Maximum roundingIncrement for Instant.round(unit) — MaximumTemporalDuration-
RoundingIncrement relative to a 24h day (§Temporal.Instant.prototype.round): the
increment must be < this maximum and divide it evenly. hour→24, minute→1440, … ns→
86400e9. Returns 0 for a non-time unit (Instant rejects those earlier)."""
def:pub temporal_instant_round_max_increment(unit: str) -> int {
    u: str = _temporal_unit_normalize(unit);  # accept plural names ("microseconds")
    if u == "day" {
        return 1;
    }
    if u == "hour" {
        return 24;
    }
    if u == "minute" {
        return 1440;
    }
    if u == "second" {
        return 86400;
    }
    if u == "millisecond" {
        return 86400000;
    }
    if u == "microsecond" {
        return 86400000000;
    }
    if u == "nanosecond" {
        return 86400000000000;
    }
    return 0;
}

"""Nanoseconds in one of the Instant/time round units, else 0."""
def:priv _temporal_unit_ns_magnitude(unit: str) -> int {
    if unit == "hour" {
        return 3600000000000;
    }
    if unit == "minute" {
        return 60000000000;
    }
    if unit == "second" {
        return 1000000000;
    }
    if unit == "millisecond" {
        return 1000000;
    }
    if unit == "microsecond" {
        return 1000;
    }
    if unit == "nanosecond" {
        return 1;
    }
    return 0;
}

"""Round an EXACT epoch-nanosecond bignum to a multiple of `step` (a positive int),
applying the ECMAScript RoundNumberToIncrement rounding mode. Kept entirely in
bignum integer space — the previous float64 duration round lost precision above 2^53
(Instant/round: 1_000_000_000_123_987_500 became …986944). `x` and the result are
signed limb-bignums; `_BN_DIV_REM` holds the remainder after each bn_divmod."""
def:priv _temporal_bn_round_to_step(x: list[int], step: int, mode: int) -> list[int] {
    if step <= 1 {
        return x;
    }
    step_bn: list[int] = bn_from_int(step);
    neg: bool = bn_sign(x) < 0;
    mag: list[int] = x;
    if neg {
        mag = bn_neg(x);
    }
    q: list[int] = bn_divmod(mag, step_bn);  # floor(|x| / step)
    rem: list[int] = _BN_DIV_REM;  # |x| mod step (0 <= rem < step)
    if bn_is_zero(rem) {
        return x;
    }  # already a multiple
    # low = q*step (toward zero), high = (q+1)*step (away from zero), in magnitude.
    low: list[int] = bn_mul_small(q, step);
    high: list[int] = bn_add(low, step_bn);
    # Decide whether the magnitude rounds up to `high` or down to `low`.
    round_up: bool = False;
    # ceil/floor act in signed space: ceil rounds toward +inf, floor toward -inf
    # (so for a negative value, ceil rounds the magnitude DOWN, floor rounds it UP).
    if mode == ROUND_CEIL {
        round_up = not neg;
    } elif mode == ROUND_FLOOR {
        round_up = neg;
    } elif mode == ROUND_EXPAND {
        round_up = True;
    } elif mode == ROUND_TRUNC {
        round_up = False;
    } else {
        # Half modes: compare 2*rem to step.
        two_rem: list[int] = bn_mul_small(rem, 2);
        c: int = bn_cmp(two_rem, step_bn);  # <0 below half, 0 exactly half, >0 above
        if c > 0 {
            round_up = True;
        } elif c < 0 {
            round_up = False;
        } else {
            # Exactly halfway.
            if mode == ROUND_HALF_EXPAND {
                round_up = True;
            } elif mode == ROUND_HALF_TRUNC {
                round_up = False;
            } elif mode == ROUND_HALF_CEIL {
                round_up = not neg;
            } elif mode == ROUND_HALF_FLOOR {
                round_up = neg;
            } elif mode == ROUND_HALF_EVEN {
                # Round to the even multiple: q even → down, q odd → up.
                qd: list[int] = bn_divmod(q, bn_from_int(2));
                _ = qd;
                round_up = not bn_is_zero(_BN_DIV_REM);
            }
        }
    }
    result_mag: list[int] = low;
    if round_up {
        result_mag = high;
    }
    if neg {
        return bn_neg(result_mag);
    }
    return result_mag;
}

def:pub temporal_round_epoch_ns(
    ns: list[int], unit: str, increment: int, mode: int
) -> list[int] {
    # Accept plural unit names ("microseconds") — some callers pass the raw option.
    step_ns: int = _temporal_unit_ns_magnitude(_temporal_unit_normalize(unit));
    if step_ns == 0 {
        # Non-time unit (should not reach here for Instant); fall back to the
        # duration-based path.
        dur: list[float] = temporal_dur_from_ns_diff(ns);
        rounded: list[float] = dur_round(dur, unit, increment, mode);
        return temporal_epoch_ns_from_duration(rounded);
    }
    step: int = step_ns * increment;
    return _temporal_bn_round_to_step(ns, step, mode);
}

def:pub temporal_round_time_ns(
    total_ns: int, unit: str, increment: int, mode: int
) -> int {
    h: int = total_ns // 3600000000000;
    rem: int = total_ns % 3600000000000;
    mi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    sc: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, 0.0, float(h), float(mi), float(sc), float(n)
    );
    rounded: list[float] = dur_round(dur, unit, increment, mode);
    return int(dur_total(rounded, "nanoseconds"));
}

# Round (h,mi,s,ns) to `step_ns` (0 = no rounding) with `mode`, returning
# [h, mi, s, ns, day_carry] where day_carry counts whole days rolled over.
def:pub _temporal_round_wallclock(
    h: int, mi: int, s: int, ns: int, step_ns: int, mode: int
) -> list[int] {
    if step_ns <= 0 {
        return [h, mi, s, ns, 0];
    }
    total: int = iso_total_nanoseconds(h, mi, s, ns);
    rt: int = _temporal_round_int_to_increment(total, step_ns, mode);
    carry: int = 0;
    if rt >= 86400000000000 {
        carry = rt // 86400000000000;
        rt = rt - carry * 86400000000000;
    }
    t: list[int] = iso_nanoseconds_to_time(rt);
    return [t[0], t[1], t[2], t[3], carry];
}

def:pub temporal_format_instant_to_string(ns: list[int], options: JSValue) -> str {
    prec: list[int] = temporal_read_tostring_precision(options);
    if vm_has_native_exc() {
        return "";
    }
    return temporal_format_instant_to_string_prec(
        ns, prec[0], prec[1], prec[3], False, ""
    );
}

# Format an Instant with precision/rounding ALREADY resolved (digits, round step ns,
# mode). When has_tz, render the wall-clock in `tz` with an offset suffix instead of the
# UTC "Z" designator (Temporal.Instant.prototype.toString timeZone option).
def:pub temporal_format_instant_to_string_prec(
    ns: list[int], digits: int, step_ns: int, mode: int, has_tz: bool, tz: str
) -> str {
    # Round in epoch-ns space so a tz offset applies to the rounded instant.
    rounded_ns: list[int] = ns;
    if step_ns > 0 {
        rounded_ns = _temporal_bn_round_to_step(ns, step_ns, mode);
    }
    parts: list[int] = temporal_epoch_ns_to_utc_parts(rounded_ns);
    off_s: int = 0;
    if has_tz {
        # Shift the UTC parts into the zone: get the zone offset at this instant, add it,
        # and re-decompose. temporal_offset_ns_for_zone returns nanoseconds.
        off_ns2: int = temporal_offset_ns_for_zone(
            tz, parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]
        );
        off_s = off_ns2 // 1000000000;
        utc_days: int = iso_days_from_ymd(parts[0], parts[1], parts[2]);
        local_total: int = (
            utc_days * 86400 + parts[3] * 3600 + parts[4] * 60 + parts[5]
        )
            * 1000000000
            + parts[6]
            + off_ns2;
        ldays: int = local_total // 86400000000000;
        rem: int = local_total - ldays * 86400000000000;
        if rem < 0 {
            rem = rem + 86400000000000;
            ldays = ldays - 1;
        }
        lymd: list[int] = iso_ymd_from_days(ldays);
        lt: list[int] = iso_nanoseconds_to_time(rem);
        parts = [lymd[0], lymd[1], lymd[2], lt[0], lt[1], lt[2], lt[3]];
    }
    s: str = iso_format_date(parts[0], parts[1], parts[2]);
    s = s
        + "T"
        + iso_format_time_precision(parts[3], parts[4], parts[5], parts[6], digits);
    if has_tz {
        s = s + temporal_format_offset_ns(off_s);
    } else {
        s = s + "Z";
    }
    return s;
}

def:pub temporal_format_time_to_string(
    h: int, mi: int, s: int, ns: int, options: JSValue
) -> str {
    prec: list[int] = temporal_read_tostring_precision(options);
    if vm_has_native_exc() {
        return "";
    }
    rc: list[int] = _temporal_round_wallclock(h, mi, s, ns, prec[1], prec[3]);
    # PlainTime wraps around the day (a cross-midnight carry is discarded — the value is
    # a wall-clock time, not a datetime).
    return iso_format_time_precision(rc[0], rc[1], rc[2], rc[3], prec[0]);
}

# "YYYY-MM-DDTHH:MM:SS" for PlainDateTime/ZonedDateTime toString, applying RoundTime and
# carrying a cross-midnight rounding into the DATE (23:59:59.9…→next day 00:00). Returns
# just the date+"T"+time; callers append offset/timezone/calendar suffixes.
def:pub temporal_format_datetime_to_string(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, options: JSValue
) -> str {
    prec: list[int] = temporal_read_tostring_precision(options);
    if vm_has_native_exc() {
        return "";
    }
    rc: list[int] = _temporal_round_wallclock(h, mi, s, ns, prec[1], prec[3]);
    if rc[4] != 0 {
        nd: list[int] = iso_ymd_from_days(iso_days_from_ymd(y, m, d) + rc[4]);
        y = nd[0];
        m = nd[1];
        d = nd[2];
    }
    return iso_format_date(y, m, d)
        + "T"
        + iso_format_time_precision(rc[0], rc[1], rc[2], rc[3], prec[0]);
}

# Difference unit ranking for GetDifferenceSettings ordering (larger unit = larger
# number). Kept local so `temporal_resolve_difference_units` can enforce
# largestUnit ≥ smallestUnit and group membership without pulling in duration math.
def:priv _temporal_diff_unit_rank(u: str) -> int {
    if u == "year" {
        return 9;
    }
    if u == "month" {
        return 8;
    }
    if u == "week" {
        return 7;
    }
    if u == "day" {
        return 6;
    }
    if u == "hour" {
        return 5;
    }
    if u == "minute" {
        return 4;
    }
    if u == "second" {
        return 3;
    }
    if u == "millisecond" {
        return 2;
    }
    if u == "microsecond" {
        return 1;
    }
    if u == "nanosecond" {
        return 0;
    }
    return -1;
}

# True when `u` belongs to `group`: "date" = year..day, "time" = hour..nanosecond,
# "datetime" = any. A since/until whose type only spans one group (PlainDate = date,
# PlainTime = time) must RangeError on an out-of-group largest/smallestUnit.
def:priv _temporal_unit_in_group(u: str, group: str) -> bool {
    if group == "datetime" {
        return True;
    }
    rank: int = _temporal_diff_unit_rank(u);
    if group == "date" {
        return rank >= 6;
    }
    if group == "time" {
        return rank >= 0 and rank <= 5;
    }
    # PlainYearMonth difference: year/month only (week and day are disallowed).
    if group == "yearmonth" {
        return u == "year" or u == "month";
    }
    return True;
}

def:pub temporal_resolve_difference_units(
    options: JSValue, default_largest: str, default_smallest: str
) -> list[str] {
    return temporal_resolve_difference_units_grouped(
        options, default_largest, default_smallest, "datetime"
    );
}

# GetDifferenceSettings — reads smallestUnit then largestUnit EXACTLY once each (spec
# order), rejecting out-of-`group` units and largestUnit < smallestUnit. `unit_group`
# is the type's span: "date" (PlainDate/PlainYearMonth), "time" (PlainTime), or
# "datetime" (PlainDateTime/ZonedDateTime/Instant). Callers must resolve units through
# THIS single call — a separate `temporal_get_largest_unit` before the rounding step
# double-reads largestUnit and fails order-of-operations tests.
def:pub temporal_resolve_difference_units_grouped(
    options: JSValue, default_largest: str, default_smallest: str, unit_group: str
) -> list[str] {
    # Legacy path (callers not yet migrated to temporal_read_difference_settings): read
    # ONLY smallestUnit then largestUnit, leaving roundingIncrement/roundingMode to the
    # rounding step. Kept unchanged so un-migrated since/until callers behave exactly as
    # before — do NOT route this through the four-option reader (it would read
    # increment/mode twice for those callers and change wrong-type error ordering).
    smallest: str = temporal_get_smallest_unit_default(options, default_smallest);
    if vm_has_native_exc() {
        return [default_largest, default_smallest];
    }
    if not _temporal_unit_in_group(smallest, unit_group) {
        vm_throw_native(
            make_range_error('"' + smallest + '" is not a valid value for smallestUnit')
        );
        return [default_largest, default_smallest];
    }
    largest: str = temporal_get_largest_unit(options);
    if vm_has_native_exc() {
        return [default_largest, smallest];
    }
    if largest != "auto" and not _temporal_unit_in_group(largest, unit_group) {
        vm_throw_native(
            make_range_error('"' + largest + '" is not a valid value for largestUnit')
        );
        return [default_largest, smallest];
    }
    if largest == "auto" {
        largest = default_largest;
        if _temporal_diff_unit_rank(smallest) > _temporal_diff_unit_rank(largest) {
            largest = smallest;
        }
    } else {
        if _temporal_diff_unit_rank(largest) < _temporal_diff_unit_rank(smallest) {
            vm_throw_native(
                make_range_error(
                    "Can't use "
                        + largest
                        + " and "
                        + smallest
                        + " as largestUnit and smallestUnit"
                )
            );
            return [largest, smallest];
        }
    }
    return [largest, smallest];
}

"""GetDifferenceSettings — reads all four difference options in ALPHABETICAL key order
(largestUnit, roundingIncrement, roundingMode, smallestUnit), which the
order-of-operations traces require, validates them, and returns
[largestUnit, smallestUnit, roundingIncrement(as str), roundingMode(as str)]. The
increment/mode are read HERE (not later in the rounding step) so they fire in the
correct position; callers thread them into temporal_apply_difference_rounding_resolved."""
def:pub temporal_read_difference_settings(
    options: JSValue, default_largest: str, default_smallest: str, unit_group: str
) -> list[str] {
    # ALL FOUR options are READ (getters fire) in alphabetical order BEFORE any
    # algorithmic validation — a unit that is valid-as-a-name but wrong for this
    # difference's unit group must not short-circuit the later reads
    # (options-read-before-algorithmic-validation). The individual getters still throw
    # for a genuinely-invalid unit NAME or an out-of-range increment; only the
    # group-membership and largest≥smallest checks are deferred to the end.
    # 1. largestUnit.
    largest: str = temporal_get_largest_unit(options);
    if vm_has_native_exc() {
        return [default_largest, default_smallest, "1", "trunc"];
    }
    # 2. roundingIncrement.
    increment: int = temporal_get_rounding_increment(options);
    if vm_has_native_exc() {
        return [default_largest, default_smallest, "1", "trunc"];
    }
    # 3. roundingMode.
    mode: int = temporal_get_rounding_mode(options);
    if vm_has_native_exc() {
        return [default_largest, default_smallest, "1", "trunc"];
    }
    # 4. smallestUnit.
    smallest: str = temporal_get_smallest_unit_default(options, default_smallest);
    if vm_has_native_exc() {
        return [default_largest, default_smallest, "1", "trunc"];
    }
    # Now validate unit-group membership (deferred so all reads happen first).
    if largest != "auto" and not _temporal_unit_in_group(largest, unit_group) {
        vm_throw_native(
            make_range_error('"' + largest + '" is not a valid value for largestUnit')
        );
        return [default_largest, default_smallest, "1", "trunc"];
    }
    if not _temporal_unit_in_group(smallest, unit_group) {
        vm_throw_native(
            make_range_error('"' + smallest + '" is not a valid value for smallestUnit')
        );
        return [default_largest, default_smallest, "1", "trunc"];
    }
    # A resolved (non-auto) largestUnit must be ≥ smallestUnit; an absent/auto one
    # defaults to LargerOfTwo(defaultLargest, smallest) so it is never below smallest.
    if largest == "auto" {
        largest = default_largest;
        if _temporal_diff_unit_rank(smallest) > _temporal_diff_unit_rank(largest) {
            largest = smallest;
        }
    } else {
        if _temporal_diff_unit_rank(largest) < _temporal_diff_unit_rank(smallest) {
            vm_throw_native(
                make_range_error(
                    "Can't use "
                        + largest
                        + " and "
                        + smallest
                        + " as largestUnit and smallestUnit"
                )
            );
            return [largest, smallest, str(increment), rounding_mode_to_string(mode)];
        }
    }
    return [largest, smallest, str(increment), rounding_mode_to_string(mode)];
}

"""Reject a calendar-unit difference rounding whose endpoint (`anchor ± increment`
units) falls outside the ISO date range (~±271821 years). Approximated in day space:
the endpoint is at least `increment * min-days-per-unit` days from the anchor, so if
that reaches beyond either ISO bound it cannot be a valid date. Conservative (never
rejects an in-range endpoint): uses the SMALLEST days-per-unit so the day delta is a
lower bound on |endpoint - anchor|."""
def:priv _temporal_reject_calendar_round_endpoint(
    unit: str, increment: int, y: int, m: int, d: int
) -> None {
    per: int = 0;
    if unit == "year" or unit == "years" {
        per = 365;
    } elif unit == "month" or unit == "months" {
        per = 28;
    } elif unit == "week" or unit == "weeks" {
        per = 7;
    }
    # NOTE: "day" is intentionally excluded. Day-unit rounding operates in absolute day
    # space (no calendar-relative endpoint is reconstructed), so a huge day increment just
    # produces a large-but-valid Duration (`until` with roundingIncrement 1e9, smallestUnit
    # "days" → 1e9 days) — it must NOT be rejected as an out-of-range date.
    else {
        return;
    }
    anchor_days: int = iso_days_from_ymd(y, m, d);
    min_day: int = iso_days_from_ymd(-271821, 4, 20);
    max_day: int = iso_days_from_ymd(275760, 9, 13);
    delta: int = increment * per;
    # Either rounding direction: anchor+delta or anchor-delta must stay in [min,max]
    # for the endpoint to be constructible; if BOTH overshoot, it is out of range.
    if (anchor_days + delta) > max_day and (anchor_days - delta) < min_day {
        vm_throw_native(make_range_error("rounded date is out of range"));
    }
}

def:pub temporal_apply_difference_rounding(
    raw: list[float],
    options: JSValue,
    default_largest: str,
    default_smallest: str,
    has_anchor: bool,
    ay: int,
    am: int,
    ad: int,
    ah: int,
    ami: int,
    asec: int,
    ans: int
) -> list[float] {
    units: list[str] = temporal_resolve_difference_units(
        options, default_largest, default_smallest
    );
    if vm_has_native_exc() {
        return raw;
    }
    return temporal_apply_difference_rounding_resolved(
        raw, options, units[0], units[1], has_anchor, ay, am, ad, ah, ami, asec, ans
    );
}

# Rounding half of GetDifferenceSettings + RoundRelativeDuration, with largestUnit and
# smallestUnit ALREADY resolved (so they are not read from `options` a second time —
# order-of-operations). Reads only roundingMode and roundingIncrement from `options`.
def:pub temporal_apply_difference_rounding_resolved(
    raw: list[float],
    options: JSValue,
    largest: str,
    smallest: str,
    has_anchor: bool,
    ay: int,
    am: int,
    ad: int,
    ah: int,
    ami: int,
    asec: int,
    ans: int,
    pre_increment: int = -1,
    pre_mode: int = -1
) -> list[float] {
    # roundingIncrement/roundingMode are normally supplied pre-read by
    # temporal_read_difference_settings (so they fire in the correct alphabetical order
    # up-front). pre_* < 0 means "not supplied" — fall back to reading them here (kept
    # for any caller not yet threading the settings through).
    mode: int = pre_mode;
    if pre_mode < 0 {
        mode = temporal_get_rounding_mode(options);
        if vm_has_native_exc() {
            return raw;
        }
    }
    increment: int = pre_increment;
    if pre_increment < 0 {
        increment = temporal_get_rounding_increment(options);
        if vm_has_native_exc() {
            return raw;
        }
    }
    # ValidateTemporalRoundingIncrement for a since/until DIFFERENCE: time units have a
    # per-unit maximum (must divide the next-larger unit), but date units (year/month/
    # week/day) allow ANY integer increment ≥ 1 — `since({smallestUnit:"years",
    # roundingIncrement:4})` is valid. So only the time-unit maximum is enforced here.
    diff_max: int = dur_max_rounding_increment(smallest);
    if diff_max >= 0 {
        dur_validate_rounding_increment(increment, diff_max, False);
        if vm_has_native_exc() {
            return raw;
        }
    } elif has_anchor and increment > 1 {
        # Calendar smallestUnit (year/month/week/day): rounding evaluates the endpoint
        # `anchor + sign*increment*unit`. A huge increment pushes that endpoint outside
        # the ISO date range (~±271821 years) → RangeError, before rounding truncates
        # back (since/until throws-if-rounded-date-outside-valid-iso-range).
        _temporal_reject_calendar_round_endpoint(smallest, increment, ay, am, ad);
        if vm_has_native_exc() {
            return raw;
        }
    }
    cal_anchor: bool = has_anchor;
    limited: list[float] = dur_limit_largest_unit(
        raw, largest, cal_anchor, ay, am, ad, ah, ami, asec, ans
    );
    if vm_has_native_exc() {
        return raw;
    }
    round_anchor: bool = cal_anchor;
    if smallest == "year" or smallest == "month" or smallest == "week" {
        round_anchor = True;
    }
    # RoundDuration no-op fast path. `dur_round_difference` totals the whole duration into
    # `smallest` and rebuilds — which FLATTENS a calendar breakdown (3Y 6M 17D with
    # smallestUnit "day" totals to 1295 days; with smallestUnit "nanosecond" — the
    # PlainDateTime since/until default — to hours). When increment == 1 and there is no
    # sub-`smallest` remainder to round, RoundDuration returns the duration unchanged, so
    # keep the y/m/w/d structure `dur_limit_largest_unit` produced. Applies whenever the
    # result carries a calendar component (largestUnit ≥ week) — the flatten only matters
    # then; a pure time diff has no structure to preserve and takes the real total.
    # Applies for ANY largestUnit that keeps a day-or-larger component (day/week/month/
    # year): those carry a structure the flatten destroys, and — critically — a large
    # multi-day span totalled into nanoseconds exceeds 2^53 and loses precision as a
    # float64 (a 15684-day PlainDateTime diff came back 21ns off). A pure time-only diff
    # (largest ≤ hour) has no structure and stays small, so it takes the real total.
    largest_keeps_days: bool = largest == "day"
        or largest == "week"
        or largest == "month"
        or largest == "year";
    if cal_anchor
        and increment == 1
        and largest_keeps_days
        and _dur_no_subunit_remainder(limited, smallest) {
        rounded_noop: list[float] = dur_limit_largest_unit(
            limited, largest, cal_anchor, ay, am, ad, ah, ami, asec, ans
        );
        if vm_has_native_exc() {
            return raw;
        }
        dur_reject_out_of_range(rounded_noop);
        if vm_has_native_exc() {
            return raw;
        }
        return rounded_noop;
    }
    rounded: list[float] = dur_round_difference(
        limited, smallest, increment, mode, round_anchor, ay, am, ad, ah, ami, asec, ans
    );
    if vm_has_native_exc() {
        return raw;
    }
    # `dur_round_difference` totals into the smallest unit then rebuilds via
    # `dur_from_unit_total`, whose time-balance stops at HOURS (never folds
    # hours→days). For a day/week/month/year largestUnit that drops the day+
    # component (e.g. a 1-day PlainDateTime diff came back as "24 hours, 0 days").
    # Re-apply the largest-unit balancing so hours fold back into days/weeks and
    # the calendar structure is restored (PlainDateTime since/until, balance-*).
    if smallest != "year" and smallest != "month" and smallest != "week" {
        rounded = dur_limit_largest_unit(
            rounded, largest, cal_anchor, ay, am, ad, ah, ami, asec, ans
        );
        if vm_has_native_exc() {
            return raw;
        }
    }
    # Bubble months up into years when the largestUnit is "year": rounding to a calendar
    # smallestUnit (e.g. months) can leave a month magnitude ≥ 12 that must carry into
    # years (since("…", {largestUnit:"years", smallestUnit:"months"}): -23 months →
    # -1 year -11 months; -24 → -2 years). For the ISO calendar 12 months == 1 year
    # exactly, so this fold is anchor-independent.
    if largest == "year" {
        yrs: float = rounded[DUR_YEARS];
        mos: float = rounded[DUR_MONTHS];
        carry: float = float(int(mos / 12.0));
        if carry != 0.0 {
            rounded[DUR_YEARS] = yrs + carry;
            rounded[DUR_MONTHS] = mos - carry * 12.0;
        }
    }
    # A large roundingIncrement can round a difference to a Duration whose components
    # exceed the valid range (since/until throws-if-rounded-date-outside-valid-iso-range).
    dur_reject_out_of_range(rounded);
    if vm_has_native_exc() {
        return raw;
    }
    return rounded;
}

def:pub temporal_parse_calendar(v: JSValue) -> str {
    if jsv_is_undefined(v) {
        return "iso8601";
    }
    if jsv_is_null(v) {
        vm_throw_native(make_type_error("invalid calendar"));
        return "iso8601";
    }
    if js_is_plain_date(v)
        or js_is_plain_datetime(v)
        or js_is_plain_month_day(v)
        or js_is_plain_year_month(v)
        or js_is_zoned_datetime(v) {
        return _get_str_slot(v, KEY_CALENDAR);
    }
    if not jsv_is_string_cell(v) {
        vm_throw_native(make_type_error("invalid calendar"));
        return "iso8601";
    }
    s: str = temporal_to_string(v);
    if len(s) == 0 {
        vm_throw_native(make_range_error("invalid calendar"));
        return "iso8601";
    }
    ann: str = extract_calendar_annotation(s);
    if len(ann) > 0 {
        if not calendar_is_known(ann) {
            vm_throw_native(make_range_error("invalid calendar"));
            return "iso8601";
        }
        return ann;
    }
    pr: list[any] = parse_iso_date_time(s);
    if pr[PR_OK] and pr[PR_HAS_DATE] {
        pr_cal: str = PR_S_CALENDAR;
        if len(pr_cal) > 0 and calendar_is_known(pr_cal) {
            return pr_cal;
        }
        return "iso8601";
    }
    cid: str = calendar_id_from_string(s);
    if not calendar_is_known(cid) {
        if iso_string_is_calendar_identifier(s) {
            return "iso8601";
        }
        vm_throw_native(make_range_error("invalid calendar"));
        return "iso8601";
    }
    return cid;
}

"""True if `s` is exactly a bare year-month "YYYY-MM": 4 ASCII digits, "-", then a
2-digit month 01-12. No sign, no day, no other text — used to gate the day-less
PlainYearMonth string retry so invalid forms ("2020-13", "+999999-01") still reject."""
def:priv _temporal_is_year_month_shape(s: str) -> bool {
    return len(_temporal_year_month_ref_day_str(s)) != 0;
}

"""Given the date portion of a day-less TemporalYearMonthString, return that portion
with a reference day appended so the full date-time parser accepts it, or "" if it is
not a valid year-month shape. Handles all four ISO forms: extended "YYYY-MM", basic
"YYYYMM", and their expanded-year variants "±YYYYYY-MM" / "±YYYYYYMM". The reference
day is appended in the SAME format (extended → "-01", basic → "01") so the retry
string stays well-formed."""
def:priv _temporal_year_month_ref_day_str(s: str) -> str {
    n: int = len(s);
    if n == 0 {
        return "";
    }
    # Optional sign introduces a 6-digit expanded year; otherwise a 4-digit year.
    pos: int = 0;
    ylen: int = 4;
    if s[0] == "+" or s[0] == "-" {
        pos = 1;
        ylen = 6;
    }
    # Digits of the year.
    yi: int = 0;
    while yi < ylen {
        if pos + yi >= n {
            return "";
        }
        c: str = s[pos + yi];
        if c < "0" or c > "9" {
            return "";
        }
        yi = yi + 1;
    }
    mpos: int = pos + ylen;
    sep: bool = False;
    if mpos < n and s[mpos] == "-" {
        sep = True;
        mpos = mpos + 1;
    }
    # Exactly two month digits must follow, and nothing else.
    if mpos + 2 != n {
        return "";
    }
    m0: str = s[mpos];
    m1: str = s[mpos + 1];
    if m0 < "0" or m0 > "9" or m1 < "0" or m1 > "9" {
        return "";
    }
    mm: int = (ord(m0) - 48) * 10 + (ord(m1) - 48);
    if mm < 1 or mm > 12 {
        return "";
    }
    if sep {
        return s + "-01";
    }
    return s + "01";
}

"""True if `s` is exactly "MM-DD": 2-digit month 01-12, "-", 2-digit day 01-31. Gates
the year-less PlainMonthDay string retry so invalid forms still reject."""
def:priv _temporal_is_month_day_shape(s: str) -> bool {
    if len(s) != 5 {
        return False;
    }
    m0: str = s[0];
    m1: str = s[1];
    if m0 < "0" or m0 > "9" or m1 < "0" or m1 > "9" {
        return False;
    }
    if s[2] != "-" {
        return False;
    }
    d0: str = s[3];
    d1: str = s[4];
    if d0 < "0" or d0 > "9" or d1 < "0" or d1 > "9" {
        return False;
    }
    mm: int = (ord(m0) - 48) * 10 + (ord(m1) - 48);
    dd: int = (ord(d0) - 48) * 10 + (ord(d1) - 48);
    return mm >= 1 and mm <= 12 and dd >= 1 and dd <= 31;
}

"""Index of the first byte equal to `ch` (a single-byte string) in `s`, or -1."""
def:priv _temporal_index_of(s: str, ch: str) -> int {
    i: int = 0;
    while i < len(s) {
        if s[i] == ch {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

"""Lowercase the ASCII letters of `s` (A–Z → a–z); other bytes unchanged. Used for
case-insensitive identifier matching (e.g. the "UTC" time zone)."""
def:priv _temporal_ascii_lower(s: str) -> str {
    out: str = "";
    i: int = 0;
    while i < len(s) {
        c: str = s[i];
        if c >= "A" and c <= "Z" {
            out = out + chr(ord(c) + 32);
        } else {
            out = out + c;
        }
        i = i + 1;
    }
    return out;
}

# Strict bare-identifier coercion for the ZonedDateTime CONSTRUCTOR's timeZone param:
# it accepts only a UTCOffset or an IANA name, NOT a full ISO datetime string (even one
# carrying a `[…]` TZ annotation). `withTimeZone`/property-bag `timeZone` use the lenient
# `ToTemporalTimeZoneIdentifier`, which extracts a TZ from such datetime strings.
def:pub ToTemporalTimeZoneIdentifierStrict(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        s: str = str_from_id(jsv_to_table_id(v));
        if _temporal_ascii_lower(s) != "utc" and not _is_offset_only_tz_string(s) {
            dt: list[any] = parse_iso_date_time(s);
            if dt[PR_OK] and (dt[PR_HAS_DATE] != 0 or dt[PR_HAS_TIME] != 0) {
                vm_throw_native(
                    make_range_error(
                        "time zone identifier must not be a date-time string"
                    )
                );
                return "";
            }
        }
    }
    return ToTemporalTimeZoneIdentifier(v);
}

def:pub ToTemporalTimeZoneIdentifier(v: JSValue) -> str {
    if js_is_zoned_datetime(v) {
        return _get_str_slot(v, KEY_TIMEZONE);
    }
    if not jsv_is_string_cell(v) {
        vm_throw_native(make_type_error("timeZone must be string"));
        return "";
    }
    s: str = str_from_id(jsv_to_table_id(v));
    # The "UTC" identifier is matched case-insensitively and canonicalized to "UTC"
    # (§GetAvailableNamedTimeZoneIdentifier — timezone-case-insensitive).
    if _temporal_ascii_lower(s) == "utc" {
        return "UTC";
    }
    if offset_string_has_subminute(s) {
        vm_throw_native(
            make_range_error('"' + s + '" is not a valid time zone string')
        );
        return "";
    }
    # A bare offset ("+00:00", "-12:00") is a valid identifier regardless of its numeric
    # value — the zero offset "+00:00" (offset seconds 0) must be accepted, so this is
    # keyed on the string SHAPE, not tzr[2] (the offset value, which was 0 for "+00:00"
    # and made the old `tzr[2] != 0` guard reject it).
    if _is_offset_only_tz_string(s) {
        return parse_temporal_time_zone_id(s);
    }
    tzr: list[any] = parse_temporal_time_zone_string(s);
    if tzr[0] == 0 {
        vm_throw_native(make_range_error("invalid time zone"));
        return "";
    }
    # tzr[1] is a `str` inside a List.i64 — it reads back as a raw pointer, so
    # the identifier text comes from the dedicated string-returning parser.
    tz: str = parse_temporal_time_zone_id(s);
    # An offset TZ extracted from a full datetime-with-annotation ("…T…[-07:00]") — the
    # lenient ToTemporalZonedDateTime string form. Reject a sub-minute extracted offset,
    # otherwise accept (withTimeZone / property-bag timeZone allow this; the stricter
    # constructor param is validated separately at the constructor call site).
    if len(tz) > 0 and (tz[0:1] == "+" or tz[0:1] == "-") {
        if offset_string_has_subminute(tz) {
            vm_throw_native(
                make_range_error('"' + tz + '" is not a valid time zone string')
            );
            return "";
        }
        return tz;
    }
    if tz == "UTC" {
        return tz;
    }
    h: int = tz_load_zone(tz);
    if h == 0 {
        tz_lower: str = calendar_id_from_string(tz);
        if tz_lower != tz {
            h = tz_load_zone(tz_lower);
            if h != 0 {
                tz = tz_lower;
            }
        }
    }
    if h == 0 {
        vm_throw_native(make_range_error("invalid time zone"));
        return "";
    }
    tz_unload(h);
    return tz;
}

def:pub ToOffsetString(v: JSValue) -> str {
    if not jsv_is_string_cell(v) and not jsv_is_object_cell(v) {
        vm_throw_native(make_type_error("offset must be string"));
        return "";
    }
    s: str = _obs_str(v);
    if vm_has_native_exc() {
        return "";
    }
    off: list[any] = parse_utc_offset_string(s);
    if off[0] == 0 {
        vm_throw_native(make_range_error("invalid offset"));
        return "";
    }
    return s;
}

def:priv _is_non_finite(n: float) -> bool {
    if n != n {
        return True;
    }
    if n > 1e308 {
        return True;
    }
    if n < -1e308 {
        return True;
    }
    return False;
}

def:priv _obs_to_integer(v: JSValue) -> list[any] {
    # ToIntegerWithTruncation — the coercion used by every calendar/time field of a
    # Temporal property bag (year, month, day, hour…nanosecond). A non-integral value
    # is TRUNCATED toward zero (1.7 → 1, -1.7 → -1), NOT rejected; only a non-finite
    # value (NaN/±∞) is a RangeError. (Duration components, which use
    # ToIntegerIfIntegral and DO reject non-integers, have their own reader.)
    if jsv_is_undefined(v) {
        return [0, 0];
    }
    n: float = js_to_number_observable(v);
    if vm_has_native_exc() {
        return [-1, 0];
    }
    if _is_non_finite(n) {
        vm_throw_native(make_range_error("non-finite integer"));
        return [-1, 0];
    }
    return [1, int(n)];
}

def:priv _obs_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return js_to_string_observable(v);
}

# monthCode field: the value must be a String (§PrepareCalendarFields uses a String-typed
# conversion). A primitive number/boolean/bigint/symbol is a TypeError — NOT a numeric
# coercion that would later fail parse as a RangeError. Objects still go through
# ToPrimitive(string) via _obs_str.
def:priv _obs_month_code_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_int32(v)
        or jsv_is_double(v)
        or jsv_is_bool(v)
        or jsv_is_bigint_cell(v)
        or jsv_is_symbol(v)
        or jsv_is_null(v) {
        vm_throw_native(make_type_error("monthCode must be a string"));
        return "";
    }
    return js_to_string_observable(v);
}

def:priv _validate_relative_to_tz(pr: list[any], s: str, tz_ann: str) -> None {
    if len(tz_ann) == 0 {
        return;
    }
    if tz_ann == "UTC" {
        if pr[PR_HAS_OFFSET] != 0 and pr[PR_OFFSET_S] != 0 and pr[PR_IS_Z] == 0 {
            vm_throw_native(make_range_error("time zone offset mismatch"));
        }
        return;
    }
    if pr[PR_IS_Z] != 0 {
        return;
    }
    ann: list[any] = offset_string_to_seconds(tz_ann);
    if ann[0] != 0 {
        if offset_string_has_subminute(tz_ann) {
            vm_throw_native(make_range_error("invalid time zone"));
            return;
        }
        if pr[PR_HAS_OFFSET] != 0 and pr[PR_OFFSET_S] != ann[1] {
            vm_throw_native(make_range_error("time zone offset mismatch"));
            return;
        }
        if pr[PR_HAS_OFFSET] != 0 {
            bracket: int = len(s);
            scan: int = 0;
            while scan < len(s) {
                if s[scan:scan + 1] == "[" {
                    bracket = scan;
                    break;
                }
                scan = scan + 1;
            }
            offpos: int = -1;
            scan2: int = 0;
            while scan2 < bracket {
                c2: str = s[scan2:scan2 + 1];
                if c2 == "+" or c2 == "-" {
                    offpos = scan2;
                }
                scan2 = scan2 + 1;
            }
            if offpos >= 0 {
                iso_off: str = str_substr(s, offpos, bracket);
                if offset_string_has_subminute(iso_off) {
                    vm_throw_native(make_range_error("time zone offset mismatch"));
                    return;
                }
            }
        }
        return;
    }
    tzr: list[any] = parse_temporal_time_zone_string(s);
    if tzr[0] == 0 {
        vm_throw_native(make_range_error("invalid time zone"));
        return;
    }
    if pr[PR_HAS_OFFSET] != 0 and tzr[2] != 0 {
        off_s: int = pr[PR_OFFSET_S];
        if off_s != tzr[2] {
            vm_throw_native(make_range_error("time zone offset mismatch"));
            return;
        }
    }
}

def:priv _anchor_from_parts(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int
) -> list[int] {
    if not iso_validate_ymd(y, m, d) {
        vm_throw_native(make_range_error("invalid date"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    if not iso_validate_relativeto_ymd(y, m, d) {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    # relativeTo uses overflow constrain: leap second :60 → :59.
    cs: int = s;
    cns: int = ns;
    if cs == 60 {
        cs = 59;
        cns = 999999999;
    }
    if not iso_validate_time(h, mi, cs, cns) {
        vm_throw_native(make_range_error("invalid time"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    return [y, m, d, h, mi, cs, cns];
}

def:priv _validate_relativeto_instant(pr: list[any], tz_ann: str) -> None {
    if pr[PR_HAS_OFFSET] == 0 and pr[PR_IS_Z] == 0 {
        if len(tz_ann) == 0 {
            return;
        }
    }
    if not pr[PR_HAS_TIME] and pr[PR_HAS_OFFSET] == 0 and pr[PR_IS_Z] == 0 {
        return;
    }
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    ns: int = 0;
    if pr[PR_HAS_TIME] {
        h = pr[PR_HOUR];
        mi = pr[PR_MINUTE];
        sc = pr[PR_SECOND];
        ns = pr[PR_NANOSECOND];
    }
    off: int = 0;
    if pr[PR_HAS_OFFSET] != 0 {
        off = pr[PR_OFFSET_S];
    }
    is_z: bool = False;
    if pr[PR_IS_Z] != 0 {
        is_z = True;
    }
    if not iso_validate_relativeto_instant(
        pr[PR_YEAR], pr[PR_MONTH], pr[PR_DAY], h, mi, sc, ns, off, is_z
    ) {
        vm_throw_native(make_range_error("invalid PlainDate"));
    }
}

def:priv _relative_to_from_string(s: str) -> list[int] {
    pr: list[any] = parse_iso_date_time(s);
    # Capture the string fields immediately (str-in-list bug: they live in module
    # globals set by the parse, overwritten by any later parse_iso_date_time call —
    # _validate_relative_to_tz re-parses internally, so read them here first).
    tz_ann0: str = PR_S_TZ_ANNOTATION;
    cal: str = PR_S_CALENDAR;
    if not pr[PR_OK] or not pr[PR_HAS_DATE] {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    if pr[PR_IS_Z] != 0 {
        if len(tz_ann0) == 0 {
            vm_throw_native(make_range_error("invalid PlainDate"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
    }
    _validate_relative_to_tz(pr, s, tz_ann0);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    _validate_relativeto_instant(pr, tz_ann0);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    if len(cal) == 0 {
        cal = extract_calendar_annotation(s);
    }
    if len(cal) == 0 {
        cal = "iso8601";
    }
    if not calendar_is_known(cal) {
        vm_throw_native(make_range_error("invalid calendar"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    ns: int = 0;
    if pr[PR_HAS_TIME] {
        h = pr[PR_HOUR];
        mi = pr[PR_MINUTE];
        sc = pr[PR_SECOND];
        ns = pr[PR_NANOSECOND];
    }
    return _anchor_from_parts(pr[PR_YEAR], pr[PR_MONTH], pr[PR_DAY], h, mi, sc, ns);
}

def:priv _relative_to_from_property_bag(o: JSValue) -> list[int] {
    cv: JSValue = js_object_get_observable(o, str_intern("calendar"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    dv: JSValue = js_object_get_observable(o, str_intern("day"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    dr: list[any] = _obs_to_integer(dv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    hv: JSValue = js_object_get_observable(o, str_intern("hour"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    hr: list[any] = _obs_to_integer(hv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    usv: JSValue = js_object_get_observable(o, str_intern("microsecond"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    usr: list[any] = _obs_to_integer(usv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    msv: JSValue = js_object_get_observable(o, str_intern("millisecond"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    msr: list[any] = _obs_to_integer(msv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    miv: JSValue = js_object_get_observable(o, str_intern("minute"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    mir: list[any] = _obs_to_integer(miv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    mv: JSValue = js_object_get_observable(o, str_intern("month"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    mr: list[any] = _obs_to_integer(mv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    mcv: JSValue = js_object_get_observable(o, str_intern("monthCode"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    mc_m: int = -1;
    if not jsv_is_undefined(mcv) {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return [0, 0, 0, 0, 0, 0, 0];
        }
        mc_m = parse_month_code(mc_s);
        if mc_m < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
    }
    nsv: JSValue = js_object_get_observable(o, str_intern("nanosecond"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    nsr: list[any] = _obs_to_integer(nsv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    ov: JSValue = js_object_get_observable(o, str_intern("offset"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    if not jsv_is_undefined(ov) {
        if not jsv_is_string_cell(ov) and not jsv_is_object_cell(ov) {
            vm_throw_native(make_type_error("offset must be string"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
        off_s: str = _obs_str(ov);
        if vm_has_native_exc() {
            return [0, 0, 0, 0, 0, 0, 0];
        }
        off_chk: list[any] = parse_utc_offset_string(off_s);
        if off_chk[0] == 0 {
            vm_throw_native(make_range_error("invalid offset"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
    }
    sv: JSValue = js_object_get_observable(o, str_intern("second"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    sr: list[any] = _obs_to_integer(sv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    tzv: JSValue = js_object_get_observable(o, str_intern("timeZone"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    yv: JSValue = js_object_get_observable(o, str_intern("year"), o);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    yr: list[any] = _obs_to_integer(yv);
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    has_y: bool = yr[0] != 0;
    has_m: bool = mr[0] != 0;
    has_d: bool = dr[0] != 0;
    has_mc: bool = not jsv_is_undefined(mcv);
    if has_y or has_m or has_d or has_mc {
        if not has_y or (not has_m and not has_mc) or not has_d {
            vm_throw_native(make_type_error("missing date field"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
    } else {
        # Empty / non-date property bag: TypeError (not a string-convertible relativeTo).
        vm_throw_native(make_type_error("invalid relativeTo"));
        return [0, 0, 0, 0, 0, 0, 0];
    }
    y: int = yr[1];
    m: int = 0;
    if has_m {
        m = mr[1];
    } elif has_mc {
        m = mc_m;
    }
    d: int = dr[1];
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    ns: int = 0;
    if hr[0] != 0 {
        h = hr[1];
    }
    if mir[0] != 0 {
        mi = mir[1];
    }
    if sr[0] != 0 {
        sc = sr[1];
    }
    ms: int = 0;
    us: int = 0;
    nsp: int = 0;
    if msr[0] != 0 {
        ms = msr[1];
    }
    if usr[0] != 0 {
        us = usr[1];
    }
    if nsr[0] != 0 {
        nsp = nsr[1];
    }
    ns = ms * 1000000 + us * 1000 + nsp;
    if not jsv_is_undefined(tzv) {
        tz: str = ToTemporalTimeZoneIdentifier(tzv);
        if vm_has_native_exc() {
            return [0, 0, 0, 0, 0, 0, 0];
        }
    }
    return _anchor_from_parts(y, m, d, h, mi, sc, ns);
}

def:pub GetTemporalRelativeToAnchor(v: JSValue) -> list[int] {
    if js_is_plain_date(v) {
        return [
            _get_int_slot(v, KEY_ISO_YEAR),
            _get_int_slot(v, KEY_ISO_MONTH),
            _get_int_slot(v, KEY_ISO_DAY),
            0,
            0,
            0,
            0
        ];
    }
    if js_is_plain_datetime(v) or js_is_zoned_datetime(v) {
        return [
            _get_int_slot(v, KEY_ISO_YEAR),
            _get_int_slot(v, KEY_ISO_MONTH),
            _get_int_slot(v, KEY_ISO_DAY),
            _get_int_slot(v, KEY_ISO_HOUR),
            _get_int_slot(v, KEY_ISO_MINUTE),
            _get_int_slot(v, KEY_ISO_SECOND),
            _get_int_slot(v, KEY_ISO_NANOSECOND)
        ];
    }
    if jsv_is_string_cell(v) {
        return _relative_to_from_string(str_from_id(jsv_to_table_id(v)));
    }
    if jsv_is_object_cell(v) {
        return _relative_to_from_property_bag(v);
    }
    # Numbers / null / undefined / boolean / symbol are not valid relativeTo
    # (ToTemporalRelativeToObject throws TypeError before string conversion).
    vm_throw_native(make_type_error("invalid relativeTo"));
    return [0, 0, 0, 0, 0, 0, 0];
}

def:pub temporal_reject_ymd(y: int, m: int, d: int) {
    if not iso_validate_ymd(y, m, d) {
        vm_throw_native(make_range_error("invalid date"));
    }
}

def:pub temporal_reject_time(h: int, mi: int, s: int, ns: int) -> None {
    if h < 0 or h > 23 or mi < 0 or mi > 59 or ns < 0 or ns > 999999999 {
        vm_throw_native(make_range_error("invalid time"));
        return;
    }
    if s < 0 or s > 60 or (s == 60 and (h != 23 or mi != 59)) {
        vm_throw_native(make_range_error("invalid time"));
        return;
    }
}

def:priv _temporal_validate_plaintime_parts(h: int, mi: int, s: int, ns: int) -> None {
    if h < 0 or h > 23 or mi < 0 or mi > 59 or ns < 0 or ns > 999999999 {
        vm_throw_native(make_range_error("invalid PlainTime"));
        return;
    }
    if s < 0 or s > 60 or (s == 60 and (h != 23 or mi != 59)) {
        vm_throw_native(make_range_error("invalid PlainTime"));
        return;
    }
}

def:pub temporal_constrain_ymd(y: int, m: int, d: int) -> list[int] {
    # Constrain overflow: clamp month to [1,12] and day to [1, daysInMonth] independently.
    cm: int = m;
    if cm < 1 {
        cm = 1;
    }
    if cm > 12 {
        cm = 12;
    }
    dim: int = iso_days_in_month(y, cm);
    cd: int = d;
    if cd < 1 {
        cd = 1;
    }
    if cd > dim {
        cd = dim;
    }
    return [y, cm, cd];
}

def:priv _month_code_is_leap(mc_s: str) -> bool {
    if len(mc_s) < 2 {
        return False;
    }
    c: str = mc_s[len(mc_s) - 1:len(mc_s)];
    return c == "L" or c == "l";
}

def:priv _temporal_cal_fields_from_bag_parts(
    cal_y: int,
    cal_m: int,
    cal_d: int,
    era_id: int,
    era_y: int,
    mc_ord: int,
    leap_month: bool
) -> list[int] {
    # Keep CF_MONTH_CODE=0 when the bag supplied a numeric month (no monthCode)
    # so hebrew/chinese fields_to_iso treat `cal_m` as already-resolved ordinal.
    mc: int = mc_ord;
    leap_m: int = 0;
    if leap_month {
        leap_m = 1;
    }
    ey: int = era_y;
    if era_id != ERA_NONE and ey == 0 and cal_y != 0 {
        ey = cal_y;
    }
    return [cal_y, cal_m, mc, cal_d, era_id, ey, 0, 0, 0, 0, 0, leap_m];
}

"""Map bag month / monthCode to Temporal numeric month for calendar_regulate."""
def:priv _temporal_bag_ordinal_month(
    cal: str, y: int, m: int, mc_ord: int, leap_month: bool
) -> int {
    norm: str = calendar_id_normalize(cal);
    if mc_ord <= 0 {
        return m;
    }
    if norm == "chinese" or norm == "dangi" {
        dest_leap: int = chinese_leap_month(y);
        if leap_month {
            return mc_ord + 1;
        }
        if dest_leap > 0 and mc_ord > dest_leap {
            return mc_ord + 1;
        }
        return mc_ord;
    }
    if norm == "hebrew" {
        miy: int = calendar_months_in_year(norm, y);
        if leap_month {
            return 6;
        }
        if mc_ord <= 5 {
            return mc_ord;
        }
        if mc_ord == 6 {
            if miy > 12 {
                return 7;
            }
            return 6;
        }
        if miy > 12 {
            return mc_ord + 1;
        }
        return mc_ord;
    }
    return mc_ord;
}

def:priv _temporal_bag_calendar_to_iso(
    y: int,
    m: int,
    d: int,
    cal: str,
    era_id: int,
    era_y: int,
    mc_ord: int,
    leap_month: bool,
    overflow: str
) -> list[int] {
    norm: str = calendar_id_normalize(cal);
    if norm == "iso8601" {
        # A monthCode is bounded to M01..M12 with no leap month in iso8601 — "M13"/"M19"
        # or a leap marker ("M05L") is a RangeError regardless of overflow (it names no
        # real month, unlike an out-of-range numeric `month` which constrains).
        if mc_ord > 12 or (mc_ord > 0 and leap_month) {
            vm_throw_native(
                make_range_error("monthCode is not valid for the ISO 8601 calendar")
            );
            return [y, m, d];
        }
        return [y, m, d];
    }
    # Regulate in calendar field space before fields→ISO so overflow days
    # clamp (constrain) / throw (reject) instead of rolling into the next month.
    ord_m: int = _temporal_bag_ordinal_month(cal, y, m, mc_ord, leap_month);
    reg: list[int] = calendar_regulate(norm, y, ord_m, d, overflow);
    if vm_has_native_exc() {
        return [y, m, d];
    }
    d = reg[2];
    fields: list[int] = _temporal_cal_fields_from_bag_parts(
        y, m, d, era_id, era_y, mc_ord, leap_month
    );
    return calendar_fields_to_iso(fields, cal);
}

"""Map era + eraYear to the calendar `year` field used by fields_to_iso."""
def:priv _temporal_calendar_year_from_era(cal: str, era_id: int, era_y: int) -> int {
    if era_id == ERA_BCE or era_id == ERA_BH or era_id == ERA_BROC {
        return 1 - era_y;
    }
    if era_id == ERA_AA {
        id: str = calendar_id_normalize(cal);
        # Ethiopic Amete Alem: AM year = AA year - 5500 (year 0 = AA 5500).
        if id == "ethiopic" {
            return era_y - 5500;
        }
        return era_y;
    }
    # Japanese CF_YEAR is Gregorian/ISO year.
    if era_id == ERA_REIWA {
        return 2018 + era_y;
    }
    if era_id == ERA_HEISEI {
        return 1988 + era_y;
    }
    if era_id == ERA_SHOWA {
        return 1925 + era_y;
    }
    if era_id == ERA_TAISHO {
        return 1911 + era_y;
    }
    if era_id == ERA_MEIJI {
        return 1867 + era_y;
    }
    # ce/ah/am/roc/ap/be/saka and friends: eraYear == calendar year
    return era_y;
}

def:priv _temporal_bag_era_from_fields(ev: JSValue, eyv: JSValue) -> list[int] {
    era_id: int = ERA_NONE;
    era_y: int = 0;
    if not jsv_is_undefined(ev) {
        era_s: str = _obs_str(ev);
        if vm_has_native_exc() {
            return [-1, 0, 0];
        }
        era_id = calendar_era_id_from_name(era_s);
        if era_id == ERA_NONE {
            vm_throw_native(make_range_error("invalid era"));
            return [-1, 0, 0];
        }
    }
    if not jsv_is_undefined(eyv) {
        eyr: list[any] = _obs_to_integer(eyv);
        if vm_has_native_exc() {
            return [-1, 0, 0];
        }
        era_y = eyr[1];
    }
    return [0, era_id, era_y];
}

# The ISO calendar has no eras, so era/eraYear are not among its field keys and must
# NOT be read observably from a property bag. Every other calendar this engine models
# is era-capable, so it reads them. (§CalendarFieldKeysPresent / calendar fieldKeys.)
def:priv _temporal_calendar_uses_era(cal: str) -> bool {
    return calendar_id_normalize(cal) != "iso8601";
}

# Read one integer-valued calendar/time field from a property bag observably and, if
# present, coerce it immediately via ToIntegerWithTruncation — the interleaved
# get-then-coerce that the order-of-operations traces require. Returns [present, value].
def:priv _temporal_bag_read_int_field(item: JSValue, key: str) -> list[any] {
    pv: JSValue = js_object_get_observable(item, str_intern(key), item);
    if vm_has_native_exc() {
        return [-1, 0];
    }
    if jsv_is_undefined(pv) {
        return [0, 0];
    }
    r: list[any] = _obs_to_integer(pv);
    if vm_has_native_exc() {
        return [-1, 0];
    }
    return [1, r[1]];
}

def _temporal_date_from_property_bag(item: JSValue, options: JSValue) -> JSValue {
    # PrepareCalendarFields + calendar date resolution. The observable read order is
    # spec-critical (order-of-operations tests): the calendar is read FIRST (it
    # determines the field list), then each field is read AND coerced immediately —
    # interleaved, in alphabetical key order (day, [era, eraYear,] month, monthCode,
    # year) — and finally options.overflow. era/eraYear are only in the field list for
    # calendars that use eras (never the ISO calendar). Reading all fields up front, or
    # coercing them in a second pass, produces the wrong trace.
    cv: JSValue = js_object_get_observable(item, str_intern("calendar"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    uses_era: bool = _temporal_calendar_uses_era(cal);

    dr: list[any] = _temporal_bag_read_int_field(item, "day");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_d: bool = dr[0] != 0;

    er_present: bool = False;
    era_code: int = 0;
    era_year: int = 0;
    if uses_era {
        ev: JSValue = js_object_get_observable(item, str_intern("era"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        eyv: JSValue = js_object_get_observable(item, str_intern("eraYear"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        er0: list[int] = _temporal_bag_era_from_fields(ev, eyv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        era_code = er0[1];
        era_year = er0[2];
        er_present = not jsv_is_undefined(ev) and not jsv_is_undefined(eyv);
    }

    mr: list[any] = _temporal_bag_read_int_field(item, "month");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = mr[0] != 0;

    mcv: JSValue = js_object_get_observable(item, str_intern("monthCode"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_mc: bool = not jsv_is_undefined(mcv);
    mc_ord: int = 0;
    leap_month: bool = False;
    if has_mc {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_ord = mc_n;
        leap_month = _month_code_is_leap(mc_s);
    }

    yr: list[any] = _temporal_bag_read_int_field(item, "year");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_y: bool = yr[0] != 0;

    has_era: bool = er_present;
    if not has_y and not has_era and not has_m and not has_d and not has_mc {
        vm_throw_native(make_type_error("invalid property bag"));
        return js_undefined();
    }
    if (not has_y and not has_era) or (not has_m and not has_mc) or not has_d {
        vm_throw_native(make_type_error("missing date field"));
        return js_undefined();
    }
    er: list[int] = [0, era_code, era_year];
    y: int = 0;
    if has_y {
        y = yr[1];
    } else {
        y = _temporal_calendar_year_from_era(cal, er[1], er[2]);
    }
    m: int = 0;
    if has_mc {
        m = mc_ord;
    }
    if has_m {
        if has_mc and mr[1] != m {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mr[1];
    }
    d: int = dr[1];
    # month/day are positive integers regardless of overflow (negative → RangeError).
    if (has_m and m < 1) or d < 1 {
        vm_throw_native(make_range_error("month and day must be positive"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    iso_parts: list[int] = _temporal_bag_calendar_to_iso(
        y, m, d, cal, er[1], er[2], mc_ord, leap_month, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = iso_parts[0];
    m = iso_parts[1];
    d = iso_parts[2];
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, d);
        y = bal[0];
        m = bal[1];
        d = bal[2];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    # The resulting date must be within the representable ISO date range
    # (ISODateWithinLimits ≡ ISODateTimeWithinLimits at noon).
    if not iso_validate_datetime_within_limits(y, m, d, 12, 0, 0, 0) {
        vm_throw_native(make_range_error("date out of range"));
        return js_undefined();
    }
    return js_plain_date_create(y, m, d, cal);
}

def:priv _temporal_time_field_observable(item: JSValue, key: str) -> list[any] {
    pv: JSValue = js_object_get_observable(item, str_intern(key), item);
    if vm_has_native_exc() {
        return [-1, 0];
    }
    if jsv_is_undefined(pv) {
        return [0, 0];
    }
    return _obs_to_integer(pv);
}

def:priv _temporal_time_parts_observable_optional(item: JSValue) -> list[int] {
    hr: list[any] = _temporal_time_field_observable(item, "hour");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    usr: list[any] = _temporal_time_field_observable(item, "microsecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    msr: list[any] = _temporal_time_field_observable(item, "millisecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    mir: list[any] = _temporal_time_field_observable(item, "minute");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    nsr: list[any] = _temporal_time_field_observable(item, "nanosecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    sr: list[any] = _temporal_time_field_observable(item, "second");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    if hr[0] > 0 {
        h = hr[1];
    }
    if mir[0] > 0 {
        mi = mir[1];
    }
    if sr[0] > 0 {
        sc = sr[1];
    }
    ms: int = 0;
    us: int = 0;
    nsp: int = 0;
    if msr[0] > 0 {
        ms = msr[1];
    }
    if usr[0] > 0 {
        us = usr[1];
    }
    if nsr[0] > 0 {
        nsp = nsr[1];
    }
    ns: int = ms * 1000000 + us * 1000 + nsp;
    return [h, mi, sc, ns];
}

def:priv _temporal_time_parts_observable_required(item: JSValue) -> list[int] {
    hr: list[any] = _temporal_time_field_observable(item, "hour");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    usr: list[any] = _temporal_time_field_observable(item, "microsecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    msr: list[any] = _temporal_time_field_observable(item, "millisecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    mir: list[any] = _temporal_time_field_observable(item, "minute");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    nsr: list[any] = _temporal_time_field_observable(item, "nanosecond");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    sr: list[any] = _temporal_time_field_observable(item, "second");
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    if hr[0] == 0
        and mir[0] == 0
        and sr[0] == 0
        and msr[0] == 0
        and usr[0] == 0
        and nsr[0] == 0 {
        vm_throw_native(make_type_error("missing time property"));
        return [0, 0, 0, 0];
    }
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    if hr[0] > 0 {
        h = hr[1];
    }
    if mir[0] > 0 {
        mi = mir[1];
    }
    if sr[0] > 0 {
        sc = sr[1];
    }
    ms: int = 0;
    us: int = 0;
    nsp: int = 0;
    if msr[0] > 0 {
        ms = msr[1];
    }
    if usr[0] > 0 {
        us = usr[1];
    }
    if nsr[0] > 0 {
        nsp = nsr[1];
    }
    ns: int = ms * 1000000 + us * 1000 + nsp;
    return [h, mi, sc, ns];
}

def:priv _temporal_datetime_from_property_bag(
    item: JSValue, options: JSValue
) -> JSValue {
    # Interleaved observable read+coerce in alphabetical key order — calendar first
    # (fixes the field list), then day, [era, eraYear,] hour, microsecond,
    # millisecond, minute, month, monthCode, nanosecond, second, year — each read then
    # coerced immediately — and finally options.overflow. era/eraYear only for non-ISO
    # calendars. Matches the order-of-operations traces.
    cv: JSValue = js_object_get_observable(item, str_intern("calendar"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    uses_era: bool = _temporal_calendar_uses_era(cal);

    dr: list[any] = _temporal_bag_read_int_field(item, "day");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_d: bool = dr[0] != 0;

    er_present: bool = False;
    era_code: int = 0;
    era_year: int = 0;
    if uses_era {
        ev: JSValue = js_object_get_observable(item, str_intern("era"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        eyv: JSValue = js_object_get_observable(item, str_intern("eraYear"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        er0: list[int] = _temporal_bag_era_from_fields(ev, eyv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        era_code = er0[1];
        era_year = er0[2];
        er_present = not jsv_is_undefined(ev) and not jsv_is_undefined(eyv);
    }

    hr: list[any] = _temporal_bag_read_int_field(item, "hour");
    if vm_has_native_exc() {
        return js_undefined();
    }
    h: int = hr[1];
    usr: list[any] = _temporal_bag_read_int_field(item, "microsecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    us: int = usr[1];
    msr: list[any] = _temporal_bag_read_int_field(item, "millisecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    ms: int = msr[1];
    mir: list[any] = _temporal_bag_read_int_field(item, "minute");
    if vm_has_native_exc() {
        return js_undefined();
    }
    mi: int = mir[1];

    mr: list[any] = _temporal_bag_read_int_field(item, "month");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = mr[0] != 0;

    mcv: JSValue = js_object_get_observable(item, str_intern("monthCode"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_mc: bool = not jsv_is_undefined(mcv);
    mc_ord: int = 0;
    leap_month: bool = False;
    if has_mc {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_ord = mc_n;
        leap_month = _month_code_is_leap(mc_s);
    }

    nsr: list[any] = _temporal_bag_read_int_field(item, "nanosecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    nsp: int = nsr[1];
    sr: list[any] = _temporal_bag_read_int_field(item, "second");
    if vm_has_native_exc() {
        return js_undefined();
    }
    sc: int = sr[1];

    yr: list[any] = _temporal_bag_read_int_field(item, "year");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_y: bool = yr[0] != 0;

    has_era: bool = er_present;
    if not has_y and not has_era and not has_m and not has_d and not has_mc {
        vm_throw_native(make_type_error("invalid property bag"));
        return js_undefined();
    }
    if (not has_y and not has_era) or (not has_m and not has_mc) or not has_d {
        vm_throw_native(make_type_error("missing date field"));
        return js_undefined();
    }
    er: list[int] = [0, era_code, era_year];
    y: int = 0;
    if has_y {
        y = yr[1];
    } else {
        y = _temporal_calendar_year_from_era(cal, er[1], er[2]);
    }
    m: int = 0;
    if has_mc {
        m = mc_ord;
    }
    if has_m {
        if has_mc and mr[1] != m {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mr[1];
    }
    d: int = dr[1];
    if (has_m and m < 1) or d < 1 {
        vm_throw_native(make_range_error("month and day must be positive"));
        return js_undefined();
    }
    ns: int = ms * 1000000 + us * 1000 + nsp;
    ov: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    iso_parts: list[int] = _temporal_bag_calendar_to_iso(
        y, m, d, cal, er[1], er[2], mc_ord, leap_month, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = iso_parts[0];
    m = iso_parts[1];
    d = iso_parts[2];
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, d);
        y = bal[0];
        m = bal[1];
        d = bal[2];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    # RegulateTime on the time-of-day too: constrain clamps a leap second 60 → 59 (and
    # minute 67 → 59); reject throws on an out-of-range field.
    if ov == "reject" {
        temporal_reject_time(h, mi, sc, ns);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        if h > 23 {
            h = 23;
        }
        if mi > 59 {
            mi = 59;
        }
        if sc > 59 {
            sc = 59;
        }
        if ns > 999999999 {
            ns = 999999999;
        }
    }
    if not iso_validate_datetime_within_limits(y, m, d, h, mi, sc, ns) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(y, m, d, h, mi, sc, ns, cal);
}

def:pub _temporal_zoned_from_property_bag(
    item: JSValue, default_tz: str, disambiguation: str, options: JSValue
) -> JSValue {
    # Interleaved observable read+coerce in ALPHABETICAL key order — calendar (fixes the
    # field list), day, [era, eraYear,] hour, microsecond, millisecond, minute, month,
    # monthCode, nanosecond, offset, second, timeZone, year — each read then coerced
    # immediately; era/eraYear only for a non-ISO calendar; offset/timeZone/calendar are
    # read but not integer-coerced. Matches the order-of-operations traces.
    cv: JSValue = js_object_get_observable(item, str_intern("calendar"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    uses_era: bool = _temporal_calendar_uses_era(cal);

    dr: list[any] = _temporal_bag_read_int_field(item, "day");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_d: bool = dr[0] != 0;

    er: list[int] = [0, 0, 0];
    if uses_era {
        ev: JSValue = js_object_get_observable(item, str_intern("era"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        eyv: JSValue = js_object_get_observable(item, str_intern("eraYear"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        er = _temporal_bag_era_from_fields(ev, eyv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }

    hr: list[any] = _temporal_bag_read_int_field(item, "hour");
    if vm_has_native_exc() {
        return js_undefined();
    }
    usr: list[any] = _temporal_bag_read_int_field(item, "microsecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    msr: list[any] = _temporal_bag_read_int_field(item, "millisecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    mir: list[any] = _temporal_bag_read_int_field(item, "minute");
    if vm_has_native_exc() {
        return js_undefined();
    }

    mr: list[any] = _temporal_bag_read_int_field(item, "month");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = mr[0] != 0;

    mcv: JSValue = js_object_get_observable(item, str_intern("monthCode"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_mc: bool = not jsv_is_undefined(mcv);
    mc_ord: int = 0;
    leap_month: bool = False;
    if has_mc {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_ord = mc_n;
        leap_month = _month_code_is_leap(mc_s);
    }

    nsr: list[any] = _temporal_bag_read_int_field(item, "nanosecond");
    if vm_has_native_exc() {
        return js_undefined();
    }
    # offset is read then immediately ToString-coerced (offset.toString fires here, in
    # alphabetical position — between nanosecond and second).
    offv: JSValue = js_object_get_observable(item, str_intern("offset"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_off: bool = not jsv_is_undefined(offv);
    off_str: str = "";
    if has_off {
        off_str = ToOffsetString(offv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    sr: list[any] = _temporal_bag_read_int_field(item, "second");
    if vm_has_native_exc() {
        return js_undefined();
    }
    tzv: JSValue = js_object_get_observable(item, str_intern("timeZone"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    yr: list[any] = _temporal_bag_read_int_field(item, "year");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_y: bool = yr[0] != 0;

    if not has_y or (not has_m and not has_mc) or not has_d {
        vm_throw_native(make_type_error("invalid property bag"));
        return js_undefined();
    }
    y: int = yr[1];
    m: int = 0;
    if has_mc {
        m = mc_ord;
    }
    if has_m {
        if has_mc and mr[1] != m {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mr[1];
    }
    d: int = dr[1];
    if (has_m and m < 1) or d < 1 {
        vm_throw_native(make_range_error("month and day must be positive"));
        return js_undefined();
    }
    h: int = int(hr[1]);
    mi: int = int(mir[1]);
    sc: int = int(sr[1]);
    ns: int = int(msr[1]) * 1000000 + int(usr[1]) * 1000 + int(nsr[1]);
    # Validate + honor the caller's `overflow` option (default "constrain").
    ov: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    iso_parts: list[int] = _temporal_bag_calendar_to_iso(
        y, m, d, cal, er[1], er[2], mc_ord, leap_month, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = iso_parts[0];
    m = iso_parts[1];
    d = iso_parts[2];
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, d);
        m = bal[1];
        d = bal[2];
    }
    temporal_reject_time(h, mi, sc, ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tz: str = default_tz;
    if not jsv_is_undefined(tzv) {
        tz = ToTemporalTimeZoneIdentifier(tzv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } elif len(default_tz) == 0 {
        tz = "UTC";
    }
    off_s: int = 0;
    if has_off {
        # offset was already ToString-coerced above (off_str); parse it here.
        offp: list[any] = parse_utc_offset_string(off_str);
        if offp[0] != 0 {
            off_s = offp[1];
        }
        # Reconcile the supplied offset with the time zone per the `offset` option
        # (InterpretISODateTimeOffset), default "reject":
        #   use    — keep this offset (exact instant).
        #   ignore — drop it, recompute from wall-clock + zone.
        #   reject — the offset MUST equal a valid zone offset, else RangeError.
        #   prefer — keep it if valid, else recompute.
        offset_opt: str = temporal_get_offset_option(options, "reject");
        if vm_has_native_exc() {
            return js_undefined();
        }
        if offset_opt == "ignore" {
            off_s = temporal_resolve_zone_offset_seconds(
                tz, y, m, d, h, mi, sc, disambiguation
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
        } elif offset_opt != "use" {
            zone_off: int = temporal_resolve_zone_offset_seconds(
                tz, y, m, d, h, mi, sc, disambiguation
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
            if zone_off != off_s {
                if offset_opt == "reject" {
                    vm_throw_native(
                        make_range_error("offset does not match the time zone")
                    );
                    return js_undefined();
                }
                # prefer: the supplied offset is invalid → recompute from the zone.
                off_s = zone_off;
            }
        }
    } else {
        off_s = temporal_resolve_zone_offset_seconds(
            tz, y, m, d, h, mi, sc, disambiguation
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    return js_zoned_datetime_create(y, m, d, h, mi, sc, ns, tz, off_s, cal);
}

def:priv _temporal_time_from_property_bag(item: JSValue, options: JSValue) -> JSValue {
    # ToTemporalTimeRecord reads ONLY the six time fields (alphabetical order) — a
    # PlainTime has no calendar, so the `calendar` property is never read from a time
    # property bag (§ToTemporalTime / order-of-operations expects no calendar read).
    parts: list[int] = _temporal_time_parts_observable_required(item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # overflow is read AFTER the time fields (order-of-operations).
    overflow: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    h: int = parts[0];
    mi: int = parts[1];
    s: int = parts[2];
    ns: int = parts[3];
    # RegulateTime applies the overflow option: "constrain" clamps each field to its
    # maximum (a leap second 60 → 59, minute 67 → 59); "reject" throws on any
    # out-of-range field.
    if overflow == "reject" {
        temporal_reject_time(h, mi, s, ns);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        if h > 23 {
            h = 23;
        }
        if mi > 59 {
            mi = 59;
        }
        if s > 59 {
            s = 59;
        }
        if ns > 999999999 {
            ns = 999999999;
        }
    }
    return js_plain_time_create(h, mi, s, ns, "iso8601");
}

def:priv _temporal_validate_iso_time_for_plain(
    h3: int, m3: int, s3: int, n3: int, err: str
) -> None {
    if h3 < 0 or h3 > 23 or m3 < 0 or m3 > 59 or n3 < 0 or n3 > 999999999 {
        vm_throw_native(make_range_error(err));
        return;
    }
    if s3 < 0 or s3 > 60 or (s3 == 60 and (h3 != 23 or m3 != 59)) {
        vm_throw_native(make_range_error(err));
        return;
    }
}

def:pub ToTemporalDate(item: JSValue, options: JSValue) -> JSValue {
    # Even when `item` is already a Temporal object and the conversion is a plain
    # copy, GetTemporalOverflowOption(options) still runs and validates the option
    # (ES §ToTemporalDate: the overflow read is not skipped for the fast paths).
    # An invalid overflow string must throw RangeError regardless of item shape.
    if js_is_plain_date(item) {
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalDate returns a fresh CreateTemporalDate, NOT the same object.
        return js_plain_date_create(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            _get_str_slot(item, KEY_CALENDAR)
        );
    }
    if js_is_plain_datetime(item) or js_is_zoned_datetime(item) {
        y: int = _get_int_slot(item, KEY_ISO_YEAR);
        m: int = _get_int_slot(item, KEY_ISO_MONTH);
        d: int = _get_int_slot(item, KEY_ISO_DAY);
        cal: str = _get_str_slot(item, KEY_CALENDAR);
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return js_plain_date_create(y, m, d, cal);
    }
    if jsv_is_undefined(item)
        or jsv_is_null(item)
        or jsv_is_bool(item)
        or jsv_is_int32(item)
        or jsv_is_double(item)
        or jsv_is_bigint_cell(item)
        or jsv_is_symbol(item) {
        vm_throw_native(make_type_error("invalid PlainDate"));
        return js_undefined();
    }
    if jsv_is_object_cell(item) {
        # Any non-branded object is a property bag. The fields MUST be read
        # observably (spec [[Get]] fires getters and fixes their order), so route
        # straight to the bag builder — a non-observable presence pre-check would
        # miss getter-defined fields entirely (order-of-operations tests) and skip
        # the required getter invocations.
        return _temporal_date_from_property_bag(item, options);
    }
    if not jsv_is_string_cell(item) {
        vm_throw_native(make_type_error("invalid PlainDate"));
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(item));
    pr: list[any] = parse_iso_date_time(s);
    pd_cal_captured: str = PR_S_CALENDAR;
    if not pr[PR_OK] or not pr[PR_HAS_DATE] {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return js_undefined();
    }
    if pr[PR_HAS_OFFSET] and not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return js_undefined();
    }
    if pr[PR_IS_Z] != 0 {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return js_undefined();
    }
    if pr[PR_HAS_TIME] {
        h3: int = pr[PR_HOUR];
        m3: int = pr[PR_MINUTE];
        s3: int = pr[PR_SECOND];
        n3: int = pr[PR_NANOSECOND];
        if h3 < 0 or h3 > 23 or m3 < 0 or m3 > 59 or n3 < 0 or n3 > 999999999 {
            vm_throw_native(make_range_error("invalid PlainDate"));
            return js_undefined();
        }
        if s3 < 0 or s3 > 60 or (s3 == 60 and (h3 != 23 or m3 != 59)) {
            vm_throw_native(make_range_error("invalid PlainDate"));
            return js_undefined();
        }
    }
    y2: int = pr[PR_YEAR];
    m2: int = pr[PR_MONTH];
    d2: int = pr[PR_DAY];
    if not iso_validate_ymd(y2, m2, d2) {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return js_undefined();
    }
    if not iso_validate_relativeto_ymd(y2, m2, d2) {
        vm_throw_native(make_range_error("invalid PlainDate"));
        return js_undefined();
    }
    ov2: str = temporal_get_overflow(options);
    if ov2 == "reject" {
        temporal_reject_ymd(y2, m2, d2);
    } else {
        bal2: list[int] = temporal_constrain_ymd(y2, m2, d2);
        y2 = bal2[0];
        m2 = bal2[1];
        d2 = bal2[2];
    }
    cal2: str = pd_cal_captured;
    if len(cal2) == 0 {
        cal2 = extract_calendar_annotation(s);
    }
    if len(cal2) == 0 {
        cal2 = "iso8601";
    }
    if not calendar_is_known(cal2) {
        vm_throw_native(make_range_error("invalid calendar"));
        return js_undefined();
    }
    return js_plain_date_create(y2, m2, d2, cal2);
}

def:pub ToTemporalPlainDateTime(item: JSValue, options: JSValue) -> JSValue {
    # GetTemporalOverflowOption(options) validates even on the Temporal-object fast
    # paths (§ToTemporalDateTime): an invalid overflow string throws RangeError.
    if js_is_plain_datetime(item) {
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalPlainDateTime returns a fresh CreateTemporalDateTime, NOT the same
        # object (from(pdt) !== pdt).
        return js_plain_datetime_create(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND),
            _get_str_slot(item, KEY_CALENDAR)
        );
    }
    if js_is_plain_date(item) {
        r_dt1: JSValue = js_plain_datetime_create(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            0,
            0,
            0,
            0,
            _get_str_slot(item, KEY_CALENDAR)
        );
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return r_dt1;
    }
    if js_is_zoned_datetime(item) {
        r_dt2: JSValue = js_plain_datetime_create(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND),
            _get_str_slot(item, KEY_CALENDAR)
        );
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return r_dt2;
    }
    if jsv_is_undefined(item)
        or jsv_is_null(item)
        or jsv_is_bool(item)
        or jsv_is_int32(item)
        or jsv_is_double(item)
        or jsv_is_bigint_cell(item)
        or jsv_is_symbol(item) {
        vm_throw_native(make_type_error("invalid PlainDateTime"));
        return js_undefined();
    }
    if jsv_is_object_cell(item) {
        # Any non-branded object is a property bag; fields are read observably by the
        # bag builder (getters fire in spec order). A non-observable presence check
        # would miss getter-defined fields (order-of-operations tests).
        return _temporal_datetime_from_property_bag(item, options);
    }
    if not jsv_is_string_cell(item) {
        vm_throw_native(make_type_error("invalid PlainDateTime"));
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(item));
    pr: list[any] = parse_iso_date_time(s);
    pdt_cal_captured: str = PR_S_CALENDAR;
    if not pr[PR_OK] or not pr[PR_HAS_DATE] {
        vm_throw_native(make_range_error("invalid PlainDateTime"));
        return js_undefined();
    }
    # A numeric UTC offset ("…+05:00", "…-08:00") is permitted in a PlainDateTime
    # string and simply ignored — the wall-clock date/time is kept. Only the "Z" UTC
    # designator is forbidden, since it would denote an exact instant rather than a
    # plain wall-clock value (§ParseTemporalDateTimeString rejects UTCDesignator).
    if pr[PR_IS_Z] != 0 {
        vm_throw_native(make_range_error("invalid PlainDateTime"));
        return js_undefined();
    }
    # A UTC offset with no time component ("2022-09-15+00:00") is not a valid
    # PlainDateTime string — the offset only has meaning attached to a time-of-day.
    if pr[PR_HAS_OFFSET] and not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainDateTime"));
        return js_undefined();
    }
    h2: int = 0;
    mi2: int = 0;
    sc2: int = 0;
    ns2: int = 0;
    if pr[PR_HAS_TIME] {
        h2 = pr[PR_HOUR];
        mi2 = pr[PR_MINUTE];
        sc2 = pr[PR_SECOND];
        ns2 = pr[PR_NANOSECOND];
        # Leap second ":60" is constrained to ":59" (no leap second in ISO).
        if sc2 == 60 {
            sc2 = 59;
        }
        _temporal_validate_iso_time_for_plain(
            h2, mi2, sc2, ns2, "invalid PlainDateTime"
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    y2: int = pr[PR_YEAR];
    m2: int = pr[PR_MONTH];
    d2: int = pr[PR_DAY];
    if not iso_validate_ymd(y2, m2, d2) {
        vm_throw_native(make_range_error("invalid PlainDateTime"));
        return js_undefined();
    }
    ov2: str = temporal_get_overflow(options);
    if ov2 == "reject" {
        temporal_reject_ymd(y2, m2, d2);
    } else {
        bal2: list[int] = temporal_constrain_ymd(y2, m2, d2);
        y2 = bal2[0];
        m2 = bal2[1];
        d2 = bal2[2];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    temporal_reject_time(h2, mi2, sc2, ns2);
    cal2: str = pdt_cal_captured;
    if len(cal2) == 0 {
        cal2 = extract_calendar_annotation(s);
    }
    if len(cal2) == 0 {
        cal2 = "iso8601";
    }
    if not calendar_is_known(cal2) {
        vm_throw_native(make_range_error("invalid calendar"));
        return js_undefined();
    }
    # The combined date+time must be within the representable PlainDateTime range:
    # "-271821-04-19" (T00:00:00) and "+275760-09-14" are out of range even though the
    # date alone passes iso_validate_ymd.
    if not iso_validate_datetime_within_limits(y2, m2, d2, h2, mi2, sc2, ns2) {
        vm_throw_native(make_range_error("invalid PlainDateTime"));
        return js_undefined();
    }
    return js_plain_datetime_create(y2, m2, d2, h2, mi2, sc2, ns2, cal2);
}

def _get_int_slot_from_val(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _time_field_int(o: JSValue, key: str) -> list[any] {
    pv: JSValue = js_object_get(o, str_intern(key));
    if jsv_is_undefined(pv) {
        return [0, 0];
    }
    return [1, _get_int_slot_from_val(pv)];
}

def _time_parts_from_string(s: str) -> list[int] {
    pr: list[any] = parse_iso_date_time(s);
    if not pr[PR_OK] or not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainTime"));
        return [0, 0, 0, 0];
    }
    h: int = pr[PR_HOUR];
    mi: int = pr[PR_MINUTE];
    sc: int = pr[PR_SECOND];
    ns: int = pr[PR_NANOSECOND];
    temporal_reject_time(h, mi, sc, ns);
    if vm_has_native_exc() {
        return [0, 0, 0, 0];
    }
    return [h, mi, sc, ns];
}

def:pub temporal_time_parts_from_like(item: JSValue) -> list[int] {
    if js_is_plain_time(item) {
        return [
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND)
        ];
    }
    if js_is_plain_datetime(item) or js_is_zoned_datetime(item) {
        return [
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND)
        ];
    }
    if jsv_is_object_cell(item) {
        hr: list[any] = _time_field_int(item, "hour");
        mir: list[any] = _time_field_int(item, "minute");
        sr: list[any] = _time_field_int(item, "second");
        msr: list[any] = _time_field_int(item, "millisecond");
        usr: list[any] = _time_field_int(item, "microsecond");
        nsr: list[any] = _time_field_int(item, "nanosecond");
        if hr[0] != 0
            or mir[0] != 0
            or sr[0] != 0
            or msr[0] != 0
            or usr[0] != 0
            or nsr[0] != 0 {
            return _temporal_time_parts_observable_required(item);
        }
        vm_throw_native(make_type_error("missing time property"));
        return [0, 0, 0, 0];
    }
    s: str = js_coerce_to_string(item);
    return _time_parts_from_string(s);
}

def:pub temporal_get_disambiguation(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "compatible";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "compatible";
    }
    dv: JSValue = js_object_get_observable(
        options, str_intern("disambiguation"), options
    );
    if vm_has_native_exc() {
        return "compatible";
    }
    if jsv_is_undefined(dv) {
        return "compatible";
    }
    s: str = js_to_string_observable(dv);
    if vm_has_native_exc() {
        return "compatible";
    }
    if s == "earlier" or s == "later" or s == "compatible" or s == "reject" {
        return s;
    }
    vm_throw_native(make_range_error('"' + s + '" is not a valid disambiguation'));
    return "compatible";
}

# ToTemporalOffsetOption — the `offset` option is a String in «prefer, use, ignore,
# reject» (default from the caller, "reject" for from). ToString-coerces (TypeError for
# null/symbol), RangeError for an out-of-set string.
def:pub temporal_get_offset_option(options: JSValue, fallback: str) -> str {
    if jsv_is_undefined(options) {
        return fallback;
    }
    ov: JSValue = js_object_get_observable(options, str_intern("offset"), options);
    if vm_has_native_exc() {
        return fallback;
    }
    if jsv_is_undefined(ov) {
        return fallback;
    }
    s: str = js_to_string_observable(ov);
    if vm_has_native_exc() {
        return fallback;
    }
    if s == "prefer" or s == "use" or s == "ignore" or s == "reject" {
        return s;
    }
    vm_throw_native(make_range_error('"' + s + '" is not a valid offset option'));
    return fallback;
}

def:pub temporal_get_timezone_from_zdt_options(
    options: JSValue, default_tz: str
) -> str {
    if jsv_is_undefined(options) {
        return default_tz;
    }
    if jsv_is_string_cell(options) or js_is_zoned_datetime(options) {
        return ToTemporalTimeZoneIdentifier(options);
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return default_tz;
    }
    tzv: JSValue = js_object_get(options, str_intern("timeZone"));
    if jsv_is_undefined(tzv) {
        return default_tz;
    }
    return ToTemporalTimeZoneIdentifier(tzv);
}

def:priv _temporal_gap_offsets(handle: int, local_s: int) -> list[int] {
    guesses: list[int] = [local_s, local_s - 43200, local_s - 86400, local_s + 43200];
    gi: int = 0;
    while gi < len(guesses) {
        guess: int = guesses[gi];
        trans_fwd: int = tz_get_next_transition(handle, guess, True);
        if trans_fwd > 0 {
            off_before: tuple[int, bool] = tz_get_offset(handle, trans_fwd - 1);
            off_after: tuple[int, bool] = tz_get_offset(handle, trans_fwd);
            return [off_before[0], off_after[0]];
        }
        trans_back: int = tz_get_next_transition(handle, guess, False);
        if trans_back > 0 {
            off_before2: tuple[int, bool] = tz_get_offset(handle, trans_back - 1);
            off_after2: tuple[int, bool] = tz_get_offset(handle, trans_back);
            return [off_before2[0], off_after2[0]];
        }
        gi = gi + 1;
    }
    return [];
}

def:priv _temporal_pick_max_offset(offs: list[int]) -> int {
    best: int = offs[0];
    j: int = 1;
    while j < len(offs) {
        if offs[j] > best {
            best = offs[j];
        }
        j = j + 1;
    }
    return best;
}

def:priv _temporal_pick_min_offset(offs: list[int]) -> int {
    best: int = offs[0];
    j: int = 1;
    while j < len(offs) {
        if offs[j] < best {
            best = offs[j];
        }
        j = j + 1;
    }
    return best;
}

def:pub temporal_resolve_zone_offset_seconds(
    tz: str, y: int, m: int, d: int, h: int, mi: int, s: int, disambiguation: str
) -> int {
    if tz == "UTC" or tz == "" {
        return 0;
    }
    if len(tz) > 0 and (tz[0:1] == "+" or tz[0:1] == "-") {
        off: list[any] = parse_utc_offset_string(tz);
        if off[0] != 0 {
            return off[1];
        }
        return 0;
    }
    handle: int = tz_load_zone(tz);
    if handle == 0 {
        return 0;
    }
    days: int = iso_days_from_ymd(y, m, d);
    local_s: int = days * 86400 + h * 3600 + mi * 60 + s;
    buf: int = io_alloc(32);
    cnt: int = tz_get_possible_offsets(handle, local_s, buf, 4);
    if cnt <= 0 {
        if disambiguation == "reject" {
            tz_unload(handle);
            vm_throw_native(make_range_error("invalid wall time"));
            return 0;
        }
        gaps: list[int] = _temporal_gap_offsets(handle, local_s);
        tz_unload(handle);
        if len(gaps) >= 2 {
            if disambiguation == "earlier" {
                return gaps[1];
            }
            return gaps[0];
        }
        handle2: int = tz_load_zone(tz);
        off_pair: tuple[int, bool] = tz_get_offset(handle2, local_s);
        tz_unload(handle2);
        return off_pair[0];
    }
    if cnt == 1 {
        off0: int = read_i32(buf, 0);
        tz_unload(handle);
        return off0;
    }
    if disambiguation == "reject" {
        tz_unload(handle);
        vm_throw_native(make_range_error("ambiguous local time"));
        return 0;
    }
    offs: list[int] = [];
    i: int = 0;
    while i < cnt {
        offs = offs + [read_i32(buf, i * 8)];
        i = i + 1;
    }
    tz_unload(handle);
    if disambiguation == "earlier" {
        return _temporal_pick_max_offset(offs);
    }
    if disambiguation == "later" {
        return _temporal_pick_min_offset(offs);
    }
    return _temporal_pick_max_offset(offs);
}

def:pub temporal_offset_ns_for_zone(
    tz: str, y: int, m: int, d: int, h: int, mi: int, s: int
) -> int {
    return temporal_resolve_zone_offset_seconds(tz, y, m, d, h, mi, s, "compatible");
}

def:pub temporal_seconds_to_offset_ns(sec: int) -> int {
    ns_bn: list[int] = bn_mul_small(bn_from_int(sec), 1000000000);
    return int(bn_to_string(ns_bn, 10));
}

def:pub ToTemporalTime(item: JSValue, options: JSValue) -> JSValue {
    # GetTemporalOverflowOption(options) validates even for the Temporal-object fast
    # paths (§ToTemporalTime): an invalid overflow string throws RangeError.
    if js_is_plain_time(item) {
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalTime returns a fresh CreateTemporalTime, NOT the same object.
        return js_plain_time_create(
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND),
            _get_str_slot(item, KEY_CALENDAR)
        );
    }
    if js_is_plain_datetime(item) or js_is_zoned_datetime(item) {
        r_ptc: JSValue = js_plain_time_create(
            _get_int_slot(item, KEY_ISO_HOUR),
            _get_int_slot(item, KEY_ISO_MINUTE),
            _get_int_slot(item, KEY_ISO_SECOND),
            _get_int_slot(item, KEY_ISO_NANOSECOND),
            _get_str_slot(item, KEY_CALENDAR)
        );
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return r_ptc;
    }
    if jsv_is_undefined(item)
        or jsv_is_null(item)
        or jsv_is_bool(item)
        or jsv_is_int32(item)
        or jsv_is_double(item)
        or jsv_is_bigint_cell(item)
        or jsv_is_symbol(item) {
        vm_throw_native(make_type_error("invalid PlainTime"));
        return js_undefined();
    }
    if jsv_is_object_cell(item) {
        # Any non-branded object is a time property bag. The builder reads its fields
        # observably, then reads overflow and applies RegulateTime: a leap second 60
        # constrains to 59 by default, or throws under overflow:"reject".
        return _temporal_time_from_property_bag(item, options);
    }
    if not jsv_is_string_cell(item) {
        vm_throw_native(make_type_error("invalid PlainTime"));
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(item));
    # PlainTime ignores the calendar entirely, so parse leniently: an unknown
    # [u-ca=…] annotation must not reject a time string (validate_calendar=False).
    pr: list[any] = parse_iso_date_time(s, False);
    if not pr[PR_OK] or not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainTime"));
        return js_undefined();
    }
    # A UTC designator "Z" means the string denotes an exact instant — invalid for a
    # bare PlainTime (ParseTemporalTimeString rejects the UTCDesignator production).
    if pr[PR_IS_Z] != 0 {
        vm_throw_native(make_range_error("invalid PlainTime"));
        return js_undefined();
    }
    h: int = pr[PR_HOUR];
    mi: int = pr[PR_MINUTE];
    sc: int = pr[PR_SECOND];
    ns: int = pr[PR_NANOSECOND];
    # ParseISODateTime accepts a leap second ":60" anywhere and normalizes it to ":59"
    # (there is no leap-second value in Temporal). This constraint always applies —
    # even under overflow:"reject", and regardless of the hour/minute — so do it before
    # range validation. Sub-second digits are preserved ("23:59:60.170" → 23:59:59.170).
    if sc == 60 {
        sc = 59;
    }
    _temporal_validate_iso_time_for_plain(h, mi, sc, ns, "invalid PlainTime");
    if vm_has_native_exc() {
        return js_undefined();
    }
    # overflow is read+validated only AFTER the string parses AND its time values pass
    # range validation — an invalid time string ("24:60") throws RangeError before the
    # options getter is touched (§ToTemporalTime: parse+validate precede
    # GetTemporalOverflowOption).
    _ = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # PlainTime carries NO calendar. A [u-ca=…] annotation on a time string is only
    # parsed for syntactic validity (handled by parse_iso_date_time) and then
    # discarded — an unknown or critical calendar is IGNORED, not rejected, and never
    # attached to the result (§ParseTemporalTimeString). Always create as iso8601.
    return js_plain_time_create(h, mi, sc, ns, "iso8601");
}

def:priv _temporal_year_month_from_property_bag(
    item: JSValue, options: JSValue
) -> JSValue {
    # Interleaved observable read+coerce in alphabetical key order: calendar first,
    # then [era, eraYear,] month, monthCode, year — coerced immediately — then
    # options.overflow. No day field. era/eraYear only for non-ISO calendars.
    cv: JSValue = js_object_get_observable(item, str_intern("calendar"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    uses_era: bool = _temporal_calendar_uses_era(cal);

    er_present: bool = False;
    era_code: int = 0;
    era_year: int = 0;
    if uses_era {
        ev: JSValue = js_object_get_observable(item, str_intern("era"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        eyv: JSValue = js_object_get_observable(item, str_intern("eraYear"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        er0: list[int] = _temporal_bag_era_from_fields(ev, eyv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        era_code = er0[1];
        era_year = er0[2];
        er_present = not jsv_is_undefined(ev) and not jsv_is_undefined(eyv);
    }

    mr: list[any] = _temporal_bag_read_int_field(item, "month");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = mr[0] != 0;

    mcv: JSValue = js_object_get_observable(item, str_intern("monthCode"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_mc: bool = not jsv_is_undefined(mcv);
    mc_ord: int = 0;
    leap_month: bool = False;
    if has_mc {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_ord = mc_n;
        leap_month = _month_code_is_leap(mc_s);
    }

    yr: list[any] = _temporal_bag_read_int_field(item, "year");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_y: bool = yr[0] != 0;

    has_era: bool = er_present;
    if (not has_y and not has_era) or (not has_m and not has_mc) {
        vm_throw_native(make_type_error("missing date field"));
        return js_undefined();
    }
    er: list[int] = [0, era_code, era_year];
    y: int = 0;
    if has_y {
        y = yr[1];
    } else {
        y = _temporal_calendar_year_from_era(cal, er[1], er[2]);
    }
    m: int = 0;
    if has_mc {
        m = mc_ord;
    }
    if has_m {
        # month and monthCode, when both present, must agree (§ month/monthCode conflict).
        if has_mc and mr[1] != m {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mr[1];
    }
    # month is a positive integer regardless of overflow (negative → RangeError).
    if has_m and m < 1 {
        vm_throw_native(make_range_error("month must be positive"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    iso_parts: list[int] = _temporal_bag_calendar_to_iso(
        y, m, 1, cal, er[1], er[2], mc_ord, leap_month, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = iso_parts[0];
    m = iso_parts[1];
    if ov == "reject" {
        temporal_reject_ymd(y, m, 1);
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, 1);
        y = bal[0];
        m = bal[1];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not iso_validate_year_month(y, m) {
        vm_throw_native(make_range_error("year-month out of range"));
        return js_undefined();
    }
    return js_plain_year_month_create(y, m, cal);
}

def:priv _temporal_month_day_from_property_bag(
    item: JSValue, options: JSValue
) -> JSValue {
    # Interleaved observable read+coerce in alphabetical key order: calendar first,
    # then day, [era, eraYear,] month, monthCode, year — coerced immediately — then
    # options.overflow. era/eraYear only for non-ISO calendars.
    cv: JSValue = js_object_get_observable(item, str_intern("calendar"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if not jsv_is_undefined(cv) {
        cal = temporal_parse_calendar(cv);
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    uses_era: bool = _temporal_calendar_uses_era(cal);

    dr: list[any] = _temporal_bag_read_int_field(item, "day");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_d: bool = dr[0] != 0;

    er_present: bool = False;
    era_code: int = 0;
    era_year: int = 0;
    if uses_era {
        ev: JSValue = js_object_get_observable(item, str_intern("era"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        eyv: JSValue = js_object_get_observable(item, str_intern("eraYear"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        er0: list[int] = _temporal_bag_era_from_fields(ev, eyv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        era_code = er0[1];
        era_year = er0[2];
        er_present = not jsv_is_undefined(ev) and not jsv_is_undefined(eyv);
    }

    mr: list[any] = _temporal_bag_read_int_field(item, "month");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = mr[0] != 0;

    mcv: JSValue = js_object_get_observable(item, str_intern("monthCode"), item);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_mc: bool = not jsv_is_undefined(mcv);
    mc_ord: int = 0;
    leap_month: bool = False;
    if has_mc {
        mc_s: str = _obs_month_code_str(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_ord = mc_n;
        leap_month = _month_code_is_leap(mc_s);
    }

    yr: list[any] = _temporal_bag_read_int_field(item, "year");
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_year: bool = yr[0] != 0;

    if (not has_m and not has_mc) or not has_d {
        vm_throw_native(make_type_error("missing date field"));
        return js_undefined();
    }
    m: int = 0;
    if has_mc {
        m = mc_ord;
    }
    if has_m {
        # When both month and monthCode are given they must agree (§ month/monthCode
        # conflict → RangeError), same as the date/datetime/year-month bag builders.
        if has_mc and mr[1] != m {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mr[1];
    }
    d: int = dr[1];
    # month/day are positive integers regardless of overflow — a negative value is a
    # RangeError even under overflow:"constrain" (§ month/day must be ≥ 1).
    if (has_m and m < 1) or d < 1 {
        vm_throw_native(make_range_error("month and day must be positive"));
        return js_undefined();
    }
    ref_y: int = 1972;
    if has_year {
        ref_y = yr[1];
    }
    er: list[int] = [0, era_code, era_year];
    ov: str = temporal_get_overflow(options);
    if vm_has_native_exc() {
        return js_undefined();
    }
    iso_parts: list[int] = _temporal_bag_calendar_to_iso(
        ref_y, m, d, cal, er[1], er[2], mc_ord, leap_month, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    ref_y = iso_parts[0];
    m = iso_parts[1];
    d = iso_parts[2];
    if ov == "reject" {
        temporal_reject_ymd(ref_y, m, d);
    } else {
        bal: list[int] = temporal_constrain_ymd(ref_y, m, d);
        m = bal[1];
        d = bal[2];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    # A PlainMonthDay's referenceISOYear is CANONICAL, not the caller's `year`: an
    # input year only disambiguates the calendar month/day, then is discarded. For
    # iso8601 the canonical reference is 1972 (a leap year, so 02-29 stays valid).
    if cal == "iso8601" {
        ref_y = 1972;
    }
    return js_plain_month_day_create(m, d, ref_y, cal);
}

def:pub ToTemporalYearMonth(item: JSValue, options: JSValue) -> JSValue {
    # GetTemporalOverflowOption(options) validates even on the fast copy path
    # (§ToTemporalYearMonth): an invalid overflow string throws RangeError.
    if js_is_plain_year_month(item) {
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalYearMonth returns a fresh CreateTemporalYearMonth, NOT the same
        # object (from(pym) !== pym); preserve the referenceISODay.
        return js_plain_year_month_create_ref(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            _get_str_slot(item, KEY_CALENDAR)
        );
    }
    if js_is_plain_date(item)
        or js_is_plain_datetime(item)
        or js_is_zoned_datetime(item) {
        r_ym: JSValue = js_plain_year_month_create(
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_str_slot(item, KEY_CALENDAR)
        );
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return r_ym;
    }
    if jsv_is_undefined(item)
        or jsv_is_null(item)
        or jsv_is_bool(item)
        or jsv_is_int32(item)
        or jsv_is_double(item)
        or jsv_is_bigint_cell(item)
        or jsv_is_symbol(item) {
        vm_throw_native(make_type_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    if jsv_is_object_cell(item) {
        # Any non-branded object is a property bag; the builder reads fields observably
        # (getters fire in spec order) and throws when the required ones are absent.
        return _temporal_year_month_from_property_bag(item, options);
    }
    if not jsv_is_string_cell(item) {
        vm_throw_native(make_type_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(item));
    pr: list[any] = parse_iso_date_time(s);
    # Capture the parsed calendar immediately (str-in-list bug: string parse fields
    # are module globals overwritten by any later parse). Refreshed in the retry.
    pr_cal_captured: str = PR_S_CALENDAR;
    # A PlainYearMonth string may be the day-less form "YYYY-MM" (TemporalYearMonthString),
    # which the full date-time parser rejects for lacking a day. Retry with a synthetic
    # reference day so "2013-06" parses; a full date string ("2013-06-15") also works and
    # just contributes its year+month.
    if not pr[PR_OK] or not pr[PR_HAS_DATE] or pr[PR_YEAR] == 0 or pr[PR_MONTH] == 0 {
        # The day-less form "YYYY-MM" (optionally with an annotation the full parser
        # accepts). Only retry when the date part is EXACTLY a valid year-month —
        # 4-digit year + "-" + 2-digit month 01-12 — so genuinely-invalid strings
        # ("2020-13", "+999999-01", "1976-11[u-ca=gregory]") still reject. Insert the
        # reference day before any [annotation], then re-parse for full annotation rules.
        br: int = _temporal_index_of(s, "[");
        date_part: str = s;
        if br >= 0 {
            date_part = s[0:br];
        }
        with_ref: str = _temporal_year_month_ref_day_str(date_part);
        ym_ok: bool = len(with_ref) != 0;
        if ym_ok {
            s_try: str = with_ref;
            if br >= 0 {
                s_try = with_ref + s[br:len(s)];
            }
            pr2: list[any] = parse_iso_date_time(s_try);
            if pr2[PR_OK]
                and pr2[PR_HAS_DATE]
                and pr2[PR_YEAR] != 0
                and pr2[PR_MONTH] != 0 {
                pr = pr2;
                # A day-less year-month string may only carry the iso8601 calendar: a
                # non-ISO [u-ca=…] needs a reference day, so "1976-11[u-ca=gregory]" is
                # invalid (while "1976-11-15[u-ca=gregory]" — with a day — is not).
                cal2: str = PR_S_CALENDAR;
                pr_cal_captured = cal2;
                if len(cal2) == 0 {
                    cal2 = extract_calendar_annotation(s_try);
                }
                if len(cal2) != 0 and cal2 != "iso8601" {
                    ym_ok = False;
                }
            } else {
                ym_ok = False;
            }
        }
        if not ym_ok {
            vm_throw_native(make_range_error("invalid PlainYearMonth"));
            return js_undefined();
        }
    }
    # A UTC designator "Z" (the string denotes an exact instant) is invalid for a plain
    # type; likewise a numeric offset with no time component ("2022-09-15Z"-style).
    if pr[PR_IS_Z] != 0 {
        vm_throw_native(make_range_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    if pr[PR_HAS_OFFSET] and not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    y: int = pr[PR_YEAR];
    m: int = pr[PR_MONTH];
    # The year-month must be within [-271821-04, +275760-09] (month-granular). Both
    # "-271821-04" (min) and "+999999-01" (out of range) are decided by (y, m) alone.
    if not iso_validate_year_month(y, m) {
        vm_throw_native(make_range_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    # For a STRING argument the parsed date-time (including its reference day) must also
    # be within the ISO date-time range: "-271821-04" parses to the min datetime's
    # midnight, which is excluded, so it is out of range even though (y, m) alone pass
    # the month-granular year-month check.
    if not iso_validate_datetime_within_limits(
        y, m, pr[PR_DAY], pr[PR_HOUR], pr[PR_MINUTE], pr[PR_SECOND], pr[PR_NANOSECOND]
    ) {
        vm_throw_native(make_range_error("invalid PlainYearMonth"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(options);
    if ov == "reject" {
        temporal_reject_ymd(y, m, 1);
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, 1);
        y = bal[0];
        m = bal[1];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = pr_cal_captured;
    if len(cal) == 0 {
        cal = extract_calendar_annotation(s);
    }
    if len(cal) == 0 {
        cal = "iso8601";
    }
    if not calendar_is_known(cal) {
        vm_throw_native(make_range_error("invalid calendar"));
        return js_undefined();
    }
    return js_plain_year_month_create(y, m, cal);
}

def:pub ToTemporalMonthDay(item: JSValue, options: JSValue) -> JSValue {
    # GetTemporalOverflowOption(options) validates even on the fast copy path
    # (§ToTemporalMonthDay): an invalid overflow string throws RangeError.
    if js_is_plain_month_day(item) {
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalMonthDay returns a fresh CreateTemporalMonthDay, NOT the same object;
        # preserve month, day, and referenceISOYear.
        return js_plain_month_day_create(
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            _get_int_slot(item, KEY_ISO_YEAR),
            _get_str_slot(item, KEY_CALENDAR)
        );
    }
    if js_is_plain_date(item)
        or js_is_plain_datetime(item)
        or js_is_zoned_datetime(item) {
        # Extracting month/day from a Date-like: the referenceISOYear is CANONICAL (1972
        # for the ISO calendar), not the source's ISO year.
        md_cal: str = _get_str_slot(item, KEY_CALENDAR);
        md_ref_y: int = _get_int_slot(item, KEY_ISO_YEAR);
        if md_cal == "iso8601" {
            md_ref_y = 1972;
        }
        r_md: JSValue = js_plain_month_day_create(
            _get_int_slot(item, KEY_ISO_MONTH),
            _get_int_slot(item, KEY_ISO_DAY),
            md_ref_y,
            md_cal
        );
        _ = temporal_get_overflow(options);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return r_md;
    }
    if jsv_is_undefined(item)
        or jsv_is_null(item)
        or jsv_is_bool(item)
        or jsv_is_int32(item)
        or jsv_is_double(item)
        or jsv_is_bigint_cell(item)
        or jsv_is_symbol(item) {
        vm_throw_native(make_type_error("invalid PlainMonthDay"));
        return js_undefined();
    }
    if jsv_is_object_cell(item) {
        # Any non-branded object is a property bag; the builder reads fields observably
        # (getters fire in spec order) and throws when the required ones are absent.
        return _temporal_month_day_from_property_bag(item, options);
    }
    if not jsv_is_string_cell(item) {
        vm_throw_native(make_type_error("invalid PlainMonthDay"));
        return js_undefined();
    }
    s: str = str_from_id(jsv_to_table_id(item));
    pr: list[any] = parse_iso_date_time(s);
    # Capture parsed calendar now (str-in-list bug — see PlainYearMonth above).
    pmd_cal_captured: str = PR_S_CALENDAR;
    if not pr[PR_OK] or not pr[PR_HAS_DATE] or pr[PR_MONTH] == 0 or pr[PR_DAY] == 0 {
        # The year-less month-day forms "--MM-DD" / "MM-DD" (TemporalMonthDayString),
        # which the full date-time parser rejects for lacking a year. Retry with a
        # synthetic reference year (1972, a leap year, so Feb 29 is valid). Only for a
        # strict MM-DD shape and iso8601-or-no calendar (a non-ISO [u-ca] needs a year).
        md_part: str = s;
        br_md: int = _temporal_index_of(s, "[");
        if br_md >= 0 {
            md_part = s[0:br_md];
        }
        md_norm: str = md_part;
        if len(md_norm) >= 2 and md_norm[0:2] == "--" {
            md_norm = md_norm[2:len(md_norm)];
        }
        pr_md: list[any] = [False];
        s_try_md: str = "1972-" + md_norm;
        if br_md >= 0 {
            s_try_md = s_try_md + s[br_md:len(s)];
        }
        if _temporal_is_month_day_shape(md_norm) {
            pr_md = parse_iso_date_time(s_try_md);
        }
        if len(pr_md) > PR_DAY
            and pr_md[PR_OK]
            and pr_md[PR_HAS_DATE]
            and pr_md[PR_MONTH] != 0
            and pr_md[PR_DAY] != 0 {
            cal_md: str = PR_S_CALENDAR;
            pmd_cal_captured = cal_md;
            if len(cal_md) == 0 {
                cal_md = extract_calendar_annotation(s_try_md);
            }
            if len(cal_md) != 0 and cal_md != "iso8601" {
                vm_throw_native(make_range_error("invalid PlainMonthDay"));
                return js_undefined();
            }
            pr = pr_md;
        } else {
            vm_throw_native(make_range_error("invalid PlainMonthDay"));
            return js_undefined();
        }
    }
    # A UTC designator / offset-without-time makes the string an instant, not a plain type.
    if pr[PR_IS_Z] != 0 {
        vm_throw_native(make_range_error("invalid PlainMonthDay"));
        return js_undefined();
    }
    if pr[PR_HAS_OFFSET] and not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid PlainMonthDay"));
        return js_undefined();
    }
    ref_y: int = pr[PR_YEAR];
    if ref_y == 0 {
        ref_y = 1972;
    }
    m: int = pr[PR_MONTH];
    d: int = pr[PR_DAY];
    ov: str = temporal_get_overflow(options);
    if ov == "reject" {
        temporal_reject_ymd(ref_y, m, d);
    } else {
        bal: list[int] = temporal_constrain_ymd(ref_y, m, d);
        m = bal[1];
        d = bal[2];
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = pmd_cal_captured;
    if len(cal) == 0 {
        cal = extract_calendar_annotation(s);
    }
    if len(cal) == 0 {
        cal = "iso8601";
    }
    if not calendar_is_known(cal) {
        vm_throw_native(make_range_error("invalid calendar"));
        return js_undefined();
    }
    # A PlainMonthDay's referenceISOYear is CANONICAL for the ISO calendar (1972, a leap
    # year) — a parsed year (e.g. "2016-12-31T23:59:60") only disambiguates month/day and
    # is then discarded, not carried into the reference year.
    if cal == "iso8601" {
        ref_y = 1972;
    }
    return js_plain_month_day_create(m, d, ref_y, cal);
}

def:pub temporal_plain_date_getter(o: JSValue, name: str) -> JSValue {
    y: int = _get_int_slot(o, KEY_ISO_YEAR);
    m: int = _get_int_slot(o, KEY_ISO_MONTH);
    d: int = _get_int_slot(o, KEY_ISO_DAY);
    cal: str = _get_str_slot(o, KEY_CALENDAR);
    if name == "calendarId" {
        return _js_str(cal);
    }
    if name == "dayOfWeek" {
        return js_int(iso_day_of_week(y, m, d));
    }
    if name == "dayOfYear" {
        fields_doy: list[int] = calendar_iso_to_fields(y, m, d, cal);
        return js_int(calendar_field_day_of_year(fields_doy));
    }
    wk: list[int] = iso_week_of_year(y, m, d);
    if name == "weekOfYear" {
        return js_int(wk[0]);
    }
    if name == "yearOfWeek" {
        return js_int(wk[1]);
    }
    fields_cal: list[int] = calendar_iso_to_fields(y, m, d, cal);
    if name == "daysInMonth" {
        return js_int(calendar_field_days_in_month(fields_cal));
    }
    if name == "daysInYear" {
        return js_int(calendar_field_days_in_year(fields_cal));
    }
    if name == "monthsInYear" {
        return js_int(calendar_field_months_in_year(fields_cal));
    }
    if name == "inLeapYear" {
        return js_boolean(calendar_field_in_leap_year(fields_cal));
    }
    if name == "daysInWeek" {
        return js_int(7);
    }
    fields: list[int] = fields_cal;
    if name == "day" {
        return js_int(fields[CF_DAY]);
    }
    if name == "year" {
        return js_int(fields[CF_YEAR]);
    }
    if name == "month" {
        return js_int(fields[CF_MONTH]);
    }
    if name == "monthCode" {
        mc: str = calendar_field_month_code(fields);
        if len(mc) > 0 {
            return _js_str(mc);
        }
        return js_undefined();
    }
    if name == "era" {
        era_s: str = calendar_field_era(fields);
        if len(era_s) > 0 {
            return _js_str(era_s);
        }
        return js_undefined();
    }
    if name == "eraYear" {
        era_s2: str = calendar_field_era(fields);
        if len(era_s2) > 0 {
            return js_int(calendar_field_era_year(fields));
        }
        return js_undefined();
    }
    return js_undefined();
}

def:pub temporal_plain_time_getter(o: JSValue, name: str) -> JSValue {
    h: int = _get_int_slot(o, KEY_ISO_HOUR);
    mi: int = _get_int_slot(o, KEY_ISO_MINUTE);
    s: int = _get_int_slot(o, KEY_ISO_SECOND);
    ns: int = _get_int_slot(o, KEY_ISO_NANOSECOND);
    cal: str = _get_str_slot(o, KEY_CALENDAR);
    if name == "calendarId" {
        return _js_str(cal);
    }
    if name == "hour" {
        return js_int(h);
    }
    if name == "minute" {
        return js_int(mi);
    }
    if name == "second" {
        return js_int(s);
    }
    if name == "millisecond" {
        return js_int(ns // 1000000);
    }
    if name == "microsecond" {
        return js_int((ns % 1000000) // 1000);
    }
    if name == "nanosecond" {
        return js_int(ns % 1000);
    }
    return js_undefined();
}

def:pub temporal_plain_datetime_getter(o: JSValue, name: str) -> JSValue {
    pd: JSValue = js_plain_date_create(
        _get_int_slot(o, KEY_ISO_YEAR),
        _get_int_slot(o, KEY_ISO_MONTH),
        _get_int_slot(o, KEY_ISO_DAY),
        _get_str_slot(o, KEY_CALENDAR)
    );
    pt: JSValue = js_plain_time_create(
        _get_int_slot(o, KEY_ISO_HOUR),
        _get_int_slot(o, KEY_ISO_MINUTE),
        _get_int_slot(o, KEY_ISO_SECOND),
        _get_int_slot(o, KEY_ISO_NANOSECOND),
        _get_str_slot(o, KEY_CALENDAR)
    );
    if name == "calendarId" {
        return temporal_plain_date_getter(pd, "calendarId");
    }
    if name == "year"
        or name == "month"
        or name == "monthCode"
        or name == "day"
        or name == "dayOfWeek"
        or name == "dayOfYear"
        or name == "weekOfYear"
        or name == "yearOfWeek"
        or name == "daysInMonth"
        or name == "daysInYear"
        or name == "monthsInYear"
        or name == "inLeapYear"
        or name == "daysInWeek"
        or name == "era"
        or name == "eraYear" {
        return temporal_plain_date_getter(pd, name);
    }
    return temporal_plain_time_getter(pt, name);
}

def:pub temporal_instant_getter(o: JSValue, name: str) -> JSValue {
    ns: list[int] = js_instant_read_ns(o);
    if name == "epochMilliseconds" {
        # epochMilliseconds = floor(epochNs / 1e6) toward -∞. bn_divmod truncates toward
        # zero, so for a negative value with a nonzero remainder subtract one to floor
        # (−217175010876543211 ns → −217175010877 ms, not −…876).
        q: list[int] = bn_divmod(ns, bn_from_int(1000000));
        if bn_sign(ns) < 0 and bn_sign(_BN_DIV_REM) != 0 {
            q = bn_sub(q, bn_from_int(1));
        }
        return js_number(float(bn_to_string(q, 10)));
    }
    if name == "epochNanoseconds" {
        return jsv_from_cell_kind(
            str_intern(bn_to_string(ns, 10)), JS_CELL_KIND_BIGINT
        );
    }
    return js_undefined();
}

def:pub temporal_format_offset_ns(off_s: int) -> str {
    sign: str = "+";
    aoff: int = off_s;
    if off_s < 0 {
        sign = "-";
        aoff = -off_s;
    }
    hr: int = aoff // 3600;
    mn: int = (aoff % 3600) // 60;
    hs: str = str(hr);
    if hr < 10 {
        hs = "0" + hs;
    }
    ms: str = str(mn);
    if mn < 10 {
        ms = "0" + ms;
    }
    out: str = sign;
    out = out + hs;
    out = out + ":";
    out = out + ms;
    return out;
}

def:pub temporal_zoned_datetime_getter(o: JSValue, name: str) -> JSValue {
    if name == "timeZoneId" {
        return _js_str(_get_str_slot(o, KEY_TIMEZONE));
    }
    if name == "offsetNanoseconds" {
        off_s: int = _get_int_slot(o, KEY_OFFSET_NS);
        off_ns_bn: list[int] = bn_mul_small(bn_from_int(off_s), 1000000000);
        return jsv_from_cell_kind(
            str_intern(bn_to_string(off_ns_bn, 10)), JS_CELL_KIND_BIGINT
        );
    }
    if name == "offset" {
        return _js_str(temporal_format_offset_ns(_get_int_slot(o, KEY_OFFSET_NS)));
    }
    if name == "epochNanoseconds" {
        ns: list[int] = js_zoned_read_ns(o);
        return jsv_from_cell_kind(
            str_intern(bn_to_string(ns, 10)), JS_CELL_KIND_BIGINT
        );
    }
    if name == "epochMilliseconds" {
        ns: list[int] = js_zoned_read_ns(o);
        q: list[int] = bn_divmod(ns, bn_from_int(1000000));
        # floor toward -∞ (bn_divmod truncates toward zero).
        if bn_sign(ns) < 0 and bn_sign(_BN_DIV_REM) != 0 {
            q = bn_sub(q, bn_from_int(1));
        }
        return js_number(float(bn_to_string(q, 10)));
    }
    if name == "hoursInDay" {
        y: int = _get_int_slot(o, KEY_ISO_YEAR);
        m: int = _get_int_slot(o, KEY_ISO_MONTH);
        d: int = _get_int_slot(o, KEY_ISO_DAY);
        tz: str = _get_str_slot(o, KEY_TIMEZONE);
        if tz == "UTC" or tz == "" {
            return js_int(24);
        }
        if len(tz) > 0 and (tz[0:1] == "+" or tz[0:1] == "-") {
            return js_int(24);
        }
        days: int = iso_days_from_ymd(y, m, d);
        start_s: int = days * 86400;
        end_s: int = start_s + 86400;
        handle: int = tz_load_zone(tz);
        if handle == 0 {
            return js_int(24);
        }
        off_start: tuple[int, bool] = tz_get_offset(handle, start_s);
        off_end: tuple[int, bool] = tz_get_offset(handle, end_s);
        tz_unload(handle);
        hrs: int = (end_s + off_end[0] - (start_s + off_start[0])) // 3600;
        if hrs < 0 {
            hrs = -hrs;
        }
        return js_int(hrs);
    }
    return temporal_plain_datetime_getter(o, name);
}

def:pub temporal_throw_valueof -> JSValue {
    vm_throw_native(make_type_error("Temporal valueOf not supported"));
    return js_undefined();
}

def:pub temporal_get_calendar_name(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "auto";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "auto";
    }
    cv: JSValue = js_object_get_observable(
        options, str_intern("calendarName"), options
    );
    if vm_has_native_exc() {
        return "auto";
    }
    if jsv_is_undefined(cv) {
        return "auto";
    }
    s: str = js_to_string_observable(cv);
    if vm_has_native_exc() {
        return "auto";
    }
    if s == "auto" or s == "always" or s == "never" or s == "critical" {
        return s;
    }
    vm_throw_native(make_range_error("invalid calendarName"));
    return "auto";
}

"""ToShowOffsetOption for ZonedDateTime.toString: "auto" (default) or "never"."""
def:pub temporal_get_show_offset(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "auto";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "auto";
    }
    ov: JSValue = js_object_get_observable(options, str_intern("offset"), options);
    if vm_has_native_exc() {
        return "auto";
    }
    if jsv_is_undefined(ov) {
        return "auto";
    }
    s: str = js_to_string_observable(ov);
    if vm_has_native_exc() {
        return "auto";
    }
    if s == "auto" or s == "never" {
        return s;
    }
    vm_throw_native(make_range_error("invalid offset"));
    return "auto";
}

"""ToShowTimeZoneNameOption for ZonedDateTime.toString: "auto" (default), "never", or
"critical"."""
def:pub temporal_get_time_zone_name(options: JSValue) -> str {
    if jsv_is_undefined(options) {
        return "auto";
    }
    if not _temporal_options_is_valid(options) {
        vm_throw_native(make_type_error("invalid options"));
        return "auto";
    }
    tv: JSValue = js_object_get_observable(
        options, str_intern("timeZoneName"), options
    );
    if vm_has_native_exc() {
        return "auto";
    }
    if jsv_is_undefined(tv) {
        return "auto";
    }
    s: str = js_to_string_observable(tv);
    if vm_has_native_exc() {
        return "auto";
    }
    if s == "auto" or s == "never" or s == "critical" {
        return s;
    }
    vm_throw_native(make_range_error("invalid timeZoneName"));
    return "auto";
}

def:pub temporal_format_calendar_suffix(cal: str, calendar_name: str) -> str {
    show: str = calendar_name;
    if len(show) == 0 {
        show = "auto";
    }
    if show == "never" {
        return "";
    }
    is_iso: bool = cal == "iso8601" or len(cal) == 0;
    if show == "auto" and is_iso {
        return "";
    }
    if show == "critical" {
        return "[!u-ca=" + cal + "]";
    }
    # always, or auto for non-ISO
    return "[u-ca=" + cal + "]";
}
