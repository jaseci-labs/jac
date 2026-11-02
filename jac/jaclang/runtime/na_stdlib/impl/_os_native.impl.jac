impl replace(
    src: str, dst: str, *, src_dir_fd: int | None = None, dst_dir_fd: int | None = None
) {
    replace_file(src, dst, src_dir_fd, dst_dir_fd);
}

impl getcwd -> str {
    return cwd_path();
}

impl getenv(key: str, fallback: (str | None) = None) -> (str | None) {
    found = env_value(key);
    return found if found is not None else fallback;
}

impl environ_get(key: str, fallback: (str | None) = None) -> (str | None) {
    found = env_value(key);
    return found if found is not None else fallback;
}

impl listdir(path: str = ".") -> list[str] {
    return directory_names(path);
}

impl makedirs(name: str, mode: int = 511, exist_ok: bool = False) -> None {
    if not name {
        raise FileNotFoundError("[Errno 2] No such file or directory: ''");
    }
    held = stat_fields(name);
    if held is not None {
        if exist_ok and (held[0] & S_IFMT) == S_IFDIR {
            return;
        }
        raise FileExistsError(f"[Errno 17] File exists: '{name}'");
    }
    trimmed = name.rstrip("/");
    cut = trimmed.rfind("/");
    if cut > 0 {
        head = trimmed[:cut];
        if stat_fields(head) is None {
            makedirs(head, mode, True);
        }
    }
    if make_dir(name, mode) != 0 {
        again = stat_fields(name);
        if exist_ok and again is not None and (again[0] & S_IFMT) == S_IFDIR {
            return;
        }
        raise OSError(f"cannot create directory '{name}'");
    }
}
