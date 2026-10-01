import from c { def localtime_r(t: int, tm: int) -> int;  }
import from c { def strftime(buf: bytes, max: u64, fmt: str, tm: int) -> u64;  }
import from c { def malloc(size: int) -> int;  }
import from c { def fopen(path: str, mode: str) -> int;  }
import from c { def fputs(s: str, stream: int) -> i32;  }
import from c { def fflush(stream: int) -> i32;  }
import from c { def fclose(stream: int) -> i32;  }

glob _LOG_TM: int = malloc(128),
     _LOG_TT: int = malloc(16);


def:pub log_strftime(fmt: str, epoch: int) -> str {
    __mem_store_i64(_LOG_TT, epoch);
    if localtime_r(_LOG_TT, _LOG_TM) == 0 {
        return "";
    }
    buf: bytes = b"\x00" * 256;
    n: int = int(strftime(buf, u64(256), fmt, _LOG_TM));
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode();
}


def:pub log_fopen(path: str, mode: str) -> int {
    return fopen(path, mode);
}


def:pub log_fputs(stream: int, text: str) -> int {
    return int(fputs(text, stream));
}


def:pub log_fflush(stream: int) -> int {
    return int(fflush(stream));
}


def:pub log_fclose(stream: int) -> int {
    return int(fclose(stream));
}
