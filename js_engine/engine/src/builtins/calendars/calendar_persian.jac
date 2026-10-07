"""Persian (Solar Hijri / Jalali) calendar — ICU persncal algorithm."""

import from engine.src.builtins.calendars.calendar_gregory {
    CF_YEAR,
    CF_MONTH,
    CF_DAY,
    CF_ERA,
    CF_ERA_YEAR,
    CF_DAYS_IN_MONTH,
    CF_DAYS_IN_YEAR,
    CF_IN_LEAP_YEAR,
    CF_MONTHS_IN_YEAR,
    CF_DAY_OF_YEAR,
    CF_MONTH_CODE,
    CF_IS_LEAP_MONTH,
    civil_days_from_ymd,
    civil_ymd_from_days,
    civil_is_leap
}
import from engine.src.builtins.calendars.calendar_era { ERA_AP }

glob _PERSIAN_EPOCH: int = 1948320,
     _PERSIAN_JD_UNIX: int = 2440588,
     _PERSIAN_MONTH_LEN: list[int] = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29],
     _PERSIAN_LEAP_MONTH_LEN: list[int] = [
         31,
         31,
         31,
         31,
         31,
         31,
         30,
         30,
         30,
         30,
         30,
         30
     ],
     _PERSIAN_CUM_DAYS: list[int] = [
         0,
         31,
         62,
         93,
         124,
         155,
         186,
         216,
         246,
         276,
         306,
         336
     ],
     _PERSIAN_NON_LEAP_CORR: list[int] = [
         1502,
         1601,
         1634,
         1667,
         1700,
         1733,
         1766,
         1799,
         1832,
         1865,
         1898,
         1931,
         1964,
         1997,
         2030,
         2059,
         2063,
         2096,
         2129,
         2158,
         2162,
         2191,
         2195,
         2224,
         2228,
         2257,
         2261,
         2290,
         2294,
         2323,
         2327,
         2356,
         2360,
         2389,
         2393,
         2422,
         2426,
         2455,
         2459,
         2488,
         2492,
         2521,
         2525,
         2554,
         2558,
         2587,
         2591,
         2620,
         2624,
         2653,
         2657,
         2686,
         2690,
         2719,
         2723,
         2748,
         2752,
         2756,
         2781,
         2785,
         2789,
         2818,
         2822,
         2847,
         2851,
         2855,
         2880,
         2884,
         2888,
         2913,
         2917,
         2921,
         2946,
         2950,
         2954,
         2979,
         2983,
         2987
     ];

def _persian_in_corr_list(y: int) -> bool {
    i: int = 0;
    while i < len(_PERSIAN_NON_LEAP_CORR) {
        if _PERSIAN_NON_LEAP_CORR[i] == y {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def:pub persian_is_leap(year: int) -> bool {
    if _persian_in_corr_list(year) {
        return False;
    }
    if year > 1502 and _persian_in_corr_list(year - 1) {
        return True;
    }
    y25: int = year * 25 + 11;
    if y25 % 33 < 8 {
        return True;
    }
    return False;
}

def _persian_first_julian_of_year(year: int) -> int {
    jd: int = 365 * (year - 1) + (8 * year + 21) // 33;
    if year > 1502 and _persian_in_corr_list(year - 1) {
        jd = jd - 1;
    }
    return jd;
}

def _persian_to_jd(py: int, pm: int, pd: int) -> int {
    m0: int = pm - 1;
    if m0 < 0 {
        adj: int = (m0 + 1) // 12 - 1;
        py = py + adj;
        m0 = m0 - adj * 12;
    }
    if m0 > 11 {
        py = py + m0 // 12;
        m0 = m0 % 12;
    }
    jd: int = _PERSIAN_EPOCH - 1 + _persian_first_julian_of_year(py);
    if m0 > 0 {
        jd = jd + _PERSIAN_CUM_DAYS[m0];
    }
    jd = jd + pd;
    return jd;
}

def _persian_from_jd(jd: int) -> list[int] {
    # Exact inverse of _persian_to_jd: find year where
    # to_jd(y,1,1) <= jd < to_jd(y+1,1,1), then month/day from leftover.
    base: int = jd - (_PERSIAN_EPOCH - 1);
    year: int = (base * 33) // (365 * 33 + 8) + 1;
    if year < 1 {
        year = 1;
    }
    guard: int = 0;
    while guard < 16 {
        y0: int = _persian_to_jd(year, 1, 1);
        y1: int = _persian_to_jd(year + 1, 1, 1);
        if jd >= y0 and jd < y1 {
            break;
        }
        if jd < y0 {
            year = year - 1;
        } else {
            year = year + 1;
        }
        guard = guard + 1;
    }
    off: int = jd - _persian_to_jd(year, 1, 1);
    month: int = 1;
    while month < 12 and off >= _PERSIAN_CUM_DAYS[month] {
        month = month + 1;
    }
    day: int = off - _PERSIAN_CUM_DAYS[month - 1] + 1;
    out: list[int] = [year, month, day];
    return out;
}

def:priv _persian_fields_pack(
    year: int,
    month: int,
    day: int,
    days_in_month: int,
    days_in_year: int,
    in_leap: bool,
    day_of_year: int
) -> list[int] {
    leap_i: int = 0;
    if in_leap {
        leap_i = 1;
    }
    out: list[int] = [
        year,
        month,
        month,
        day,
        ERA_AP,
        year,
        days_in_month,
        days_in_year,
        leap_i,
        12,
        day_of_year,
        0
    ];
    return out;
}

def:pub persian_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    jd: int = days + _PERSIAN_JD_UNIX;
    ymd: list[int] = _persian_from_jd(jd);
    py: int = ymd[0];
    pm: int = ymd[1];
    pd: int = ymd[2];
    leap: bool = persian_is_leap(py);
    dim: int = _PERSIAN_MONTH_LEN[pm - 1];
    if leap {
        dim = _PERSIAN_LEAP_MONTH_LEN[pm - 1];
    }
    diy: int = 365;
    if leap {
        diy = 366;
    }
    doy: int = _PERSIAN_CUM_DAYS[pm - 1] + pd;
    return _persian_fields_pack(py, pm, pd, dim, diy, leap, doy);
}

def:pub persian_fields_to_iso(fields: list[int]) -> list[int] {
    jd: int = _persian_to_jd(fields[CF_YEAR], fields[CF_MONTH], fields[CF_DAY]);
    days: int = jd - _PERSIAN_JD_UNIX;
    return civil_ymd_from_days(days);
}

def:pub persian_months_in_year(year: int) -> int {
    return 12;
}

def:pub persian_days_in_month(year: int, month: int) -> int {
    if persian_is_leap(year) {
        return _PERSIAN_LEAP_MONTH_LEN[month - 1];
    }
    return _PERSIAN_MONTH_LEN[month - 1];
}
