"""Hebrew lunisolar calendar — Metonic cycle with postponement rules (ICU hebrwcal)."""

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
    civil_ymd_from_days
}
import from engine.src.builtins.calendars.calendar_era { ERA_AM }

# Unix-day epoch (1970-01-01 = 0), not Rata Die (−1373427).
glob _HEBREW_EPOCH_DAYS: int = -2092590,
     _HEB_MONTH_LEN: list[list[int]] = [
         [30, 30, 30],
         [29, 29, 30],
         [29, 30, 30],
         [29, 29, 29],
         [30, 30, 30],
         [30, 30, 30],
         [29, 29, 29],
         [30, 30, 30],
         [29, 29, 29],
         [30, 30, 30],
         [29, 29, 29],
         [30, 30, 30],
         [29, 29, 29]
     ],
     _HEB_MONTH_START: list[list[int]] = [
         [0, 0, 0],
         [30, 30, 30],
         [59, 59, 60],
         [88, 89, 90],
         [117, 118, 119],
         [147, 148, 149],
         [147, 148, 149],
         [176, 177, 178],
         [206, 207, 208],
         [235, 236, 237],
         [265, 266, 267],
         [294, 295, 296],
         [324, 325, 326]
     ],
     _HEB_LEAP_MONTH_START: list[list[int]] = [
         [0, 0, 0],
         [30, 30, 30],
         [59, 59, 60],
         [88, 89, 90],
         [117, 118, 119],
         [147, 148, 149],
         [177, 178, 179],
         [206, 207, 208],
         [236, 237, 238],
         [265, 266, 267],
         [295, 296, 297],
         [324, 325, 326],
         [354, 355, 356]
     ];

def:pub hebrew_is_leap(year: int) -> bool {
    return (7 * year + 1) % 19 < 7;
}

def _hebrew_delay1(year: int) -> int {
    months: int = (235 * year - 234) // 19;
    parts: int = 12084 + 13753 * months;
    day: int = months * 29 + parts // 25920;
    if (3 * (day + 1) % 7) < 3 {
        day = day + 1;
    }
    return day;
}

def _hebrew_delay2(year: int) -> int {
    last: int = _hebrew_delay1(year - 1);
    present: int = _hebrew_delay1(year);
    next_: int = _hebrew_delay1(year + 1);
    if next_ - present == 356 {
        return 2;
    }
    if present - last == 382 {
        return 1;
    }
    return 0;
}

def _hebrew_year_type(year: int) -> int {
    ylen: int = _hebrew_days_in_year(year);
    if ylen > 380 {
        ylen = ylen - 30;
    }
    if ylen == 353 {
        return 0;
    }
    if ylen == 354 {
        return 1;
    }
    return 2;
}

def _hebrew_days_in_year(year: int) -> int {
    return _hebrew_start_of_year(year + 1) - _hebrew_start_of_year(year);
}

def _hebrew_start_of_year(year: int) -> int {
    # delay1 already applies the first postponement; delay2 adds year-length rules.
    return _HEBREW_EPOCH_DAYS + _hebrew_delay1(year) + _hebrew_delay2(year);
}

def _hebrew_month_len(year: int, month: int) -> int {
    # Temporal month numbers: leap 1..13 (Adar I=6, Adar II=7); common 1..12 (Adar=6).
    # Table is ICU's 13-slot layout (index 5 = Adar I, 6 = Adar/Adar II).
    ytype: int = _hebrew_year_type(year);
    if month < 1 {
        return 0;
    }
    if hebrew_is_leap(year) {
        if month > 13 {
            return 0;
        }
        return _HEB_MONTH_LEN[month - 1][ytype];
    }
    if month > 12 {
        return 0;
    }
    idx: int = month - 1;
    if month >= 6 {
        idx = month;
    }
    return _HEB_MONTH_LEN[idx][ytype];
}

def _hebrew_months_in_year(year: int) -> int {
    if hebrew_is_leap(year) {
        return 13;
    }
    return 12;
}

def:priv _hebrew_month_code_num(month: int, leap_month: bool) -> str {
    mc: str = "M";
    if month < 10 {
        mc = mc + "0";
    }
    mc = mc + str(month);
    if leap_month {
        mc = mc + "L";
    }
    return mc;
}

def _hebrew_month_code(year: int, month: int) -> str {
    if hebrew_is_leap(year) and month == 6 {
        return "M05L";
    }
    ord_m: int = month;
    if hebrew_is_leap(year) and month > 6 {
        ord_m = month - 1;
    }
    return _hebrew_month_code_num(ord_m, False);
}

def:pub hebrew_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    year: int = (days - _HEBREW_EPOCH_DAYS) // 365 + 1;
    i: int = 0;
    while i < 20 {
        if days < _hebrew_start_of_year(year) {
            year = year - 1;
        } elif days >= _hebrew_start_of_year(year + 1) {
            year = year + 1;
        } else {
            break;
        }
        i = i + 1;
    }
    ystart: int = _hebrew_start_of_year(year);
    doy: int = days - ystart + 1;
    ytype: int = _hebrew_year_type(year);
    mcount: int = _hebrew_months_in_year(year);
    month: int = 1;
    day: int = 1;
    mi: int = 1;
    while mi <= mcount {
        mlen: int = _hebrew_month_len(year, mi);
        if doy <= mlen {
            month = mi;
            day = doy;
            break;
        }
        doy = doy - mlen;
        mi = mi + 1;
    }
    dim: int = _hebrew_month_len(year, month);
    diy: int = _hebrew_days_in_year(year);
    mc_ord: int = month;
    leap_m: int = 0;
    if hebrew_is_leap(year) and month == 6 {
        mc_ord = 5;
        leap_m = 1;
    } elif hebrew_is_leap(year) and month > 6 {
        mc_ord = month - 1;
    }
    leap_i: int = 0;
    if hebrew_is_leap(year) {
        leap_i = 1;
    }
    doy_out: int = days - ystart + 1;
    out: list[int] = [
        year,
        month,
        mc_ord,
        day,
        ERA_AM,
        year,
        dim,
        diy,
        leap_i,
        mcount,
        doy_out,
        leap_m
    ];
    return out;
}

def:pub hebrew_fields_to_iso(fields: list[int]) -> list[int] {
    hy: int = fields[CF_YEAR];
    hm: int = fields[CF_MONTH];
    hd: int = fields[CF_DAY];
    mc: int = fields[CF_MONTH_CODE];
    leap_m: int = 0;
    if len(fields) > CF_IS_LEAP_MONTH {
        leap_m = fields[CF_IS_LEAP_MONTH];
    }
    # Only remap bag monthCode form (mc > 0). Arithmetic packs CF_MONTH_CODE=0
    # with already-resolved numeric months (1..13) — do not double-apply.
    if mc > 0 {
        if leap_m != 0 {
            # M05L → Adar I (numeric month 6) in leap years.
            hm = 6;
        } elif hm == mc and hebrew_is_leap(hy) and mc >= 6 {
            # M06..M12 in a leap year → skip Adar I slot.
            hm = mc + 1;
        }
    }
    ystart: int = _hebrew_start_of_year(hy);
    doy: int = 0;
    mi: int = 1;
    while mi < hm {
        doy = doy + _hebrew_month_len(hy, mi);
        mi = mi + 1;
    }
    days: int = ystart + doy + hd - 1;
    return civil_ymd_from_days(days);
}

def:pub hebrew_months_in_year(year: int) -> int {
    return _hebrew_months_in_year(year);
}

def:pub hebrew_days_in_month(year: int, month: int) -> int {
    return _hebrew_month_len(year, month);
}
