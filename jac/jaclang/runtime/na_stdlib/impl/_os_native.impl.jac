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

impl environ_getitem(key: str) -> str {
    found = env_value(key);
    if found is None {
        raise KeyError(key);
    }
    return found;
}

impl _environ_name(key: str) -> None {
    if not key or "=" in key {
        raise ValueError("illegal environment variable name");
    }
    if "\x00" in key {
        raise ValueError("embedded null byte");
    }
}

impl environ_setitem(key: str, value: str) -> None {
    _environ_name(key);
    if "\x00" in value {
        raise ValueError("embedded null byte");
    }
    if env_set(key, value) != 0 {
        raise OSError("setenv failed");
    }
}

impl environ_delitem(key: str) -> None {
    if env_value(key) is None {
        raise KeyError(key);
    }
    _environ_name(key);
    if env_unset(key) != 0 {
        raise OSError("unsetenv failed");
    }
}

impl environ_pop(key: str, fallback: (str | None) = "\x00") -> (str | None) {
    found = env_value(key);
    if found is None {
        if fallback == "\x00" {
            raise KeyError(key);
        }
        return fallback;
    }
    _environ_name(key);
    env_unset(key);
    return found;
}

impl environ_contains(key: str) -> bool {
    return env_value(key) is not None;
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

impl mkdir(path: str, mode: int = 511) -> None {
    if make_dir(path, mode) != 0 {
        raise_path_error(path, last_errno());
    }
}

impl remove(path: str) -> None {
    if remove_file(path) != 0 {
        raise_path_error(path, last_errno());
    }
}

impl unlink(path: str) -> None {
    remove(path);
}

impl rmdir(path: str) -> None {
    if remove_dir(path) != 0 {
        raise_path_error(path, last_errno());
    }
}

impl system(command: str) -> int {
    return run_shell(command);
}
