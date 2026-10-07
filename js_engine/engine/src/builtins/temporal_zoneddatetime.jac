"""Temporal.ZonedDateTime built-in — uses ffi/tz for IANA zones."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_int,
    js_number,
    js_boolean,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_double,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_bigint_cell,
    jsv_to_table_id,
    jsv_is_undefined,
    jsv_is_string_cell
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject { js_object_get, js_object_set, js_object_keys }
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_parse {
    parse_iso_date_time,
    PR_OK,
    PR_YEAR,
    PR_MONTH,
    PR_DAY,
    PR_HOUR,
    PR_MINUTE,
    PR_SECOND,
    PR_NANOSECOND,
    PR_OFFSET_S,
    PR_TZ_ANNOTATION,
    PR_HAS_DATE,
    PR_HAS_TIME,
    PR_HAS_OFFSET,
    PR_CALENDAR,
    PR_IS_Z,
    parse_utc_offset_string,
    parse_month_code,
    PR_S_TZ_ANNOTATION,
    PR_S_CALENDAR
}
import from engine.src.ffi.tz {
    tz_load_zone,
    tz_get_offset,
    tz_unload,
    tz_get_next_transition
}
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }
import from engine.src.runtime.temporal_duration_math {
    DUR_YEARS,
    DUR_MONTHS,
    DUR_WEEKS,
    DUR_DAYS,
    DUR_HOURS,
    DUR_MINUTES,
    DUR_SECONDS,
    DUR_NANOSECONDS,
    DUR_SIGN,
    dur_from_components,
    dur_balance,
    dur_round,
    dur_total,
    dur_add_to_iso_ymd,
    ROUND_TRUNC,
    dur_validate_rounding_increment,
    dur_negate,
    rounding_mode_from_string,
    negate_rounding_mode_string,
    ROUND_HALF_EXPAND,
    ROUND_HALF_TRUNC,
    ROUND_HALF_EVEN,
    ROUND_CEIL,
    ROUND_FLOOR,
    ROUND_EXPAND,
    ROUND_HALF_CEIL,
    ROUND_HALF_FLOOR
}
import from engine.src.builtins.calendars.calendar_arithmetic {
    calendar_date_add,
    calendar_date_until
}
import from engine.src.runtime.temporal_iso {
    iso_format_date,
    iso_format_time,
    iso_days_from_ymd,
    iso_ymd_from_days,
    iso_nanoseconds_to_time,
    iso_add_days,
    iso_add_months,
    iso_add_time,
    iso_total_nanoseconds,
    iso_balance_date,
    iso_format_time_precision,
    iso_validate_relativeto_instant,
    iso_validate_datetime_within_limits
}
import from engine.src.runtime.bignat {
    bn_from_int,
    bn_parse_decimal,
    bn_to_string,
    bn_divmod,
    bn_cmp,
    bn_sub,
    bn_neg,
    bn_sign,
    bn_add,
    bn_mul_small,
    _BN_DIV_REM
}
import from engine.src.builtins.temporal {
    js_duration_create,
    js_zoned_datetime_create,
    js_zoned_datetime_init,
    js_this_zoned_datetime,
    js_is_zoned_datetime,
    js_is_instant,
    js_instant_read_ns,
    js_instant_create,
    js_zoned_read_ns,
    js_plain_date_create,
    js_plain_time_create,
    js_plain_datetime_create,
    temporal_to_string,
    temporal_parse_calendar,
    temporal_reject_ymd,
    temporal_reject_time,
    temporal_zoned_datetime_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    temporal_format_calendar_suffix,
    temporal_get_calendar,
    temporal_get_rounding_mode,
    temporal_get_round_rounding_mode,
    temporal_get_rounding_increment,
    temporal_instant_round_max_increment,
    temporal_require_options_object,
    temporal_get_largest_unit,
    ToTemporalTimeZoneIdentifier,
    ToTemporalTimeZoneIdentifierStrict,
    ToOffsetString,
    temporal_apply_difference_rounding,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    _temporal_zoned_from_property_bag,
    temporal_format_offset_ns,
    temporal_offset_ns_for_zone,
    temporal_constrain_ymd,
    temporal_str_copy,
    temporal_resolve_zone_offset_seconds,
    temporal_zoned_from_epoch_ns_string,
    temporal_zoned_from_epoch_ns_string_on,
    temporal_format_time_to_string,
    temporal_read_zdt_tostring,
    _temporal_round_wallclock,
    temporal_get_calendar_name,
    temporal_get_disambiguation,
    temporal_get_offset_option,
    temporal_get_timezone_from_zdt_options,
    temporal_round_epoch_ns,
    ToTemporalTime,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_ISO_HOUR,
    KEY_ISO_MINUTE,
    KEY_ISO_SECOND,
    KEY_ISO_NANOSECOND,
    KEY_TIMEZONE,
    KEY_OFFSET_NS,
    KEY_CALENDAR,
    KEY_NANOSECONDS,
    temporal_get_overflow
}
import from engine.src.vm.vm_obs { js_object_get_observable, js_to_string_observable }

glob _ZDT_STR_DIVMOD_REM: int = 0;

def:priv _zdt_trim_zeros(s: str) -> str {
    i: int = 0;
    n: int = len(s);
    while i < n - 1 {
        if s[i:i + 1] != "0" {
            break;
        }
        i = i + 1;
    }
    out: str = "";
    while i < n {
        out = out + s[i:i + 1];
        i = i + 1;
    }
    return out;
}

def:priv _zdt_str_divmod_int(s: str, div: int) -> str {
    if div == 0 {
        _ZDT_STR_DIVMOD_REM = 0;
        return "0";
    }
    rem: int = 0;
    q: str = "";
    i: int = 0;
    n: int = len(s);
    while i < n {
        rem = rem * 10 + int(s[i:i + 1]);
        q = q + str(rem // div);
        rem = rem % div;
        i = i + 1;
    }
    _ZDT_STR_DIVMOD_REM = rem;
    return _zdt_trim_zeros(q);
}

def:priv _zdt_str_mul_int(s: str, n: int) -> str {
    if n == 0 or s == "0" or len(s) == 0 {
        return "0";
    }
    carry: int = 0;
    out: str = "";
    i: int = len(s) - 1;
    while i >= 0 {
        d: int = int(s[i:i + 1]);
        prod: int = d * n + carry;
        carry = prod // 10;
        out = str(prod % 10) + out;
        i = i - 1;
    }
    if carry > 0 {
        out = str(carry) + out;
    }
    return _zdt_trim_zeros(out);
}

def:priv _get_int(o: JSValue, key: int) -> int {
    v: JSValue = js_object_get(o, key);
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def:priv _to_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _offset_ns_for_zone(
    tz: str, y: int, m: int, d: int, h: int, mi: int, s: int
) -> int {
    if tz == "UTC" or tz == "" {
        return 0;
    }
    handle: int = tz_load_zone(tz);
    if handle == 0 {
        return 0;
    }
    days: int = iso_days_from_ymd(y, m, d);
    epoch_s: int = days * 86400 + h * 3600 + mi * 60 + s;
    off: tuple[int, bool] = tz_get_offset(handle, epoch_s);
    tz_unload(handle);
    return off[0] * 1000000000;
}

def _ns_parts_from_epoch(total_ns: int) -> list[int] {
    epoch_s: int = total_ns // 1000000000;
    rem_ns: int = total_ns - epoch_s * 1000000000;
    if total_ns < 0 and rem_ns != 0 {
        epoch_s = epoch_s - 1;
        rem_ns = rem_ns + 1000000000;
    }
    # Jac int `//` already floors (verified native) — no truncation correction.
    days: int = epoch_s // 86400;
    sec_in_day: int = epoch_s - days * 86400;
    ymd: list[int] = iso_ymd_from_days(days);
    day_ns: int = sec_in_day * 1000000000 + rem_ns;
    t: list[int] = iso_nanoseconds_to_time(day_ns);
    return [ymd[0], ymd[1], ymd[2], t[0], t[1], t[2], t[3]];
}

def:priv _zdt_normalize_ns_string(s: str) -> str {
    epos: int = -1;
    scan: int = 0;
    while scan < len(s) {
        c: str = s[scan:scan + 1];
        if c == "e" or c == "E" {
            epos = scan;
            break;
        }
        scan = scan + 1;
    }
    if epos < 0 {
        return s;
    }
    mant: str = s[0:epos];
    exp_part: str = s[epos + 1:len(s)];
    exp: int = int(exp_part);
    dot: int = -1;
    scan2: int = 0;
    while scan2 < len(mant) {
        if mant[scan2:scan2 + 1] == "." {
            dot = scan2;
            break;
        }
        scan2 = scan2 + 1;
    }
    digits: str = mant;
    dec_places: int = 0;
    if dot >= 0 {
        digits = mant[0:dot] + mant[dot + 1:len(mant)];
        dec_places = len(mant) - dot - 1;
    }
    zeros: int = exp - dec_places;
    if zeros < 0 {
        return s;
    }
    out: str = digits;
    zi: int = 0;
    while zi < zeros {
        out = out + "0";
        zi = zi + 1;
    }
    return out;
}

def _ns_parts_from_ns_string(ns_s: str) -> list[int] {
    ns_s = _zdt_normalize_ns_string(ns_s);
    neg: bool = False;
    if len(ns_s) > 0 and ns_s[0:1] == "-" {
        neg = True;
        ns_s = ns_s[1:len(ns_s)];
    }
    epoch_s_str: str = _zdt_str_divmod_int(ns_s, 1000000000);
    rem_ns: int = _ZDT_STR_DIVMOD_REM;
    days_str: str = _zdt_str_divmod_int(epoch_s_str, 86400);
    days: int = int(days_str);
    sec_in_day: int = _ZDT_STR_DIVMOD_REM;
    # (days, sec_in_day, rem_ns) is the floor-decomposition of the ABSOLUTE value. For a
    # negative instant, negate with a single whole-day borrow so day_ns stays in
    # [0, 86400e9) and `days` is the true (negative) day index. The previous
    # `days = days + 1` normalization produced the positive mirror date (pre-1970 ZDT
    # rendered a year+ later — 1969-07-24 became 1970-06-12).
    if neg {
        sub_day_ns: int = sec_in_day * 1000000000 + rem_ns;
        if sub_day_ns == 0 {
            days = -days;
        } else {
            days = -days - 1;
            day_total: int = 86400000000000 - sub_day_ns;
            sec_in_day = day_total // 1000000000;
            rem_ns = day_total % 1000000000;
        }
    }
    ymd: list[int] = iso_ymd_from_days(days);
    day_ns: int = sec_in_day * 1000000000 + rem_ns;
    t: list[int] = iso_nanoseconds_to_time(day_ns);
    return [ymd[0], ymd[1], ymd[2], t[0], t[1], t[2], t[3]];
}

def _zdt_instant_to_local_parts(ns_s: str, zone_id: str) -> list[int] {
    utc: list[int] = _ns_parts_from_ns_string(ns_s);
    if zone_id == "UTC" or zone_id == "" {
        return utc;
    }
    if len(zone_id) > 0 and (zone_id[0:1] == "+" or zone_id[0:1] == "-") {
        off_parse: list[any] = parse_utc_offset_string(zone_id);
        if off_parse[0] != 0 {
            off_s: int = off_parse[1];
            days: int = iso_days_from_ymd(utc[0], utc[1], utc[2]);
            utc_epoch_s: int = days * 86400 + utc[3] * 3600 + utc[4] * 60 + utc[5];
            local_epoch_s: int = utc_epoch_s + off_s;
            ldays: int = local_epoch_s // 86400;
            sec_in_day: int = local_epoch_s - ldays * 86400;
            ymd: list[int] = iso_ymd_from_days(ldays);
            day_ns: int = sec_in_day * 1000000000 + utc[6];
            t: list[int] = iso_nanoseconds_to_time(day_ns);
            return [ymd[0], ymd[1], ymd[2], t[0], t[1], t[2], t[3]];
        }
        return utc;
    }
    days: int = iso_days_from_ymd(utc[0], utc[1], utc[2]);
    utc_epoch_s: int = days * 86400 + utc[3] * 3600 + utc[4] * 60 + utc[5];
    handle: int = tz_load_zone(zone_id);
    if handle == 0 {
        return utc;
    }
    tz_off: tuple[int, bool] = tz_get_offset(handle, utc_epoch_s);
    tz_unload(handle);
    local_epoch_s: int = utc_epoch_s + tz_off[0];
    ldays: int = local_epoch_s // 86400;
    sec_in_day: int = local_epoch_s - ldays * 86400;
    ymd: list[int] = iso_ymd_from_days(ldays);
    day_ns: int = sec_in_day * 1000000000 + utc[6];
    t: list[int] = iso_nanoseconds_to_time(day_ns);
    return [ymd[0], ymd[1], ymd[2], t[0], t[1], t[2], t[3]];
}

def _zdt_finish(
    this_val: JSValue,
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    tz: str,
    off_s: int,
    cal: str
) -> JSValue {
    if jsv_is_object_cell(this_val) and jsv_to_table_id(this_val) > 0 {
        return js_zoned_datetime_init(this_val, y, m, d, h, mi, s, ns, tz, off_s, cal);
    }
    return js_zoned_datetime_create(y, m, d, h, mi, s, ns, tz, off_s, cal);
}

def _zdt_from_ns_string_on(this_val: JSValue, spec: list[any], cal: str) -> JSValue {
    tz: str = temporal_str_copy(spec[0]);
    ns_s: str = spec[1];
    parts: list[int] = _zdt_instant_to_local_parts(ns_s, tz);
    y: int = parts[0];
    m: int = parts[1];
    d: int = parts[2];
    h: int = parts[3];
    mi: int = parts[4];
    sc: int = parts[5];
    nsv: int = parts[6];
    off_s: int = temporal_offset_ns_for_zone(tz, y, m, d, h, mi, sc);
    return _zdt_finish(this_val, y, m, d, h, mi, sc, nsv, tz, off_s, cal);
}

def:pub temporal_zoned_epoch_ns_to_zdt(ns_s: str, tz: str, cal: str) -> JSValue {
    parts: list[int] = _zdt_instant_to_local_parts(ns_s, tz);
    y: int = parts[0];
    m: int = parts[1];
    d: int = parts[2];
    h: int = parts[3];
    mi: int = parts[4];
    sc: int = parts[5];
    nsv: int = parts[6];
    off_s: int = temporal_offset_ns_for_zone(tz, y, m, d, h, mi, sc);
    return js_zoned_datetime_create(y, m, d, h, mi, sc, nsv, tz, off_s, cal);
}

def _zdt_from_ns_string(ns_s: str, tz: str, cal: str) -> JSValue {
    return temporal_zoned_epoch_ns_to_zdt(ns_s, tz, cal);
}

def:pub temporal_zoned_from_epoch_ns_string(ns_s: str, tz: str, cal: str) -> JSValue {
    return _zdt_from_ns_string(ns_s, tz, cal);
}

def:pub temporal_zoned_from_epoch_ns_string_on(
    this_val: JSValue, ns_s: str, tz: str, cal: str
) -> JSValue {
    spec: list[any] = [temporal_str_copy(tz), ns_s];
    return _zdt_from_ns_string_on(this_val, spec, cal);
}

def:priv _zdt_tz_has_transitions(tz: str) -> bool {
    if tz == "UTC" or tz == "" {
        return False;
    }
    if len(tz) > 0 and (tz[0:1] == "+" or tz[0:1] == "-") {
        return False;
    }
    return True;
}

def _zdt_from_epoch_nanoseconds(ns: list[int]) -> JSValue {
    ns_s: str = bn_to_string(ns, 10);
    return _zdt_from_ns_string(ns_s, "UTC", "iso8601");
}

def:pub js_Temporal_ZonedDateTime(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(
            make_type_error("ZonedDateTime constructor requires 2 arguments")
        );
        return js_undefined();
    }
    tz_id: str = ToTemporalTimeZoneIdentifierStrict(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tz_box: list[any] = [temporal_str_copy(tz_id)];
    a0: JSValue = args[0];
    if js_is_instant(a0) {
        ns_s: str = bn_to_string(js_instant_read_ns(a0), 10);
        return temporal_zoned_from_epoch_ns_string_on(
            this_val, ns_s, tz_box[0], "iso8601"
        );
    }
    if jsv_is_bigint_cell(a0) {
        ns_s: str = temporal_to_string(a0);
        return temporal_zoned_from_epoch_ns_string_on(
            this_val, ns_s, tz_box[0], "iso8601"
        );
    }
    result: JSValue = js_Temporal_ZonedDateTime_from(args);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if jsv_is_object_cell(this_val)
        and jsv_to_table_id(this_val) > 0
        and result != this_val {
        ek: list[int] = js_object_keys(result);
        i: int = 0;
        while i < len(ek) {
            js_object_set(this_val, ek[i], js_object_get(result, ek[i]));
            i = i + 1;
        }
        return this_val;
    }
    return result;
}

def _temporal_zoned_from_local_roundtrip(
    tz: str,
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    cal: str,
    disambiguation: str
) -> JSValue {
    off_s: int = temporal_resolve_zone_offset_seconds(
        tz, y, m, d, h, mi, s, disambiguation
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    days: int = iso_days_from_ymd(y, m, d);
    local_s: int = days * 86400 + h * 3600 + mi * 60 + s;
    local_ns_bn: list[int] = bn_add(
        bn_mul_small(bn_from_int(local_s), 1000000000), bn_from_int(ns)
    );
    off_ns_bn: list[int] = bn_mul_small(bn_from_int(off_s), 1000000000);
    epoch_bn: list[int] = bn_sub(local_ns_bn, off_ns_bn);
    # The resulting instant must be a valid epoch-nanosecond value (a local wall-clock
    # near the ISO limits can map out of range).
    temporal_reject_epoch_ns_out_of_range(epoch_bn);
    if vm_has_native_exc() {
        return js_undefined();
    }
    epoch_s: str = bn_to_string(epoch_bn, 10);
    parts: list[int] = _zdt_instant_to_local_parts(epoch_s, tz);
    off2: int = temporal_resolve_zone_offset_seconds(
        tz, parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], disambiguation
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_zoned_datetime_create(
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        parts[4],
        parts[5],
        parts[6],
        tz,
        off2,
        cal
    );
}

def _temporal_zoned_from_local_with_offset_roundtrip(
    tz: str,
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    cal: str,
    off_s: int
) -> JSValue {
    # offset:"use" keeps the exact instant the wall-clock + supplied offset denote.
    # js_zoned_datetime_create derives epoch = local − off_s, so pass the ORIGINAL
    # wall-clock and off_s DIRECTLY. (Re-deriving local parts from the epoch in `tz` and
    # then passing off_s again double-counts the offset — a −07:00[!UTC] "use" instant
    # came out 7h off.)
    return js_zoned_datetime_create(y, m, d, h, mi, s, ns, tz, off_s, cal);
}

def:pub js_Temporal_ZonedDateTime_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("ZonedDateTime.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    tz: str = "UTC";
    if len(args) > 1 {
        if jsv_is_string_cell(args[1]) or js_is_zoned_datetime(args[1]) {
            tz = ToTemporalTimeZoneIdentifier(args[1]);
            if vm_has_native_exc() {
                return js_undefined();
            }
        } else {
            opts = args[1];
            tz = temporal_get_timezone_from_zdt_options(opts, "UTC");
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
    }
    # disambiguation (and the other options) are read PER BRANCH, after the argument
    # has been validated — for a string argument, an invalid string throws RangeError
    # before any option getter fires (from/observable-get-overflow-argument-string-invalid).
    tz_box: list[any] = [temporal_str_copy(tz)];
    a0: JSValue = args[0];
    if js_is_zoned_datetime(a0) {
        # A ZonedDateTime argument returns a copy, but the options are still read and
        # validated (§ToTemporalZonedDateTime): an invalid disambiguation/overflow string
        # throws RangeError even on this fast path.
        _ = temporal_get_disambiguation(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # The `offset` option is read + validated even on the ZDT fast path (a wrong-type
        # or out-of-set value throws before the copy is returned).
        _ = temporal_get_offset_option(opts, "reject");
        if vm_has_native_exc() {
            return js_undefined();
        }
        _ = temporal_get_overflow(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # ToTemporalZonedDateTime returns a fresh CreateTemporalZonedDateTime, NOT the same
        # object (from(zdt) !== zdt); rebuild from the epoch-ns + time zone + calendar.
        a0_tz: str = temporal_to_string(js_object_get(a0, KEY_TIMEZONE));
        a0_cal: str = temporal_get_calendar(a0);
        return temporal_zoned_epoch_ns_to_zdt(
            bn_to_string(js_zoned_read_ns(a0), 10), a0_tz, a0_cal
        );
    }
    # ToTemporalZonedDateTime accepts only a branded ZonedDateTime, a property-bag
    # object, or a String. Every other primitive — undefined, null, boolean,
    # number, bigint, symbol — is a TypeError (a String that fails to parse is a
    # RangeError, handled below). Note: bigint is NOT epoch-ns here; only the
    # ZonedDateTime constructor takes a bigint epoch value.
    if not jsv_is_object_cell(a0) and not jsv_is_string_cell(a0) {
        vm_throw_native(
            make_type_error(
                "ZonedDateTime.from: argument must be a string, object, or Temporal.ZonedDateTime"
            )
        );
        return js_undefined();
    }
    if jsv_is_object_cell(a0) {
        # Any non-Temporal object is a property bag (ToTemporalZonedDateTime): the bag
        # builder validates required fields and throws TypeError when they are missing
        # (from({}) is a TypeError, not a string-parse RangeError).
        disambig: str = temporal_get_disambiguation(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # The `offset` option is read + validated (ToTemporalOffsetOption, default
        # "reject"): a wrong-type value → TypeError, an out-of-set string → RangeError.
        _ = temporal_get_offset_option(opts, "reject");
        if vm_has_native_exc() {
            return js_undefined();
        }
        # The bag builder performs offset reconciliation (InterpretISODateTimeOffset)
        # per the `offset` option and returns a ZonedDateTime whose epoch-ns already
        # reflects the resolved instant — use it directly (re-deriving the offset from
        # the zone here would discard an offset:"use" instant that differs from the zone).
        bag: JSValue = _temporal_zoned_from_property_bag(a0, tz, disambig, opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        temporal_reject_epoch_ns_out_of_range(js_zoned_read_ns(bag));
        if vm_has_native_exc() {
            return js_undefined();
        }
        return bag;
    }
    s: str = js_coerce_to_string(a0);
    pr: list[any] = parse_iso_date_time(s);
    if not pr[PR_OK] or not pr[PR_HAS_DATE] or not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid ZonedDateTime string"));
        return js_undefined();
    }
    # A ZonedDateTime string REQUIRES a [TimeZone] annotation (ParseTemporalZonedDateTime
    # String) — a bare date-time ("2021-01-01T00:00") or an offset-only string
    # ("…+05:00", no bracket) is not a ZonedDateTime.
    # String parse-result fields are read via the accessors (str-in-list bug):
    # capture them into locals immediately, before any later parse overwrites them.
    ann_present: str = PR_S_TZ_ANNOTATION;
    cal: str = PR_S_CALENDAR;
    if len(ann_present) == 0 {
        vm_throw_native(
            make_range_error("ZonedDateTime string requires a time zone annotation")
        );
        return js_undefined();
    }
    y: int = pr[PR_YEAR];
    m: int = pr[PR_MONTH];
    d: int = pr[PR_DAY];
    h: int = pr[PR_HOUR];
    mi: int = pr[PR_MINUTE];
    sc: int = pr[PR_SECOND];
    ns: int = pr[PR_NANOSECOND];
    # Leap second ":60" is constrained to ":59" (no leap second in ISO).
    if sc == 60 {
        sc = 59;
    }
    # The parsed date/time values are range-validated BEFORE any option getter fires —
    # "2020-13-34T25:60:60…" throws RangeError before options.disambiguation is read
    # (from/observable-get-overflow-argument-string-invalid).
    temporal_reject_ymd(y, m, d);
    if vm_has_native_exc() {
        return js_undefined();
    }
    temporal_reject_time(h, mi, sc, ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Options are read only AFTER the string parses and its values validate.
    disambig: str = temporal_get_disambiguation(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # The `offset` option is read + validated (ToTemporalOffsetOption, default "reject").
    offset_opt: str = temporal_get_offset_option(opts, "reject");
    if vm_has_native_exc() {
        return js_undefined();
    }
    if ann_present != "" {
        tz = ann_present;
    }
    is_z: bool = pr[PR_IS_Z] != 0;
    # The wall-clock time, once its UTC offset (or Z) is applied, must yield an epoch
    # instant within the representable range — "+275760-09-14T00:00+23:59" and
    # "-271821-04-19T00:00:01-23:59" are out of range even though their date/time parse.
    # A ZonedDateTime's range is the INSTANT range (no separate local-day bound: unlike a
    # Duration relativeTo, "-271821-04-19T23:00-01:00" → min instant is VALID), so
    # range-check the resulting epoch nanoseconds directly.
    # Reconcile the parsed UTC offset with the time zone per the `offset` option
    # (InterpretISODateTimeOffset):
    #   use     — keep the exact instant the parsed offset denotes (offset wins).
    #   ignore  — drop the parsed offset, recompute the instant from the wall-clock+zone.
    #   reject  — the parsed offset MUST equal a valid zone offset for this wall-clock,
    #             else RangeError.
    #   prefer  — use the parsed offset if it is a valid zone offset, else recompute.
    # A "Z" designator behaves like offset 0 with "use" semantics (exact UTC instant).
    zdt: JSValue = js_undefined();
    if pr[PR_HAS_OFFSET] != 0 or is_z {
        off_s: int = 0;
        if pr[PR_HAS_OFFSET] != 0 {
            off_s = pr[PR_OFFSET_S];
        }
        use_exact: bool = is_z or offset_opt == "use";
        if not use_exact and offset_opt != "ignore" {
            # reject / prefer: does the parsed offset match a valid zone offset here?
            zone_off: int = temporal_resolve_zone_offset_seconds(
                tz, y, m, d, h, mi, sc, disambig
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
            if zone_off == off_s {
                use_exact = True;
            } elif offset_opt == "reject" {
                vm_throw_native(
                    make_range_error("offset does not match the time zone")
                );
                return js_undefined();
            }
        }
        if offset_opt == "ignore" {
            zdt = _temporal_zoned_from_local_roundtrip(
                tz, y, m, d, h, mi, sc, ns, cal, disambig
            );
        } elif use_exact {
            zdt = _temporal_zoned_from_local_with_offset_roundtrip(
                tz, y, m, d, h, mi, sc, ns, cal, off_s
            );
        } else {
            # prefer with a non-matching offset: recompute from the wall-clock + zone.
            zdt = _temporal_zoned_from_local_roundtrip(
                tz, y, m, d, h, mi, sc, ns, cal, disambig
            );
        }
    } else {
        zdt = _temporal_zoned_from_local_roundtrip(
            tz, y, m, d, h, mi, sc, ns, cal, disambig
        );
    }
    if vm_has_native_exc() {
        return js_undefined();
    }
    temporal_reject_epoch_ns_out_of_range(js_zoned_read_ns(zdt));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return zdt;
}

def:pub js_ZonedDateTime_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Read all six options in alphabetical order (calendarName, fractionalSecondDigits,
    # offset, roundingMode, smallestUnit, timeZoneName) — order-of-operations.
    to: list[any] = temporal_read_zdt_tostring(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    step_ns: int = to[1];
    mode: int = to[3];
    prec_digits: int = to[0];
    cal_name: str = to[4];
    show_offset: str = to[5];
    show_tz: str = to[6];

    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    rc: list[int] = _temporal_round_wallclock(
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        step_ns,
        mode
    );
    if rc[4] != 0 {
        nd: list[int] = iso_ymd_from_days(iso_days_from_ymd(y, m, d) + rc[4]);
        y = nd[0];
        m = nd[1];
        d = nd[2];
    }
    s: str = iso_format_date(y, m, d)
        + "T"
        + iso_format_time_precision(rc[0], rc[1], rc[2], rc[3], prec_digits);
    if show_offset != "never" {
        s = s + temporal_format_offset_ns(_get_int(o, KEY_OFFSET_NS));
    }
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    if show_tz != "never" and tz != "" {
        crit: str = "";
        if show_tz == "critical" {
            crit = "!";
        }
        s = s + "[" + crit + tz + "]";
    }
    s = s + temporal_format_calendar_suffix(temporal_get_calendar(o), cal_name);
    return jsv_from_string_id(str_intern(s));
}

def:pub js_ZonedDateTime_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("ZonedDateTime.with requires an object"));
        return js_undefined();
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    h: int = _get_int(o, KEY_ISO_HOUR);
    mi: int = _get_int(o, KEY_ISO_MINUTE);
    s: int = _get_int(o, KEY_ISO_SECOND);
    ns: int = _get_int(o, KEY_ISO_NANOSECOND);
    fields: JSValue = args[0];
    # `calendar`/`timeZone` are not calendar fields — a TypeError if present.
    if not jsv_is_undefined(js_object_get(fields, str_intern("calendar"))) {
        vm_throw_native(make_type_error("calendar property not allowed in with()"));
        return js_undefined();
    }
    if not jsv_is_undefined(js_object_get(fields, str_intern("timeZone"))) {
        vm_throw_native(make_type_error("timeZone property not allowed in with()"));
        return js_undefined();
    }
    seen: bool = False;
    yv: JSValue = js_object_get_observable(fields, str_intern("year"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(yv) {
        y = _to_int(yv);
        seen = True;
    }
    mcv: JSValue = js_object_get_observable(fields, str_intern("monthCode"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    mc_month: int = 0;
    if not jsv_is_undefined(mcv) {
        mc_n: int = parse_month_code(temporal_to_string(mcv));
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_month = mc_n;
        seen = True;
    }
    mv: JSValue = js_object_get_observable(fields, str_intern("month"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    has_m: bool = not jsv_is_undefined(mv);
    if has_m {
        m = _to_int(mv);
        seen = True;
        if m < 1 {
            vm_throw_native(make_range_error("month must be positive"));
            return js_undefined();
        }
    }
    if mc_month != 0 {
        if has_m and m != mc_month {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mc_month;
    }
    dv: JSValue = js_object_get_observable(fields, str_intern("day"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(dv) {
        d = _to_int(dv);
        seen = True;
    }
    hv: JSValue = js_object_get_observable(fields, str_intern("hour"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(hv) {
        h = _to_int(hv);
        seen = True;
    }
    miv: JSValue = js_object_get_observable(fields, str_intern("minute"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(miv) {
        mi = _to_int(miv);
        seen = True;
    }
    sv: JSValue = js_object_get_observable(fields, str_intern("second"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(sv) {
        s = _to_int(sv);
        seen = True;
    }
    msv: JSValue = js_object_get_observable(fields, str_intern("millisecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    usv: JSValue = js_object_get_observable(fields, str_intern("microsecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    nsv: JSValue = js_object_get_observable(fields, str_intern("nanosecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(msv)
        or not jsv_is_undefined(usv)
        or not jsv_is_undefined(nsv) {
        cur_ms: int = ns // 1000000;
        cur_us: int = (ns // 1000) % 1000;
        cur_ns: int = ns % 1000;
        if not jsv_is_undefined(msv) {
            cur_ms = _to_int(msv);
        }
        if not jsv_is_undefined(usv) {
            cur_us = _to_int(usv);
        }
        if not jsv_is_undefined(nsv) {
            cur_ns = _to_int(nsv);
        }
        ns = cur_ms * 1000000 + cur_us * 1000 + cur_ns;
        seen = True;
    }
    # `offset` field is read too (an offset can be part of a ZDT fields bag).
    ofv: JSValue = js_object_get_observable(fields, str_intern("offset"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(ofv) {
        seen = True;
    }
    if not seen {
        vm_throw_native(
            make_type_error("with() requires at least one recognized field")
        );
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    ov: str = temporal_get_overflow(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    disambig: str = temporal_get_disambiguation(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # The `offset` option is read + validated (ToTemporalOffsetOption, default "prefer"
    # for with): a wrong-type value → TypeError, an out-of-set string → RangeError.
    _ = temporal_get_offset_option(opts, "prefer");
    if vm_has_native_exc() {
        return js_undefined();
    }
    nyy: int = y;
    nmm: int = m;
    ndd: int = d;
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, d);
        nyy = bal[0];
        nmm = bal[1];
        ndd = bal[2];
    }
    temporal_reject_time(h, mi, s, ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    return _temporal_zoned_from_local_roundtrip(
        tz, nyy, nmm, ndd, h, mi, s, ns, temporal_get_calendar(o), disambig
    );
}

def:pub js_ZonedDateTime_withCalendar(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("ZonedDateTime.withCalendar requires 1 argument")
        );
        return js_undefined();
    }
    cal: str = temporal_parse_calendar(args[0]);
    return js_zoned_datetime_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        temporal_to_string(js_object_get(o, KEY_TIMEZONE)),
        _get_int(o, KEY_OFFSET_NS),
        cal
    );
}

def:pub js_ZonedDateTime_withTimeZone(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("ZonedDateTime.withTimeZone requires 1 argument")
        );
        return js_undefined();
    }
    tz: str = ToTemporalTimeZoneIdentifier(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    ns_s: str = bn_to_string(js_zoned_read_ns(o), 10);
    return _zdt_from_ns_string(ns_s, tz, temporal_get_calendar(o));
}

def:pub js_ZonedDateTime_withPlainTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    h: int = 0;
    mi: int = 0;
    s: int = 0;
    ns: int = 0;
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        pt: JSValue = ToTemporalTime(args[0], js_undefined());
        if vm_has_native_exc() {
            return js_undefined();
        }
        h = _get_int(pt, KEY_ISO_HOUR);
        mi = _get_int(pt, KEY_ISO_MINUTE);
        s = _get_int(pt, KEY_ISO_SECOND);
        ns = _get_int(pt, KEY_ISO_NANOSECOND);
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    disambig: str = temporal_get_disambiguation(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return _temporal_zoned_from_local_roundtrip(
        tz, y, m, d, h, mi, s, ns, temporal_get_calendar(o), disambig
    );
}

def:pub js_ZonedDateTime_round(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 or jsv_is_undefined(args[0]) {
        vm_throw_native(
            make_type_error("ZonedDateTime.round requires an options argument")
        );
        return js_undefined();
    }
    # roundTo may be a string shorthand ("day") or an options bag; smallestUnit is REQUIRED.
    unit: str = "";
    increment: int = 1;
    mode: int = ROUND_HALF_EXPAND;
    a0: JSValue = args[0];
    if jsv_is_string_cell(a0) {
        unit = _temporal_round_unit_normalize(temporal_to_string(a0));
    } elif jsv_is_object_cell(a0) {
        # Options read OBSERVABLY in ALPHABETICAL order (roundingIncrement, roundingMode,
        # smallestUnit); smallestUnit is required (§ZonedDateTime.round).
        increment = temporal_get_rounding_increment(a0);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mode = temporal_get_round_rounding_mode(a0);
        if vm_has_native_exc() {
            return js_undefined();
        }
        su: JSValue = js_object_get_observable(a0, str_intern("smallestUnit"), a0);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if jsv_is_undefined(su) {
            vm_throw_native(make_range_error("smallestUnit is required"));
            return js_undefined();
        }
        unit = _temporal_round_unit_normalize(js_to_string_observable(su));
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        vm_throw_native(make_type_error("invalid roundTo"));
        return js_undefined();
    }
    if unit == ""
        or unit == "auto"
        or unit == "week"
        or unit == "month"
        or unit == "year" {
        vm_throw_native(
            make_range_error("invalid smallestUnit for ZonedDateTime.round")
        );
        return js_undefined();
    }
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    cal: str = temporal_get_calendar(o);
    ns: list[int] = js_zoned_read_ns(o);
    if unit == "day" {
        # DST-aware day rounding: round the offset WITHIN the local day, where the day
        # length is (next local midnight epoch − this local midnight epoch) — 23/24/25h
        # around transitions — not a fixed 86400e9.
        lp: list[int] = _zdt_local_parts(ns, tz);
        start_ns: list[int] = _zdt_add_date_time_epoch(
            ns, tz, cal, 0, 0, 0, 0, -lp[3], -lp[4], -lp[5], -lp[6]
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
        next_ns: list[int] = _zdt_add_date_time_epoch(
            start_ns, tz, cal, 0, 0, 0, 1, 0, 0, 0, 0
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
        day_len: int = int(bn_to_string(bn_sub(next_ns, start_ns), 10));
        into: int = int(bn_to_string(bn_sub(ns, start_ns), 10));
        rounded_into: int = _temporal_round_int_to_increment_signed(
            into, day_len, mode
        );
        rounded_ns: list[int] = bn_add(start_ns, bn_from_int(rounded_into));
        return _zdt_from_ns_string(bn_to_string(rounded_ns, 10), tz, cal);
    }
    dur_validate_rounding_increment(
        increment, temporal_instant_round_max_increment(unit), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    rounded_ns2: list[int] = temporal_round_epoch_ns(ns, unit, increment, mode);
    return _zdt_from_ns_string(bn_to_string(rounded_ns2, 10), tz, cal);
}

def:priv _temporal_round_unit_normalize(s: str) -> str {
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

# Round `v` to a multiple of `step` (step>0) with sign-aware half-* modes. Unlike the
# unsigned helper, `v` may be negative (offset into a day can't be, but keep it general).
def:priv _temporal_round_int_to_increment_signed(v: int, step: int, mode: int) -> int {
    if step <= 0 {
        return v;
    }
    q: int = v // step;
    r: int = v - q * step;
    if r == 0 {
        return v;
    }
    lo: int = q * step;
    hi: int = lo + step;
    if mode == ROUND_TRUNC {
        if v >= 0 {
            return lo;
        }
        return hi;
    }
    if mode == ROUND_FLOOR {
        return lo;
    }
    if mode == ROUND_CEIL {
        return hi;
    }
    if mode == ROUND_EXPAND {
        if v >= 0 {
            return hi;
        }
        return lo;
    }
    twice: int = r * 2;
    if twice < step {
        return lo;
    }
    if twice > step {
        return hi;
    }
    if mode == ROUND_HALF_TRUNC {
        if v >= 0 {
            return lo;
        }
        return hi;
    }
    if mode == ROUND_HALF_FLOOR {
        return lo;
    }
    if mode == ROUND_HALF_CEIL {
        return hi;
    }
    if mode == ROUND_HALF_EVEN {
        if (q % 2) == 0 {
            return lo;
        }
        return hi;
    }
    return hi;
}

def:pub js_ZonedDateTime_startOfDay(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
    }
    disambig: str = temporal_get_disambiguation(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return _temporal_zoned_from_local_roundtrip(
        tz, y, m, d, 0, 0, 0, 0, temporal_get_calendar(o), disambig
    );
}

def:pub js_ZonedDateTime_getTimeZoneTransition(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    direction: str = "next";
    if len(args) > 0 {
        a0: JSValue = args[0];
        if jsv_is_string_cell(a0) {
            direction = temporal_to_string(a0);
        } elif jsv_is_object_cell(a0) or jsv_is_undefined(a0) {
            if not jsv_is_undefined(a0) {
                dv: JSValue = js_object_get(a0, str_intern("direction"));
                if not jsv_is_undefined(dv) {
                    direction = temporal_to_string(dv);
                }
            }
        } else {
            vm_throw_native(make_type_error("invalid direction"));
            return js_undefined();
        }
    }
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    if not _zdt_tz_has_transitions(tz) {
        return js_null();
    }
    ns: list[int] = js_zoned_read_ns(o);
    q: list[int] = bn_divmod(ns, bn_from_int(1000000000));
    epoch_s: int = int(bn_to_string(q, 10));
    handle: int = tz_load_zone(tz);
    if handle == 0 {
        return js_null();
    }
    forward: bool = direction != "previous";
    trans_s: int = tz_get_next_transition(handle, epoch_s, forward);
    tz_unload(handle);
    if trans_s < 0 {
        return js_null();
    }
    trans_ns: list[int] = bn_mul_small(bn_from_int(trans_s), 1000000000);
    return _zdt_from_ns_string(
        bn_to_string(trans_ns, 10), tz, temporal_get_calendar(o)
    );
}

def:priv _zdt_duration_has_calendar_units(dur: list[float]) -> bool {
    return dur[DUR_YEARS] != 0.0
        or dur[DUR_MONTHS] != 0.0
        or dur[DUR_WEEKS] != 0.0
        or dur[DUR_DAYS] != 0.0;
}

def:priv _zdt_add_time_only_epoch(
    o: JSValue, dur: list[float], tz: str, cal: str
) -> JSValue {
    epoch_ns: list[int] = js_zoned_read_ns(o);
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    days: int = int(dur[DUR_DAYS]) + int(dur[DUR_WEEKS]) * 7;
    sub_ns: int = iso_total_nanoseconds(
        int(dur[DUR_HOURS]),
        int(dur[DUR_MINUTES]),
        int(dur[DUR_SECONDS]),
        int(dur[DUR_NANOSECONDS])
    );
    delta_ns: int = days * 86400000000000 + sub_ns;
    if sign < 0 {
        delta_ns = -delta_ns;
    }
    new_ns: list[int] = bn_add(epoch_ns, bn_from_int(delta_ns));
    # Fresh object (js_undefined), not the receiver `o` — otherwise time-only add mutates it.
    return temporal_zoned_from_epoch_ns_string_on(
        js_undefined(), bn_to_string(new_ns, 10), tz, cal
    );
}

def:pub js_ZonedDateTime_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("ZonedDateTime.add requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # Duration converted BEFORE options.overflow is read (§add order-of-operations).
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    _ = temporal_get_overflow(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    h: int = _get_int(o, KEY_ISO_HOUR);
    mi: int = _get_int(o, KEY_ISO_MINUTE);
    s: int = _get_int(o, KEY_ISO_SECOND);
    ns: int = _get_int(o, KEY_ISO_NANOSECOND);
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    cal: str = temporal_get_calendar(o);
    if not _zdt_duration_has_calendar_units(dur) {
        return _zdt_add_time_only_epoch(o, dur, tz, cal);
    }
    # Calendar-aware date units + ISO time units.
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    ov: str = "constrain";
    date_bal: list[int] = calendar_date_add(
        y,
        m,
        d,
        cal,
        int(dur[DUR_YEARS]) * sign,
        int(dur[DUR_MONTHS]) * sign,
        int(dur[DUR_WEEKS]) * sign,
        int(dur[DUR_DAYS]) * sign,
        ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = date_bal[0];
    m = date_bal[1];
    d = date_bal[2];
    at: list[int] = iso_add_time(
        h,
        mi,
        s,
        ns,
        int(dur[DUR_HOURS]) * sign,
        int(dur[DUR_MINUTES]) * sign,
        int(dur[DUR_SECONDS]) * sign,
        int(dur[DUR_NANOSECONDS]) * sign
    );
    if at[0] != 0 {
        bal3: list[int] = iso_add_days(y, m, d, at[0]);
        y = bal3[0];
        m = bal3[1];
        d = bal3[2];
    }
    end: list[int] = [y, m, d, at[1], at[2], at[3], at[4]];
    off_s: int = temporal_resolve_zone_offset_seconds(
        tz, end[0], end[1], end[2], end[3], end[4], end[5], "compatible"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    # A fresh ZonedDateTime — NOT `o`. `_zdt_finish(o, …)` re-inits the receiver in place
    # (that path is only for the constructor's `this`); passing the receiver here made
    # `.add()`/`.subtract()` MUTATE the object they were called on.
    return _zdt_finish(
        js_undefined(),
        end[0],
        end[1],
        end[2],
        end[3],
        end[4],
        end[5],
        end[6],
        tz,
        off_s,
        cal
    );
}

def:pub js_ZonedDateTime_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur[DUR_SIGN] = -dur[DUR_SIGN];
    sub_args: list[JSValue] = [js_duration_create(dur)];
    if len(args) > 1 {
        sub_args.append(args[1]);
    }
    return js_ZonedDateTime_add(this_val, sub_args);
}

def:priv _zdt_to_temporal(v: JSValue) -> JSValue {
    if js_is_zoned_datetime(v) {
        return v;
    }
    return js_Temporal_ZonedDateTime_from([v]);
}

def:pub js_Temporal_ZonedDateTime_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("ZonedDateTime.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = _zdt_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = _zdt_to_temporal(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_int(bn_cmp(js_zoned_read_ns(a), js_zoned_read_ns(b)));
}

def:priv _zdt_dur_from_ns_diff(diff: list[int]) -> list[float] {
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

# True when the difference largestUnit needs a calendar (day-or-larger) breakdown, so
# the diff must be computed on the zone's local wall-clocks (DifferenceZonedDateTime)
# rather than as a flat epoch-nanosecond span.
def:priv _zdt_largest_is_calendar(u: str) -> bool {
    return u == "day" or u == "week" or u == "month" or u == "year";
}

# Local wall-clock nanoseconds within the day plus the ISO date, for a zoned instant.
def:priv _zdt_local_parts(ns: list[int], tz: str) -> list[int] {
    return _zdt_instant_to_local_parts(bn_to_string(ns, 10), tz);
}

# DifferenceZonedDateTime for a calendar largestUnit: y/m/w/d comes from the local
# wall-clock date difference, but the DAY boundary is validated against the true elapsed
# instant so DST-length days are handled. Returns an UNROUNDED duration (y,m,w,d + time).
def:priv _zdt_calendar_difference(
    start_ns: list[int], end_ns: list[int], tz: str, cal: str, largest: str
) -> list[float] {
    sp: list[int] = _zdt_local_parts(start_ns, tz);
    ep: list[int] = _zdt_local_parts(end_ns, tz);
    sy: int = sp[0];
    sm: int = sp[1];
    sd: int = sp[2];
    sh: int = sp[3];
    smi: int = sp[4];
    ss: int = sp[5];
    sns: int = sp[6];
    ey: int = ep[0];
    em: int = ep[1];
    ed: int = ep[2];
    eh: int = ep[3];
    emi: int = ep[4];
    es: int = ep[5];
    ens: int = ep[6];
    # Overall direction from the true instant order.
    total_sign: int = bn_cmp(end_ns, start_ns);
    if total_sign == 0 {
        return dur_from_components(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    }
    # Local time-of-day difference; borrow one local day when it opposes the direction.
    t_start: int = iso_total_nanoseconds(sh, smi, ss, sns);
    t_end: int = iso_total_nanoseconds(eh, emi, es, ens);
    time_ns: int = t_end - t_start;
    adj_ey: int = ey;
    adj_em: int = em;
    adj_ed: int = ed;
    if time_ns != 0 and ((time_ns < 0) != (total_sign < 0)) {
        shifted: list[int] = iso_balance_date(adj_ey, adj_em, adj_ed - total_sign);
        adj_ey = shifted[0];
        adj_em = shifted[1];
        adj_ed = shifted[2];
    }
    # Calendar date difference on the (possibly borrowed) end date.
    date_parts: list[int] = calendar_date_until(
        sy, sm, sd, adj_ey, adj_em, adj_ed, cal, largest
    );
    # DST-correct the day count: add the calendar date part back through the zone and
    # measure the remaining ns to `end`. Adjust days until the intermediate does not pass
    # the target in the travel direction.
    yy: int = date_parts[0];
    mm: int = date_parts[1];
    ww: int = date_parts[2];
    dd: int = date_parts[3];
    inter_ns: list[int] = _zdt_add_date_time_epoch(
        start_ns, tz, cal, yy, mm, ww, dd, 0, 0, 0, 0
    );
    if vm_has_native_exc() {
        return dur_from_components(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    }
    # If adding the date part overshoots `end` in the travel direction, step days back once.
    guard: int = 0;
    while guard < 3 and total_sign * bn_cmp(inter_ns, end_ns) > 0 {
        dd = dd - total_sign;
        inter_ns = _zdt_add_date_time_epoch(
            start_ns, tz, cal, yy, mm, ww, dd, 0, 0, 0, 0
        );
        if vm_has_native_exc() {
            return dur_from_components(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        }
        guard = guard + 1;
    }
    # Remaining time from the intermediate instant to `end` (fits well within a day → int).
    rem_bn: list[int] = bn_sub(end_ns, inter_ns);
    rem_ns: int = int(bn_to_string(rem_bn, 10));
    tsgn: float = 1.0;
    abs_rem: int = rem_ns;
    if rem_ns < 0 {
        tsgn = -1.0;
        abs_rem = -rem_ns;
    }
    th: int = abs_rem // 3600000000000;
    tr: int = abs_rem % 3600000000000;
    tmi: int = tr // 60000000000;
    tr2: int = tr % 60000000000;
    tsc: int = tr2 // 1000000000;
    tnsp: int = tr2 % 1000000000;
    return dur_from_components(
        float(yy),
        float(mm),
        float(ww),
        float(dd),
        float(th) * tsgn,
        float(tmi) * tsgn,
        float(tsc) * tsgn,
        float(tnsp) * tsgn
    );
}

# Add a date (y/m/w/d) + time to a zoned instant, returning the resulting epoch ns.
def:priv _zdt_add_date_time_epoch(
    start_ns: list[int],
    tz: str,
    cal: str,
    yy: int,
    mm: int,
    ww: int,
    dd: int,
    hh: int,
    mmi: int,
    sss: int,
    nnn: int
) -> list[int] {
    sp: list[int] = _zdt_local_parts(start_ns, tz);
    date_bal: list[int] = calendar_date_add(
        sp[0], sp[1], sp[2], cal, yy, mm, ww, dd, "constrain"
    );
    if vm_has_native_exc() {
        return start_ns;
    }
    ny: int = date_bal[0];
    nm: int = date_bal[1];
    nd: int = date_bal[2];
    at: list[int] = iso_add_time(sp[3], sp[4], sp[5], sp[6], hh, mmi, sss, nnn);
    if at[0] != 0 {
        bal3: list[int] = iso_add_days(ny, nm, nd, at[0]);
        ny = bal3[0];
        nm = bal3[1];
        nd = bal3[2];
    }
    # AddZonedDateTime step: the intermediate ISO date-time must be within limits
    # (adding a duration at the epoch boundary can land outside the representable range).
    if not iso_validate_datetime_within_limits(
        ny, nm, nd, at[1], at[2], at[3], at[4]
    ) {
        vm_throw_native(make_range_error("date-time out of range"));
        return start_ns;
    }
    off_s: int = temporal_resolve_zone_offset_seconds(
        tz, ny, nm, nd, at[1], at[2], at[3], "compatible"
    );
    if vm_has_native_exc() {
        return start_ns;
    }
    days_i: int = iso_days_from_ymd(ny, nm, nd);
    local_s: int = days_i * 86400 + at[1] * 3600 + at[2] * 60 + at[3];
    local_ns_bn: list[int] = bn_add(
        bn_mul_small(bn_from_int(local_s), 1000000000), bn_from_int(at[4])
    );
    return bn_sub(local_ns_bn, bn_mul_small(bn_from_int(off_s), 1000000000));
}

def:pub js_ZonedDateTime_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("ZonedDateTime.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` converts BEFORE options are read/validated (§until).
    other: JSValue = _zdt_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return _zdt_diff_impl(o, other, opts, False);
}

def:pub js_ZonedDateTime_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("ZonedDateTime.since requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` converts BEFORE options are read/validated (§since).
    other: JSValue = _zdt_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # since rounds the NEGATED difference: flip the roundingMode (NegateRoundingMode) in
    # the diff core, then negate the resulting duration.
    dur_v: JSValue = _zdt_diff_impl(o, other, opts, True);
    if vm_has_native_exc() {
        return js_undefined();
    }
    neg: list[float] = dur_negate(ToTemporalDurationValue(dur_v));
    return js_duration_create(neg);
}

# Shared until/since core. `flip_mode` negates roundingMode (NegateRoundingMode) for
# `since`, which rounds the negated difference; the caller then negates the duration.
def:priv _zdt_diff_impl(
    o: JSValue, other: JSValue, opts: JSValue, flip_mode: bool
) -> JSValue {
    oy: int = _get_int(o, KEY_ISO_YEAR);
    om: int = _get_int(o, KEY_ISO_MONTH);
    od: int = _get_int(o, KEY_ISO_DAY);
    oh: int = _get_int(o, KEY_ISO_HOUR);
    omi: int = _get_int(o, KEY_ISO_MINUTE);
    os: int = _get_int(o, KEY_ISO_SECOND);
    ons: int = _get_int(o, KEY_ISO_NANOSECOND);
    tz: str = temporal_to_string(js_object_get(o, KEY_TIMEZONE));
    cal: str = temporal_get_calendar(o);
    # GetDifferenceSettings: read largestUnit, roundingIncrement, roundingMode,
    # smallestUnit in ALPHABETICAL order (all units allowed for ZonedDateTime).
    units: list[str] = temporal_read_difference_settings(
        opts, "hour", "nanosecond", "datetime"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if flip_mode {
        units[3] = negate_rounding_mode_string(units[3]);
    }
    inc: int = int(units[2]);
    mode: int = rounding_mode_from_string(units[3]);
    start_ns: list[int] = js_zoned_read_ns(o);
    end_ns: list[int] = js_zoned_read_ns(other);
    if _zdt_largest_is_calendar(units[0]) {
        raw: list[float] = _zdt_calendar_difference(
            start_ns, end_ns, tz, cal, units[0]
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
        dur: list[float] = temporal_apply_difference_rounding_resolved(
            raw, opts, units[0], units[1], True, oy, om, od, oh, omi, os, ons, inc, mode
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
        return js_duration_create(dur);
    }
    # Time-only largestUnit (hour and below): the diff is a flat epoch-ns span. Round and
    # decompose in BIGNUM (never float64, which loses precision past 2^53 ns — the
    # float64-representable-integer / roundingmode tests). Same builder shape as Instant.
    dur_validate_rounding_increment(
        inc, temporal_instant_round_max_increment(units[1]), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(
        _zdt_time_diff_duration(bn_sub(end_ns, start_ns), units[0], units[1], inc, mode)
    );
}

# Balanced time Duration from a SIGNED epoch-ns bignum span, rounded to smallest/inc/mode
# and capped at `largest` — all in bignum/int (no float64 loss). ZDT time largestUnit is
# at most "hour" (day and above take the calendar path); never balances up past largest.
def:priv _zdt_time_diff_duration(
    diff: list[int], largest: str, smallest: str, increment: int, mode: int
) -> list[float] {
    rounded: list[int] = temporal_round_epoch_ns(diff, smallest, increment, mode);
    neg: int = 0;
    abs_ns: list[int] = rounded;
    if bn_sign(rounded) < 0 {
        neg = 1;
        abs_ns = bn_neg(rounded);
    }
    lvl: int = 2;
    if largest == "hour" {
        lvl = 4;
    } elif largest == "minute" {
        lvl = 3;
    }
    hh: int = 0;
    mm: int = 0;
    ss: int = 0;
    rem: list[int] = abs_ns;
    if lvl >= 4 {
        qh: list[int] = bn_divmod(rem, bn_from_int(3600000000000));
        hh = int(bn_to_string(qh, 10));
        rem = _BN_DIV_REM;
    }
    if lvl >= 3 {
        qm: list[int] = bn_divmod(rem, bn_from_int(60000000000));
        mm = int(bn_to_string(qm, 10));
        rem = _BN_DIV_REM;
    }
    if lvl >= 2 {
        qs: list[int] = bn_divmod(rem, bn_from_int(1000000000));
        ss = int(bn_to_string(qs, 10));
        rem = _BN_DIV_REM;
    }
    nn: int = int(bn_to_string(rem, 10));
    sgn: float = 1.0;
    if neg != 0 {
        sgn = -1.0;
    }
    return dur_from_components(
        0.0,
        0.0,
        0.0,
        0.0,
        float(hh) * sgn,
        float(mm) * sgn,
        float(ss) * sgn,
        float(nn) * sgn
    );
}

def:pub js_ZonedDateTime_toInstant(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    return js_instant_create(js_zoned_read_ns(o));
}

def:pub js_ZonedDateTime_toPlainDate(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    return js_plain_date_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        temporal_get_calendar(o)
    );
}

def:pub js_ZonedDateTime_toPlainTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    return js_plain_time_create(
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        temporal_get_calendar(o)
    );
}

def:pub js_ZonedDateTime_toPlainDateTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    return js_plain_datetime_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        temporal_get_calendar(o)
    );
}

def:pub js_ZonedDateTime_toLocaleString(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    return js_ZonedDateTime_toString(this_val, args);
}

def:pub js_ZonedDateTime_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("ZonedDateTime.equals requires 1 argument"));
        return js_undefined();
    }
    # The argument is coerced via ToTemporalZonedDateTime (accepts a ZonedDateTime, a
    # property bag, or an ISO string) BEFORE comparison — not a bare identity check.
    other: JSValue = _zdt_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    eq: bool = bn_cmp(js_zoned_read_ns(o), js_zoned_read_ns(other)) == 0;
    eq = eq and temporal_get_calendar(o) == temporal_get_calendar(other);
    eq = eq
        and temporal_to_string(js_object_get(o, KEY_TIMEZONE))
            == temporal_to_string(js_object_get(other, KEY_TIMEZONE));
    return js_boolean(eq);
}

def:pub js_ZonedDateTime_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options and must not read off its argument (toJSON/basic passes
    # a throwing Proxy) — call toString with fixed defaults, ignoring args.
    empty_args: list[JSValue] = [];
    return js_ZonedDateTime_toString(this_val, empty_args);
}

def:pub js_ZonedDateTime_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_ZonedDateTime_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_zoned_datetime(this_val);
    return temporal_zoned_datetime_getter(o, temporal_callee_name());
}
