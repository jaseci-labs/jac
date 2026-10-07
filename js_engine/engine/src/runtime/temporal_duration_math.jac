"""
runtime/temporal_duration_math.na.jac — Temporal Duration arithmetic engine.

Balance/bubble across unit boundaries, rounding modes, total(), sign validation.
"""

import from engine.src.runtime.error {
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}

import from engine.src.runtime.temporal_iso {
    iso_add_days,
    iso_add_months,
    iso_balance_date,
    iso_days_from_ymd,
    iso_ymd_from_days,
    iso_total_nanoseconds,
    iso_nanoseconds_to_time,
    iso_add_time,
    iso_is_leap_year,
    iso_days_in_month,
    iso_compare,
    iso_validate_relativeto_ymd
}

glob DUR_YEARS: int = 0,
     DUR_MONTHS: int = 1,
     DUR_WEEKS: int = 2,
     DUR_DAYS: int = 3,
     DUR_HOURS: int = 4,
     DUR_MINUTES: int = 5,
     DUR_SECONDS: int = 6,
     DUR_NANOSECONDS: int = 7,
     DUR_SIGN: int = 8;

def:pub dur_empty -> list[float] {
    return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0];
}

def _float_abs(v: float) -> float {
    if v < 0.0 {
        return -v;
    }
    return v;
}

def:pub dur_from_components(
    y: float, mo: float, w: float, d: float, h: float, mi: float, s: float, ns: float
) -> list[float] {
    sign: float = 1.0;
    if y < 0 or mo < 0 or w < 0 or d < 0 or h < 0 or mi < 0 or s < 0 or ns < 0 {
        sign = -1.0;
    }
    return [
        _float_abs(y),
        _float_abs(mo),
        _float_abs(w),
        _float_abs(d),
        _float_abs(h),
        _float_abs(mi),
        _float_abs(s),
        _float_abs(ns),
        sign
    ];
}

def:pub dur_sign(d: list[float]) -> int {
    if d[DUR_SIGN] < 0 {
        return -1;
    }
    return 1;
}

def:pub dur_is_zero(d: list[float]) -> bool {
    i: int = 0;
    while i <= DUR_NANOSECONDS {
        if d[i] != 0.0 {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def:pub dur_negate(d: list[float]) -> list[float] {
    out: list[float] = dur_from_components(
        d[DUR_YEARS],
        d[DUR_MONTHS],
        d[DUR_WEEKS],
        d[DUR_DAYS],
        d[DUR_HOURS],
        d[DUR_MINUTES],
        d[DUR_SECONDS],
        d[DUR_NANOSECONDS]
    );
    out[DUR_SIGN] = -d[DUR_SIGN];
    # A zero duration is signless (spec sign 0). Negating it must NOT yield sign=-1,
    # or `.total()` returns -0 (Temporal PlainDate.since with a same-instant arg —
    # argument-plaindatetime "time part dropped"). Normalize zero back to +1.
    return _dur_normalize_sign(out);
}

def:pub dur_add(a: list[float], b: list[float]) -> list[float] {
    sa: int = dur_sign(a);
    sb: int = dur_sign(b);
    y: float = a[DUR_YEARS] * float(sa) + b[DUR_YEARS] * float(sb);
    mo: float = a[DUR_MONTHS] * float(sa) + b[DUR_MONTHS] * float(sb);
    w: float = a[DUR_WEEKS] * float(sa) + b[DUR_WEEKS] * float(sb);
    d: float = a[DUR_DAYS] * float(sa) + b[DUR_DAYS] * float(sb);
    h: float = a[DUR_HOURS] * float(sa) + b[DUR_HOURS] * float(sb);
    mi: float = a[DUR_MINUTES] * float(sa) + b[DUR_MINUTES] * float(sb);
    s: float = a[DUR_SECONDS] * float(sa) + b[DUR_SECONDS] * float(sb);
    ns: float = a[DUR_NANOSECONDS] * float(sa) + b[DUR_NANOSECONDS] * float(sb);
    return _dur_balance_signed(y, mo, w, d, h, mi, s, ns);
}

def:priv _dur_idiv_trunc(n: float, d: float) -> int {
    q: float = n / d;
    if q < 0.0 {
        return -int(-q);
    }
    return int(q);
}

def:priv _dur_balance_signed(
    y: float, mo: float, w: float, days: float, h: float, mi: float, s: float, ns: float
) -> list[float] {
    if ns >= 1000000000.0 or ns <= -1000000000.0 {
        extra: int = int(ns) // 1000000000;
        if ns < 0 and int(ns) % 1000000000 != 0 {
            extra = extra - 1;
        }
        s = s + float(extra);
        ns = ns - float(extra) * 1000000000.0;
    }
    if s >= 60.0 or s <= -60.0 {
        extra2: int = int(s) // 60;
        if s < 0 and int(s) % 60 != 0 {
            extra2 = extra2 - 1;
        }
        mi = mi + float(extra2);
        s = s - float(extra2) * 60.0;
    }
    if mi >= 60.0 or mi <= -60.0 {
        extra3: int = int(mi) // 60;
        if mi < 0 and int(mi) % 60 != 0 {
            extra3 = extra3 - 1;
        }
        h = h + float(extra3);
        mi = mi - float(extra3) * 60.0;
    }
    total_h: float = days * 24.0 + h;
    if total_h != 0.0 or days != 0.0 {
        qd: int = _dur_idiv_trunc(total_h, 24.0);
        days = float(qd);
        h = total_h - float(qd) * 24.0;
    }
    if w != 0.0 {
        days = days + w * 7.0;
        w = 0.0;
    }
    return dur_from_components(y, mo, w, days, h, mi, s, ns);
}

def:pub dur_subtract(a: list[float], b: list[float]) -> list[float] {
    return dur_add(a, dur_negate(b));
}

def:pub dur_balance_time(d: list[float]) -> list[float] {
    sign: float = d[DUR_SIGN];
    ns: float = d[DUR_NANOSECONDS];
    s: float = d[DUR_SECONDS];
    mi: float = d[DUR_MINUTES];
    h: float = d[DUR_HOURS];
    if ns >= 1000000000.0 or ns <= -1000000000.0 {
        extra: int = int(ns) // 1000000000;
        if ns < 0 and int(ns) % 1000000000 != 0 {
            extra = extra - 1;
        }
        s = s + float(extra);
        ns = ns - float(extra) * 1000000000.0;
    }
    if s >= 60.0 or s <= -60.0 {
        extra2: int = int(s) // 60;
        if s < 0 and int(s) % 60 != 0 {
            extra2 = extra2 - 1;
        }
        mi = mi + float(extra2);
        s = s - float(extra2) * 60.0;
    }
    if mi >= 60.0 or mi <= -60.0 {
        extra3: int = int(mi) // 60;
        if mi < 0 and int(mi) % 60 != 0 {
            extra3 = extra3 - 1;
        }
        h = h + float(extra3);
        mi = mi - float(extra3) * 60.0;
    }
    out: list[float] = dur_from_components(
        d[DUR_YEARS], d[DUR_MONTHS], d[DUR_WEEKS], d[DUR_DAYS], h, mi, s, ns
    );
    out[DUR_SIGN] = sign;
    return out;
}

def:pub dur_balance(d: list[float]) -> list[float] {
    sign: float = d[DUR_SIGN];
    ns: float = d[DUR_NANOSECONDS];
    s: float = d[DUR_SECONDS];
    mi: float = d[DUR_MINUTES];
    h: float = d[DUR_HOURS];
    days: float = d[DUR_DAYS];
    w: float = d[DUR_WEEKS];
    mo: float = d[DUR_MONTHS];
    y: float = d[DUR_YEARS];
    if ns >= 1000000000.0 or ns <= -1000000000.0 {
        extra: int = int(ns) // 1000000000;
        if ns < 0 and int(ns) % 1000000000 != 0 {
            extra = extra - 1;
        }
        s = s + float(extra);
        ns = ns - float(extra) * 1000000000.0;
    }
    if s >= 60.0 or s <= -60.0 {
        extra2: int = int(s) // 60;
        if s < 0 and int(s) % 60 != 0 {
            extra2 = extra2 - 1;
        }
        mi = mi + float(extra2);
        s = s - float(extra2) * 60.0;
    }
    if mi >= 60.0 or mi <= -60.0 {
        extra3: int = int(mi) // 60;
        if mi < 0 and int(mi) % 60 != 0 {
            extra3 = extra3 - 1;
        }
        h = h + float(extra3);
        mi = mi - float(extra3) * 60.0;
    }
    if h >= 24.0 or h <= -24.0 {
        extra4: int = int(h) // 24;
        if h < 0 and int(h) % 24 != 0 {
            extra4 = extra4 - 1;
        }
        days = days + float(extra4);
        h = h - float(extra4) * 24.0;
    }
    if w != 0.0 {
        days = days + w * 7.0;
        w = 0.0;
    }
    out: list[float] = dur_from_components(y, mo, w, days, h, mi, s, ns);
    out[DUR_SIGN] = sign;
    return out;
}

glob ROUND_TRUNC: int = 0,
     ROUND_HALF_EXPAND: int = 1,
     ROUND_HALF_TRUNC: int = 2,
     ROUND_HALF_EVEN: int = 3,
     ROUND_CEIL: int = 4,
     ROUND_FLOOR: int = 5,
     ROUND_EXPAND: int = 6,
     ROUND_HALF_CEIL: int = 7,
     ROUND_HALF_FLOOR: int = 8;

def:pub dur_from_unit_total(v: float, unit: str) -> list[float] {
    sign: float = 1.0;
    if v < 0.0 {
        sign = -1.0;
        v = -v;
    }
    y: float = 0.0;
    mo: float = 0.0;
    w: float = 0.0;
    d: float = 0.0;
    h: float = 0.0;
    mi: float = 0.0;
    s: float = 0.0;
    ns: float = 0.0;
    if unit == "years" or unit == "year" {
        y = v;
    } elif unit == "months" or unit == "month" {
        mo = v;
    } elif unit == "weeks" or unit == "week" {
        w = v;
    } elif unit == "days" or unit == "day" {
        d = v;
    } elif unit == "hours" or unit == "hour" {
        h = v;
    } elif unit == "minutes" or unit == "minute" {
        mi = v;
    } elif unit == "seconds" or unit == "second" {
        s = v;
    } elif unit == "milliseconds" or unit == "millisecond" {
        ns = v * 1000000.0;
    } elif unit == "microseconds" or unit == "microsecond" {
        ns = v * 1000.0;
    } else {
        ns = v;
    }
    out: list[float] = dur_from_components(y, mo, w, d, h, mi, s, ns);
    out[DUR_SIGN] = sign;
    # Balance only within time below days — do NOT fold hours→days or weeks→days
    # here; Duration.round / largestUnit decides the final shape.
    if y != 0.0 or mo != 0.0 or w != 0.0 or d != 0.0 {
        return _dur_normalize_sign(out);
    }
    return _dur_normalize_sign(dur_balance_time(out));
}

def:priv _dur_normalize_sign(d: list[float]) -> list[float] {
    if dur_is_zero(d) {
        d[DUR_SIGN] = 1.0;
    }
    return d;
}

def:priv _dur_is_calendar_unit(unit: str) -> bool {
    if unit == "years" or unit == "year" {
        return True;
    }
    if unit == "months" or unit == "month" {
        return True;
    }
    if unit == "weeks" or unit == "week" {
        return True;
    }
    return False;
}

def:priv _dur_needs_relative_anchor(d: list[float], unit: str) -> bool {
    if _dur_is_calendar_unit(unit) {
        return True;
    }
    if unit == "days" or unit == "day" {
        if d[DUR_YEARS] != 0.0 or d[DUR_MONTHS] != 0.0 or d[DUR_WEEKS] != 0.0 {
            return True;
        }
    }
    return False;
}

def:pub dur_total_relative(
    d: list[float],
    unit: str,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> float {
    end: list[int] = dur_add_to_iso_ymd(y, m, day, h, mi, s, ns, d);
    if vm_has_native_exc() {
        return dur_total(d, unit);
    }
    if unit == "days" or unit == "day" {
        dd: int = dur_until_days(y, m, day, end[0], end[1], end[2]);
        t0: int = iso_total_nanoseconds(h, mi, s, ns);
        t1: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
        total_ns: int = dd * 86400000000000 + (t1 - t0);
        return float(total_ns) / 86400000000000.0;
    }
    if unit == "weeks" or unit == "week" {
        dd: int = dur_until_days(y, m, day, end[0], end[1], end[2]);
        t0: int = iso_total_nanoseconds(h, mi, s, ns);
        t1: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
        total_ns: int = dd * 86400000000000 + (t1 - t0);
        return float(total_ns) / 604800000000000.0;
    }
    if unit == "months" or unit == "month" {
        # Whole months + fraction of the partial month (remaining days / daysInMonth).
        mo: int = (end[0] - y) * 12 + (end[1] - m);
        if end[2] < day {
            mo = mo - 1;
        }
        mid: list[int] = iso_add_months(y, m, day, mo);
        rem_days: int = dur_until_days(mid[0], mid[1], mid[2], end[0], end[1], end[2]);
        t0: int = iso_total_nanoseconds(h, mi, s, ns);
        t1: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
        time_ns: int = t1 - t0;
        if time_ns < 0 {
            rem_days = rem_days - 1;
            time_ns = time_ns + 86400000000000;
        }
        dim: int = iso_days_in_month(mid[0], mid[1]);
        if dim < 1 {
            dim = 1;
        }
        frac: float = (float(rem_days) + float(time_ns) / 86400000000000.0)
            / float(dim);
        return float(mo) + frac;
    }
    if unit == "years" or unit == "year" {
        # Whole years + fraction of the partial year (via month remainder / 12).
        mo2: float = dur_total_relative(d, "months", y, m, day, h, mi, s, ns);
        return mo2 / 12.0;
    }
    # Time units: elapsed nanoseconds between anchor and anchor+duration.
    # (Must go through the calendar add so years/months/weeks convert correctly.)
    dd2: int = dur_until_days(y, m, day, end[0], end[1], end[2]);
    t0b: int = iso_total_nanoseconds(h, mi, s, ns);
    t1b: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
    total_ns2: int = dd2 * 86400000000000 + (t1b - t0b);
    f_ns: float = float(total_ns2);
    if unit == "hours" or unit == "hour" {
        return f_ns / 3600000000000.0;
    }
    if unit == "minutes" or unit == "minute" {
        return f_ns / 60000000000.0;
    }
    if unit == "seconds" or unit == "second" {
        return f_ns / 1000000000.0;
    }
    if unit == "milliseconds" or unit == "millisecond" {
        return f_ns / 1000000.0;
    }
    if unit == "microseconds" or unit == "microsecond" {
        return f_ns / 1000.0;
    }
    if unit == "nanoseconds" or unit == "nanosecond" {
        return f_ns;
    }
    return dur_total(d, unit);
}

def:pub dur_round(d: list[float], unit: str, increment: int, mode: int) -> list[float] {
    return dur_round_with_anchor(d, unit, increment, mode, False, 0, 0, 0, 0, 0, 0, 0);
}

"""Round only at or below smallestUnit while preserving larger calendar fields."""
def:pub dur_round_preserve_calendar(
    d: list[float], unit: str, increment: int, mode: int
) -> list[float] {
    lvl: int = _unit_level(unit);
    if lvl >= 5 {
        return dur_round(d, unit, increment, mode);
    }
    sign: float = d[DUR_SIGN];
    time_d: list[float] = dur_from_components(
        0.0,
        0.0,
        0.0,
        0.0,
        d[DUR_HOURS],
        d[DUR_MINUTES],
        d[DUR_SECONDS],
        d[DUR_NANOSECONDS]
    );
    time_d[DUR_SIGN] = sign;
    rounded_time: list[float] = dur_round(time_d, unit, increment, mode);
    out: list[float] = dur_from_components(
        d[DUR_YEARS],
        d[DUR_MONTHS],
        d[DUR_WEEKS],
        d[DUR_DAYS],
        rounded_time[DUR_HOURS],
        rounded_time[DUR_MINUTES],
        rounded_time[DUR_SECONDS],
        rounded_time[DUR_NANOSECONDS]
    );
    out[DUR_SIGN] = sign;
    return _dur_normalize_sign(dur_balance_time(out));
}

def:pub dur_round_with_anchor(
    d: list[float],
    unit: str,
    increment: int,
    mode: int,
    has_anchor: bool,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    total: float = dur_total(d, unit);
    if has_anchor and _dur_needs_relative_anchor(d, unit) {
        total = dur_total_relative(d, unit, y, m, day, h, mi, s, ns);
    }
    inc: float = float(increment);
    if inc <= 0.0 {
        inc = 1.0;
    }
    rounded: float = _round_to_increment(total, inc, mode);
    out: list[float] = dur_from_unit_total(rounded, unit);
    if has_anchor and _dur_needs_relative_anchor(d, unit) {
        out = _dur_rebalance_calendar(out, y, m, day, h, mi, s, ns);
    }
    return _dur_normalize_sign(out);
}

"""Round a duration for since/until difference (no post-round calendar rebalance)."""
def:pub dur_round_difference(
    d: list[float],
    unit: str,
    increment: int,
    mode: int,
    has_anchor: bool,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    total: float = dur_total(d, unit);
    if has_anchor and _dur_needs_relative_anchor(d, unit) {
        total = dur_total_relative(d, unit, y, m, day, h, mi, s, ns);
    }
    inc: float = float(increment);
    if inc <= 0.0 {
        inc = 1.0;
    }
    rounded: float = _round_to_increment(total, inc, mode);
    sign: int = dur_sign(d);
    if rounded == 0.0 {
        sign = 1;
    }
    out: list[float] = dur_from_unit_total(rounded, unit);
    # The relative-anchor path (`dur_total_relative`) returns an UNSIGNED magnitude,
    # so when the true direction is negative but `rounded` came out positive, force
    # DUR_SIGN negative. Do NOT touch the case where `rounded` is already negative:
    # `dur_from_unit_total` set the correct sign from it — the prior code's
    # `sign<0 and rounded<0 → +1` branch WRONGLY re-flipped that to positive,
    # inverting since/until day/week diffs (PlainDate/PlainDateTime since/until).
    if sign < 0 and rounded > 0.0 {
        out[DUR_SIGN] = -1.0;
    }
    return _dur_normalize_sign(out);
}

def:priv _dur_rebalance_calendar(
    d: list[float], y: int, m: int, day: int, h: int, mi: int, s: int, ns: int
) -> list[float] {
    return _dur_rebalance_calendar_weeks(d, y, m, day, h, mi, s, ns, False);
}

"""Calendar rebalance; when prefer_weeks, leftover days become weeks+days."""
def:priv _dur_rebalance_calendar_weeks(
    d: list[float],
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    prefer_weeks: bool
) -> list[float] {
    end: list[int] = dur_add_to_iso_ymd(y, m, day, h, mi, s, ns, d);
    if vm_has_native_exc() {
        return d;
    }
    # Month/year delta from calendar fields; remaining days are AFTER years+months.
    mo_delta: int = (end[0] - y) * 12 + (end[1] - m);
    if end[2] < day {
        mo_delta = mo_delta - 1;
    }
    # Intermediate date after applying the signed year/month delta.
    mid: list[int] = iso_add_months(y, m, day, mo_delta);
    day_delta: int = dur_until_days(mid[0], mid[1], mid[2], end[0], end[1], end[2]);
    t0: int = iso_total_nanoseconds(h, mi, s, ns);
    t1: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
    # Elapsed ns from mid@anchor-time → end (may be negative).
    elapsed_ns: int = day_delta * 86400000000000 + (t1 - t0);
    # Month/day opposite signs: borrow one month so the remainder matches
    # mo_delta's sign (e.g. -5Y-8M + 4D → -5Y-7M - 26D).
    if mo_delta < 0 and elapsed_ns > 0 {
        mo_delta = mo_delta + 1;
        mid = iso_add_months(y, m, day, mo_delta);
        day_delta = dur_until_days(mid[0], mid[1], mid[2], end[0], end[1], end[2]);
        elapsed_ns = day_delta * 86400000000000 + (t1 - t0);
    } elif mo_delta > 0 and elapsed_ns < 0 {
        mo_delta = mo_delta - 1;
        mid = iso_add_months(y, m, day, mo_delta);
        day_delta = dur_until_days(mid[0], mid[1], mid[2], end[0], end[1], end[2]);
        elapsed_ns = day_delta * 86400000000000 + (t1 - t0);
    }
    # Overall sign from months when present, else from the day/time remainder.
    sign: float = 1.0;
    abs_mo_delta: int = mo_delta;
    if abs_mo_delta < 0 {
        sign = -1.0;
        abs_mo_delta = -abs_mo_delta;
    } elif abs_mo_delta == 0 and elapsed_ns < 0 {
        sign = -1.0;
    }
    ayr: float = float(abs_mo_delta // 12);
    amo: float = float(abs_mo_delta % 12);
    abs_elapsed: int = elapsed_ns;
    if abs_elapsed < 0 {
        abs_elapsed = -abs_elapsed;
    }
    adays: int = abs_elapsed // 86400000000000;
    abs_time: int = abs_elapsed % 86400000000000;
    hh: int = abs_time // 3600000000000;
    rem: int = abs_time % 3600000000000;
    mmi: int = rem // 60000000000;
    rem2: int = rem % 60000000000;
    sc: int = rem2 // 1000000000;
    n: int = rem2 % 1000000000;
    aw: float = 0.0;
    if prefer_weeks and adays >= 7 {
        aw = float(adays // 7);
        adays = adays % 7;
    }
    out: list[float] = dur_from_components(
        ayr, amo, aw, float(adays), float(hh), float(mmi), float(sc), float(n)
    );
    out[DUR_SIGN] = sign;
    return _dur_normalize_sign(dur_balance_time(out));
}

def _round_to_increment(v: float, inc: float, mode: int) -> float {
    if inc == 0.0 {
        return v;
    }
    q: float = v / inc;
    if mode == ROUND_TRUNC {
        return float(int(q)) * inc;
    }
    if mode == ROUND_EXPAND {
        if v >= 0.0 {
            if q == float(int(q)) {
                return v;
            }
            return float(int(q) + 1) * inc;
        }
        if q == float(int(q)) {
            return v;
        }
        return float(int(q) - 1) * inc;
    }
    if mode == ROUND_CEIL {
        if q == float(int(q)) {
            return v;
        }
        if v >= 0.0 {
            return float(int(q) + 1) * inc;
        }
        return float(int(q)) * inc;
    }
    if mode == ROUND_FLOOR {
        if v >= 0.0 {
            return float(int(q)) * inc;
        }
        if q == float(int(q)) {
            return v;
        }
        return float(int(q) - 1) * inc;
    }
    # Nearest rounding: half = floor(q), frac in [0, 1).
    half: float = float(int(q));
    if v < 0.0 and q != float(int(q)) {
        half = half - 1.0;
    }
    frac: float = q - half;
    if frac > 0.5 {
        return (half + 1.0) * inc;
    }
    if frac < 0.5 {
        return half * inc;
    }
    # Exact halfway — break ties by mode.
    if mode == ROUND_HALF_EVEN {
        if int(half) % 2 == 0 {
            return half * inc;
        }
        return (half + 1.0) * inc;
    }
    if mode == ROUND_HALF_TRUNC {
        # Toward zero.
        if v >= 0.0 {
            return half * inc;
        }
        return (half + 1.0) * inc;
    }
    if mode == ROUND_HALF_FLOOR {
        return half * inc;
    }
    if mode == ROUND_HALF_CEIL {
        return (half + 1.0) * inc;
    }
    # halfExpand (default): away from zero.
    if v >= 0.0 {
        return (half + 1.0) * inc;
    }
    return half * inc;
}

def:pub dur_total(d: list[float], unit: str) -> float {
    sign: float = d[DUR_SIGN];
    ns: float = d[DUR_NANOSECONDS];
    s: float = d[DUR_SECONDS];
    mi: float = d[DUR_MINUTES];
    h: float = d[DUR_HOURS];
    days: float = d[DUR_DAYS];
    w: float = d[DUR_WEEKS];
    mo: float = d[DUR_MONTHS];
    y: float = d[DUR_YEARS];
    total_ns: float = ns + s * 1000000000.0 + mi * 60000000000.0 + h * 3600000000000.0;
    total_ns = total_ns + days * 86400000000000.0 + w * 604800000000000.0;
    if unit == "nanoseconds" or unit == "nanosecond" {
        return total_ns * sign;
    }
    if unit == "microseconds" or unit == "microsecond" {
        return total_ns / 1000.0 * sign;
    }
    if unit == "milliseconds" or unit == "millisecond" {
        return total_ns / 1000000.0 * sign;
    }
    if unit == "seconds" or unit == "second" {
        return total_ns / 1000000000.0 * sign;
    }
    if unit == "minutes" or unit == "minute" {
        return total_ns / 60000000000.0 * sign;
    }
    if unit == "hours" or unit == "hour" {
        return total_ns / 3600000000000.0 * sign;
    }
    if unit == "days" or unit == "day" {
        return total_ns / 86400000000000.0 * sign;
    }
    if unit == "weeks" or unit == "week" {
        return total_ns / 604800000000000.0 * sign;
    }
    if unit == "months" or unit == "month" {
        return (mo + y * 12.0) * sign;
    }
    if unit == "years" or unit == "year" {
        return (y + mo / 12.0) * sign;
    }
    return total_ns * sign;
}

def:pub dur_compare(a: list[float], b: list[float]) -> int {
    if a[DUR_YEARS] != 0.0
        or b[DUR_YEARS] != 0.0
        or a[DUR_MONTHS] != 0.0
        or b[DUR_MONTHS] != 0.0 {
        sa: int = dur_sign(a);
        sb: int = dur_sign(b);
        fields: list[any] = [
            DUR_YEARS,
            DUR_MONTHS,
            DUR_WEEKS,
            DUR_DAYS,
            DUR_HOURS,
            DUR_MINUTES,
            DUR_SECONDS,
            DUR_NANOSECONDS
        ];
        i: int = 0;
        while i < len(fields) {
            f: int = fields[i];
            va: float = a[f] * float(sa);
            vb: float = b[f] * float(sb);
            if va < vb {
                return -1;
            }
            if va > vb {
                return 1;
            }
            i = i + 1;
        }
        return 0;
    }
    days_a: int = int(a[DUR_DAYS]) + int(a[DUR_WEEKS]) * 7;
    days_b: int = int(b[DUR_DAYS]) + int(b[DUR_WEEKS]) * 7;
    if days_a > 100000
        or days_b > 100000
        or a[DUR_HOURS] >= 1000000.0
        or b[DUR_HOURS] >= 1000000.0
        or a[DUR_MINUTES] >= 60000000.0
        or b[DUR_MINUTES] >= 60000000.0
        or a[DUR_SECONDS] >= 1000000000000.0
        or b[DUR_SECONDS] >= 1000000000000.0 {
        sa: int = dur_sign(a);
        sb: int = dur_sign(b);
        fields: list[any] = [
            DUR_WEEKS,
            DUR_DAYS,
            DUR_HOURS,
            DUR_MINUTES,
            DUR_SECONDS,
            DUR_NANOSECONDS
        ];
        i2: int = 0;
        while i2 < len(fields) {
            f2: int = fields[i2];
            va2: float = a[f2] * float(sa);
            vb2: float = b[f2] * float(sb);
            if va2 < vb2 {
                return -1;
            }
            if va2 > vb2 {
                return 1;
            }
            i2 = i2 + 1;
        }
        return 0;
    }
    ta2: int = _dur_total_ns_signed(a);
    tb2: int = _dur_total_ns_signed(b);
    if ta2 < tb2 {
        return -1;
    }
    if ta2 > tb2 {
        return 1;
    }
    return 0;
}

def:priv _dur_total_ns_signed(d: list[float]) -> int {
    sgn: int = dur_sign(d);
    days: int = int(d[DUR_DAYS]) + int(d[DUR_WEEKS]) * 7;
    sub: int = iso_total_nanoseconds(
        int(d[DUR_HOURS]),
        int(d[DUR_MINUTES]),
        int(d[DUR_SECONDS]),
        int(d[DUR_NANOSECONDS])
    );
    abs_total: int = days * 86400000000000 + sub;
    if sgn < 0 {
        return -abs_total;
    }
    return abs_total;
}

def:pub dur_identical(a: list[float], b: list[float]) -> bool {
    i: int = 0;
    while i <= DUR_SIGN {
        if a[i] != b[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def:pub dur_needs_relative_to(a: list[float], b: list[float]) -> bool {
    if dur_identical(a, b) {
        return False;
    }
    if a[DUR_YEARS] != 0.0 or b[DUR_YEARS] != 0.0 {
        return True;
    }
    if a[DUR_MONTHS] != 0.0 or b[DUR_MONTHS] != 0.0 {
        return True;
    }
    if a[DUR_WEEKS] != 0.0 or b[DUR_WEEKS] != 0.0 {
        return True;
    }
    return False;
}

"""Add signed duration to ISO YMD+hms (anchor). Returns [y, m, d, h, mi, s, ns]."""
def:pub dur_add_to_iso_ymd(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, dur: list[float]
) -> list[int] {
    sgn: float = 1.0;
    if dur[DUR_SIGN] < 0 {
        sgn = -1.0;
    }
    ymo: float = (dur[DUR_YEARS] * 12.0 + dur[DUR_MONTHS]) * sgn;
    if ymo != 0.0 {
        bal: list[int] = iso_add_months(y, m, d, int(ymo));
        y = bal[0];
        m = bal[1];
        d = bal[2];
    }
    day_delta: float = (dur[DUR_DAYS] + dur[DUR_WEEKS] * 7.0) * sgn;
    if day_delta != 0.0 {
        bal2: list[int] = iso_add_days(y, m, d, int(day_delta));
        y = bal2[0];
        m = bal2[1];
        d = bal2[2];
    }
    dh: int = int(dur[DUR_HOURS] * sgn);
    dmi: int = int(dur[DUR_MINUTES] * sgn);
    ds: int = int(dur[DUR_SECONDS] * sgn);
    dns: int = int(dur[DUR_NANOSECONDS] * sgn);
    if ds >= 86400 or ds <= -86400 {
        extra_d: int = ds // 86400;
        rem_s: int = ds - extra_d * 86400;
        if ds < 0 and rem_s != 0 {
            extra_d = extra_d - 1;
            rem_s = rem_s + 86400;
        }
        if extra_d > 500000000 or extra_d < -500000000 {
            vm_throw_native(make_range_error("invalid date"));
            return [0, 0, 0, 0, 0, 0, 0];
        }
        bal_ds: list[int] = iso_add_days(y, m, d, extra_d);
        y = bal_ds[0];
        m = bal_ds[1];
        d = bal_ds[2];
        ds = rem_s;
    }
    ta: list[int] = iso_add_time(h, mi, s, ns, dh, dmi, ds, dns);
    if ta[0] != 0 {
        bal3: list[int] = iso_add_days(y, m, d, ta[0]);
        y = bal3[0];
        m = bal3[1];
        d = bal3[2];
    }
    return [y, m, d, ta[1], ta[2], ta[3], ta[4]];
}

def _compare_iso_instant(a: list[int], b: list[int]) -> int {
    c: int = iso_compare(a[0], a[1], a[2], b[0], b[1], b[2]);
    if c != 0 {
        return c;
    }
    t1: int = iso_total_nanoseconds(a[3], a[4], a[5], a[6]);
    t2: int = iso_total_nanoseconds(b[3], b[4], b[5], b[6]);
    if t1 < t2 {
        return -1;
    }
    if t1 > t2 {
        return 1;
    }
    return 0;
}

def:priv _reject_invalid_relativeto_ymd(y: int, m: int, d: int) {
    if not iso_validate_relativeto_ymd(y, m, d) {
        vm_throw_native(make_range_error("invalid date"));
    }
}

def:pub dur_compare_relative(
    y: int,
    m: int,
    d: int,
    h: int,
    mi: int,
    sc: int,
    ns: int,
    a: list[float],
    b: list[float]
) -> int {
    ra: list[int] = dur_add_to_iso_ymd(y, m, d, h, mi, sc, ns, a);
    if vm_has_native_exc() {
        return 0;
    }
    rb: list[int] = dur_add_to_iso_ymd(y, m, d, h, mi, sc, ns, b);
    if vm_has_native_exc() {
        return 0;
    }
    _reject_invalid_relativeto_ymd(ra[0], ra[1], ra[2]);
    if vm_has_native_exc() {
        return 0;
    }
    _reject_invalid_relativeto_ymd(rb[0], rb[1], rb[2]);
    if vm_has_native_exc() {
        return 0;
    }
    return _compare_iso_instant(ra, rb);
}

def:pub dur_to_string(d: list[float]) -> str {
    sign: str = "";
    if d[DUR_SIGN] < 0 {
        sign = "-";
    }
    out: str = sign + "P";
    if d[DUR_YEARS] != 0.0 {
        out = out + _fmt_num(d[DUR_YEARS]) + "Y";
    }
    if d[DUR_MONTHS] != 0.0 {
        out = out + _fmt_num(d[DUR_MONTHS]) + "M";
    }
    if d[DUR_WEEKS] != 0.0 {
        out = out + _fmt_num(d[DUR_WEEKS]) + "W";
    }
    if d[DUR_DAYS] != 0.0 {
        out = out + _fmt_num(d[DUR_DAYS]) + "D";
    }
    has_time: bool = d[DUR_HOURS] != 0.0
        or d[DUR_MINUTES] != 0.0
        or d[DUR_SECONDS] != 0.0
        or d[DUR_NANOSECONDS] != 0.0;
    if has_time {
        out = out + "T";
        if d[DUR_HOURS] != 0.0 {
            out = out + _fmt_num(d[DUR_HOURS]) + "H";
        }
        if d[DUR_MINUTES] != 0.0 {
            out = out + _fmt_num(d[DUR_MINUTES]) + "M";
        }
        if d[DUR_SECONDS] != 0.0 or d[DUR_NANOSECONDS] != 0.0 {
            # Normalize seconds + sub-second into whole-seconds + [0,1e9) nanoseconds so the
            # fraction formats from integers (no float scientific-notation like "3.5e-06",
            # no precision loss beyond 2^53). A fractional DUR_SECONDS (unbalanced input)
            # is folded into the nanosecond bucket first.
            out = out + _dur_format_seconds_field(d[DUR_SECONDS], d[DUR_NANOSECONDS]);
            out = out + "S";
        }
    }
    if out == sign + "P" {
        out = "PT0S";
    }
    return out;
}

def _fmt_num(v: float) -> str {
    if v == float(int(v)) {
        return str(int(v));
    }
    return str(v);
}

# "SS" or "SS.fffffffff" (trailing zeros trimmed) for the seconds field of a Duration
# string. `secs`/`subns` are the (sign-stripped magnitude of the) SECONDS and sub-second
# NANOSECONDS. A fractional `secs` (unbalanced duration) contributes its fraction to the
# nanosecond bucket; the whole seconds and 9-digit fraction then format from integers.
def:priv _dur_format_seconds_field(secs: float, subns: float) -> str {
    a_secs: float = secs;
    if a_secs < 0.0 {
        a_secs = -a_secs;
    }
    a_ns: float = subns;
    if a_ns < 0.0 {
        a_ns = -a_ns;
    }
    whole_f: float = float(int(a_secs));
    frac_secs: float = a_secs - whole_f;
    # Total sub-second nanoseconds = fraction-of-seconds*1e9 + the ns bucket.
    total_ns: float = frac_secs * 1000000000.0 + a_ns;
    extra_s: float = float(int(total_ns / 1000000000.0));
    whole_f = whole_f + extra_s;
    ns_i: int = int(total_ns - extra_s * 1000000000.0);
    whole: str = _fmt_num(whole_f);
    if ns_i == 0 {
        return whole;
    }
    frac_part: str = _dur_trim_trailing_zeros(_dur_pad_left(str(ns_i), 9));
    if len(frac_part) == 0 {
        return whole;
    }
    return whole + "." + frac_part;
}

def:pub _dur_pow10(n: int) -> int {
    r: int = 1;
    i: int = 0;
    while i < n {
        r = r * 10;
        i = i + 1;
    }
    return r;
}

def:priv _dur_trim_trailing_zeros(s: str) -> str {
    while len(s) > 0 and s[len(s) - 1:len(s)] == "0" {
        s = s[0:len(s) - 1];
    }
    return s;
}

def:priv _dur_pad_left(s: str, n: int) -> str {
    while len(s) < n {
        s = "0" + s;
    }
    return s;
}

"""Format a balanced duration with TemporalDurationToString precision rules."""
def:pub dur_to_string_with_options(
    d: list[float], smallest_unit: str, frac_digits: int, explicit_smallest: bool
) -> str {
    sign: str = "";
    if d[DUR_SIGN] < 0 {
        sign = "-";
    }
    y: float = d[DUR_YEARS];
    mo: float = d[DUR_MONTHS];
    w: float = d[DUR_WEEKS];
    day: float = d[DUR_DAYS];
    h: float = d[DUR_HOURS];
    mi: float = d[DUR_MINUTES];
    s: float = d[DUR_SECONDS];
    sub_ns: float = d[DUR_NANOSECONDS];
    if sub_ns < 0.0 {
        sub_ns = -sub_ns;
    }
    if s < 0.0 {
        s = -s;
    }
    out: str = sign + "P";
    if y != 0.0 {
        out = out + _fmt_num(y) + "Y";
    }
    if mo != 0.0 {
        out = out + _fmt_num(mo) + "M";
    }
    if w != 0.0 {
        out = out + _fmt_num(w) + "W";
    }
    if day != 0.0 {
        out = out + _fmt_num(day) + "D";
    }
    date_all_zero: bool = y == 0.0 and mo == 0.0 and w == 0.0 and day == 0.0;
    time_date_zero: bool = date_all_zero and h == 0.0 and mi == 0.0;
    sub_nonzero: bool = s != 0.0 or sub_ns != 0.0;
    precision_not_auto: bool = frac_digits >= 0;
    subsecond_unit: bool = smallest_unit == "millisecond"
        or smallest_unit == "microsecond"
        or smallest_unit == "nanosecond";
    second_unit: bool = smallest_unit == "second";
    show_seconds: bool = sub_nonzero
        or time_date_zero
        or precision_not_auto
        or subsecond_unit
        or (explicit_smallest and second_unit);
    has_time: bool = h != 0.0 or mi != 0.0 or show_seconds;
    if has_time {
        out = out + "T";
        if h != 0.0 {
            out = out + _fmt_num(h) + "H";
        }
        if mi != 0.0 {
            out = out + _fmt_num(mi) + "M";
        }
        if show_seconds {
            sec_str: str = _fmt_num(s);
            frac_str: str = "";
            if frac_digits >= 0 {
                scale: int = _dur_pow10(frac_digits);
                scaled: int = int(s) * scale;
                if frac_digits > 0 {
                    frac_ns: int = int(sub_ns) // _dur_pow10(9 - frac_digits);
                    scaled = scaled + frac_ns;
                }
                if frac_digits == 0 {
                    sec_str = str(scaled);
                } else {
                    sec_str = str(scaled // scale);
                    frac_str = _dur_pad_left(str(scaled % scale), frac_digits);
                }
            } elif smallest_unit == "second" {
                sec_str = _fmt_num(s);
            } elif smallest_unit == "millisecond" {
                ms: int = int(sub_ns) // 1000000;
                sec_str = _fmt_num(s);
                if ms == 0 {
                    frac_str = "000";
                } else {
                    frac_str = _dur_pad_left(str(ms), 3);
                }
            } elif smallest_unit == "microsecond" {
                us: int = int(sub_ns) // 1000;
                sec_str = _fmt_num(s);
                if us == 0 {
                    frac_str = "000000";
                } else {
                    frac_str = _dur_pad_left(str(us), 6);
                }
            } elif smallest_unit == "nanosecond" {
                ns: int = int(sub_ns);
                sec_str = _fmt_num(s);
                if ns == 0 {
                    frac_str = "000000000";
                } else {
                    frac_str = _dur_trim_trailing_zeros(_dur_pad_left(str(ns), 9));
                }
            } else {
                # auto precision, no explicit smallestUnit: whole seconds + trimmed
                # sub-second fraction (from integers, no scientific notation).
                out = out + _dur_format_seconds_field(s, sub_ns);
                out = out + "S";
                sec_str = "";
            }
            if len(sec_str) > 0 {
                out = out + sec_str;
                if len(frac_str) > 0 {
                    out = out + "." + frac_str;
                }
                out = out + "S";
            }
        }
    }
    if out == sign + "P" {
        out = sign + "PT0S";
    }
    return out;
}

def:pub dur_validate_sign(d: list[float]) -> bool {
    has_pos: bool = False;
    has_neg: bool = False;
    i: int = 0;
    while i <= DUR_NANOSECONDS {
        if d[i] > 0.0 {
            has_pos = True;
        }
        if d[i] < 0.0 {
            has_neg = True;
        }
        i = i + 1;
    }
    if has_pos and has_neg {
        return False;
    }
    return True;
}

"""IsValidDuration bounds check (ES §): each component must be below its maximum
(years/months/weeks < 2^32; days/hours/… bounded so the total stays within ±2^53 ms).
Throws a RangeError otherwise. Used after difference-rounding, where a large
roundingIncrement can push a component out of range (since/until throws-if-rounded-*)."""
def:pub dur_reject_out_of_range(d: list[float]) -> None {
    lim_ymw: float = 4294967296.0;
    lim_d: float = 104249991375.0;
    lim_h: float = 2501999792984.0;
    lim_mi: float = 150119987579017.0;
    lim_s: float = 9007199254740992.0;
    if _float_abs(d[DUR_YEARS]) >= lim_ymw
        or _float_abs(d[DUR_MONTHS]) >= lim_ymw
        or _float_abs(d[DUR_WEEKS]) >= lim_ymw {
        vm_throw_native(make_range_error("duration is out of range"));
        return;
    }
    if _float_abs(d[DUR_DAYS]) >= lim_d
        or _float_abs(d[DUR_HOURS]) >= lim_h
        or _float_abs(d[DUR_MINUTES]) >= lim_mi
        or _float_abs(d[DUR_SECONDS]) >= lim_s {
        vm_throw_native(make_range_error("duration is out of range"));
        return;
    }
}

def:priv _unit_level(unit: str) -> int {
    if unit == "year" or unit == "years" {
        return 8;
    }
    if unit == "month" or unit == "months" {
        return 7;
    }
    if unit == "week" or unit == "weeks" {
        return 6;
    }
    if unit == "day" or unit == "days" {
        return 5;
    }
    if unit == "hour" or unit == "hours" {
        return 4;
    }
    if unit == "minute" or unit == "minutes" {
        return 3;
    }
    if unit == "second" or unit == "seconds" {
        return 2;
    }
    if unit == "millisecond" or unit == "milliseconds" {
        return 1;
    }
    if unit == "microsecond" or unit == "microseconds" {
        return 0;
    }
    if unit == "nanosecond" or unit == "nanoseconds" {
        return -1;
    }
    return -2;
}

"""True when `d` has no non-zero component SMALLER than `unit` — i.e. rounding to
`unit` with increment 1 would leave `d` unchanged. Used to skip RoundDuration's
total-and-rebuild (which flattens a calendar breakdown) when it would be a no-op."""
def:pub _dur_no_subunit_remainder(d: list[float], unit: str) -> bool {
    lvl: int = _unit_level(unit);
    # Each guard fires when `unit` is strictly larger than that field's unit.
    if lvl > 4 and d[DUR_HOURS] != 0.0 {
        return False;
    }
    if lvl > 3 and d[DUR_MINUTES] != 0.0 {
        return False;
    }
    if lvl > 2 and d[DUR_SECONDS] != 0.0 {
        return False;
    }
    # DUR_NANOSECONDS holds the WHOLE sub-second remainder (0..999,999,999), not just the
    # nanosecond digit. For a second-or-coarser unit ANY nonzero value is a remainder; for
    # millisecond/microsecond only the digits BELOW that unit count (ns % 1e6 / % 1e3).
    ns_field: int = int(d[DUR_NANOSECONDS]);
    if lvl >= 2 {
        if ns_field != 0 {
            return False;
        }
    } elif lvl == 1 {
        if ns_field % 1000000 != 0 {
            return False;
        }
    } elif lvl == 0 {
        if ns_field % 1000 != 0 {
            return False;
        }
    }
    # Day is the smallest calendar unit (level 5); weeks (6) sit between day and month.
    if lvl > 5 and d[DUR_DAYS] != 0.0 {
        return False;
    }
    if lvl > 6 and d[DUR_WEEKS] != 0.0 {
        return False;
    }
    if lvl > 7 and d[DUR_MONTHS] != 0.0 {
        return False;
    }
    return True;
}

"""DefaultTemporalLargestUnit — largest non-zero unit, else nanosecond."""
def:pub dur_default_largest_unit(d: list[float]) -> str {
    if d[DUR_YEARS] != 0.0 {
        return "year";
    }
    if d[DUR_MONTHS] != 0.0 {
        return "month";
    }
    if d[DUR_WEEKS] != 0.0 {
        return "week";
    }
    if d[DUR_DAYS] != 0.0 {
        return "day";
    }
    if d[DUR_HOURS] != 0.0 {
        return "hour";
    }
    if d[DUR_MINUTES] != 0.0 {
        return "minute";
    }
    if d[DUR_SECONDS] != 0.0 {
        return "second";
    }
    ns: float = d[DUR_NANOSECONDS];
    if ns == 0.0 {
        return "nanosecond";
    }
    abs_ns: float = ns;
    if abs_ns < 0.0 {
        abs_ns = -abs_ns;
    }
    if abs_ns % 1000000.0 == 0.0 {
        return "millisecond";
    }
    if abs_ns % 1000.0 == 0.0 {
        return "microsecond";
    }
    return "nanosecond";
}

"""LargerOfTwoTemporalUnits."""
def:pub dur_larger_unit(u1: str, u2: str) -> str {
    if _unit_level(u1) >= _unit_level(u2) {
        return u1;
    }
    return u2;
}

"""True when unit is year/month/week (calendar units needing relativeTo)."""
def:pub dur_is_calendar_unit(unit: str) -> bool {
    return _dur_is_calendar_unit(unit);
}

"""MaximumTemporalDurationRoundingIncrement; -1 means unset (no maximum)."""
def:pub dur_max_rounding_increment(unit: str) -> int {
    if unit == "hour" or unit == "hours" {
        return 24;
    }
    if unit == "minute" or unit == "minutes" {
        return 60;
    }
    if unit == "second" or unit == "seconds" {
        return 60;
    }
    if unit == "millisecond" or unit == "milliseconds" {
        return 1000;
    }
    if unit == "microsecond" or unit == "microseconds" {
        return 1000;
    }
    if unit == "nanosecond" or unit == "nanoseconds" {
        return 1000;
    }
    return -1;
}

"""ValidateTemporalRoundingIncrement(increment, dividend, inclusive=false)."""
def:pub dur_validate_rounding_increment(
    increment: int, maximum: int, inclusive: bool
) -> None {
    if maximum < 0 {
        return;
    }
    if inclusive {
        if increment > maximum {
            vm_throw_native(make_range_error("invalid roundingIncrement"));
            return;
        }
    } else {
        if increment >= maximum {
            vm_throw_native(make_range_error("invalid roundingIncrement"));
            return;
        }
    }
    if maximum % increment != 0 {
        vm_throw_native(make_range_error("invalid roundingIncrement"));
    }
}

"""
Express a duration relative to an anchor using largestUnit (add then until).
Used after Duration.round collapses to smallestUnit totals.
prefer_weeks: when smallestUnit is week, keep week remainder under year/month.
"""
def:pub dur_express_relative(
    d: list[float],
    largest: str,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    return dur_express_relative_ex(d, largest, y, m, day, h, mi, s, ns, False);
}

def:pub dur_express_relative_ex(
    d: list[float],
    largest: str,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int,
    prefer_weeks: bool
) -> list[float] {
    end: list[int] = dur_add_to_iso_ymd(y, m, day, h, mi, s, ns, d);
    if vm_has_native_exc() {
        return d;
    }
    days: int = dur_until_days(y, m, day, end[0], end[1], end[2]);
    t0: int = iso_total_nanoseconds(h, mi, s, ns);
    t1: int = iso_total_nanoseconds(end[3], end[4], end[5], end[6]);
    # Signed elapsed; split into same-sign day/time via absolute value.
    elapsed_ns: int = days * 86400000000000 + (t1 - t0);
    sign_el: float = 1.0;
    abs_el: int = elapsed_ns;
    if abs_el < 0 {
        sign_el = -1.0;
        abs_el = -abs_el;
    }
    days = abs_el // 86400000000000;
    time_ns: int = abs_el % 86400000000000;
    lvl: int = _unit_level(largest);
    if lvl >= 8 {
        return _dur_rebalance_calendar_weeks(d, y, m, day, h, mi, s, ns, prefer_weeks);
    }
    if lvl == 7 {
        # months as largest — fold years into months
        bal: list[float] = _dur_rebalance_calendar_weeks(
            d, y, m, day, h, mi, s, ns, prefer_weeks
        );
        bal[DUR_MONTHS] = bal[DUR_MONTHS] + bal[DUR_YEARS] * 12.0;
        bal[DUR_YEARS] = 0.0;
        return _dur_normalize_sign(bal);
    }
    if lvl == 6 {
        # weeks + leftover days + time
        w: int = days // 7;
        rem_d: int = days % 7;
        hh: int = time_ns // 3600000000000;
        rem: int = time_ns % 3600000000000;
        mmi: int = rem // 60000000000;
        rem2: int = rem % 60000000000;
        sc: int = rem2 // 1000000000;
        n: int = rem2 % 1000000000;
        out_w: list[float] = dur_from_components(
            0.0, 0.0, float(w), float(rem_d), float(hh), float(mmi), float(sc), float(n)
        );
        out_w[DUR_SIGN] = sign_el;
        return _dur_normalize_sign(out_w);
    }
    if lvl == 5 {
        hh2: int = time_ns // 3600000000000;
        rem3: int = time_ns % 3600000000000;
        mmi2: int = rem3 // 60000000000;
        rem4: int = rem3 % 60000000000;
        sc2: int = rem4 // 1000000000;
        n2: int = rem4 % 1000000000;
        out_d: list[float] = dur_from_components(
            0.0, 0.0, 0.0, float(days), float(hh2), float(mmi2), float(sc2), float(n2)
        );
        out_d[DUR_SIGN] = sign_el;
        return _dur_normalize_sign(out_d);
    }
    # Time largest unit: fold days into hours etc.
    full_ns: int = elapsed_ns;
    sign_t: float = 1.0;
    abs_ns: int = full_ns;
    if abs_ns < 0 {
        sign_t = -1.0;
        abs_ns = -abs_ns;
    }
    lim: list[float] = dur_from_components(
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, float(abs_ns)
    );
    lim[DUR_SIGN] = sign_t;
    return dur_limit_largest_unit(lim, largest, False, 0, 0, 0, 0, 0, 0, 0);
}

"""Round integer v to a multiple of step with Temporal rounding mode."""
def:priv _round_int_to_step(v: int, step: int, mode: int) -> int {
    if step <= 1 {
        return v;
    }
    if v >= 0 {
        q: int = v // step;
        r: int = v % step;
        if r == 0 {
            return v;
        }
        if mode == ROUND_TRUNC or mode == ROUND_FLOOR {
            return q * step;
        }
        if mode == ROUND_CEIL or mode == ROUND_EXPAND {
            return (q + 1) * step;
        }
        # half* modes
        half: int = step // 2;
        if r * 2 < step {
            return q * step;
        }
        if r * 2 > step {
            return (q + 1) * step;
        }
        # exact half
        if mode == ROUND_HALF_TRUNC or mode == ROUND_HALF_FLOOR {
            return q * step;
        }
        if mode == ROUND_HALF_CEIL or mode == ROUND_HALF_EXPAND {
            return (q + 1) * step;
        }
        if mode == ROUND_HALF_EVEN {
            if q % 2 == 0 {
                return q * step;
            }
            return (q + 1) * step;
        }
        return (q + 1) * step;
    }
    # negative
    av: int = -v;
    q2: int = av // step;
    r2: int = av % step;
    if r2 == 0 {
        return v;
    }
    if mode == ROUND_TRUNC or mode == ROUND_CEIL {
        return -(q2 * step);
    }
    if mode == ROUND_FLOOR or mode == ROUND_EXPAND {
        return -((q2 + 1) * step);
    }
    if r2 * 2 < step {
        return -(q2 * step);
    }
    if r2 * 2 > step {
        return -((q2 + 1) * step);
    }
    if mode == ROUND_HALF_TRUNC or mode == ROUND_HALF_CEIL {
        return -(q2 * step);
    }
    if mode == ROUND_HALF_FLOOR or mode == ROUND_HALF_EXPAND {
        return -((q2 + 1) * step);
    }
    if mode == ROUND_HALF_EVEN {
        if q2 % 2 == 0 {
            return -(q2 * step);
        }
        return -((q2 + 1) * step);
    }
    return -((q2 + 1) * step);
}

"""Decompose signed elapsed nanoseconds into a duration limited by largestUnit."""
def:priv _dur_decompose_elapsed_ns(elapsed_ns: int, largest: str) -> list[float] {
    sign: float = 1.0;
    rem: int = elapsed_ns;
    if rem < 0 {
        sign = -1.0;
        rem = -rem;
    }
    lvl: int = _unit_level(largest);
    days: float = 0.0;
    hh: float = 0.0;
    mmi: float = 0.0;
    sc: float = 0.0;
    n: float = 0.0;
    if lvl >= 5 {
        days = float(rem // 86400000000000);
        rem = rem % 86400000000000;
    }
    if lvl >= 4 {
        hh = float(rem // 3600000000000);
        rem = rem % 3600000000000;
    }
    if lvl >= 3 {
        mmi = float(rem // 60000000000);
        rem = rem % 60000000000;
    }
    if lvl >= 2 {
        sc = float(rem // 1000000000);
        rem = rem % 1000000000;
    } elif lvl <= 1 {
        # Sub-second largestUnit: keep whole seconds in DUR_SECONDS (fits float
        # exactly for Temporal ranges) and only the <1e9 rem in ns — avoids
        # stuffing multi-year spans into float DUR_NANOSECONDS (>2^53).
        sc = float(rem // 1000000000);
        rem = rem % 1000000000;
    }
    n = float(rem);
    out: list[float] = dur_from_components(0.0, 0.0, 0.0, days, hh, mmi, sc, n);
    out[DUR_SIGN] = sign;
    return _dur_normalize_sign(out);
}

"""
Round the smallest calendar/day field of an already-balanced duration.
Higher units are left unchanged; lower units fold into the fractional part.
"""
def:priv _dur_round_calendar_fields(
    d: list[float],
    smallest: str,
    inc: float,
    mode: int,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    sgn: float = 1.0;
    if d[DUR_SIGN] < 0.0 {
        sgn = -1.0;
    }
    if smallest == "year" or smallest == "years" {
        tot: float = dur_total_relative(d, "year", y, m, day, h, mi, s, ns);
        rnd: float = _round_to_increment(tot, inc, mode);
        return dur_from_unit_total(rnd, "year");
    }
    if smallest == "month" or smallest == "months" {
        # Keep years; round months (+ days/time fraction) then bubble to years.
        y_signed: int = int(d[DUR_YEARS] * sgn);
        mid: list[int] = iso_add_months(y, m, day, y_signed * 12);
        rest: list[float] = dur_from_components(
            0.0,
            d[DUR_MONTHS],
            d[DUR_WEEKS],
            d[DUR_DAYS],
            d[DUR_HOURS],
            d[DUR_MINUTES],
            d[DUR_SECONDS],
            d[DUR_NANOSECONDS]
        );
        rest[DUR_SIGN] = sgn;
        tot_m: float = dur_total_relative(
            rest, "month", mid[0], mid[1], mid[2], h, mi, s, ns
        );
        rnd_m: float = _round_to_increment(tot_m, inc, mode);
        # years + rounded months as a single month count, then split.
        total_mo: float = d[DUR_YEARS] * 12.0 * sgn + rnd_m;
        out_sign: float = 1.0;
        abs_mo: float = total_mo;
        if abs_mo < 0.0 {
            out_sign = -1.0;
            abs_mo = -abs_mo;
        }
        bub_y: float = float(int(abs_mo) // 12);
        bub_m: float = float(int(abs_mo) % 12);
        # Handle non-integer month totals from exotic increments.
        if abs_mo != float(int(abs_mo)) {
            bub_y = float(int(abs_mo) // 12);
            bub_m = abs_mo - bub_y * 12.0;
        }
        out_m: list[float] = dur_from_components(
            bub_y, bub_m, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
        );
        out_m[DUR_SIGN] = out_sign;
        return _dur_normalize_sign(out_m);
    }
    if smallest == "week" or smallest == "weeks" {
        frac_days: float = d[DUR_DAYS];
        frac_days = frac_days + d[DUR_HOURS] / 24.0;
        frac_days = frac_days + d[DUR_MINUTES] / 1440.0;
        frac_days = frac_days + d[DUR_SECONDS] / 86400.0;
        frac_days = frac_days + d[DUR_NANOSECONDS] / 86400000000000.0;
        signed_w: float = sgn * (d[DUR_WEEKS] + frac_days / 7.0);
        rnd_w: float = _round_to_increment(signed_w, inc, mode);
        # Preserve higher calendar units with the duration sign; only the week
        # field is replaced by the rounded value.
        out_sign_w: float = sgn;
        aw: float = rnd_w;
        if aw < 0.0 {
            out_sign_w = -1.0;
            aw = -aw;
        } elif aw > 0.0 {
            out_sign_w = 1.0;
        } elif d[DUR_YEARS] != 0.0 or d[DUR_MONTHS] != 0.0 {
            out_sign_w = sgn;
        } else {
            out_sign_w = 1.0;
        }
        out_w: list[float] = dur_from_components(
            d[DUR_YEARS], d[DUR_MONTHS], aw, 0.0, 0.0, 0.0, 0.0, 0.0
        );
        out_w[DUR_SIGN] = out_sign_w;
        return _dur_normalize_sign(out_w);
    }
    # day
    frac_d: float = d[DUR_DAYS];
    frac_d = frac_d + d[DUR_HOURS] / 24.0;
    frac_d = frac_d + d[DUR_MINUTES] / 1440.0;
    frac_d = frac_d + d[DUR_SECONDS] / 86400.0;
    frac_d = frac_d + d[DUR_NANOSECONDS] / 86400000000000.0;
    signed_d: float = sgn * frac_d;
    rnd_d: float = _round_to_increment(signed_d, inc, mode);
    out_sign_d: float = sgn;
    ad: float = rnd_d;
    if ad < 0.0 {
        out_sign_d = -1.0;
        ad = -ad;
    } elif ad > 0.0 {
        out_sign_d = 1.0;
    } elif d[DUR_YEARS] != 0.0 or d[DUR_MONTHS] != 0.0 or d[DUR_WEEKS] != 0.0 {
        out_sign_d = sgn;
    } else {
        out_sign_d = 1.0;
    }
    out_d: list[float] = dur_from_components(
        d[DUR_YEARS], d[DUR_MONTHS], d[DUR_WEEKS], ad, 0.0, 0.0, 0.0, 0.0
    );
    out_d[DUR_SIGN] = out_sign_d;
    return _dur_normalize_sign(out_d);
}

"""
RoundDuration for Duration.prototype.round:
With relativeTo, prefer add→until (avoids float ns precision loss on calendar
durations). Otherwise total→round at smallestUnit, then limit to largestUnit.
"""
def:pub dur_round_duration(
    d: list[float],
    smallest: str,
    largest: str,
    increment: int,
    mode: int,
    has_anchor: bool,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    inc: float = float(increment);
    if inc <= 0.0 {
        inc = 1.0;
    }
    small_lvl: int = _unit_level(smallest);
    large_lvl: int = _unit_level(largest);

    if has_anchor {
        prefer_weeks: bool = (small_lvl == 6) or (large_lvl == 6);
        # Calendar / day smallestUnit relative to anchor.
        if small_lvl >= 5 {
            if large_lvl > small_lvl {
                # Spec-shaped path: balance to largestUnit first, then round the
                # smallestUnit field (keeps higher calendar units stable).
                # Include weeks only when rounding weeks or largestUnit is week.
                use_weeks: bool = (small_lvl == 6) or (large_lvl == 6);
                raw_c: list[float] = dur_express_relative_ex(
                    d, largest, y, m, day, h, mi, s, ns, use_weeks
                );
                if vm_has_native_exc() {
                    return d;
                }
                return _dur_round_calendar_fields(
                    raw_c, smallest, inc, mode, y, m, day, h, mi, s, ns
                );
            }
            # largestUnit == smallestUnit: total → round → express.
            total_c: float = dur_total_relative(d, smallest, y, m, day, h, mi, s, ns);
            rounded_c: float = _round_to_increment(total_c, inc, mode);
            out_c: list[float] = dur_from_unit_total(rounded_c, smallest);
            return dur_express_relative_ex(
                out_c, largest, y, m, day, h, mi, s, ns, prefer_weeks
            );
        }
        # Time smallestUnit: difference at largestUnit, then round time fields.
        raw: list[float] = dur_express_relative_ex(
            d, largest, y, m, day, h, mi, s, ns, False
        );
        if vm_has_native_exc() {
            return d;
        }
        if large_lvl >= 5 {
            time_d: list[float] = dur_from_components(
                0.0,
                0.0,
                0.0,
                0.0,
                raw[DUR_HOURS],
                raw[DUR_MINUTES],
                raw[DUR_SECONDS],
                raw[DUR_NANOSECONDS]
            );
            time_d[DUR_SIGN] = raw[DUR_SIGN];
            rt: list[float] = dur_round(time_d, smallest, increment, mode);
            # Days bubbled from time rounding fold into the date duration.
            days_b: float = raw[DUR_DAYS] + rt[DUR_DAYS];
            comb: list[float] = dur_from_components(
                raw[DUR_YEARS],
                raw[DUR_MONTHS],
                raw[DUR_WEEKS],
                days_b,
                rt[DUR_HOURS],
                rt[DUR_MINUTES],
                rt[DUR_SECONDS],
                rt[DUR_NANOSECONDS]
            );
            comb[DUR_SIGN] = raw[DUR_SIGN];
            if days_b != raw[DUR_DAYS] and large_lvl > 5 {
                return dur_express_relative_ex(
                    comb, largest, y, m, day, h, mi, s, ns, False
                );
            }
            return _dur_normalize_sign(comb);
        }
        # largestUnit is a time unit — integer elapsed ns, then decompose by largest
        # without stuffing the whole span into a float DUR_NANOSECONDS (precision).
        end_t: list[int] = dur_add_to_iso_ymd(y, m, day, h, mi, s, ns, d);
        if vm_has_native_exc() {
            return d;
        }
        dd_t: int = dur_until_days(y, m, day, end_t[0], end_t[1], end_t[2]);
        t0_t: int = iso_total_nanoseconds(h, mi, s, ns);
        t1_t: int = iso_total_nanoseconds(end_t[3], end_t[4], end_t[5], end_t[6]);
        elapsed_ns: int = dd_t * 86400000000000 + (t1_t - t0_t);
        unit_ns: int = 1;
        if smallest == "hour" or smallest == "hours" {
            unit_ns = 3600000000000;
        } elif smallest == "minute" or smallest == "minutes" {
            unit_ns = 60000000000;
        } elif smallest == "second" or smallest == "seconds" {
            unit_ns = 1000000000;
        } elif smallest == "millisecond" or smallest == "milliseconds" {
            unit_ns = 1000000;
        } elif smallest == "microsecond" or smallest == "microseconds" {
            unit_ns = 1000;
        }
        step: int = unit_ns * increment;
        if step < 1 {
            step = 1;
        }
        # Integer rounding — float(elapsed_ns) loses low bits above 2^53.
        rounded_ns: int = _round_int_to_step(elapsed_ns, step, mode);
        return _dur_decompose_elapsed_ns(rounded_ns, largest);
    }

    total: float = dur_total(d, smallest);
    rounded: float = _round_to_increment(total, inc, mode);
    out: list[float] = dur_from_unit_total(rounded, smallest);
    return dur_limit_largest_unit(out, largest, False, 0, 0, 0, 0, 0, 0, 0);
}

def:priv _dur_decompose_ns(abs_ns: int, max_level: int) -> list[float] {
    h: int = 0;
    mi: int = 0;
    sc: int = 0;
    n: int = 0;
    ms: int = 0;
    us: int = 0;
    rem: int = abs_ns;
    if max_level <= 4 {
        h = rem // 3600000000000;
        rem = rem % 3600000000000;
    }
    if max_level <= 3 {
        mi = rem // 60000000000;
        rem = rem % 60000000000;
    }
    if max_level <= 2 {
        sc = rem // 1000000000;
        rem = rem % 1000000000;
    }
    if max_level <= 1 {
        ms = rem // 1000000;
        rem = rem % 1000000;
    }
    if max_level <= 0 {
        us = rem // 1000;
        rem = rem % 1000;
    }
    if max_level <= -1 {
        n = rem;
    } else {
        n = rem;
    }
    return [float(h), float(mi), float(sc), float(n)];
}

def:pub dur_limit_largest_unit(
    d: list[float],
    largest: str,
    has_anchor: bool,
    y: int,
    m: int,
    day: int,
    h: int,
    mi: int,
    s: int,
    ns: int
) -> list[float] {
    if largest == "auto" {
        return d;
    }
    lvl: int = _unit_level(largest);
    sign: int = dur_sign(d);
    out: list[float] = dur_from_components(
        d[DUR_YEARS],
        d[DUR_MONTHS],
        d[DUR_WEEKS],
        d[DUR_DAYS],
        d[DUR_HOURS],
        d[DUR_MINUTES],
        d[DUR_SECONDS],
        d[DUR_NANOSECONDS]
    );
    out[DUR_SIGN] = d[DUR_SIGN];
    if has_anchor and (out[DUR_YEARS] != 0.0 or out[DUR_MONTHS] != 0.0) {
        out = _dur_rebalance_calendar(out, y, m, day, h, mi, s, ns);
        if vm_has_native_exc() {
            return d;
        }
    }
    # With an anchor date, `_dur_rebalance_calendar` above already produced a proper
    # calendar breakdown for the requested largestUnit (BalanceDateDurationRelative):
    # years/months are whole, months < 12, and the day/time remainder is kept intact.
    # A `largestUnit:"years"` since/until must stay 3Y 6M 17D — never collapse the
    # smaller fields into a fractional year/month. That fractional collapse is only
    # correct WITHOUT an anchor (a reference-free balance that cannot express a
    # calendar breakdown), so it is gated on `not has_anchor` below.
    if lvl == 7 {
        if has_anchor {
            # largestUnit "month": years are not permitted, so fold them into months
            # (iso8601: 12 months per year) but KEEP the whole week/day/time remainder
            # the calendar rebalance produced. Only years collapse — not the tail.
            out[DUR_MONTHS] = out[DUR_MONTHS] + out[DUR_YEARS] * 12.0;
            out[DUR_YEARS] = 0.0;
            return _dur_normalize_sign(out);
        }
        out[DUR_MONTHS] = out[DUR_MONTHS] + out[DUR_YEARS] * 12.0;
        out[DUR_YEARS] = 0.0;
        out[DUR_WEEKS] = 0.0;
        out[DUR_DAYS] = 0.0;
        out[DUR_HOURS] = 0.0;
        out[DUR_MINUTES] = 0.0;
        out[DUR_SECONDS] = 0.0;
        out[DUR_NANOSECONDS] = 0.0;
        return _dur_normalize_sign(out);
    }
    if lvl == 8 {
        if has_anchor {
            return _dur_normalize_sign(out);
        }
        out[DUR_YEARS] = out[DUR_YEARS] + out[DUR_MONTHS] / 12.0;
        out[DUR_MONTHS] = 0.0;
        out[DUR_WEEKS] = 0.0;
        out[DUR_DAYS] = 0.0;
        out[DUR_HOURS] = 0.0;
        out[DUR_MINUTES] = 0.0;
        out[DUR_SECONDS] = 0.0;
        out[DUR_NANOSECONDS] = 0.0;
        return _dur_normalize_sign(out);
    }
    if lvl < 6 and out[DUR_WEEKS] != 0.0 {
        # Fold weeks into days when largestUnit is day or smaller.
        out[DUR_DAYS] = out[DUR_DAYS] + out[DUR_WEEKS] * 7.0;
        out[DUR_WEEKS] = 0.0;
    }
    if lvl == 6 {
        # largestUnit = week: keep weeks + leftover days; balance time only.
        if out[DUR_DAYS] >= 7.0 or out[DUR_DAYS] <= -7.0 {
            w_add: int = int(out[DUR_DAYS]) // 7;
            out[DUR_WEEKS] = out[DUR_WEEKS] + float(w_add);
            out[DUR_DAYS] = out[DUR_DAYS] - float(w_add) * 7.0;
        }
        bal_w: list[float] = dur_balance_time(out);
        # Time may spill days; fold those into weeks.
        if bal_w[DUR_DAYS] >= 7.0 {
            w2: int = int(bal_w[DUR_DAYS]) // 7;
            bal_w[DUR_WEEKS] = bal_w[DUR_WEEKS] + float(w2);
            bal_w[DUR_DAYS] = bal_w[DUR_DAYS] - float(w2) * 7.0;
        }
        return _dur_normalize_sign(bal_w);
    }
    if lvl == 5 {
        # largestUnit = day: fold time into days via full balance.
        return _dur_normalize_sign(dur_balance(out));
    }
    days: float = out[DUR_DAYS];
    # largestUnit is a SUB-SECOND unit (millisecond/microsecond/nanosecond, lvl < 2):
    # nothing above the second is kept, so the total collapses into the nanosecond
    # field. Stay in FLOAT space — the ns field can hold the whole span (e.g. 1.8e19),
    # and int() of a value beyond 2^63 would overflow / blow up allocation. The
    # subsecond builder (js_duration_create_unbalanced_subseconds) re-derives ms/µs/ns.
    if lvl < 2 {
        total_sub_ns: float = out[DUR_NANOSECONDS]
            + out[DUR_SECONDS] * 1000000000.0
            + out[DUR_MINUTES] * 60000000000.0
            + out[DUR_HOURS] * 3600000000000.0
            + days * 86400000000000.0;
        lim_sub: list[float] = dur_from_components(
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, total_sub_ns
        );
        if sign < 0 {
            lim_sub[DUR_SIGN] = -1.0;
        }
        return _dur_normalize_sign(lim_sub);
    }
    time_ns: int = iso_total_nanoseconds(
        int(out[DUR_HOURS]),
        int(out[DUR_MINUTES]),
        int(out[DUR_SECONDS]),
        int(out[DUR_NANOSECONDS])
    );
    full_ns: int = int(days) * 86400000000000 + time_ns;
    if sign < 0 {
        full_ns = -full_ns;
    }
    abs_ns: int = full_ns;
    if abs_ns < 0 {
        abs_ns = -abs_ns;
    }
    rem_ns: int = abs_ns;
    hh: int = 0;
    mmi: int = 0;
    sc: int = 0;
    n: int = 0;
    # Fill only units at or below largestUnit (higher _unit_level = larger unit).
    if lvl >= 4 {
        hh = rem_ns // 3600000000000;
        rem_ns = rem_ns % 3600000000000;
    }
    if lvl >= 3 {
        mmi = rem_ns // 60000000000;
        rem_ns = rem_ns % 60000000000;
    }
    if lvl >= 2 {
        sc = rem_ns // 1000000000;
        rem_ns = rem_ns % 1000000000;
    }
    n = rem_ns;
    lim: list[float] = dur_from_components(
        0.0, 0.0, 0.0, 0.0, float(hh), float(mmi), float(sc), float(n)
    );
    if sign < 0 {
        lim[DUR_SIGN] = -1.0;
    }
    # Do not balance upward — that would reintroduce units above largestUnit
    # (e.g. minutes→hours when largestUnit is minute).
    return _dur_normalize_sign(lim);
}

def:pub dur_until_days(
    iso_y1: int, iso_m1: int, iso_d1: int, iso_y2: int, iso_m2: int, iso_d2: int
) -> int {
    return iso_days_from_ymd(iso_y2, iso_m2, iso_d2)
        - iso_days_from_ymd(iso_y1, iso_m1, iso_d1);
}

def:pub rounding_mode_from_string(s: str) -> int {
    if s == "trunc" {
        return ROUND_TRUNC;
    }
    if s == "halfExpand" {
        return ROUND_HALF_EXPAND;
    }
    if s == "halfTrunc" {
        return ROUND_HALF_TRUNC;
    }
    if s == "halfEven" {
        return ROUND_HALF_EVEN;
    }
    if s == "halfCeil" {
        return ROUND_HALF_CEIL;
    }
    if s == "halfFloor" {
        return ROUND_HALF_FLOOR;
    }
    if s == "ceil" {
        return ROUND_CEIL;
    }
    if s == "floor" {
        return ROUND_FLOOR;
    }
    if s == "expand" {
        return ROUND_EXPAND;
    }
    return ROUND_TRUNC;
}

# NegateRoundingMode (§Temporal): `since` rounds the NEGATED difference, so the mode
# must flip its direction — ceil↔floor and halfCeil↔halfFloor. trunc, expand, and the
# symmetric half-* modes (halfExpand/halfTrunc/halfEven) are unchanged.
def:pub negate_rounding_mode_string(s: str) -> str {
    if s == "ceil" {
        return "floor";
    }
    if s == "floor" {
        return "ceil";
    }
    if s == "halfCeil" {
        return "halfFloor";
    }
    if s == "halfFloor" {
        return "halfCeil";
    }
    return s;
}

def:pub rounding_mode_to_string(mode: int) -> str {
    if mode == ROUND_TRUNC {
        return "trunc";
    }
    if mode == ROUND_HALF_EXPAND {
        return "halfExpand";
    }
    if mode == ROUND_HALF_TRUNC {
        return "halfTrunc";
    }
    if mode == ROUND_HALF_EVEN {
        return "halfEven";
    }
    if mode == ROUND_HALF_CEIL {
        return "halfCeil";
    }
    if mode == ROUND_HALF_FLOOR {
        return "halfFloor";
    }
    if mode == ROUND_CEIL {
        return "ceil";
    }
    if mode == ROUND_FLOOR {
        return "floor";
    }
    if mode == ROUND_EXPAND {
        return "expand";
    }
    return "trunc";
}
