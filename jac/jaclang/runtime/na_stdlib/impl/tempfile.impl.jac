impl _gettempdir -> str {
    for name in ["TMPDIR", "TEMP", "TMP"] {
        env_dir = os.getenv(name);
        if env_dir is not None and env_dir != "" {
            if os.path.isdir(env_dir) and access(env_dir, 3) == 0 {
                return env_dir;
            }
        }
    }
    for cand in ["/tmp", "/var/tmp", "/usr/tmp"] {
        if os.path.isdir(cand) and access(cand, 3) == 0 {
            return cand;
        }
    }
    return os.getcwd();
}

impl mkdtemp(
    suffix: (str | None) = None, prefix: (str | None) = None, dir: (str | None) = None
) -> str {
    base: str = "";
    if dir is not None {
        base = dir;
    } else {
        base = _gettempdir();
    }

    stem: str = _DEFAULT_PREFIX;
    if prefix is not None {
        stem = prefix;
    }
    tail: str = "";
    if suffix is not None {
        tail = suffix;
    }

    for _ in range(_TMP_MAX) {
        path: str = os.path.join(base, stem + uuid4().hex + tail);
        if mkdir(path, 0o700) == 0 {
            return os.path.abspath(path);
        }
        code: int = last_errno();
        if code == EEXIST {
            continue;
        }
        raise_os_error("mkdir", path, code);
    }
    raise FileExistsError("no usable temporary directory name found");
}
