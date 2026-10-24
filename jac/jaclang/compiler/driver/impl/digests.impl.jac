impl file_identity(path: str) -> (tuple[int, int, int, int] | None) {
    try {
        st = os.stat(path);
    } except OSError {
        return None;
    }
    return (st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns);
}

impl file_sha256(path: str) -> str {
    real = os.path.realpath(path);
    ident = file_identity(real);
    if ident is None {
        return _hash_file(real);
    }
    known = _MEMO.get(real);
    if known is not None and known[0] == ident {
        return known[1];
    }
    name = _shard_name(real);
    rec = _shard(name).get(real);
    if isinstance(rec, list) and len(rec) == 5 and tuple(rec[:4]) == ident {
        _MEMO[real] = (ident, str(rec[4]));
        return str(rec[4]);
    }
    digest = _hash_file(real);
    if _stable(ident) {
        _MEMO[real] = (ident, digest);
        _shard(name)[real] = [ident[0], ident[1], ident[2], ident[3], digest];
        _DIRTY.add(name);
        if not _FLUSH_ARMED {
            import atexit;
            atexit.register(flush_digests);
            _FLUSH_ARMED.append(True);
        }
    }
    return digest;
}

impl flush_digests {
    if not _DIRTY {
        return;
    }
    base = _ledger_dir();
    try {
        base.mkdir(parents=True, exist_ok=True);
    } except OSError {
        _DIRTY.clear();
        return;
    }
    for name in sorted(_DIRTY) {
        path = base / f"{name}.json";
        merged: dict[str, list] = {};
        try {
            on_disk = json.loads(path.read_text());
            if isinstance(on_disk, dict) {
                merged.update(on_disk);
            }
        } except (OSError, ValueError) {}
        merged.update(_SHARDS.get(name, {}));
        if len(merged) > LEDGER_SHARD_CAP {
            merged = dict(list(merged.items())[-LEDGER_SHARD_CAP:]);
        }
        tmp = path.with_suffix(f".{os.getpid()}.tmp");
        try {
            tmp.write_text(json.dumps(merged));
            os.replace(tmp, path);
        } except OSError {
            try {
                tmp.unlink();
            } except OSError {}
        }
    }
    _DIRTY.clear();
}

impl forget_digests {
    _MEMO.clear();
    _SHARDS.clear();
    _DIRTY.clear();
}

impl _ledger_dir -> Path {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
    return get_jir_cache_dir() / LEDGER_SUBDIR;
}

impl _shard_name(real: str) -> str {
    return hashlib.sha256(os.path.dirname(real).encode()).hexdigest()[:16];
}

impl _shard(name: str) -> dict[str, list] {
    loaded = _SHARDS.get(name);
    if loaded is not None {
        return loaded;
    }
    entries: dict[str, list] = {};
    try {
        raw = json.loads((_ledger_dir() / f"{name}.json").read_text());
        if isinstance(raw, dict) {
            entries = raw;
        }
    } except (OSError, ValueError) {}
    _SHARDS[name] = entries;
    return entries;
}

impl _hash_file(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        while True {
            chunk = f.read(1 << 20);
            if not chunk {
                break;
            }
            h.update(chunk);
        }
    }
    return h.hexdigest();
}

impl _stable(ident: tuple[int, int, int, int]) -> bool {
    return time.time_ns() - max(ident[2], ident[3]) > RACY_WINDOW_NS;
}
