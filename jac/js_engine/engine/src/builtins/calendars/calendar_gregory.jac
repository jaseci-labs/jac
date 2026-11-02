"""Gregorian-family calendars — Howard-Hinnant civil math + era-offset calendars.

Covers: iso8601, gregory, buddhist, coptic, ethiopic, ethioaa, indian, roc, japanese.
"""

import from engine.src.builtins.calendars.calendar_era {
    ERA_NONE,
    ERA_CE,
    ERA_BCE,
    ERA_BE,
    ERA_SAKA,
    ERA_ROC,
    ERA_BROC,
    ERA_MEIJI,
    ERA_TAISHO,
    ERA_SHOWA,
    ERA_HEISEI,
    ERA_REIWA,
    ERA_AM,
    ERA_AA
}

glob _JD_UNIX_EPOCH: int = 2440588,
     CF_YEAR: int = 0,
     CF_MONTH: int = 1,
     CF_MONTH_CODE: int = 2,
     CF_DAY: int = 3,
     CF_ERA: int = 4,
     CF_ERA_YEAR: int = 5,
     CF_DAYS_IN_MONTH: int = 6,
     CF_DAYS_IN_YEAR: int = 7,
     CF_IN_LEAP_YEAR: int = 8,
     CF_MONTHS_IN_YEAR: int = 9,
     CF_DAY_OF_YEAR: int = 10,
     CF_IS_LEAP_MONTH: int = 11;

# ── Field record layout (flat list[int] — strings via calendar_field_* helpers) ──
def:priv _gregory_fields_pack(
    year: int,
    month: int,
    day: int,
    era_id: int,
    era_year: int,
    month_code_ord: int,
    leap_month: bool,
    days_in_month: int,
    days_in_year: int,
    in_leap: bool,
    months_in_year: int,
    day_of_year: int
) -> list[int] {
    leap_m: int = 0;
    if leap_month {
        leap_m = 1;
    }
    leap_y: int = 0;
    if in_leap {
        leap_y = 1;
    }
    out: list[int] = [
        year,
        month,
        month_code_ord,
        day,
        era_id,
        era_year,
        days_in_month,
        days_in_year,
        leap_y,
        months_in_year,
        day_of_year,
        leap_m
    ];
    return out;
}

# ── Howard-Hinnant civil ↔ day number (1970-01-01 = 0) ─────────────────────

def:pub civil_days_from_ymd(y: int, m: int, d: int) -> int {
    adj_y: int = y;
    if m <= 2 {
        adj_y = adj_y - 1;
    }
    era: int = 0;
    if adj_y >= 0 {
        era = adj_y // 400;
    } else {
        era = (adj_y - 399) // 400;
    }
    yoe: int = adj_y - era * 400;
    mp: int = m - 3;
    if m <= 2 {
        mp = m + 9;
    }
    doy: int = (153 * mp + 2) // 5 + d - 1;
    doe: int = yoe * 365 + yoe // 4 - yoe // 100 + doy;
    return era * 146097 + doe - 719468;
}

def:pub civil_ymd_from_days(days: int) -> list[int] {
    z: int = days + 719468;
    era: int = 0;
    if z >= 0 {
        era = z // 146097;
    } else {
        era = (z - 146096) // 146097;
    }
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
    out: list[int] = [y, m, d];
    return out;
}

def:pub civil_is_leap(y: int) -> bool {
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

def _civil_days_in_month(y: int, m: int) -> int {
    if m == 2 {
        if civil_is_leap(y) {
            return 29;
        }
        return 28;
    }
    if m == 4 or m == 6 or m == 9 or m == 11 {
        return 30;
    }
    return 31;
}

def _civil_day_of_year(y: int, m: int, d: int) -> int {
    mdays: list[int] = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if civil_is_leap(y) {
        mdays[2] = 29;
    }
    doy: int = d;
    i: int = 1;
    while i < m {
        doy = doy + mdays[i];
        i = i + 1;
    }
    return doy;
}

def _year_days(leap: bool) -> int {
    if leap {
        return 366;
    }
    return 365;
}

def _iso8601_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    # iso8601 has no era system — .era / .eraYear must be undefined.
    dim: int = _civil_days_in_month(iso_y, iso_m);
    diy: int = _year_days(civil_is_leap(iso_y));
    doy: int = _civil_day_of_year(iso_y, iso_m, iso_d);
    return _gregory_fields_pack(
        iso_y,
        iso_m,
        iso_d,
        ERA_NONE,
        iso_y,
        iso_m,
        False,
        dim,
        diy,
        civil_is_leap(iso_y),
        12,
        doy
    );
}

def _gregory_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    dim: int = _civil_days_in_month(iso_y, iso_m);
    diy: int = _year_days(civil_is_leap(iso_y));
    doy: int = _civil_day_of_year(iso_y, iso_m, iso_d);
    era_id: int = ERA_CE;
    era_y: int = iso_y;
    if iso_y <= 0 {
        era_id = ERA_BCE;
        era_y = 1 - iso_y;
    }
    return _gregory_fields_pack(
        iso_y,
        iso_m,
        iso_d,
        era_id,
        era_y,
        iso_m,
        False,
        dim,
        diy,
        civil_is_leap(iso_y),
        12,
        doy
    );
}

def _gregory_fields_to_iso(fields: list[int]) -> list[int] {
    return [fields[CF_YEAR], fields[CF_MONTH], fields[CF_DAY]];
}

# ── Buddhist (+543) ─────────────────────────────────────────────────────────

def:pub buddhist_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    be_y: int = iso_y + 543;
    dim: int = _civil_days_in_month(iso_y, iso_m);
    diy: int = _year_days(civil_is_leap(iso_y));
    doy: int = _civil_day_of_year(iso_y, iso_m, iso_d);
    return _gregory_fields_pack(
        be_y,
        iso_m,
        iso_d,
        ERA_BE,
        be_y,
        iso_m,
        False,
        dim,
        diy,
        civil_is_leap(iso_y),
        12,
        doy
    );
}

def:pub buddhist_fields_to_iso(fields: list[int]) -> list[int] {
    return [fields[CF_YEAR] - 543, fields[CF_MONTH], fields[CF_DAY]];
}

def:pub buddhist_months_in_year(year: int) -> int {
    return 12;
}

def:pub buddhist_days_in_month(year: int, month: int) -> int {
    gy: int = year - 543;
    return _civil_days_in_month(gy, month);
}

# ── Coptic / Ethiopic (13-month Alexandrian) ────────────────────────────────

glob _COPTIC_JD_EPOCH: int = 1824665,
     _ETHIOPIC_JD_EPOCH: int = 1723856,
     _ETHIOAA_JD_EPOCH: int = -285019;

def _ce_is_leap(ext_year: int) -> bool {
    if ext_year % 4 == 3 {
        return True;
    }
    return False;
}

"""Convert JD → calendar fields for Alexandrian calendars (coptic / ethiopic / ethioaa).

era_mode:
  0 = coptic  — always era "am", eraYear = calendar year (1-based even when ≤ 0 via absolute)
  1 = ethiopic — era "am" when Amete Mihret year > 0; "aa" (Amete Alem = AM + 5500) otherwise
  2 = ethioaa — always era "aa", eraYear = Amete Alem year
"""
def _ce_jd_to_fields(
    jd: int, jd_epoch: int, year_offset: int, era_mode: int
) -> list[int] {
    rel: int = jd - jd_epoch;
    c4: int = 0;
    if rel >= 0 {
        c4 = rel // 1461;
    } else {
        c4 = (rel - 1460) // 1461;
    }
    r4: int = rel - c4 * 1461;
    ey: int = 4 * c4 + (r4 // 365 - r4 // 1460);
    doy0: int = 0;
    if r4 == 1460 {
        doy0 = 365;
    } else {
        doy0 = r4 % 365;
    }
    month0: int = doy0 // 30;
    day: int = doy0 % 30 + 1;
    month: int = month0 + 1;
    cy: int = ey + year_offset;
    dim: int = 30;
    if month == 13 {
        if _ce_is_leap(ey) {
            dim = 6;
        } else {
            dim = 5;
        }
    }
    diy: int = _year_days(_ce_is_leap(ey));
    doy: int = doy0 + 1;
    era_id: int = ERA_AM;
    era_y: int = cy;
    if era_mode == 0 {
        # Coptic: single era "am".
        era_id = ERA_AM;
        if cy <= 0 {
            era_y = 1 - cy;
        } else {
            era_y = cy;
        }
    } elif era_mode == 2 {
        # Ethioaa: always Amete Alem ("aa").
        era_id = ERA_AA;
        era_y = cy;
        if cy <= 0 {
            era_y = 1 - cy;
        }
    } else {
        # Ethiopic: "am" for Amete Mihret year > 0; "aa" otherwise (AM + 5500).
        if cy > 0 {
            era_id = ERA_AM;
            era_y = cy;
        } else {
            era_id = ERA_AA;
            era_y = cy + 5500;
            if era_y <= 0 {
                era_y = 1 - (cy + 5500);
            }
        }
    }
    mc_ord: int = month;
    if month == 13 {
        mc_ord = 13;
    }
    return _gregory_fields_pack(
        cy, month, day, era_id, era_y, mc_ord, False, dim, diy, _ce_is_leap(ey), 13, doy
    );
}

def _ce_fields_to_jd(fields: list[int], jd_epoch: int, year_offset: int) -> int {
    cy: int = fields[CF_YEAR];
    ey: int = cy - year_offset;
    month: int = fields[CF_MONTH];
    day: int = fields[CF_DAY];
    m0: int = month - 1;
    jd: int = jd_epoch + 365 * ey + ey // 4 + 30 * m0 + day - 1;
    return jd;
}

def _ce_fields_to_iso(fields: list[int], jd_epoch: int, year_offset: int) -> list[int] {
    jd: int = _ce_fields_to_jd(fields, jd_epoch, year_offset);
    days: int = jd - _JD_UNIX_EPOCH;
    return civil_ymd_from_days(days);
}

def:pub coptic_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    jd: int = days + _JD_UNIX_EPOCH;
    return _ce_jd_to_fields(jd, _COPTIC_JD_EPOCH, 0, 0);
}

def:pub coptic_fields_to_iso(fields: list[int]) -> list[int] {
    return _ce_fields_to_iso(fields, _COPTIC_JD_EPOCH, 0);
}

def:pub coptic_months_in_year(year: int) -> int {
    return 13;
}

def:pub coptic_days_in_month(year: int, month: int) -> int {
    if month == 13 {
        ey: int = year;
        if year <= 0 {
            ey = 1 - year;
        }
        if _ce_is_leap(ey) {
            return 6;
        }
        return 5;
    }
    return 30;
}

def:pub ethiopic_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    jd: int = days + _JD_UNIX_EPOCH;
    return _ce_jd_to_fields(jd, _ETHIOPIC_JD_EPOCH, 0, 1);
}

def:pub ethiopic_fields_to_iso(fields: list[int]) -> list[int] {
    return _ce_fields_to_iso(fields, _ETHIOPIC_JD_EPOCH, 0);
}

def:pub ethiopic_months_in_year(year: int) -> int {
    return 13;
}

def:pub ethiopic_days_in_month(year: int, month: int) -> int {
    return coptic_days_in_month(year, month);
}

def:pub ethioaa_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    jd: int = days + _JD_UNIX_EPOCH;
    f: list[any] = _ce_jd_to_fields(jd, _ETHIOAA_JD_EPOCH, 5500, 2);
    return f;
}

def:pub ethioaa_fields_to_iso(fields: list[int]) -> list[int] {
    return _ce_fields_to_iso(fields, _ETHIOAA_JD_EPOCH, 5500);
}

def:pub ethioaa_months_in_year(year: int) -> int {
    return 13;
}

def:pub ethioaa_days_in_month(year: int, month: int) -> int {
    return coptic_days_in_month(year, month);
}

# ── Indian (Saka) national calendar ─────────────────────────────────────────

glob _INDIAN_ERA_START: int = 78;

def _indian_month_len(saka_y: int, month: int) -> int {
    gy: int = saka_y + _INDIAN_ERA_START;
    if month == 1 {
        if civil_is_leap(gy) {
            return 31;
        }
        return 30;
    }
    if month >= 2 and month <= 6 {
        return 31;
    }
    return 30;
}

def _indian_to_days(saka_y: int, month: int, day: int) -> int {
    gy: int = saka_y + _INDIAN_ERA_START;
    leap_m: int = 30;
    if civil_is_leap(gy) {
        leap_m = 31;
    }
    if month == 1 {
        if civil_is_leap(gy) {
            return civil_days_from_ymd(gy, 3, 21) + day - 1;
        }
        return civil_days_from_ymd(gy, 3, 22) + day - 1;
    }
    start: int = civil_days_from_ymd(gy, 3, 22);
    if civil_is_leap(gy) {
        start = civil_days_from_ymd(gy, 3, 21);
    }
    start = start + leap_m;
    m: int = month - 2;
    if m > 5 {
        m = 5;
    }
    start = start + m * 31;
    if month >= 8 {
        start = start + (month - 7) * 30;
    }
    return start + day - 1;
}

def _indian_from_days(days: int) -> list[int] {
    y: int = 1300;
    i: int = 0;
    while i < 4000 {
        gy: int = y + _INDIAN_ERA_START;
        leap_m: int = 30;
        if civil_is_leap(gy) {
            leap_m = 31;
        }
        ystart: int = civil_days_from_ymd(gy, 3, 22);
        if civil_is_leap(gy) {
            ystart = civil_days_from_ymd(gy, 3, 21);
        }
        ylen: int = _year_days(civil_is_leap(gy));
        yend: int = ystart + ylen;
        if days >= ystart and days < yend {
            doy: int = days - ystart + 1;
            if doy <= leap_m {
                return [y, 1, doy];
            }
            rem: int = doy - leap_m;
            month: int = 0;
            day: int = 0;
            if rem > 5 * 31 {
                rem2: int = rem - 5 * 31;
                month = 7 + (rem2 - 1) // 30;
                day = (rem2 - 1) % 30 + 1;
            } else {
                month = 2 + (rem - 1) // 31;
                day = (rem - 1) % 31 + 1;
            }
            return [y, month, day];
        }
        y = y + 1;
        i = i + 1;
    }
    return [1, 1, 1];
}

def:pub indian_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    days: int = civil_days_from_ymd(iso_y, iso_m, iso_d);
    ymd: list[int] = _indian_from_days(days);
    sy: int = ymd[0];
    sm: int = ymd[1];
    sd: int = ymd[2];
    dim: int = _indian_month_len(sy, sm);
    gy: int = sy + _INDIAN_ERA_START;
    diy: int = _year_days(civil_is_leap(gy));
    doy: int = days - _indian_to_days(sy, 1, 1) + 1;
    return _gregory_fields_pack(
        sy, sm, sd, ERA_SAKA, sy, sm, False, dim, diy, civil_is_leap(gy), 12, doy
    );
}

def:pub indian_fields_to_iso(fields: list[int]) -> list[int] {
    days: int = _indian_to_days(fields[CF_YEAR], fields[CF_MONTH], fields[CF_DAY]);
    return civil_ymd_from_days(days);
}

def:pub indian_months_in_year(year: int) -> int {
    return 12;
}

def:pub indian_days_in_month(year: int, month: int) -> int {
    return _indian_month_len(year, month);
}

# ── ROC (Minguo) ────────────────────────────────────────────────────────────

def:pub roc_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    # Temporal ROC `year` is signed Minguo year (iso - 1911), not Gregorian.
    cal_y: int = iso_y - 1911;
    era_id: int = ERA_ROC;
    era_y: int = cal_y;
    if iso_y < 1912 {
        era_id = ERA_BROC;
        era_y = 1912 - iso_y;
    }
    dim: int = _civil_days_in_month(iso_y, iso_m);
    diy: int = _year_days(civil_is_leap(iso_y));
    doy: int = _civil_day_of_year(iso_y, iso_m, iso_d);
    return _gregory_fields_pack(
        cal_y,
        iso_m,
        iso_d,
        era_id,
        era_y,
        iso_m,
        False,
        dim,
        diy,
        civil_is_leap(iso_y),
        12,
        doy
    );
}

def:pub roc_fields_to_iso(fields: list[int]) -> list[int] {
    gy: int = fields[CF_YEAR] + 1911;
    era_id: int = fields[CF_ERA];
    ey: int = fields[CF_ERA_YEAR];
    if era_id == ERA_ROC {
        gy = ey + 1911;
    } elif era_id == ERA_BROC {
        gy = 1912 - ey;
    }
    return [gy, fields[CF_MONTH], fields[CF_DAY]];
}

def:pub roc_months_in_year(year: int) -> int {
    return 12;
}

def:pub roc_days_in_month(year: int, month: int) -> int {
    gy: int = year + 1911;
    return _civil_days_in_month(gy, month);
}

# ── Japanese imperial eras ──────────────────────────────────────────────────

glob _JP_ERA_STARTS: list[int] = [
         18680125,
         19120730,
         19261225,
         19890108,
         20190501,
         99991231
     ],
     _JP_ERA_NAMES: list[str] = ["meiji", "taisho", "showa", "heisei", "reiwa"];

def _jp_int_date(y: int, m: int, d: int) -> int {
    return y * 10000 + m * 100 + d;
}

def _jp_era_id_for_gregorian(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    id: int = _jp_int_date(iso_y, iso_m, iso_d);
    if id >= _jp_int_date(2019, 5, 1) {
        out: list[int] = [ERA_REIWA, iso_y - 2018];
        return out;
    }
    if id >= _jp_int_date(1989, 1, 8) {
        out2: list[int] = [ERA_HEISEI, iso_y - 1988];
        return out2;
    }
    if id >= _jp_int_date(1926, 12, 25) {
        out3: list[int] = [ERA_SHOWA, iso_y - 1925];
        return out3;
    }
    if id >= _jp_int_date(1912, 7, 30) {
        out4: list[int] = [ERA_TAISHO, iso_y - 1911];
        return out4;
    }
    if id >= _jp_int_date(1868, 1, 25) {
        out5: list[int] = [ERA_MEIJI, iso_y - 1867];
        return out5;
    }
    if iso_y <= 0 {
        out6: list[int] = [ERA_BCE, 1 - iso_y];
        return out6;
    }
    out7: list[int] = [ERA_CE, iso_y];
    return out7;
}

def:pub japanese_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    er: list[int] = _jp_era_id_for_gregorian(iso_y, iso_m, iso_d);
    era_id: int = er[0];
    era_y: int = er[1];
    dim: int = _civil_days_in_month(iso_y, iso_m);
    diy: int = _year_days(civil_is_leap(iso_y));
    doy: int = _civil_day_of_year(iso_y, iso_m, iso_d);
    return _gregory_fields_pack(
        iso_y,
        iso_m,
        iso_d,
        era_id,
        era_y,
        iso_m,
        False,
        dim,
        diy,
        civil_is_leap(iso_y),
        12,
        doy
    );
}

def:pub japanese_fields_to_iso(fields: list[int]) -> list[int] {
    era_id: int = fields[CF_ERA];
    ey: int = fields[CF_ERA_YEAR];
    gy: int = fields[CF_YEAR];
    if era_id == ERA_REIWA {
        gy = 2018 + ey;
    } elif era_id == ERA_HEISEI {
        gy = 1988 + ey;
    } elif era_id == ERA_SHOWA {
        gy = 1925 + ey;
    } elif era_id == ERA_TAISHO {
        gy = 1911 + ey;
    } elif era_id == ERA_MEIJI {
        gy = 1867 + ey;
    } elif era_id == ERA_BCE {
        gy = 1 - ey;
    } elif era_id == ERA_CE {
        gy = ey;
    }
    return [gy, fields[CF_MONTH], fields[CF_DAY]];
}

def:pub japanese_months_in_year(year: int) -> int {
    return 12;
}

def:pub japanese_days_in_month(year: int, month: int) -> int {
    return _civil_days_in_month(year, month);
}

# ── Public gregory / iso8601 aliases ────────────────────────────────────────

def:pub gregory_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    return _gregory_iso_to_fields(iso_y, iso_m, iso_d);
}

def:pub gregory_fields_to_iso(fields: list[int]) -> list[int] {
    return _gregory_fields_to_iso(fields);
}

def:pub gregory_months_in_year(year: int) -> int {
    return 12;
}

def:pub gregory_days_in_month(year: int, month: int) -> int {
    return _civil_days_in_month(year, month);
}

def:pub iso8601_iso_to_fields(iso_y: int, iso_m: int, iso_d: int) -> list[int] {
    return _iso8601_iso_to_fields(iso_y, iso_m, iso_d);
}

def:pub iso8601_fields_to_iso(fields: list[int]) -> list[int] {
    return _gregory_fields_to_iso(fields);
}

def:pub iso8601_months_in_year(year: int) -> int {
    return 12;
}

def:pub iso8601_days_in_month(year: int, month: int) -> int {
    return _civil_days_in_month(year, month);
}
