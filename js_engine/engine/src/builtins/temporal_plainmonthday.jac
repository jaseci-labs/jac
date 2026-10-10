"""Temporal.PlainMonthDay built-in."""

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
import from engine.src.runtime.temporal_parse { parse_month_code }
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_iso {
    iso_days_in_month,
    iso_add_days,
    iso_format_date
}
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_balance,
    dur_negate,
    dur_until_days,
    DUR_DAYS,
    DUR_SIGN
}
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }
import from engine.src.builtins.temporal {
    js_plain_month_day_create,
    js_this_plain_month_day,
    js_is_plain_month_day,
    js_is_any_temporal_object,
    js_plain_date_create,
    js_duration_create,
    temporal_require_options_object,
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
    temporal_constrain_ymd,
    ToTemporalMonthDay,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_REF_YEAR,
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
def:priv _md_field_int(v: JSValue) -> int {
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

def:pub js_Temporal_PlainMonthDay(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(
            make_type_error("PlainMonthDay constructor requires 2 arguments")
        );
        return js_undefined();
    }
    # Args are ToIntegerWithTruncation: coerce observably, reject non-finite.
    m: int = _md_field_int(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    d: int = _md_field_int(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if len(args) > 2 {
        cal = temporal_parse_calendar(args[2]);
    }
    # 4th argument is the referenceISOYear (defaults to the canonical 1972 for iso8601,
    # a leap year so 02-29 stays valid). It is kept verbatim on the result.
    ref_y: int = 1972;
    if len(args) > 3 and not jsv_is_undefined(args[3]) {
        ref_y = _md_field_int(args[3]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    temporal_reject_ymd(ref_y, m, d);
    return js_plain_month_day_create(m, d, ref_y, cal);
}

def:pub js_Temporal_PlainMonthDay_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("PlainMonthDay.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = ToTemporalMonthDay(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = ToTemporalMonthDay(args[1], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    m1: int = _get_int(a, KEY_ISO_MONTH);
    d1: int = _get_int(a, KEY_ISO_DAY);
    m2: int = _get_int(b, KEY_ISO_MONTH);
    d2: int = _get_int(b, KEY_ISO_DAY);
    if m1 < m2 {
        return js_int(-1);
    }
    if m1 > m2 {
        return js_int(1);
    }
    if d1 < d2 {
        return js_int(-1);
    }
    if d1 > d2 {
        return js_int(1);
    }
    return js_int(0);
}

def:pub js_Temporal_PlainMonthDay_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainMonthDay.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    return ToTemporalMonthDay(args[0], opts);
}

def:pub js_PlainMonthDay_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    opts: JSValue = js_undefined();
    if len(args) >= 1 {
        opts = args[0];
    }
    cal_name: str = temporal_get_calendar_name(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    cal: str = temporal_get_calendar(o);
    is_iso: bool = cal == "iso8601" or len(cal) == 0;
    # TemporalMonthDayToString (ES §): "--MM-DD" for ISO, but when the calendar is
    # shown (non-ISO, or showCalendar always/critical) the full reference date
    # "YYYY-MM-DD[u-ca=…]" is emitted so the string round-trips.
    show_ref: bool = (not is_iso) or cal_name == "always" or cal_name == "critical";
    s: str = "";
    if show_ref {
        s = iso_format_date(_get_int(o, KEY_REF_YEAR), m, d);
    } else {
        ms: str = str(m);
        if m < 10 {
            ms = "0" + ms;
        }
        ds: str = str(d);
        if d < 10 {
            ds = "0" + ds;
        }
        s = "--" + ms + "-" + ds;
    }
    s = s + temporal_format_calendar_suffix(cal, cal_name);
    return jsv_from_string_id(str_intern(s));
}

def:pub js_PlainMonthDay_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options and must not read off its argument (toJSON/basic passes
    # a throwing Proxy) — call toString with fixed defaults, ignoring args.
    empty_args: list[JSValue] = [];
    return js_PlainMonthDay_toString(this_val, empty_args);
}

def:pub js_PlainMonthDay_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_PlainMonthDay_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    if len(args) < 1 {
        return js_boolean(False);
    }
    other: JSValue = ToTemporalMonthDay(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_boolean(False);
    }
    eq: bool = _get_int(o, KEY_ISO_MONTH) == _get_int(other, KEY_ISO_MONTH);
    eq = eq and _get_int(o, KEY_ISO_DAY) == _get_int(other, KEY_ISO_DAY);
    eq = eq and temporal_get_calendar(o) == temporal_get_calendar(other);
    return js_boolean(eq);
}

def:pub js_PlainMonthDay_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainMonthDay.add requires 1 argument"));
        return js_undefined();
    }
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    ref_y: int = _get_int(o, KEY_REF_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    bal: list[int] = iso_add_days(ref_y, m, d, int(dur[DUR_DAYS]) * sign);
    return js_plain_month_day_create(bal[1], bal[2], ref_y, temporal_get_calendar(o));
}

def:pub js_PlainMonthDay_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    neg: list[float] = dur_negate(ToTemporalDurationValue(args[0]));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_PlainMonthDay_add(this_val, [js_duration_create(neg)]);
}

def:pub js_PlainMonthDay_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("PlainMonthDay.with requires an object"));
        return js_undefined();
    }
    cal: str = temporal_get_calendar(o);
    ref_y: int = _get_int(o, KEY_REF_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    fields: JSValue = args[0];
    # with-template: reject Temporal objects, read calendar/timeZone (reject if present),
    # then day, month, monthCode, year observably in alphabetical order, then
    # options.overflow. The `year` only disambiguates; the referenceISOYear stays
    # canonical. See js_engine-temporal-with-template.
    if js_is_any_temporal_object(fields) {
        vm_throw_native(
            make_type_error("PlainMonthDay.with: argument must be a plain object")
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
            make_type_error("PlainMonthDay.with accepts only month-day fields")
        );
        return js_undefined();
    }
    seen: bool = False;
    dv: JSValue = js_object_get_observable(fields, str_intern("day"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(dv) {
        d = _md_field_int(dv);
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
        m_int = _md_field_int(mv);
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
        _ = _md_field_int(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    if not seen {
        vm_throw_native(
            make_type_error("PlainMonthDay.with requires at least one field")
        );
        return js_undefined();
    }
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
    }
    if bad_month_code {
        vm_throw_native(make_range_error("monthCode is incorrect for calendar"));
        return js_undefined();
    }
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
    return js_plain_month_day_create(m, d, ref_y, cal);
}

def:pub js_PlainMonthDay_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainMonthDay.until requires 1 argument"));
        return js_undefined();
    }
    other: JSValue = ToTemporalMonthDay(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    ref_y: int = _get_int(o, KEY_REF_YEAR);
    days: int = dur_until_days(
        ref_y,
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        ref_y,
        _get_int(other, KEY_ISO_MONTH),
        _get_int(other, KEY_ISO_DAY)
    );
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, float(days), 0.0, 0.0, 0.0, 0.0
    );
    return js_duration_create(dur_balance(dur));
}

def:pub js_PlainMonthDay_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainMonthDay.since requires 1 argument"));
        return js_undefined();
    }
    other: JSValue = ToTemporalMonthDay(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    ref_y: int = _get_int(o, KEY_REF_YEAR);
    days: int = dur_until_days(
        ref_y,
        _get_int(other, KEY_ISO_MONTH),
        _get_int(other, KEY_ISO_DAY),
        ref_y,
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY)
    );
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, float(days), 0.0, 0.0, 0.0, 0.0
    );
    return js_duration_create(dur_balance(dur));
}

def:pub js_PlainMonthDay_toPlainDate(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    # The argument supplies the missing `year` field and MUST be an object
    # (§Temporal.PlainMonthDay.prototype.toPlainDate: a non-Object is a TypeError).
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(
            make_type_error("PlainMonthDay.toPlainDate requires an object argument")
        );
        return js_undefined();
    }
    y: int = _get_int(o, KEY_REF_YEAR);
    # `year` is read observably (its valueOf fires) — order-of-operations.
    yv: JSValue = js_object_get_observable(args[0], str_intern("year"), args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(yv) {
        y = _md_field_int(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
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
    return js_plain_date_create(y, m, d, temporal_get_calendar(o));
}

def:pub js_PlainMonthDay_toLocaleString(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    return js_PlainMonthDay_toString(this_val, args);
}

def:pub js_PlainMonthDay_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_month_day(this_val);
    name: str = temporal_callee_name();
    ref_y: int = _get_int(o, KEY_REF_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    if name == "calendarId" {
        return temporal_plain_date_getter(o, name);
    }
    if name == "monthCode" {
        return temporal_plain_date_getter(o, name);
    }
    if name == "referenceISOYear" {
        return js_int(ref_y);
    }
    if name == "day" {
        return js_int(d);
    }
    if name == "daysInMonth" {
        return js_int(iso_days_in_month(ref_y, m));
    }
    if name == "daysInWeek" {
        return js_int(7);
    }
    return js_undefined();
}
