import from c { def malloc(size: u64) -> int;  }
import from c { def localtime_r(timep: int, result: int) -> int;  }
import from c { def gmtime_r(timep: int, result: int) -> int;  }
import from c { def strftime(s: int, max: u64, format: str, tm: int) -> u64;  }
import from c { def strdup(s: int) -> str;  }

glob _DT_S: int = malloc(u64(2176));
glob _DT_TV: int = _DT_S,
     _DT_TM: int = _DT_S + 16,
     _DT_TMW: int = _DT_S + 72,
     _DT_FMT: int = _DT_S + 128,
     _DT_FMT_CAP: int = 1024,
     _DT_ISO: int = _DT_S + 1152,
     _DT_ISO_CAP: int = 1024;


def:pub dt_out_buf -> int;


def:pub dt_fmt_buf -> int;


def:pub dt_out_str(n: int) -> str;


def:pub dt_epoch_us -> int;


def:pub dt_localtime(t: int) -> int;


def:pub dt_gmtime(t: int) -> int;


def:pub dt_tm(field: int) -> int;


def:pub dt_tm_gmtoff -> int;


def:pub dt_tm_zone -> str;


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
);


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
) -> str;
