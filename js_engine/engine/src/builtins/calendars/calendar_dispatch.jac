"""Temporal calendar dispatch — routes calendar IDs to per-calendar modules."""

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
    iso8601_iso_to_fields,
    iso8601_fields_to_iso,
    iso8601_months_in_year,
    iso8601_days_in_month,
    gregory_iso_to_fields,
    gregory_fields_to_iso,
    gregory_months_in_year,
    gregory_days_in_month,
    buddhist_iso_to_fields,
    buddhist_fields_to_iso,
    buddhist_months_in_year,
    buddhist_days_in_month,
    coptic_iso_to_fields,
    coptic_fields_to_iso,
    coptic_months_in_year,
    coptic_days_in_month,
    ethiopic_iso_to_fields,
    ethiopic_fields_to_iso,
    ethiopic_months_in_year,
    ethiopic_days_in_month,
    ethioaa_iso_to_fields,
    ethioaa_fields_to_iso,
    ethioaa_months_in_year,
    ethioaa_days_in_month,
    indian_iso_to_fields,
    indian_fields_to_iso,
    indian_months_in_year,
    indian_days_in_month,
    roc_iso_to_fields,
    roc_fields_to_iso,
    roc_months_in_year,
    roc_days_in_month,
    japanese_iso_to_fields,
    japanese_fields_to_iso,
    japanese_months_in_year,
    japanese_days_in_month
}

import from engine.src.builtins.calendars.calendar_persian {
    persian_iso_to_fields,
    persian_fields_to_iso,
    persian_months_in_year,
    persian_days_in_month
}

import from engine.src.builtins.calendars.calendar_hebrew {
    hebrew_iso_to_fields,
    hebrew_fields_to_iso,
    hebrew_months_in_year,
    hebrew_days_in_month
}

import from engine.src.builtins.calendars.calendar_islamic {
    islamic_civil_iso_to_fields,
    islamic_civil_fields_to_iso,
    islamic_civil_months_in_year,
    islamic_civil_days_in_month,
    islamic_tbla_iso_to_fields,
    islamic_tbla_fields_to_iso,
    islamic_tbla_months_in_year,
    islamic_tbla_days_in_month
}

import from engine.src.builtins.calendars.calendar_islamic_umalqura {
    islamic_umalqura_iso_to_fields,
    islamic_umalqura_fields_to_iso,
    islamic_umalqura_months_in_year,
    islamic_umalqura_days_in_month
}

import from engine.src.builtins.calendars.calendar_era {
    calendar_era_name,
    calendar_month_code_str
}

import from engine.src.builtins.calendars.calendar_chinese {
    chinese_iso_to_fields,
    chinese_fields_to_iso,
    chinese_months_in_year,
    chinese_days_in_month,
    dangi_iso_to_fields,
    dangi_fields_to_iso,
    dangi_months_in_year,
    dangi_days_in_month
}

glob _KNOWN_CALENDARS: list[str] = [
         "iso8601",
         "gregory",
         "buddhist",
         "coptic",
         "ethiopic",
         "ethioaa",
         "indian",
         "japanese",
         "persian",
         "roc",
         "hebrew",
         "islamic-civil",
         "islamic-tbla",
         "islamic-umalqura",
         "chinese",
         "dangi"
     ];

def _lower_ascii(c: str) -> str {
    upper: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    lower: str = "abcdefghijklmnopqrstuvwxyz";
    i: int = 0;
    while i < 26 {
        if c == upper[i:i + 1] {
            return lower[i:i + 1];
        }
        i = i + 1;
    }
    return c;
}

def _str_lower(s: str) -> str {
    out: str = "";
    i: int = 0;
    while i < len(s) {
        out = out + _lower_ascii(s[i:i + 1]);
        i = i + 1;
    }
    return out;
}

def _str_eq_ci(a: str, b: str) -> bool {
    return _str_lower(a) == _str_lower(b);
}

def:pub calendar_id_normalize(s: str) -> str {
    id: str = _str_lower(s);
    if id == "islamic" {
        return "islamic-civil";
    }
    if id == "islamic-c" {
        return "islamic-civil";
    }
    if id == "islamic-rgsa" {
        return "islamic-tbla";
    }
    if id == "islamicc" {
        return "islamic-civil";
    }
    return id;
}

def:pub calendar_is_known(id: str) -> bool {
    norm: str = calendar_id_normalize(id);
    i: int = 0;
    while i < len(_KNOWN_CALENDARS) {
        if _KNOWN_CALENDARS[i] == norm {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def:pub calendar_iso_to_fields(
    iso_y: int, iso_m: int, iso_d: int, calendar_id: str
) -> list[int] {
    id: str = calendar_id_normalize(calendar_id);
    if id == "iso8601" {
        return iso8601_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "gregory" {
        return gregory_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "buddhist" {
        return buddhist_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "coptic" {
        return coptic_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "ethiopic" {
        return ethiopic_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "ethioaa" {
        return ethioaa_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "indian" {
        return indian_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "japanese" {
        return japanese_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "persian" {
        return persian_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "roc" {
        return roc_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "hebrew" {
        return hebrew_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "islamic-civil" {
        return islamic_civil_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "islamic-tbla" {
        return islamic_tbla_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "islamic-umalqura" {
        return islamic_umalqura_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "chinese" {
        return chinese_iso_to_fields(iso_y, iso_m, iso_d);
    }
    if id == "dangi" {
        return dangi_iso_to_fields(iso_y, iso_m, iso_d);
    }
    return gregory_iso_to_fields(iso_y, iso_m, iso_d);
}

def:pub calendar_fields_to_iso(fields: list[int], calendar_id: str) -> list[int] {
    id: str = calendar_id_normalize(calendar_id);
    if id == "iso8601" {
        return iso8601_fields_to_iso(fields);
    }
    if id == "gregory" {
        return gregory_fields_to_iso(fields);
    }
    if id == "buddhist" {
        return buddhist_fields_to_iso(fields);
    }
    if id == "coptic" {
        return coptic_fields_to_iso(fields);
    }
    if id == "ethiopic" {
        return ethiopic_fields_to_iso(fields);
    }
    if id == "ethioaa" {
        return ethioaa_fields_to_iso(fields);
    }
    if id == "indian" {
        return indian_fields_to_iso(fields);
    }
    if id == "japanese" {
        return japanese_fields_to_iso(fields);
    }
    if id == "persian" {
        return persian_fields_to_iso(fields);
    }
    if id == "roc" {
        return roc_fields_to_iso(fields);
    }
    if id == "hebrew" {
        return hebrew_fields_to_iso(fields);
    }
    if id == "islamic-civil" {
        return islamic_civil_fields_to_iso(fields);
    }
    if id == "islamic-tbla" {
        return islamic_tbla_fields_to_iso(fields);
    }
    if id == "islamic-umalqura" {
        return islamic_umalqura_fields_to_iso(fields);
    }
    if id == "chinese" {
        return chinese_fields_to_iso(fields);
    }
    if id == "dangi" {
        return dangi_fields_to_iso(fields);
    }
    return gregory_fields_to_iso(fields);
}

def:pub calendar_months_in_year(calendar_id: str, year: int) -> int {
    id: str = calendar_id_normalize(calendar_id);
    if id == "iso8601" {
        return iso8601_months_in_year(year);
    }
    if id == "gregory" {
        return gregory_months_in_year(year);
    }
    if id == "buddhist" {
        return buddhist_months_in_year(year);
    }
    if id == "coptic" {
        return coptic_months_in_year(year);
    }
    if id == "ethiopic" {
        return ethiopic_months_in_year(year);
    }
    if id == "ethioaa" {
        return ethioaa_months_in_year(year);
    }
    if id == "indian" {
        return indian_months_in_year(year);
    }
    if id == "japanese" {
        return japanese_months_in_year(year);
    }
    if id == "persian" {
        return persian_months_in_year(year);
    }
    if id == "roc" {
        return roc_months_in_year(year);
    }
    if id == "hebrew" {
        return hebrew_months_in_year(year);
    }
    if id == "islamic-civil" {
        return islamic_civil_months_in_year(year);
    }
    if id == "islamic-tbla" {
        return islamic_tbla_months_in_year(year);
    }
    if id == "islamic-umalqura" {
        return islamic_umalqura_months_in_year(year);
    }
    if id == "chinese" {
        return chinese_months_in_year(year);
    }
    if id == "dangi" {
        return dangi_months_in_year(year);
    }
    return 12;
}

def:pub calendar_days_in_month(calendar_id: str, year: int, month: int) -> int {
    id: str = calendar_id_normalize(calendar_id);
    if id == "iso8601" {
        return iso8601_days_in_month(year, month);
    }
    if id == "gregory" {
        return gregory_days_in_month(year, month);
    }
    if id == "buddhist" {
        return buddhist_days_in_month(year, month);
    }
    if id == "coptic" {
        return coptic_days_in_month(year, month);
    }
    if id == "ethiopic" {
        return ethiopic_days_in_month(year, month);
    }
    if id == "ethioaa" {
        return ethioaa_days_in_month(year, month);
    }
    if id == "indian" {
        return indian_days_in_month(year, month);
    }
    if id == "japanese" {
        return japanese_days_in_month(year, month);
    }
    if id == "persian" {
        return persian_days_in_month(year, month);
    }
    if id == "roc" {
        return roc_days_in_month(year, month);
    }
    if id == "hebrew" {
        return hebrew_days_in_month(year, month);
    }
    if id == "islamic-civil" {
        return islamic_civil_days_in_month(year, month);
    }
    if id == "islamic-tbla" {
        return islamic_tbla_days_in_month(year, month);
    }
    if id == "islamic-umalqura" {
        return islamic_umalqura_days_in_month(year, month);
    }
    if id == "chinese" {
        return chinese_days_in_month(year, month);
    }
    if id == "dangi" {
        return dangi_days_in_month(year, month);
    }
    return gregory_days_in_month(year, month);
}

def:pub calendar_field_year(fields: list[int]) -> int {
    return fields[CF_YEAR];
}

def:pub calendar_field_month(fields: list[int]) -> int {
    return fields[CF_MONTH];
}

def:pub calendar_field_day(fields: list[int]) -> int {
    return fields[CF_DAY];
}

def:pub calendar_field_month_code(fields: list[int]) -> str {
    ord_m: int = fields[CF_MONTH_CODE];
    leap_m: bool = False;
    if len(fields) > CF_IS_LEAP_MONTH and fields[CF_IS_LEAP_MONTH] != 0 {
        leap_m = True;
    }
    return calendar_month_code_str(ord_m, leap_m);
}

def:pub calendar_field_era(fields: list[int]) -> str {
    if len(fields) <= CF_ERA {
        return "";
    }
    return calendar_era_name(fields[CF_ERA]);
}

def:pub calendar_field_era_year(fields: list[int]) -> int {
    return fields[CF_ERA_YEAR];
}

def:pub calendar_field_days_in_month(fields: list[int]) -> int {
    return fields[CF_DAYS_IN_MONTH];
}

def:pub calendar_field_days_in_year(fields: list[int]) -> int {
    return fields[CF_DAYS_IN_YEAR];
}

def:pub calendar_field_in_leap_year(fields: list[int]) -> bool {
    return fields[CF_IN_LEAP_YEAR] != 0;
}

def:pub calendar_field_months_in_year(fields: list[int]) -> int {
    return fields[CF_MONTHS_IN_YEAR];
}

def:pub calendar_field_day_of_year(fields: list[int]) -> int {
    return fields[CF_DAY_OF_YEAR];
}
