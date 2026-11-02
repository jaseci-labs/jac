"""Chinese and Dangi (Korean) lunisolar calendars — LUNAR_INFO table 1900–2100."""

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
import from engine.src.builtins.calendars.calendar_era { ERA_NONE }

glob _CHINESE_BASE_YEAR: int = 1900,
     _CHINESE_EPOCH_DAYS: int = -25537,
     _LUNAR_INFO: list[int] = [
         19416,
         19168,
         42352,
         21717,
         53856,
         55632,
         91476,
         22176,
         39632,
         21970,
         19168,
         42422,
         42192,
         53840,
         119381,
         46400,
         54944,
         44450,
         38320,
         84343,
         18800,
         42160,
         46261,
         27216,
         27968,
         109396,
         11104,
         38256,
         21234,
         18800,
         25958,
         54432,
         59984,
         28309,
         23248,
         11104,
         100067,
         37600,
         116951,
         51536,
         54432,
         120998,
         46416,
         22176,
         107956,
         9680,
         37584,
         53938,
         43344,
         46423,
         27808,
         46416,
         86869,
         19872,
         42416,
         83315,
         21168,
         43432,
         59728,
         27296,
         44710,
         43856,
         19296,
         43748,
         42352,
         21088,
         62051,
         55632,
         23383,
         22176,
         38608,
         19925,
         19152,
         42192,
         54484,
         53840,
         54616,
         46400,
         46752,
         103846,
         38320,
         18864,
         43380,
         42160,
         45690,
         27216,
         27968,
         44870,
         43872,
         38256,
         19189,
         18800,
         25776,
         29859,
         59984,
         27480,
         21952,
         43872,
         38613,
         37600,
         51552,
         55636,
         54432,
         55888,
         30034,
         22176,
         43959,
         9680,
         37584,
         51893,
         43344,
         46240,
         47780,
         44368,
         21977,
         19360,
         42416,
         86390,
         21168,
         43312,
         31060,
         27296,
         44368,
         23378,
         19296,
         42726,
         42208,
         53856,
         60005,
         54576,
         23200,
         30371,
         38608,
         19195,
         19152,
         42192,
         118966,
         53840,
         54560,
         56645,
         46496,
         22224,
         21938,
         18864,
         42359,
         42160,
         43600,
         111189,
         27936,
         44448,
         84835,
         37744,
         18936,
         18800,
         25776,
         92326,
         59984,
         27424,
         108228,
         43744,
         41696,
         53987,
         51552,
         54615,
         54432,
         55888,
         23893,
         22176,
         42704,
         21972,
         21200,
         43448,
         43344,
         46240,
         46758,
         44368,
         21920,
         43940,
         42416,
         21168,
         45683,
         26928,
         29495,
         27296,
         44368,
         84821,
         19296,
         42352,
         21732,
         53600,
         59752,
         54560,
         55968,
         92838,
         22224,
         19168,
         43476,
         41680,
         53584,
         62034,
         54560
     ];

def _lunar_leap_month(lunar_y: int) -> int {
    idx: int = lunar_y - _CHINESE_BASE_YEAR;
    if idx < 0 or idx >= len(_LUNAR_INFO) {
        return 0;
    }
    return _LUNAR_INFO[idx] & 0xF;
}

def _lunar_leap_days(lunar_y: int) -> int {
    lm: int = _lunar_leap_month(lunar_y);
    if lm == 0 {
        return 0;
    }
    idx: int = lunar_y - _CHINESE_BASE_YEAR;
    if (_LUNAR_INFO[idx] & 0x10000) != 0 {
        return 30;
    }
    return 29;
}

def _lunar_month_days(lunar_y: int, lunar_m: int) -> int {
    idx: int = lunar_y - _CHINESE_BASE_YEAR;
    if idx < 0 or idx >= len(_LUNAR_INFO) {
        return 30;
    }
    if lunar_m > 12 {
        return 0;
    }
    bit: int = 0x8000 >> (lunar_m - 1);
    if (_LUNAR_INFO[idx] & bit) != 0 {
        return 30;
    }
    return 29;
}

def _lunar_year_days(lunar_y: int) -> int {
    idx: int = lunar_y - _CHINESE_BASE_YEAR;
    if idx < 0 or idx >= len(_LUNAR_INFO) {
        return 354;
    }
    total: int = 348;
    i: int = 0x8000;
    while i > 0x8 {
        if (_LUNAR_INFO[idx] & i) != 0 {
            total = total + 1;
        }
        i = i // 2;
    }
    return total + _lunar_leap_days(lunar_y);
}

def _lunar_months_in_year(lunar_y: int) -> int {
    if _lunar_leap_month(lunar_y) > 0 {
        return 13;
    }
    return 12;
}

def _lunar_to_days(lunar_y: int, lunar_m: int, lunar_d: int) -> int {
    days: int = _CHINESE_EPOCH_DAYS;
    y: int = _CHINESE_BASE_YEAR;
    while y < lunar_y {
        days = days + _lunar_year_days(y);
        y = y + 1;
    }
    lm: int = _lunar_leap_month(lunar_y);
    m: int = 1;
    while m < lunar_m {
        days = days + _lunar_month_days(lunar_y, m);
        if lm > 0 and m == lm {
            days = days + _lunar_leap_days(lunar_y);
        }
        m = m + 1;
    }
    return days + lunar_d - 1;
}

def _lunar_from_days(days: int) -> list[int] {
    if days < _CHINESE_EPOCH_DAYS {
        return [_CHINESE_BASE_YEAR, 1, 1];
    }
    y: int = _CHINESE_BASE_YEAR;
    offset: int = days - _CHINESE_EPOCH_DAYS;
    while y < _CHINESE_BASE_YEAR + len(_LUNAR_INFO) {
        ylen: int = _lunar_year_days(y);
        if offset < ylen {
            break;
        }
        offset = offset - ylen;
        y = y + 1;
    }
    lm: int = _lunar_leap_month(y);
    month: int = 1;
    while month <= 13 {
        mlen: int = _lunar_month_days(y, month);
        if offset < mlen {
            out: list[int] = [y, month, offset + 1, 0];
            return out;
        }
        offset = offset - mlen;
        if lm > 0 and month == lm {
            llen: int = _lunar_leap_days(y);
            if offset < llen {
                out2: list[int] = [y, month, offset + 1, 1];
                return out2;
            }
            offset = offset - llen;
        }
        month = month + 1;
    }
    return [y, 1, 1, 0];
}

"""Decode year-ordinal month (1..13) to (lunar_month, is_leap)."""
def:priv _chinese_ordinal_to_lunar(lunar_y: int, ordinal: int) -> list[int] {
    lm: int = _lunar_leap_month(lunar_y);
    if lm > 0 and ordinal == lm + 1 {
        return [lm, 1];
    }
    if lm > 0 and ordinal > lm + 1 {
        return [ordinal - 1, 0];
    }
    return [ordinal, 0];
}

def:pub chinese_leap_month(year: int) -> int {
    return _lunar_leap_month(year);
}

def _chinese_pack(
    lunar_y: int, lunar_m: int, lunar_d: int, is_leap: bool
) -> list[int] {
    # CF_MONTH is Temporal year-ordinal (1..13, leap slot inserted).
    # CF_MONTH_CODE is the lunar month number used in monthCode (M0n / M0nL).
    lm: int = _lunar_leap_month(lunar_y);
    ordinal: int = lunar_m;
    if is_leap {
        ordinal = lunar_m + 1;
    } elif lm > 0 and lunar_m > lm {
        ordinal = lunar_m + 1;
    }
    dim: int = _lunar_month_days(lunar_y, lunar_m);
    if is_leap {
        dim = _lunar_leap_days(lunar_y);
    }
    diy: int = _lunar_year_days(lunar_y);
    miy: int = _lunar_months_in_year(lunar_y);
    doy: int = lunar_d;
    mi: int = 1;
    while mi < lunar_m {
        doy = doy + _lunar_month_days(lunar_y, mi);
        if lm == mi {
            doy = doy + _lunar_leap_days(lunar_y);
        }
        mi = mi + 1;
    }
    if is_leap {
        doy = doy + _lunar_month_days(lunar_y, lunar_m);
    }
    leap_bit: int = 0;
    if is_leap {
        leap_bit = 1;
    }
    # Chinese/Dangi have no era system — .era / .eraYear must be undefined.
    return [
        lunar_y,
        ordinal,
        lunar_m,
        lunar_d,
        ERA_NONE,
        lunar_y,
        dim,
        diy,
        0,
        miy,
        doy,
        leap_bit
    ];
}

def:pub chinese_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    ymd: list[int] = _lunar_from_days(days);
    return _chinese_pack(ymd[0], ymd[1], ymd[2], ymd[3] == 1);
}

def:pub chinese_fields_to_iso(fields: list[int]) -> list[int] {
    ly: int = fields[CF_YEAR];
    month_field: int = fields[CF_MONTH];
    ld: int = fields[CF_DAY];
    mc: int = fields[CF_MONTH_CODE];
    leap_flag: int = 0;
    if len(fields) > CF_IS_LEAP_MONTH {
        leap_flag = fields[CF_IS_LEAP_MONTH];
    }
    lunar_m: int = month_field;
    is_leap: bool = False;
    # Bag monthCode form: CF_MONTH == code number, leap bit from "M0nL".
    if mc > 0 and month_field == mc {
        lunar_m = mc;
        if leap_flag != 0 {
            is_leap = True;
        }
    } else {
        # Arithmetic / numeric-month form: CF_MONTH is year ordinal 1..13.
        decoded: list[int] = _chinese_ordinal_to_lunar(ly, month_field);
        lunar_m = decoded[0];
        if decoded[1] != 0 {
            is_leap = True;
        }
    }
    if is_leap {
        lm_leap: int = _lunar_leap_month(ly);
        if lm_leap <= 0 {
            lm_leap = lunar_m;
        }
        base: int = _lunar_to_days(ly, lm_leap, 1);
        days: int = base + _lunar_month_days(ly, lm_leap) + ld - 1;
        return civil_ymd_from_days(days);
    }
    days2: int = _lunar_to_days(ly, lunar_m, ld);
    return civil_ymd_from_days(days2);
}

def:pub chinese_months_in_year(year: int) -> int {
    return _lunar_months_in_year(year);
}

def:pub chinese_days_in_month(year: int, month: int) -> int {
    # `month` is Temporal year-ordinal (1..13), not bare lunar 1..12.
    decoded: list[int] = _chinese_ordinal_to_lunar(year, month);
    if decoded[1] != 0 {
        return _lunar_leap_days(year);
    }
    return _lunar_month_days(year, decoded[0]);
}

def:pub dangi_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    # Dangi shares Chinese math and also has no era system.
    return chinese_iso_to_fields(iso_y, iso_m, iso_d);
}

def:pub dangi_fields_to_iso(fields: list[int]) -> list[int] {
    return chinese_fields_to_iso(fields);
}

def:pub dangi_months_in_year(year: int) -> int {
    return chinese_months_in_year(year);
}

def:pub dangi_days_in_month(year: int, month: int) -> int {
    return chinese_days_in_month(year, month);
}
