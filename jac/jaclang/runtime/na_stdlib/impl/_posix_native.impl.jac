impl stat_fields(path: str) -> (list[int] | None) {
    out = b"\x00" * 32;
    if __jac_stat(path, out) != 0 {
        return None;
    }
    return [
        int.from_bytes(out[0:8], "little"),
        int.from_bytes(out[8:16], "little"),
        int.from_bytes(out[16:24], "little"),
        int.from_bytes(out[24:32], "little")
    ];
}

impl cwd_path -> str {
    buf = b"\x00" * 4096;
    at = getcwd(buf, 4096);
    if at == 0 {
        raise OSError("getcwd failed");
    }
    return strdup(at);
}

impl env_value(name: str) -> (str | None) {
    at = getenv(name);
    if at == 0 {
        return None;
    }
    return strdup(at);
}

impl resolved_path(path: str) -> (str | None) {
    buf = b"\x00" * 4096;
    at = realpath(path, buf);
    if at == 0 {
        return None;
    }
    return strdup(at);
}

impl make_dir(path: str, mode: int) -> int {
    return int(mkdir(path, i32(mode)));
}
