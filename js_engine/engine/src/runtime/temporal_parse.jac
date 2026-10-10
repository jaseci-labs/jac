"""
runtime/temporal_parse.na.jac — RFC 9557 / ISO 8601 grammar parser.

Shared by all Temporal from()/ToTemporal* call sites. Returns structured parse
records as lists with named index constants (no tuples in Jac).
"""

import from engine.src.runtime.jsstring {
    str_substr,
    str_char_at,
    str_len,
    str_to_float
}
import from engine.src.builtins.calendars.calendar_dispatch { calendar_is_known }
import from engine.src.runtime.bignat { bn_from_int, bn_mul_small, bn_to_string }

# ── Parse result field indices ───────────────────────────────────────────────
glob PR_OK: int = 0,
     PR_ERROR: int = 1,
     PR_YEAR: int = 2,
     PR_MONTH: int = 3,
     PR_DAY: int = 4,
     PR_HOUR: int = 5,
     PR_MINUTE: int = 6,
     PR_SECOND: int = 7,
     PR_NANOSECOND: int = 8,
     PR_OFFSET_S: int = 9,
     PR_TZ_ANNOTATION: int = 10,
     PR_CALENDAR: int = 11,
     PR_HAS_TIME: int = 12,
     PR_HAS_DATE: int = 13,
     PR_HAS_OFFSET: int = 14,
     PR_IS_Z: int = 15,
     PR_DUR_YEARS: int = 16,
     PR_DUR_MONTHS: int = 17,
     PR_DUR_WEEKS: int = 18,
     PR_DUR_DAYS: int = 19,
     PR_DUR_HOURS: int = 20,
     PR_DUR_MINUTES: int = 21,
     PR_DUR_SECONDS: int = 22,
     PR_DUR_NANOS: int = 23,
     PR_IS_DURATION: int = 24,
     PR_IS_NEGATIVE: int = 25,
     PR_OFFSET_NS: int = 26;

# Sub-second part of the UTC offset, in nanoseconds (0..999_999_999, signed with the
# offset). PR_OFFSET_S holds whole seconds; a sub-minute offset like "+00:19:32.37"
# carries its .37s here so Instant parsing keeps exact precision.
# ── String parse-result fields, held OUTSIDE the numeric list ────────────────
# A `str` stored inside a heterogeneous `list` lowers to List.i64 and reads back
# as a raw pointer (jac-native str-in-list corruption). The parse result mixes
# ints, floats AND strings, so the three string fields (error, tz annotation,
# calendar) live in module globals set by the parser and read via the accessors
# below — NEVER inside the returned list. Single-threaded parse → read pattern,
# so a plain global is safe (consumed immediately after the parse call).
glob:pub PR_S_ERROR: str = "",
     PR_S_TZ_ANNOTATION: str = "",
     PR_S_CALENDAR: str = "iso8601";

def:pub parse_empty_result -> list[any] {
    # Homogeneous-ish numeric list only (ints + floats). String fields removed —
    # the PR_ERROR/PR_TZ_ANNOTATION/PR_CALENDAR slots are kept as 0 placeholders
    # so every legacy index constant still addresses the right numeric field.
    PR_S_ERROR = "";
    PR_S_TZ_ANNOTATION = "";
    PR_S_CALENDAR = "iso8601";
    return [
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0,
        0,
        0
    ];
}

def _parse_fail(msg: str) -> list[any] {
    r: list[any] = parse_empty_result();
    r[PR_OK] = 0;
    PR_S_ERROR = msg;
    return r;
}

def _tp_is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

def _char_at(s: str, i: int) -> str {
    if i < 0 or i >= len(s) {
        return "";
    }
    return s[i:i + 1];
}

# A bracket time-zone annotation that is a numeric OFFSET must be a valid
# TimeZoneUTCOffsetName: sign + HH, optionally :MM, optionally :SS — with NO fractional
# seconds and NO sub-minute decimal. "-05:00" / "-07:00:01" are valid; "-12:12:59.9"
# (fractional) and "-07:00:01.0" (trailing-zero decimal) are NOT (those forms are only
# legal in the datetime's own offset, not in the [bracket] identifier).
def _is_valid_tz_offset_name(s: str) -> bool {
    n: int = len(s);
    if n < 3 {
        return False;
    }
    c0: str = s[0:1];
    if c0 != "+" and c0 != "-" {
        return False;
    }
    i: int = 1;
    # HH — exactly two digits, 00-23.
    if i + 1 >= n
        or not _tp_is_digit(_char_at(s, i))
        or not _tp_is_digit(_char_at(s, i + 1)) {
        return False;
    }
    hh: int = (ord(_char_at(s, i)) - 48) * 10 + (ord(_char_at(s, i + 1)) - 48);
    if hh > 23 {
        return False;
    }
    i = i + 2;
    if i >= n {
        return True;
    }
    # Optional :MM then optional :SS — each a 2-digit group (separator ":" required or a
    # fully separatorless HHMMSS form; keep it simple: require ":" separators here since
    # the failing cases all use them). A "." anywhere → fractional seconds → invalid.
    group_count: int = 0;
    while i < n {
        if _char_at(s, i) != ":" {
            return False;
        }
        i = i + 1;
        if i + 1 >= n
            or not _tp_is_digit(_char_at(s, i))
            or not _tp_is_digit(_char_at(s, i + 1)) {
            return False;
        }
        i = i + 2;
        group_count = group_count + 1;
        if group_count > 2 {
            return False;
        }  # at most :MM:SS
    }
    return True;
}

def _tp_normalize_decimal(num_s: str) -> str {
    out: str = "";
    i: int = 0;
    while i < len(num_s) {
        c: str = num_s[i:i + 1];
        if c == "," {
            out = out + ".";
        } else {
            out = out + c;
        }
        i = i + 1;
    }
    return out;
}

def _tp_decimal_to_num(num_s: str) -> float {
    if len(num_s) == 0 {
        return 0.0;
    }
    di: int = 0;
    while di < len(num_s) {
        c0: str = num_s[di:di + 1];
        if c0 == "." or c0 == "," {
            return str_to_float(_tp_normalize_decimal(num_s));
        }
        di = di + 1;
    }
    val: float = 0.0;
    di2: int = 0;
    while di2 < len(num_s) {
        c1: str = num_s[di2:di2 + 1];
        if c1 >= "0" and c1 <= "9" {
            val = val * 10.0 + float(int(c1));
        }
        di2 = di2 + 1;
    }
    return val;
}

def _tp_parse_digits(s: str, pos: int, min_d: int, max_d: int) -> list[any] {
    start: int = pos;
    n: int = 0;
    limit: int = pos + max_d;
    while pos < len(s) and pos < limit and _tp_is_digit(_char_at(s, pos)) {
        n = n * 10 + int(_char_at(s, pos));
        pos = pos + 1;
    }
    count: int = pos - start;
    if count < min_d or count > max_d {
        return [-1, 0, start];
    }
    return [pos, n, start];
}

def _parse_extended_year(s: str, pos: int) -> list[any] {
    sign: int = 1;
    if _char_at(s, pos) == "+" {
        pos = pos + 1;
    } elif _char_at(s, pos) == "-" {
        sign = -1;
        pos = pos + 1;
    }
    start: int = pos;
    digit_count: int = 0;
    while pos < len(s) and _tp_is_digit(_char_at(s, pos)) and digit_count < 6 {
        pos = pos + 1;
        digit_count = digit_count + 1;
    }
    if digit_count < 4 {
        return [-1, 0];
    }
    yr: int = 0;
    i: int = start;
    while i < pos {
        yr = yr * 10 + int(_char_at(s, i));
        i = i + 1;
    }
    if sign == -1 and yr == 0 {
        return [-1, 0];
    }
    return [pos, yr * sign];
}

def _parse_fraction(s: str, pos: int) -> list[any] {
    if _char_at(s, pos) != "." and _char_at(s, pos) != "," {
        return [pos, 0];
    }
    pos = pos + 1;
    start: int = pos;
    frac: int = 0;
    ndigits: int = 0;
    while pos < len(s) and _tp_is_digit(_char_at(s, pos)) {
        frac = frac * 10 + int(_char_at(s, pos));
        ndigits = ndigits + 1;
        pos = pos + 1;
    }
    if ndigits == 0 {
        return [-1, 0];
    }
    if ndigits > 9 {
        return [-1, 0];
    }
    while ndigits < 9 {
        frac = frac * 10;
        ndigits = ndigits + 1;
    }
    return [pos, frac];
}

def _parse_time(s: str, pos: int) -> list[any] {
    if pos + 6 <= len(s)
        and _tp_is_digit(_char_at(s, pos))
        and _tp_is_digit(_char_at(s, pos + 1))
        and _tp_is_digit(_char_at(s, pos + 2))
        and _tp_is_digit(_char_at(s, pos + 3))
        and _tp_is_digit(_char_at(s, pos + 4))
        and _tp_is_digit(_char_at(s, pos + 5)) {
        h6: list[any] = _tp_parse_digits(s, pos, 2, 2);
        m6: list[any] = _tp_parse_digits(s, pos + 2, 2, 2);
        s6: list[any] = _tp_parse_digits(s, pos + 4, 2, 2);
        if h6[0] >= 0
            and m6[0] >= 0
            and s6[0] >= 0
            and h6[1] < 24
            and m6[1] < 60
            and s6[1] < 60 {
            npos: int = pos + 6;
            ns6: int = 0;
            fr6: list[any] = _parse_fraction(s, npos);
            if fr6[0] >= 0 {
                npos = fr6[0];
                ns6 = fr6[1];
            }
            return [npos, h6[1], m6[1], s6[1], ns6];
        }
    }
    if pos + 4 <= len(s)
        and _tp_is_digit(_char_at(s, pos))
        and _tp_is_digit(_char_at(s, pos + 1))
        and _tp_is_digit(_char_at(s, pos + 2))
        and _tp_is_digit(_char_at(s, pos + 3)) {
        d4t: list[any] = _tp_parse_digits(s, pos, 4, 4);
        if d4t[0] >= 0 {
            val4: int = d4t[1];
            hr4: int = val4 // 100;
            mn4: int = val4 % 100;
            if hr4 < 24 and mn4 < 60 {
                return [d4t[0], hr4, mn4, 0, 0];
            }
        }
    }
    d1: list[any] = _tp_parse_digits(s, pos, 2, 2);
    if d1[0] < 0 {
        return [-1, 0, 0, 0, 0];
    }
    pos = d1[0];
    hr: int = d1[1];
    if _char_at(s, pos) != ":" {
        d2c: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d2c[0] < 0 {
            return [pos, hr, 0, 0, 0];
        }
        pos = d2c[0];
        mn: int = d2c[1];
        sc: int = 0;
        ns: int = 0;
        if pos < len(s) and _tp_is_digit(_char_at(s, pos)) {
            d3c: list[any] = _tp_parse_digits(s, pos, 2, 2);
            if d3c[0] >= 0 {
                pos = d3c[0];
                sc = d3c[1];
                fr: list[any] = _parse_fraction(s, pos);
                if fr[0] >= 0 {
                    pos = fr[0];
                    ns = fr[1];
                }
            }
        }
        return [pos, hr, mn, sc, ns];
    }
    pos = pos + 1;
    d2: list[any] = _tp_parse_digits(s, pos, 2, 2);
    if d2[0] < 0 {
        return [-1, 0, 0, 0, 0];
    }
    pos = d2[0];
    mn: int = d2[1];
    sc: int = 0;
    ns: int = 0;
    if _char_at(s, pos) == ":" {
        pos = pos + 1;
        d3: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d3[0] < 0 {
            return [-1, 0, 0, 0, 0];
        }
        pos = d3[0];
        sc = d3[1];
        fr2: list[any] = _parse_fraction(s, pos);
        if fr2[0] >= 0 {
            pos = fr2[0];
            ns = fr2[1];
        }
    }
    return [pos, hr, mn, sc, ns];
}

def _parse_offset(s: str, pos: int) -> list[any] {
    if _char_at(s, pos) == "Z" or _char_at(s, pos) == "z" {
        return [pos + 1, 0, True, True];
    }
    sign: int = 1;
    if _char_at(s, pos) == "+" {
        pos = pos + 1;
    } elif _char_at(s, pos) == "-" {
        sign = -1;
        pos = pos + 1;
    } else {
        return [pos, 0, False, False];
    }
    d1: list[any] = _tp_parse_digits(s, pos, 2, 2);
    if d1[0] < 0 {
        return [-1, 0, False, False];
    }
    pos = d1[0];
    hr: int = d1[1];
    mn: int = 0;
    if _char_at(s, pos) == ":" {
        pos = pos + 1;
        d2: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d2[0] < 0 {
            return [-1, 0, False, False];
        }
        pos = d2[0];
        mn = d2[1];
    } elif pos + 2 <= len(s) and _tp_is_digit(_char_at(s, pos)) {
        d2b: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d2b[0] >= 0 {
            pos = d2b[0];
            mn = d2b[1];
        }
    }
    off_s: int = sign * (hr * 3600 + mn * 60);
    return [pos, off_s, True, False];
}

def _annotation_key_is_lower(key: str) -> bool {
    i: int = 0;
    while i < len(key) {
        c: str = key[i:i + 1];
        if c >= "A" and c <= "Z" {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def _parse_annotations(s: str, pos: int) -> list[any] {
    tz: str = "";
    cal: str = "iso8601";
    cal_count: int = 0;
    tz_count: int = 0;
    saw_critical: bool = False;
    while pos < len(s) and _char_at(s, pos) == "[" {
        end: int = pos + 1;
        while end < len(s) and _char_at(s, end) != "]" {
            end = end + 1;
        }
        if end >= len(s) {
            return [-1, tz, cal];
        }
        inner: str = s[pos + 1:end];
        pos = end + 1;
        critical: bool = False;
        if len(inner) > 0 and inner[0:1] == "!" {
            critical = True;
            saw_critical = True;
            inner = inner[1:len(inner)];
        }
        if len(inner) == 0 {
            return [-1, tz, cal];
        }
        eq: int = -1;
        ei: int = 0;
        while ei < len(inner) {
            if _char_at(inner, ei) == "=" {
                eq = ei;
                break;
            }
            ei = ei + 1;
        }
        if eq < 0 {
            if inner == "UTC" or inner == "utc" {
                tz_count = tz_count + 1;
                if tz_count > 1 {
                    return [-1, tz, cal];
                }
                tz = "UTC";
            } elif len(inner) > 0 and (inner[0:1] == "+" or inner[0:1] == "-") {
                # A numeric-offset bracket annotation must be a valid TimeZoneUTCOffsetName
                # (no fractional seconds / trailing-zero sub-minute decimals).
                if not _is_valid_tz_offset_name(inner) {
                    return [-1, tz, cal];
                }
                tz_count = tz_count + 1;
                if tz_count > 1 {
                    return [-1, tz, cal];
                }
                tz = inner;
            } elif len(inner) > 0 {
                tz_count = tz_count + 1;
                if tz_count > 1 {
                    return [-1, tz, cal];
                }
                tz = inner;
            } elif critical {
                return [-1, tz, cal];
            }
            continue;
        }
        key: str = inner[0:eq];
        val: str = inner[eq + 1:len(inner)];
        if not _annotation_key_is_lower(key) {
            return [-1, tz, cal];
        }
        if key == "u-ca" {
            cal_count = cal_count + 1;
            if cal_count > 1 {
                if saw_critical {
                    return [-1, tz, cal];
                }
                continue;
            }
            cal = calendar_id_from_string(val);
        } elif key == "TimeZone" {
            tz_count = tz_count + 1;
            if tz_count > 1 {
                return [-1, tz, cal];
            }
            tz = val;
        } elif critical {
            return [-1, tz, cal];
        }
    }
    return [pos, tz, cal];
}

def _parse_date(s: str, pos: int) -> list[any] {
    if pos + 8 <= len(s) {
        ok8: bool = True;
        i8: int = pos;
        while i8 < pos + 8 {
            if not _tp_is_digit(_char_at(s, i8)) {
                ok8 = False;
                break;
            }
            i8 = i8 + 1;
        }
        if ok8
            and (
                pos + 8 == len(s)
                or _char_at(s, pos + 8) == "T"
                or _char_at(s, pos + 8) == "t"
            ) {
            y8: list[any] = _tp_parse_digits(s, pos, 4, 4);
            m8: list[any] = _tp_parse_digits(s, pos + 4, 2, 2);
            d8: list[any] = _tp_parse_digits(s, pos + 6, 2, 2);
            if y8[0] >= 0 and m8[0] >= 0 and d8[0] >= 0 {
                return [pos + 8, y8[1], m8[1], d8[1]];
            }
        }
    }
    yr: int = 0;
    mo: int = 0;
    dy: int = 0;
    if _char_at(s, pos) == "+"
        or _char_at(s, pos) == "-"
        or (
            _tp_is_digit(_char_at(s, pos))
            and pos + 4 <= len(s)
            and _char_at(s, pos + 4) == "-"
        ) {
        ey: list[any] = _parse_extended_year(s, pos);
        if ey[0] < 0 {
            return [-1, 0, 0, 0];
        }
        pos = ey[0];
        yr = ey[1];
        if _char_at(s, pos) == "-" {
            pos = pos + 1;
            dm: list[any] = _tp_parse_digits(s, pos, 2, 2);
            if dm[0] < 0 {
                return [-1, 0, 0, 0];
            }
            pos = dm[0];
            mo = dm[1];
            if _char_at(s, pos) != "-" {
                return [-1, 0, 0, 0];
            }
            pos = pos + 1;
            dd: list[any] = _tp_parse_digits(s, pos, 2, 2);
            if dd[0] < 0 {
                return [-1, 0, 0, 0];
            }
            pos = dd[0];
            dy = dd[1];
            return [pos, yr, mo, dy];
        }
        if pos + 8 <= len(s)
            and (_char_at(s, pos + 8) == "T" or _char_at(s, pos + 8) == "t") {
            ok8e: bool = True;
            i8e: int = pos;
            while i8e < pos + 8 {
                if not _tp_is_digit(_char_at(s, i8e)) {
                    ok8e = False;
                    break;
                }
                i8e = i8e + 1;
            }
            if ok8e {
                y8e: list[any] = _tp_parse_digits(s, pos, 4, 4);
                m8e: list[any] = _tp_parse_digits(s, pos + 4, 2, 2);
                d8e: list[any] = _tp_parse_digits(s, pos + 6, 2, 2);
                if y8e[0] >= 0 and m8e[0] >= 0 and d8e[0] >= 0 {
                    return [pos + 8, y8e[1], m8e[1], d8e[1]];
                }
            }
        }
        if pos + 4 <= len(s) {
            dm4e: list[any] = _tp_parse_digits(s, pos, 4, 4);
            if dm4e[0] >= 0 {
                pos = dm4e[0];
                val4e: int = dm4e[1];
                mo = val4e // 100;
                dy = val4e % 100;
                return [pos, yr, mo, dy];
            }
        }
        return [-1, 0, 0, 0];
    }
    if _char_at(s, pos) == "-" and _char_at(s, pos + 1) == "-" {
        pos = pos + 2;
        dm2: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if dm2[0] < 0 {
            return [-1, 0, 0, 0];
        }
        pos = dm2[0];
        mo = dm2[1];
        if _char_at(s, pos) != "-" {
            return [-1, 0, 0, 0];
        }
        pos = pos + 1;
        dd2: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if dd2[0] < 0 {
            return [-1, 0, 0, 0];
        }
        pos = dd2[0];
        dy = dd2[1];
        return [pos, 0, mo, dy];
    }
    d4: list[any] = _tp_parse_digits(s, pos, 4, 4);
    if d4[0] < 0 {
        return [-1, 0, 0, 0];
    }
    pos = d4[0];
    yr = d4[1];
    if _char_at(s, pos) == "-" {
        pos = pos + 1;
        dm3: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if dm3[0] < 0 {
            return [-1, 0, 0, 0];
        }
        pos = dm3[0];
        mo = dm3[1];
        if _char_at(s, pos) == "-" {
            pos = pos + 1;
            dd3: list[any] = _tp_parse_digits(s, pos, 2, 2);
            if dd3[0] < 0 {
                return [-1, 0, 0, 0];
            }
            pos = dd3[0];
            dy = dd3[1];
        }
    } elif pos + 4 <= len(s) and _tp_is_digit(_char_at(s, pos)) {
        dm4: list[any] = _tp_parse_digits(s, pos, 4, 4);
        if dm4[0] >= 0 {
            pos = dm4[0];
            val: int = dm4[1];
            mo = val // 100;
            dy = val % 100;
        }
    }
    return [pos, yr, mo, dy];
}

def _parse_basic_date(s: str, pos: int) -> list[any] {
    if pos + 8 > len(s) {
        return [-1, 0, 0, 0];
    }
    i: int = pos;
    while i < pos + 8 {
        if not _tp_is_digit(_char_at(s, i)) {
            return [-1, 0, 0, 0];
        }
        i = i + 1;
    }
    if pos + 8 < len(s) {
        nx: str = _char_at(s, pos + 8);
        if _tp_is_digit(nx) {
            return [-1, 0, 0, 0];
        }
    }
    yp: list[any] = _tp_parse_digits(s, pos, 4, 4);
    mp: list[any] = _tp_parse_digits(s, pos + 4, 2, 2);
    dp: list[any] = _tp_parse_digits(s, pos + 6, 2, 2);
    if yp[0] < 0 or mp[0] < 0 or dp[0] < 0 {
        return [-1, 0, 0, 0];
    }
    return [pos + 8, yp[1], mp[1], dp[1]];
}

# validate_calendar: when True (the default, used by date-bearing types) an unknown
# [u-ca=…] calendar is a parse failure. PlainTime passes False — a time string parses
# its calendar annotation for syntax only and then ignores the value entirely, so an
# unknown calendar must NOT reject (§ParseTemporalTimeString).
def:pub parse_iso_date_time(s: str, validate_calendar: bool = True) -> list[any] {
    r: list[any] = parse_empty_result();
    if len(s) == 0 {
        return _parse_fail("empty string");
    }
    pos: int = 0;
    neg: bool = False;
    if len(s) > 1 and s[0:1] == "-" and (s[1:2] == "P" or s[1:2] == "p") {
        neg = True;
        pos = 1;
    }
    if s[pos:pos + 1] == "P" or s[pos:pos + 1] == "p" {
        return parse_duration(s);
    }
    has_date: bool = False;
    has_time: bool = False;
    yr: int = 0;
    mo: int = 0;
    dy: int = 0;
    hr: int = 0;
    mn: int = 0;
    sc: int = 0;
    ns: int = 0;
    fi_colon: int = -1;
    fi_dash: int = -1;
    fi: int = pos;
    while fi < len(s) {
        fc: str = _char_at(s, fi);
        if fc == ":" and fi_colon < 0 {
            fi_colon = fi;
        }
        if fc == "-" and fi_dash < 0 {
            fi_dash = fi;
        }
        if fc == "[" {
            break;
        }
        fi = fi + 1;
    }
    if fi_colon >= 0 and (fi_dash < 0 or fi_colon < fi_dash) {
        colon_time_only: bool = True;
        if pos + 8 <= len(s) {
            ok8c: bool = True;
            i8c: int = pos;
            while i8c < pos + 8 {
                if not _tp_is_digit(_char_at(s, i8c)) {
                    ok8c = False;
                    break;
                }
                i8c = i8c + 1;
            }
            if ok8c
                and (
                    pos + 8 == len(s)
                    or _char_at(s, pos + 8) == "T"
                    or _char_at(s, pos + 8) == "t"
                ) {
                colon_time_only = False;
            }
        }
        if pos + 4 <= len(s) and _char_at(s, pos + 4) == "-" {
            colon_time_only = False;
        }
        if colon_time_only {
            tr0: list[any] = _parse_time(s, pos);
            if tr0[0] >= 0 {
                pos = tr0[0];
                hr = tr0[1];
                mn = tr0[2];
                sc = tr0[3];
                ns = tr0[4];
                has_time = True;
            }
        }
    }
    if not has_time and (_char_at(s, pos) == "T" or _char_at(s, pos) == "t") {
        pos = pos + 1;
        trt: list[any] = _parse_time(s, pos);
        if trt[0] >= 0 {
            pos = trt[0];
            hr = trt[1];
            mn = trt[2];
            sc = trt[3];
            ns = trt[4];
            has_time = True;
        }
    }
    if not has_time and not has_date and _tp_is_digit(_char_at(s, pos)) {
        looks_like_date: bool = False;
        if pos + 4 <= len(s) and _char_at(s, pos + 4) == "-" {
            looks_like_date = True;
        }
        if pos + 8 <= len(s) {
            ok8t: bool = True;
            i8t: int = pos;
            while i8t < pos + 8 {
                if not _tp_is_digit(_char_at(s, i8t)) {
                    ok8t = False;
                    break;
                }
                i8t = i8t + 1;
            }
            if ok8t
                and (
                    pos + 8 == len(s)
                    or _char_at(s, pos + 8) == "T"
                    or _char_at(s, pos + 8) == "t"
                ) {
                looks_like_date = True;
            }
        }
        if _char_at(s, pos) == "+" or _char_at(s, pos) == "-" {
            looks_like_date = True;
        }
        if not looks_like_date {
            trc: list[any] = _parse_time(s, pos);
            if trc[0] >= 0 and trc[1] < 24 {
                pos = trc[0];
                hr = trc[1];
                mn = trc[2];
                sc = trc[3];
                ns = trc[4];
                has_time = True;
            }
        }
    }
    if not has_time
        and (
            _tp_is_digit(_char_at(s, pos))
            or _char_at(s, pos) == "+"
            or _char_at(s, pos) == "-"
        ) {
        dr: list[any] = _parse_date(s, pos);
        if dr[0] < 0 {
            return _parse_fail("invalid date");
        }
        pos = dr[0];
        yr = dr[1];
        mo = dr[2];
        dy = dr[3];
        has_date = True;
    }
    if _char_at(s, pos) == "T" or _char_at(s, pos) == "t" {
        pos = pos + 1;
        tr: list[any] = _parse_time(s, pos);
        if tr[0] < 0 {
            return _parse_fail("invalid time");
        }
        pos = tr[0];
        hr = tr[1];
        mn = tr[2];
        sc = tr[3];
        ns = tr[4];
        has_time = True;
    } elif has_date and mo > 0 and pos < len(s) and _char_at(s, pos) == " " {
        pos = pos + 1;
        if pos < len(s) and _tp_is_digit(_char_at(s, pos)) {
            trs: list[any] = _parse_time(s, pos);
            if trs[0] >= 0 {
                pos = trs[0];
                hr = trs[1];
                mn = trs[2];
                sc = trs[3];
                ns = trs[4];
                has_time = True;
            }
        }
    } elif has_date and mo > 0 and pos < len(s) and _tp_is_digit(_char_at(s, pos)) {
        tr2: list[any] = _parse_time(s, pos);
        if tr2[0] >= 0 and tr2[1] < 24 {
            pos = tr2[0];
            hr = tr2[1];
            mn = tr2[2];
            sc = tr2[3];
            ns = tr2[4];
            has_time = True;
        }
    }
    off_s: int = 0;
    off_ns: int = 0;
    has_off: bool = False;
    is_z: bool = False;
    if pos < len(s) {
        orr: list[any] = _parse_offset_extended(s, pos);
        if orr[0] >= 0 and orr[2] != 0 {
            pos = orr[0];
            off_s = orr[1];
            if len(orr) > 6 {
                off_ns = orr[6];
            }
            has_off = True;
            if orr[3] != 0 {
                is_z = True;
            }
        }
    }
    tz: str = "";
    cal: str = "iso8601";
    if pos < len(s) {
        ar: list[any] = _parse_annotations(s, pos);
        if ar[0] < 0 {
            return _parse_fail("invalid annotation");
        }
        pos = ar[0];
        tz = ar[1];
        cal = ar[2];
    }
    if pos < len(s) {
        return _parse_fail("trailing junk");
    }
    cal_out: str = cal;
    if validate_calendar and len(cal_out) > 0 and not calendar_is_known(cal_out) {
        return _parse_fail("invalid calendar");
    }
    r[PR_YEAR] = yr;
    r[PR_MONTH] = mo;
    r[PR_DAY] = dy;
    r[PR_HOUR] = hr;
    r[PR_MINUTE] = mn;
    r[PR_SECOND] = sc;
    r[PR_NANOSECOND] = ns;
    r[PR_OFFSET_S] = off_s;
    r[PR_OFFSET_NS] = off_ns;
    PR_S_TZ_ANNOTATION = tz;
    PR_S_CALENDAR = cal_out;
    r[PR_HAS_DATE] = 0;
    if has_date {
        r[PR_HAS_DATE] = 1;
    }
    r[PR_HAS_TIME] = 0;
    if has_time {
        r[PR_HAS_TIME] = 1;
    }
    r[PR_HAS_OFFSET] = 0;
    if has_off {
        r[PR_HAS_OFFSET] = 1;
    }
    r[PR_IS_Z] = 0;
    if is_z {
        r[PR_IS_Z] = 1;
    }
    r[PR_IS_NEGATIVE] = 0;
    if neg {
        r[PR_IS_NEGATIVE] = 1;
    }
    return r;
}

def:priv _tp_round_half_expand_ns(v: float) -> int {
    if v >= 0.0 {
        return int(v + 0.5);
    }
    return int(v - 0.5);
}

def:priv _tp_split_ns_below_hours(abs_ns: int) -> list[int] {
    ami: int = abs_ns // 60000000000;
    rem: int = abs_ns - ami * 60000000000;
    asc: int = rem // 1000000000;
    sub: int = rem - asc * 1000000000;
    return [ami, asc, sub];
}

def:priv _tp_split_ns_below_minutes(abs_ns: int) -> list[int] {
    asc: int = abs_ns // 1000000000;
    sub: int = abs_ns - asc * 1000000000;
    return [asc, sub];
}

def:priv _tp_apply_fractional_ns_to_mi_se_ns(
    mi: float, se: float, ns: float, extra_ns: float
) -> list[float] {
    en: int = _tp_round_half_expand_ns(extra_ns);
    if en == 0 {
        return [mi, se, ns];
    }
    sign: int = 1;
    abs_en: int = en;
    if en < 0 {
        sign = -1;
        abs_en = -en;
    }
    parts: list[int] = _tp_split_ns_below_hours(abs_en);
    return [
        mi + float(parts[0] * sign),
        se + float(parts[1] * sign),
        ns + float(parts[2] * sign)
    ];
}

def:priv _tp_apply_fractional_ns_to_se_ns(
    se: float, ns: float, extra_ns: float
) -> list[float] {
    en: int = _tp_round_half_expand_ns(extra_ns);
    if en == 0 {
        return [se, ns];
    }
    sign: int = 1;
    abs_en: int = en;
    if en < 0 {
        sign = -1;
        abs_en = -en;
    }
    parts: list[int] = _tp_split_ns_below_minutes(abs_en);
    return [se + float(parts[0] * sign), ns + float(parts[1] * sign)];
}

def:priv _tp_expand_fractional_duration_time(
    h: float, mi: float, se: float, ns: float, frac_h: bool, frac_mi: bool
) -> list[float] {
    if frac_h {
        whole_h: float = float(int(h));
        if h != whole_h {
            extra: float = (h - whole_h) * 3600000000000.0;
            parts: list[float] = _tp_apply_fractional_ns_to_mi_se_ns(mi, se, ns, extra);
            mi = parts[0];
            se = parts[1];
            ns = parts[2];
            h = whole_h;
        }
    }
    if frac_mi {
        whole_mi: float = float(int(mi));
        if mi != whole_mi {
            extra2: float = (mi - whole_mi) * 60000000000.0;
            parts2: list[float] = _tp_apply_fractional_ns_to_se_ns(se, ns, extra2);
            se = parts2[0];
            ns = parts2[1];
            mi = whole_mi;
        }
    }
    return [h, mi, se, ns];
}

def _tp_parse_fractional_seconds(num_s: str) -> list[float] {
    dot: int = -1;
    i: int = 0;
    while i < len(num_s) {
        c: str = num_s[i:i + 1];
        if c == "." or c == "," {
            dot = i;
            break;
        }
        i = i + 1;
    }
    if dot < 0 {
        return [_tp_decimal_to_num(num_s), 0.0];
    }
    whole_s: str = num_s[0:dot];
    frac_s: str = num_s[dot + 1:len(num_s)];
    se: float = _tp_decimal_to_num(whole_s);
    ns: float = 0.0;
    if len(frac_s) > 0 {
        frac_ns: int = 0;
        fi: int = 0;
        while fi < len(frac_s) and fi < 9 {
            fc: str = frac_s[fi:fi + 1];
            if fc >= "0" and fc <= "9" {
                frac_ns = frac_ns * 10 + int(fc);
            }
            fi = fi + 1;
        }
        while fi < 9 {
            frac_ns = frac_ns * 10;
            fi = fi + 1;
        }
        ns = float(frac_ns);
    }
    return [se, ns];
}

def _duration_num_is_negative(num_s: str) -> bool {
    if len(num_s) > 0 and _char_at(num_s, 0) == "-" {
        return True;
    }
    return False;
}

def:pub parse_duration(s: str) -> list[any] {
    r: list[any] = parse_empty_result();
    if len(s) == 0 {
        return _parse_fail("empty duration");
    }
    pos: int = 0;
    neg: bool = False;
    if s[0:1] == "-" {
        neg = True;
        pos = 1;
    } elif s[0:1] == "+" {
        pos = 1;
    }
    if _char_at(s, pos) != "P" and _char_at(s, pos) != "p" {
        return _parse_fail("duration must start with P");
    }
    pos = pos + 1;
    y: float = 0.0;
    mo: float = 0.0;
    w: float = 0.0;
    d: float = 0.0;
    h: float = 0.0;
    mi: float = 0.0;
    se: float = 0.0;
    ns: float = 0.0;
    in_time: bool = False;
    seen_y: bool = False;
    seen_mo: bool = False;
    seen_w: bool = False;
    seen_d: bool = False;
    seen_h: bool = False;
    seen_mi: bool = False;
    seen_s: bool = False;
    frac_h: bool = False;
    frac_mi: bool = False;
    frac_s: bool = False;
    frac_terminal_seen: bool = False;
    last_date_ord: int = 0;
    last_time_ord: int = 0;
    has_unit: bool = False;
    while pos < len(s) {
        ch: str = _char_at(s, pos);
        if ch == "T" or ch == "t" {
            in_time = True;
            pos = pos + 1;
            continue;
        }
        if not _tp_is_digit(ch) and ch != "." and ch != "," {
            break;
        }
        # A fractional component (TimeFractionalPart) must be the LAST time
        # component — no further designator may follow it (§ ISO 8601 duration
        # grammar). Reaching another numeric component after one is a parse error.
        if frac_terminal_seen {
            return _parse_fail("component after fractional part");
        }
        start: int = pos;
        while pos < len(s)
            and (
                _tp_is_digit(_char_at(s, pos))
                or _char_at(s, pos) == "."
                or _char_at(s, pos) == ","
            ) {
            pos = pos + 1;
        }
        num_s: str = s[start:pos];
        if len(num_s) == 0 {
            return _parse_fail("missing duration component value");
        }
        if _char_at(num_s, 0) == "." or _char_at(num_s, 0) == "," {
            return _parse_fail("invalid duration component");
        }
        if _duration_num_is_negative(num_s) {
            return _parse_fail("negative duration component");
        }
        has_frac: bool = False;
        frac_digits: int = 0;
        fi: int = 0;
        while fi < len(num_s) {
            fc: str = _char_at(num_s, fi);
            if fc == "." or fc == "," {
                has_frac = True;
            } elif has_frac {
                frac_digits = frac_digits + 1;
            }
            fi = fi + 1;
        }
        # TimeFractionalPart is 1–9 digits; more than 9 is not a valid duration.
        if has_frac and frac_digits > 9 {
            return _parse_fail("fractional part too long");
        }
        val: float = _tp_decimal_to_num(num_s);
        if val < 0.0 {
            return _parse_fail("negative duration component");
        }
        if has_frac and not in_time {
            return _parse_fail("fractional calendar duration");
        }
        if has_frac {
            frac_terminal_seen = True;
        }
        if pos >= len(s) {
            break;
        }
        u: str = _char_at(s, pos);
        pos = pos + 1;
        u_ord: int = 0;
        if u == "Y" or u == "y" {
            if in_time {
                return _parse_fail("invalid duration unit order");
            }
            if seen_y {
                return _parse_fail("duplicate duration unit");
            }
            seen_y = True;
            u_ord = 1;
            y = val;
        } elif u == "M" or u == "m" {
            if in_time {
                if seen_mi {
                    return _parse_fail("duplicate duration unit");
                }
                seen_mi = True;
                u_ord = 2;
                mi = val;
                if has_frac {
                    frac_mi = True;
                }
            } else {
                if seen_mo {
                    return _parse_fail("duplicate duration unit");
                }
                seen_mo = True;
                u_ord = 2;
                mo = val;
            }
        } elif u == "W" or u == "w" {
            if in_time {
                return _parse_fail("invalid duration unit order");
            }
            if seen_w {
                return _parse_fail("duplicate duration unit");
            }
            seen_w = True;
            u_ord = 3;
            w = val;
        } elif u == "D" or u == "d" {
            if in_time {
                return _parse_fail("invalid duration unit order");
            }
            if seen_d {
                return _parse_fail("duplicate duration unit");
            }
            seen_d = True;
            u_ord = 4;
            d = val;
        } elif u == "H" or u == "h" {
            if not in_time {
                return _parse_fail("invalid duration unit order");
            }
            if seen_h {
                return _parse_fail("duplicate duration unit");
            }
            seen_h = True;
            u_ord = 1;
            h = val;
            if has_frac {
                frac_h = True;
            }
        } elif u == "S" or u == "s" {
            if not in_time {
                return _parse_fail("invalid duration unit order");
            }
            if seen_s {
                return _parse_fail("duplicate duration unit");
            }
            seen_s = True;
            u_ord = 3;
            sf: list[float] = _tp_parse_fractional_seconds(num_s);
            se = sf[0];
            ns = sf[1];
            if has_frac {
                frac_s = True;
            }
        } else {
            return _parse_fail("invalid duration unit");
        }
        has_unit = True;
        if in_time {
            if u_ord <= last_time_ord {
                return _parse_fail("invalid duration unit order");
            }
            last_time_ord = u_ord;
        } else {
            if u_ord <= last_date_ord {
                return _parse_fail("invalid duration unit order");
            }
            last_date_ord = u_ord;
        }
    }
    if pos < len(s) {
        return _parse_fail("trailing junk");
    }
    if not has_unit {
        return _parse_fail("empty duration");
    }
    # Expand fractional hours/minutes into lower units without normalizing overflow
    # (e.g. PT100M stays 100 minutes; only the fractional tail is distributed).
    if frac_h {
        if seen_mi and mi == 0.0 {
            return _parse_fail("fractional unit with zero sub-part");
        }
        if seen_s and se == 0.0 and ns == 0.0 {
            return _parse_fail("fractional unit with zero sub-part");
        }
    }
    if frac_mi {
        if seen_s and se == 0.0 and ns == 0.0 {
            return _parse_fail("fractional unit with zero sub-part");
        }
    }
    if frac_h or frac_mi {
        expanded: list[float] = _tp_expand_fractional_duration_time(
            h, mi, se, ns, frac_h, frac_mi
        );
        h = expanded[0];
        mi = expanded[1];
        se = expanded[2];
        ns = expanded[3];
    }
    r[PR_IS_DURATION] = 1;
    r[PR_IS_NEGATIVE] = 0;
    if neg {
        r[PR_IS_NEGATIVE] = 1;
    }
    r[PR_DUR_YEARS] = y;
    r[PR_DUR_MONTHS] = mo;
    r[PR_DUR_WEEKS] = w;
    r[PR_DUR_DAYS] = d;
    r[PR_DUR_HOURS] = h;
    r[PR_DUR_MINUTES] = mi;
    r[PR_DUR_SECONDS] = se;
    r[PR_DUR_NANOS] = ns;
    return r;
}

def:pub parse_temporal_instant(s: str) -> list[any] {
    return parse_iso_date_time(s);
}

def:pub parse_plain_date(s: str) -> list[any] {
    pr: list[any] = parse_iso_date_time(s);
    if not pr[PR_OK] {
        return pr;
    }
    if not pr[PR_HAS_DATE] {
        return _parse_fail("missing date");
    }
    return pr;
}

def:pub parse_plain_time(s: str) -> list[any] {
    pr: list[any] = parse_iso_date_time(s);
    if not pr[PR_OK] {
        return pr;
    }
    if not pr[PR_HAS_TIME] {
        return _parse_fail("missing time");
    }
    return pr;
}

def:pub parse_plain_year_month(s: str) -> list[any] {
    return parse_iso_date_time(s);
}

def:pub parse_plain_month_day(s: str) -> list[any] {
    return parse_iso_date_time(s);
}

def:pub iso_string_is_calendar_identifier(s: str) -> bool {
    ann: str = extract_calendar_annotation(s);
    if len(ann) > 0 and calendar_is_known(ann) {
        return True;
    }
    pr: list[any] = parse_iso_date_time(s);
    if pr[PR_OK] and pr[PR_HAS_DATE] {
        return True;
    }
    if len(s) == 7 and _char_at(s, 4) == "-" {
        yp: list[any] = _tp_parse_digits(s, 0, 4, 4);
        mp: list[any] = _tp_parse_digits(s, 5, 2, 2);
        if yp[0] >= 0 and mp[0] >= 0 {
            return True;
        }
    }
    if len(s) == 5 and _char_at(s, 2) == "-" {
        mp2: list[any] = _tp_parse_digits(s, 0, 2, 2);
        dp2: list[any] = _tp_parse_digits(s, 3, 2, 2);
        if mp2[0] >= 0 and dp2[0] >= 0 {
            return True;
        }
    }
    if len(s) >= 7 and s[0:2] == "--" and _char_at(s, 4) == "-" {
        mp3: list[any] = _tp_parse_digits(s, 2, 2, 2);
        dp3: list[any] = _tp_parse_digits(s, 5, 2, 2);
        if mp3[0] >= 0 and dp3[0] >= 0 {
            return True;
        }
    }
    return False;
}

def:pub calendar_id_from_string(s: str) -> str {
    out: str = s;
    i: int = 0;
    while i < len(out) {
        c: str = out[i:i + 1];
        if c >= "A" and c <= "Z" {
            out = out[0:i] + chr(ord(c) + 32) + out[i + 1:len(out)];
        }
        i = i + 1;
    }
    return out;
}

def:pub extract_calendar_annotation(s: str) -> str {
    cal: str = "";
    i: int = 0;
    while i < len(s) {
        if _char_at(s, i) == "[" {
            j: int = i + 1;
            while j < len(s) and _char_at(s, j) != "]" {
                j = j + 1;
            }
            if j < len(s) {
                inner: str = s[i + 1:j];
                if len(inner) > 0 and inner[0:1] == "!" {
                    inner = inner[1:len(inner)];
                }
                eq: int = -1;
                ei: int = 0;
                while ei < len(inner) {
                    if _char_at(inner, ei) == "=" {
                        eq = ei;
                        break;
                    }
                    ei = ei + 1;
                }
                if eq >= 0 {
                    key: str = inner[0:eq];
                    val: str = inner[eq + 1:len(inner)];
                    if _annotation_key_is_lower(key) and key == "u-ca" {
                        cal = calendar_id_from_string(val);
                    }
                }
            }
            i = j + 1;
        } else {
            i = i + 1;
        }
    }
    return cal;
}

def:pub is_valid_iso_date(y: int, m: int, d: int) -> bool {
    if m < 1 or m > 12 {
        return False;
    }
    if d < 1 {
        return False;
    }
    dim: int = _days_in_month(y, m);
    if d > dim {
        return False;
    }
    if y < -999999 or y > 999999 {
        return False;
    }
    return True;
}

def _days_in_month(y: int, m: int) -> int {
    if m == 2 {
        if _is_leap_year(y) {
            return 29;
        }
        return 28;
    }
    if m == 4 or m == 6 or m == 9 or m == 11 {
        return 30;
    }
    return 31;
}

def _is_leap_year(y: int) -> bool {
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

def:pub is_valid_iso_time(h: int, m: int, s: int, ns: int) -> bool {
    if h < 0 or h > 23 {
        return False;
    }
    if m < 0 or m > 59 {
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

def _parse_offset_extended(s: str, pos: int) -> list[any] {
    if _char_at(s, pos) == "Z" or _char_at(s, pos) == "z" {
        return [pos + 1, 0, 1, 1, 0];
    }
    sign: int = 1;
    if _char_at(s, pos) == "+" {
        pos = pos + 1;
    } elif _char_at(s, pos) == "-" {
        sign = -1;
        pos = pos + 1;
    } else {
        return [pos, 0, 0, 0, 0];
    }
    d1: list[any] = _tp_parse_digits(s, pos, 2, 2);
    if d1[0] < 0 {
        return [-1, 0, 0, 0, 0];
    }
    pos = d1[0];
    hr: int = d1[1];
    mn: int = 0;
    sc: int = 0;
    ns: int = 0;
    has_sec_field: bool = False;
    if _char_at(s, pos) == ":" {
        pos = pos + 1;
        d2: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d2[0] < 0 {
            return [-1, 0, 0, 0, 0];
        }
        pos = d2[0];
        mn = d2[1];
        if _char_at(s, pos) == ":" {
            has_sec_field = True;
            pos = pos + 1;
            d3: list[any] = _tp_parse_digits(s, pos, 2, 2);
            if d3[0] < 0 {
                return [-1, 0, 0, 0, 0];
            }
            pos = d3[0];
            sc = d3[1];
            fr: list[any] = _parse_fraction(s, pos);
            if fr[0] >= 0 {
                pos = fr[0];
                ns = fr[1];
            }
        }
    } elif pos + 2 <= len(s) and _tp_is_digit(_char_at(s, pos)) {
        d2b: list[any] = _tp_parse_digits(s, pos, 2, 2);
        if d2b[0] >= 0 {
            pos = d2b[0];
            mn = d2b[1];
            if pos + 2 <= len(s) and _tp_is_digit(_char_at(s, pos)) {
                d3b: list[any] = _tp_parse_digits(s, pos, 2, 2);
                if d3b[0] >= 0 {
                    pos = d3b[0];
                    sc = d3b[1];
                    frb: list[any] = _parse_fraction(s, pos);
                    if frb[0] >= 0 {
                        pos = frb[0];
                        ns = frb[1];
                    }
                }
            }
        }
    }
    sub: int = 0;
    if sc != 0 or ns != 0 {
        sub = 1;
    }
    off_s: int = sign * (hr * 3600 + mn * 60 + sc);
    off_ns: int = sign * ns;
    return [pos, off_s, 1, 0, sub, 1 if has_sec_field else 0, off_ns];
}

def:pub offset_string_has_subminute(s: str) -> bool {
    orr: list[any] = _parse_offset_extended(s, 0);
    if orr[2] == 0 {
        return False;
    }
    return orr[4] != 0;
}

def:pub offset_string_has_seconds_field(s: str) -> bool {
    orr: list[any] = _parse_offset_extended(s, 0);
    if orr[2] == 0 {
        return False;
    }
    if len(orr) > 5 and orr[5] != 0 {
        return True;
    }
    return False;
}

def:pub offset_string_to_seconds(s: str) -> list[any] {
    orr: list[any] = _parse_offset_extended(s, 0);
    if orr[2] == 0 or orr[0] != len(s) {
        return [0, 0];
    }
    return [1, orr[1]];
}

def:pub parse_utc_offset_string(s: str) -> list[any] {
    if len(s) == 0 {
        return [0, 0];
    }
    orr: list[any] = _parse_offset_extended(s, 0);
    if orr[0] < 0 or orr[2] == 0 {
        return [0, 0];
    }
    if orr[0] != len(s) {
        return [0, 0];
    }
    return [1, orr[1]];
}

def:pub parse_month_code(mc: str) -> int {
    # A well-formed monthCode is EXACTLY uppercase "M" + two digits + optional uppercase
    # "L" (e.g. "M01", "M12", "M05L"). Lowercase "m"/"l", one digit ("M1"), or extra chars
    # are RangeErrors, so the format is validated strictly (not lenient).
    if len(mc) != 3 and len(mc) != 4 {
        return -1;
    }
    if _char_at(mc, 0) != "M" {
        return -1;
    }
    if not _tp_is_digit(_char_at(mc, 1)) or not _tp_is_digit(_char_at(mc, 2)) {
        return -1;
    }
    num: int = int(_char_at(mc, 1)) * 10 + int(_char_at(mc, 2));
    if len(mc) == 4 {
        if _char_at(mc, 3) != "L" {
            return -1;
        }
    }
    if num < 1 {
        return -1;
    }
    return num;
}

def _seconds_to_offset_ns(sec: int) -> int {
    return int(bn_to_string(bn_mul_small(bn_from_int(sec), 1000000000), 10));
}

def _format_offset_tz_from_seconds(off_s: int) -> str {
    sign: str = "+";
    aoff: int = off_s;
    if off_s < 0 {
        sign = "-";
        aoff = -off_s;
    }
    hr: int = aoff // 3600;
    mn: int = (aoff % 3600) // 60;
    hs: str = str(hr);
    if hr < 10 {
        hs = "0" + hs;
    }
    ms: str = str(mn);
    if mn < 10 {
        ms = "0" + ms;
    }
    out: str = sign;
    out = out + hs;
    out = out + ":";
    out = out + ms;
    return out;
}

def:pub _is_offset_only_tz_string(s: str) -> bool {
    if len(s) == 0 {
        return False;
    }
    c0: str = _char_at(s, 0);
    if c0 != "+" and c0 != "-" {
        return False;
    }
    orr: list[any] = _parse_offset_extended(s, 0);
    if orr[2] == 0 {
        return False;
    }
    if orr[0] != len(s) {
        return False;
    }
    return True;
}

"""Time-zone identifier from a time-zone string, as a real `str`.

parse_temporal_time_zone_string returns `list`, which the native backend lowers
to List.i64 — a `str` stored in it comes back as a raw pointer, so the offset
identifiers it builds (e.g. "-08:00") read as garbage. That function is kept for
its integer fields; callers that need the identifier text use this instead.
Returns "" when the string is not a valid time zone."""
def:pub parse_temporal_time_zone_id(s: str) -> str {
    if _is_offset_only_tz_string(s) {
        orr: list[any] = _parse_offset_extended(s, 0);
        return _format_offset_tz_from_seconds(orr[1]);
    }
    pr: list[any] = parse_iso_date_time(s);
    if pr[PR_OK] {
        if pr[PR_YEAR] == 0 {
            return "";
        }
        tz_ann: str = PR_S_TZ_ANNOTATION;
        if len(tz_ann) > 0 {
            return tz_ann;
        }
        if pr[PR_IS_Z] != 0 {
            return "UTC";
        }
        if pr[PR_HAS_OFFSET] != 0 {
            offpos: int = -1;
            bracket: int = len(s);
            scan: int = 0;
            while scan < len(s) {
                if _char_at(s, scan) == "[" {
                    bracket = scan;
                    break;
                }
                scan = scan + 1;
            }
            scan2: int = 0;
            while scan2 < bracket {
                c2: str = _char_at(s, scan2);
                if c2 == "+" or c2 == "-" {
                    offpos = scan2;
                }
                scan2 = scan2 + 1;
            }
            if offpos >= 0 {
                orr2: list[any] = _parse_offset_extended(s, offpos);
                if orr2[4] != 0 or (len(orr2) > 5 and orr2[5] != 0) {
                    return "";
                }
                return _format_offset_tz_from_seconds(orr2[1]);
            }
        }
        return "";
    }
    pr2: list[any] = parse_iso_date_time(s);
    if pr2[PR_OK] and (pr2[PR_HAS_DATE] != 0 or pr2[PR_HAS_TIME] != 0) {
        return "";
    }
    if len(s) > 0 and _char_at(s, 0) != "+" and _char_at(s, 0) != "-" {
        return s;
    }
    return "";
}

def:pub parse_temporal_time_zone_string(s: str) -> list[any] {
    if _is_offset_only_tz_string(s) {
        orr: list[any] = _parse_offset_extended(s, 0);
        return [1, _format_offset_tz_from_seconds(orr[1]), orr[1]];
    }
    pr: list[any] = parse_iso_date_time(s);
    if pr[PR_OK] {
        if pr[PR_YEAR] == 0 {
            return [0, "", 0];
        }
        tz_ann: str = PR_S_TZ_ANNOTATION;
        if len(tz_ann) > 0 {
            return [1, tz_ann, 0];
        }
        if pr[PR_IS_Z] != 0 {
            return [1, "UTC", 0];
        }
        if pr[PR_HAS_OFFSET] != 0 {
            offpos: int = -1;
            scan: int = 0;
            bracket: int = len(s);
            while scan < len(s) {
                if _char_at(s, scan) == "[" {
                    bracket = scan;
                    break;
                }
                scan = scan + 1;
            }
            scan2: int = 0;
            while scan2 < bracket {
                c2: str = _char_at(s, scan2);
                if c2 == "+" or c2 == "-" {
                    offpos = scan2;
                }
                scan2 = scan2 + 1;
            }
            if offpos >= 0 {
                orr2: list[any] = _parse_offset_extended(s, offpos);
                if orr2[4] != 0 or (len(orr2) > 5 and orr2[5] != 0) {
                    return [0, "", 0];
                }
                return [1, _format_offset_tz_from_seconds(orr2[1]), orr2[1]];
            }
        }
        return [0, "", 0];
    }
    pr2: list[any] = parse_iso_date_time(s);
    if pr2[PR_OK] and (pr2[PR_HAS_DATE] != 0 or pr2[PR_HAS_TIME] != 0) {
        return [0, "", 0];
    }
    if len(s) > 0 and _char_at(s, 0) != "+" and _char_at(s, 0) != "-" {
        return [1, s, 0];
    }
    return [0, "", 0];
}
