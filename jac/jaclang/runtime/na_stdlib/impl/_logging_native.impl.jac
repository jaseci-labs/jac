impl log_strftime(fmt: str, epoch: int) -> str {
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

impl log_fopen(path: str, mode: str) -> int {
    return fopen(path, mode);
}

impl log_fputs(stream: int, text: str) -> int {
    return int(fputs(text, stream));
}

impl log_fflush(stream: int) -> int {
    return int(fflush(stream));
}

impl log_fclose(stream: int) -> int {
    return int(fclose(stream));
}
