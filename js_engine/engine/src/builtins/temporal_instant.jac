"""Temporal.Instant built-in — epoch nanoseconds via bignat."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_number,
    js_boolean,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_double,
    jsv_is_double,
    jsv_is_bigint_cell
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.temporal_parse {
    parse_temporal_instant,
    PR_OK,
    PR_YEAR,
    PR_MONTH,
    PR_DAY,
    PR_HOUR,
    PR_MINUTE,
    PR_SECOND,
    PR_NANOSECOND,
    PR_OFFSET_S,
    PR_OFFSET_NS,
    PR_HAS_OFFSET,
    PR_IS_Z,
    PR_HAS_DATE,
    PR_HAS_TIME
}
import from engine.src.runtime.temporal_iso { iso_days_from_ymd, iso_total_nanoseconds }
import from engine.src.runtime.bignat {
    bn_zero,
    bn_from_int,
    bn_parse_decimal,
    bn_to_string,
    bn_add,
    bn_sub,
    bn_cmp,
    bn_sign,
    bn_mul_small,
    bn_divmod,
    bn_neg,
    _BN_DIV_REM
}
import from engine.src.runtime.temporal_duration_math {
    dur_from_components,
    dur_balance,
    dur_round,
    dur_total,
    DUR_YEARS,
    DUR_MONTHS,
    DUR_WEEKS,
    DUR_DAYS,
    DUR_HOURS,
    DUR_MINUTES,
    DUR_SECONDS,
    DUR_NANOSECONDS,
    DUR_SIGN,
    ROUND_TRUNC,
    dur_sign,
    dur_validate_rounding_increment,
    rounding_mode_from_string
}
import from engine.src.builtins.temporal_zoneddatetime {
    js_Temporal_ZonedDateTime_from,
    temporal_zoned_epoch_ns_to_zdt
}
import from engine.src.builtins.temporal {
    js_instant_create,
    js_instant_read_ns,
    js_this_instant,
    js_is_instant,
    js_is_zoned_datetime,
    js_zoned_read_ns,
    temporal_reject_epoch_ns_out_of_range,
    js_duration_create,
    js_duration_read,
    js_instant_init,
    temporal_to_string,
    temporal_instant_getter,
    temporal_throw_valueof,
    temporal_callee_name,
    temporal_get_rounding_mode,
    temporal_get_round_rounding_mode,
    temporal_get_smallest_unit,
    temporal_get_smallest_unit_required,
    temporal_require_options_object,
    temporal_get_rounding_increment,
    temporal_instant_round_max_increment,
    temporal_round_options_from_arg,
    temporal_get_largest_unit,
    temporal_apply_difference_rounding,
    temporal_apply_difference_rounding_resolved,
    temporal_resolve_difference_units_grouped,
    temporal_read_difference_settings,
    ToTemporalTimeZoneIdentifier,
    temporal_format_instant_to_string,
    temporal_format_instant_to_string_prec,
    temporal_read_tostring_precision,
    temporal_round_epoch_ns,
}
import from engine.src.builtins.temporal_duration { ToTemporalDurationValue }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.jsvalue {
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_string_cell
}
import from engine.src.runtime.js_bigint { js_bigint_from_primitive }
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.vm.vm_obs { js_object_get_observable }

def _epoch_ns_from_parts(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, offset_s: int
) -> list[int] {
    return _epoch_ns_from_parts_off_ns(y, m, d, h, mi, s, ns, offset_s, 0);
}

def _epoch_ns_from_parts_off_ns(
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    offset_s: int,
    offset_ns: int
) -> list[int] {
    days: int = iso_days_from_ymd(y, m, d);
    total_s: int = days * 86400 + h * 3600 + mi * 60 + s - offset_s;
    scaled: list[int] = bn_mul_small(bn_from_int(total_s), 1000000000);
    # Subtract the sub-second part of the offset too (sub-minute offsets like +00:19:32.37).
    return bn_sub(bn_add(scaled, bn_from_int(ns)), bn_from_int(offset_ns));
}

def:pub js_Temporal_Instant(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant constructor requires 1 argument"));
        return js_undefined();
    }
    # Temporal.Instant(epochNanoseconds): the argument is ToBigInt-coerced epoch
    # nanoseconds and range-checked to ±8.64e21 ns. ToBigInt accepts a bigint, a
    # boolean (0n/1n), or a numeric STRING (SyntaxError if unparseable), and rejects a
    # Number (TypeError). This is distinct from Instant.from, which parses an ISO STRING
    # and rejects a bigint — so the constructor must NOT route through
    # js_Temporal_Instant_from.
    a0: JSValue = args[0];
    big: JSValue = js_bigint_from_primitive(a0, False);
    if vm_has_native_exc() {
        return js_undefined();
    }
    ns: list[int] = bn_parse_decimal(temporal_to_string(big));
    temporal_reject_epoch_ns_out_of_range(ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if jsv_is_object_cell(this_val) and jsv_to_table_id(this_val) > 0 {
        return js_instant_init(this_val, ns);
    }
    return js_instant_create(ns);
}

# Remove [u-ca=…] / [!u-ca=…] calendar annotations from an ISO string, keeping timezone
# annotations. An Instant is calendar-agnostic, so an unknown/critical calendar the shared
# parser would reject must be dropped before re-parsing.
def:priv _instant_calendar_annotation_count(s: str) -> int {
    cnt: int = 0;
    i: int = 0;
    n: int = len(s);
    while i < n {
        if s[i:i + 1] == "[" {
            j: int = i + 1;
            while j < n and s[j:j + 1] != "]" {
                j = j + 1;
            }
            inner: str = s[i + 1:j];
            if len(inner) > 0 and inner[0:1] == "!" {
                inner = inner[1:len(inner)];
            }
            if len(inner) >= 5 and inner[0:5] == "u-ca=" {
                cnt = cnt + 1;
            }
            i = j + 1;
        } else {
            i = i + 1;
        }
    }
    return cnt;
}

def:priv _instant_strip_calendar(s: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(s);
    while i < n {
        if s[i:i + 1] == "[" {
            j: int = i + 1;
            while j < n and s[j:j + 1] != "]" {
                j = j + 1;
            }
            inner: str = s[i + 1:j];
            body: str = inner;
            if len(body) > 0 and body[0:1] == "!" {
                body = body[1:len(body)];
            }
            is_cal: bool = len(body) >= 5 and body[0:5] == "u-ca=";
            if not is_cal {
                out = out + s[i:j + 1];
            }
            i = j + 1;
        } else {
            out = out + s[i:i + 1];
            i = i + 1;
        }
    }
    return out;
}

def:pub js_Temporal_Instant_from(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.from requires 1 argument"));
        return js_undefined();
    }
    a0: JSValue = args[0];
    # ToTemporalInstant returns a fresh CreateTemporalInstant, NOT the same object.
    if js_is_instant(a0) {
        return js_instant_create(js_instant_read_ns(a0));
    }
    # A ZonedDateTime IS a fixed instant — take its epoch nanoseconds directly.
    if js_is_zoned_datetime(a0) {
        return js_instant_create(js_zoned_read_ns(a0));
    }
    # ToTemporalInstant: after the Instant/ZonedDateTime fast paths, a non-branded
    # OBJECT is ToString-coerced (ToPrimitive with string hint) and then parsed — a
    # plain object stringifies to "[object Object]" and fails the ISO parse with a
    # RangeError, NOT a TypeError. Only the primitives undefined/null/boolean/number/
    # bigint/symbol are a TypeError (they are not valid ParseTemporalInstantString
    # inputs). In particular bigint is NOT epoch-ns here; only fromEpochNanoseconds is.
    if jsv_is_undefined(a0)
        or jsv_is_null(a0)
        or jsv_is_bool(a0)
        or jsv_is_int32(a0)
        or jsv_is_double(a0)
        or jsv_is_bigint_cell(a0)
        or jsv_is_symbol(a0) {
        vm_throw_native(
            make_type_error(
                "Instant.from: argument must be a string, object, or Temporal.Instant"
            )
        );
        return js_undefined();
    }
    s: str = js_coerce_to_string(a0);
    if vm_has_native_exc() {
        return js_undefined();
    }
    pr: list[any] = parse_temporal_instant(s);
    if not pr[PR_OK] {
        # An Instant ignores the calendar — a single unknown/critical calendar
        # ("…Z[u-ca=discord]", "…Z[!u-ca=hebrew]") is accepted. Retry with the lone
        # calendar annotation stripped. Do NOT strip when there are MULTIPLE calendar
        # annotations: "…[u-ca=iso8601][!u-ca=iso8601]" must still throw (the shared
        # parser's multiple-critical check), so leave those for it to reject.
        if _instant_calendar_annotation_count(s) == 1 {
            s2: str = _instant_strip_calendar(s);
            if s2 != s {
                pr = parse_temporal_instant(s2);
            }
        }
    }
    if not pr[PR_OK] or not pr[PR_HAS_DATE] or not pr[PR_HAS_TIME] {
        vm_throw_native(make_range_error("invalid Instant string"));
        return js_undefined();
    }
    # An Instant string MUST carry a UTC offset or the "Z" designator (it denotes an exact
    # instant); a bare wall-clock is a RangeError.
    if pr[PR_HAS_OFFSET] == 0 and pr[PR_IS_Z] == 0 {
        vm_throw_native(make_range_error("Instant string requires a UTC offset"));
        return js_undefined();
    }
    off: int = 0;
    off_ns: int = 0;
    if pr[PR_HAS_OFFSET] {
        off = pr[PR_OFFSET_S];
        if len(pr) > PR_OFFSET_NS {
            off_ns = pr[PR_OFFSET_NS];
        }
    }
    # ParseISODateTime constrains a leap second ":60" to ":59" (there is no leap second
    # in the epoch) — "2016-12-31T23:59:60Z" is 2016-12-31T23:59:59Z, NOT the next day.
    sec_in: int = pr[PR_SECOND];
    if sec_in == 60 {
        sec_in = 59;
    }
    ns: list[int] = _epoch_ns_from_parts_off_ns(
        pr[PR_YEAR],
        pr[PR_MONTH],
        pr[PR_DAY],
        pr[PR_HOUR],
        pr[PR_MINUTE],
        sec_in,
        pr[PR_NANOSECOND],
        off,
        off_ns
    );
    # The resulting epoch nanoseconds must be within the representable Instant range;
    # a valid wall-clock string can still be out of range once its offset is applied
    # ("+275760-09-13T00:00:00.000-12" overshoots the maximum).
    temporal_reject_epoch_ns_out_of_range(ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_instant_create(ns);
}

def:pub js_Temporal_Instant_fromEpochMilliseconds(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("Instant.fromEpochMilliseconds requires 1 argument")
        );
        return js_undefined();
    }
    ms: int = 0;
    if jsv_is_int32(args[0]) {
        ms = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        ms = int(jsv_to_double(args[0]));
    }
    ns: list[int] = bn_mul_small(bn_from_int(ms), 1000000);
    temporal_reject_epoch_ns_out_of_range(ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_instant_create(ns);
}

def:pub js_Temporal_Instant_fromEpochNanoseconds(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("Instant.fromEpochNanoseconds requires 1 argument")
        );
        return js_undefined();
    }
    s: str = temporal_to_string(args[0]);
    ns: list[int] = bn_parse_decimal(s);
    temporal_reject_epoch_ns_out_of_range(ns);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_instant_create(ns);
}

def:pub js_Temporal_Instant_compare(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("Instant.compare requires 2 arguments"));
        return js_undefined();
    }
    # Both arguments are coerced via ToTemporalInstant (accepts an Instant or a parseable
    # instant string) — not read as raw slots, which skipped all string validation.
    ao: JSValue = _instant_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    bo: JSValue = _instant_to_temporal(args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    a: list[int] = js_instant_read_ns(ao);
    b: list[int] = js_instant_read_ns(bo);
    return js_int(bn_cmp(a, b));
}

def _instant_reject_date_units(dur: list[float]) -> None {
    if dur[DUR_YEARS] != 0.0
        or dur[DUR_MONTHS] != 0.0
        or dur[DUR_WEEKS] != 0.0
        or dur[DUR_DAYS] != 0.0 {
        vm_throw_native(make_range_error("invalid duration"));
        return;
    }
}

def _duration_time_to_ns_bn(dur: list[float]) -> list[int] {
    _instant_reject_date_units(dur);
    if vm_has_native_exc() {
        return bn_zero();
    }
    sgn: int = dur_sign(dur);
    total: list[int] = bn_zero();
    total = bn_add(
        total, bn_mul_small(bn_from_int(int(dur[DUR_HOURS])), 3600000000000)
    );
    total = bn_add(
        total, bn_mul_small(bn_from_int(int(dur[DUR_MINUTES])), 60000000000)
    );
    total = bn_add(total, bn_mul_small(bn_from_int(int(dur[DUR_SECONDS])), 1000000000));
    total = bn_add(total, bn_from_int(int(dur[DUR_NANOSECONDS])));
    if sgn < 0 {
        return bn_neg(total);
    }
    return total;
}

def _epoch_ns_from_duration(d: list[float]) -> list[int] {
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

def _instant_ns_to_duration(ns: list[int]) -> list[float] {
    return _dur_from_ns_diff(ns);
}

def:pub js_Instant_add(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.add requires 1 argument"));
        return js_undefined();
    }
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    delta: list[int] = _duration_time_to_ns_bn(dur);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cur: list[int] = js_instant_read_ns(o);
    if bn_sign(delta) < 0 {
        return js_instant_create(bn_sub(cur, bn_neg(delta)));
    }
    return js_instant_create(bn_add(cur, delta));
}

def:pub js_Instant_subtract(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.subtract requires 1 argument"));
        return js_undefined();
    }
    dur: list[float] = ToTemporalDurationValue(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    delta: list[int] = _duration_time_to_ns_bn(dur);
    if vm_has_native_exc() {
        return js_undefined();
    }
    cur: list[int] = js_instant_read_ns(o);
    if bn_sign(delta) < 0 {
        return js_instant_create(bn_add(cur, bn_neg(delta)));
    }
    return js_instant_create(bn_sub(cur, delta));
}

def:priv _instant_to_temporal(v: JSValue) -> JSValue {
    if js_is_instant(v) {
        return v;
    }
    return js_Temporal_Instant_from([v]);
}

def:priv _dur_from_ns_diff(diff: list[int]) -> list[float] {
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

def:pub js_Instant_equals(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.equals requires 1 argument"));
        return js_undefined();
    }
    other: JSValue = _instant_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_boolean(bn_cmp(js_instant_read_ns(o), js_instant_read_ns(other)) == 0);
}

def:pub js_Instant_toZonedDateTimeISO(
    this_val: JSValue, args: list[JSValue]
) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(
            make_type_error("Instant.toZonedDateTimeISO requires 1 argument")
        );
        return js_undefined();
    }
    tz: str = ToTemporalTimeZoneIdentifier(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    ns_s: str = bn_to_string(js_instant_read_ns(o), 10);
    return temporal_zoned_epoch_ns_to_zdt(ns_s, tz, "iso8601");
}

def:pub js_Instant_toLocaleString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Instant_toString(this_val, args);
}

# Balanced time Duration from a SIGNED epoch-ns bignum diff, rounded to `smallest`/
# `increment`/`mode` and balanced up to `largest` — entirely in bignum/int space so no
# float64 rounding creeps in for large spans (Instant since/until float64-representable).
def:priv _instant_diff_duration(
    diff: list[int], largest: str, smallest: str, increment: int, mode: int
) -> list[float] {
    step_ns: int = 1;
    if smallest == "second" {
        step_ns = 1000000000;
    } elif smallest == "millisecond" {
        step_ns = 1000000;
    } elif smallest == "microsecond" {
        step_ns = 1000;
    } elif smallest == "minute" {
        step_ns = 60000000000;
    } elif smallest == "hour" {
        step_ns = 3600000000000;
    }
    step_ns = step_ns * increment;
    rounded: list[int] = temporal_round_epoch_ns(diff, smallest, increment, mode);
    neg: int = 0;
    abs_ns: list[int] = rounded;
    if bn_sign(rounded) < 0 {
        neg = 1;
        abs_ns = bn_neg(rounded);
    }
    # Decompose into the largest allowed time unit downward, in bignum then int once small.
    hh: int = 0;
    mm: int = 0;
    ss: int = 0;
    nn: int = 0;
    days: int = 0;
    lvl: int = 5;
    if largest == "hour" {
        lvl = 4;
    } elif largest == "minute" {
        lvl = 3;
    } elif largest == "second" {
        lvl = 2;
    } elif largest == "millisecond"
        or largest == "microsecond"
        or largest == "nanosecond" {
        lvl = 2;
    }
    rem: list[int] = abs_ns;
    # Fill only units at or below `largest` (do NOT balance upward afterwards — that would
    # reintroduce hours/days above the requested largestUnit). Instant has no day/week
    # (not calendar-aware): the largest is at most "hour".
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
    # Sub-second remainder folds into the nanosecond field; dur_from_components' consumer
    # (the .milliseconds/.microseconds accessors) split it. When largest is a sub-second
    # unit, the whole remainder is still expressed through the ns field.
    nn = int(bn_to_string(rem, 10));
    sgn: float = 1.0;
    if neg != 0 {
        sgn = -1.0;
    }
    ns_total: float = float(nn);
    # If largest is below second (ms/µs/ns), also fold seconds/minutes/hours down — but for
    # Instant the default/typical largest is second or hour, so ss/mm/hh are already placed.
    dur: list[float] = dur_from_components(
        0.0,
        0.0,
        0.0,
        0.0,
        float(hh) * sgn,
        float(mm) * sgn,
        float(ss) * sgn,
        ns_total * sgn
    );
    return dur;
}

def:pub js_Instant_until(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.until requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` converts BEFORE options; then read largestUnit/roundingIncrement/
    # roundingMode/smallestUnit in ALPHABETICAL order (§Instant.until).
    other: JSValue = _instant_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    diff: list[int] = bn_sub(js_instant_read_ns(other), js_instant_read_ns(o));
    units: list[str] = temporal_read_difference_settings(
        opts, "second", "nanosecond", "time"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    inc: int = int(units[2]);
    mode: int = rounding_mode_from_string(units[3]);
    dur_validate_rounding_increment(
        inc, temporal_instant_round_max_increment(units[1]), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur: list[float] = _instant_diff_duration(diff, units[0], units[1], inc, mode);
    return js_duration_create(dur);
}

def:pub js_Instant_since(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    if len(args) < 1 {
        vm_throw_native(make_type_error("Instant.since requires 1 argument"));
        return js_undefined();
    }
    opts: JSValue = js_undefined();
    if len(args) > 1 {
        opts = args[1];
    }
    # `other` converts BEFORE options; then read the four settings in ALPHABETICAL
    # order (§Instant.since). since == until with the sign of `diff` flipped.
    other: JSValue = _instant_to_temporal(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    diff: list[int] = bn_sub(js_instant_read_ns(o), js_instant_read_ns(other));
    units: list[str] = temporal_read_difference_settings(
        opts, "second", "nanosecond", "time"
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    inc: int = int(units[2]);
    mode: int = rounding_mode_from_string(units[3]);
    dur_validate_rounding_increment(
        inc, temporal_instant_round_max_increment(units[1]), True
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    dur: list[float] = _instant_diff_duration(diff, units[0], units[1], inc, mode);
    return js_duration_create(dur);
}

def:pub js_Instant_round(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    # round(roundTo): a missing/undefined roundTo is a TypeError (§step 3).
    if len(args) < 1 or jsv_is_undefined(args[0]) {
        vm_throw_native(make_type_error("Instant.round requires a roundTo argument"));
        return js_undefined();
    }
    opts: JSValue = args[0];
    opts = temporal_round_options_from_arg(opts);
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Options read in ALPHABETICAL order, all before the increment-vs-unit validation
    # (§Instant.round order-of-operations).
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
    # Instant.round accepts only TIME units — a calendar unit (year/month/week/day) is a
    # RangeError (an Instant has no calendar date to round).
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
    ns: list[int] = js_instant_read_ns(o);
    rounded_ns: list[int] = temporal_round_epoch_ns(ns, unit, increment, mode);
    return js_instant_create(rounded_ns);
}

def:pub js_Instant_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    opts: JSValue = js_undefined();
    if len(args) > 0 {
        opts = args[0];
    }
    temporal_require_options_object(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # Precision/rounding options (fractionalSecondDigits → roundingMode → smallestUnit)
    # are read first, then `timeZone` — the order-of-operations sequence.
    prec: list[int] = temporal_read_tostring_precision(opts);
    if vm_has_native_exc() {
        return js_undefined();
    }
    tz: str = "";
    has_tz: bool = False;
    if jsv_is_object_cell(opts) {
        tzv: JSValue = js_object_get_observable(opts, str_intern("timeZone"), opts);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not jsv_is_undefined(tzv) {
            tz = ToTemporalTimeZoneIdentifier(tzv);
            if vm_has_native_exc() {
                return js_undefined();
            }
            has_tz = True;
        }
    }
    s: str = temporal_format_instant_to_string_prec(
        js_instant_read_ns(o), prec[0], prec[1], prec[3], has_tz, tz
    );
    if vm_has_native_exc() {
        return js_undefined();
    }
    return jsv_from_string_id(str_intern(s));
}

def:pub js_Instant_toJSON(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # toJSON takes NO options — ignore the argument (call toString with defaults).
    empty_args: list[JSValue] = [];
    return js_Instant_toString(this_val, empty_args);
}

def:pub js_Instant_valueOf(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return temporal_throw_valueof();
}

def:pub js_Instant_getter(this_val: JSValue, args: list[JSValue]) -> JSValue {
    o: JSValue = js_this_instant(this_val);
    return temporal_instant_getter(o, temporal_callee_name());
}
