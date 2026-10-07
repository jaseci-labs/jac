"""Temporal.PlainTime built-in."""

import from engine.src.vm.vm_obs { js_object_get_observable, js_to_number_observable }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_boolean,
    js_number,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_double,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_parse {
    parse_iso_date_time,
    PR_OK,
    PR_HOUR,
    PR_MINUTE,
    PR_SECOND,
    PR_NANOSECOND,
    PR_HAS_TIME,
    PR_CALENDAR
}
import from engine.src.runtime.temporal_iso {
    iso_format_time,
    iso_add_time,
    iso_total_nanoseconds
}
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_balance,
    dur_total,
    dur_round,
    DUR_HOURS,
    DUR_MINUTES,
    DUR_SECONDS,
    DUR_NANOSECONDS,
    DUR_SIGN,
    dur_validate_rounding_increment,
    rounding_mode_from_string
}
import from engine.src.builtins.temporal {
    js_plain_time_create,
    js_this_plain_time,
    js_is_plain_time,
    js_is_any_temporal_object,
    js_plain_time_init,
    js_is_duration,
    js_duration_create,
    js_duration_read,
    temporal_to_string,
    temporal_parse_calendar,
    temporal_reject_time,
    temporal_plain_time_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    ToTemporalTime,
    temporal_get_rounding_mode,
    temporal_get_round_rounding_mode,
    temporal_get_smallest_unit,
    temporal_get_smallest_unit_required,
    temporal_get_rounding_increment,
    temporal_instant_round_max_increment,
    temporal_require_options_object,
    temporal_round_options_from_arg,
    temporal_get_largest_unit,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    temporal_get_overflow,
    temporal_apply_difference_rounding,
    temporal_format_calendar_suffix,
    temporal_get_calendar,
    temporal_format_time_to_string,
    KEY_ISO_HOUR,
    KEY_ISO_MINUTE,
    KEY_ISO_SECOND,
    KEY_ISO_NANOSECOND,
    KEY_CALENDAR
}
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }

def:priv _pt_get_int(o: JSValue, key: int) -> int {
    v: JSValue = js_object_get(o, key);
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def:priv _pt_to_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

# ToIntegerWithTruncation for a property-bag field (observable valueOf, truncate).
def:priv _pt_field_int(v: JSValue) -> int {
    n: float = js_to_number_observable(v);
    if vm_has_native_exc() {
        return 0;
    }
    if n != n or n == n + 1.0 {
        vm_throw_native(make_range_error("invalid time field"));
        return 0;
    }
    return int(n);
}

def:pub js_Temporal_PlainTime(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # Spec signature: PlainTime(hour, minute, second, millisecond, microsecond,
    # nanosecond). PlainTime carries NO calendar — every positional argument is a
    # time component; the fractional-second args (ms/µs/ns) fold into a single ns
    # value. ES §sec-temporal.plaintime.
    h: int = 0;
    mi: int = 0;
    s: int = 0;
    ms: int = 0;
    us: int = 0;
    nsp: int = 0;
    # Args are ToIntegerWithTruncation: coerce observably, reject non-finite, stop at
    # the first bad arg (infinity-throws-rangeerror / constructor order-of-operations).
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        h = _pt_field_int(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 1 and not jsv_is_undefined(args[1]) {
        mi = _pt_field_int(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 2 and not jsv_is_undefined(args[2]) {
        s = _pt_field_int(args[2]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 3 and not jsv_is_undefined(args[3]) {
        ms = _pt_field_int(args[3]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 4 and not jsv_is_undefined(args[4]) {
        us = _pt_field_int(args[4]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 5 and not jsv_is_undefined(args[5]) {
        nsp = _pt_field_int(args[5]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # RejectTime range-checks each sub-second field independently (0-999), so
    # validate before folding — otherwise ms=1000 would masquerade as a valid ns.
    if ms < 0 or ms > 999 or us < 0 or us > 999 or nsp < 0 or nsp > 999 {
        vm_throw_native(make_range_error("invalid time"));
        return js_undefined();
    }
    ns: int = ms * 1000000 + us * 1000 + nsp;
    cal: str = "iso8601";
    temporal_reject_time(h, mi, s, ns);
    if jsv_is_object_cell(this_val) and jsv_to_table_id(this_val) > 0 {
        return js_plain_time_init(this_val, h, mi, s, ns, cal);
    }
    return js_plain_time_create(h, mi, s, ns, cal);
}

def:pub js_Temporal_PlainTime_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainTime.from requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    if js_is_plain_time(args[0]) {
        # Even when the argument is already a PlainTime, the `overflow` option is still
        # read + validated (§Temporal.PlainTime.from — overflow-wrong-type/-invalid-string).
        _ = temporal_get_overflow(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # from returns a fresh CreateTemporalTime, NOT the same object (from(pt) !== pt).
        return js_plain_time_create(
            _pt_get_int(args[0], KEY_ISO_HOUR),
            _pt_get_int(args[0], KEY_ISO_MINUTE),
            _pt_get_int(args[0], KEY_ISO_SECOND),
            _pt_get_int(args[0], KEY_ISO_NANOSECOND),
            temporal_get_calendar(args[0])
        );
    }
    return ToTemporalTime(args[0], opts);
}

def:pub js_Temporal_PlainTime_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("PlainTime.compare requires 2 arguments"));
        return js_undefined();
    }
    a: JSValue = ToTemporalTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    b: JSValue = ToTemporalTime(args[1], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    t1: int = iso_total_nanoseconds(
        _pt_get_int(a, KEY_ISO_HOUR),
        _pt_get_int(a, KEY_ISO_MINUTE),
        _pt_get_int(a, KEY_ISO_SECOND),
        _pt_get_int(a, KEY_ISO_NANOSECOND)
    );
    t2: int = iso_total_nanoseconds(
        _pt_get_int(b, KEY_ISO_HOUR),
        _pt_get_int(b, KEY_ISO_MINUTE),
        _pt_get_int(b, KEY_ISO_SECOND),
        _pt_get_int(b, KEY_ISO_NANOSECOND)
    );
    if t1 < t2 {
        return js_int(-1);
    }
    if t1 > t2 {
        return js_int(1);
    }
    return js_int(0);
}

def:pub js_PlainTime_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainTime.add requires 1 argument"));
        return js_undefined();
    }
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    sign: int = 1;
    if dur[DUR_SIGN] < 0 {
        sign = -1;
    }
    at: list[int] = iso_add_time(
        _pt_get_int(o, KEY_ISO_HOUR),
        _pt_get_int(o, KEY_ISO_MINUTE),
        _pt_get_int(o, KEY_ISO_SECOND),
        _pt_get_int(o, KEY_ISO_NANOSECOND),
        int(dur[DUR_HOURS]) * sign,
        int(dur[DUR_MINUTES]) * sign,
        int(dur[DUR_SECONDS]) * sign,
        int(dur[DUR_NANOSECONDS]) * sign
    );
    return js_plain_time_create(
        at[1], at[2], at[3], at[4], temporal_to_string(js_object_get(o, KEY_CALENDAR))
    );
}

def:pub js_PlainTime_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur[DUR_SIGN] = -dur[DUR_SIGN];
    return js_PlainTime_add(o, [js_duration_create(dur)]);
}

def:pub js_PlainTime_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("PlainTime.with requires an object"));
        return js_undefined();
    }
    h: int = _pt_get_int(o, KEY_ISO_HOUR);
    mi: int = _pt_get_int(o, KEY_ISO_MINUTE);
    s: int = _pt_get_int(o, KEY_ISO_SECOND);
    ns: int = _pt_get_int(o, KEY_ISO_NANOSECOND);
    fields: JSValue = args[0];
    # A PlainTime fields bag carries only time fields. RejectObjectWithCalendarOrTimeZone:
    # a Temporal object, or a bag with a `calendar`/`timeZone` property, is a TypeError.
    # calendar/timeZone are read OBSERVABLY first; the six time fields then follow in
    # ALPHABETICAL order (hour, microsecond, millisecond, minute, nanosecond, second),
    # each coerced immediately. See js_engine-temporal-with-template.
    if js_is_any_temporal_object(fields) {
        vm_throw_native(
            make_type_error("PlainTime.with: argument must be a plain object")
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
        vm_throw_native(make_type_error("PlainTime.with accepts only time fields"));
        return js_undefined();
    }
    seen: bool = False;
    cur_ms: int = ns // 1000000;
    cur_us: int = (ns // 1000) % 1000;
    cur_ns: int = ns % 1000;
    hv: JSValue = js_object_get_observable(fields, str_intern("hour"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(hv) {
        h = _pt_field_int(hv);
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
        cur_us = _pt_field_int(usv);
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
        cur_ms = _pt_field_int(msv);
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
        mi = _pt_field_int(miv);
        if vm_has_native_exc() {
            return js_undefined();
        }
        seen = True;
    }
    nsv: JSValue = js_object_get_observable(fields, str_intern("nanosecond"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(nsv) {
        cur_ns = _pt_field_int(nsv);
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
        s = _pt_field_int(sv);
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
    # overflow option is read + validated (§Temporal.PlainTime.prototype.with).
    ov: str = "constrain";
    if len(args) > 1 {
        ov = temporal_get_overflow(args[1]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if ov == "constrain" {
        if h > 23 {
            h = 23;
        }
        if h < 0 {
            h = 0;
        }
        if mi > 59 {
            mi = 59;
        }
        if mi < 0 {
            mi = 0;
        }
        if s > 59 {
            s = 59;
        }
        if s < 0 {
            s = 0;
        }
        if ns > 999999999 {
            ns = 999999999;
        }
        if ns < 0 {
            ns = 0;
        }
    } else {
        # Under overflow:"reject" each SUB-SECOND field is range-checked individually
        # (0-999) — a folded ns would let millisecond/microsecond 1000 masquerade as a
        # valid nanosecond count (with({microsecond:1000}) must throw).
        if cur_ms < 0
            or cur_ms > 999
            or cur_us < 0
            or cur_us > 999
            or cur_ns < 0
            or cur_ns > 999 {
            vm_throw_native(make_range_error("invalid time"));
            return js_undefined();
        }
        temporal_reject_time(h, mi, s, ns);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    return js_plain_time_create(
        h, mi, s, ns, temporal_to_string(js_object_get(o, KEY_CALENDAR))
    );
}

def:pub js_PlainTime_round(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    # round(roundTo): a missing/undefined roundTo is a TypeError (§step 3).
    if len(args) < 1 or jsv_is_undefined(args[0]) {
        vm_throw_native(make_type_error("PlainTime.round requires a roundTo argument"));
        return js_undefined();
    }
    opts: JSValue = args[0];
    opts = temporal_round_options_from_arg(opts);
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Options are read in alphabetical key order (roundingIncrement, roundingMode,
    # smallestUnit) and ALL reads complete before any algorithmic validation of their
    # values — the increment-vs-unit check fires only afterward
    # (§Temporal.PlainTime.prototype.round order-of-operations).
    increment: int = temporal_get_rounding_increment(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    mode: int = temporal_get_round_rounding_mode(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # smallestUnit is REQUIRED for round — absent → RangeError (empty options object).
    unit: str = temporal_get_smallest_unit_required(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # PlainTime.round accepts only TIME units — a calendar unit (year/month/week/day) is a
    # RangeError (there is no date component to round).
    if unit != "hour"
        and unit != "minute"
        and unit != "second"
        and unit != "millisecond"
        and unit != "microsecond"
        and unit != "nanosecond" {
        vm_throw_native(
            make_range_error('"' + unit + '" is not a valid value for smallest unit')
        );
        return js_undefined();
    }
    dur_validate_rounding_increment(
        increment, temporal_instant_round_max_increment(unit), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    total_ns: int = iso_total_nanoseconds(
        _pt_get_int(o, KEY_ISO_HOUR),
        _pt_get_int(o, KEY_ISO_MINUTE),
        _pt_get_int(o, KEY_ISO_SECOND),
        _pt_get_int(o, KEY_ISO_NANOSECOND)
    );
    dur: list[float] = dur_from_components(
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, float(total_ns)
    );
    rounded: list[float] = dur_round(dur, unit, increment, mode);
    ns: float = dur_total(rounded, "nanoseconds");
    h: int = int(ns) // 3600000000000;
    rem: int = int(ns) % 3600000000000;
    mi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    s: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    return js_plain_time_create(h % 24, mi, s, n, temporal_get_calendar(o));
}

def:priv _pt_duration_between(
    h1: int, mi1: int, s1: int, ns1: int, h2: int, mi2: int, s2: int, ns2: int
) -> list[float] {
    t1: int = iso_total_nanoseconds(h1, mi1, s1, ns1);
    t2: int = iso_total_nanoseconds(h2, mi2, s2, ns2);
    # DifferenceTime returns a SIGNED value in (-1 day, +1 day). It must NOT wrap a
    # negative diff into the positive clock cycle — PlainTime.until/since produce signed
    # durations (later.until(earlier) is negative), not a wall-clock delta.
    diff: int = t2 - t1;
    sgn: float = 1.0;
    if diff < 0 {
        sgn = -1.0;
        diff = -diff;
    }
    h: int = diff // 3600000000000;
    rem: int = diff % 3600000000000;
    mi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    sc: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    dur: list[float] = dur_from_components(
        0.0,
        0.0,
        0.0,
        0.0,
        float(h) * sgn,
        float(mi) * sgn,
        float(sc) * sgn,
        float(n) * sgn
    );
    return dur_balance(dur);
}

def:pub js_PlainTime_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainTime.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` is converted BEFORE the options object is validated (a primitive options
    # value still throws TypeError, but only after other's fields are read — the
    # difference-settings reader validates options via its getters). §since/until.
    other: JSValue = ToTemporalTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    oh: int = _pt_get_int(o, KEY_ISO_HOUR);
    omi: int = _pt_get_int(o, KEY_ISO_MINUTE);
    os: int = _pt_get_int(o, KEY_ISO_SECOND);
    ons: int = _pt_get_int(o, KEY_ISO_NANOSECOND);
    raw: list[float] = _pt_duration_between(
        oh,
        omi,
        os,
        ons,
        _pt_get_int(other, KEY_ISO_HOUR),
        _pt_get_int(other, KEY_ISO_MINUTE),
        _pt_get_int(other, KEY_ISO_SECOND),
        _pt_get_int(other, KEY_ISO_NANOSECOND)
    );
    sett: list[str] = temporal_read_difference_settings(
        opts, "hour", "nanosecond", "time"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur: list[float] = temporal_apply_difference_rounding_resolved(
        raw,
        opts,
        sett[0],
        sett[1],
        False,
        1970,
        1,
        1,
        oh,
        omi,
        os,
        ons,
        int(sett[2]),
        rounding_mode_from_string(sett[3])
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(dur);
}

def:pub js_PlainTime_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("PlainTime.since requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` is converted BEFORE the options object is validated (a primitive options
    # value still throws TypeError, but only after other's fields are read — the
    # difference-settings reader validates options via its getters). §since/until.
    other: JSValue = ToTemporalTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_undefined();
    }
    oh: int = _pt_get_int(o, KEY_ISO_HOUR);
    omi: int = _pt_get_int(o, KEY_ISO_MINUTE);
    os: int = _pt_get_int(o, KEY_ISO_SECOND);
    ons: int = _pt_get_int(o, KEY_ISO_NANOSECOND);
    eh: int = _pt_get_int(other, KEY_ISO_HOUR);
    emi: int = _pt_get_int(other, KEY_ISO_MINUTE);
    es: int = _pt_get_int(other, KEY_ISO_SECOND);
    ens: int = _pt_get_int(other, KEY_ISO_NANOSECOND);
    raw: list[float] = _pt_duration_between(eh, emi, es, ens, oh, omi, os, ons);
    sett: list[str] = temporal_read_difference_settings(
        opts, "hour", "nanosecond", "time"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur: list[float] = temporal_apply_difference_rounding_resolved(
        raw,
        opts,
        sett[0],
        sett[1],
        False,
        1970,
        1,
        1,
        eh,
        emi,
        es,
        ens,
        int(sett[2]),
        rounding_mode_from_string(sett[3])
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(dur);
}

def:pub js_PlainTime_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    if len(args) < 1 {
        return js_boolean(False);
    }
    other: JSValue = ToTemporalTime(args[0], js_undefined());
    if vm_has_native_exc() {
        return js_boolean(False);
    }
    eq: bool = _pt_get_int(o, KEY_ISO_HOUR) == _pt_get_int(other, KEY_ISO_HOUR);
    eq = eq and _pt_get_int(o, KEY_ISO_MINUTE) == _pt_get_int(other, KEY_ISO_MINUTE);
    eq = eq and _pt_get_int(o, KEY_ISO_SECOND) == _pt_get_int(other, KEY_ISO_SECOND);
    eq = eq
        and _pt_get_int(o, KEY_ISO_NANOSECOND)
            == _pt_get_int(other, KEY_ISO_NANOSECOND);
    return js_boolean(eq);
}

def:pub js_PlainTime_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    s: str = temporal_format_time_to_string(
        _pt_get_int(o, KEY_ISO_HOUR),
        _pt_get_int(o, KEY_ISO_MINUTE),
        _pt_get_int(o, KEY_ISO_SECOND),
        _pt_get_int(o, KEY_ISO_NANOSECOND),
        opts
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    s = s
        + temporal_format_calendar_suffix(
            temporal_to_string(js_object_get(o, KEY_CALENDAR)), "auto"
        );
    return jsv_from_string_id(str_intern(s));
}

def:pub js_PlainTime_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options — ignore the argument (call toString with defaults).
    empty_args: list[JSValue] = [];
    return js_PlainTime_toString(this_val, empty_args);
}

def:pub js_PlainTime_toLocaleString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_PlainTime_toString(this_val, args);
}

def:pub js_PlainTime_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_PlainTime_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_plain_time(this_val);
    return temporal_plain_time_getter(o, temporal_callee_name());
}
