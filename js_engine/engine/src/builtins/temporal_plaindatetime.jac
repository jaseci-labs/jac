"""Temporal.PlainDateTime built-in."""

import from engine.src.runtime.temporal_parse { parse_month_code }
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_to_number_observable,
    js_to_string_observable
}
import from engine.src.runtime.temporal_iso {
    iso_format_date,
    iso_format_time,
    iso_compare,
    iso_add_days,
    iso_add_months,
    iso_add_time,
    iso_total_nanoseconds,
    iso_days_from_ymd,
    iso_balance_date,
    iso_validate_relativeto_ymd,
    iso_validate_relativeto_instant,
    iso_validate_datetime_within_limits
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_boolean,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_double,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_null
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.builtins.temporal {
    js_plain_datetime_create,
    js_this_plain_datetime,
    js_is_plain_datetime,
    js_is_duration,
    js_is_any_temporal_object,
    js_duration_create,
    js_duration_read,
    js_plain_date_create,
    js_plain_time_create,
    js_zoned_datetime_create,
    temporal_to_string,
    temporal_parse_calendar,
    temporal_reject_ymd,
    temporal_reject_time,
    temporal_plain_datetime_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    temporal_get_overflow,
    temporal_constrain_ymd,
    temporal_format_calendar_suffix,
    temporal_get_calendar,
    temporal_get_calendar_name,
    temporal_get_rounding_mode,
    temporal_get_round_rounding_mode,
    temporal_get_smallest_unit,
    temporal_get_smallest_unit_required,
    temporal_get_rounding_increment,
    temporal_instant_round_max_increment,
    temporal_require_options_object,
    temporal_round_options_from_arg,
    temporal_get_largest_unit,
    temporal_apply_difference_rounding,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    temporal_format_time_to_string,
    temporal_format_datetime_to_string,
    temporal_round_time_ns,
    ToTemporalPlainDateTime,
    ToTemporalTimeZoneIdentifier,
    temporal_offset_ns_for_zone,
    temporal_local_epoch_ns,
    temporal_reject_epoch_ns_out_of_range,
    ToTemporalTime,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_ISO_HOUR,
    KEY_ISO_MINUTE,
    KEY_ISO_SECOND,
    KEY_ISO_NANOSECOND,
    KEY_CALENDAR
}
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_balance,
    dur_round,
    dur_total,
    dur_negate,
    DUR_YEARS,
    DUR_MONTHS,
    DUR_WEEKS,
    DUR_DAYS,
    DUR_HOURS,
    DUR_MINUTES,
    DUR_SECONDS,
    DUR_NANOSECONDS,
    DUR_SIGN,
    dur_until_days,
    ROUND_TRUNC,
    dur_validate_rounding_increment,
    ROUND_FLOOR,
    ROUND_CEIL,
    ROUND_EXPAND,
    ROUND_HALF_TRUNC,
    ROUND_HALF_FLOOR,
    ROUND_HALF_EVEN,
    rounding_mode_from_string,
    negate_rounding_mode_string
}
import from engine.src.builtins.calendars.calendar_arithmetic {
    calendar_date_add,
    calendar_date_until
}
import from engine.src.builtins.calendars.calendar_dispatch {
    calendar_iso_to_fields,
    calendar_fields_to_iso
}
import from engine.src.builtins.calendars.calendar_gregory {
    CF_YEAR,
    CF_MONTH,
    CF_DAY,
    CF_ERA,
    CF_ERA_YEAR,
    CF_IS_LEAP_MONTH
}
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.builtins.temporal_plaintime { js_Temporal_PlainTime_compare }

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

# ToIntegerWithTruncation for a property-bag field: coerce to Number observably (fires
# valueOf), truncate toward zero, reject non-finite. See js_engine-temporal-with-template.
def:priv _pdt_field_int(v: JSValue) -> int {
    n: float = js_to_number_observable(v);
    if vm_has_native_exc() {
        return 0;
    }
    if n != n or n == n + 1.0 {
        vm_throw_native(make_range_error("invalid field"));
        return 0;
    }
    return int(n);
}

def:pub js_Temporal_PlainDateTime(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        vm_throw_native(
            make_type_error("PlainDateTime constructor requires at least 3 arguments")
        );
        return js_undefined();
    }
    # Spec signature: PlainDateTime(year, month, day, hour, minute, second,
    # millisecond, microsecond, nanosecond, calendar). Each positional argument
    # maps to one field; only the final arg (index 9) is the calendar. Reading a
    # sub-second field as the calendar is the classic off-by-position bug.
    # ES §sec-temporal.plaindatetime.
    # Args are ToIntegerWithTruncation: coerce observably and reject non-finite
    # (Infinity/NaN → RangeError), stopping at the first bad arg.
    y: int = _pdt_field_int(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    m: int = _pdt_field_int(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    d: int = _pdt_field_int(args[2]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    h: int = 0;
    mi: int = 0;
    s: int = 0;
    ms: int = 0;
    us: int = 0;
    nsp: int = 0;
    cal: str = "iso8601";
    # Optional sub-day args: an explicit `undefined` keeps the default 0 (a present
    # value is coerced/validated).
    if len(args) > 3 and not jsv_is_undefined(args[3]) {
        h = _pdt_field_int(args[3]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 4 and not jsv_is_undefined(args[4]) {
        mi = _pdt_field_int(args[4]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 5 and not jsv_is_undefined(args[5]) {
        s = _pdt_field_int(args[5]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 6 and not jsv_is_undefined(args[6]) {
        ms = _pdt_field_int(args[6]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 7 and not jsv_is_undefined(args[7]) {
        us = _pdt_field_int(args[7]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 8 and not jsv_is_undefined(args[8]) {
        nsp = _pdt_field_int(args[8]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 9 {
        cal = temporal_parse_calendar(args[9]);
    }
    if ms < 0 or ms > 999 or us < 0 or us > 999 or nsp < 0 or nsp > 999 {
        vm_throw_native(make_range_error("invalid time"));
        return js_undefined();
    }
    ns: int = ms * 1000000 + us * 1000 + nsp;
    temporal_reject_ymd(y, m, d);
    if vm_has_native_exc() {
        return js_undefined();
    }
    temporal_reject_time(h, mi, s, ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # The combined date+time must be within the representable ISO datetime range —
    # CreateTemporalDateTime rejects an out-of-range value even from the constructor.
    if not iso_validate_datetime_within_limits(y, m, d, h, mi, s, ns) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(y, m, d, h, mi, s, ns, cal);
}

def:pub js_Temporal_PlainDateTime_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDateTime.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    return ToTemporalPlainDateTime(args[0], opts);
}

def:pub js_Temporal_PlainDateTime_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("PlainDateTime.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = ToTemporalPlainDateTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = ToTemporalPlainDateTime(args[1], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    dc: int = iso_compare(
        _get_int(a, KEY_ISO_YEAR),
        _get_int(a, KEY_ISO_MONTH),
        _get_int(a, KEY_ISO_DAY),
        _get_int(b, KEY_ISO_YEAR),
        _get_int(b, KEY_ISO_MONTH),
        _get_int(b, KEY_ISO_DAY)
    );
    if dc != 0 {
        return js_int(dc);
    }
    return js_Temporal_PlainTime_compare(
        [
            js_plain_datetime_create(
                1970,
                1,
                1,
                _get_int(a, KEY_ISO_HOUR),
                _get_int(a, KEY_ISO_MINUTE),
                _get_int(a, KEY_ISO_SECOND),
                _get_int(a, KEY_ISO_NANOSECOND),
                "iso8601"
            ),
            js_plain_datetime_create(
                1970,
                1,
                1,
                _get_int(b, KEY_ISO_HOUR),
                _get_int(b, KEY_ISO_MINUTE),
                _get_int(b, KEY_ISO_SECOND),
                _get_int(b, KEY_ISO_NANOSECOND),
                "iso8601"
            )
        ]
    );
}

def:pub js_PlainDateTime_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDateTime.add requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # The duration argument is converted (its fields read) BEFORE the options are
    # examined (§add order-of-operations).
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # GetOptionsObject: undefined → default; otherwise ANY object is accepted, including
    # a callable (a function is an object — subtract/options-undefined `() => {}`). null
    # and primitives are a TypeError.
    if not jsv_is_undefined(opts) and not jsv_is_any_object(opts) {
        vm_throw_native(make_type_error("invalid options"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(opts);
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
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    cal: str = temporal_get_calendar(o);
    bal: list[int] = calendar_date_add(
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
    y = bal[0];
    m = bal[1];
    d = bal[2];
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
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
        if vm_has_native_exc() {
            return js_undefined();
        }
        temporal_reject_time(at[1], at[2], at[3], at[4]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # The resulting date+time must stay within the representable ISO datetime range.
    if not iso_validate_datetime_within_limits(y, m, d, at[1], at[2], at[3], at[4]) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(y, m, d, at[1], at[2], at[3], at[4], cal);
}

def:pub js_PlainDateTime_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur[DUR_SIGN] = -dur[DUR_SIGN];
    sub_args: list[JSValue] = [js_duration_create(dur)];
    if len(args) > 1 {
        sub_args.append(args[1]);
    }
    return js_PlainDateTime_add(this_val, sub_args);
}

def:pub js_PlainDateTime_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("PlainDateTime.with requires an object"));
        return js_undefined();
    }
    cal: str = temporal_get_calendar(o);
    cfields: list[int] = calendar_iso_to_fields(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        cal
    );
    y: int = int(cfields[CF_YEAR]);
    m: int = int(cfields[CF_MONTH]);
    d: int = int(cfields[CF_DAY]);
    h: int = _get_int(o, KEY_ISO_HOUR);
    mi: int = _get_int(o, KEY_ISO_MINUTE);
    s: int = _get_int(o, KEY_ISO_SECOND);
    ns: int = _get_int(o, KEY_ISO_NANOSECOND);
    fields: JSValue = args[0];
    # See js_engine-temporal-with-template: RejectObjectWithCalendarOrTimeZone, then read
    # calendar/timeZone (reject if present), then every field observably in ALPHABETICAL
    # key order (day, hour, microsecond, millisecond, minute, month, monthCode,
    # nanosecond, second, year) with immediate coercion, then options.overflow.
    if js_is_any_temporal_object(fields) {
        vm_throw_native(
            make_type_error("PlainDateTime.with: argument must be a plain object")
        );
        return js_undefined();
    }
    cvf: JSValue = js_object_get_observable(fields, str_intern("calendar"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tzvf: JSValue = js_object_get_observable(fields, str_intern("timeZone"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(cvf) or not jsv_is_undefined(tzvf) {
        vm_throw_native(
            make_type_error("PlainDateTime.with accepts only date/time fields")
        );
        return js_undefined();
    }
    seen: bool = False;
    cur_ms: int = ns // 1000000;
    cur_us: int = (ns // 1000) % 1000;
    cur_ns: int = ns % 1000;
    dv: JSValue = js_object_get_observable(fields, str_intern("day"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(dv) {
        d = _pdt_field_int(dv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    hv: JSValue = js_object_get_observable(fields, str_intern("hour"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(hv) {
        h = _pdt_field_int(hv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    usv: JSValue = js_object_get_observable(fields, str_intern("microsecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(usv) {
        cur_us = _pdt_field_int(usv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    msv: JSValue = js_object_get_observable(fields, str_intern("millisecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(msv) {
        cur_ms = _pdt_field_int(msv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    miv: JSValue = js_object_get_observable(fields, str_intern("minute"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(miv) {
        mi = _pdt_field_int(miv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    mv: JSValue = js_object_get_observable(fields, str_intern("month"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    have_m: bool = not jsv_is_undefined(mv);
    m_int: int = 0;
    if have_m {
        m_int = _pdt_field_int(mv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    mcv: JSValue = js_object_get_observable(fields, str_intern("monthCode"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    bad_month_code: bool = False;
    if not jsv_is_undefined(mcv) {
        mc_s: str = js_to_string_observable(mcv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        mc_n: int = parse_month_code(mc_s);
        if mc_n < 0 {
            vm_throw_native(make_range_error("invalid monthCode"));
            return js_undefined();
        }
        mc_is_leap: bool = len(mc_s) > 0 and mc_s[len(mc_s) - 1] == "L";
        if cal == "iso8601" and (mc_n > 12 or mc_is_leap) {
            bad_month_code = True;
        }
        if have_m and mc_n != m_int {
            vm_throw_native(make_range_error("month and monthCode must agree"));
            return js_undefined();
        }
        m = mc_n;
        seen = True;
    } elif have_m {
        m = m_int;
    }
    nsvv: JSValue = js_object_get_observable(fields, str_intern("nanosecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(nsvv) {
        cur_ns = _pdt_field_int(nsvv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    sv: JSValue = js_object_get_observable(fields, str_intern("second"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(sv) {
        s = _pdt_field_int(sv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    yv: JSValue = js_object_get_observable(fields, str_intern("year"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(yv) {
        y = _pdt_field_int(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    ns = cur_ms * 1000000 + cur_us * 1000 + cur_ns;
    if not seen {
        vm_throw_native(
            make_type_error("with() requires at least one recognized field")
        );
        return js_undefined();
    }
    # Non-positive month/day reject before options (ToPositiveIntegerWithTruncation).
    if m < 1 or d < 1 {
        vm_throw_native(make_range_error("month and day must be positive"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(js_undefined());
    if len(args) > 1 {
        temporal_require_options_object(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
        ov = temporal_get_overflow(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # monthCode incorrect for calendar rejects AFTER options.overflow is read.
    if bad_month_code {
        vm_throw_native(make_range_error("monthCode is incorrect for calendar"));
        return js_undefined();
    }
    era: int = cfields[CF_ERA];
    era_y: int = cfields[CF_ERA_YEAR];
    leap_m: int = 0;
    if len(cfields) > CF_IS_LEAP_MONTH {
        leap_m = cfields[CF_IS_LEAP_MONTH];
    }
    iso_parts: list[int] = calendar_fields_to_iso(
        [y, m, m, d, era, era_y, 0, 0, 0, 0, 0, leap_m], cal
    );
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
    # Time fields honor overflow too: "reject" throws on an out-of-range value, the
    # default "constrain" clamps each to its maximum (minute 67 → 59). RegulateTime.
    if ov == "reject" {
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
    # The COMBINED date+time must be within the representable ISO datetime range. This
    # is stricter than the date alone: "-271821-04-19T00:00:00" is out of range even
    # though "-271821-04-20" (the min) is fine — the time matters at the boundary.
    if not iso_validate_datetime_within_limits(y, m, d, h, mi, s, ns) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(y, m, d, h, mi, s, ns, cal);
}

def:priv _pdt_duration_until(
    y1: int,
    m1: int,
    d1: int,
    h1: int,
    mi1: int,
    s1: int,
    ns1: int,
    y2: int,
    m2: int,
    d2: int,
    h2: int,
    mi2: int,
    s2: int,
    ns2: int
) -> list[float] {
    days: int = dur_until_days(y1, m1, d1, y2, m2, d2);
    t1: int = iso_total_nanoseconds(h1, mi1, s1, ns1);
    t2: int = iso_total_nanoseconds(h2, mi2, s2, ns2);
    time_ns: int = t2 - t1;
    # ES DifferenceISODateTime: the date-part (days) and time-part must share one
    # sign. When they disagree, borrow a whole day across the boundary IN THE
    # DIRECTION of the overall difference. Forward (days>0) with a negative time
    # borrows a day down; backward (days<0) with a positive time borrows a day up.
    # The old code only handled the forward case, so PlainDateTime since/until on a
    # backward-in-time argument came out mis-balanced (extra day + tiny opposite
    # remainder). After this, days and time_ns share a sign (or one is zero).
    if days > 0 and time_ns < 0 {
        days = days - 1;
        time_ns = time_ns + 86400000000000;
    } elif days < 0 and time_ns > 0 {
        days = days + 1;
        time_ns = time_ns - 86400000000000;
    }
    # Decompose the ABSOLUTE time-of-day remainder (Jac // / % floor for negatives,
    # which would corrupt the h/mi/sc/ns split), then re-apply the sign via
    # dur_from_components (it derives DUR_SIGN from any negative component).
    time_neg: bool = time_ns < 0;
    abs_ns: int = time_ns;
    if time_neg {
        abs_ns = -abs_ns;
    }
    h: int = abs_ns // 3600000000000;
    rem: int = abs_ns % 3600000000000;
    mi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    sc: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    if time_neg {
        h = -h;
        mi = -mi;
        sc = -sc;
        n = -n;
    }
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, float(days), float(h), float(mi), float(sc), float(n)
    );
    return dur_balance(dur);
}

def:pub js_PlainDateTime_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return _pdt_until_core(this_val, args, False);
}

# Shared until/since core. `flip_mode` negates the roundingMode (NegateRoundingMode) so
# `since` — which rounds the NEGATED difference — rounds in the correct direction; the
# caller (`since`) then negates the resulting duration.
def:priv _pdt_until_core(
    this_val: JSValue, args: list[JSValue], flip_mode: bool
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDateTime.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` is converted BEFORE options are read/validated (§since/until).
    other: JSValue = ToTemporalPlainDateTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    oy: int = _get_int(o, KEY_ISO_YEAR);
    om: int = _get_int(o, KEY_ISO_MONTH);
    od: int = _get_int(o, KEY_ISO_DAY);
    oh: int = _get_int(o, KEY_ISO_HOUR);
    omi: int = _get_int(o, KEY_ISO_MINUTE);
    os: int = _get_int(o, KEY_ISO_SECOND);
    ons: int = _get_int(o, KEY_ISO_NANOSECOND);
    ey: int = _get_int(other, KEY_ISO_YEAR);
    em: int = _get_int(other, KEY_ISO_MONTH);
    ed: int = _get_int(other, KEY_ISO_DAY);
    eh: int = _get_int(other, KEY_ISO_HOUR);
    emi: int = _get_int(other, KEY_ISO_MINUTE);
    es: int = _get_int(other, KEY_ISO_SECOND);
    ens: int = _get_int(other, KEY_ISO_NANOSECOND);
    cal: str = temporal_get_calendar(o);
    # GetDifferenceSettings(DATETIME): read largestUnit, roundingIncrement, roundingMode,
    # smallestUnit in ALPHABETICAL order (all units allowed).
    du_units: list[str] = temporal_read_difference_settings(
        opts, "day", "nanosecond", "datetime"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if flip_mode {
        du_units[3] = negate_rounding_mode_string(du_units[3]);
    }
    largest: str = du_units[0];
    smallest: str = du_units[1];
    # DifferenceISODateTime: separate the diff into a whole-day-aligned DATE part and a
    # time-of-day part in [0, 1 day). The time part is `end_time - start_time`; when it
    # opposes the overall date direction, borrow ONE day from the date part so the time
    # remainder matches the date sign (e.g. later time-of-day is earlier → date -1 day,
    # time + 24h). Then the date difference runs on the (possibly adjusted) end date, and
    # the calendar y/m/w/d breakdown comes from calendar_date_until.
    t1: int = iso_total_nanoseconds(oh, omi, os, ons);
    t2: int = iso_total_nanoseconds(eh, emi, es, ens);
    time_ns: int = t2 - t1;
    date_days: int = iso_days_from_ymd(ey, em, ed) - iso_days_from_ymd(oy, om, od);
    # Overall direction from the total signed nanoseconds.
    total_sign: int = 0;
    if date_days > 0 or (date_days == 0 and time_ns > 0) {
        total_sign = 1;
    } elif date_days < 0 or (date_days == 0 and time_ns < 0) {
        total_sign = -1;
    }
    # Adjust the end DATE so the residual time matches total_sign.
    adj_ey: int = ey;
    adj_em: int = em;
    adj_ed: int = ed;
    if time_ns != 0 and total_sign != 0 and ((time_ns < 0) != (total_sign < 0)) {
        # time_ns opposes the date direction: move the end date one step toward start and
        # fold a day back into the time remainder.
        shifted: list[int] = iso_balance_date(adj_ey, adj_em, adj_ed - total_sign);
        adj_ey = shifted[0];
        adj_em = shifted[1];
        adj_ed = shifted[2];
        time_ns = time_ns + total_sign * 86400000000000;
    }
    # Calendar date difference on the adjusted end date.
    date_parts: list[int] = calendar_date_until(
        oy, om, od, adj_ey, adj_em, adj_ed, cal, largest
    );
    # Time remainder decomposed into h/m/s/ns (signed).
    abs_t: int = time_ns;
    if abs_t < 0 {
        abs_t = -abs_t;
    }
    th: int = abs_t // 3600000000000;
    tr: int = abs_t % 3600000000000;
    tmi: int = tr // 60000000000;
    tr2: int = tr % 60000000000;
    tsc: int = tr2 // 1000000000;
    tnsp: int = tr2 % 1000000000;
    tsgn: float = 1.0;
    if time_ns < 0 {
        tsgn = -1.0;
    }
    merged: list[float] = dur_from_components(
        float(date_parts[0]),
        float(date_parts[1]),
        float(date_parts[2]),
        float(date_parts[3]),
        float(th) * tsgn,
        float(tmi) * tsgn,
        float(tsc) * tsgn,
        float(tnsp) * tsgn
    );
    dur2: list[float] = temporal_apply_difference_rounding_resolved(
        dur_balance(merged),
        opts,
        largest,
        smallest,
        True,
        oy,
        om,
        od,
        oh,
        omi,
        os,
        ons,
        int(du_units[2]),
        rounding_mode_from_string(du_units[3])
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(dur2);
}

def:pub js_PlainDateTime_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDateTime.since requires 1 argument"));
        return js_undefined();
    }
    # since rounds the NEGATED difference: compute until with a flipped roundingMode
    # (NegateRoundingMode), then negate the resulting duration.
    until_v: JSValue = _pdt_until_core(this_val, args, True);
    if vm_has_native_exc() {
        return js_undefined();
    }
    neg: list[float] = dur_negate(ToTemporalDurationValue(until_v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(neg);
}

def:pub js_PlainDateTime_withPlainTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
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
    return js_plain_datetime_create(y, m, d, h, mi, s, ns, temporal_get_calendar(o));
}

def:pub js_PlainDateTime_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 {
        return js_boolean(False);
    }
    other: JSValue = ToTemporalPlainDateTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_boolean(False);
    }
    eq: bool = _get_int(o, KEY_ISO_YEAR) == _get_int(other, KEY_ISO_YEAR);
    eq = eq and _get_int(o, KEY_ISO_MONTH) == _get_int(other, KEY_ISO_MONTH);
    eq = eq and _get_int(o, KEY_ISO_DAY) == _get_int(other, KEY_ISO_DAY);
    eq = eq and _get_int(o, KEY_ISO_HOUR) == _get_int(other, KEY_ISO_HOUR);
    eq = eq and _get_int(o, KEY_ISO_MINUTE) == _get_int(other, KEY_ISO_MINUTE);
    eq = eq and _get_int(o, KEY_ISO_SECOND) == _get_int(other, KEY_ISO_SECOND);
    eq = eq and _get_int(o, KEY_ISO_NANOSECOND) == _get_int(other, KEY_ISO_NANOSECOND);
    eq = eq and temporal_get_calendar(o) == temporal_get_calendar(other);
    return js_boolean(eq);
}

def:pub js_PlainDateTime_round(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    # round(roundTo): a missing/undefined roundTo is a TypeError (§step 3), thrown
    # before any option is read — distinct from the empty-object RangeError below.
    if len(args) < 1 or jsv_is_undefined(args[0]) {
        vm_throw_native(
            make_type_error("PlainDateTime.round requires a roundTo argument")
        );
        return js_undefined();
    }
    opts: JSValue = args[0];
    opts = temporal_round_options_from_arg(opts);
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Round options are read in ALPHABETICAL order (roundingIncrement, roundingMode,
    # smallestUnit) and ALL reads complete before the increment-vs-unit validation
    # (§round order-of-operations / options-read-before-algorithmic-validation).
    increment: int = temporal_get_rounding_increment(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    mode: int = temporal_get_round_rounding_mode(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # smallestUnit is REQUIRED for round — an empty options object → RangeError (distinct
    # from the undefined-roundTo TypeError above). This getter throws when absent instead
    # of defaulting to "nanosecond".
    unit: str = temporal_get_smallest_unit_required(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur_validate_rounding_increment(
        increment, temporal_instant_round_max_increment(unit), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    y0: int = _get_int(o, KEY_ISO_YEAR);
    m0: int = _get_int(o, KEY_ISO_MONTH);
    d0: int = _get_int(o, KEY_ISO_DAY);
    total_ns: int = iso_total_nanoseconds(
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND)
    );
    if unit == "day" {
        # Round the time-of-day toward the nearest midnight; a round-up to 86400e9 carries
        # into the DATE (RoundISODateTime rolls to the next day).
        rounded_day_ns: int = _temporal_round_int(total_ns, 86400000000000, mode);
        carry: int = rounded_day_ns // 86400000000000;
        nd: list[int] = iso_add_days(y0, m0, d0, carry);
        if not iso_validate_datetime_within_limits(nd[0], nd[1], nd[2], 0, 0, 0, 0) {
            vm_throw_native(make_range_error("date-time out of range"));
            return js_undefined();
        }
        return js_plain_datetime_create(
            nd[0], nd[1], nd[2], 0, 0, 0, 0, temporal_get_calendar(o)
        );
    }
    rounded_ns: int = temporal_round_time_ns(total_ns, unit, increment, mode);
    carry2: int = rounded_ns // 86400000000000;
    rem_day: int = rounded_ns - carry2 * 86400000000000;
    h: int = rem_day // 3600000000000;
    rem: int = rem_day % 3600000000000;
    mi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    sc: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    ny: int = y0;
    nm: int = m0;
    ndd: int = d0;
    if carry2 != 0 {
        cd: list[int] = iso_add_days(y0, m0, d0, carry2);
        ny = cd[0];
        nm = cd[1];
        ndd = cd[2];
    }
    if not iso_validate_datetime_within_limits(ny, nm, ndd, h, mi, sc, n) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(
        ny, nm, ndd, h, mi, sc, n, temporal_get_calendar(o)
    );
}

# Round a non-negative int to a multiple of `step` per rounding mode (RoundISODateTime
# day path — halfExpand default already resolved by the caller's mode).
def:priv _temporal_round_int(v: int, step: int, mode: int) -> int {
    q: int = v // step;
    r: int = v - q * step;
    if r == 0 {
        return v;
    }
    lo: int = q * step;
    hi: int = lo + step;
    if mode == ROUND_TRUNC or mode == ROUND_FLOOR {
        return lo;
    }
    if mode == ROUND_EXPAND or mode == ROUND_CEIL {
        return hi;
    }
    twice: int = r * 2;
    if twice < step {
        return lo;
    }
    if twice > step {
        return hi;
    }
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

def:pub js_PlainDateTime_toPlainDate(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    return js_plain_date_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        temporal_get_calendar(o)
    );
}

def:pub js_PlainDateTime_toPlainTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    return js_plain_time_create(
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        temporal_get_calendar(o)
    );
}

def:pub js_PlainDateTime_withCalendar(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("PlainDateTime.withCalendar requires 1 argument")
        );
        return js_undefined();
    }
    cal: str = temporal_parse_calendar(args[0]);
    return js_plain_datetime_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        cal
    );
}

def:pub js_PlainDateTime_toZonedDateTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("PlainDateTime.toZonedDateTime requires 1 argument")
        );
        return js_undefined();
    }
    tz: str = ToTemporalTimeZoneIdentifier(args[0]);
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
    off_ns: int = temporal_offset_ns_for_zone(tz, y, m, d, h, mi, s);
    # The resulting instant (local wall-clock minus the zone offset) must be a valid
    # epoch-nanosecond value; a PDT at the ISO date limit can map to an out-of-range
    # instant (off_ns here is in SECONDS, matching js_zoned_datetime_create's offset_s).
    epoch_ns: list[int] = temporal_local_epoch_ns(
        y, m, d, h, mi, s, ns, off_ns * 1000000000
    );
    temporal_reject_epoch_ns_out_of_range(epoch_ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_zoned_datetime_create(
        y, m, d, h, mi, s, ns, tz, off_ns, temporal_get_calendar(o)
    );
}

def:pub js_PlainDateTime_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Options are read in ALPHABETICAL order: calendarName FIRST, then
    # fractionalSecondDigits, roundingMode, smallestUnit (inside the formatter)
    # (§Temporal.PlainDateTime.prototype.toString order-of-operations).
    cal_name: str = temporal_get_calendar_name(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    s: str = temporal_format_datetime_to_string(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        _get_int(o, KEY_ISO_HOUR),
        _get_int(o, KEY_ISO_MINUTE),
        _get_int(o, KEY_ISO_SECOND),
        _get_int(o, KEY_ISO_NANOSECOND),
        opts
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    s = s + temporal_format_calendar_suffix(temporal_get_calendar(o), cal_name);
    return jsv_from_string_id(str_intern(s));
}

def:pub js_PlainDateTime_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options and must not read off its argument (toJSON/basic passes
    # a throwing Proxy) — call toString with fixed defaults, ignoring args.
    empty_args: list[JSValue] = [];
    return js_PlainDateTime_toString(this_val, empty_args);
}

def:pub js_PlainDateTime_toLocaleString(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    return js_PlainDateTime_toString(this_val, args);
}

def:pub js_PlainDateTime_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_PlainDateTime_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_datetime(this_val);
    return temporal_plain_datetime_getter(o, temporal_callee_name());
}
