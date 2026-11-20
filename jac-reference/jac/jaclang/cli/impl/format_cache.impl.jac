impl _stable_dump(value: any) -> str {
    if value is None or isinstance(value, (bool, int, float, str)) {
        return repr(value);
    }
    if isinstance(value, (list, tuple)) {
        return "[" + ",".join([_stable_dump(v) for v in value]) + "]";
    }
    if isinstance(value, dict) {
        items = sorted([(str(kv[0]), _stable_dump(kv[1])) for kv in value.items()]);
        return "{" + ",".join([f"{kv[0]}:{kv[1]}" for kv in items]) + "}";
    }

    attrs: dict[str, any] = {};
    for name in dir(value) {
        if name.startswith("_") {
            continue;
        }
        try {
            attr = getattr(value, name);
        } except Exception {
            continue;
        }
        if callable(attr) {
            continue;
        }
        attrs[name] = attr;
    }
    return _stable_dump(attrs);
}

impl config_fingerprint(config: any, lintfix: bool) -> str {
    if config is None {
        return "none";
    }
    parts: list[str] = [f"lintfix={int(bool(lintfix))}"];
    parts.append(f"profile={getattr(config, 'active_profile', '') or ''}");
    parts.append("format=" + _stable_dump(config?.format));
    if lintfix {
        parts.append("check=" + _stable_dump(config?.check));
    }
    raw_plugins = config?.plugin_dependencies;
    if isinstance(raw_plugins, dict) and raw_plugins {
        items = sorted([f"{kv[0]}={kv[1]}" for kv in raw_plugins.items()]);
        parts.append("plugins=" + "|".join(items));
    }
    return hashlib.sha256("\n".join(parts).encode()).hexdigest();
}

impl canonical_logical_path(path: str, project_root: (str | None) = None) -> str {
    norm = os.path.normpath(path);
    if project_root {
        try {
            rel = os.path.relpath(norm, os.path.normpath(project_root));
            if not rel.startswith("..") {
                return rel.replace(os.sep, "/");
            }
        } except ValueError {}
    }
    return norm.replace(os.sep, "/");
}

impl default_format_cache_dir(anchor: (Path | str)) -> Path {
    base = Path(anchor);

    if base.is_file() or base.suffix == ".jac" {
        base = base.parent;
    }
    return base.resolve() / ".jac" / "cache";
}

impl _module_source_bytes(modname: str) -> bytes {
    try {
        mod = importlib.import_module(modname);
    } except Exception {
        return b"";
    }
    file_path = mod?.__file__;
    if not file_path {
        return b"";
    }
    path = Path(file_path);
    candidates = [
        path.with_suffix(".jac"),
        path.parent / "impl" / f"{path.stem}.impl.jac",
        path,

    ];

    if path.parent.name == "tool" {
        impl_path = path.parent / "impl" / f"{path.stem}.impl.jac";
        candidates.insert(1, impl_path);
    }
    chunks: list[bytes] = [];
    seen: set[str] = set();
    for candidate in candidates {
        key = str(candidate);
        if key in seen or not candidate.is_file() {
            continue;
        }
        seen.add(key);
        try {
            chunks.append(candidate.read_bytes());
        } except OSError {
            continue;
        }
    }
    return b"\0".join(chunks);
}

impl formatter_pipeline_revision -> str {
    h = hashlib.sha256();
    for modname in _FORMATTER_PIPELINE_MODULES {
        h.update(modname.encode());
        h.update(b"\0");
        h.update(_module_source_bytes(modname));
        h.update(b"\0");
    }
    return h.hexdigest()[:16];
}

impl frame_unit(parts: list[bytes]) -> bytes {
    return b"".join([f"{len(p)}:".encode() + p for p in parts]);
}

impl _frame(label: str, payload: bytes) -> bytes {
    return f"{label}:{len(payload)}:".encode() + payload;
}

impl FormatCache.postinit {
    if bool(self.enabled) and self.cache_dir is not None {
        self.cache_root = Path(self.cache_dir) / f"fmt-{FORMAT_CACHE_SCHEMA_VERSION}";
    } else {
        self.cache_root = None;
    }
}

impl FormatCache.make_key(
    content: bytes, lintfix: bool, config_fingerprint: str, logical_path: str = ""
) -> str {
    h = hashlib.sha256();
    h.update(_frame("stamp", self.formatter_stamp.encode()));
    h.update(_frame("lintfix", b"1" if lintfix else b"0"));
    h.update(_frame("cfg", config_fingerprint.encode()));
    if lintfix {
        h.update(_frame("path", logical_path.encode()));
    }
    h.update(_frame("content", content));
    return h.hexdigest();
}

impl FormatCache.entry_path(key: str) -> Path {
    assert self.cache_root is not None;
    return self.cache_root / key;
}

impl FormatCache.is_clean(key: str) -> bool {
    if self.cache_root is None {
        return False;
    }
    path = self.cache_root / key;
    try {
        data = path.read_bytes();
    } except OSError {
        return False;
    }
    if not data.startswith(_ENTRY_MARKER) {
        try {
            path.unlink();
        } except OSError {}
        return False;
    }

    try {
        os.utime(path, None);
    } except OSError {}
    return True;
}

impl FormatCache.mark_clean(key: str) {
    if self.cache_root is None {
        return;
    }
    path = self.cache_root / key;
    try {
        path.parent.mkdir(parents=True, exist_ok=True);

        tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp");
        try {
            tmp.write_bytes(_ENTRY_MARKER);
            os.replace(tmp, path);
        } finally {
            try {
                tmp.unlink();
            } except OSError {}
        }
    } except OSError {
        return;
    }
    self._maybe_prune();
}

impl FormatCache._maybe_prune {
    if self.cache_root is None {
        return;
    }
    policy = Policy(
        ttl_days=self.entry_ttl / DAY_SECONDS, max_entries=self.max_entries
    );
    maybe_sweep_dir(
        self.cache_root, policy, once_per_process=False, interval=self.prune_interval
    );
}
