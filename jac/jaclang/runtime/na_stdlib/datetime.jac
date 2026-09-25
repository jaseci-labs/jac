import from _datetime_native {
    dt_epoch_us,
    dt_localtime,
    dt_gmtime,
    dt_tm,
    dt_tm_gmtoff,
    dt_tm_zone,
    dt_strftime,
    dt_out_buf,
    dt_fmt_buf,
    dt_out_str
}
import from _ascii { is_digit, is_space }

glob:pub MINYEAR: int = 1,
     MAXYEAR: int = 9999;

glob:pub _MAXORDINAL: int = 3652059,
     _EPOCHORDINAL: int = 719163;

glob _DAYS_IN_MONTH: list[int] = [
         -1,
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
     _DAYS_BEFORE_MONTH: list[int] = [
         -1,
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
     _MONTHNAMES: list[str] = [
         "",
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     _DAYNAMES: list[str] = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     _MONTHNAMES_FULL: list[str] = [
         "",
         "January",
         "February",
         "March",
         "April",
         "May",
         "June",
         "July",
         "August",
         "September",
         "October",
         "November",
         "December"
     ],
     _DAYNAMES_FULL: list[str] = [
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday",
         "Sunday"
     ],
     _FRACTION_CORRECTION: list[int] = [100000, 10000, 1000, 100, 10];


def _iabs(x: int) -> int {
    return -x if x < 0 else x;
}


def _is_leap(year: int) -> bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}


def _days_before_year(year: int) -> int {
    y: int = year - 1;
    return y * 365 + y // 4 - y // 100 + y // 400;
}


def _days_in_month(year: int, month: int) -> int {
    if month == 2 and _is_leap(year) {
        return 29;
    }
    return _DAYS_IN_MONTH[month];
}


def _days_before_month(year: int, month: int) -> int {
    extra: int = 0;
    if month > 2 and _is_leap(year) {
        extra = 1;
    }
    return _DAYS_BEFORE_MONTH[month] + extra;
}


def _ymd2ord(year: int, month: int, day: int) -> int {
    return _days_before_year(year) + _days_before_month(year, month) + day;
}


def:pub _ord2ymd(n_in: int) -> tuple[(int, int, int)] {
    n: int = n_in - 1;
    n400: int = n // 146097;
    n = n - n400 * 146097;
    year: int = n400 * 400 + 1;
    n100: int = n // 36524;
    n = n - n100 * 36524;
    n4: int = n // 1461;
    n = n - n4 * 1461;
    n1: int = n // 365;
    n = n - n1 * 365;
    year += n100 * 100 + n4 * 4 + n1;
    if n1 == 4 or n100 == 4 {
        return (year - 1, 12, 31);
    }
    leapyear: bool = n1 == 3 and (n4 != 24 or n100 == 3);
    month: int = (n + 50) // 32;
    preceding: int = _DAYS_BEFORE_MONTH[month] + (1 if month > 2 and leapyear else 0);
    if preceding > n {
        month -= 1;
        preceding -= _DAYS_IN_MONTH[month] + (1 if month == 2 and leapyear else 0);
    }
    n -= preceding;
    return (year, month, n + 1);
}


def _isoweek1monday(year: int) -> int {
    firstday: int = _ymd2ord(year, 1, 1);
    firstweekday: int = (firstday + 6) % 7;
    week1monday: int = firstday - firstweekday;
    if firstweekday > 3 {
        week1monday += 7;
    }
    return week1monday;
}


def _isoweek_to_gregorian(year: int, week: int, day: int) -> tuple[(int, int, int)] {
    if not (year >= MINYEAR and year <= MAXYEAR) {
        raise ValueError(f"year must be in {MINYEAR}..{MAXYEAR}, not {year}");
    }
    if not (week > 0 and week < 53) {
        out_of_range: bool = True;
        if week == 53 {
            first_weekday: int = _ymd2ord(year, 1, 1) % 7;
            if first_weekday == 4 or (first_weekday == 3 and _is_leap(year)) {
                out_of_range = False;
            }
        }
        if out_of_range {
            raise ValueError(f"Invalid week: {week}");
        }
    }
    if not (day > 0 and day < 8) {
        raise ValueError(f"Invalid weekday: {day} (range is [1, 7])");
    }
    day_offset: int = (week - 1) * 7 + (day - 1);
    return _ord2ymd(_isoweek1monday(year) + day_offset);
}


def _modf(x: float) -> tuple[(float, float)] {
    if x > 9.0e18 or x < -9.0e18 {
        return (0.0, x);
    }
    t: float = float(int(x));
    return (x - t, t);
}


def _floorf(x: float) -> float {
    t: float = float(int(x));
    if x < t {
        return t - 1.0;
    }
    return t;
}


def _round_half_even(x: float) -> int {
    f: float = _floorf(x);
    diff: float = x - f;
    fi: int = int(f);
    if diff > 0.5 or (diff == 0.5 and fi % 2 != 0) {
        return fi + 1;
    }
    return fi;
}


def _float_ratio(x: float) -> tuple[(int, int)] {
    bits: int = __float_bits(x);
    sign: int = -1 if bits < 0 else 1;
    exp: int = (bits >> 52) & 2047;
    mant: int = bits & 4503599627370495;
    if exp == 2047 {
        if mant == 0 {
            raise OverflowError("cannot convert Infinity to integer ratio");
        }
        raise ValueError("cannot convert NaN to integer ratio");
    }
    num: int = 0;
    shift: int = 0;
    if exp == 0 {
        num = mant;
        shift = -1074;
    } else {
        num = mant | 4503599627370496;
        shift = exp - 1075;
    }
    if num == 0 {
        return (0, 1);
    }
    while num % 2 == 0 and shift < 0 {
        num = num // 2;
        shift += 1;
    }
    if shift > 0 {
        if shift > 62 {
            raise OverflowError("integer or float too large to convert");
        }
        return (sign * (num << shift), 1);
    }
    return (sign * num, 1 << -shift);
}


def _divide_and_round(a: int, b: int) -> int {
    q: int = a // b;
    r: int = (a - q * b) * 2;
    greater: bool = r > b if b > 0 else r < b;
    if greater or (r == b and q % 2 != 0) {
        q += 1;
    }
    return q;
}


def _build_d2 -> list[str] {
    r: list[str] = [];
    i: int = 0;
    while i < 100 {
        if i < 10 {
            r.append("0" + str(i));
        } else {
            r.append(str(i));
        }
        i += 1;
    }
    return r;
}


glob _D2: list[str] = _build_d2();


def _pad2(n: int) -> str {
    if n >= 0 and n < 100 {
        return _D2[n];
    }
    return str(n);
}


def _pad4(n: int) -> str {
    if n >= 0 and n < 10000 {
        return _D2[n // 100] + _D2[n % 100];
    }
    return str(n);
}


def _pad6(n: int) -> str {
    if n >= 0 and n < 1000000 {
        return _D2[n // 10000] + _D2[(n // 100) % 100] + _D2[n % 100];
    }
    return str(n);
}


def _wb(p: int, v: int) {
    __mem_store_i8(p, i8(v));
}


def _w2(p: int, n: int) {
    __mem_store_i16(p, i16(48 + n // 10 + ((48 + n % 10) << 8)));
}


def _w3(p: int, n: int) {
    _wb(p, 48 + n // 100);
    _w2(p + 1, n % 100);
}


def _w4(p: int, n: int) {
    _w2(p, n // 100);
    _w2(p + 2, n % 100);
}


def _w6(p: int, n: int) {
    _w2(p, n // 10000);
    _w2(p + 2, (n // 100) % 100);
    _w2(p + 4, n % 100);
}


def _w_uint(p: int, n: int) -> int {
    k: int = 1;
    m: int = n;
    while m >= 10 {
        m = m // 10;
        k += 1;
    }
    i: int = k;
    m = n;
    while i > 0 {
        i -= 1;
        _wb(p + i, 48 + m % 10);
        m = m // 10;
    }
    return k;
}


def _w_int(p: int, n: int) -> int {
    if n < 0 {
        _wb(p, 45);
        return 1 + _w_uint(p + 1, -n);
    }
    return _w_uint(p, n);
}


def _w_bytes(p: int, b: bytes) -> int {
    n: int = len(b);
    i: int = 0;
    while i < n {
        _wb(p + i, b[i]);
        i += 1;
    }
    return n;
}


def _w_str(p: int, s: str) -> int {
    if len(s) == 0 {
        return 0;
    }
    if len(s) == 1 {
        _wb(p, ord(s));
        return 1;
    }
    return _w_bytes(p, s.encode());
}


def _w_copy(p: int, src: int, n: int) -> int {
    i: int = 0;
    while i < n {
        _wb(p + i, int(__mem_load_i8(src + i)));
        i += 1;
    }
    return n;
}


def _w_date(p: int, y: int, m: int, d: int) -> int {
    _w4(p, y);
    _wb(p + 4, 45);
    _w2(p + 5, m);
    _wb(p + 7, 45);
    _w2(p + 8, d);
    return 10;
}


def _w_time(p: int, hh: int, mm: int, ss: int, us: int, timespec: str) -> int {
    ts: str = timespec;
    u: int = us;
    if ts == "auto" {
        ts = "microseconds" if u != 0 else "seconds";
    } elif ts == "milliseconds" {
        u = u // 1000;
    }
    if ts == "hours" {
        _w2(p, hh);
        return 2;
    }
    _w2(p, hh);
    _wb(p + 2, 58);
    _w2(p + 3, mm);
    if ts == "minutes" {
        return 5;
    }
    _wb(p + 5, 58);
    _w2(p + 6, ss);
    if ts == "seconds" {
        return 8;
    }
    _wb(p + 8, 46);
    if ts == "milliseconds" {
        _w3(p + 9, u);
        return 12;
    }
    if ts == "microseconds" {
        _w6(p + 9, us);
        return 15;
    }
    raise ValueError("Unknown timespec value");
}


def _w_offset(p: int, off: (timedelta | None), sep: str) -> int {
    if off is None {
        return 0;
    }
    o: timedelta = off;
    u: int = o._to_microseconds();
    q: int = p;
    if u < 0 {
        _wb(q, 45);
        u = -u;
    } else {
        _wb(q, 43);
    }
    q += 1;
    hh: int = u // 3600000000;
    u = u % 3600000000;
    mm: int = u // 60000000;
    u = u % 60000000;
    ss: int = u // 1000000;
    us: int = u % 1000000;
    if hh >= 0 and hh < 100 {
        _w2(q, hh);
        q += 2;
    } else {
        q += _w_int(q, hh);
    }
    q += _w_str(q, sep);
    _w2(q, mm);
    q += 2;
    if ss != 0 or us != 0 {
        q += _w_str(q, sep);
        _w2(q, ss);
        q += 2;
        if us != 0 {
            _wb(q, 46);
            q += 1;
            _w6(q, us);
            q += 6;
        }
    }
    return q - p;
}


def _check_date_fields(year: int, month: int, day: int) {
    if not (year >= MINYEAR and year <= MAXYEAR) {
        raise ValueError(f"year must be in {MINYEAR}..{MAXYEAR}, not {year}");
    }
    if not (month >= 1 and month <= 12) {
        raise ValueError(f"month must be in 1..12, not {month}");
    }
    dim: int = _days_in_month(year, month);
    if not (day >= 1 and day <= dim) {
        raise ValueError(
            f"day {day} must be in range 1..{dim} for month {month} in year {year}"
        );
    }
}


def _check_time_fields(
    hour: int, minute: int, second: int, microsecond: int, fold: int
) {
    if not (hour >= 0 and hour <= 23) {
        raise ValueError(f"hour must be in 0..23, not {hour}");
    }
    if not (minute >= 0 and minute <= 59) {
        raise ValueError(f"minute must be in 0..59, not {minute}");
    }
    if not (second >= 0 and second <= 59) {
        raise ValueError(f"second must be in 0..59, not {second}");
    }
    if not (microsecond >= 0 and microsecond <= 999999) {
        raise ValueError(f"microsecond must be in 0..999999, not {microsecond}");
    }
    if fold != 0 and fold != 1 {
        raise ValueError(f"fold must be either 0 or 1, not {fold}");
    }
}


def _format_offset(off: (timedelta | None), sep: str = ":") -> str {
    s: str = "";
    if off is not None {
        o: timedelta = off;
        u: int = o._to_microseconds();
        sign: str = "+";
        if u < 0 {
            sign = "-";
            u = -u;
        }
        hh: int = u // 3600000000;
        u = u % 3600000000;
        mm: int = u // 60000000;
        u = u % 60000000;
        ss: int = u // 1000000;
        us: int = u % 1000000;
        s = sign + _pad2(hh) + sep + _pad2(mm);
        if ss != 0 or us != 0 {
            s += sep + _pad2(ss);
            if us != 0 {
                s += "." + _pad6(us);
            }
        }
    }
    return s;
}


def _format_time(hh: int, mm: int, ss: int, us: int, timespec: str = "auto") -> str {
    ts: str = timespec;
    u: int = us;
    if ts == "auto" {
        ts = "microseconds" if u != 0 else "seconds";
    } elif ts == "milliseconds" {
        u = u // 1000;
    }
    if ts == "hours" {
        return _pad2(hh);
    }
    if ts == "minutes" {
        return _D2[hh] + ":" + _D2[mm];
    }
    if ts == "seconds" {
        return _D2[hh] + ":" + _D2[mm] + ":" + _D2[ss];
    }
    if ts == "milliseconds" {
        return _pad2(hh) + ":" + _pad2(mm) + ":" + _pad2(ss) + "." + str(u + 1000)[1:];
    }
    if ts == "microseconds" {
        return _pad2(hh) + ":" + _pad2(mm) + ":" + _pad2(ss) + "." + _pad6(u);
    }
    raise ValueError("Unknown timespec value");
}


def _td_repr(td: timedelta) -> str {
    parts: list[str] = [];
    if td.days != 0 {
        parts.append("days=" + str(td.days));
    }
    if td.seconds != 0 {
        parts.append("seconds=" + str(td.seconds));
    }
    if td.microseconds != 0 {
        parts.append("microseconds=" + str(td.microseconds));
    }
    if len(parts) == 0 {
        parts.append("0");
    }
    return "datetime.timedelta(" + ", ".join(parts) + ")";
}


def _tz_repr(tz: (tzinfo | None)) -> str {
    if tz is None {
        return "";
    }
    t: tzinfo = tz;
    return t.__repr__();
}


def _off_eq(a: (timedelta | None), b: (timedelta | None)) -> bool {
    if a is None and b is None {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    return (a as timedelta) == (b as timedelta);
}


def _check_utc_offset(offset: (timedelta | None)) {
    if offset is None {
        return;
    }
    o: timedelta = offset;
    if not (timedelta(-1).__lt__(o) and o.__lt__(timedelta(1))) {
        raise ValueError(
            "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not "
                + _td_repr(o)
        );
    }
}


def _build_struct_time(
    y: int, m: int, d: int, hh: int, mm: int, ss: int, dstflag: int
) -> struct_time {
    wday: int = (_ymd2ord(y, m, d) + 6) % 7;
    dnum: int = _days_before_month(y, m) + d;
    return struct_time(y, m, d, hh, mm, ss, wday, dnum, dstflag);
}


def _localtime(t: int) -> struct_time {
    dt_localtime(t);
    return struct_time(
        dt_tm(5) + 1900,
        dt_tm(4) + 1,
        dt_tm(3),
        dt_tm(2),
        dt_tm(1),
        dt_tm(0),
        (dt_tm(6) + 6) % 7,
        dt_tm(7) + 1,
        dt_tm(8)
    );
}


def _gmtime(t: int) -> struct_time {
    dt_gmtime(t);
    return struct_time(
        dt_tm(5) + 1900,
        dt_tm(4) + 1,
        dt_tm(3),
        dt_tm(2),
        dt_tm(1),
        dt_tm(0),
        (dt_tm(6) + 6) % 7,
        dt_tm(7) + 1,
        dt_tm(8)
    );
}


glob _NNC: int = -1;


def _need_normalize_century -> bool {
    if _NNC < 0 {
        try {
            _NNC = 1;
            if dt_strftime("%Y", 0, 0, 0, 1, 0, -1901, 0, 0, 0) != "0099" {
                _NNC = 1;
            } else {
                _NNC = 0;
            }
        } except Exception {
            _NNC = 1;
        }
    }
    return _NNC == 1;
}


def _wrap_strftime(
    us: int,
    off: (timedelta | None),
    tzname_val: (str | None),
    format: str,
    sec: int,
    minute: int,
    hour: int,
    mday: int,
    mon: int,
    year: int,
    wday: int,
    yday: int,
    isdst: int
) -> str {
    fb: bytes = format.encode();
    n: int = len(fb);
    if n > 640 or (tzname_val is not None and len(tzname_val) > 160) {
        return _wrap_strftime_slow(
            us,
            off,
            tzname_val,
            format,
            sec,
            minute,
            hour,
            mday,
            mon,
            year,
            wday,
            yday,
            isdst
        );
    }
    p: int = dt_out_buf();
    aux: int = dt_fmt_buf();
    q: int = p;
    flen: int = -1;
    zlen: int = -1;
    czlen: int = -1;
    Zlen: int = -1;
    i: int = 0;
    while i < n {
        if q - p > 640 {
            return _wrap_strftime_slow(
                us,
                off,
                tzname_val,
                format,
                sec,
                minute,
                hour,
                mday,
                mon,
                year,
                wday,
                yday,
                isdst
            );
        }
        ch: int = fb[i];
        i += 1;
        if ch == 37 {
            if i < n {
                ch = fb[i];
                i += 1;
                if ch == 102 {
                    if flen < 0 {
                        _w6(aux, us);
                        flen = 6;
                    }
                    q += _w_copy(q, aux, flen);
                } elif ch == 122 {
                    if zlen < 0 {
                        zlen = _w_offset(aux + 32, off, "");
                    }
                    q += _w_copy(q, aux + 32, zlen);
                } elif ch == 58 {
                    if i < n {
                        ch2: int = fb[i];
                        i += 1;
                        if ch2 == 122 {
                            if czlen < 0 {
                                czlen = _w_offset(aux + 64, off, ":");
                            }
                            q += _w_copy(q, aux + 64, czlen);
                        } else {
                            _wb(q, 37);
                            _wb(q + 1, 58);
                            _wb(q + 2, ch2);
                            q += 3;
                        }
                    } else {
                        _wb(q, 37);
                        _wb(q + 1, 58);
                        q += 2;
                    }
                } elif ch == 90 {
                    if Zlen < 0 {
                        Zlen = 0;
                        if tzname_val is not None {
                            zb: bytes = (tzname_val).encode();
                            zn: int = len(zb);
                            w: int = aux + 96;
                            zi: int = 0;
                            while zi < zn {
                                c: int = zb[zi];
                                zi += 1;
                                if c == 37 {
                                    _wb(w, 37);
                                    w += 1;
                                }
                                _wb(w, c);
                                w += 1;
                            }
                            Zlen = w - (aux + 96);
                        }
                    }
                    q += _w_copy(q, aux + 96, Zlen);
                } elif ch == 89 or ch == 71 or ch == 70 or ch == 67 {
                    if year < 1000 and _need_normalize_century() {
                        if ch == 67 {
                            _w2(q, year // 100);
                            q += 2;
                        } else {
                            _w4(q, year);
                            q += 4;
                            if ch == 70 {
                                _wb(q, 45);
                                _w2(q + 1, mon);
                                _wb(q + 3, 45);
                                _w2(q + 4, mday);
                                q += 6;
                            }
                        }
                    } else {
                        _wb(q, 37);
                        _wb(q + 1, ch);
                        q += 2;
                    }
                } else {
                    _wb(q, 37);
                    _wb(q + 1, ch);
                    q += 2;
                }
            } else {
                _wb(q, 37);
                q += 1;
            }
        } else {
            _wb(q, ch);
            q += 1;
        }
    }
    fmt: str = dt_out_str(q - p);
    return dt_strftime(
        fmt,
        sec,
        minute,
        hour,
        mday,
        mon - 1,
        year - 1900,
        (wday + 1) % 7,
        yday - 1,
        isdst
    );
}


def _wrap_strftime_slow(
    us: int,
    off: (timedelta | None),
    tzname_val: (str | None),
    format: str,
    sec: int,
    minute: int,
    hour: int,
    mday: int,
    mon: int,
    year: int,
    wday: int,
    yday: int,
    isdst: int
) -> str {
    freplace: str = "";
    zreplace: str = "";
    colonzreplace: str = "";
    Zreplace: str = "";
    freplace_set: bool = False;
    zreplace_set: bool = False;
    colonzreplace_set: bool = False;
    Zreplace_set: bool = False;
    newformat: str = "";
    i: int = 0;
    n: int = len(format);
    while i < n {
        ch: str = format[i];
        i += 1;
        if ch == "%" {
            if i < n {
                ch = format[i];
                i += 1;
                if ch == "f" {
                    if not freplace_set {
                        freplace = _pad6(us);
                        freplace_set = True;
                    }
                    newformat += freplace;
                } elif ch == "z" {
                    if not zreplace_set {
                        zreplace = _format_offset(off, "");
                        zreplace_set = True;
                    }
                    newformat += zreplace;
                } elif ch == ":" {
                    if i < n {
                        ch2: str = format[i];
                        i += 1;
                        if ch2 == "z" {
                            if not colonzreplace_set {
                                colonzreplace = _format_offset(off, ":");
                                colonzreplace_set = True;
                            }
                            newformat += colonzreplace;
                        } else {
                            newformat += "%" + ch + ch2;
                        }
                    } else {
                        newformat += "%:";
                    }
                } elif ch == "Z" {
                    if not Zreplace_set {
                        Zreplace = "";
                        if tzname_val is not None {
                            Zreplace = (tzname_val).replace("%", "%%");
                        }
                        Zreplace_set = True;
                    }
                    newformat += Zreplace;
                } elif ch == "Y" or ch == "G" or ch == "F" or ch == "C" {
                    if year < 1000 and _need_normalize_century() {
                        if ch == "C" {
                            newformat += _pad2(year // 100);
                        } else {
                            newformat += _pad4(year);
                            if ch == "F" {
                                newformat += "-" + _pad2(mon) + "-" + _pad2(mday);
                            }
                        }
                    } else {
                        newformat += "%" + ch;
                    }
                } else {
                    newformat += "%" + ch;
                }
            } else {
                newformat += "%";
            }
        } else {
            newformat += ch;
        }
    }
    return dt_strftime(
        newformat,
        sec,
        minute,
        hour,
        mday,
        mon - 1,
        year - 1900,
        (wday + 1) % 7,
        yday - 1,
        isdst
    );
}


def _is_ascii_digit(c: str) -> bool {
    return is_digit(ord(c));
}


def _dig2(s: bytes, p: int) -> int {
    a: int = s[p] - 48;
    b: int = s[p + 1] - 48;
    if a < 0 or a > 9 or b < 0 or b > 9 {
        return -1;
    }
    return a * 10 + b;
}


def _dig4(s: bytes, p: int) -> int {
    a: int = s[p] - 48;
    b: int = s[p + 1] - 48;
    c: int = s[p + 2] - 48;
    d: int = s[p + 3] - 48;
    if a < 0 or a > 9 or b < 0 or b > 9 or c < 0 or c > 9 or d < 0 or d > 9 {
        return -1;
    }
    return a * 1000 + b * 100 + c * 10 + d;
}


def _atoi(s: str) -> int {
    n: int = len(s);
    if n == 0 {
        raise ValueError("invalid literal for int()");
    }
    v: int = 0;
    i: int = 0;
    neg: bool = False;
    if s[0] == "+" or s[0] == "-" {
        if n == 1 {
            raise ValueError("invalid literal for int()");
        }
        neg = s[0] == "-";
        i = 1;
    }
    while i < n {
        dv: int = ord(s[i]) - 48;
        if dv < 0 or dv > 9 {
            raise ValueError("invalid literal for int()");
        }
        v = v * 10 + dv;
        i += 1;
    }
    if neg {
        v = -v;
    }
    return v;
}


def _find_isoformat_datetime_separator(dtstr: bytes) -> int {
    len_dtstr: int = len(dtstr);
    if len_dtstr == 7 {
        return 7;
    }
    if len_dtstr <= 7 {
        return -1;
    }
    if dtstr[4] == 45 {
        if dtstr[5] == 87 {
            if len_dtstr < 8 {
                return -1;
            }
            if len_dtstr > 8 and dtstr[8] == 45 {
                if len_dtstr == 9 {
                    return -1;
                }
                d10: int = 0;
                if len_dtstr > 10 {
                    d10 = dtstr[10] - 48;
                }
                if len_dtstr > 10 and d10 >= 0 and d10 <= 9 {
                    return 8;
                }
                return 10;
            }
            return 8;
        }
        return 10;
    }
    if dtstr[4] == 87 {
        idx: int = 7;
        while idx < len_dtstr {
            dc: int = dtstr[idx] - 48;
            if dc < 0 or dc > 9 {
                break;
            }
            idx += 1;
        }
        if idx < 9 {
            return idx;
        }
        if idx % 2 == 0 {
            return 7;
        }
        return 8;
    }
    return 8;
}


def _parse_isoformat_date(dtstr: str) -> tuple[(int, int, int)] {
    b: bytes = dtstr.encode();
    return _parse_isoformat_date_range(b, 0, len(b));
}


def _parse_isoformat_date_range(s: bytes, lo: int, hi: int) -> tuple[(int, int, int)] {
    n: int = hi - lo;
    if n != 7 and n != 8 and n != 10 {
        return (-1, -1, -1);
    }
    year: int = _dig4(s, lo);
    if year < 0 {
        return (-1, -1, -1);
    }
    has_sep: bool = s[lo + 4] == 45;
    pos: int = lo + 4 + (1 if has_sep else 0);
    if s[pos] == 87 {
        pos += 1;
        weekno: int = _dig2(s, pos);
        pos += 2;
        dayno: int = 1;
        if pos < hi {
            if (s[pos] == 45) != has_sep {
                return (-1, -1, -1);
            }
            pos += 1 if has_sep else 0;
            dayno = s[pos] - 48;
            if dayno < 0 or dayno > 9 {
                return (-1, -1, -1);
            }
        }
        week_ok: bool = weekno > 0 and weekno < 53;
        if weekno == 53 {
            first_weekday: int = _ymd2ord(year, 1, 1) % 7;
            week_ok = first_weekday == 4 or (first_weekday == 3 and _is_leap(year));
        }
        if not week_ok or dayno < 1 or dayno > 7 {
            return (-1, -1, -1);
        }
        return _isoweek_to_gregorian(year, weekno, dayno);
    }
    month: int = _dig2(s, pos);
    if month < 0 {
        return (-1, -1, -1);
    }
    pos += 2;
    if (s[pos] == 45) != has_sep {
        return (-1, -1, -1);
    }
    pos += 1 if has_sep else 0;
    day: int = s[pos] - 48;
    if day < 0 or day > 9 {
        return (-1, -1, -1);
    }
    if pos + 1 < hi {
        d2: int = s[pos + 1] - 48;
        if d2 < 0 or d2 > 9 {
            return (-1, -1, -1);
        }
        day = day * 10 + d2;
    }
    return (year, month, day);
}


obj _IsoTimeResult {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzi: (tzinfo | None) = None,
        became_next_day: bool = False,
        error_from_components: bool = False,
        invalid: bool = False;
}

glob _TZ_SCRATCH: _IsoTimeResult = _IsoTimeResult(),
     _TZ_CACHE: dict[int, timezone] = {};


def _parse_hh_mm_ss_ff(tstr: bytes, pos: int, end: int, res: _IsoTimeResult) {
    if end < 0 {
        end = len(tstr);
    }
    res.hour = 0;
    res.minute = 0;
    res.second = 0;
    res.microsecond = 0;
    res.invalid = False;
    comp: int = 0;
    has_sep: bool = False;
    while comp < 3 {
        if end - pos < 2 {
            res.invalid = True;
            return;
        }
        v: int = _dig2(tstr, pos);
        if v < 0 {
            res.invalid = True;
            return;
        }
        if comp == 0 {
            res.hour = v;
        } elif comp == 1 {
            res.minute = v;
        } else {
            res.second = v;
        }
        pos += 2;
        nc: int = -1;
        if pos < end {
            nc = tstr[pos];
        }
        if comp == 0 {
            has_sep = nc == 58;
        }
        if nc < 0 or comp >= 2 {
            break;
        }
        if has_sep and nc != 58 {
            res.invalid = True;
            return;
        }
        pos += 1 if has_sep else 0;
        comp += 1;
    }
    if pos < end {
        if tstr[pos] != 46 and tstr[pos] != 44 {
            res.invalid = True;
            return;
        }
        pos += 1;
        micro: int = 0;
        ndig: int = 0;
        while pos < end {
            d9: int = tstr[pos] - 48;
            if d9 < 0 or d9 > 9 {
                res.invalid = True;
                return;
            }
            if ndig < 6 {
                micro = micro * 10 + d9;
            }
            ndig += 1;
            pos += 1;
        }
        if ndig == 0 {
            res.invalid = True;
            return;
        }
        if ndig < 6 {
            micro *= _FRACTION_CORRECTION[ndig - 1];
        }
        res.microsecond = micro;
    }
    return;
}


def _parse_isoformat_time(tstr: str) -> _IsoTimeResult {
    return _parse_isoformat_time_at(tstr.encode(), 0);
}


def _parse_isoformat_time_at(s: bytes, lo: int) -> _IsoTimeResult {
    len_str: int = len(s);
    if len_str - lo < 2 {
        res0: _IsoTimeResult = _IsoTimeResult();
        res0.invalid = True;
        return res0;
    }
    tz_idx: int = -1;
    k: int = lo;
    while k < len_str {
        c: int = s[k];
        if c == 45 or c == 43 or c == 90 {
            tz_idx = k;
            break;
        }
        k += 1;
    }
    tend: int = len_str if tz_idx < 0 else tz_idx;
    res: _IsoTimeResult = _IsoTimeResult();
    _parse_hh_mm_ss_ff(s, lo, tend, res);
    if res.invalid {
        return res;
    }
    if res.hour == 24 {
        if res.minute == 0 and res.second == 0 and res.microsecond == 0 {
            res.hour = 0;
            res.became_next_day = True;
        } else {
            res.error_from_components = True;
        }
    }
    if tz_idx >= 0 {
        if s[tz_idx] == 90 {
            if tz_idx != len_str - 1 {
                res.invalid = True;
                return res;
            }
            res.tzi = timezone.utc;
        } else {
            lz: int = len_str - tz_idx - 1;
            if lz == 0 or lz == 1 or lz == 3 {
                res.invalid = True;
                return res;
            }
            _parse_hh_mm_ss_ff(s, tz_idx + 1, len_str, _TZ_SCRATCH);
            tzc: _IsoTimeResult = _TZ_SCRATCH;
            if tzc.invalid {
                res.invalid = True;
                return res;
            }
            tzsign: int = -1 if s[tz_idx] == 45 else 1;
            off_us: int = tzsign
                * (
                    (tzc.hour * 3600 + tzc.minute * 60 + tzc.second) * 1000000
                    + tzc.microsecond
                );
            if off_us == 0 {
                res.tzi = timezone.utc;
            } else {
                ntz: (timezone | None) = _TZ_CACHE.get(off_us);
                if ntz is None {
                    ntz = timezone(timedelta(0, 0, off_us));
                    _TZ_CACHE[off_us] = ntz;
                }
                res.tzi = ntz;
            }
        }
    }
    return res;
}


obj:pub timedelta {
    has days: int = 0,
        seconds: int = 0,
        microseconds: int = 0;

    def init(
        days: (int | float) = 0,
        seconds: (int | float) = 0,
        microseconds: (int | float) = 0,
        milliseconds: (int | float) = 0,
        minutes: (int | float) = 0,
        hours: (int | float) = 0,
        weeks: (int | float) = 0
    ) {
        d: int = 0;
        s: int = 0;
        us: int = 0;
        days_w: int = 0;
        seconds_w: int = 0;
        microseconds_w: int = 0;
        milliseconds_w: int = 0;
        minutes_w: int = 0;
        hours_w: int = 0;
        weeks_w: int = 0;
        days_f: float = 0.0;
        seconds_f: float = 0.0;
        microseconds_f: float = 0.0;
        milliseconds_f: float = 0.0;
        minutes_f: float = 0.0;
        hours_f: float = 0.0;
        weeks_f: float = 0.0;
        if isinstance(days, float) {
            days_f = days;
            if _fabs(days_f) > 1.0e15 {
                raise OverflowError("days value too large");
            }
        } else {
            days_w = days as int;
        }
        if isinstance(seconds, float) {
            seconds_f = seconds;
            if _fabs(seconds_f) > 9.0e17 {
                raise OverflowError("seconds value too large");
            }
        } else {
            seconds_w = seconds as int;
        }
        if isinstance(microseconds, float) {
            microseconds_f = microseconds;
            if _fabs(microseconds_f) > 9.0e17 {
                raise OverflowError("microseconds value too large");
            }
        } else {
            microseconds_w = microseconds as int;
        }
        if isinstance(milliseconds, float) {
            milliseconds_f = milliseconds;
            if _fabs(milliseconds_f) > 9.0e17 {
                raise OverflowError("milliseconds value too large");
            }
        } else {
            milliseconds_w = milliseconds as int;
        }
        if isinstance(minutes, float) {
            minutes_f = minutes;
            if _fabs(minutes_f) > 9.0e17 {
                raise OverflowError("minutes value too large");
            }
        } else {
            minutes_w = minutes as int;
        }
        if isinstance(hours, float) {
            hours_f = hours;
            if _fabs(hours_f) > 9.0e17 {
                raise OverflowError("hours value too large");
            }
        } else {
            hours_w = hours as int;
        }
        if isinstance(weeks, float) {
            weeks_f = weeks;
            if _fabs(weeks_f) > 1.0e15 {
                raise OverflowError("weeks value too large");
            }
        } else {
            weeks_w = weeks as int;
        }
        days_w += weeks_w * 7;
        days_f += weeks_f * 7.0;
        seconds_w += minutes_w * 60 + hours_w * 3600;
        seconds_f += minutes_f * 60.0 + hours_f * 3600.0;
        microseconds_f += milliseconds_f * 1000.0;
        microseconds_w += milliseconds_w * 1000;
        if days_f == 0.0 and seconds_f == 0.0 and microseconds_f == 0.0 {
            ssec: int = microseconds_w // 1000000;
            us = microseconds_w - ssec * 1000000;
            s = seconds_w + ssec;
            ddays: int = s // 86400;
            s -= ddays * 86400;
            d = days_w + ddays;
            self.days = d;
            self.seconds = s;
            self.microseconds = us;
            if _iabs(d) > 999999999 {
                raise OverflowError(f"days={d}; must have magnitude <= 999999999");
            }
            return;
        }
        daysecondsfrac: float = 0.0;
        if days_f != 0.0 {
            fr: float = 0.0;
            ip: float = 0.0;
            (fr, ip) = _modf(days_f);
            d = int(ip);
            (fr, ip) = _modf(fr * 86400.0);
            s = int(ip);
            daysecondsfrac = fr;
        } else {
            d = days_w;
        }
        secondsfrac: float = daysecondsfrac;
        if seconds_f != 0.0 {
            fr: float = 0.0;
            ip: float = 0.0;
            (fr, ip) = _modf(seconds_f);
            seconds_w = int(ip);
            secondsfrac += fr;
        }
        dd: int = seconds_w // 86400;
        seconds_w -= dd * 86400;
        d += dd;
        s += seconds_w;
        usdouble: float = secondsfrac * 1000000.0;
        if microseconds_f != 0.0 {
            mf: int = _round_half_even(microseconds_f + usdouble);
            ss2: int = mf // 1000000;
            mf -= ss2 * 1000000;
            dds: int = ss2 // 86400;
            ss2 -= dds * 86400;
            d += dds;
            s += ss2;
            microseconds_w = mf;
        } else {
            microseconds_w += _round_half_even(usdouble);
        }
        ssec: int = microseconds_w // 1000000;
        us = microseconds_w - ssec * 1000000;
        s += ssec;
        ddays: int = s // 86400;
        s -= ddays * 86400;
        d += ddays;
        self.days = d;
        self.seconds = s;
        self.microseconds = us;
        if _iabs(d) > 999999999 {
            raise OverflowError(f"days={d}; must have magnitude <= 999999999");
        }
    }

    def _to_microseconds -> int {
        return (self.days * 86400 + self.seconds) * 1000000 + self.microseconds;
    }

    def __repr__ -> str {
        args: str = "";
        if self.days != 0 {
            args += "days=" + str(self.days);
        }
        if self.seconds != 0 {
            if args != "" {
                args += ", ";
            }
            args += "seconds=" + str(self.seconds);
        }
        if self.microseconds != 0 {
            if args != "" {
                args += ", ";
            }
            args += "microseconds=" + str(self.microseconds);
        }
        if args == "" {
            args = "0";
        }
        return "datetime.timedelta(" + args + ")";
    }

    def __str__ -> str {
        mm: int = self.seconds // 60;
        ss: int = self.seconds % 60;
        hh: int = mm // 60;
        mm = mm % 60;
        p: int = dt_out_buf();
        q: int = p;
        if self.days != 0 {
            q += _w_int(q, self.days);
            q += _w_bytes(q, b" day");
            if _iabs(self.days) != 1 {
                _wb(q, 115);
                q += 1;
            }
            q += _w_bytes(q, b", ");
        }
        q += _w_uint(q, hh);
        _wb(q, 58);
        q += 1;
        _w2(q, mm);
        q += 2;
        _wb(q, 58);
        q += 1;
        _w2(q, ss);
        q += 2;
        if self.microseconds != 0 {
            _wb(q, 46);
            q += 1;
            _w6(q, self.microseconds);
            q += 6;
        }
        return dt_out_str(q - p);
    }

    def __format__(fmt: str) -> str {
        return str(self);
    }

    def total_seconds -> float {
        return float((self.days * 86400 + self.seconds) * 1000000 + self.microseconds)
            / 1000000.0;
    }

    def __add__(other: (timedelta | date)) -> (timedelta | date) {
        if isinstance(other, timedelta) {
            o: timedelta = other;
            return timedelta(
                self.days + o.days,
                self.seconds + o.seconds,
                self.microseconds + o.microseconds
            );
        }
        return (other as date) + self;
    }

    def __radd__(other: (timedelta | date)) -> (timedelta | date) {
        return self + other;
    }

    def __sub__(other: timedelta) -> timedelta {
        return timedelta(
            self.days - other.days,
            self.seconds - other.seconds,
            self.microseconds - other.microseconds
        );
    }

    def __rsub__(other: (timedelta | date)) -> (timedelta | date) {
        if isinstance(other, timedelta) {
            return (other as timedelta) - self;
        }
        return (other as date) - self;
    }

    def __neg__ -> timedelta {
        return timedelta(-self.days, -self.seconds, -self.microseconds);
    }

    def __pos__ -> timedelta {
        return timedelta(self.days, self.seconds, self.microseconds);
    }

    def __abs__ -> timedelta {
        if self.days < 0 {
            return self.__neg__();
        }
        return self;
    }

    def __mul__(other: (int | float)) -> timedelta {
        if isinstance(other, int) {
            oi: int = other;
            return timedelta(self.days * oi, self.seconds * oi, self.microseconds * oi);
        }
        usec: int = self._to_microseconds();
        (a, b) = _float_ratio((other as float));
        if _iabs(usec) > 0 and _iabs(a) > 9007199254740992 // _iabs(usec) {
            raise OverflowError("integer or float too large to convert");
        }
        return timedelta(0, 0, _divide_and_round(usec * a, b));
    }

    def __rmul__(other: (int | float)) -> timedelta {
        return self * other;
    }

    def __floordiv__(other: (int | timedelta)) -> (timedelta | int) {
        usec: int = self._to_microseconds();
        if isinstance(other, timedelta) {
            return usec // (other as timedelta)._to_microseconds();
        }
        oi: int = other as int;
        return timedelta(0, 0, usec // oi);
    }

    def __truediv__(other: (int | float | timedelta)) -> (timedelta | float) {
        usec: int = self._to_microseconds();
        if isinstance(other, timedelta) {
            return float(usec) / float((other as timedelta)._to_microseconds());
        }
        if isinstance(other, int) {
            return timedelta(0, 0, _divide_and_round(usec, (other as int)));
        }
        (a, b) = _float_ratio((other as float));
        if _iabs(usec) > 0 and _iabs(b) > 9007199254740992 // _iabs(usec) {
            raise OverflowError("integer or float too large to convert");
        }
        return timedelta(0, 0, _divide_and_round(b * usec, a));
    }

    def __mod__(other: timedelta) -> timedelta {
        return timedelta(0, 0, self._to_microseconds() % other._to_microseconds());
    }

    def __divmod__(other: timedelta) -> tuple[(int, timedelta)] {
        q: int = self._to_microseconds() // other._to_microseconds();
        r: int = self._to_microseconds() - q * other._to_microseconds();
        return (q, timedelta(0, 0, r));
    }

    def _cmp(other: timedelta) -> int {
        a: int = self._to_microseconds();
        b: int = other._to_microseconds();
        if a == b {
            return 0;
        }
        return 1 if a > b else -1;
    }

    def __eq__(other: timedelta) -> bool {
        return self._cmp(other) == 0;
    }

    def __ne__(other: timedelta) -> bool {
        return self._cmp(other) != 0;
    }

    def __le__(other: timedelta) -> bool {
        return self._cmp(other) <= 0;
    }

    def __lt__(other: timedelta) -> bool {
        return self._cmp(other) < 0;
    }

    def __ge__(other: timedelta) -> bool {
        return self._cmp(other) >= 0;
    }

    def __gt__(other: timedelta) -> bool {
        return self._cmp(other) > 0;
    }

    def __bool__ -> bool {
        return self.days != 0 or self.seconds != 0 or self.microseconds != 0;
    }

    static has min: timedelta = timedelta(-999999999),
        max: timedelta = timedelta(999999999, 86399, 999999),
        resolution: timedelta = timedelta(0, 0, 1);
}


def _fabs(x: float) -> float {
    return -x if x < 0.0 else x;
}


obj:pub struct_time {
    has tm_year: int = 0,
        tm_mon: int = 0,
        tm_mday: int = 0,
        tm_hour: int = 0,
        tm_min: int = 0,
        tm_sec: int = 0,
        tm_wday: int = 0,
        tm_yday: int = 0,
        tm_isdst: int = 0;

    def __getitem__(i: int) -> int {
        if i == 0 {
            return self.tm_year;
        }
        if i == 1 {
            return self.tm_mon;
        }
        if i == 2 {
            return self.tm_mday;
        }
        if i == 3 {
            return self.tm_hour;
        }
        if i == 4 {
            return self.tm_min;
        }
        if i == 5 {
            return self.tm_sec;
        }
        if i == 6 {
            return self.tm_wday;
        }
        if i == 7 {
            return self.tm_yday;
        }
        if i == 8 {
            return self.tm_isdst;
        }
        raise IndexError("struct_time index out of range");
    }

    def __len__ -> int {
        return 9;
    }

    def __repr__ -> str {
        return "time.struct_time(tm_year="
            + str(self.tm_year)
            + ", tm_mon="
            + str(self.tm_mon)
            + ", tm_mday="
            + str(self.tm_mday)
            + ", tm_hour="
            + str(self.tm_hour)
            + ", tm_min="
            + str(self.tm_min)
            + ", tm_sec="
            + str(self.tm_sec)
            + ", tm_wday="
            + str(self.tm_wday)
            + ", tm_yday="
            + str(self.tm_yday)
            + ", tm_isdst="
            + str(self.tm_isdst)
            + ")";
    }
}


obj:pub IsoCalendarDate {
    has year: int = 0,
        week: int = 0,
        weekday: int = 0;

    def __getitem__(i: int) -> int {
        if i == 0 {
            return self.year;
        }
        if i == 1 {
            return self.week;
        }
        if i == 2 {
            return self.weekday;
        }
        raise IndexError("IsoCalendarDate index out of range");
    }

    def __len__ -> int {
        return 3;
    }

    def __repr__ -> str {
        return "datetime.IsoCalendarDate(year="
            + str(self.year)
            + ", week="
            + str(self.week)
            + ", weekday="
            + str(self.weekday)
            + ")";
    }
}


obj:pub date {
    has year: int = 0,
        month: int = 0,
        day: int = 0;

    def init(year: int, month: int, day: int) {
        _check_date_fields(year, month, day);
        self.year = year;
        self.month = month;
        self.day = day;
    }

    static def fromtimestamp(t: float) -> date {
        if t > 9.0e18 or t < -9.0e18 {
            raise OverflowError("timestamp out of range for platform time_t");
        }
        st: struct_time = _localtime(int(t));
        return date(st.tm_year, st.tm_mon, st.tm_mday);
    }

    static def today -> date {
        return date.fromtimestamp(float(dt_epoch_us() // 1000000));
    }

    static def fromordinal(n: int) -> date {
        if n < 1 {
            raise ValueError("ordinal must be >= 1");
        }
        (y, m, d) = _ord2ymd(n);
        return date(y, m, d);
    }

    static def fromisoformat(date_string: str) -> date {
        (y, m, d) = _parse_isoformat_date(date_string);
        if y < 0 {
            raise ValueError(f"Invalid isoformat string: '{date_string}'");
        }
        return date(y, m, d);
    }

    static def fromisocalendar(year: int, week: int, day: int) -> date {
        (y, m, d) = _isoweek_to_gregorian(year, week, day);
        return date(y, m, d);
    }

    static def strptime(date_string: str, format: str) -> date {
        r: _StrptimeResult = _strptime(date_string, format);
        return date(r.year, r.month, r.day);
    }

    def timetuple -> struct_time {
        return _build_struct_time(self.year, self.month, self.day, 0, 0, 0, -1);
    }

    def toordinal -> int {
        return _ymd2ord(self.year, self.month, self.day);
    }

    def replace(
        year: (int | None) = None, month: (int | None) = None, day: (int | None) = None
    ) -> date {
        y: int = self.year if year is None else year;
        m: int = self.month if month is None else month;
        d: int = self.day if day is None else day;
        return date(y, m, d);
    }

    def __eq__(other: date) -> bool {
        if isinstance(other, datetime) {
            return False;
        }
        return self._cmp(other) == 0;
    }

    def __ne__(other: date) -> bool {
        if isinstance(other, datetime) {
            return True;
        }
        return self._cmp(other) != 0;
    }

    def __le__(other: date) -> bool {
        if isinstance(other, datetime) {
            raise TypeError(
                "'<=' not supported between instances of 'datetime.date' and 'datetime.datetime'"
            );
        }
        return self._cmp(other) <= 0;
    }

    def __lt__(other: date) -> bool {
        if isinstance(other, datetime) {
            raise TypeError(
                "'<' not supported between instances of 'datetime.date' and 'datetime.datetime'"
            );
        }
        return self._cmp(other) < 0;
    }

    def __ge__(other: date) -> bool {
        if isinstance(other, datetime) {
            raise TypeError(
                "'>=' not supported between instances of 'datetime.date' and 'datetime.datetime'"
            );
        }
        return self._cmp(other) >= 0;
    }

    def __gt__(other: date) -> bool {
        if isinstance(other, datetime) {
            raise TypeError(
                "'>' not supported between instances of 'datetime.date' and 'datetime.datetime'"
            );
        }
        return self._cmp(other) > 0;
    }

    def _cmp(other: date) -> int {
        if self.year != other.year {
            return 1 if self.year > other.year else -1;
        }
        if self.month != other.month {
            return 1 if self.month > other.month else -1;
        }
        if self.day != other.day {
            return 1 if self.day > other.day else -1;
        }
        return 0;
    }

    def __add__(other: timedelta) -> date {
        o: int = self.toordinal() + other.days;
        if o > 0 and o <= _MAXORDINAL {
            return date.fromordinal(o);
        }
        raise OverflowError("result out of range");
    }

    def __radd__(other: timedelta) -> date {
        return self + other;
    }

    def __sub__(other: (timedelta | date)) -> (timedelta | date) {
        if isinstance(other, timedelta) {
            return self + timedelta(-(other as timedelta).days);
        }
        if isinstance(other, datetime) {
            raise TypeError(
                "unsupported operand type(s) for -: 'datetime.date' and 'datetime.datetime'"
            );
        }
        return timedelta(self.toordinal() - (other as date).toordinal());
    }

    def weekday -> int {
        return (self.toordinal() + 6) % 7;
    }

    def isoweekday -> int {
        r: int = self.toordinal() % 7;
        return 7 if r == 0 else r;
    }

    def isocalendar -> IsoCalendarDate {
        year: int = self.year;
        week1monday: int = _isoweek1monday(year);
        today: int = _ymd2ord(self.year, self.month, self.day);
        week: int = (today - week1monday) // 7;
        day: int = (today - week1monday) % 7;
        if week < 0 {
            year -= 1;
            week1monday = _isoweek1monday(year);
            week = (today - week1monday) // 7;
            day = (today - week1monday) % 7;
        } elif week >= 52 {
            if today >= _isoweek1monday(year + 1) {
                year += 1;
                week = -1;
            }
        }
        return IsoCalendarDate(year, week + 1, day + 1);
    }

    def ctime -> str {
        weekday: int = self.toordinal() % 7;
        if weekday == 0 {
            weekday = 7;
        }
        ds: str = " " + str(self.day) if self.day < 10 else str(self.day);
        return _DAYNAMES[weekday]
            + " "
            + _MONTHNAMES[self.month]
            + " "
            + ds
            + " 00:00:00 "
            + _pad4(self.year);
    }

    def strftime(format: str) -> str {
        return _wrap_strftime(
            0,
            None,
            None,
            format,
            0,
            0,
            0,
            self.day,
            self.month,
            self.year,
            self.weekday(),
            _days_before_month(self.year, self.month) + self.day,
            -1
        );
    }

    def __format__(fmt: str) -> str {
        if len(fmt) != 0 {
            return self.strftime(fmt);
        }
        return str(self);
    }

    def isoformat -> str {
        return _pad4(self.year) + "-" + _pad2(self.month) + "-" + _pad2(self.day);
    }

    def __str__ -> str {
        return self.isoformat();
    }

    def __repr__ -> str {
        return "datetime.date("
            + str(self.year)
            + ", "
            + str(self.month)
            + ", "
            + str(self.day)
            + ")";
    }

    static has min: date = date(1, 1, 1),
        max: date = date(9999, 12, 31),
        resolution: timedelta = timedelta(1);
}


obj:pub tzinfo {
    def tzname(dt: (datetime | None)) -> (str | None) {
        raise NotImplementedError("tzinfo subclass must override tzname()");
    }

    def utcoffset(dt: (datetime | None)) -> (timedelta | None) {
        raise NotImplementedError("tzinfo subclass must override utcoffset()");
    }

    def dst(dt: (datetime | None)) -> (timedelta | None) {
        raise NotImplementedError("tzinfo subclass must override dst()");
    }

    def fromutc(dt: datetime) -> datetime {
        if not isinstance(dt, datetime) {
            raise TypeError("fromutc() requires a datetime argument");
        }
        if dt.tzinfo is not self {
            raise ValueError("dt.tzinfo is not self");
        }
        dtoff: (timedelta | None) = dt.utcoffset();
        if dtoff is None {
            raise ValueError("fromutc() requires a non-None utcoffset() result");
        }
        dtdst: (timedelta | None) = dt.dst();
        if dtdst is None {
            raise ValueError("fromutc() requires a non-None dst() result");
        }
        delta: timedelta = (dtoff as timedelta) - (dtdst as timedelta);
        if delta {
            dt = dt + delta;
            dtdst = dt.dst();
            if dtdst is None {
                raise ValueError(
                    "fromutc(): dt.dst gave inconsistent results; cannot convert"
                );
            }
        }
        return dt + (dtdst as timedelta);
    }

    def __repr__ -> str {
        return "<tzinfo>";
    }
}


glob _TZ_KEEP: tzinfo = tzinfo();


obj:pub time {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzinfo: (tzinfo | None) = None,
        fold: int = 0;

    def init(
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzinfo: (tzinfo | None) = None,
        fold: int = 0
    ) {
        _check_time_fields(hour, minute, second, microsecond, fold);
        self.hour = hour;
        self.minute = minute;
        self.second = second;
        self.microsecond = microsecond;
        self.tzinfo = tzinfo;
        self.fold = fold;
    }

    static def fromisoformat(time_string: str) -> time {
        s: str = time_string;
        if len(s) > 0 and s[0] == "T" {
            s = s[1:];
        }
        r: _IsoTimeResult = _parse_isoformat_time(s);
        if r.invalid or r.error_from_components {
            raise ValueError(f"Invalid isoformat string: '{time_string}'");
        }
        return time(r.hour, r.minute, r.second, r.microsecond, r.tzi);
    }

    static def strptime(date_string: str, format: str) -> time {
        r: _StrptimeResult = _strptime(date_string, format);
        return time(r.hour, r.minute, r.second, r.microsecond, r.tz);
    }

    def _tzstr -> str {
        off: (timedelta | None) = self.utcoffset();
        return _format_offset(off);
    }

    def utcoffset -> (timedelta | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        offset: (timedelta | None) = tz.utcoffset(None);
        _check_utc_offset(offset);
        return offset;
    }

    def tzname -> (str | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        return tz.tzname(None);
    }

    def dst -> (timedelta | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        offset: (timedelta | None) = tz.dst(None);
        _check_utc_offset(offset);
        return offset;
    }

    def replace(
        hour: (int | None) = None,
        minute: (int | None) = None,
        second: (int | None) = None,
        microsecond: (int | None) = None,
        tzinfo: (tzinfo | None) = _TZ_KEEP,
        fold: (int | None) = None
    ) -> time {
        h: int = self.hour if hour is None else hour;
        mi: int = self.minute if minute is None else minute;
        s: int = self.second if second is None else second;
        us: int = self.microsecond if microsecond is None else microsecond;
        tz: (tzinfo | None) = self.tzinfo if tzinfo is _TZ_KEEP else tzinfo;
        f: int = self.fold if fold is None else fold;
        return time(h, mi, s, us, tz, f);
    }

    def isoformat(timespec: str = "auto") -> str {
        p: int = dt_out_buf();
        n: int = _w_time(
            p, self.hour, self.minute, self.second, self.microsecond, timespec
        );
        n += _w_offset(p + n, self.utcoffset(), ":");
        return dt_out_str(n);
    }

    def __str__ -> str {
        return self.isoformat();
    }

    def strftime(format: str) -> str {
        return _wrap_strftime(
            self.microsecond,
            self.utcoffset(),
            self.tzname(),
            format,
            self.second,
            self.minute,
            self.hour,
            1,
            1,
            1900,
            0,
            1,
            -1
        );
    }

    def __format__(fmt: str) -> str {
        if len(fmt) != 0 {
            return self.strftime(fmt);
        }
        return str(self);
    }

    def __repr__ -> str {
        s: str = "";
        if self.microsecond != 0 {
            s = ", " + str(self.second) + ", " + str(self.microsecond);
        } elif self.second != 0 {
            s = ", " + str(self.second);
        }
        r: str = "datetime.time(" + str(self.hour) + ", " + str(self.minute) + s + ")";
        if self.tzinfo is not None {
            r = r[0:len(r) - 1] + ", tzinfo=" + _tz_repr(self.tzinfo) + ")";
        }
        if self.fold != 0 {
            r = r[0:len(r) - 1] + ", fold=1)";
        }
        return r;
    }

    def _cmp(other: time, allow_mixed: bool) -> int {
        mytz: (tzinfo | None) = self.tzinfo;
        ottz: (tzinfo | None) = other.tzinfo;
        myoff: (timedelta | None) = None;
        otoff: (timedelta | None) = None;
        base_compare: bool = False;
        if mytz is ottz {
            base_compare = True;
        } else {
            myoff = self.utcoffset();
            otoff = other.utcoffset();
            if myoff is None and otoff is None {
                base_compare = True;
            } elif myoff is None or otoff is None {
                base_compare = False;
            } else {
                base_compare = (myoff as timedelta) == (otoff as timedelta);
            }
        }
        if base_compare {
            if self.hour != other.hour {
                return 1 if self.hour > other.hour else -1;
            }
            if self.minute != other.minute {
                return 1 if self.minute > other.minute else -1;
            }
            if self.second != other.second {
                return 1 if self.second > other.second else -1;
            }
            if self.microsecond != other.microsecond {
                return 1 if self.microsecond > other.microsecond else -1;
            }
            return 0;
        }
        if myoff is None or otoff is None {
            if allow_mixed {
                return 2;
            }
            raise TypeError("cannot compare naive and aware times");
        }
        mo: timedelta = myoff;
        oo: timedelta = otoff;
        myhhmm: int = self.hour * 60 + self.minute
            - (mo._to_microseconds() // 60000000);
        othhmm: int = other.hour * 60 + other.minute
            - (oo._to_microseconds() // 60000000);
        if myhhmm != othhmm {
            return 1 if myhhmm > othhmm else -1;
        }
        if self.second != other.second {
            return 1 if self.second > other.second else -1;
        }
        if self.microsecond != other.microsecond {
            return 1 if self.microsecond > other.microsecond else -1;
        }
        return 0;
    }

    def __eq__(other: time) -> bool {
        return self._cmp(other, True) == 0;
    }

    def __ne__(other: time) -> bool {
        return self._cmp(other, True) != 0;
    }

    def __le__(other: time) -> bool {
        return self._cmp(other, False) <= 0;
    }

    def __lt__(other: time) -> bool {
        return self._cmp(other, False) < 0;
    }

    def __ge__(other: time) -> bool {
        return self._cmp(other, False) >= 0;
    }

    def __gt__(other: time) -> bool {
        return self._cmp(other, False) > 0;
    }

    static has min: time = time(0, 0, 0),
        max: time = time(23, 59, 59, 999999),
        resolution: timedelta = timedelta(0, 0, 1);
}


obj:pub datetime(date) {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzinfo: (tzinfo | None) = None,
        fold: int = 0;

    def init(
        year: int,
        month: int,
        day: int,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        tzinfo: (tzinfo | None) = None,
        fold: int = 0
    ) {
        _check_date_fields(year, month, day);
        _check_time_fields(hour, minute, second, microsecond, fold);
        self.year = year;
        self.month = month;
        self.day = day;
        self.hour = hour;
        self.minute = minute;
        self.second = second;
        self.microsecond = microsecond;
        self.tzinfo = tzinfo;
        self.fold = fold;
    }

    static def _fromepoch(
        sec: int, us: int, utc: bool, tz: (tzinfo | None)
    ) -> datetime {
        if utc {
            dt_gmtime(sec);
        } else {
            dt_localtime(sec);
        }
        ss: int = dt_tm(0);
        if ss > 59 {
            ss = 59;
        }
        result: datetime = datetime(
            dt_tm(5) + 1900, dt_tm(4) + 1, dt_tm(3), dt_tm(2), dt_tm(1), ss, us, tz
        );
        if tz is None and not utc {
            off_now: int = dt_tm_gmtoff();
            dt_localtime(sec - 86400);
            shift: int = off_now - dt_tm_gmtoff();
            if shift < 0 {
                dt_localtime(sec + shift);
                probe2: datetime = datetime(
                    dt_tm(5) + 1900,
                    dt_tm(4) + 1,
                    dt_tm(3),
                    dt_tm(2),
                    dt_tm(1),
                    dt_tm(0),
                    us,
                    None
                );
                if probe2 == result {
                    result.fold = 1;
                }
            }
        } elif tz is not None {
            tzv: tzinfo = tz;
            result = tzv.fromutc(result);
        }
        return result;
    }

    static def fromtimestamp(t: float, tz: (tzinfo | None) = None) -> datetime {
        (frac, tf) = _modf(t);
        us: int = _round_half_even(frac * 1000000.0);
        if us >= 1000000 {
            tf += 1.0;
            us -= 1000000;
        } elif us < 0 {
            tf -= 1.0;
            us += 1000000;
        }
        if tf > 9.0e18 or tf < -9.0e18 {
            raise OverflowError("timestamp out of range for platform time_t");
        }
        return datetime._fromepoch(int(tf), us, tz is not None, tz);
    }

    static def utcfromtimestamp(t: float) -> datetime {
        (frac, tf) = _modf(t);
        us: int = _round_half_even(frac * 1000000.0);
        if us >= 1000000 {
            tf += 1.0;
            us -= 1000000;
        } elif us < 0 {
            tf -= 1.0;
            us += 1000000;
        }
        if tf > 9.0e18 or tf < -9.0e18 {
            raise OverflowError("timestamp out of range for platform time_t");
        }
        return datetime._fromepoch(int(tf), us, True, None);
    }

    static def now(tz: (tzinfo | None) = None) -> datetime {
        us_total: int = dt_epoch_us();
        return datetime._fromepoch(
            us_total // 1000000, us_total % 1000000, tz is not None, tz
        );
    }

    static def utcnow -> datetime {
        us_total: int = dt_epoch_us();
        return datetime._fromepoch(us_total // 1000000, us_total % 1000000, True, None);
    }

    static def combine(d: any, t: any, tzinfo: (tzinfo | None) = _TZ_KEEP) -> datetime {
        return _datetime_combine(d, t, tzinfo);
    }

    static def fromisoformat(date_string: str) -> datetime {
        if len(date_string) < 7 {
            raise ValueError(f"Invalid isoformat string: '{date_string}'");
        }
        dy: int = 0;
        dm: int = 0;
        dd: int = 0;
        sep: int = 0;
        b: bytes = date_string.encode();
        sep = _find_isoformat_datetime_separator(b);
        if sep >= 0 {
            (dy, dm, dd) = _parse_isoformat_date_range(b, 0, sep);
        }
        if sep < 0 or dy < 0 {
            raise ValueError(f"Invalid isoformat string: '{date_string}'");
        }
        tr: _IsoTimeResult = _IsoTimeResult();
        if sep + 1 < len(b) {
            tr = _parse_isoformat_time_at(b, sep + 1);
            if tr.invalid {
                raise ValueError(f"Invalid isoformat string: '{date_string}'");
            }
            if tr.error_from_components {
                raise ValueError(
                    "minute, second, and microsecond must be 0 when hour is 24"
                );
            }
            if tr.became_next_day {
                if dm >= 1 and dm <= 12 {
                    dim: int = _days_in_month(dy, dm);
                    if dd <= dim {
                        dd += 1;
                        if dd > dim {
                            dd = 1;
                            dm += 1;
                            if dm > 12 {
                                dm = 1;
                                dy += 1;
                            }
                        }
                    }
                }
            }
        }
        return datetime(
            dy, dm, dd, tr.hour, tr.minute, tr.second, tr.microsecond, tr.tzi
        );
    }

    static def strptime(date_string: str, format: str) -> datetime {
        r: _StrptimeResult = _strptime(date_string, format);
        return datetime(
            r.year, r.month, r.day, r.hour, r.minute, r.second, r.microsecond, r.tz
        );
    }

    static def fromordinal(n: int) -> datetime {
        if n < 1 {
            raise ValueError("ordinal must be >= 1");
        }
        (y, m, d) = _ord2ymd(n);
        return datetime(y, m, d);
    }

    static def fromisocalendar(year: int, week: int, day: int) -> datetime {
        (y, m, d) = _isoweek_to_gregorian(year, week, day);
        return datetime(y, m, d);
    }

    static def today -> datetime {
        return datetime.now(None);
    }

    def timetuple -> struct_time {
        d: (timedelta | None) = self.dst();
        dstflag: int = -1;
        if d is not None {
            dstflag = 1 if (d as timedelta) else 0;
        }
        return _build_struct_time(
            self.year,
            self.month,
            self.day,
            self.hour,
            self.minute,
            self.second,
            dstflag
        );
    }

    def _local_u(u: int) -> int {
        dt_localtime(u);
        return (_ymd2ord(dt_tm(5) + 1900, dt_tm(4) + 1, dt_tm(3)) - _EPOCHORDINAL)
            * 86400
            + dt_tm(2) * 3600
            + dt_tm(1) * 60
            + dt_tm(0);
    }

    def _mktime -> int {
        max_fold_seconds: int = 86400;
        t: int = (_ymd2ord(self.year, self.month, self.day) - _EPOCHORDINAL) * 86400
            + self.hour * 3600
            + self.minute * 60
            + self.second;
        a: int = self._local_u(t) - t;
        u1: int = t - a;
        t1: int = self._local_u(u1);
        b: int = 0;
        if t1 == t {
            u2a: int = u1 + (max_fold_seconds if self.fold != 0 else -max_fold_seconds);
            b = self._local_u(u2a) - u2a;
            if a == b {
                return u1;
            }
        } else {
            b = t1 - u1;
        }
        u2: int = t - b;
        t2: int = self._local_u(u2);
        if t2 == t {
            return u2;
        }
        if t1 == t {
            return u1;
        }
        if self.fold != 0 {
            return u1 if u1 < u2 else u2;
        }
        return u1 if u1 > u2 else u2;
    }

    def timestamp -> float {
        if self.tzinfo is None {
            s: int = self._mktime();
            return float(s) + float(self.microsecond) / 1000000.0;
        }
        return ((self - _EPOCH) as timedelta).total_seconds();
    }

    def utctimetuple -> struct_time {
        offset: (timedelta | None) = self.utcoffset();
        s2: datetime = self;
        if offset is not None {
            off: timedelta = offset;
            if off {
                s2 = (self - off) as datetime;
            }
        }
        return _build_struct_time(
            s2.year, s2.month, s2.day, s2.hour, s2.minute, s2.second, 0
        );
    }

    def date -> any {
        return _mk_date(self.year, self.month, self.day);
    }

    def time -> any {
        return _mk_time(
            self.hour, self.minute, self.second, self.microsecond, None, self.fold
        );
    }

    def timetz -> any {
        return _mk_time(
            self.hour,
            self.minute,
            self.second,
            self.microsecond,
            self.tzinfo,
            self.fold
        );
    }

    def replace(
        year: (int | None) = None,
        month: (int | None) = None,
        day: (int | None) = None,
        hour: (int | None) = None,
        minute: (int | None) = None,
        second: (int | None) = None,
        microsecond: (int | None) = None,
        tzinfo: (tzinfo | None) = _TZ_KEEP,
        fold: (int | None) = None
    ) -> datetime {
        y: int = self.year if year is None else year;
        mo: int = self.month if month is None else month;
        d: int = self.day if day is None else day;
        h: int = self.hour if hour is None else hour;
        mi: int = self.minute if minute is None else minute;
        s: int = self.second if second is None else second;
        us: int = self.microsecond if microsecond is None else microsecond;
        tz: (tzinfo | None) = self.tzinfo if tzinfo is _TZ_KEEP else tzinfo;
        f: int = self.fold if fold is None else fold;
        return datetime(y, mo, d, h, mi, s, us, tz, f);
    }

    def _local_timezone -> timezone {
        ts: int = 0;
        if self.tzinfo is None {
            ts = self._mktime();
            ts2: int = self.replace(fold=1 - self.fold)._mktime();
            if ts2 != ts {
                if (ts2 > ts) == (self.fold != 0) {
                    ts = ts2;
                }
            }
        } else {
            ts = (((self - _EPOCH) as timedelta) // timedelta(0, 1)) as int;
        }
        dt_localtime(ts);
        gmtoff: int = dt_tm_gmtoff();
        zone: str = dt_tm_zone();
        return timezone(timedelta(0, gmtoff), zone);
    }

    def astimezone(tz: (tzinfo | None) = None) -> datetime {
        tzv: tzinfo = self._local_timezone() if tz is None else tz;
        mytz: (tzinfo | None) = None;
        myoffset: (timedelta | None) = None;
        if self.tzinfo is None {
            mytz = self._local_timezone();
            myoffset = mytz.utcoffset(self);
        } else {
            mytz = self.tzinfo;
            myoffset = mytz.utcoffset(self);
            if myoffset is None {
                mytz = self.replace(tzinfo=None)._local_timezone();
                myoffset = mytz.utcoffset(self);
            }
        }
        if tzv is mytz {
            return self;
        }
        if myoffset is None {
            raise ValueError("astimezone() cannot determine UTC offset");
        }
        mo: timedelta = myoffset;
        utc: datetime = ((self - mo) as datetime).replace(tzinfo=tzv);
        return tzv.fromutc(utc);
    }

    def ctime -> str {
        weekday: int = self.toordinal() % 7;
        if weekday == 0 {
            weekday = 7;
        }
        ds: str = " " + str(self.day) if self.day < 10 else str(self.day);
        return _DAYNAMES[weekday]
            + " "
            + _MONTHNAMES[self.month]
            + " "
            + ds
            + " "
            + _pad2(self.hour)
            + ":"
            + _pad2(self.minute)
            + ":"
            + _pad2(self.second)
            + " "
            + _pad4(self.year);
    }

    def isoformat(sep: str = "T", timespec: str = "auto") -> str {
        if len(sep) > 512 {
            s: str = _pad4(self.year)
                + "-"
                + _pad2(self.month)
                + "-"
                + _pad2(self.day)
                + sep
                + _format_time(
                    self.hour, self.minute, self.second, self.microsecond, timespec
                );
            off: (timedelta | None) = self.utcoffset();
            tzs: str = _format_offset(off);
            if tzs != "" {
                s += tzs;
            }
            return s;
        }
        p: int = dt_out_buf();
        n: int = _w_date(p, self.year, self.month, self.day);
        n += _w_str(p + n, sep);
        n += _w_time(
            p + n, self.hour, self.minute, self.second, self.microsecond, timespec
        );
        n += _w_offset(p + n, self.utcoffset(), ":");
        return dt_out_str(n);
    }

    def __str__ -> str {
        return self.isoformat(" ");
    }

    def __repr__ -> str {
        r: str = "datetime.datetime("
            + str(self.year)
            + ", "
            + str(self.month)
            + ", "
            + str(self.day)
            + ", "
            + str(self.hour)
            + ", "
            + str(self.minute);
        if self.microsecond != 0 {
            r += ", " + str(self.second) + ", " + str(self.microsecond);
        } elif self.second != 0 {
            r += ", " + str(self.second);
        }
        r += ")";
        if self.tzinfo is not None {
            r = r[0:len(r) - 1] + ", tzinfo=" + _tz_repr(self.tzinfo) + ")";
        }
        if self.fold != 0 {
            r = r[0:len(r) - 1] + ", fold=1)";
        }
        return r;
    }

    def utcoffset -> (timedelta | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        offset: (timedelta | None) = tz.utcoffset(self);
        _check_utc_offset(offset);
        return offset;
    }

    def tzname -> (str | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        return tz.tzname(self);
    }

    def dst -> (timedelta | None) {
        tzv: (tzinfo | None) = self.tzinfo;
        if tzv is None {
            return None;
        }
        tz: tzinfo = tzv;
        offset: (timedelta | None) = tz.dst(self);
        _check_utc_offset(offset);
        return offset;
    }

    def _cmp(other: datetime, allow_mixed: bool) -> int {
        mytz: (tzinfo | None) = self.tzinfo;
        ottz: (tzinfo | None) = other.tzinfo;
        myoff: (timedelta | None) = None;
        otoff: (timedelta | None) = None;
        base_compare: bool = False;
        if mytz is ottz {
            base_compare = True;
        } else {
            myoff = self.utcoffset();
            otoff = other.utcoffset();
            if allow_mixed {
                if not _off_eq(myoff, self.replace(fold=1 - self.fold).utcoffset()) {
                    return 2;
                }
                if not _off_eq(otoff, other.replace(fold=1 - other.fold).utcoffset()) {
                    return 2;
                }
            }
            base_compare = _off_eq(myoff, otoff);
        }
        if base_compare {
            if self.year != other.year {
                return 1 if self.year > other.year else -1;
            }
            if self.month != other.month {
                return 1 if self.month > other.month else -1;
            }
            if self.day != other.day {
                return 1 if self.day > other.day else -1;
            }
            if self.hour != other.hour {
                return 1 if self.hour > other.hour else -1;
            }
            if self.minute != other.minute {
                return 1 if self.minute > other.minute else -1;
            }
            if self.second != other.second {
                return 1 if self.second > other.second else -1;
            }
            if self.microsecond != other.microsecond {
                return 1 if self.microsecond > other.microsecond else -1;
            }
            return 0;
        }
        if myoff is None or otoff is None {
            if allow_mixed {
                return 2;
            }
            raise TypeError("cannot compare naive and aware datetimes");
        }
        diff: timedelta = (self - other) as timedelta;
        if diff.days < 0 {
            return -1;
        }
        return 1 if diff else 0;
    }

    def __eq__(other: datetime) -> bool {
        return self._cmp(other, True) == 0;
    }

    def __ne__(other: datetime) -> bool {
        return self._cmp(other, True) != 0;
    }

    def __le__(other: datetime) -> bool {
        return self._cmp(other, False) <= 0;
    }

    def __lt__(other: datetime) -> bool {
        return self._cmp(other, False) < 0;
    }

    def __ge__(other: datetime) -> bool {
        return self._cmp(other, False) >= 0;
    }

    def __gt__(other: datetime) -> bool {
        return self._cmp(other, False) > 0;
    }

    def __add__(other: timedelta) -> datetime {
        us: int = self.microsecond + other.microseconds;
        sec: int = self.hour * 3600 + self.minute * 60 + self.second + other.seconds;
        ord2: int = self.toordinal() + other.days;
        if us < 0 or us > 999999 {
            q: int = us // 1000000;
            us -= q * 1000000;
            sec += q;
        }
        if sec < 0 or sec > 86399 {
            q2: int = sec // 86400;
            sec -= q2 * 86400;
            ord2 += q2;
        }
        if ord2 > 0 and ord2 <= _MAXORDINAL {
            (y, m, d) = _ord2ymd(ord2);
            return datetime(
                y, m, d, sec // 3600, (sec % 3600) // 60, sec % 60, us, self.tzinfo
            );
        }
        raise OverflowError("result out of range");
    }

    static def _from_ord_hms(
        ords: int, hour: int, minute: int, second: int, us: int, tz: (tzinfo | None)
    ) -> datetime {
        (y, m, d) = _ord2ymd(ords);
        return datetime(y, m, d, hour, minute, second, us, tz, 0);
    }

    def __radd__(other: timedelta) -> datetime {
        return self + other;
    }

    def __sub__(other: (timedelta | datetime)) -> (timedelta | datetime) {
        if isinstance(other, timedelta) {
            neg: timedelta = (other as timedelta).__neg__();
            return self + neg;
        }
        o2: datetime = other as datetime;
        days1: int = self.toordinal();
        days2: int = o2.toordinal();
        secs1: int = self.second + self.minute * 60 + self.hour * 3600;
        secs2: int = o2.second + o2.minute * 60 + o2.hour * 3600;
        base: timedelta = timedelta(
            days1 - days2, secs1 - secs2, self.microsecond - o2.microsecond
        );
        if self.tzinfo is o2.tzinfo {
            return base;
        }
        myoff: (timedelta | None) = self.utcoffset();
        otoff: (timedelta | None) = o2.utcoffset();
        if _off_eq(myoff, otoff) {
            return base;
        }
        if myoff is None or otoff is None {
            raise TypeError("cannot mix naive and timezone-aware time");
        }
        bo: timedelta = otoff;
        bm: timedelta = myoff;
        return ((base + bo) as timedelta) - bm;
    }

    def __format__(fmt: str) -> str {
        if len(fmt) != 0 {
            return self.strftime(fmt);
        }
        return str(self);
    }

    def strftime(format: str) -> str {
        dtd: (timedelta | None) = self.dst();
        dstflag: int = -1;
        if dtd is not None {
            dstflag = 1 if (dtd as timedelta) else 0;
        }
        return _wrap_strftime(
            self.microsecond,
            self.utcoffset(),
            self.tzname(),
            format,
            self.second,
            self.minute,
            self.hour,
            self.day,
            self.month,
            self.year,
            self.weekday(),
            _days_before_month(self.year, self.month) + self.day,
            dstflag
        );
    }

    static has min: datetime = datetime(1, 1, 1),
        max: datetime = datetime(9999, 12, 31, 23, 59, 59, 999999),
        resolution: timedelta = timedelta(0, 0, 1);
}


obj:pub timezone(tzinfo) {
    has _offset: timedelta = timedelta(0),
        _name: str = "",
        _named: bool = False;

    def init(offset: timedelta, name: (str | None) = None) {
        off: int = offset._to_microseconds();
        if off <= -86400000000 or off >= 86400000000 {
            raise ValueError(
                "offset must be a timedelta strictly between -timedelta(hours=24) and timedelta(hours=24), not "
                    + _td_repr(offset)
            );
        }
        self._offset = offset;
        if name is None {
            self._name = "";
            self._named = False;
        } else {
            self._name = name;
            self._named = True;
        }
    }

    def utcoffset(dt: (datetime | None)) -> (timedelta | None) {
        if dt is None or isinstance(dt, datetime) {
            return self._offset;
        }
        raise TypeError("utcoffset() argument must be a datetime instance or None");
    }

    def tzname(dt: (datetime | None)) -> (str | None) {
        if dt is None or isinstance(dt, datetime) {
            if not self._named {
                return self._name_from_offset(self._offset);
            }
            return self._name;
        }
        raise TypeError("tzname() argument must be a datetime instance or None");
    }

    def dst(dt: (datetime | None)) -> (timedelta | None) {
        if dt is None or isinstance(dt, datetime) {
            return None;
        }
        raise TypeError("dst() argument must be a datetime instance or None");
    }

    def fromutc(dt: datetime) -> datetime {
        if dt.tzinfo is not self {
            raise ValueError("fromutc: dt.tzinfo is not self");
        }
        return dt + self._offset;
    }

    def _name_from_offset(delta: timedelta) -> str {
        if not delta {
            return "UTC";
        }
        sign: str = "+";
        d: timedelta = delta;
        if d.__lt__(timedelta(0)) {
            sign = "-";
            d = d.__neg__();
        }
        hours: int = (d // timedelta(hours=1)) as int;
        rest: timedelta = d % timedelta(hours=1);
        minutes: int = (rest // timedelta(minutes=1)) as int;
        rest2: timedelta = rest % timedelta(minutes=1);
        seconds: int = rest2.seconds;
        microseconds: int = rest2.microseconds;
        if microseconds != 0 {
            return "UTC"
                + sign
                + _pad2(hours)
                + ":"
                + _pad2(minutes)
                + ":"
                + _pad2(seconds)
                + "."
                + _pad6(microseconds);
        }
        if seconds != 0 {
            return "UTC"
                + sign
                + _pad2(hours)
                + ":"
                + _pad2(minutes)
                + ":"
                + _pad2(seconds);
        }
        return "UTC" + sign + _pad2(hours) + ":" + _pad2(minutes);
    }

    def __eq__(other: timezone) -> bool {
        return self._offset == other._offset;
    }

    def __ne__(other: timezone) -> bool {
        return not (self._offset == other._offset);
    }

    def __str__ -> str {
        n: (str | None) = self.tzname(None);
        if n is None {
            return "";
        }
        return n;
    }

    def __repr__ -> str {
        if self is timezone.utc {
            return "datetime.timezone.utc";
        }
        if not self._named {
            return "datetime.timezone(" + _td_repr(self._offset) + ")";
        }
        return "datetime.timezone("
            + _td_repr(self._offset)
            + ", '"
            + self._name
            + "')";
    }

    static has utc: timezone = UTC,
        min: timezone = timezone(timedelta(-1, 3600)),
        max: timezone = timezone(timedelta(0, 86340));
}


glob:pub UTC: timezone = timezone(timedelta(0), "UTC");
glob _EPOCH: datetime = datetime(1970, 1, 1, tzinfo=UTC);


def _mk_date(y: int, m: int, d: int) -> date {
    return date(y, m, d);
}


def _datetime_combine(d: date, t: time, tzinfo: (tzinfo | None)) -> datetime {
    tz: (tzinfo | None) = t.tzinfo if tzinfo is _TZ_KEEP else tzinfo;
    return datetime(
        d.year, d.month, d.day, t.hour, t.minute, t.second, t.microsecond, tz, t.fold
    );
}


def _mk_time(h: int, mi: int, s: int, us: int, tz: (tzinfo | None), fold: int) -> time {
    return time(h, mi, s, us, tz, fold);
}

obj _StrptimeResult {
    has year: int = -1,
        month: int = 1,
        day: int = 1,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        weekday: int = -1,
        julian: int = -1,
        iso_year: int = -1,
        iso_week: int = -1,
        week_of_year: int = -1,
        week_of_year_start: int = -1,
        hour12: int = -1,
        ampm: int = -1,
        century: int = -1,
        y2: int = -1,
        tzname: str = "",
        gmtoff_seen: bool = False,
        gmtoff: int = 0,
        gmtoff_fraction: int = 0,
        tz_index: int = -1,
        tz: (tzinfo | None) = None;
}


def _is_ws(c: str) -> bool {
    return is_space(ord(c));
}


def _collapse_ws(s: str) -> str {
    out: str = "";
    in_ws: bool = False;
    i: int = 0;
    while i < len(s) {
        if _is_ws(s[i]) {
            in_ws = True;
        } else {
            if in_ws and out != "" {
                out += " ";
            }
            in_ws = False;
            out += s[i];
        }
        i += 1;
    }
    return out;
}


def _sp_nomatch(data: str, fmt: str) {
    raise ValueError("time data '" + data + "' does not match format '" + fmt + "'");
}


def _sp_num(
    data: str, pos: int, ndmax: int, minv: int, maxv: int, space_ok: bool
) -> tuple[(int, int)] {
    if pos >= len(data) {
        return (-1, pos);
    }
    if space_ok and data[pos] == " " {
        if pos + 1 < len(data) and _is_ascii_digit(data[pos + 1]) {
            dv: int = "0123456789".find(data[pos + 1]);
            if dv >= minv and dv <= maxv {
                return (dv, pos + 2);
            }
        }
        return (-1, pos);
    }
    nd: int = ndmax;
    while nd >= 1 {
        if pos + nd <= len(data) {
            ok: bool = True;
            v: int = 0;
            j: int = 0;
            while j < nd {
                if not _is_ascii_digit(data[pos + j]) {
                    ok = False;
                    break;
                }
                v = v * 10 + "0123456789".find(data[pos + j]);
                j += 1;
            }
            if ok and v >= minv and v <= maxv {
                return (v, pos + nd);
            }
        }
        nd -= 1;
    }
    return (-1, pos);
}


def _match_name(data: str, pos: int, names: list[str]) -> tuple[(int, int)] {
    best: int = -1;
    bestlen: int = 0;
    dlow: str = data.lower();
    i: int = 0;
    while i < len(names) {
        nm: str = names[i];
        ln: int = len(nm);
        if ln > bestlen and pos + ln <= len(data) and dlow[pos:pos + ln] == nm {
            best = i;
            bestlen = ln;
        }
        i += 1;
    }
    if best < 0 {
        return (-1, pos);
    }
    return (best, pos + bestlen);
}


def _calc_julian_from_U_or_W(
    year: int, week_of_year: int, day_of_week: int, week_starts_Mon: bool
) -> int {
    first_weekday: int = (_ymd2ord(year, 1, 1) + 6) % 7;
    dow: int = day_of_week;
    if not week_starts_Mon {
        first_weekday = (first_weekday + 1) % 7;
        dow = (dow + 1) % 7;
    }
    week_0_length: int = (7 - first_weekday) % 7;
    if week_of_year == 0 {
        return 1 + dow - first_weekday;
    }
    return 1 + week_0_length + 7 * (week_of_year - 1) + dow;
}


def _sp_directive(r: _StrptimeResult, data: str, pos_in: int, d: str, fmt: str) -> int {
    pos: int = pos_in;
    v: int = -1;
    np: int = pos;
    if d == "%" {
        if pos < len(data) and data[pos] == "%" {
            return pos + 1;
        }
        _sp_nomatch(data, fmt);
    }
    if d == "d" or d == "e" {
        (v, np) = _sp_num(data, pos, 2, 1, 31, True);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.day = v;
        return np;
    }
    if d == "f" {
        n: int = 0;
        vv: int = 0;
        while pos + n < len(data) and n < 6 and _is_ascii_digit(data[pos + n]) {
            vv = vv * 10 + "0123456789".find(data[pos + n]);
            n += 1;
        }
        if n == 0 {
            _sp_nomatch(data, fmt);
        }
        consumed: int = n;
        while n < 6 {
            vv *= 10;
            n += 1;
        }
        r.microsecond = vv;
        return pos + consumed;
    }
    if d == "H" or d == "k" {
        (v, np) = _sp_num(data, pos, 2, 0, 23, True);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.hour = v;
        return np;
    }
    if d == "I" or d == "l" {
        (v, np) = _sp_num(data, pos, 2, 1, 12, True);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.hour12 = v;
        return np;
    }
    if d == "j" {
        (v, np) = _sp_num(data, pos, 3, 1, 366, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.julian = v;
        return np;
    }
    if d == "m" {
        (v, np) = _sp_num(data, pos, 2, 1, 12, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.month = v;
        return np;
    }
    if d == "M" {
        (v, np) = _sp_num(data, pos, 2, 0, 59, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.minute = v;
        return np;
    }
    if d == "S" {
        (v, np) = _sp_num(data, pos, 2, 0, 61, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.second = v;
        return np;
    }
    if d == "U" or d == "W" {
        (v, np) = _sp_num(data, pos, 2, 0, 53, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.week_of_year = v;
        r.week_of_year_start = 6 if d == "U" else 0;
        return np;
    }
    if d == "V" {
        (v, np) = _sp_num(data, pos, 2, 0, 53, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.iso_week = v;
        return np;
    }
    if d == "w" {
        (v, np) = _sp_num(data, pos, 1, 0, 6, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.weekday = 6 if v == 0 else v - 1;
        return np;
    }
    if d == "u" {
        (v, np) = _sp_num(data, pos, 1, 1, 7, False);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.weekday = v - 1;
        return np;
    }
    if d == "y" {
        (v, np) = _sp_num(data, pos, 2, 0, 99, False);
        if v < 0 or np - pos != 2 {
            _sp_nomatch(data, fmt);
        }
        r.y2 = v;
        return np;
    }
    if d == "Y" {
        (v, np) = _sp_num(data, pos, 4, 0, 9999, False);
        if v < 0 or np - pos != 4 {
            _sp_nomatch(data, fmt);
        }
        r.year = v;
        return np;
    }
    if d == "G" {
        (v, np) = _sp_num(data, pos, 4, 0, 9999, False);
        if v < 0 or np - pos != 4 {
            _sp_nomatch(data, fmt);
        }
        r.iso_year = v;
        return np;
    }
    if d == "C" {
        (v, np) = _sp_num(data, pos, 2, 0, 99, True);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.century = v;
        return np;
    }
    if d == "p" {
        (v, np) = _match_name(data, pos, ["am", "pm"]);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.ampm = v;
        return np;
    }
    if d == "A" {
        (v, np) = _match_name(
            data,
            pos,
            [
                "monday",
                "tuesday",
                "wednesday",
                "thursday",
                "friday",
                "saturday",
                "sunday"
            ]
        );
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.weekday = v;
        return np;
    }
    if d == "a" {
        (v, np) = _match_name(
            data, pos, ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        );
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.weekday = v;
        return np;
    }
    if d == "B" {
        (v, np) = _match_name(
            data,
            pos,
            [
                "",
                "january",
                "february",
                "march",
                "april",
                "may",
                "june",
                "july",
                "august",
                "september",
                "october",
                "november",
                "december"
            ]
        );
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.month = v;
        return np;
    }
    if d == "b" or d == "h" {
        (v, np) = _match_name(
            data,
            pos,
            [
                "",
                "jan",
                "feb",
                "mar",
                "apr",
                "may",
                "jun",
                "jul",
                "aug",
                "sep",
                "oct",
                "nov",
                "dec"
            ]
        );
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.month = v;
        return np;
    }
    if d == "Z" {
        zn: str = dt_tm_zone();
        (v, np) = _match_name(data, pos, ["gmt", "utc", zn.lower(), zn.lower()]);
        if v < 0 {
            _sp_nomatch(data, fmt);
        }
        r.tzname = data[pos:np];
        r.tz_index = 0 if v <= 1 else v - 1;
        return np;
    }
    if d == "z" {
        if pos < len(data) and data[pos] == "Z" {
            r.gmtoff = 0;
            r.gmtoff_seen = True;
            return pos + 1;
        }
        if pos + 5 > len(data) {
            _sp_nomatch(data, fmt);
        }
        sign_c: str = data[pos];
        if sign_c != "+" and sign_c != "-" {
            _sp_nomatch(data, fmt);
        }
        (v, np) = _sp_num(data, pos + 1, 2, 0, 99, False);
        if v < 0 or np - pos - 1 != 2 {
            _sp_nomatch(data, fmt);
        }
        zhh: int = v;
        zp: int = np;
        colon1: bool = False;
        if zp < len(data) and data[zp] == ":" {
            colon1 = True;
            zp += 1;
        }
        (v, np) = _sp_num(data, zp, 2, 0, 59, False);
        if v < 0 or np - zp != 2 {
            _sp_nomatch(data, fmt);
        }
        zmm: int = v;
        zp = np;
        zss: int = 0;
        zfrac: int = 0;
        if zp < len(data) and data[zp] == ":" {
            if not colon1 {
                raise ValueError("Inconsistent use of : in " + data[pos:pos + 12]);
            }
            zp += 1;
            (v, np) = _sp_num(data, zp, 2, 0, 59, False);
            if v < 0 or np - zp != 2 {
                _sp_nomatch(data, fmt);
            }
            zss = v;
            zp = np;
            if zp < len(data) and data[zp] == "." {
                zp += 1;
                fn: int = 0;
                while zp + fn < len(data)
                    and fn < 6
                    and _is_ascii_digit(data[zp + fn]) {
                    zfrac = zfrac * 10 + "0123456789".find(data[zp + fn]);
                    fn += 1;
                }
                if fn == 0 {
                    _sp_nomatch(data, fmt);
                }
                fconsumed: int = fn;
                while fn < 6 {
                    zfrac *= 10;
                    fn += 1;
                }
                zp += fconsumed;
            }
        } elif zp + 2 <= len(data)
            and _is_ascii_digit(data[zp])
            and _is_ascii_digit(data[zp + 1])
            and "0123456789".find(data[zp]) <= 5 {
            (v, np) = _sp_num(data, zp, 2, 0, 59, False);
            if v >= 0 and np - zp == 2 {
                zss = v;
                zp = np;
            }
        }
        off: int = zhh * 3600 + zmm * 60 + zss;
        if sign_c == "-" {
            off = -off;
            zfrac = -zfrac;
        }
        r.gmtoff = off;
        r.gmtoff_fraction = zfrac;
        r.gmtoff_seen = True;
        return zp;
    }
    raise ValueError("'%" + d + "' is a bad directive in format '" + fmt + "'");
}


def _sp_walk(r: _StrptimeResult, data: str, fmt: str, pos_in: int) -> int {
    pos: int = pos_in;
    i: int = 0;
    n: int = len(fmt);
    while i < n {
        c: str = fmt[i];
        if c == "%" {
            i += 1;
            while i < n
                and (
                    fmt[i] == "-"
                    or fmt[i] == "_"
                    or fmt[i] == "0"
                    or fmt[i] == "^"
                    or fmt[i] == "#"
                ) {
                i += 1;
            }
            while i < n and _is_ascii_digit(fmt[i]) {
                i += 1;
            }
            if i >= n {
                raise ValueError("stray % in format '" + fmt + "'");
            }
            d: str = fmt[i];
            i += 1;
            if d == "O" or d == "E" {
                if i >= n {
                    raise ValueError("stray % in format '" + fmt + "'");
                }
                dd: str = fmt[i];
                i += 1;
                if not (
                    dd == "d"
                    or dd == "m"
                    or dd == "y"
                    or dd == "C"
                    or dd == "H"
                    or dd == "I"
                    or dd == "M"
                    or dd == "S"
                    or dd == "w"
                ) {
                    raise ValueError(
                        "'%" + d + dd + "' is a bad directive in format '" + fmt + "'"
                    );
                }
                d = dd;
            }
            if d == "c" {
                pos = _sp_walk(r, data, "%a %b %d %H:%M:%S %Y", pos);
            } elif d == "x" {
                pos = _sp_walk(r, data, "%m/%d/%y", pos);
            } elif d == "X" {
                pos = _sp_walk(r, data, "%H:%M:%S", pos);
            } elif d == "n" or d == "t" {
                if pos < len(data) and _is_ws(data[pos]) {
                    while pos < len(data) and _is_ws(data[pos]) {
                        pos += 1;
                    }
                } elif pos >= len(data) {} else {
                    _sp_nomatch(data, fmt);
                }
            } else {
                pos = _sp_directive(r, data, pos, d, fmt);
            }
        } elif _is_ws(c) {
            while i < n and _is_ws(fmt[i]) {
                i += 1;
            }
            if pos >= len(data) or not _is_ws(data[pos]) {
                _sp_nomatch(data, fmt);
            }
            while pos < len(data) and _is_ws(data[pos]) {
                pos += 1;
            }
        } else {
            if pos >= len(data) or data[pos] != c {
                _sp_nomatch(data, fmt);
            }
            pos += 1;
            i += 1;
        }
    }
    return pos;
}


def _strptime(data_string: str, format: str) -> _StrptimeResult {
    r: _StrptimeResult = _StrptimeResult();
    data: str = _collapse_ws(data_string);
    pos: int = _sp_walk(r, data, format, 0);
    if pos != len(data) {
        raise ValueError("unconverted data remains: " + data[pos:]);
    }
    year: int = r.year;
    if r.y2 >= 0 {
        year = r.y2;
        if r.century >= 0 {
            year += r.century * 100;
        } else {
            year += 2000 if year <= 68 else 1900;
        }
    }
    if r.hour12 >= 0 {
        hour: int = r.hour12;
        if r.ampm <= 0 {
            if hour == 12 {
                hour = 0;
            }
        } elif hour != 12 {
            hour += 12;
        }
        r.hour = hour;
    }
    weekday: int = r.weekday;
    julian: int = r.julian;
    iso_year: int = r.iso_year;
    iso_week: int = r.iso_week;
    if iso_year >= 0 {
        if julian >= 0 {
            raise ValueError(
                "Day of the year directive '%j' is not compatible with ISO year directive '%G'. Use '%Y' instead."
            );
        } elif iso_week < 0 or weekday < 0 {
            raise ValueError(
                "ISO year directive '%G' must be used with the ISO week directive '%V' and a weekday directive ('%A', '%a', '%w', or '%u')."
            );
        }
    } elif iso_week >= 0 {
        if year < 0 or weekday < 0 {
            raise ValueError(
                "ISO week directive '%V' must be used with the ISO year directive '%G' and a weekday directive ('%A', '%a', '%w', or '%u')."
            );
        }
        raise ValueError(
            "ISO week directive '%V' is incompatible with the year directive '%Y'. Use the ISO year '%G' instead."
        );
    }
    leap_year_fix: bool = False;
    if year < 0 {
        if r.month == 2 and r.day == 29 {
            year = 1904;
            leap_year_fix = True;
        } else {
            year = 1900;
        }
    }
    if julian < 0 and weekday >= 0 {
        if r.week_of_year >= 0 {
            julian = _calc_julian_from_U_or_W(
                year, r.week_of_year, weekday, r.week_of_year_start == 0
            );
        } elif iso_year >= 0 and iso_week >= 0 {
            (iy, im, idd) = _isoweek_to_gregorian(iso_year, iso_week, weekday + 1);
            year = iy;
            r.month = im;
            r.day = idd;
        }
        if julian >= 0 and julian <= 0 {
            year -= 1;
            julian += 366 if _is_leap(year) else 365;
        }
    }
    if julian < 0 {
        julian = _days_before_month(year, r.month) + r.day;
    } else {
        (yy, mm2, dd2) = _ord2ymd(julian - 1 + _ymd2ord(year, 1, 1));
        year = yy;
        r.month = mm2;
        r.day = dd2;
    }
    if leap_year_fix {
        year = 1900;
    }
    r.year = year;
    if r.gmtoff_seen {
        tzd: timedelta = timedelta(0, r.gmtoff, r.gmtoff_fraction);
        if r.tzname != "" {
            r.tz = timezone(tzd, r.tzname);
        } else {
            r.tz = timezone(tzd);
        }
    }
    return r;
}
