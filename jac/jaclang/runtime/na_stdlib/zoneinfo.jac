import from datetime { datetime, timedelta, tzinfo, _MAXORDINAL, _ord2ymd }
import from os.path { normpath }
import from _file_native { read_file_bytes }
import from _directory_native { try_directory_names }

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

    def init(key: str) {
        self.key = key;
    }

    def __str__ -> str {
        return "'" + self.key + "'";
    }
}


def _be_u8(b: bytes, off: int) -> int {
    return b[off];
}


def _be_i32(b: bytes, off: int) -> int {
    v: int = (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];
    if v >= 2147483648 {
        v -= 4294967296;
    }
    return v;
}


def _be_u32(b: bytes, off: int) -> int {
    return ((b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3]);
}


def _be_i64(b: bytes, off: int) -> int {
    v: int = 0;
    i: int = 0;
    while i < 8 {
        v = (v << 8) | b[off + i];
        i += 1;
    }
    if v > 9223372036854775807 {
        v -= 18446744073709551616;
    }
    return v;
}


obj _ttinfo {
    has utcoff: (timedelta | None) = None,
        dstoff: (timedelta | None) = None,
        tzname: (str | None) = None;

    def init(
        utcoff: (timedelta | None) = None,
        dstoff: (timedelta | None) = None,
        tzname: (str | None) = None
    ) {
        self.utcoff = utcoff;
        self.dstoff = dstoff;
        self.tzname = tzname;
    }

    def __eq__(other: _ttinfo) -> bool {
        if not _tti_field_eq(self.utcoff, other.utcoff) {
            return False;
        }
        if not _tti_field_eq(self.dstoff, other.dstoff) {
            return False;
        }
        return _tti_str_eq(self.tzname, other.tzname);
    }
}


def _tti_field_eq(a: (timedelta | None), b: (timedelta | None)) -> bool {
    if a is None and b is None {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    return (a as timedelta) == (b as timedelta);
}


def _tti_str_eq(a: (str | None), b: (str | None)) -> bool {
    if a is None and b is None {
        return True;
    }
    if a is None or b is None {
        return False;
    }
    return (a as str) == (b as str);
}


glob _NO_TTINFO: _ttinfo = _ttinfo();


def _td_seconds(td: timedelta) -> int {
    return td.days * 86400 + td.seconds;
}


def _post_epoch_days_before_year(year: int) -> int {
    y: int = year - 1;
    return y * 365 + y // 4 - y // 100 + y // 400 - _EPOCHORDINAL;
}


def _zi_isleap(year: int) -> bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}


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

    def year_to_epoch(year: int) -> int {
        if self.m == 0 {
            d: int = self.d;
            if self.julian and d >= 59 and _zi_isleap(year) {
                d += 1;
            }
            epoch: int = (_post_epoch_days_before_year(year) + d) * 86400;
            epoch += self.hour * 3600 + self.minute * 60 + self.second;
            return epoch;
        }
        first_day: int = (
            _post_epoch_days_before_year(year)
            + _ZI_DAYS_BEFORE_MONTH[self.m]
            + (1 if self.m > 2 and _zi_isleap(year) else 0)
            + 1
            + 6
        )
            % 7;
        days_in_month: int = _ZI_MDAYS[self.m]
            + (1 if self.m == 2 and _zi_isleap(year) else 0);
        month_day: int = (self.d - (first_day + 1)) % 7 + 1;
        month_day += (self.w - 1) * 7;
        if month_day > days_in_month {
            month_day -= 7;
        }
        ordinal: int = _post_epoch_days_before_year(year)
            + _ZI_DAYS_BEFORE_MONTH[self.m]
            + (1 if self.m > 2 and _zi_isleap(year) else 0)
            + month_day;
        epoch2: int = ordinal * 86400;
        epoch2 += self.hour * 3600 + self.minute * 60 + self.second;
        return epoch2;
    }
}


obj _TZStr {
    has std: _ttinfo = _ttinfo(),
        dst: _ttinfo = _ttinfo(),
        start: _TransOffset = _TransOffset(),
        end: _TransOffset = _TransOffset(),
        dst_diff: int = 0;

    def transitions(year: int) -> tuple[(int, int)] {
        return (self.start.year_to_epoch(year), self.end.year_to_epoch(year));
    }

    def get_trans_info(ts: int, year: int, fold: int) -> _ttinfo {
        (start, end) = self.transitions(year);
        if (fold != 0) == (self.dst_diff >= 0) {
            end -= self.dst_diff;
        } else {
            start += self.dst_diff;
        }
        isdst: bool = False;
        if start < end {
            isdst = start <= ts and ts < end;
        } else {
            isdst = not (end <= ts and ts < start);
        }
        return self.dst if isdst else self.std;
    }

    def get_trans_info_fromutc(ts: int, year: int) -> tuple[(_ttinfo, int)] {
        (start, end) = self.transitions(year);
        so: (timedelta | None) = self.std.utcoff;
        do: (timedelta | None) = self.dst.utcoff;
        if so is not None {
            start -= _td_seconds(so);
        }
        if do is not None {
            end -= _td_seconds(do);
        }
        isdst: bool = False;
        if start < end {
            isdst = start <= ts and ts < end;
        } else {
            isdst = not (end <= ts and ts < start);
        }
        ambig_start: int = 0;
        ambig_end: int = 0;
        if self.dst_diff > 0 {
            ambig_start = end;
            ambig_end = end + self.dst_diff;
        } else {
            ambig_start = start;
            ambig_end = start - self.dst_diff;
        }
        fold: int = 0;
        if ambig_start <= ts and ts < ambig_end {
            fold = 1;
        }
        return (self.dst if isdst else self.std, fold);
    }
}


def _zi_bisect_right(a: list[int], x: int) -> int {
    lo: int = 0;
    hi: int = len(a);
    while lo < hi {
        mid: int = (lo + hi) // 2;
        if x < a[mid] {
            hi = mid;
        } else {
            lo = mid + 1;
        }
    }
    return lo;
}


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

    def init(key: str = "", _raw: bool = False) {
        if _raw {
            return;
        }
        cached: (ZoneInfo | None) = _zone_cache_get(key);
        if cached is not None {
            self.key = cached.key;
            self._data = cached._data;
            return;
        }
        self.key = key;
        self._data = _zone_data_for_key(key);
        _zone_cache_put(key, self);
    }

    static def no_cache(key: str) -> ZoneInfo {
        z: ZoneInfo = ZoneInfo("", True);
        z.key = key;
        z._data = _zone_data_for_key(key);
        return z;
    }

    static def from_file(data: bytes, key: (str | None) = None) -> ZoneInfo {
        z: ZoneInfo = ZoneInfo("", True);
        z.key = key;
        z._data = _build_zone_data(_parse_tzif(data), "");
        return z;
    }

    static def clear_cache {
        _zone_cache.clear();
    }

    def utcoffset(dt: (datetime | None)) -> (timedelta | None) {
        return self._find_trans(dt).utcoff;
    }

    def dst(dt: (datetime | None)) -> (timedelta | None) {
        return self._find_trans(dt).dstoff;
    }

    def tzname(dt: (datetime | None)) -> (str | None) {
        return self._find_trans(dt).tzname;
    }

    def fromutc(dt: datetime) -> datetime {
        if not isinstance(dt, datetime) {
            raise TypeError("fromutc() requires a datetime argument");
        }
        if dt.tzinfo is not self {
            raise ValueError("dt.tzinfo is not self");
        }
        timestamp: int = self._get_local_timestamp(dt);
        trans_utc: list[int] = self._data.trans_utc;
        num_trans: int = len(trans_utc);
        tti: _ttinfo;
        fold: int = 0;
        tb: (_ttinfo | None) = self._data.tti_before;
        tzs: (_TZStr | None) = self._data.tz_str;
        if num_trans >= 1 and timestamp < trans_utc[0] {
            if tb is None {
                tti = self._data.ttinfos[0];
            } else {
                tti = tb;
            }
            fold = 0;
        } elif (num_trans == 0 or timestamp > trans_utc[num_trans - 1])
            and tzs is not None {
            (tti, fold) = tzs.get_trans_info_fromutc(timestamp, dt.year);
        } elif num_trans == 0 {
            tti = self._data.tz_after;
            fold = 0;
        } else {
            idx: int = _zi_bisect_right(trans_utc, timestamp);
            tti_prev: _ttinfo;
            if num_trans > 1 and timestamp >= trans_utc[1] {
                tti_prev = self._data.ttinfos[idx - 2];
                tti = self._data.ttinfos[idx - 1];
            } elif timestamp > trans_utc[num_trans - 1] {
                tti_prev = self._data.ttinfos[num_trans - 1];
                tti = self._data.tz_after;
            } else {
                if tb is None {
                    tti_prev = self._data.ttinfos[0];
                } else {
                    tti_prev = tb;
                }
                tti = self._data.ttinfos[0];
            }
            poff: (timedelta | None) = tti_prev.utcoff;
            toff: (timedelta | None) = tti.utcoff;
            poff_us: int = 0;
            toff_us: int = 0;
            if poff is not None {
                poff_us = poff._to_microseconds();
            }
            if toff is not None {
                toff_us = toff._to_microseconds();
            }
            if (poff_us - toff_us) > (timestamp - trans_utc[idx - 1]) * 1000000 {
                fold = 1;
            } else {
                fold = 0;
            }
        }
        uoff_us: int = 0;
        uoff: (timedelta | None) = tti.utcoff;
        if uoff is not None {
            uoff_us = uoff._to_microseconds();
        }
        total_us: int = timestamp * 1000000 + dt.microsecond + uoff_us;
        days: int = total_us // 86400000000;
        rem: int = total_us - days * 86400000000;
        ord2: int = days + _EPOCHORDINAL;
        if ord2 < 1 or ord2 > _MAXORDINAL {
            raise OverflowError("result out of range");
        }
        (y, m, d) = _ord2ymd(ord2);
        return datetime(
            y,
            m,
            d,
            rem // 3600000000,
            (rem // 60000000) % 60,
            (rem // 1000000) % 60,
            rem % 1000000,
            self,
            fold
        );
    }

    def _find_trans(dt: (datetime | None)) -> _ttinfo {
        if dt is None {
            if self._data.fixed_offset {
                return self._data.tz_after;
            }
            return _NO_TTINFO;
        }
        d: datetime = dt;
        ts: int = self._get_local_timestamp(d);
        lt: list[int] = self._data.trans_local[d.fold];
        num_trans: int = len(lt);
        if num_trans > 0 and ts < lt[0] {
            tb: (_ttinfo | None) = self._data.tti_before;
            if tb is None {
                return self._data.ttinfos[0];
            }
            return tb;
        } elif num_trans == 0 or ts > lt[num_trans - 1] {
            tzs: (_TZStr | None) = self._data.tz_str;
            if tzs is not None {
                return tzs.get_trans_info(ts, d.year, d.fold);
            }
            return self._data.tz_after;
        }
        idx: int = _zi_bisect_right(lt, ts) - 1;
        return self._data.ttinfos[idx];
    }

    def _get_local_timestamp(dt: datetime) -> int {
        return (dt.toordinal() - _EPOCHORDINAL) * 86400
            + dt.hour * 3600
            + dt.minute * 60
            + dt.second;
    }

    def __str__ -> str {
        k: (str | None) = self.key;
        if k is not None {
            return k;
        }
        return self.__repr__();
    }

    def __repr__ -> str {
        if self.key is not None {
            return "zoneinfo.ZoneInfo(key='" + self.key + "')";
        }
        return "zoneinfo.ZoneInfo.from_file(<bytes>)";
    }
}


def _zone_data_for_key(key: str) -> _ZoneData {
    (path, data) = _find_tzfile(key);
    if data is None {
        raise ZoneInfoNotFoundError("No time zone found with key " + key);
    }
    return _build_zone_data(_parse_tzif(data as bytes), path);
}


def _build_zone_data(parsed: _TzifData, file_path: str) -> _ZoneData {
    d: _ZoneData = _ZoneData();
    d.file_path = file_path;
    trans_idx: list[int] = parsed.trans_idx;
    trans_utc: list[int] = parsed.trans_utc;
    utcoff: list[int] = parsed.utcoff;
    isdst: list[int] = parsed.isdst;
    abbr: list[str] = parsed.abbr;
    tz_str: str = parsed.tz_str;
    typecnt: int = len(isdst);
    dstoffs: list[int] = [];
    dst_cnt: int = 0;
    i: int = 0;
    while i < typecnt {
        dstoffs.append(0);
        dst_cnt += isdst[i];
        i += 1;
    }
    dst_found: int = 0;
    i = 1;
    while i < len(trans_idx) {
        if dst_cnt == dst_found {
            break;
        }
        idx: int = trans_idx[i];
        if isdst[idx] == 0 {
            i += 1;
            continue;
        }
        if dstoffs[idx] != 0 {
            i += 1;
            continue;
        }
        dstoff: int = 0;
        uoff: int = utcoff[idx];
        comp_idx: int = trans_idx[i - 1];
        if isdst[comp_idx] == 0 {
            dstoff = uoff - utcoff[comp_idx];
        }
        if dstoff == 0 and idx < typecnt - 1 and i + 1 < len(trans_idx) {
            comp_idx = trans_idx[i + 1];
            if isdst[comp_idx] != 0 {
                i += 1;
                continue;
            }
            dstoff = uoff - utcoff[comp_idx];
        }
        if dstoff != 0 {
            dst_found += 1;
            dstoffs[idx] = dstoff;
        }
        i += 1;
    }
    i = 0;
    while i < typecnt {
        if dstoffs[i] == 0 and isdst[i] != 0 {
            dstoffs[i] = 3600;
        }
        i += 1;
    }
    trans_local: list[list[int]] = [[], []];
    if len(trans_utc) > 0 {
        wall0: list[int] = [];
        wall1: list[int] = [];
        for t in trans_utc {
            wall0.append(t);
            wall1.append(t);
        }
        offset_0: int = 0;
        offset_1: int = 0;
        if len(utcoff) > 1 {
            offset_0 = utcoff[0];
            offset_1 = utcoff[trans_idx[0]];
            if offset_1 > offset_0 {
                tmp: int = offset_0;
                offset_0 = offset_1;
                offset_1 = tmp;
            }
        } else {
            offset_0 = utcoff[0];
            offset_1 = utcoff[0];
        }
        wall0[0] = wall0[0] + offset_0;
        wall1[0] = wall1[0] + offset_1;
        i = 1;
        while i < len(trans_idx) {
            offset_0 = utcoff[trans_idx[i - 1]];
            offset_1 = utcoff[trans_idx[i]];
            if offset_1 > offset_0 {
                tmp2: int = offset_0;
                offset_0 = offset_1;
                offset_1 = tmp2;
            }
            wall0[i] = wall0[i] + offset_0;
            wall1[i] = wall1[i] + offset_1;
            i += 1;
        }
        trans_local = [wall0, wall1];
    } else {
        trans_local = [[], []];
    }
    ttinfo_list: list[_ttinfo] = [];
    i = 0;
    while i < typecnt {
        ttinfo_list.append(
            _ttinfo(timedelta(0, utcoff[i]), timedelta(0, dstoffs[i]), abbr[i])
        );
        i += 1;
    }
    d.trans_utc = trans_utc;
    d.trans_local = trans_local;
    d.ttinfos = [];
    for ti in trans_idx {
        d.ttinfos.append(ttinfo_list[ti]);
    }
    d.tti_before = None;
    i = 0;
    while i < len(isdst) {
        if isdst[i] == 0 {
            d.tti_before = ttinfo_list[i];
            break;
        }
        i += 1;
    }
    if d.tti_before is None {
        if len(d.ttinfos) > 0 {
            d.tti_before = d.ttinfos[0];
        }
    }
    d.tz_str = None;
    if tz_str != "" {
        (za, zs) = _parse_tz_str(tz_str);
        if zs is not None {
            d.tz_str = zs;
            d.tz_after = _ttinfo();
        } else {
            d.tz_after = za as _ttinfo;
        }
    } else {
        if len(d.ttinfos) == 0 and len(ttinfo_list) == 0 {
            raise ValueError("No time zone information found.");
        }
        if len(d.ttinfos) > 0 {
            d.tz_after = d.ttinfos[len(d.ttinfos) - 1];
        } else {
            d.tz_after = ttinfo_list[len(ttinfo_list) - 1];
        }
    }
    if len(ttinfo_list) > 1 or d.tz_str is not None {
        d.fixed_offset = False;
    } elif len(ttinfo_list) == 0 {
        d.fixed_offset = True;
    } else {
        d.fixed_offset = ttinfo_list[0] == d.tz_after;
    }
    return d;
}


obj _TzifData {
    has trans_idx: list[int] = [],
        trans_utc: list[int] = [],
        utcoff: list[int] = [],
        isdst: list[int] = [],
        abbr: list[str] = [],
        tz_str: str = "";
}


def _parse_tzif(data: bytes) -> _TzifData {
    if len(data) < 44 {
        raise ValueError("Invalid TZif file: magic not found");
    }
    if data[0:4] != b"TZif" {
        raise ValueError("Invalid TZif file: magic not found");
    }
    vb: int = data[4];
    version: int = 1;
    if vb != 0 {
        version = vb;
    }
    isutcnt: int = _be_i32(data, 20);
    isstdcnt: int = _be_i32(data, 24);
    leapcnt: int = _be_i32(data, 28);
    timecnt: int = _be_i32(data, 32);
    typecnt: int = _be_i32(data, 36);
    charcnt: int = _be_i32(data, 40);
    pos: int = 44;
    time_size: int = 4;
    if version >= 2 {
        time_size = 8;
        skipn: int = timecnt * 5
            + typecnt * 6
            + charcnt
            + leapcnt * 8
            + isstdcnt
            + isutcnt;
        pos += skipn;
        if data[pos:pos + 4] != b"TZif" {
            raise ValueError("Invalid TZif file: magic not found");
        }
        pos += 20;
        isutcnt = _be_i32(data, pos);
        isstdcnt = _be_i32(data, pos + 4);
        leapcnt = _be_i32(data, pos + 8);
        timecnt = _be_i32(data, pos + 12);
        typecnt = _be_i32(data, pos + 16);
        charcnt = _be_i32(data, pos + 20);
        pos += 24;
    }
    trans_utc: list[int] = [];
    trans_idx: list[int] = [];
    if timecnt > 0 {
        i: int = 0;
        while i < timecnt {
            if time_size == 8 {
                trans_utc.append(_be_i64(data, pos));
            } else {
                trans_utc.append(_be_i32(data, pos));
            }
            pos += time_size;
            i += 1;
        }
        i = 0;
        while i < timecnt {
            trans_idx.append(data[pos]);
            pos += 1;
            i += 1;
        }
        i = 0;
        while i < timecnt {
            if trans_idx[i] >= typecnt {
                raise ValueError("Invalid transition index found while reading TZif");
            }
            i += 1;
        }
    }
    utcoff: list[int] = [];
    isdst: list[int] = [];
    abbrind: list[int] = [];
    i: int = 0;
    while i < typecnt {
        utcoff.append(_be_i32(data, pos));
        isdst.append(data[pos + 4]);
        abbrind.append(data[pos + 5]);
        pos += 6;
        i += 1;
    }
    abbr: list[str] = [];
    abbr_chars: bytes = data[pos:pos + charcnt];
    i = 0;
    while i < len(abbrind) {
        idx: int = abbrind[i];
        e: int = idx;
        while e < len(abbr_chars) and abbr_chars[e] != 0 {
            e += 1;
        }
        abbr.append(abbr_chars[idx:e].decode());
        i += 1;
    }
    pos += charcnt;
    tz_str: str = "";
    if version >= 2 {
        pos += isutcnt + isstdcnt + leapcnt * 12;
        if pos >= len(data) or data[pos] != 10 {
            raise ValueError("Invalid TZif file: unexpected end of file");
        }
        pos += 1;
        e2: int = pos;
        while e2 < len(data) and data[e2] != 10 {
            e2 += 1;
        }
        if e2 >= len(data) {
            raise ValueError("Invalid TZif file: unexpected end of file");
        }
        tz_str = data[pos:e2].decode();
    }
    r: _TzifData = _TzifData();
    r.trans_idx = trans_idx;
    r.trans_utc = trans_utc;
    r.utcoff = utcoff;
    r.isdst = isdst;
    r.abbr = abbr;
    r.tz_str = tz_str;
    return r;
}


def _validate_tzfile_path(path: str) {
    if len(path) > 0 and path[0] == "/" {
        raise ValueError("ZoneInfo keys may not be absolute paths, got: " + path);
    }
    new_path: str = normpath(path);
    if len(new_path) != len(path) {
        raise ValueError(
            "ZoneInfo keys must be normalized relative paths, got: " + path
        );
    }
    resolved: str = normpath("_/_/" + new_path);
    if not resolved.startswith("_/_/") {
        raise ValueError(
            "ZoneInfo keys must refer to subdirectories of TZPATH, got: " + path
        );
    }
}


def _find_tzfile(key: str) -> tuple[(str, (bytes | None))] {
    _validate_tzfile_path(key);
    for sp in TZPATH {
        filepath: str = sp + "/" + key;
        try {
            b: bytes = read_file_bytes(filepath);
            if len(b) > 0 {
                return (filepath, b);
            }
        } except OSError {}
    }
    return ("", None);
}


glob _zone_cache: dict[str, ZoneInfo] = {};


def _zone_cache_get(key: str) -> (ZoneInfo | None) {
    return _zone_cache.get(key);
}


def _zone_cache_put(key: str, z: ZoneInfo) {
    _zone_cache[key] = z;
}


def:pub reset_tzpath(to: (list[str] | None) = None) {
    src: list[str] = _DEFAULT_TZPATH if to is None else to;
    for p in src {
        if len(p) == 0 or p[0] != "/" {
            raise ValueError("TZPATH entries must be absolute paths");
        }
    }
    TZPATH.clear();
    for p in src {
        TZPATH.append(p);
    }
}


def:pub available_timezones -> list[str] {
    zones: list[str] = [];
    for tzroot in TZPATH {
        _walk_tzdir(tzroot, "", zones);
    }
    zones.sort();
    return zones;
}


def _walk_tzdir(tzroot: str, prefix: str, zones: list[str]) {
    names: list[str] = try_directory_names(tzroot + "/" + prefix);
    if len(names) == 0 {
        return;
    }
    for nm in names {
        if nm == "right" or nm == "posix" {
            continue;
        }
        rel: str = nm if prefix == "" else prefix + "/" + nm;
        full: str = tzroot + "/" + rel;
        sub: list[str] = try_directory_names(full);
        if len(sub) > 0 {
            _walk_tzdir(tzroot, rel, zones);
        } else {
            try {
                b: bytes = read_file_bytes(full);
                if len(b) >= 4 and b[0:4] == b"TZif" {
                    zones.append(rel);
                }
            } except OSError {}
        }
    }
}


def _parse_transition_time(ts: str) -> tuple[(int, int, int)] {
    pos: int = 0;
    sign: int = 1;
    if pos < len(ts) and (ts[pos] == "-" or ts[pos] == "+") {
        if ts[pos] == "-" {
            sign = -1;
        }
        pos += 1;
    }
    (h, np) = _sp_zd(ts, pos, 3);
    if np < 0 {
        raise ValueError("Invalid time: " + ts);
    }
    pos = np;
    m: int = 0;
    s: int = 0;
    if pos < len(ts) and ts[pos] == ":" {
        (m, np) = _sp_zd(ts, pos + 1, 2);
        if np < 0 or np - pos - 1 != 2 {
            raise ValueError("Invalid time: " + ts);
        }
        pos = np;
        if pos < len(ts) and ts[pos] == ":" {
            (s, np) = _sp_zd(ts, pos + 1, 2);
            if np < 0 or np - pos - 1 != 2 {
                raise ValueError("Invalid time: " + ts);
            }
            pos = np;
        }
    }
    if pos != len(ts) {
        raise ValueError("Invalid time: " + ts);
    }
    if h > 167 {
        raise ValueError("Hour must be in [0, 167]: " + ts);
    }
    return (sign * h, sign * m, sign * s);
}


def _sp_zd(s: str, pos: int, maxn: int) -> tuple[(int, int)] {
    v: int = 0;
    n: int = 0;
    while pos + n < len(s) and n < maxn {
        c: int = "0123456789".find(s[pos + n]);
        if c < 0 {
            break;
        }
        v = v * 10 + c;
        n += 1;
    }
    if n == 0 {
        return (0, -1);
    }
    return (v, pos + n);
}


def _parse_tz_delta(td: str) -> int {
    (h, m, s) = _parse_transition_time(td);
    if h < -24 or h > 24 {
        raise ValueError("Offset hours must be in [0, 24]: " + td);
    }
    total: int = h * 3600 + m * 60 + s;
    if total < 0 {
        total = -total;
    }
    if not td.startswith("-") {
        total = -total;
    }
    return total;
}


def _zi_abbr_end(s: str, pos: int) -> int {
    if pos < len(s) and s[pos] == "<" {
        e: int = pos + 1;
        while e < len(s) and s[e] != ">" {
            e += 1;
        }
        if e >= len(s) {
            return -1;
        }
        return e + 1;
    }
    e: int = pos;
    while e < len(s) {
        c: str = s[e];
        ok: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z");
        if not ok {
            break;
        }
        e += 1;
    }
    return e;
}


def _zi_strip_abbr(s: str) -> str {
    if s.startswith("<") and s.endswith(">") {
        return s[1:len(s) - 1];
    }
    return s;
}


def _zi_off_end(s: str, pos: int) -> int {
    i: int = pos;
    if i < len(s) and (s[i] == "+" or s[i] == "-") {
        i += 1;
    }
    nd: int = 0;
    while i + nd < len(s) and nd < 3 {
        if "0123456789".find(s[i + nd]) < 0 {
            break;
        }
        nd += 1;
    }
    if nd == 0 {
        return pos;
    }
    i += nd;
    if i < len(s) and s[i] == ":" {
        j: int = i + 1;
        n2: int = 0;
        while j + n2 < len(s) and n2 < 2 {
            if "0123456789".find(s[j + n2]) < 0 {
                break;
            }
            n2 += 1;
        }
        if n2 == 2 {
            i = j + 2;
            if i < len(s) and s[i] == ":" {
                j = i + 1;
                n2 = 0;
                while j + n2 < len(s) and n2 < 2 {
                    if "0123456789".find(s[j + n2]) < 0 {
                        break;
                    }
                    n2 += 1;
                }
                if n2 == 2 {
                    i = j + 2;
                }
            }
        }
    }
    return i;
}


def _parse_dst_start_end(dststr: str) -> _TransOffset {
    parts: list[str] = dststr.split("/");
    date: str = parts[0];
    o: _TransOffset = _TransOffset();
    if date.startswith("M") {
        inner: list[str] = date[1:].split(".");
        if len(inner) != 3 {
            raise ValueError("Invalid dst start/end date: " + dststr);
        }
        o.m = _atoi_zi(inner[0]);
        o.w = _atoi_zi(inner[1]);
        o.d = _atoi_zi(inner[2]);
        if not (o.m >= 1 and o.m <= 12) {
            raise ValueError("m must be in [1, 12]");
        }
        if not (o.w >= 1 and o.w <= 5) {
            raise ValueError("w must be in [1, 5]");
        }
        if not (o.d >= 0 and o.d <= 6) {
            raise ValueError("d must be in [0, 6]");
        }
    } else {
        if date.startswith("J") {
            o.julian = True;
            date = date[1:];
        }
        i: int = 0;
        while i < len(date) {
            if "0123456789".find(date[i]) < 0 {
                raise ValueError("Invalid dst start/end date: " + dststr);
            }
            i += 1;
        }
        if len(date) == 0 or len(date) > 3 {
            raise ValueError("Invalid dst start/end date: " + dststr);
        }
        o.d = _atoi_zi(date);
        mind: int = 1 if o.julian else 0;
        if not (o.d >= mind and o.d <= 365) {
            raise ValueError("d must be in [" + str(mind) + ", 365], not: " + str(o.d));
        }
    }
    if len(parts) > 1 {
        (h, m, s) = _parse_transition_time(parts[1]);
        o.hour = h;
        o.minute = m;
        o.second = s;
    }
    return o;
}


def _atoi_zi(s: str) -> int {
    v: int = 0;
    i: int = 0;
    while i < len(s) {
        c: int = "0123456789".find(s[i]);
        if c < 0 {
            raise ValueError("invalid literal for int()");
        }
        v = v * 10 + c;
        i += 1;
    }
    return v;
}


def _parse_tz_str(tz_str: str) -> tuple[(_ttinfo, (_TZStr | None))] {
    comma: int = tz_str.find(",");
    offset_str: str = tz_str;
    rules: str = "";
    if comma >= 0 {
        offset_str = tz_str[0:comma];
        rules = tz_str[comma + 1:];
    }
    ae: int = _zi_abbr_end(offset_str, 0);
    if ae <= 0 {
        raise ValueError(tz_str + " is not a valid TZ string");
    }
    std_abbr: str = _zi_strip_abbr(offset_str[0:ae]);
    oe: int = _zi_off_end(offset_str, ae);
    if oe == ae {
        raise ValueError("Invalid STD offset in " + tz_str);
    }
    std_offset: int = _parse_tz_delta(offset_str[ae:oe]);
    rest: str = offset_str[oe:];
    dst_abbr: str = "";
    dst_offset: int = 0;
    if rest != "" {
        de: int = _zi_abbr_end(rest, 0);
        if de <= 0 {
            raise ValueError(tz_str + " is not a valid TZ string");
        }
        dst_abbr = _zi_strip_abbr(rest[0:de]);
        doe: int = _zi_off_end(rest, de);
        if doe > de {
            dst_offset = _parse_tz_delta(rest[de:doe]);
            if rest[doe:] != "" {
                raise ValueError(tz_str + " is not a valid TZ string");
            }
        } else {
            dst_offset = std_offset + 3600;
        }
        if rules == "" {
            raise ValueError("Missing transition rules: " + tz_str);
        }
        rp: list[str] = rules.split(",");
        if len(rp) != 2 {
            raise ValueError("Invalid TZ string: " + tz_str);
        }
        start: _TransOffset = _TransOffset();
        end: _TransOffset = _TransOffset();
        try {
            start = _parse_dst_start_end(rp[0]);
            end = _parse_dst_start_end(rp[1]);
        } except ValueError {
            raise ValueError("Invalid TZ string: " + tz_str);
        }
        zs: _TZStr = _TZStr();
        zs.std = _ttinfo(timedelta(0, std_offset), timedelta(0), std_abbr);
        zs.dst = _ttinfo(
            timedelta(0, dst_offset), timedelta(0, dst_offset - std_offset), dst_abbr
        );
        zs.start = start;
        zs.end = end;
        zs.dst_diff = dst_offset - std_offset;
        return (_ttinfo(), zs);
    }
    if rules != "" {
        raise ValueError("Transition rule present without DST: " + tz_str);
    }
    return (_ttinfo(timedelta(0, std_offset), timedelta(0), std_abbr), None);
}
