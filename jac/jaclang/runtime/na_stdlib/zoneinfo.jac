import from datetime { datetime, timedelta, tzinfo }
import from os.path { normpath }

glob _DEFAULT_TZPATH: list[str] = [
         "/usr/share/zoneinfo",
         "/usr/lib/zoneinfo",
         "/usr/share/lib/zoneinfo",
         "/etc/zoneinfo"
     ];
glob:pub TZPATH: list[str] = _DEFAULT_TZPATH[:];

glob _EPOCHORDINAL: int = 719163;


obj:pub ZoneInfoNotFoundError(KeyError) {
    has key: str = "";

    def init(key: str);
    def __str__ -> str;
}


def _be_u8(b: bytes, off: int) -> int;


def _be_i32(b: bytes, off: int) -> int;


def _be_u32(b: bytes, off: int) -> int;


def _be_i64(b: bytes, off: int) -> int;


obj _ttinfo {
    has utcoff: (timedelta | None) = None,
        dstoff: (timedelta | None) = None,
        tzname: (str | None) = None;

    def init(
        utcoff: (timedelta | None) = None,
        dstoff: (timedelta | None) = None,
        tzname: (str | None) = None
    );

    def __eq__(other: _ttinfo) -> bool;
}


def _tti_field_eq(a: (timedelta | None), b: (timedelta | None)) -> bool;


def _tti_str_eq(a: (str | None), b: (str | None)) -> bool;


glob _NO_TTINFO: _ttinfo = _ttinfo();


def _td_seconds(td: timedelta) -> int;


def _post_epoch_days_before_year(year: int) -> int;


def _zi_isleap(year: int) -> bool;


glob _ZI_DAYS_BEFORE_MONTH: list[int] = [
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
     _ZI_MDAYS: list[int] = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];


obj _TransOffset {
    has d: int = 0,
        julian: bool = False,
        m: int = 0,
        w: int = 0,
        hour: int = 2,
        minute: int = 0,
        second: int = 0;

    def year_to_epoch(year: int) -> int;
}


obj _TZStr {
    has std: _ttinfo = _ttinfo(),
        dst: _ttinfo = _ttinfo(),
        start: _TransOffset = _TransOffset(),
        end: _TransOffset = _TransOffset(),
        dst_diff: int = 0;

    def transitions(year: int) -> tuple[(int, int)];
    def get_trans_info(ts: int, year: int, fold: int) -> _ttinfo;
    def get_trans_info_fromutc(ts: int, year: int) -> tuple[(_ttinfo, int)];
}


def _zi_bisect_right(a: list[int], x: int) -> int;


obj _ZoneData {
    has file_path: str = "",
        trans_utc: list[int] = [],
        trans_local: list[list[int]] = [],
        ttinfos: list[_ttinfo] = [],
        tti_before: (_ttinfo | None) = None,
        tz_after: _ttinfo = _ttinfo(),
        tz_str: (_TZStr | None) = None,
        fixed_offset: bool = False;
}

glob _EMPTY_ZONE_DATA: _ZoneData = _ZoneData();


obj:pub ZoneInfo(tzinfo) {
    has key: (str | None) = None,
        _data: _ZoneData = _EMPTY_ZONE_DATA;

    def init(key: str = "", _raw: bool = False);
    static def no_cache(key: str) -> ZoneInfo;
    static def from_file(data: bytes, key: (str | None) = None) -> ZoneInfo;
    static def clear_cache;
    def utcoffset(dt: (datetime | None)) -> (timedelta | None);
    def dst(dt: (datetime | None)) -> (timedelta | None);
    def tzname(dt: (datetime | None)) -> (str | None);
    def fromutc(dt: datetime) -> datetime;
    def _find_trans(dt: (datetime | None)) -> _ttinfo;
    def _get_local_timestamp(dt: datetime) -> int;
    def __str__ -> str;
    def __repr__ -> str;
}


def _zone_data_for_key(key: str) -> _ZoneData;


def _build_zone_data(parsed: _TzifData, file_path: str) -> _ZoneData;


obj _TzifData {
    has trans_idx: list[int] = [],
        trans_utc: list[int] = [],
        utcoff: list[int] = [],
        isdst: list[int] = [],
        abbr: list[str] = [],
        tz_str: str = "";
}


def _parse_tzif(data: bytes) -> _TzifData;


def _validate_tzfile_path(path: str);


def _find_tzfile(key: str) -> tuple[(str, (bytes | None))];


glob _zone_cache: dict[str, ZoneInfo] = {};


def _zone_cache_get(key: str) -> (ZoneInfo | None);


def _zone_cache_put(key: str, z: ZoneInfo);


def:pub reset_tzpath(to: (list[str] | None) = None);


def:pub available_timezones -> list[str];


def _walk_tzdir(tzroot: str, prefix: str, zones: list[str]);


def _parse_transition_time(ts: str) -> tuple[(int, int, int)];


def _sp_zd(s: str, pos: int, maxn: int) -> tuple[(int, int)];


def _parse_tz_delta(td: str) -> int;


def _zi_abbr_end(s: str, pos: int) -> int;


def _zi_strip_abbr(s: str) -> str;


def _zi_off_end(s: str, pos: int) -> int;


def _parse_dst_start_end(dststr: str) -> _TransOffset;


def _atoi_zi(s: str) -> int;


def _parse_tz_str(tz_str: str) -> tuple[(_ttinfo, (_TZStr | None))];
