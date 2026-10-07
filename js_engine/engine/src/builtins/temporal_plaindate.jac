"""Temporal.PlainDate built-in."""

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
    jsv_is_string_cell
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get, js_object_set }
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_to_string_observable,
    js_to_number_observable
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_parse {
    parse_iso_date_time,
    parse_month_code,
    PR_OK,
    PR_YEAR,
    PR_MONTH,
    PR_DAY,
    PR_CALENDAR,
    PR_HAS_DATE
}
import from engine.src.runtime.temporal_iso {
    iso_compare,
    iso_format_date,
    iso_add_days,
    iso_add_months,
    iso_balance_date,
    iso_validate_relativeto_ymd,
    iso_validate_datetime_within_limits
}
import from engine.src.runtime.temporal_duration_math {
    dur_until_days,
    DUR_YEARS,
    DUR_MONTHS,
    DUR_WEEKS,
    DUR_DAYS,
    DUR_SIGN,
    dur_negate,
    dur_from_components,
    dur_balance,
    rounding_mode_from_string,
    negate_rounding_mode_string
}
import from engine.src.builtins.calendars.calendar_arithmetic {
    calendar_date_add,
    calendar_date_until,
    calendar_regulate
}
import from engine.src.builtins.calendars.calendar_dispatch {
    calendar_iso_to_fields,
    calendar_fields_to_iso,
    calendar_id_normalize
}
import from engine.src.builtins.calendars.calendar_gregory {
    CF_YEAR,
    CF_MONTH,
    CF_DAY,
    CF_ERA,
    CF_ERA_YEAR,
    CF_IS_LEAP_MONTH
}
import from engine.src.builtins.temporal {
    js_plain_date_create,
    js_plain_date_init,
    js_this_plain_date,
    js_is_plain_date,
    js_is_duration,
    js_is_any_temporal_object,
    js_is_zoned_datetime,
    js_duration_create,
    js_duration_read,
    js_plain_datetime_create,
    js_plain_year_month_create,
    js_plain_month_day_create,
    js_zoned_datetime_create,
    temporal_to_string,
    temporal_parse_calendar,
    temporal_reject_ymd,
    temporal_plain_date_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    temporal_get_overflow,
    temporal_constrain_ymd,
    temporal_format_calendar_suffix,
    temporal_get_calendar_name,
    temporal_time_parts_from_like,
    temporal_offset_ns_for_zone,
    temporal_reject_epoch_ns_out_of_range,
    temporal_local_epoch_ns,
    temporal_require_options_object,
    temporal_get_largest_unit,
    temporal_apply_difference_rounding,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    ToTemporalDate,
    ToTemporalTime,
    ToTemporalTimeZoneIdentifier,
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

def:priv _pd_to_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

# ToIntegerWithTruncation for a property-bag field: coerce to Number observably
# (fires valueOf) then truncate toward zero. Non-finite → RangeError.
def:priv _pd_field_int(v: JSValue) -> int {
    n: float = js_to_number_observable(v);
    if vm_has_native_exc() {
        return 0;
    }
    if n != n or n == n + 1.0 {
        vm_throw_native(make_range_error("invalid date field"));
        return 0;
    }
    return int(n);
}

def:pub js_Temporal_PlainDate(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        vm_throw_native(make_type_error("PlainDate constructor requires 3 arguments"));
        return js_undefined();
    }
    # Constructor args are ToIntegerWithTruncation: coerce observably (fire an object's
    # valueOf) and throw RangeError for a non-finite value (Infinity/NaN), stopping at
    # the first bad arg — infinity-throws-rangeerror / constructor order-of-operations.
    y: int = _pd_field_int(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    m: int = _pd_field_int(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    d: int = _pd_field_int(args[2]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cal: str = "iso8601";
    if len(args) > 3 {
        cal = temporal_parse_calendar(args[3]);
    }
    temporal_reject_ymd(y, m, d);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # The date must be within the representable ISO range [-271821-04-19, +275760-09-14]
    # — CreateTemporalDate rejects an out-of-range date even from the constructor.
    if not iso_validate_relativeto_ymd(y, m, d) {
        vm_throw_native(make_range_error("date out of range"));
        return js_undefined();
    }
    if jsv_is_object_cell(this_val) and jsv_to_table_id(this_val) > 0 {
        return js_plain_date_init(this_val, y, m, d, cal);
    }
    return js_plain_date_create(y, m, d, cal);
}

def:pub js_Temporal_PlainDate_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    if js_is_plain_date(args[0]) {
        o: JSValue = args[0];
        # from(PlainDate, options): copy the source's calendar and only read+validate
        # the `overflow` option (§Temporal.PlainDate.from step 1.a). The second argument
        # is the OPTIONS bag, NOT a calendar — parsing it as a calendar was wrong
        # (from/options-basic: `{overflow:"constrain"}` → "invalid calendar").
        cal: str = _get_str_cal(o);
        _ = temporal_get_overflow(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return js_plain_date_create(
            _get_int(o, KEY_ISO_YEAR),
            _get_int(o, KEY_ISO_MONTH),
            _get_int(o, KEY_ISO_DAY),
            cal
        );
    }
    return ToTemporalDate(args[0], opts);
}

def _get_str_cal(o: JSValue) -> str {
    return temporal_to_string(js_object_get(o, KEY_CALENDAR));
}

def:pub js_Temporal_PlainDate_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("PlainDate.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = ToTemporalDate(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = ToTemporalDate(args[1], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_int(
        iso_compare(
            _get_int(a, KEY_ISO_YEAR),
            _get_int(a, KEY_ISO_MONTH),
            _get_int(a, KEY_ISO_DAY),
            _get_int(b, KEY_ISO_YEAR),
            _get_int(b, KEY_ISO_MONTH),
            _get_int(b, KEY_ISO_DAY)
        )
    );
}

def:pub js_PlainDate_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.add requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # The duration argument is converted (ToTemporalDuration reads its fields) BEFORE
    # options.overflow is read (§Temporal.PlainDate.prototype.add order-of-operations).
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
    d: int = _get_int(o, KEY_ISO_DAY);
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    cal: str = _get_str_cal(o);
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
    if not iso_validate_relativeto_ymd(bal[0], bal[1], bal[2]) {
        vm_throw_native(make_range_error("date out of range"));
        return js_undefined();
    }
    return js_plain_date_create(bal[0], bal[1], bal[2], cal);
}

def:pub js_PlainDate_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.subtract requires 1 argument"));
        return js_undefined();
    }
    neg: list[float] = dur_negate(ToTemporalDurationValue(args[0]));
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Forward the options argument (overflow) to add — subtract must read+validate it
    # (subtract/overflow-wrong-type, overflow-invalid-string).
    add_args: list[JSValue] = [js_duration_create(neg)];
    if len(args) > 1 {
        add_args.append(args[1]);
    }
    return js_PlainDate_add(o, add_args);
}

def:pub js_PlainDate_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("PlainDate.with requires an object"));
        return js_undefined();
    }
    cal: str = _get_str_cal(o);
    iso_y: int = _get_int(o, KEY_ISO_YEAR);
    iso_m: int = _get_int(o, KEY_ISO_MONTH);
    iso_d: int = _get_int(o, KEY_ISO_DAY);
    # Merge in calendar field space so non-ISO calendars interpret year/month/day correctly.
    cfields: list[int] = calendar_iso_to_fields(iso_y, iso_m, iso_d, cal);
    y: int = cfields[CF_YEAR];
    m: int = cfields[CF_MONTH];
    d: int = cfields[CF_DAY];
    fields: JSValue = args[0];
    # RejectObjectWithCalendarOrTimeZone: a Temporal object (which carries its own
    # calendar/timeZone) is never a valid plain fields bag.
    if js_is_any_temporal_object(fields) {
        vm_throw_native(
            make_type_error("PlainDate.with: argument must be a plain object")
        );
        return js_undefined();
    }
    # PrepareCalendarFields reads in alphabetical key order with getters firing:
    # calendar and timeZone first (both must be ABSENT — a PlainDate-like bag rejects
    # them), then day, month, monthCode, year — each read+coerced immediately. At least
    # one recognized field must be present. (§Temporal.PlainDate.prototype.with)
    cvf: JSValue = js_object_get_observable(fields, str_intern("calendar"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tzvf: JSValue = js_object_get_observable(fields, str_intern("timeZone"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(cvf) or not jsv_is_undefined(tzvf) {
        vm_throw_native(make_type_error("PlainDate.with accepts only date fields"));
        return js_undefined();
    }
    seen: bool = False;
    dv: JSValue = js_object_get_observable(fields, str_intern("day"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(dv) {
        d = _pd_field_int(dv);
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
        m_int = _pd_field_int(mv);
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
        # A monthCode identifies a specific month of the calendar and is NEVER
        # constrained: "M13" or a leap-month code ("M05L") that the ISO calendar lacks
        # is a RangeError even under overflow:"constrain". But this ALGORITHMIC check
        # fires only AFTER options.overflow is read (options-read-before-validation),
        # so remember it here and throw below.
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
        y = _pd_field_int(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    if not seen {
        vm_throw_native(
            make_type_error("PlainDate.with requires at least one date field")
        );
        return js_undefined();
    }
    # month and day are ToPositiveIntegerWithTruncation: a non-positive value is a
    # RangeError regardless of overflow, and this fires while reading the fields —
    # BEFORE options is validated (with/overflow: "non-positive month rejects even
    # with constrain"; options-wrong-type: "partial date processed before TypeError").
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
    # A monthCode the calendar doesn't have is rejected here — after options.overflow
    # has been read — never constrained (options-read-before-algorithmic-validation).
    if bad_month_code {
        vm_throw_native(make_range_error("monthCode is incorrect for calendar"));
        return js_undefined();
    }
    # Regulate in calendar space, then convert to ISO.
    era: int = cfields[CF_ERA];
    era_y: int = cfields[CF_ERA_YEAR];
    leap_m: int = 0;
    if len(cfields) > CF_IS_LEAP_MONTH {
        leap_m = cfields[CF_IS_LEAP_MONTH];
    }
    reg: list[int] = calendar_regulate(cal, y, m, d, ov);
    if vm_has_native_exc() {
        return js_undefined();
    }
    y = reg[0];
    m = reg[1];
    d = reg[2];
    merged: list[int] = [y, m, 0, d, era, era_y, 0, 0, 0, 0, 0, leap_m];
    iso_parts: list[int] = calendar_fields_to_iso(merged, cal);
    y = iso_parts[0];
    m = iso_parts[1];
    d = iso_parts[2];
    if ov == "reject" {
        temporal_reject_ymd(y, m, d);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        bal: list[int] = temporal_constrain_ymd(y, m, d);
        y = bal[0];
        m = bal[1];
        d = bal[2];
    }
    # The final date must land inside the representable ISO range — a too-low/too-high
    # year is a RangeError even under overflow:"constrain".
    if not iso_validate_relativeto_ymd(y, m, d) {
        vm_throw_native(make_range_error("date out of range"));
        return js_undefined();
    }
    return js_plain_date_create(y, m, d, cal);
}

def:pub js_PlainDate_withCalendar(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.withCalendar requires 1 argument"));
        return js_undefined();
    }
    cal: str = temporal_parse_calendar(args[0]);
    return js_plain_date_create(
        _get_int(o, KEY_ISO_YEAR),
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        cal
    );
}

def:pub js_PlainDate_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return _pd_until_core(this_val, args, False);
}

# Shared until/since core. `flip_mode` negates roundingMode (NegateRoundingMode) for
# `since`, which rounds the negated difference then negates the resulting duration.
def:priv _pd_until_core(
    this_val: JSValue, args: list[JSValue], flip_mode: bool
) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` is converted BEFORE options are read/validated (§since/until).
    other: JSValue = ToTemporalDate(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    oy: int = _get_int(o, KEY_ISO_YEAR);
    om: int = _get_int(o, KEY_ISO_MONTH);
    od: int = _get_int(o, KEY_ISO_DAY);
    ey: int = _get_int(other, KEY_ISO_YEAR);
    em: int = _get_int(other, KEY_ISO_MONTH);
    ed: int = _get_int(other, KEY_ISO_DAY);
    cal: str = _get_str_cal(o);
    # GetDifferenceSettings (unit group "date"): reads largestUnit, roundingIncrement,
    # roundingMode, smallestUnit in ALPHABETICAL order, then validates.
    sett: list[str] = temporal_read_difference_settings(opts, "day", "day", "date");
    if vm_has_native_exc() {
        return js_undefined();
    }
    if flip_mode {
        sett[3] = negate_rounding_mode_string(sett[3]);
    }
    largest: str = sett[0];
    smallest: str = sett[1];
    parts: list[int] = calendar_date_until(oy, om, od, ey, em, ed, cal, largest);
    raw: list[float] = dur_from_components(
        float(parts[0]),
        float(parts[1]),
        float(parts[2]),
        float(parts[3]),
        0.0,
        0.0,
        0.0,
        0.0
    );
    dur: list[float] = temporal_apply_difference_rounding_resolved(
        dur_balance(raw),
        opts,
        largest,
        smallest,
        True,
        oy,
        om,
        od,
        0,
        0,
        0,
        0,
        int(sett[2]),
        rounding_mode_from_string(sett[3])
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(dur);
}

def:pub js_PlainDate_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainDate.since requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # since rounds the NEGATED difference: until with a flipped roundingMode, then negate.
    until_v: JSValue = _pd_until_core(this_val, args, True);
    if vm_has_native_exc() {
        return js_undefined();
    }
    neg: list[float] = dur_negate(ToTemporalDurationValue(until_v));
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(neg);
}

def:pub js_PlainDate_toPlainDateTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    cal: str = _get_str_cal(o);
    h: int = 0;
    mi: int = 0;
    s: int = 0;
    ns: int = 0;
    # An undefined argument gives midnight; otherwise ToTemporalTime(arg) reads the time
    # fields observably in alphabetical order (order-of-operations).
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
    if not iso_validate_datetime_within_limits(y, m, d, h, mi, s, ns) {
        vm_throw_native(make_range_error("date-time out of range"));
        return js_undefined();
    }
    return js_plain_datetime_create(y, m, d, h, mi, s, ns, cal);
}

def:pub js_PlainDate_toZonedDateTime(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("toZonedDateTime requires 1 argument"));
        return js_undefined();
    }
    y: int = _get_int(o, KEY_ISO_YEAR);
    m: int = _get_int(o, KEY_ISO_MONTH);
    d: int = _get_int(o, KEY_ISO_DAY);
    cal: str = _get_str_cal(o);
    h: int = 0;
    mi: int = 0;
    s: int = 0;
    ns: int = 0;
    tz: str = "";
    item: JSValue = args[0];
    time_arg: JSValue = js_undefined();
    if len(args) > 1 {
        time_arg = args[1];
    }
    if jsv_is_object_cell(item) and not js_is_zoned_datetime(item) {
        # An options-bag form { timeZone, plainTime }: read timeZone OBSERVABLY, then
        # plainTime, then ToTemporalTime(plainTime) for the observable time-field reads
        # (order-of-operations: get item.timeZone, get item.plainTime, then its fields).
        tzv: JSValue = js_object_get_observable(item, str_intern("timeZone"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        tz = ToTemporalTimeZoneIdentifier(tzv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        ptv: JSValue = js_object_get_observable(item, str_intern("plainTime"), item);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not jsv_is_undefined(ptv) {
            pt: JSValue = ToTemporalTime(ptv, js_undefined());
            if vm_has_native_exc() {
                return js_undefined();
            }
            h = _get_int(pt, KEY_ISO_HOUR);
            mi = _get_int(pt, KEY_ISO_MINUTE);
            s = _get_int(pt, KEY_ISO_SECOND);
            ns = _get_int(pt, KEY_ISO_NANOSECOND);
        }
    } else {
        tz = ToTemporalTimeZoneIdentifier(item);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(time_arg) {
        pt2: JSValue = ToTemporalTime(time_arg, js_undefined());
        if vm_has_native_exc() {
            return js_undefined();
        }
        h = _get_int(pt2, KEY_ISO_HOUR);
        mi = _get_int(pt2, KEY_ISO_MINUTE);
        s = _get_int(pt2, KEY_ISO_SECOND);
        ns = _get_int(pt2, KEY_ISO_NANOSECOND);
    }
    off_ns: int = temporal_offset_ns_for_zone(tz, y, m, d, h, mi, s);
    # Reject when the combined date+time+offset lands outside the ±8.64e21 ns Instant
    # range (PlainDate at the ISO date limits shifted by the offset).
    temporal_reject_epoch_ns_out_of_range(
        temporal_local_epoch_ns(y, m, d, h, mi, s, ns, off_ns)
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_zoned_datetime_create(y, m, d, h, mi, s, ns, tz, off_ns, cal);
}

def:pub js_PlainDate_toPlainYearMonth(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    return js_plain_year_month_create(
        _get_int(o, KEY_ISO_YEAR), _get_int(o, KEY_ISO_MONTH), _get_str_cal(o)
    );
}

def:pub js_PlainDate_toPlainMonthDay(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    return js_plain_month_day_create(
        _get_int(o, KEY_ISO_MONTH),
        _get_int(o, KEY_ISO_DAY),
        _get_int(o, KEY_ISO_YEAR),
        _get_str_cal(o)
    );
}

def:pub js_PlainDate_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    opts: JSValue = js_undefined();
    if len(args) >= 1 {
        opts = args[0];
    }
    cal_name: str = temporal_get_calendar_name(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    s: str = iso_format_date(
        _get_int(o, KEY_ISO_YEAR), _get_int(o, KEY_ISO_MONTH), _get_int(o, KEY_ISO_DAY)
    );
    s = s + temporal_format_calendar_suffix(_get_str_cal(o), cal_name);
    return jsv_from_string_id(str_intern(s));
}

def:pub js_PlainDate_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options — it calls TemporalDateToString with a fixed "auto"
    # calendarName and must not read anything off its argument (toJSON/basic passes a
    # throwing Proxy). Forwarding args would trip the observable calendarName read.
    empty_args: list[JSValue] = [];
    return js_PlainDate_toString(this_val, empty_args);
}

def:pub js_PlainDate_toLocaleString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toLocaleString(locales, options) has a DIFFERENT signature than
    # toString(options): its args are Intl locale/format options, NOT Temporal
    # toString options (calendarName/etc). Forwarding args to toString mis-validates
    # them (`{ dateStyle: "short" }` → "invalid options"). Without an Intl backend we
    # produce the default ISO string, ignoring the locale args.
    empty_args: list[JSValue] = [];
    return js_PlainDate_toString(this_val, empty_args);
}

def:pub js_PlainDate_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_PlainDate_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    if len(args) < 1 {
        return js_boolean(False);
    }
    other: JSValue = ToTemporalDate(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_boolean(False);
    }
    eq: bool = _get_int(o, KEY_ISO_YEAR) == _get_int(other, KEY_ISO_YEAR);
    eq = eq and _get_int(o, KEY_ISO_MONTH) == _get_int(other, KEY_ISO_MONTH);
    eq = eq and _get_int(o, KEY_ISO_DAY) == _get_int(other, KEY_ISO_DAY);
    eq = eq and _get_str_cal(o) == _get_str_cal(other);
    return js_boolean(eq);
}

def:pub js_PlainDate_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_date(this_val);
    return temporal_plain_date_getter(o, temporal_callee_name());
}
