"""Temporal.Duration built-in."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_number,
    js_boolean,
    jsv_from_string_id,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_to_double,
    jsv_is_double,
    jsv_to_table_id,
    jsv_to_int32,
    jsv_is_int32,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_symbol,
    jsv_is_bigint_cell,
    jsv_is_any_object,
    jsv_is_object_cell
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_set,
    js_object_create,
    js_object_create_null
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
import from engine.src.runtime.temporal_parse {
    parse_duration,
    PR_OK,
    PR_IS_DURATION,
    PR_DUR_YEARS,
    PR_DUR_MONTHS,
    PR_DUR_WEEKS,
    PR_DUR_DAYS,
    PR_DUR_HOURS,
    PR_DUR_MINUTES,
    PR_DUR_SECONDS,
    PR_DUR_NANOS,
    PR_IS_NEGATIVE
}
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_add,
    dur_subtract,
    dur_negate,
    dur_balance,
    dur_balance_time,
    dur_balance_time,
    dur_compare,
    dur_compare_relative,
    dur_identical,
    dur_needs_relative_to,
    dur_to_string,
    dur_total,
    dur_total_relative,
    dur_round,
    dur_round_with_anchor,
    dur_round_duration,
    dur_empty,
    dur_sign,
    dur_is_zero,
    dur_validate_sign,
    dur_default_largest_unit,
    dur_larger_unit,
    dur_is_calendar_unit,
    dur_max_rounding_increment,
    dur_validate_rounding_increment,
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
    ROUND_TRUNC,
    ROUND_HALF_EXPAND
}
import from engine.src.builtins.temporal {
    js_duration_create,
    js_duration_read,
    js_this_duration,
    js_is_duration,
    js_duration_init,
    js_duration_init_explicit,
    js_duration_create_unbalanced_subseconds,
    _dur_split_subsecond,
    js_is_plain_date,
    js_is_plain_datetime,
    js_is_zoned_datetime,
    temporal_to_string,
    temporal_throw_valueof,
    temporal_get_rounding_mode,
    temporal_get_smallest_unit,
    temporal_require_options_object,
    temporal_get_total_unit,
    temporal_get_total_unit_observable,
    temporal_get_unit_from_string_arg,
    temporal_get_rounding_increment,
    temporal_format_duration_to_string,
    temporal_callee_name,
    ToTemporalDate,
    GetTemporalRelativeToAnchor,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_ISO_HOUR,
    KEY_ISO_MINUTE,
    KEY_ISO_SECOND,
    KEY_ISO_NANOSECOND,
    _DUR_PROTO
}
import from engine.src.builtins.string { js_coerce_to_string }

def _num(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    return jsv_to_double(v);
}

def _round_half_expand_ns(v: float) -> int {
    if v >= 0.0 {
        return int(v + 0.5);
    }
    return int(v - 0.5);
}

def _dur_float_abs(v: float) -> float {
    if v < 0.0 {
        return -v;
    }
    return v;
}

# Combine ms/µs/ns into total nanoseconds in FLOAT space. A large millisecond field
# (e.g. 1.8e13 ms) makes ms*1e6 exceed i64 (2^63); the native int multiply overflows
# and crashes, so the fold must be float (the Duration stores subsecond ns as a float
# anyway). Precision loss above 2^53 is spec-accepted for out-of-safe-range durations.
def _duration_combine_subsecond_ns(ms: float, us: float, ns: float) -> float {
    return ms * 1000000.0 + us * 1000.0 + ns;
}

def _duration_seconds_overflow_int(s: int, ms: int, us: int, ns: int) -> bool {
    lim_s: int = 9007199254740992;
    a_s: int = s;
    if a_s < 0 {
        a_s = -a_s;
    }
    ams: int = ms;
    if ams < 0 {
        ams = -ams;
    }
    aus: int = us;
    if aus < 0 {
        aus = -aus;
    }
    ans: int = ns;
    if ans < 0 {
        ans = -ans;
    }
    # Avoid i64 overflow: ms*1e6/1e9 == ms//1000 with remainder folded into sub-ns.
    carry_ms: int = ams // 1000;
    rem_ms: int = ams % 1000;
    sub: int = rem_ms * 1000000 + aus * 1000 + ans;
    carry_sub: int = sub // 1000000000;
    total: int = a_s + carry_ms + carry_sub;
    if total >= lim_s {
        return True;
    }
    return False;
}

def _reject_constructor_time_overflow(s: int, ms: int, us: int, ns: int) -> None {
    if _duration_seconds_overflow_int(s, ms, us, ns) {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
}

def _duration_seconds_overflow(sec: float, nanos: float) -> bool {
    lim_s: int = 9007199254740992;
    bs: int = int(sec);
    bn: int = int(nanos);
    if bn >= 1000000000 {
        carry: int = bn // 1000000000;
        bs = bs + carry;
    }
    if bs >= lim_s {
        return True;
    }
    return False;
}

def _duration_from_parse(pr: list[any]) -> list[float] {
    sign: float = 1.0;
    if pr[PR_IS_NEGATIVE] != 0 {
        sign = -1.0;
    }
    # The PR_DUR_* slots always hold floats (parse_empty_result, parse_duration),
    # so read them through a float-typed binding: that unboxes natively, while
    # float() of a list[any] element has no native lowering. A typed read does
    # not convert, so a slot must never hold an int here.
    y: float = pr[PR_DUR_YEARS];
    mo: float = pr[PR_DUR_MONTHS];
    w: float = pr[PR_DUR_WEEKS];
    d: float = pr[PR_DUR_DAYS];
    h: float = pr[PR_DUR_HOURS];
    mi: float = pr[PR_DUR_MINUTES];
    s: float = pr[PR_DUR_SECONDS];
    ns: float = 0.0;
    if len(pr) > PR_DUR_NANOS {
        ns = pr[PR_DUR_NANOS];
    }
    dur2: list[float] = dur_from_components(
        y * sign,
        mo * sign,
        w * sign,
        d * sign,
        h * sign,
        mi * sign,
        s * sign,
        ns * sign
    );
    _reject_duration_out_of_range(dur2);
    if vm_has_native_exc() {
        return dur_empty();
    }
    _reject_duration_out_of_range(dur2);
    if vm_has_native_exc() {
        return dur_empty();
    }
    return dur2;
}

def:pub js_Temporal_Duration(this_val: JSValue, args: list[JSValue]) -> JSValue {
    y: float = 0.0;
    mo: float = 0.0;
    w: float = 0.0;
    d: float = 0.0;
    h: float = 0.0;
    mi: float = 0.0;
    s: float = 0.0;
    ms: float = 0.0;
    us: float = 0.0;
    ns: float = 0.0;
    if len(args) > 0 {
        if not jsv_is_undefined(args[0]) {
            y = _ctor_duration_component(args[0]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 1 {
        if not jsv_is_undefined(args[1]) {
            mo = _ctor_duration_component(args[1]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 2 {
        if not jsv_is_undefined(args[2]) {
            w = _ctor_duration_component(args[2]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 3 {
        if not jsv_is_undefined(args[3]) {
            d = _ctor_duration_component(args[3]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 4 {
        if not jsv_is_undefined(args[4]) {
            h = _ctor_duration_component(args[4]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 5 {
        if not jsv_is_undefined(args[5]) {
            mi = _ctor_duration_component(args[5]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 6 {
        if not jsv_is_undefined(args[6]) {
            s = _ctor_duration_component(args[6]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 7 {
        if not jsv_is_undefined(args[7]) {
            ms = _ctor_duration_component(args[7]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 8 {
        if not jsv_is_undefined(args[8]) {
            us = _ctor_duration_component(args[8]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if len(args) > 9 {
        if not jsv_is_undefined(args[9]) {
            ns = _ctor_duration_component(args[9]);
        }
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    _reject_constructor_time_overflow(int(s), int(ms), int(us), int(ns));
    if vm_has_native_exc() {
        return js_undefined();
    }
    sub_ns_f: float = _duration_combine_subsecond_ns(ms, us, ns);
    if not _is_valid_duration_components(
        int(y),
        int(mo),
        int(w),
        int(d),
        int(h),
        int(mi),
        int(s),
        int(ms),
        int(us),
        int(ns)
    ) {
        vm_throw_native(make_range_error("invalid duration"));
        return js_undefined();
    }
    dur: list[float] = dur_from_components(y, mo, w, d, h, mi, s, sub_ns_f);
    _reject_duration_out_of_range(dur);
    if vm_has_native_exc() {
        return js_undefined();
    }
    ams: int = int(ms);
    if ams < 0 {
        ams = -ams;
    }
    aus: int = int(us);
    if aus < 0 {
        aus = -aus;
    }
    ans: int = int(ns);
    if ans < 0 {
        ans = -ans;
    }
    if jsv_is_object_cell(this_val) and jsv_to_table_id(this_val) > 0 {
        return js_duration_init_explicit(
            this_val,
            dur[DUR_YEARS],
            dur[DUR_MONTHS],
            dur[DUR_WEEKS],
            dur[DUR_DAYS],
            dur[DUR_HOURS],
            dur[DUR_MINUTES],
            dur[DUR_SECONDS],
            float(ams),
            float(aus),
            float(ans),
            dur[DUR_SIGN]
        );
    }
    o: JSValue = js_object_create(_DUR_PROTO)
        if jsv_is_object_cell(_DUR_PROTO)
        else js_object_create_null();
    return js_duration_init_explicit(
        o,
        dur[DUR_YEARS],
        dur[DUR_MONTHS],
        dur[DUR_WEEKS],
        dur[DUR_DAYS],
        dur[DUR_HOURS],
        dur[DUR_MINUTES],
        dur[DUR_SECONDS],
        float(ams),
        float(aus),
        float(ans),
        dur[DUR_SIGN]
    );
}

def:priv _dur_slot_int(o: JSValue, key: int) -> int {
    v: JSValue = js_object_get(o, key);
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _to_integer_if_integral(v: JSValue) -> int {
    if jsv_is_symbol(v) or jsv_is_bigint_cell(v) {
        vm_throw_native(make_type_error("cannot convert to number"));
        return 0;
    }
    n: float = js_to_number_observable(v);
    if vm_has_native_exc() {
        return 0;
    }
    if n != float(int(n)) {
        vm_throw_native(make_range_error("non-integer duration component"));
        return 0;
    }
    return int(n);
}

def _ctor_duration_component(v: JSValue) -> float {
    return float(_to_integer_if_integral(v));
}

def _partial_duration_field(o: JSValue, key: str) -> list[any] {
    pv: JSValue = js_object_get_observable(o, str_intern(key), o);
    if vm_has_native_exc() {
        return [-1, 0];
    }
    if jsv_is_undefined(pv) {
        return [0, 0];
    }
    return [1, _to_integer_if_integral(pv)];
}

def _to_temporal_partial_duration(o: JSValue) -> list[any] {
    if not jsv_is_object_cell(o) {
        vm_throw_native(make_type_error("duration must be object"));
        return [];
    }
    dr: list[any] = _partial_duration_field(o, "days");
    if vm_has_native_exc() {
        return [];
    }
    hr: list[any] = _partial_duration_field(o, "hours");
    if vm_has_native_exc() {
        return [];
    }
    us: list[any] = _partial_duration_field(o, "microseconds");
    if vm_has_native_exc() {
        return [];
    }
    ms: list[any] = _partial_duration_field(o, "milliseconds");
    if vm_has_native_exc() {
        return [];
    }
    mi: list[any] = _partial_duration_field(o, "minutes");
    if vm_has_native_exc() {
        return [];
    }
    mo: list[any] = _partial_duration_field(o, "months");
    if vm_has_native_exc() {
        return [];
    }
    ns: list[any] = _partial_duration_field(o, "nanoseconds");
    if vm_has_native_exc() {
        return [];
    }
    sc: list[any] = _partial_duration_field(o, "seconds");
    if vm_has_native_exc() {
        return [];
    }
    wk: list[any] = _partial_duration_field(o, "weeks");
    if vm_has_native_exc() {
        return [];
    }
    yr: list[any] = _partial_duration_field(o, "years");
    if vm_has_native_exc() {
        return [];
    }
    if dr[0] == 0
        and hr[0] == 0
        and us[0] == 0
        and ms[0] == 0
        and mi[0] == 0
        and mo[0] == 0
        and ns[0] == 0
        and sc[0] == 0
        and wk[0] == 0
        and yr[0] == 0 {
        vm_throw_native(make_type_error("missing duration property"));
        return [];
    }
    y: int = 0;
    mo2: int = 0;
    w: int = 0;
    d: int = 0;
    h: int = 0;
    mi2: int = 0;
    s2: int = 0;
    ms2: int = 0;
    us2: int = 0;
    ns2: int = 0;
    if yr[0] != 0 {
        y = yr[1];
    }
    if mo[0] != 0 {
        mo2 = mo[1];
    }
    if wk[0] != 0 {
        w = wk[1];
    }
    if dr[0] != 0 {
        d = dr[1];
    }
    if hr[0] != 0 {
        h = hr[1];
    }
    if mi[0] != 0 {
        mi2 = mi[1];
    }
    if sc[0] != 0 {
        s2 = sc[1];
    }
    if ms[0] != 0 {
        ms2 = ms[1];
    }
    if us[0] != 0 {
        us2 = us[1];
    }
    if ns[0] != 0 {
        ns2 = ns[1];
    }
    # Return a HOMOGENEOUS list[int] of the 10 integral components. Appending the
    # float `sub_ns` here made a mixed int/float list, which the native typed-list
    # representation reads back as garbage (heterogeneous-list corruption) — the
    # caller recomputes sub_ns from the int fields instead.
    return [y, mo2, w, d, h, mi2, s2, ms2, us2, ns2];
}

def _is_valid_duration_components(
    y: int, mo: int, w: int, d: int, h: int, mi: int, s: int, ms: int, us: int, ns: int
) -> bool {
    sign: int = 0;
    vals: list[any] = [y, mo, w, d, h, mi, s, ms, us, ns];
    i: int = 0;
    while i < len(vals) {
        v: int = vals[i];
        if v < 0 {
            if sign > 0 {
                return False;
            }
            sign = -1;
        } elif v > 0 {
            if sign < 0 {
                return False;
            }
            sign = 1;
        }
        i = i + 1;
    }
    return True;
}

def _reject_duration_time_overflow(d: list[float]) -> None {
    lim_h_out: float = 2501999792984.0;
    lim_mi_out: float = 150119987579017.0;
    lim_s_out: float = 9007199254740992.0;
    ah: float = _dur_float_abs(d[DUR_HOURS]);
    am: float = _dur_float_abs(d[DUR_MINUTES]);
    sec_v: float = _dur_float_abs(d[DUR_SECONDS]);
    ns_v: float = _dur_float_abs(d[DUR_NANOSECONDS]);
    if ah + am / 60.0 + sec_v / 3600.0 + ns_v / 3600000000000.0 >= lim_h_out {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
    if am + sec_v / 60.0 + ns_v / 60000000000.0 >= lim_mi_out {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
    if _duration_seconds_overflow(sec_v, ns_v) {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
}


def _reject_duration_out_of_range(d: list[float]) -> None {
    lim_ymw: float = 4294967296.0;
    lim_d_out: float = 104249991375.0;
    lim_h_out: float = 2501999792984.0;
    lim_mi_out: float = 150119987579017.0;
    lim_s_out: float = 9007199254740992.0;
    if _dur_float_abs(d[DUR_YEARS]) >= lim_ymw
        or _dur_float_abs(d[DUR_MONTHS]) >= lim_ymw
        or _dur_float_abs(d[DUR_WEEKS]) >= lim_ymw {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
    if _dur_float_abs(d[DUR_DAYS]) >= lim_d_out
        or _dur_float_abs(d[DUR_HOURS]) >= lim_h_out
        or _dur_float_abs(d[DUR_MINUTES]) >= lim_mi_out
        or _dur_float_abs(d[DUR_SECONDS]) >= lim_s_out {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
    _reject_duration_time_overflow(d);
    if vm_has_native_exc() {
        return;
    }
    bt: list[float] = dur_balance_time(d);
    _reject_duration_time_overflow(bt);
    if vm_has_native_exc() {
        return;
    }
}

def:pub temporal_validate_duration(d: list[float]) -> None {
    if not dur_validate_sign(d) {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
    _reject_duration_out_of_range(d);
}

def:pub temporal_duration_post_arithmetic(d: list[float]) -> list[float] {
    b: list[float] = dur_balance(d);
    temporal_validate_duration(b);
    if vm_has_native_exc() {
        return dur_empty();
    }
    return b;
}

def:pub ToTemporalDurationValue(item: JSValue) -> list[float] {
    if js_is_duration(item) {
        return js_duration_read(item);
    }
    if not jsv_is_object_cell(item) {
        if not jsv_is_string_cell(item) {
            vm_throw_native(make_type_error("duration must be string or object"));
            return dur_empty();
        }
        s: str = temporal_to_string(item);
        pr: list[any] = parse_duration(s);
        if pr[PR_OK] == 0 or pr[PR_IS_DURATION] == 0 {
            vm_throw_native(make_range_error("invalid duration string"));
            return dur_empty();
        }
        return _duration_from_parse(pr);
    }
    parts: list[any] = _to_temporal_partial_duration(item);
    if vm_has_native_exc() or len(parts) == 0 {
        return dur_empty();
    }
    y: int = parts[0];
    mo: int = parts[1];
    w: int = parts[2];
    d: int = parts[3];
    h: int = parts[4];
    mi: int = parts[5];
    s: int = parts[6];
    ms2: int = parts[7];
    us2: int = parts[8];
    ns2: int = parts[9];
    sub_ns: float = float(ms2) * 1000000.0 + float(us2) * 1000.0 + float(ns2);
    if not _is_valid_duration_components(y, mo, w, d, h, mi, s, ms2, us2, ns2) {  # jac:ignore[E1053] pointer reinterpret
        vm_throw_native(make_range_error("invalid duration"));
        return dur_empty();
    }
    out: list[float] = dur_from_components(
        float(y), float(mo), float(w), float(d), float(h), float(mi), float(s), sub_ns
    );
    _reject_duration_out_of_range(out);
    if vm_has_native_exc() {
        return dur_empty();
    }
    return out;
}

def _bad_options_type(v: JSValue) -> bool {
    if jsv_is_undefined(v) {
        return False;
    }
    if jsv_is_object_cell(v) {
        return False;
    }
    return True;
}

def _relative_to_anchor(v: JSValue) -> list[int] {
    return GetTemporalRelativeToAnchor(v);
}

def _temporal_unit_normalize_local(s: str) -> str {
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

def _temporal_unit_name_ok(s: str, allow_auto: bool) -> bool {
    if len(s) == 0 {
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

def _duration_has_date_units(d: list[float]) -> bool {
    return d[DUR_YEARS] != 0.0
        or d[DUR_MONTHS] != 0.0
        or d[DUR_WEEKS] != 0.0
        or d[DUR_DAYS] != 0.0;
}

def _duration_has_calendar_units(d: list[float]) -> bool {
    return d[DUR_YEARS] != 0.0 or d[DUR_MONTHS] != 0.0 or d[DUR_WEEKS] != 0.0;
}

def _duration_total_needs_relative_to(d: list[float], unit: str) -> bool {
    if unit == "year" or unit == "years" {
        return True;
    }
    if unit == "month" or unit == "months" {
        return True;
    }
    if unit == "week" or unit == "weeks" {
        return True;
    }
    if unit == "day" or unit == "days" {
        return _duration_has_calendar_units(d);
    }
    # Time totals still need relativeTo when the duration carries calendar units.
    if _duration_has_calendar_units(d) {
        return True;
    }
    return False;
}

def _needs_zoned_relative_compare(
    relative_to: JSValue, one: list[float], two: list[float]
) -> bool {
    if not js_is_zoned_datetime(relative_to) {
        return False;
    }
    return _duration_has_date_units(one) or _duration_has_date_units(two);
}

def:pub js_Temporal_Duration_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("Duration.compare requires 2 arguments"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 2 {
        opts = args[2];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    one: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    two: list[float] = ToTemporalDurationValue(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    relative_to: JSValue = js_undefined();
    anchor: list[int] = [0, 0, 0, 0, 0, 0, 0];
    has_anchor: bool = False;
    if jsv_is_any_object(opts) {
        relative_to = js_object_get_observable(opts, str_intern("relativeTo"), opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not jsv_is_undefined(relative_to) {
            anchor = _relative_to_anchor(relative_to);
            if vm_has_native_exc() {
                return js_undefined();
            }
            has_anchor = True;
        }
    } elif not jsv_is_undefined(opts) {
        vm_throw_native(make_type_error("options must be object"));
        return js_undefined();
    }
    if dur_identical(one, two) {
        return js_int(0);
    }
    need_rel: bool = dur_needs_relative_to(one, two);
    if not need_rel and has_anchor {
        need_rel = _needs_zoned_relative_compare(relative_to, one, two);
    }
    if need_rel {
        if not has_anchor {
            vm_throw_native(
                make_range_error("cannot compare Duration values without relativeTo")
            );
            return js_undefined();
        }
        cmp: int = dur_compare_relative(
            anchor[0],
            anchor[1],
            anchor[2],
            anchor[3],
            anchor[4],
            anchor[5],
            anchor[6],
            one,
            two
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
        return js_int(cmp);
    }
    return js_int(dur_compare(one, two));
}

def:pub js_Temporal_Duration_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("Duration.from requires 1 argument"));
        return js_undefined();
    }
    a0: JSValue = args[0];
    if js_is_duration(a0) {
        return js_duration_create(js_duration_read(a0));
    }
    if jsv_is_object_cell(a0) {
        d: list[float] = ToTemporalDurationValue(a0);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return js_duration_create(d);
    }
    # ToTemporalDuration: a non-object, non-string argument (undefined, null,
    # boolean, number, bigint, symbol) is a TypeError — only a String is parsed
    # (§ToTemporalDuration). Coercing it to a string would wrongly yield a
    # RangeError instead.
    if not jsv_is_string_cell(a0) {
        vm_throw_native(
            make_type_error("Duration.from: argument must be a string or object")
        );
        return js_undefined();
    }
    s: str = js_coerce_to_string(a0);
    pr: list[any] = parse_duration(s);
    if pr[PR_OK] == 0 or pr[PR_IS_DURATION] == 0 {
        vm_throw_native(make_range_error("invalid duration string"));
        return js_undefined();
    }
    return js_duration_create(_duration_from_parse(pr));
}

def:pub js_Duration_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    self: JSValue = js_this_duration(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Duration.add requires 1 argument"));
        return js_undefined();
    }
    other: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    result: list[float] = temporal_duration_post_arithmetic(
        dur_add(js_duration_read(self), other)
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(result);
}

def:pub js_Duration_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    self: JSValue = js_this_duration(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Duration.subtract requires 1 argument"));
        return js_undefined();
    }
    other: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    result: list[float] = temporal_duration_post_arithmetic(
        dur_subtract(js_duration_read(self), other)
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(result);
}

def:pub js_Duration_negated(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_duration_create(dur_negate(js_duration_read(js_this_duration(this_val))));
}

def:priv _dur_abs_slot(o: JSValue, key: str) -> float {
    v: JSValue = js_object_get(o, str_intern(key));
    if jsv_is_undefined(v) {
        return 0.0;
    }
    x: float = jsv_to_double(v);
    if x < 0.0 {
        return -x;
    }
    return x;
}

def:pub js_Duration_abs(this_val: JSValue, args: list[JSValue]) -> JSValue {
    src: JSValue = js_this_duration(this_val);
    d: list[float] = js_duration_read(src);
    d[DUR_SIGN] = 1.0;
    o: JSValue = js_object_create(_DUR_PROTO)
        if jsv_is_object_cell(_DUR_PROTO)
        else js_object_create_null();
    ms_v: JSValue = js_object_get(src, str_intern("__ms"));
    if jsv_is_undefined(ms_v) {
        return js_duration_create(d);
    }
    return js_duration_init_explicit(
        o,
        d[DUR_YEARS],
        d[DUR_MONTHS],
        d[DUR_WEEKS],
        d[DUR_DAYS],
        d[DUR_HOURS],
        d[DUR_MINUTES],
        d[DUR_SECONDS],
        jsv_to_double(js_object_get(src, str_intern("__ms"))),
        jsv_to_double(js_object_get(src, str_intern("__us"))),
        jsv_to_double(js_object_get(src, str_intern("__ns"))),
        1.0
    );
}

def:pub js_Duration_round(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # Temporal.Duration.prototype.round — option resolution per proposal §7.3.20.
    self: JSValue = js_this_duration(this_val);
    d: list[float] = js_duration_read(self);
    if len(args) < 1 or jsv_is_undefined(args[0]) {
        vm_throw_native(make_type_error("Duration.round requires an argument"));
        return js_undefined();
    }
    opts: JSValue = args[0];
    # String → { smallestUnit: string }
    if jsv_is_string_cell(opts) {
        unit_s: str = temporal_get_unit_from_string_arg(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        opts = js_object_create_null();
        js_object_set(
            opts, str_intern("smallestUnit"), jsv_from_string_id(str_intern(unit_s))
        );
    } else {
        temporal_require_options_object(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Alphabetical option reads (largestUnit, relativeTo, roundingIncrement,
    # roundingMode, smallestUnit) with presence tracking. Use observable Get +
    # ToString so propertyBagObserver order and symbol TypeErrors match the spec.
    smallest_present: bool = True;
    largest_present: bool = True;
    largest: str = "";
    lu_v: JSValue = js_object_get_observable(opts, str_intern("largestUnit"), opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if jsv_is_undefined(lu_v) {
        largest_present = False;
        largest = "";
    } else {
        raw_lu: str = js_to_string_observable(lu_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if raw_lu == "auto" {
            largest = "auto";
        } else {
            largest = _temporal_unit_normalize_local(raw_lu);
            if not _temporal_unit_name_ok(largest, True) {
                vm_throw_native(
                    make_range_error(
                        '"' + raw_lu + '" is not a valid value for largestUnit'
                    )
                );
                return js_undefined();
            }
        }
    }
    # Get relativeTo during alphabetical reads but defer conversion until after
    # all options are cast (spec: read options before algorithmic validation).
    relative_to: JSValue = js_object_get_observable(
        opts, str_intern("relativeTo"), opts
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    increment: int = 1;
    ri_v: JSValue = js_object_get_observable(
        opts, str_intern("roundingIncrement"), opts
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(ri_v) {
        # GetRoundingIncrementOption: ToNumber → truncate → [1, 1e9].
        ri_n: float = js_to_number_observable(ri_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        # NaN / ±Infinity are not valid increments.
        if ri_n != ri_n or ri_n > 1.0e300 or ri_n < -1.0e300 {
            vm_throw_native(make_range_error("invalid roundingIncrement"));
            return js_undefined();
        }
        ri_trunc: int = int(ri_n);
        if ri_n < 0.0 {
            ri_trunc = -int(-ri_n);
        }
        if ri_trunc < 1 or ri_trunc > 1000000000 {
            vm_throw_native(make_range_error("invalid roundingIncrement"));
            return js_undefined();
        }
        increment = ri_trunc;
    }
    mode: int = ROUND_HALF_EXPAND;
    rm_v: JSValue = js_object_get_observable(opts, str_intern("roundingMode"), opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(rm_v) {
        rms: str = js_to_string_observable(rm_v);
        if vm_has_native_exc() {
            return js_undefined();
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
            return js_undefined();
        }
        mode = rounding_mode_from_string(rms);
    }
    smallest: str = "nanosecond";
    su_v: JSValue = js_object_get_observable(opts, str_intern("smallestUnit"), opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if jsv_is_undefined(su_v) {
        smallest_present = False;
        smallest = "nanosecond";
    } else {
        raw_su: str = js_to_string_observable(su_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        smallest = _temporal_unit_normalize_local(raw_su);
        if not _temporal_unit_name_ok(smallest, False) {
            vm_throw_native(
                make_range_error(
                    '"' + raw_su + '" is not a valid value for smallest unit'
                )
            );
            return js_undefined();
        }
    }
    # --- algorithmic validation / relativeTo conversion (after all option casts) ---
    has_anchor: bool = False;
    anchor: list[int] = [0, 0, 0, 0, 0, 0, 0];
    if not jsv_is_undefined(relative_to) {
        anchor = _relative_to_anchor(relative_to);
        if vm_has_native_exc() {
            return js_undefined();
        }
        has_anchor = True;
    }
    existing: str = dur_default_largest_unit(d);
    default_largest: str = dur_larger_unit(existing, smallest);
    if not largest_present {
        largest = default_largest;
    } elif largest == "auto" {
        largest = default_largest;
    }
    if not smallest_present and not largest_present {
        vm_throw_native(make_range_error("smallestUnit or largestUnit is required"));
        return js_undefined();
    }
    if dur_larger_unit(largest, smallest) != largest {
        vm_throw_native(make_range_error("smallestUnit is larger than largestUnit"));
        return js_undefined();
    }
    maximum: int = dur_max_rounding_increment(smallest);
    if maximum >= 0 {
        dur_validate_rounding_increment(increment, maximum, False);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Increment > 1 with date smallestUnit requires largestUnit == smallestUnit
    # (year/month/week/day — TemporalUnitCategory date).
    if increment > 1 and largest != smallest {
        if dur_is_calendar_unit(smallest) or smallest == "day" or smallest == "days" {
            vm_throw_native(
                make_range_error("invalid roundingIncrement for calendar unit")
            );
            return js_undefined();
        }
    }
    # Calendar units in input or largestUnit require relativeTo (plain or zoned).
    if not has_anchor {
        if dur_is_calendar_unit(existing) or dur_is_calendar_unit(largest) {
            vm_throw_native(make_range_error("relativeTo is required"));
            return js_undefined();
        }
    }
    rounded: list[float] = dur_round_duration(
        d,
        smallest,
        largest,
        increment,
        mode,
        has_anchor,
        anchor[0],
        anchor[1],
        anchor[2],
        anchor[3],
        anchor[4],
        anchor[5],
        anchor[6]
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    if largest == "millisecond"
        or largest == "microsecond"
        or largest == "nanosecond" {
        return js_duration_create_unbalanced_subseconds(rounded, largest);
    }
    return js_duration_create(rounded);
}

def:pub js_Duration_with(this_val: JSValue, args: list[JSValue]) -> JSValue {
    self: JSValue = js_this_duration(this_val);
    if len(args) < 1 or not jsv_is_object_cell(args[0]) {
        vm_throw_native(make_type_error("Duration.with requires an object"));
        return js_undefined();
    }
    d: list[float] = js_duration_read(self);
    sgn: int = 1;
    if d[DUR_SIGN] < 0 {
        sgn = -1;
    }
    y: int = int(d[DUR_YEARS]) * sgn;
    mo: int = int(d[DUR_MONTHS]) * sgn;
    w: int = int(d[DUR_WEEKS]) * sgn;
    dy: int = int(d[DUR_DAYS]) * sgn;
    h: int = int(d[DUR_HOURS]) * sgn;
    mi: int = int(d[DUR_MINUTES]) * sgn;
    s: int = int(d[DUR_SECONDS]) * sgn;
    sub_ns: float = d[DUR_NANOSECONDS] * float(sgn);
    fields: JSValue = args[0];
    yv: JSValue = js_object_get_observable(fields, str_intern("years"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    mov: JSValue = js_object_get_observable(fields, str_intern("months"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    wv: JSValue = js_object_get_observable(fields, str_intern("weeks"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    dv: JSValue = js_object_get_observable(fields, str_intern("days"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    hv: JSValue = js_object_get_observable(fields, str_intern("hours"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    miv: JSValue = js_object_get_observable(fields, str_intern("minutes"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    sv: JSValue = js_object_get_observable(fields, str_intern("seconds"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # milliseconds/microseconds/nanoseconds are SEPARATE Duration fields (the object
    # stores them folded into DUR_NANOSECONDS): read the ORIGINAL values by splitting
    # sub_ns, then override each field the caller supplies. (§Duration.with reads all
    # ten fields observably — millisecond/microsecond must not be dropped.)
    msv: JSValue = js_object_get_observable(fields, str_intern("milliseconds"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    usv: JSValue = js_object_get_observable(fields, str_intern("microseconds"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    nsv: JSValue = js_object_get_observable(fields, str_intern("nanoseconds"), fields);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not jsv_is_undefined(yv) {
        y = _to_integer_if_integral(yv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(mov) {
        mo = _to_integer_if_integral(mov);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(wv) {
        w = _to_integer_if_integral(wv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(dv) {
        dy = _to_integer_if_integral(dv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(hv) {
        h = _to_integer_if_integral(hv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(miv) {
        mi = _to_integer_if_integral(miv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(sv) {
        s = _to_integer_if_integral(sv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Split the ORIGINAL sub-second remainder into signed ms/us/ns (keep the sign so an
    # un-overridden field retains the original duration's direction).
    ms_i: int = 0;
    us_i: int = 0;
    ns_i: int = 0;
    if sub_ns != 0.0 {
        ans: int = int(sub_ns);
        ms_i = ans // 1000000;
        rem: int = ans % 1000000;
        us_i = rem // 1000;
        ns_i = rem % 1000;
    }
    if not jsv_is_undefined(msv) {
        ms_i = _to_integer_if_integral(msv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(usv) {
        us_i = _to_integer_if_integral(usv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not jsv_is_undefined(nsv) {
        ns_i = _to_integer_if_integral(nsv);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Recompose the sub-second remainder (in nanoseconds) from the resolved ms/us/ns.
    sub_ns = float(ms_i) * 1000000.0 + float(us_i) * 1000.0 + float(ns_i);
    if not _is_valid_duration_components(y, mo, w, dy, h, mi, s, ms_i, us_i, ns_i) {
        vm_throw_native(make_range_error("invalid duration"));
        return js_undefined();
    }
    out: list[float] = dur_from_components(
        float(y), float(mo), float(w), float(dy), float(h), float(mi), float(s), sub_ns
    );
    temporal_validate_duration(out);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_duration_create(out);
}

def:pub js_Temporal_Duration_max(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("Duration.max requires 2 arguments"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 2 {
        opts = args[2];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    one: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    two: list[float] = ToTemporalDurationValue(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    relative_to: JSValue = js_undefined();
    anchor: list[int] = [0, 0, 0, 0, 0, 0, 0];
    has_anchor: bool = False;
    if jsv_is_any_object(opts) {
        relative_to = js_object_get_observable(opts, str_intern("relativeTo"), opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not jsv_is_undefined(relative_to) {
            anchor = _relative_to_anchor(relative_to);
            if vm_has_native_exc() {
                return js_undefined();
            }
            has_anchor = True;
        }
    } elif not jsv_is_undefined(opts) {
        vm_throw_native(make_type_error("options must be object"));
        return js_undefined();
    }
    if dur_identical(one, two) {
        return js_duration_create(one);
    }
    need_rel: bool = dur_needs_relative_to(one, two);
    if not need_rel and has_anchor {
        need_rel = _needs_zoned_relative_compare(relative_to, one, two);
    }
    cmp: int = 0;
    if need_rel {
        if not has_anchor {
            vm_throw_native(
                make_range_error("cannot compare Duration values without relativeTo")
            );
            return js_undefined();
        }
        cmp = dur_compare_relative(
            anchor[0],
            anchor[1],
            anchor[2],
            anchor[3],
            anchor[4],
            anchor[5],
            anchor[6],
            one,
            two
        );
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        cmp = dur_compare(one, two);
    }
    if cmp >= 0 {
        return js_duration_create(one);
    }
    return js_duration_create(two);
}

def abs(v: float) -> float {
    if v < 0.0 {
        return -v;
    }
    return v;
}

def:priv _dur_signed_field(v: float, sgn: int) -> float {
    r: float = v * float(sgn);
    if r == 0.0 {
        return 0.0;
    }
    return r;
}

def:pub js_Duration_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
        temporal_require_options_object(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    s: str = temporal_format_duration_to_string(
        js_duration_read(js_this_duration(this_val)), opts
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return jsv_from_string_id(str_intern(s));
}

def:pub js_Duration_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options — ignore the argument (call toString with defaults).
    empty_args: list[JSValue] = [];
    return js_Duration_toString(this_val, empty_args);
}

def:pub js_Duration_toLocaleString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Duration_toString(this_val, args);
}

def:pub js_Duration_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_Duration_total(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("Duration.total requires 1 argument"));
        return js_undefined();
    }
    d: list[float] = js_duration_read(js_this_duration(this_val));
    opts: JSValue = args[0];
    unit: str = "";
    has_anchor: bool = False;
    anchor: list[int] = [0, 0, 0, 0, 0, 0, 0];
    if jsv_is_string_cell(opts) {
        unit = temporal_get_unit_from_string_arg(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
    } else {
        temporal_require_options_object(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if jsv_is_object_cell(opts) {
            relative_to: JSValue = js_object_get_observable(
                opts, str_intern("relativeTo"), opts
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
            if not jsv_is_undefined(relative_to) {
                anchor = GetTemporalRelativeToAnchor(relative_to);
                if vm_has_native_exc() {
                    return js_undefined();
                }
                has_anchor = True;
            }
        }
        unit = temporal_get_total_unit_observable(opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if _duration_total_needs_relative_to(d, unit) {
        if not has_anchor {
            vm_throw_native(make_range_error("relativeTo is required"));
            return js_undefined();
        }
        return js_number(
            dur_total_relative(
                d,
                unit,
                anchor[0],
                anchor[1],
                anchor[2],
                anchor[3],
                anchor[4],
                anchor[5],
                anchor[6]
            )
        );
    }
    return js_number(dur_total(d, unit));
}

def:pub js_Duration_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_duration(this_val);
    name: str = temporal_callee_name();
    d: list[float] = js_duration_read(o);
    sgn: int = dur_sign(d);
    if name == "years" {
        return js_number(_dur_signed_field(d[DUR_YEARS], sgn));
    }
    if name == "months" {
        return js_number(_dur_signed_field(d[DUR_MONTHS], sgn));
    }
    if name == "weeks" {
        return js_number(_dur_signed_field(d[DUR_WEEKS], sgn));
    }
    if name == "days" {
        return js_number(_dur_signed_field(d[DUR_DAYS], sgn));
    }
    if name == "hours" {
        return js_number(_dur_signed_field(d[DUR_HOURS], sgn));
    }
    if name == "minutes" {
        return js_number(_dur_signed_field(d[DUR_MINUTES], sgn));
    }
    if name == "seconds" {
        return js_number(_dur_signed_field(d[DUR_SECONDS], sgn));
    }
    if name == "sign" {
        return js_int(dur_sign(d));
    }
    if name == "blank" {
        return js_boolean(dur_is_zero(d));
    }
    sub: list[float] = _dur_split_subsecond(d[DUR_NANOSECONDS]);
    ms_v: JSValue = js_object_get(o, str_intern("__ms"));
    ms: float = sub[0];
    us: float = sub[1];
    nss: float = sub[2];
    if not jsv_is_undefined(ms_v) {
        ms = jsv_to_double(ms_v);
        us = jsv_to_double(js_object_get(o, str_intern("__us")));
        nss = jsv_to_double(js_object_get(o, str_intern("__ns")));
    }
    if name == "nanoseconds" {
        return js_number(_dur_signed_field(nss, sgn));
    }
    if name == "microseconds" {
        return js_number(_dur_signed_field(us, sgn));
    }
    if name == "milliseconds" {
        return js_number(_dur_signed_field(ms, sgn));
    }
    return js_undefined();
}
