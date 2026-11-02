"""Islamic Umm al-Qura calendar — ICU table (AH 1300–1600, ~1882–2077 CE)."""

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
    civil_days_from_ymd,
    civil_ymd_from_days
}

import from engine.src.builtins.calendars.calendar_era { ERA_AH, ERA_BH }

import from engine.src.builtins.calendars.calendar_islamic {
    islamic_civil_iso_to_fields,
    islamic_civil_fields_to_iso,
    islamic_civil_days_in_month,
    islamic_civil_months_in_year
}

glob _UMALQURA_YEAR_START: int = 1300,
     _UMALQURA_YEAR_END: int = 1600;

glob:priv _UMALQURA_CIVIL_EPOCH: int = -492148;

glob _UMALQURA_MONTHLENGTH: list[int] = [
         2730,
         3412,
         3785,
         1748,
         1770,
         876,
         2733,
         1365,
         1705,
         1938,
         2985,
         1492,
         2778,
         1372,
         3373,
         1685,
         1866,
         2900,
         2922,
         1453,
         1198,
         2639,
         1303,
         1675,
         1701,
         2773,
         726,
         2395,
         1181,
         2637,
         3366,
         3477,
         1452,
         2486,
         698,
         2651,
         1323,
         2709,
         1738,
         2793,
         756,
         2422,
         694,
         2390,
         2762,
         2980,
         3026,
         1497,
         732,
         2413,
         1357,
         2725,
         2898,
         2981,
         1460,
         2486,
         1367,
         663,
         1355,
         1699,
         1874,
         2917,
         1386,
         2731,
         1323,
         3221,
         3402,
         3493,
         1482,
         2774,
         2391,
         1195,
         2379,
         2725,
         2898,
         2922,
         1397,
         630,
         2231,
         1115,
         1365,
         1449,
         1460,
         2522,
         1245,
         622,
         2358,
         2730,
         3412,
         3506,
         1493,
         730,
         2395,
         1195,
         2645,
         2889,
         2916,
         2929,
         1460,
         2741,
         2645,
         3365,
         3730,
         3785,
         1748,
         2793,
         2411,
         1195,
         2707,
         3401,
         3492,
         3506,
         2745,
         1210,
         2651,
         1323,
         2709,
         2858,
         2901,
         1372,
         1213,
         573,
         2333,
         2709,
         2890,
         2906,
         1389,
         694,
         2363,
         1179,
         1621,
         1705,
         1876,
         2922,
         1388,
         2733,
         1365,
         2857,
         2962,
         2985,
         1492,
         2778,
         1370,
         2731,
         1429,
         1865,
         1892,
         2986,
         1461,
         694,
         2646,
         3661,
         2853,
         2898,
         2922,
         1453,
         686,
         2351,
         1175,
         1611,
         1701,
         1708,
         2774,
         1373,
         1181,
         2637,
         3350,
         3477,
         1450,
         1461,
         730,
         2395,
         1197,
         1429,
         1738,
         1764,
         2794,
         1269,
         694,
         2390,
         2730,
         2900,
         3026,
         1497,
         746,
         2413,
         1197,
         2709,
         2890,
         2981,
         1458,
         2485,
         1238,
         2711,
         1351,
         1683,
         1865,
         2901,
         1386,
         2667,
         1323,
         2699,
         3398,
         3491,
         1482,
         2774,
         1243,
         619,
         2379,
         2725,
         2898,
         2921,
         1397,
         374,
         2231,
         603,
         1323,
         1381,
         1460,
         2522,
         1261,
         365,
         2230,
         2726,
         3410,
         3497,
         1492,
         2778,
         2395,
         1195,
         1619,
         1833,
         1890,
         2985,
         1458,
         2741,
         1365,
         2853,
         3474,
         3785,
         1746,
         2793,
         1387,
         1195,
         2645,
         3369,
         3412,
         3498,
         2485,
         1210,
         2619,
         1179,
         2637,
         2730,
         2773,
         730,
         2397,
         1118,
         2606,
         3226,
         3413,
         1714,
         1721,
         1210,
         2653,
         1325,
         2709,
         2898,
         2984,
         2996,
         1465,
         730,
         2394,
         2890,
         3492,
         3793,
         1768,
         2922,
         1389,
         1333,
         1685,
         3402,
         3496,
         3540,
         1754,
         1371,
         669,
         1579,
         2837,
         2890,
         2965,
         1450,
         2734,
         2350,
         3215,
         1319,
         1685,
         1706,
         2774,
         1373,
         669
     ],
     _UMALQURA_YR_FIX: list[int] = [
         0,
         0,
         -1,
         0,
         -1,
         0,
         0,
         0,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         1,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         0,
         0,
         0,
         1,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         -1,
         0,
         0,
         0,
         1,
         1,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         1,
         0,
         0,
         -1,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         -1,
         -1,
         0,
         -1,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         -1,
         0,
         0,
         -1,
         -1,
         0,
         -1,
         0,
         -1,
         0,
         0,
         -1,
         -1,
         0,
         0,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         1,
         0,
         0,
         -1,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         0,
         0,
         0,
         1,
         1,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         1,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         0,
         -1,
         0,
         -1,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         1,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         0,
         -1,
         0,
         -1,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         -1,
         0,
         1,
         0,
         0,
         -1,
         -1,
         0,
         0,
         1,
         1,
         0,
         0,
         -1,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         1
     ];

def _umalqura_in_range(year: int) -> bool {
    if year < _UMALQURA_YEAR_START {
        return False;
    }
    if year > _UMALQURA_YEAR_END {
        return False;
    }
    return True;
}

def _umalqura_month_len(year: int, month: int) -> int {
    if not _umalqura_in_range(year) {
        return 29;
    }
    idx: int = year - _UMALQURA_YEAR_START;
    mask: int = 1 << (11 - (month - 1));
    if (_UMALQURA_MONTHLENGTH[idx] & mask) != 0 {
        return 30;
    }
    return 29;
}

def _umalqura_year_start(year: int) -> int {
    if not _umalqura_in_range(year) {
        ys: int = _UMALQURA_CIVIL_EPOCH + (354 * year + 3 * (year // 30)) // 30;
        return ys;
    }
    yi: int = year - _UMALQURA_YEAR_START;
    est: int = (3543672 * yi) // 10000 + 460322;
    return est + _UMALQURA_YR_FIX[yi];
}

def _umalqura_year_len(year: int) -> int {
    total: int = 0;
    m: int = 1;
    while m <= 12 {
        total = total + _umalqura_month_len(year, m);
        m = m + 1;
    }
    return total;
}

def _umalqura_to_days(year: int, month: int, day: int) -> int {
    ys: int = _umalqura_year_start(year);
    m: int = 1;
    while m < month {
        ys = ys + _umalqura_month_len(year, m);
        m = m + 1;
    }
    return ys + day - 1;
}

def _umalqura_from_days(days: int) -> list[int] {
    year: int = 1400;
    i: int = 0;
    while i < 400 {
        ys: int = _umalqura_year_start(year);
        ylen: int = _umalqura_year_len(year);
        if days < ys {
            year = year - 1;
        } elif days >= ys + ylen {
            year = year + 1;
        } else {
            rem: int = days - ys + 1;
            month: int = 1;
            while month <= 12 {
                mlen: int = _umalqura_month_len(year, month);
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

def:priv _umalqura_month_code(month: int) -> str {
    mc: str = "M";
    if month < 10 {
        mc = mc + "0";
    }
    mc = mc + str(month);
    return mc;
}

def:pub islamic_umalqura_iso_to_fields(
    iso_y: int, iso_m: int, iso_d: int
) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    ymd: list[int] = _umalqura_from_days(days);
    ay: int = ymd[0];
    am: int = ymd[1];
    ad: int = ymd[2];
    dim: int = _umalqura_month_len(ay, am);
    diy: int = _umalqura_year_len(ay);
    doy: int = ad;
    mi: int = 1;
    while mi < am {
        doy = doy + _umalqura_month_len(ay, mi);
        mi = mi + 1;
    }
    era_id: int = ERA_AH;
    era_y: int = ay;
    if ay <= 0 {
        era_id = ERA_BH;
        era_y = 1 - ay;
    }
    return [ay, am, am, ad, era_id, era_y, dim, diy, 0, 12, doy, 0];
}

def:pub islamic_umalqura_fields_to_iso(fields: list[int]) -> list[int] {
    ay: int = fields[CF_YEAR];
    if not _umalqura_in_range(ay) {
        return islamic_civil_fields_to_iso(fields);
    }
    days: int = _umalqura_to_days(ay, fields[CF_MONTH], fields[CF_DAY]);
    return civil_ymd_from_days(days);
}

def:pub islamic_umalqura_months_in_year(year: int) -> int {
    return islamic_civil_months_in_year(year);
}

def:pub islamic_umalqura_days_in_month(year: int, month: int) -> int {
    if not _umalqura_in_range(year) {
        return islamic_civil_days_in_month(year, month);
    }
    return _umalqura_month_len(year, month);
}
