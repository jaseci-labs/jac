"""Islamic civil and tabular (tbla) calendars."""

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
import from engine.src.builtins.calendars.calendar_era { ERA_AH, ERA_BH }

glob:priv _ISLAMIC_CIVIL_EPOCH: int = -492148,
     _ISLAMIC_TBLA_EPOCH: int = -492149,
     _ISLAMIC_JD_UNIX: int = 2440588;

def _islamic_leap(year: int) -> bool {
    return (14 + 11 * year) % 30 < 11;
}

def _islamic_month_len(year: int, month: int, tbla: bool) -> int {
    if month == 12 {
        if _islamic_leap(year) {
            return 30;
        }
        return 29;
    }
    if month % 2 == 1 {
        return 30;
    }
    return 29;
}

def _islamic_year_len(year: int) -> int {
    if _islamic_leap(year) {
        return 355;
    }
    return 354;
}

def _islamic_year_start(year: int, epoch: int) -> int {
    # ICU IslamicCalendar::yearStart:
    #   (year-1)*354 + floor((3+11*year)/30)
    # Note: intercalation uses 11*year (not 11*(year-1)) so year lengths
    # stay consistent with _islamic_leap / _islamic_year_len.
    return epoch + (year - 1) * 354 + (3 + 11 * year) // 30;
}

def _islamic_to_days(year: int, month: int, day: int, epoch: int) -> int {
    ys: int = _islamic_year_start(year, epoch);
    mi: int = 1;
    while mi < month {
        ys = ys + _islamic_month_len(year, mi, False);
        mi = mi + 1;
    }
    return ys + day - 1;
}

def _islamic_from_days(days: int, epoch: int) -> list[int] {
    year: int = (days - epoch) * 30 // 10631 + 1;
    i: int = 0;
    while i < 30 {
        ys: int = _islamic_year_start(year, epoch);
        ylen: int = _islamic_year_len(year);
        if days < ys {
            year = year - 1;
        } elif days >= ys + ylen {
            year = year + 1;
        } else {
            rem: int = days - ys + 1;
            month: int = 1;
            while month <= 12 {
                mlen: int = _islamic_month_len(year, month, False);
                if rem <= mlen {
                    out: list[int] = [year, month, rem];
                    return out;
                }
                rem = rem - mlen;
                month = month + 1;
            }
        }
        i = i + 1;
    }
    return [1, 1, 1];
}

def:priv _islamic_fields_pack(
    year: int, month: int, day: int, tbla: bool
) -> list[int] {
    dim: int = _islamic_month_len(year, month, tbla);
    diy: int = _islamic_year_len(year);
    doy: int = day;
    mi: int = 1;
    while mi < month {
        doy = doy + _islamic_month_len(year, mi, tbla);
        mi = mi + 1;
    }
    leap_i: int = 0;
    if _islamic_leap(year) {
        leap_i = 1;
    }
    era_id: int = ERA_AH;
    era_y: int = year;
    if year <= 0 {
        era_id = ERA_BH;
        era_y = 1 - year;
    }
    out: list[int] = [
        year,
        month,
        month,
        day,
        era_id,
        era_y,
        dim,
        diy,
        leap_i,
        12,
        doy,
        0
    ];
    return out;
}

def:pub islamic_civil_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    ymd: list[int] = _islamic_from_days(days, _ISLAMIC_CIVIL_EPOCH);
    return _islamic_fields_pack(ymd[0], ymd[1], ymd[2], False);
}

def:pub islamic_civil_fields_to_iso(fields: list[int]) -> list[int] {
    days: int = _islamic_to_days(
        fields[CF_YEAR], fields[CF_MONTH], fields[CF_DAY], _ISLAMIC_CIVIL_EPOCH
    );
    return civil_ymd_from_days(days);
}

def:pub islamic_civil_months_in_year(year: int) -> int {
    return 12;
}

def:pub islamic_civil_days_in_month(year: int, month: int) -> int {
    return _islamic_month_len(year, month, False);
}

def:pub islamic_tbla_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    ymd: list[int] = _islamic_from_days(days, _ISLAMIC_TBLA_EPOCH);
    return _islamic_fields_pack(ymd[0], ymd[1], ymd[2], True);
}

def:pub islamic_tbla_fields_to_iso(fields: list[int]) -> list[int] {
    days: int = _islamic_to_days(
        fields[CF_YEAR], fields[CF_MONTH], fields[CF_DAY], _ISLAMIC_TBLA_EPOCH
    );
    return civil_ymd_from_days(days);
}

def:pub islamic_tbla_months_in_year(year: int) -> int {
    return 12;
}

def:pub islamic_tbla_days_in_month(year: int, month: int) -> int {
    return _islamic_month_len(year, month, True);
}
