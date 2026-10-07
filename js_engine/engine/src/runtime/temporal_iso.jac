"""
runtime/temporal_iso.na.jac — ISO-8601 calendar core arithmetic.

Days-since-epoch, balancing, ISO week/day-of-year calculations.
Uses Howard-Hinnant civil date algorithms (same as date.na.jac).
"""

glob ISO_MIN_YEAR: int = -999999,
     ISO_MAX_YEAR: int = 999999,
     ISO_REL_MIN_Y: int = -271821,
     ISO_REL_MIN_M: int = 4,
     ISO_REL_MIN_D: int = 19,
     ISO_REL_MAX_Y: int = 275760,
     ISO_REL_MAX_M: int = 9,
     ISO_REL_MAX_D: int = 13;

"""y=year, m=month 1-based, d=day 1-based → days since 1970-01-01."""
def _iso_civil_to_days(y: int, m: int, d: int) -> int {
    adj_y: int = y;
    if m <= 2 {
        adj_y = adj_y - 1;
    }
    # Jac `//` floors → adj_y // 400 is the floored era for both signs. The
    # (adj_y - 399) bias (a truncating-division floor emulation) double-adjusts
    # and must stay removed to round-trip with iso_ymd_from_days's plain floor.
    era: int = adj_y // 400;
    yoe: int = adj_y - era * 400;
    mp: int = m - 3;
    if m <= 2 {
        mp = m + 9;
    }
    doy: int = (153 * mp + 2) // 5 + d - 1;
    doe: int = yoe * 365 + yoe // 4 - yoe // 100 + doy;
    return era * 146097 + doe - 719468;
}

def:pub iso_days_from_ymd(y: int, m: int, d: int) -> int {
    return _iso_civil_to_days(y, m, d);
}

def:pub iso_ymd_from_days(days: int) -> list[int] {
    z: int = days + 719468;
    # Jac `//` floors, so z // 146097 is the floored era for both signs. Hinnant's
    # (z - 146096) bias emulates floor on TRUNCATING C++ division — applying it on
    # top of Jac's already-flooring `//` double-adjusts and shifts far-negative
    # dates by a day (e.g. year -100000 rendered -07-02 instead of -07-01).
    era: int = z // 146097;
    doe: int = z - era * 146097;
    yoe: int = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365;
    y: int = yoe + era * 400;
    doy: int = doe - (365 * yoe + yoe // 4 - yoe // 100);
    mp: int = (5 * doy + 2) // 153;
    d: int = doy - (153 * mp + 2) // 5 + 1;
    m: int = mp + 3;
    if mp >= 10 {
        m = mp - 9;
    }
    if m <= 2 {
        y = y + 1;
    }
    return [y, m, d];
}

def:pub iso_is_leap_year(y: int) -> bool {
    if y % 4 != 0 {
        return False;
    }
    if y % 100 != 0 {
        return True;
    }
    if y % 400 != 0 {
        return False;
    }
    return True;
}

def:pub iso_days_in_month(y: int, m: int) -> int {
    if m == 2 {
        if iso_is_leap_year(y) {
            return 29;
        }
        return 28;
    }
    if m == 4 or m == 6 or m == 9 or m == 11 {
        return 30;
    }
    return 31;
}

def:pub iso_days_in_year(y: int) -> int {
    if iso_is_leap_year(y) {
        return 366;
    }
    return 365;
}

def:pub iso_day_of_week(y: int, m: int, d: int) -> int {
    # ISO weekday 1=Monday…7=Sunday. Day 0 of the civil-days epoch (1970-01-01) is a
    # Thursday (weekday 4), so the offset is +3: (days+3) mod 7 gives 0=Mon…6=Sun,
    # then +1. (The previous +4 was off by one — every weekday came out one too high.)
    days: int = iso_days_from_ymd(y, m, d);
    wd: int = (days + 3) % 7;
    if wd < 0 {
        wd = wd + 7;
    }
    return wd + 1;
}

def:pub iso_day_of_year(y: int, m: int, d: int) -> int {
    doy: int = d;
    mo: int = 1;
    while mo < m {
        doy = doy + iso_days_in_month(y, mo);
        mo = mo + 1;
    }
    return doy;
}

def:pub iso_week_of_year(y: int, m: int, d: int) -> list[int] {
    doy: int = iso_day_of_year(y, m, d);
    dow: int = iso_day_of_week(y, m, d);
    thu_doy: int = doy + (4 - dow);
    if thu_doy < 1 {
        py: int = y - 1;
        pd: int = iso_days_in_year(py);
        thu_doy = doy + (4 - dow) + pd;
        y = py;
    }
    woy: int = (thu_doy - 1) // 7 + 1;
    yow: int = y;
    if woy == 0 {
        py2: int = y - 1;
        woy = iso_week_of_year(py2, 12, 31)[0];
        yow = py2;
    }
    if woy >= 53 {
        # A computed week 53 is only real if this ISO year actually has 53 weeks — it
        # does when 1 January (of this year) or 31 December is a Thursday. Otherwise the
        # date belongs to WEEK 1 of the NEXT ISO year (e.g. Mon 1975-12-29 → 1976-W01):
        # renumber the week to 1 and advance the week-year.
        ny: int = y + 1;
        p_year_has_53: bool = iso_day_of_week(y, 1, 1) == 4
            or iso_day_of_week(y, 12, 31) == 4;
        if not p_year_has_53 {
            woy = 1;
            yow = ny;
        }
    }
    return [woy, yow];
}

def:pub iso_month_code(m: int) -> str {
    if m < 10 {
        return "M0" + str(m);
    }
    return "M" + str(m);
}

def:pub iso_balance_date(y: int, m: int, d: int) -> list[int] {
    days: int = iso_days_from_ymd(y, m, d);
    return iso_ymd_from_days(days);
}

def:pub iso_add_days(y: int, m: int, d: int, delta: int) -> list[int] {
    days: int = iso_days_from_ymd(y, m, d) + delta;
    return iso_ymd_from_days(days);
}

def:pub iso_add_months(y: int, m: int, d: int, delta: int) -> list[int] {
    # Euclidean month index so negative totals (crossing year 0) stay correct
    # regardless of truncating vs flooring division.
    total_m: int = y * 12 + (m - 1) + delta;
    nm0: int = total_m % 12;
    if nm0 < 0 {
        nm0 = nm0 + 12;
    }
    ny: int = (total_m - nm0) // 12;
    nm: int = nm0 + 1;
    dim: int = iso_days_in_month(ny, nm);
    nd: int = d;
    if nd > dim {
        nd = dim;
    }
    return [ny, nm, nd];
}

def:pub iso_compare(y1: int, m1: int, d1: int, y2: int, m2: int, d2: int) -> int {
    days1: int = iso_days_from_ymd(y1, m1, d1);
    days2: int = iso_days_from_ymd(y2, m2, d2);
    if days1 < days2 {
        return -1;
    }
    if days1 > days2 {
        return 1;
    }
    return 0;
}

def:pub iso_validate_ymd(y: int, m: int, d: int) -> bool {
    # Temporal ISO uses astronomical year numbering (year 0 = 1 BCE).
    if y < ISO_MIN_YEAR or y > ISO_MAX_YEAR {
        return False;
    }
    if m < 1 or m > 12 {
        return False;
    }
    if d < 1 or d > iso_days_in_month(y, m) {
        return False;
    }
    return True;
}

"""ISOYearMonthWithinLimits: a PlainYearMonth is valid iff its (year, month) lies in
[-271821-04, +275760-09] — month-granular, NOT the day-inclusive date range. The
reference day is irrelevant to this bound, so "-271821-04" is valid even though its
reference day 04-01 is before the date-range minimum 04-19."""
def:pub iso_validate_year_month(y: int, m: int) -> bool {
    if y < -271821 {
        return False;
    }
    if y == -271821 and m < 4 {
        return False;
    }
    if y > 275760 {
        return False;
    }
    if y == 275760 and m > 9 {
        return False;
    }
    return True;
}

def:pub iso_validate_relativeto_ymd(y: int, m: int, d: int) -> bool {
    if iso_compare(y, m, d, ISO_REL_MIN_Y, ISO_REL_MIN_M, ISO_REL_MIN_D) < 0 {
        return False;
    }
    if iso_compare(y, m, d, ISO_REL_MAX_Y, ISO_REL_MAX_M, ISO_REL_MAX_D) > 0 {
        return False;
    }
    return True;
}

"""ISODateTimeWithinLimits: a PlainDateTime is valid iff its (UTC) epoch nanoseconds
lie strictly between nsMinInstant−nsPerDay and nsMaxInstant+nsPerDay — i.e. strictly
inside (-271821-04-19T00:00:00, +275760-09-14T00:00:00). Note the MIN day `-04-19` at
exactly midnight is EXCLUDED (must be later), while the MAX runs to
+275760-09-13T23:59:59.999999999. This differs from the tighter instant bounds."""
def:pub iso_validate_datetime_within_limits(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int
) -> bool {
    day: int = iso_days_from_ymd(y, m, d);
    sec: int = h * 3600 + mi * 60 + s;
    # Representable range: (-271821-04-19T00:00:00, +275760-09-13T23:59:59.999999999].
    # Min day midnight is excluded; the full max day (-13) is valid through end-of-day,
    # but +275760-09-14 (and beyond) is out of range entirely.
    min_day: int = iso_days_from_ymd(-271821, 4, 19);
    max_day: int = iso_days_from_ymd(275760, 9, 13);
    if day < min_day {
        return False;
    }
    if day == min_day and sec == 0 and ns == 0 {
        return False;
    }
    if day > max_day {
        return False;
    }
    return True;
}

"""Validate relativeTo instant bounds (UTC = local + offset_s)."""
def:pub iso_validate_relativeto_instant(
    y: int, m: int, d: int, h: int, mi: int, s: int, ns: int, offset_s: int, is_z: bool
) -> bool {
    local_day: int = iso_days_from_ymd(y, m, d);
    local_s: int = h * 3600 + mi * 60 + s;
    utc_day: int = local_day;
    utc_s: int = local_s;
    utc_ns: int = ns;
    if is_z {
        utc_day = local_day;
        utc_s = local_s;
        utc_ns = ns;
    } else {
        local_total: int = local_day * 86400 + local_s;
        utc_total: int = local_total - offset_s;
        utc_day = utc_total // 86400;
        utc_s = utc_total - utc_day * 86400;
        utc_ns = ns;
    }
    min_day: int = iso_days_from_ymd(-271821, 4, 20);
    max_day: int = iso_days_from_ymd(275760, 9, 13);
    if utc_day < min_day {
        return False;
    }
    if utc_day == min_day {
        if utc_s < 0 {
            return False;
        }
        if utc_s == 0 and utc_ns < 0 {
            return False;
        }
    }
    if utc_day > max_day {
        return False;
    }
    if utc_day == max_day {
        if utc_s > 0 {
            return False;
        }
        if utc_s == 0 and utc_ns > 0 {
            return False;
        }
    }
    # For an offset (non-Z) value the LOCAL wall-clock date must ALSO stay within the
    # representable day range (a relativeTo like "-271821-04-19T23:00-01:00" is out of
    # range even though its UTC instant lands exactly on the min). The bogus
    # local_day-vs-utc_day comparisons that used to live here — which rejected any
    # offset date crossing midnight — are intentionally NOT restored.
    if not is_z and offset_s != 0 {
        if local_day < min_day {
            return False;
        }
        if local_day > max_day {
            return False;
        }
    }
    return True;
}

def:pub iso_validate_time(h: int, mi: int, s: int, ns: int) -> bool {
    if h < 0 or h > 23 {
        return False;
    }
    if mi < 0 or mi > 59 {
        return False;
    }
    if s < 0 or s > 59 {
        return False;
    }
    if ns < 0 or ns > 999999999 {
        return False;
    }
    return True;
}

def:pub iso_format_date(y: int, m: int, d: int) -> str {
    # PadISOYear (ES Temporal §): years 0000–9999 are 4 digits with NO sign; years
    # outside that range use a mandatory sign (+/-) and 6 digits (expanded year).
    ys: str = str(y);
    if y >= 0 and y < 10000 {
        while len(ys) < 4 {
            ys = "0" + ys;
        }
    } elif y >= 10000 {
        # Expanded positive year: mandatory "+" and SIX digits (10000 → "+010000").
        while len(ys) < 6 {
            ys = "0" + ys;
        }
        ys = "+" + ys;
    } else {
        neg_ys: str = str(-y);
        while len(neg_ys) < 6 {
            neg_ys = "0" + neg_ys;
        }
        ys = "-" + neg_ys;
    }
    ms: str = str(m);
    if m < 10 {
        ms = "0" + ms;
    }
    ds: str = str(d);
    if d < 10 {
        ds = "0" + ds;
    }
    return ys + "-" + ms + "-" + ds;
}

def:pub iso_format_time(h: int, mi: int, s: int, ns: int) -> str {
    return iso_format_time_precision(h, mi, s, ns, -1);
}

def:pub iso_format_time_precision(
    h: int, mi: int, s: int, ns: int, frac_digits: int
) -> str {
    hs: str = str(h);
    if h < 10 {
        hs = "0" + hs;
    }
    mis: str = str(mi);
    if mi < 10 {
        mis = "0" + mis;
    }
    # frac_digits == -2 → "minute" precision: HH:MM with the seconds field OMITTED
    # entirely (Temporal toString with smallestUnit "minute").
    if frac_digits == -2 {
        return hs + ":" + mis;
    }
    ss: str = str(s);
    if s < 10 {
        ss = "0" + ss;
    }
    out: str = hs + ":" + mis + ":" + ss;
    if frac_digits == 0 {
        return out;
    }
    if ns == 0 and frac_digits < 0 {
        return out;
    }
    ns_s: str = str(ns);
    while len(ns_s) < 9 {
        ns_s = "0" + ns_s;
    }
    if frac_digits < 0 {
        while len(ns_s) > 0 and ns_s[len(ns_s) - 1:len(ns_s)] == "0" {
            ns_s = ns_s[0:len(ns_s) - 1];
        }
        if len(ns_s) > 0 {
            out = out + "." + ns_s;
        }
        return out;
    }
    if frac_digits > 9 {
        frac_digits = 9;
    }
    if frac_digits > len(ns_s) {
        while len(ns_s) < frac_digits {
            ns_s = ns_s + "0";
        }
    }
    if frac_digits < len(ns_s) {
        ns_s = ns_s[0:frac_digits];
    }
    out = out + "." + ns_s;
    return out;
}

def:pub iso_total_nanoseconds(h: int, mi: int, s: int, ns: int) -> int {
    return h * 3600000000000 + mi * 60000000000 + s * 1000000000 + ns;
}

def:pub iso_nanoseconds_to_time(total_ns: int) -> list[int] {
    if total_ns < 0 {
        total_ns = -total_ns;
    }
    ns: int = total_ns % 1000000000;
    total_s: int = total_ns // 1000000000;
    s: int = total_s % 60;
    total_m: int = total_s // 60;
    mi: int = total_m % 60;
    h: int = total_m // 60;
    h = h % 24;
    return [h, mi, s, ns];
}

def:pub iso_add_time(
    h: int, mi: int, s: int, ns: int, dh: int, dmi: int, ds: int, dns: int
) -> list[int] {
    total: int = iso_total_nanoseconds(h, mi, s, ns)
        + iso_total_nanoseconds(dh, dmi, ds, dns);
    # Jac `//` floors and `%` is non-negative for a positive divisor, so a single
    # floored divmod gives the whole-day carry and an in-[0,86400e9) remainder for
    # BOTH signs. The old negative branch used a (total - D + 1)//D truncation-floor
    # emulation that double-adjusted under Jac's already-flooring // — add({hours:-12})
    # borrowed 2 days instead of 1 (day 29 → 27 instead of 28).
    days: int = total // 86400000000000;
    total = total - days * 86400000000000;
    t: list[int] = iso_nanoseconds_to_time(total);
    return [days, t[0], t[1], t[2], t[3]];
}

def:pub iso_months_in_year(y: int) -> int {
    return 12;
}

def:pub iso_days_in_week -> int {
    return 7;
}
