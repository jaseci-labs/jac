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


def _iabs(x: int) -> int;


def _is_leap(year: int) -> bool;


def _days_before_year(year: int) -> int;


def _days_in_month(year: int, month: int) -> int;


def _days_before_month(year: int, month: int) -> int;


def _ymd2ord(year: int, month: int, day: int) -> int;


def _ord2ymd(n_in: int) -> tuple[(int, int, int)];


def _isoweek1monday(year: int) -> int;


def _isoweek_to_gregorian(year: int, week: int, day: int) -> tuple[(int, int, int)];


def _modf(x: float) -> tuple[(float, float)];


def _floorf(x: float) -> float;


def _round_half_even(x: float) -> int;


def _float_ratio(x: float) -> tuple[(int, int)];


def _divide_and_round(a: int, b: int) -> int;


def _build_d2 -> list[str];


glob _D2: list[str] = _build_d2();


def _pad2(n: int) -> str;


def _pad4(n: int) -> str;


def _pad6(n: int) -> str;


def _wb(p: int, v: int);


def _w2(p: int, n: int);


def _w3(p: int, n: int);


def _w4(p: int, n: int);


def _w6(p: int, n: int);


def _w_uint(p: int, n: int) -> int;


def _w_int(p: int, n: int) -> int;


def _w_bytes(p: int, b: bytes) -> int;


def _w_str(p: int, s: str) -> int;


def _w_copy(p: int, src: int, n: int) -> int;


def _w_date(p: int, y: int, m: int, d: int) -> int;


def _w_time(p: int, hh: int, mm: int, ss: int, us: int, timespec: str) -> int;


def _w_offset(p: int, off: (timedelta | None), sep: str) -> int;


def _check_date_fields(year: int, month: int, day: int);


def _check_time_fields(
    hour: int, minute: int, second: int, microsecond: int, fold: int
);


def _format_offset(off: (timedelta | None), sep: str = ":") -> str;


def _format_time(hh: int, mm: int, ss: int, us: int, timespec: str = "auto") -> str;


def _td_repr(td: timedelta) -> str;


def _tz_repr(tz: (tzinfo | None)) -> str;


def _off_eq(a: (timedelta | None), b: (timedelta | None)) -> bool;


def _check_utc_offset(offset: (timedelta | None));


def _build_struct_time(
    y: int, m: int, d: int, hh: int, mm: int, ss: int, dstflag: int
) -> struct_time;


def _localtime(t: int) -> struct_time;


def _gmtime(t: int) -> struct_time;


glob _NNC: int = -1;


def _need_normalize_century -> bool;


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
) -> str;


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
) -> str;


def _is_ascii_digit(c: str) -> bool;


def _dig2(s: bytes, p: int) -> int;


def _dig4(s: bytes, p: int) -> int;


def _atoi(s: str) -> int;


def _find_isoformat_datetime_separator(dtstr: bytes) -> int;


def _parse_isoformat_date(dtstr: str) -> tuple[(int, int, int)];


def _parse_isoformat_date_range(s: bytes, lo: int, hi: int) -> tuple[(int, int, int)];


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


def _parse_hh_mm_ss_ff(tstr: bytes, pos: int, end: int, res: _IsoTimeResult);


def _parse_isoformat_time(tstr: str) -> _IsoTimeResult;


def _parse_isoformat_time_at(s: bytes, lo: int) -> _IsoTimeResult;


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
    );

    def _to_microseconds -> int;
    def __repr__ -> str;
    def __str__ -> str;
    def __format__(fmt: str) -> str;
    def total_seconds -> float;
    def __add__(other: (timedelta | date)) -> (timedelta | date);
    def __radd__(other: (timedelta | date)) -> (timedelta | date);
    def __sub__(other: timedelta) -> timedelta;
    def __rsub__(other: (timedelta | date)) -> (timedelta | date);
    def __neg__ -> timedelta;
    def __pos__ -> timedelta;
    def __abs__ -> timedelta;
    def __mul__(other: (int | float)) -> timedelta;
    def __rmul__(other: (int | float)) -> timedelta;
    def __floordiv__(other: (int | timedelta)) -> (timedelta | int);
    def __truediv__(other: (int | float | timedelta)) -> (timedelta | float);
    def __mod__(other: timedelta) -> timedelta;
    def __divmod__(other: timedelta) -> tuple[(int, timedelta)];
    def _cmp(other: timedelta) -> int;
    def __eq__(other: timedelta) -> bool;
    def __ne__(other: timedelta) -> bool;
    def __le__(other: timedelta) -> bool;
    def __lt__(other: timedelta) -> bool;
    def __ge__(other: timedelta) -> bool;
    def __gt__(other: timedelta) -> bool;
    def __bool__ -> bool;

    static has min: timedelta = timedelta(-999999999),
        max: timedelta = timedelta(999999999, 86399, 999999),
        resolution: timedelta = timedelta(0, 0, 1);
}


def _fabs(x: float) -> float;


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

    def __getitem__(i: int) -> int;
    def __len__ -> int;
    def __repr__ -> str;
}


obj IsoCalendarDate {
    has year: int = 0,
        week: int = 0,
        weekday: int = 0;

    def __getitem__(i: int) -> int;
    def __len__ -> int;
    def __repr__ -> str;
}


obj:pub date {
    has year: int = 0,
        month: int = 0,
        day: int = 0;

    def init(year: int, month: int, day: int);
    static def fromtimestamp(t: float) -> date;
    static def today -> date;
    static def fromordinal(n: int) -> date;
    static def fromisoformat(date_string: str) -> date;
    static def fromisocalendar(year: int, week: int, day: int) -> date;
    static def strptime(date_string: str, format: str) -> date;
    def timetuple -> struct_time;
    def toordinal -> int;
    def replace(
        year: (int | None) = None, month: (int | None) = None, day: (int | None) = None
    ) -> date;

    def __eq__(other: date) -> bool;
    def __ne__(other: date) -> bool;
    def __le__(other: date) -> bool;
    def __lt__(other: date) -> bool;
    def __ge__(other: date) -> bool;
    def __gt__(other: date) -> bool;
    def _cmp(other: date) -> int;
    def __add__(other: timedelta) -> date;
    def __radd__(other: timedelta) -> date;
    def __sub__(other: (timedelta | date)) -> (timedelta | date);
    def weekday -> int;
    def isoweekday -> int;
    def isocalendar -> IsoCalendarDate;
    def ctime -> str;
    def strftime(format: str) -> str;
    def __format__(fmt: str) -> str;
    def isoformat -> str;
    def __str__ -> str;
    def __repr__ -> str;

    static has min: date = date(1, 1, 1),
        max: date = date(9999, 12, 31),
        resolution: timedelta = timedelta(1);
}


obj:pub tzinfo {
    def tzname(dt: (datetime | None)) -> (str | None);
    def utcoffset(dt: (datetime | None)) -> (timedelta | None);
    def dst(dt: (datetime | None)) -> (timedelta | None);
    def fromutc(dt: datetime) -> datetime;
    def __repr__ -> str;
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
    );

    static def fromisoformat(time_string: str) -> time;
    static def strptime(date_string: str, format: str) -> time;
    def _tzstr -> str;
    def utcoffset -> (timedelta | None);
    def tzname -> (str | None);
    def dst -> (timedelta | None);
    def replace(
        hour: (int | None) = None,
        minute: (int | None) = None,
        second: (int | None) = None,
        microsecond: (int | None) = None,
        tzinfo: (tzinfo | None) = _TZ_KEEP,
        fold: (int | None) = None
    ) -> time;

    def isoformat(timespec: str = "auto") -> str;
    def __str__ -> str;
    def strftime(format: str) -> str;
    def __format__(fmt: str) -> str;
    def __repr__ -> str;
    def _cmp(other: time, allow_mixed: bool) -> int;
    def __eq__(other: time) -> bool;
    def __ne__(other: time) -> bool;
    def __le__(other: time) -> bool;
    def __lt__(other: time) -> bool;
    def __ge__(other: time) -> bool;
    def __gt__(other: time) -> bool;

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
    );

    static def _fromepoch(
        sec: int, us: int, utc: bool, tz: (tzinfo | None)
    ) -> datetime;

    static def fromtimestamp(t: float, tz: (tzinfo | None) = None) -> datetime;
    static def utcfromtimestamp(t: float) -> datetime;
    static def now(tz: (tzinfo | None) = None) -> datetime;
    static def utcnow -> datetime;
    static def combine(d: any, t: any, tzinfo: (tzinfo | None) = _TZ_KEEP) -> datetime;
    static def fromisoformat(date_string: str) -> datetime;
    static def strptime(date_string: str, format: str) -> datetime;
    static def fromordinal(n: int) -> datetime;
    static def fromisocalendar(year: int, week: int, day: int) -> datetime;
    static def today -> datetime;
    def timetuple -> struct_time;
    def _local_u(u: int) -> int;
    def _mktime -> int;
    def timestamp -> float;
    def utctimetuple -> struct_time;
    def date -> any;
    def time -> any;
    def timetz -> any;
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
    ) -> datetime;

    def _local_timezone -> timezone;
    def astimezone(tz: (tzinfo | None) = None) -> datetime;
    def ctime -> str;
    def isoformat(sep: str = "T", timespec: str = "auto") -> str;
    def __str__ -> str;
    def __repr__ -> str;
    def utcoffset -> (timedelta | None);
    def tzname -> (str | None);
    def dst -> (timedelta | None);
    def _cmp(other: datetime, allow_mixed: bool) -> int;
    def __eq__(other: datetime) -> bool;
    def __ne__(other: datetime) -> bool;
    def __le__(other: datetime) -> bool;
    def __lt__(other: datetime) -> bool;
    def __ge__(other: datetime) -> bool;
    def __gt__(other: datetime) -> bool;
    def __add__(other: timedelta) -> datetime;
    static def _from_ord_hms(
        ords: int, hour: int, minute: int, second: int, us: int, tz: (tzinfo | None)
    ) -> datetime;

    def __radd__(other: timedelta) -> datetime;
    def __sub__(other: (timedelta | datetime)) -> (timedelta | datetime);
    def __format__(fmt: str) -> str;
    def strftime(format: str) -> str;

    static has min: datetime = datetime(1, 1, 1),
        max: datetime = datetime(9999, 12, 31, 23, 59, 59, 999999),
        resolution: timedelta = timedelta(0, 0, 1);
}


obj:pub timezone(tzinfo) {
    has _offset: timedelta = timedelta(0),
        _name: str = "",
        _named: bool = False;

    def init(offset: timedelta, name: (str | None) = None);
    def utcoffset(dt: (datetime | None)) -> (timedelta | None);
    def tzname(dt: (datetime | None)) -> (str | None);
    def dst(dt: (datetime | None)) -> (timedelta | None);
    def fromutc(dt: datetime) -> datetime;
    def _name_from_offset(delta: timedelta) -> str;
    def __eq__(other: timezone) -> bool;
    def __ne__(other: timezone) -> bool;
    def __str__ -> str;
    def __repr__ -> str;

    static has utc: timezone = UTC,
        min: timezone = timezone(timedelta(-1, 3600)),
        max: timezone = timezone(timedelta(0, 86340));
}


glob:pub UTC: timezone = timezone(timedelta(0), "UTC");
glob _EPOCH: datetime = datetime(1970, 1, 1, tzinfo=UTC);


def _mk_date(y: int, m: int, d: int) -> date;


def _datetime_combine(d: date, t: time, tzinfo: (tzinfo | None)) -> datetime;


def _mk_time(h: int, mi: int, s: int, us: int, tz: (tzinfo | None), fold: int) -> time;

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


def _is_ws(c: str) -> bool;


def _collapse_ws(s: str) -> str;


def _sp_nomatch(data: str, fmt: str);


def _sp_num(
    data: str, pos: int, ndmax: int, minv: int, maxv: int, space_ok: bool
) -> tuple[(int, int)];


def _match_name(data: str, pos: int, names: list[str]) -> tuple[(int, int)];


def _calc_julian_from_U_or_W(
    year: int, week_of_year: int, day_of_week: int, week_starts_Mon: bool
) -> int;


def _sp_directive(r: _StrptimeResult, data: str, pos_in: int, d: str, fmt: str) -> int;


def _sp_walk(r: _StrptimeResult, data: str, fmt: str, pos_in: int) -> int;


def _strptime(data_string: str, format: str) -> _StrptimeResult;
