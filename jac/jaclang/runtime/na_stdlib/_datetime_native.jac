import from c { def malloc(size: u64) -> int;  }
import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def localtime_r(timep: int, result: int) -> int;  }
import from c { def gmtime_r(timep: int, result: int) -> int;  }
import from c { def strftime(s: int, max: u64, format: str, tm: int) -> u64;  }
import from c { def strdup(s: int) -> str;  }
import from _errno_native { last_errno, raise_os_error }

glob _DT_S: int = malloc(u64(2176));
glob _DT_TV: int = _DT_S,
     _DT_TM: int = _DT_S + 16,
     _DT_TMW: int = _DT_S + 72,
     _DT_FMT: int = _DT_S + 128,
     _DT_FMT_CAP: int = 1024,
     _DT_ISO: int = _DT_S + 1152,
     _DT_ISO_CAP: int = 1024;


def:pub dt_out_buf -> int {
    return _DT_ISO;
}


def:pub dt_fmt_buf -> int {
    return _DT_FMT;
}


def:pub dt_out_str(n: int) -> str {
    if n < 0 or n >= _DT_ISO_CAP {
        raise ValueError("formatted output exceeds scratch capacity");
    }
    __mem_store_i8(_DT_ISO + n, i8(0));
    return strdup(_DT_ISO);
}


def:pub dt_epoch_us -> int {
    if clock_gettime(0, _DT_TV) != 0 {
        raise_os_error("clock_gettime", "", last_errno());
    }
    return __mem_load_i64(_DT_TV) * 1000000 + __mem_load_i64(_DT_TV + 8) // 1000;
}


def:pub dt_localtime(t: int) -> int {
    __mem_store_i64(_DT_TV, t);
    if localtime_r(_DT_TV, _DT_TM) == 0 {
        raise_os_error("localtime", "", last_errno());
    }
    return 0;
}


def:pub dt_gmtime(t: int) -> int {
    __mem_store_i64(_DT_TV, t);
    if gmtime_r(_DT_TV, _DT_TM) == 0 {
        raise_os_error("gmtime", "", last_errno());
    }
    return 0;
}


def:pub dt_tm(field: int) -> int {
    if field < 9 {
        return int(__mem_load_i32(_DT_TM + field * 4));
    }
    return 0;
}


def:pub dt_tm_gmtoff -> int {
    return __mem_load_i64(_DT_TM + 40);
}


def:pub dt_tm_zone -> str {
    zp: int = __mem_load_i64(_DT_TM + 48);
    if zp == 0 {
        return "";
    }
    return strdup(zp);
}


def _tmw_store(
    sec: int,
    min: int,
    hour: int,
    mday: int,
    mon: int,
    year: int,
    wday: int,
    yday: int,
    isdst: int
) {
    __mem_store_i32(_DT_TMW + 0, i32(sec));
    __mem_store_i32(_DT_TMW + 4, i32(min));
    __mem_store_i32(_DT_TMW + 8, i32(hour));
    __mem_store_i32(_DT_TMW + 12, i32(mday));
    __mem_store_i32(_DT_TMW + 16, i32(mon));
    __mem_store_i32(_DT_TMW + 20, i32(year));
    __mem_store_i32(_DT_TMW + 24, i32(wday));
    __mem_store_i32(_DT_TMW + 28, i32(yday));
    __mem_store_i32(_DT_TMW + 32, i32(isdst));
    __mem_store_i64(_DT_TMW + 40, 0);
    __mem_store_i64(_DT_TMW + 48, 0);
}


def:pub dt_strftime(
    format: str,
    sec: int,
    min: int,
    hour: int,
    mday: int,
    mon: int,
    year: int,
    wday: int,
    yday: int,
    isdst: int
) -> str {
    _tmw_store(sec, min, hour, mday, mon, year, wday, yday, isdst);
    n: int = int(strftime(_DT_FMT, u64(_DT_FMT_CAP), format, _DT_TMW));
    if n == 0 and format != "" {
        raise ValueError("strftime result exceeds 1024 bytes");
    }
    return strdup(_DT_FMT);
}
