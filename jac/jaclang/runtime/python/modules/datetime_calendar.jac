"""Calendar arithmetic and ISO 8601 text parsing of the _datetime module.

Modules/_datetimemodule.c's math utilities, calendrical helpers,
normalization utilities and string parsing helpers in native Jac. Nothing
here touches a Python object: the parsers read the NUL-terminated UTF-8
text PyUnicode_AsUTF8AndSize() returns, one byte past the end included, as
the C code does. See ../LICENSE.cpython.
"""

glob MINYEAR: Final[int] = 1,
     MAXYEAR: Final[int] = 9999,
     # date(9999,12,31).toordinal()
     MAXORDINAL: Final[int] = 3652059,
     # Nine decimal digits is easy to communicate, and leaves enough room so
     # that two delta days can be added w/o fear of overflowing a signed
     # 32-bit int, and with plenty of room left over to absorb any possible
     # carries from adding seconds.
     MAX_DELTA_DAYS: Final[int] = 999999999,
     # Number of days in 4, 100, and 400 year cycles.
     DI4Y: Final[int] = 1461,
     DI100Y: Final[int] = 36524,
     DI400Y: Final[int] = 146097;

# For each month ordinal in 1..12, the number of days in that month, and the
# number of days before that month in the same year. These are correct for
# non-leap years only; index 0 is unused.
glob:priv DAYS_IN_MONTH: list[int] = [
         0,
         31,
         28,
         31,
         30,
         31,
         30,
         31,
         31,
         30,
         31,
         30,
         31
     ],
     DAYS_BEFORE_MONTH: list[int] = [
         0,
         0,
         31,
         59,
         90,
         120,
         151,
         181,
         212,
         243,
         273,
         304,
         334
     ],
     # Fractional-second scaling for 1 to 5 parsed digits.
     CORRECTION: list[int] = [100000, 10000, 1000, 100, 10];

"""A year, month and day computed together."""
obj YearMonthDay {
    has year: int = 0,
        month: int = 0,
        day: int = 0;
}

"""The fields parse_isoformat_time() fills: the time, and the UTC offset in
seconds and microseconds when the text has one."""
obj IsoTime {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzoffset: int = 0,
        tzmicrosecond: int = 0;
}

"""A day, second and microsecond count normalized together."""
obj DaySecondMicro {
    has days: int = 0,
        seconds: int = 0,
        microseconds: int = 0;
}

"""The seven fields of a datetime normalized together."""
obj DateTimeFields {
    has year: int = 0,
        month: int = 0,
        day: int = 0,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0;
}

# year -> True if leap year. The year is read as C's unsigned int, as the C
# code casts it, so a negative year keeps C's answer.
def is_leap(year: int) -> bool {
    ayear = year & 0xFFFFFFFF;
    return ayear % 4 == 0 and (ayear % 100 != 0 or ayear % 400 == 0);
}

# year, month -> number of days in that month in that year.
def days_in_month(year: int, month: int) -> int {
    if month == 2 and is_leap(year) {
        return 29;
    }
    return DAYS_IN_MONTH[month];
}

# year, month -> number of days in year preceding first day of month.
def days_before_month(year: int, month: int) -> int {
    days = DAYS_BEFORE_MONTH[month];
    if month > 2 and is_leap(year) {
        days += 1;
    }
    return days;
}

# year -> number of days before January 1st of year. Remember that we start
# with year 1, so days_before_year(1) == 0.
def days_before_year(year: int) -> int {
    y = year - 1;
    return y * 365 + y // 4 - y // 100 + y // 400;
}

# ordinal -> year, month, day, considering 01-Jan-0001 as day 1.
def ord_to_ymd(ordinal: int) -> YearMonthDay {
    result = YearMonthDay();
    # ordinal is a 1-based index, starting at 1-Jan-1. The pattern of leap
    # years repeats exactly every 400 years; subtracting 1 first makes the
    # values at 400-year boundaries exactly those divisible by DI400Y.
    ordinal -= 1;
    n400 = ordinal // DI400Y;
    n = ordinal % DI400Y;
    result.year = n400 * 400 + 1;
    # n100 can equal 4: then the desired day is December 31 at the end of a
    # 400-year cycle.
    n100 = n // DI100Y;
    n = n % DI100Y;
    n4 = n // DI4Y;
    n = n % DI4Y;
    # n1 can be 4 too: December 31 at the end of the 4-year cycle.
    n1 = n // 365;
    n = n % 365;
    result.year += n100 * 100 + n4 * 4 + n1;
    if n1 == 4 or n100 == 4 {
        result.year -= 1;
        result.month = 12;
        result.day = 31;
        return result;
    }
    # The year is correct and n is the offset from January 1. Estimate the
    # month; the estimate is either exact or one too large.
    leapyear = n1 == 3 and (n4 != 24 or n100 == 3);
    result.month = (n + 50) >> 5;
    preceding = DAYS_BEFORE_MONTH[result.month]
        + (1 if result.month > 2 and leapyear else 0);
    if preceding > n {
        result.month -= 1;
        preceding -= days_in_month(result.year, result.month);
    }
    n -= preceding;
    result.day = n + 1;
    return result;
}

# year, month, day -> ordinal, considering 01-Jan-0001 as day 1.
def ymd_to_ord(year: int, month: int, day: int) -> int {
    return days_before_year(year) + days_before_month(year, month) + day;
}

# Day of week, where Monday==0, ..., Sunday==6. 1/1/1 was a Monday.
def weekday(year: int, month: int, day: int) -> int {
    return (ymd_to_ord(year, month, day) + 6) % 7;
}

# Ordinal of the Monday starting week 1 of the ISO year. Week 1 is the first
# calendar week containing a Thursday.
def iso_week1_monday(year: int) -> int {
    first_day = ymd_to_ord(year, 1, 1);
    # 0 if 1/1 is a Monday, 1 if a Tue, etc.
    first_weekday = (first_day + 6) % 7;
    # ordinal of closest Monday at or before 1/1
    week1_monday = first_day - first_weekday;
    if first_weekday > 3 {
        week1_monday += 7;
    }
    return week1_monday;
}

# ISO year, week, day -> year, month, day in `out`. 0 on success; -4 for a
# year out of range, -2 for a bad week and -3 for a bad weekday.
def iso_to_ymd(iso_year: int, iso_week: int, iso_day: int, out: YearMonthDay) -> int {
    # Year is bounded to 0 < year < 10000 because 9999-12-31 is (9999, 52, 5)
    if iso_year < MINYEAR or iso_year > MAXYEAR {
        return -4;
    }
    if iso_week <= 0 or iso_week >= 53 {
        out_of_range = True;
        if iso_week == 53 {
            # ISO years have 53 weeks in it on years starting with a Thursday
            # and on leap years starting on Wednesday
            first_weekday = weekday(iso_year, 1, 1);
            if first_weekday == 3 or (first_weekday == 2 and is_leap(iso_year)) {
                out_of_range = False;
            }
        }
        if out_of_range {
            return -2;
        }
    }
    if iso_day <= 0 or iso_day >= 8 {
        return -3;
    }
    day_1 = iso_week1_monday(iso_year);
    day_offset = (iso_week - 1) * 7 + iso_day - 1;
    found = ord_to_ymd(day_1 + day_offset);
    out.year = found.year;
    out.month = found.month;
    out.day = found.day;
    return 0;
}

# ---------------------------------------------------------------------------
# Normalization utilities.

# One step of a mixed-radix conversion: a "hi" unit is `factor` "lo" units.
# Returns (hi, lo) with 0 <= lo < factor.
def normalize_pair(hi: int, lo: int, factor: int) -> tuple[int, int] {
    if lo < 0 or lo >= factor {
        return (hi + lo // factor, lo % factor);
    }
    return (hi, lo);
}

# Fiddle days, seconds and microseconds so that 0 <= seconds < 24*3600 and
# 0 <= microseconds < 1000000.
def normalize_d_s_us(days: int, seconds: int, microseconds: int) -> DaySecondMicro {
    if microseconds < 0 or microseconds >= 1000000 {
        (seconds, microseconds) = normalize_pair(seconds, microseconds, 1000000);
    }
    if seconds < 0 or seconds >= 24 * 3600 {
        (days, seconds) = normalize_pair(days, seconds, 24 * 3600);
    }
    return DaySecondMicro(days=days, seconds=seconds, microseconds=microseconds);
}

# Fiddle years, months and days in `fields` so that 1 <= month <= 12 and
# 1 <= day <= days_in_month(year, month). The month is always a month of a
# date already, so only the day can be out of bounds. False when the adjusted
# date is out of range ("date value out of range").
def normalize_y_m_d(fields: DateTimeFields) -> bool {
    dim = days_in_month(fields.year, fields.month);
    if fields.day < 1 or fields.day > dim {
        # Move day-1 days from the first of the month. First try to get off
        # cheap if we're only one day out of range (adjustments for timezone
        # alone can't be worse than that).
        if fields.day == 0 {
            fields.month -= 1;
            if fields.month > 0 {
                fields.day = days_in_month(fields.year, fields.month);
            } else {
                fields.year -= 1;
                fields.month = 12;
                fields.day = 31;
            }
        } elif fields.day == dim + 1 {
            # move forward a day
            fields.month += 1;
            fields.day = 1;
            if fields.month > 12 {
                fields.month = 1;
                fields.year += 1;
            }
        } else {
            ordinal = ymd_to_ord(fields.year, fields.month, 1) + fields.day - 1;
            if ordinal < 1 or ordinal > MAXORDINAL {
                return False;
            }
            found = ord_to_ymd(ordinal);
            fields.year = found.year;
            fields.month = found.month;
            fields.day = found.day;
            return True;
        }
    }
    return MINYEAR <= fields.year and fields.year <= MAXYEAR;
}

# Force all the datetime fields into range; False when the date is out of
# range.
def normalize_datetime(fields: DateTimeFields) -> bool {
    (second, microsecond) = normalize_pair(fields.second, fields.microsecond, 1000000);
    (minute, second) = normalize_pair(fields.minute, second, 60);
    (hour, minute) = normalize_pair(fields.hour, minute, 60);
    (day, hour) = normalize_pair(fields.day, hour, 24);
    fields.day = day;
    fields.hour = hour;
    fields.minute = minute;
    fields.second = second;
    fields.microsecond = microsecond;
    return normalize_y_m_d(fields);
}

# ---------------------------------------------------------------------------
# String parsing utilities.

# The byte at `text + index`.
def byte_at(text: ptr[u8], index: int) -> int {
    return int((text + index).view(1)[0]);
}

def is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}

# Accumulate `count` decimal digits at `text + position` onto `value`:
# (position after them, value), or position -1 at a non-digit.
def parse_digits(
    text: ptr[u8], position: int, value: int, count: int
) -> tuple[int, int] {
    for _ in range(count) {
        digit = byte_at(text, position) - 48;
        position += 1;
        if digit < 0 or digit > 9 {
            return (-1, value);
        }
        value = value * 10 + digit;
    }
    return (position, value);
}

# Parse the date components of the result of date.isoformat(): 0 on success,
# -1 for a malformed date component, -2 for inconsistent separators, -3 for a
# malformed ISO week, -4 for a malformed ISO day, and -5, -6, -7 when
# iso_to_ymd() rejects the ISO date.
def parse_isoformat_date(text: ptr[u8], length: int, out: YearMonthDay) -> int {
    (p, year) = parse_digits(text, 0, out.year, 4);
    if p < 0 {
        return -1;
    }
    out.year = year;
    uses_separator = byte_at(text, p) == 45;
    if uses_separator {
        p += 1;
    }
    if byte_at(text, p) == 87 {
        # This is an isocalendar-style date string
        p += 1;
        (p, iso_week) = parse_digits(text, p, 0, 2);
        if p < 0 {
            return -3;
        }
        iso_day = 0;
        if p < length {
            if uses_separator {
                separator = byte_at(text, p);
                p += 1;
                if separator != 45 {
                    return -2;
                }
            }
            (p, iso_day) = parse_digits(text, p, 0, 1);
            if p < 0 {
                return -4;
            }
        } else {
            iso_day = 1;
        }
        rv = iso_to_ymd(out.year, iso_week, iso_day, out);
        return -3 + rv if rv != 0 else 0;
    }
    (p, month) = parse_digits(text, p, out.month, 2);
    if p < 0 {
        return -1;
    }
    out.month = month;
    if uses_separator {
        separator = byte_at(text, p);
        p += 1;
        if separator != 45 {
            return -2;
        }
    }
    (p, day) = parse_digits(text, p, out.day, 2);
    if p < 0 {
        return -1;
    }
    out.day = day;
    return 0;
}

# Parse [HH[:?MM[:?SS]]][.fraction] between `start` and `end` into `out`
# (hour, minute, second, microsecond): 0 when the text ends there, 1 when
# more follows, -3 for a malformed component and -4 for a malformed
# separator.
def parse_hh_mm_ss_ff(text: ptr[u8], start: int, end: int, out: IsoTime) -> int {
    out.hour = 0;
    out.minute = 0;
    out.second = 0;
    out.microsecond = 0;
    p = start;
    has_separator = True;
    for i in range(3) {
        (p, value) = parse_digits(text, p, 0, 2);
        if p < 0 {
            return -3;
        }
        if i == 0 {
            out.hour = value;
        } elif i == 1 {
            out.minute = value;
        } else {
            out.second = value;
        }
        c = byte_at(text, p);
        p += 1;
        if i == 0 {
            has_separator = c == 58;
        }
        if p >= end {
            return 1 if c != 0 else 0;
        } elif has_separator and c == 58 {
            if i == 2 {
                # Malformed microsecond separator
                return -4;
            }
            continue;
        } elif c == 46 or c == 44 {
            if i < 2 {
                # Decimal mark on hour or minute
                return -3;
            }
            break;
        } elif not has_separator {
            p -= 1;
        } else {
            # Malformed time separator
            return -4;
        }
    }
    # Parse fractional components
    to_parse = min(end - p, 6);
    (p, microsecond) = parse_digits(text, p, 0, to_parse);
    if p < 0 {
        return -3;
    }
    if to_parse < 6 {
        microsecond *= CORRECTION[to_parse - 1];
    }
    out.microsecond = microsecond;
    while is_digit(byte_at(text, p)) {
        # skip truncated digits
        p += 1;
    }
    # 1 if it's not the end of the string
    return 1 if byte_at(text, p) != 0 else 0;
}

# Parse the time portion of a datetime.isoformat() string of `length` bytes
# at `text`: 0 on success without a UTC offset, 1 with one (in
# tzoffset/tzmicrosecond), -3 for a malformed time component, -4 for a
# malformed time separator and -5 for a malformed time zone.
def parse_isoformat_time(text: ptr[u8], length: int, out: IsoTime) -> int {
    tzinfo_pos = 0;
    while True {
        c = byte_at(text, tzinfo_pos);
        if c == 90 or c == 43 or c == 45 {
            break;
        }
        tzinfo_pos += 1;
        if tzinfo_pos >= length {
            break;
        }
    }
    rv = parse_hh_mm_ss_ff(text, 0, tzinfo_pos, out);
    if rv < 0 {
        return rv;
    } elif tzinfo_pos == length {
        # There's no time zone, so stuff at the end of the string is an error.
        return -5 if rv == 1 else 0;
    }
    # Special case UTC / Zulu time.
    if byte_at(text, tzinfo_pos) == 90 {
        out.tzoffset = 0;
        out.tzmicrosecond = 0;
        return -5 if byte_at(text, tzinfo_pos + 1) != 0 else 1;
    }
    tzsign = -1 if byte_at(text, tzinfo_pos) == 45 else 1;
    zone = IsoTime();
    rv = parse_hh_mm_ss_ff(text, tzinfo_pos + 1, length, zone);
    out.tzoffset = tzsign * (zone.hour * 3600 + zone.minute * 60 + zone.second);
    out.tzmicrosecond = zone.microsecond * tzsign;
    return -5 if rv != 0 else 1;
}

# Where the date part of a datetime.fromisoformat() string of `length` bytes
# ends, or -1 when no ISO date form fits. The valid date formats can all be
# distinguished by characters 4 and 5 and further narrowed down by character
# 8 or the run of digits after an ISO week:
#   %Y-%m-%d YYYY-MM-DD 10, %Y%m%d YYYYMMDD 8, %Y-W%V YYYY-Www 8,
#   %YW%V YYYYWww 7, %Y-W%V-%u YYYY-Www-d 10, %YW%V%u YYYYWwwd 8.
def find_isoformat_datetime_separator(text: ptr[u8], length: int) -> int {
    if length == 7 {
        return 7;
    }
    if byte_at(text, 4) == 45 {
        # YYYY-???
        if byte_at(text, 5) == 87 {
            # YYYY-W??
            if length < 8 {
                return -1;
            }
            if length > 8 and byte_at(text, 8) == 45 {
                # YYYY-Www-D (10) or YYYY-Www-HH (8)
                if length == 9 {
                    return -1;
                }
                if length > 10 and is_digit(byte_at(text, 10)) {
                    # YYYY-Www-##: the separator is either a hyphen at 8 or
                    # a number at 10; assume the far likelier hyphen.
                    return 8;
                }
                return 10;
            }
            # YYYY-Www (8)
            return 8;
        }
        # YYYY-MM-DD (10)
        return 10;
    }
    # YYYY???
    if byte_at(text, 4) == 87 {
        # YYYYWww (7) or YYYYWwwd (8): an odd number of digits before the
        # first non-digit means the week has no day.
        index = 7;
        while index < length {
            if not is_digit(byte_at(text, index)) {
                break;
            }
            index += 1;
        }
        if index < 9 {
            return index;
        }
        return 7 if index % 2 == 0 else 8;
    }
    # YYYYMMDD (8)
    return 8;
}
