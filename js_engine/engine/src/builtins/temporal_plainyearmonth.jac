"""Temporal.PlainYearMonth built-in."""

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
    jsv_is_undefined
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_to_number_observable,
    js_to_string_observable
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_iso {
    iso_format_date,
    iso_days_in_month,
    iso_compare,
    iso_add_months,
    iso_validate_relativeto_ymd,
    iso_validate_year_month,
    iso_validate_datetime_within_limits
}
import from engine.src.runtime.temporal_parse { parse_month_code }
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_balance,
    dur_negate,
    rounding_mode_from_string,
    negate_rounding_mode_string,
    DUR_YEARS,
    DUR_MONTHS,
    DUR_SIGN
}
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }
import from engine.src.builtins.calendars.calendar_dispatch {
    calendar_iso_to_fields,
    calendar_fields_to_iso
}
import from engine.src.builtins.calendars.calendar_gregory {
    CF_YEAR,
    CF_MONTH,
    CF_MONTH_CODE,
    CF_ERA,
    CF_ERA_YEAR,
    CF_DAY,
    CF_IS_LEAP_MONTH
}
import from engine.src.builtins.calendars.calendar_arithmetic {
    calendar_date_add,
    calendar_date_until
}
import from engine.src.builtins.temporal {
    js_plain_year_month_create,
    js_plain_year_month_create_ref,
    js_this_plain_year_month,
    js_is_plain_year_month,
    js_is_any_temporal_object,
    js_plain_date_create,
    js_duration_create,
    temporal_to_string,
    temporal_parse_calendar,
    temporal_reject_ymd,
    temporal_plain_date_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    temporal_format_calendar_suffix,
    temporal_get_calendar,
    temporal_get_calendar_name,
    temporal_get_overflow,
    temporal_require_options_object,
    temporal_get_largest_unit,
    temporal_apply_difference_rounding,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    temporal_constrain_ymd,
    ToTemporalYearMonth,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_CALENDAR
}
import from engine.src.builtins.string { js_coerce_to_string }

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

# ToIntegerWithTruncation for a property-bag field (observable valueOf, truncate).
def:priv _ym_field_int(v: JSValue) -> int {
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

def:pub js_Temporal_PlainYearMonth(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(
            make_type_error("PlainYearMonth constructor requires 2 arguments")
        );
        return js_undefined();
    }
    # Args are ToIntegerWithTruncation: coerce observably, reject non-finite.
    y: int = _ym_field_int(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    m: int = _ym_field_int(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if len(args) > 2 {
        cal = temporal_parse_calendar(args[2]);
    }
    # The optional 4th argument is referenceISODay (ToIntegerWithTruncation, default 1);
    # it must form a valid ISO date with (y, m).
    ref_day: int = 1;
    if len(args) > 3 and not jsv_is_undefined(args[3]) {
        ref_day = _ym_field_int(args[3]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    temporal_reject_ymd(y, m, ref_day);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not iso_validate_year_month(y, m) {
        vm_throw_native(make_range_error("year-month out of range"));
        return js_undefined();
    }
    return js_plain_year_month_create_ref(y, m, ref_day, cal);
}

def:pub js_Temporal_PlainYearMonth_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("PlainYearMonth.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = ToTemporalYearMonth(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = ToTemporalYearMonth(args[1], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    y1: int = _get_int(a, KEY_ISO_YEAR);
    m1: int = _get_int(a, KEY_ISO_MONTH);
    y2: int = _get_int(b, KEY_ISO_YEAR);
    m2: int = _get_int(b, KEY_ISO_MONTH);
    if y1 < y2 {
        return js_int(-1);
    }
    if y1 > y2 {
        return js_int(1);
    }
    if m1 < m2 {
        return js_int(-1);
    }
    if m1 > m2 {
        return js_int(1);
    }
    return js_int(0);
}

def:pub js_Temporal_PlainYearMonth_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainYearMonth.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    return ToTemporalYearMonth(args[0], opts);
}

def:pub js_PlainYearMonth_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    opts: JSValue = js_undefined();
    if len(args) >= 1 {
        opts = args[0];
    }
    cal_name: str = temporal_get_calendar_name(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = temporal_get_calendar(o);
    is_iso: bool = cal == "iso8601" or len(cal) == 0;
    # TemporalYearMonthToString (ES §): normally "YYYY-MM", but when the calendar is
    # shown — a non-ISO calendar, or showCalendar is "always"/"critical" — the
    # reference ISO day is appended so the string round-trips: "YYYY-MM-DD[u-ca=…]".
    show_ref: bool = (not is_iso) or cal_name == "always" or cal_name == "critical";
    full: str = iso_format_date(
        _get_int(o, KEY_ISO_YEAR), _get_int(o, KEY_ISO_MONTH), _get_int(o, KEY_ISO_DAY)
    );
    s: str = full;
    if not show_ref {
        s = full[0:len(full) - 3];
    }
    s = s + temporal_format_calendar_suffix(cal, cal_name);
    return jsv_from_string_id(str_intern(s));
}

def:pub js_PlainYearMonth_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options and must not read off its argument (toJSON/basic passes
    # a throwing Proxy) — call toString with a fixed default, ignoring args.
    empty_args: list[JSValue] = [];
    return js_PlainYearMonth_toString(this_val, empty_args);
}

def:pub js_PlainYearMonth_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_PlainYearMonth_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    if len(args) < 1 {
        return js_boolean(False);
    }
    other: JSValue = ToTemporalYearMonth(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_boolean(False);
    }
    eq: bool = _get_int(o, KEY_ISO_YEAR) == _get_int(other, KEY_ISO_YEAR);
    eq = eq and _get_int(o, KEY_ISO_MONTH) == _get_int(other, KEY_ISO_MONTH);
    eq = eq and temporal_get_calendar(o) == temporal_get_calendar(other);
    return js_boolean(eq);
}

def:priv _pym_months_between(y1: int, m1: int, y2: int, m2: int) -> int {
    return (y2 - y1) * 12 + (m2 - m1);
}

def:pub js_PlainYearMonth_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainYearMonth.add requires 1 argument"));
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
    ov: str = temporal_get_overflow(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    cal: str = temporal_get_calendar(o);
    bal: list[int] = calendar_date_add(
        y, m, 1, cal, int(dur[DUR_YEARS]) * sign, int(dur[DUR_MONTHS]) * sign, 0, 0, ov
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not iso_validate_year_month(bal[0], bal[1]) {
        vm_throw_native(make_range_error("year-month out of range"));
        return js_undefined();
    }
    return js_plain_year_month_create(bal[0], bal[1], cal);
}

def:pub js_PlainYearMonth_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    neg: list[float] = dur_negate(ToTemporalDurationValue(args[0]));
    if vm_has_native_exc() {
        return js_undefined();
    }
    sub_args: list[JSValue] = [js_duration_create(neg)];
    if len(args) > 1 {
        sub_args.append(args[1]);
    }
    return js_PlainYearMonth_add(this_val, sub_args);
}

def:pub js_PlainYearMonth_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("PlainYearMonth.with requires an object"));
        return js_undefined();
    }
    cal: str = temporal_get_calendar(o);
    cfields: list[int] = calendar_iso_to_fields(
        _get_int(o, KEY_ISO_YEAR), _get_int(o, KEY_ISO_MONTH), 1, cal
    );
    y: int = cfields[CF_YEAR];
    m: int = cfields[CF_MONTH];
    fields: JSValue = args[0];
    # with-template (no day field): reject Temporal objects, then read calendar/timeZone
    # (reject if present), then month, monthCode, year observably in alphabetical order,
    # then options.overflow. See js_engine-temporal-with-template.
    if js_is_any_temporal_object(fields) {
        vm_throw_native(
            make_type_error("PlainYearMonth.with: argument must be a plain object")
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
            make_type_error("PlainYearMonth.with accepts only year-month fields")
        );
        return js_undefined();
    }
    seen: bool = False;
    mv: JSValue = js_object_get_observable(fields, str_intern("month"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    have_m: bool = not jsv_is_undefined(mv);
    m_int: int = 0;
    if have_m {
        m_int = _ym_field_int(mv);
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
    yv: JSValue = js_object_get_observable(fields, str_intern("year"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(yv) {
        y = _ym_field_int(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    if not seen {
        vm_throw_native(
            make_type_error("PlainYearMonth.with requires at least one field")
        );
        return js_undefined();
    }
    if m < 1 {
        vm_throw_native(make_range_error("month must be positive"));
        return js_undefined();
    }
    ov: str = temporal_get_overflow(js_undefined());
    if len(args) > 1 {
        temporal_require_options_object(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
        ov = temporal_get_overflow(args[1]);
    }
    if bad_month_code {
        vm_throw_native(make_range_error("monthCode is incorrect for calendar"));
        return js_undefined();
    }
    era: int = cfields[CF_ERA];
    era_y: int = cfields[CF_ERA_YEAR];
    iso_parts: list[int] = calendar_fields_to_iso(
        [y, m, m, 1, era, era_y, 0, 0, 0, 0, 0, 0], cal
    );
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
    if not iso_validate_relativeto_ymd(y, m, 1) {
        vm_throw_native(make_range_error("year-month out of range"));
        return js_undefined();
    }
    return js_plain_year_month_create(y, m, cal);
}

def:pub js_PlainYearMonth_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return _ym_until_core(this_val, args, False);
}

# Shared until/since core. `flip_mode` negates roundingMode (NegateRoundingMode) for
# `since`, which rounds the negated difference then negates the resulting duration.
def:priv _ym_until_core(
    this_val: JSValue, args: list[JSValue], flip_mode: bool
) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainYearMonth.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` is converted BEFORE options are read/validated (§since/until).
    other: JSValue = ToTemporalYearMonth(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    oy: int = _get_int(o, KEY_ISO_YEAR);
    om: int = _get_int(o, KEY_ISO_MONTH);
    ey: int = _get_int(other, KEY_ISO_YEAR);
    em: int = _get_int(other, KEY_ISO_MONTH);
    cal: str = temporal_get_calendar(o);
    # GetDifferenceSettings(YEARMONTH, disallowed «week,day»): read largestUnit,
    # roundingIncrement, roundingMode, smallestUnit in ALPHABETICAL order.
    units: list[str] = temporal_read_difference_settings(
        opts, "year", "month", "yearmonth"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if flip_mode {
        units[3] = negate_rounding_mode_string(units[3]);
    }
    largest: str = units[0];
    smallest: str = units[1];
    parts: list[int] = calendar_date_until(oy, om, 1, ey, em, 1, cal, largest);
    raw: list[float] = dur_from_components(
        float(parts[0]), float(parts[1]), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    );
    dur: list[float] = temporal_apply_difference_rounding_resolved(
        dur_balance(raw),
        opts,
        largest,
        smallest,
        True,
        oy,
        om,
        1,
        0,
        0,
        0,
        0,
        int(units[2]),
        rounding_mode_from_string(units[3])
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(dur);
}

def:pub js_PlainYearMonth_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainYearMonth.since requires 1 argument"));
        return js_undefined();
    }
    # since rounds the NEGATED difference: until with a flipped roundingMode, then negate.
    until_v: JSValue = _ym_until_core(this_val, args, True);
    if vm_has_native_exc() {
        return js_undefined();
    }
    neg: list[float] = dur_negate(ToTemporalDurationValue(until_v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(neg);
}

def:pub js_PlainYearMonth_toPlainDate(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    # The argument supplies the missing `day` field and MUST be an object
    # (§Temporal.PlainYearMonth.prototype.toPlainDate: ToTemporalDay reads item.day
    # after a "not an Object → TypeError" check).
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(
            make_type_error("PlainYearMonth.toPlainDate requires an object argument")
        );
        return js_undefined();
    }
    d: int = 1;
    # `day` is read observably (its valueOf fires) — order-of-operations.
    dv: JSValue = js_object_get_observable(args[0], str_intern("day"), args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(dv) {
        d = _ym_field_int(dv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    ov: str = "constrain";
    if len(args) > 1 {
        temporal_require_options_object(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
        ov = temporal_get_overflow(args[1]);
    }
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
    # The resulting PlainDate must be within the representable ISO date range
    # (ISODateWithinLimits ≡ ISODateTimeWithinLimits at noon).
    if not iso_validate_datetime_within_limits(y, m, d, 12, 0, 0, 0) {
        vm_throw_native(make_range_error("date out of range"));
        return js_undefined();
    }
    return js_plain_date_create(y, m, d, temporal_get_calendar(o));
}

def:pub js_PlainYearMonth_toLocaleString(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    return js_PlainYearMonth_toString(this_val, args);
}

def:pub js_PlainYearMonth_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_year_month(this_val);
    name: str = temporal_callee_name();
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    cal: str = temporal_to_string(js_object_get(o, KEY_CALENDAR));
    if name == "calendarId" {
        return temporal_plain_date_getter(o, name);
    }
    if name == "year"
        or name == "month"
        or name == "monthCode"
        or name == "era"
        or name == "eraYear"
        or name == "daysInMonth"
        or name == "daysInYear"
        or name == "monthsInYear"
        or name == "inLeapYear" {
        return temporal_plain_date_getter(o, name);
    }
    if name == "daysInWeek" {
        return js_int(7);
    }
    return js_undefined();
}
