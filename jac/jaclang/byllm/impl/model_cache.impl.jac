impl _is_interactive -> bool {
    try {
        return os.isatty(0) and os.isatty(2);
    } except Exception {
        return False;
    }
}

impl _emit(msg: str) {
    console.print(msg, end="");
}

impl get_cache_dir -> Path {
    return bucket("models").ensure();
}

impl alias_dir(alias: str) -> Path {
    return get_cache_dir() / alias;
}

impl gguf_path(alias: str, spec: dict[str, any]) -> Path {
    fname: str = str(spec["file"]);
    return alias_dir(alias) / fname;
}

impl _consent_marker(alias: str) -> Path {
    return alias_dir(alias) / ".jac_download_consent";
}

impl is_downloaded(alias: str, spec: dict[str, any]) -> bool {
    p = gguf_path(alias, spec);
    if not p.is_file() {
        return False;
    }
    try {
        with open(p, "rb") as f {
            return f.read(4) == b"GGUF" and p.stat().st_size >= _gguf_size_needed(f);
        }
    } except (ValueError, OverflowError, ZeroDivisionError, OSError) {
        return False;
    }
}

impl _read_le(f: any, fmt: str) -> int {
    n = struct.calcsize(fmt);
    data = f.read(n);
    if len(data) < n {
        raise ValueError("GGUF header is cut short");
    }
    return struct.unpack("<" + fmt, data)[0];
}

impl _skip_gguf_value(f: any, vtype: int) {
    if vtype in _GGUF_SCALAR_SIZES {
        f.seek(_GGUF_SCALAR_SIZES[vtype], 1);
    } elif vtype == 8 {
        f.seek(_read_le(f, "Q"), 1);
    } elif vtype == 9 {
        etype = _read_le(f, "I");
        count = _read_le(f, "Q");
        if etype in _GGUF_SCALAR_SIZES {
            f.seek(count * _GGUF_SCALAR_SIZES[etype], 1);
        } elif etype == 8 {
            for _ in range(count) {
                f.seek(_read_le(f, "Q"), 1);
            }
        } else {
            raise ValueError(f"GGUF array of type {etype}");
        }
    } else {
        raise ValueError(f"unknown GGUF value type {vtype}");
    }
}

impl _gguf_size_needed(f: any) -> int {
    if _read_le(f, "I") not in (2, 3) {
        return 0;
    }
    n_tensors = _read_le(f, "Q");
    n_kv = _read_le(f, "Q");
    alignment = 32;
    for _ in range(n_kv) {
        key_len = _read_le(f, "Q");
        key = f.read(key_len) if key_len == len(b"general.alignment") else b"";
        if not key {
            f.seek(key_len, 1);
        }
        vtype = _read_le(f, "I");
        if key == b"general.alignment" and vtype == 4 {
            alignment = _read_le(f, "I");
        } else {
            _skip_gguf_value(f, vtype);
        }
    }
    data_end = 0;
    for _ in range(n_tensors) {
        f.seek(_read_le(f, "Q"), 1);
        elements = 1;
        for _ in range(_read_le(f, "I")) {
            elements *= _read_le(f, "Q");
        }
        ttype = _read_le(f, "I");
        offset = _read_le(f, "Q");

        (block, block_bytes) = _GGML_BLOCKS.get(ttype, (1, 0));
        data_end = max(data_end, offset + elements // block * block_bytes);
    }
    header_end = f.tell();
    return -(-header_end // alignment) * alignment + data_end;
}

impl _fmt_size(mb: int) -> str {
    if mb >= 1024 {
        return f"{mb / 1024:.1f} GB";
    }
    return f"{mb} MB";
}

impl _resolve_consent(alias: str, spec: dict[str, any], auto_download: bool) -> bool {
    env = os.environ.get("BYLLM_AUTO_DOWNLOAD");
    if env is not None {
        if env.strip().lower() in ("1", "true", "yes", "y") {
            return True;
        }
        if env.strip().lower() in ("0", "false", "no", "n") {
            return False;
        }
    }
    if auto_download {
        return True;
    }
    if _consent_marker(alias).exists() {
        return True;
    }
    if not _is_interactive() {
        return False;
    }
    size = _fmt_size(int(spec.get("size_mb", 0)));
    target = alias_dir(alias);
    _emit(
        f"\n[byllm] Local model '{alias}' is not downloaded.\n"
        f"        repo: {spec['repo']}\n"
        f"        file: {spec['file']}\n"
        f"        size: ~{size}\n"
        f"        path: {target}\n"
        "        Download now? [Y/n] "
    );
    try {
        answer = input().strip().lower();
    } except EOFError {
        return False;
    }
    if answer in ("", "y", "yes") {
        target.mkdir(parents=True, exist_ok=True);
        try {
            _consent_marker(alias).write_text("1\n");
        } except OSError {}
        return True;
    }
    return False;
}

impl _download(alias: str, spec: dict[str, any], force: bool = False) -> Path {
    try {
        import from huggingface_hub { hf_hub_download }
    } except ImportError {
        raise ImportError(
            "huggingface_hub is required to download local model weights. "
            "Install with: pip install 'byllm[local]'"
        );
    }
    target_dir = alias_dir(alias);
    target_dir.mkdir(parents=True, exist_ok=True);
    _logger.info(f"Downloading {spec['repo']}/{spec['file']} -> {target_dir}");
    _emit(
        f"[byllm] Downloading {spec['repo']}/{spec['file']} (~{_fmt_size(
            int(spec.get('size_mb', 0))
        )})...\n"
    );
    path = hf_hub_download(
        repo_id=spec["repo"],
        filename=spec["file"],
        local_dir=str(target_dir),
        force_download=force,
    );
    return Path(path);
}

impl ensure_model(
    alias: str, spec: dict[str, any], auto_download: bool = False
) -> str {
    if is_downloaded(alias, spec) {
        return str(gguf_path(alias, spec));
    }
    if not _resolve_consent(alias, spec, auto_download) {
        raise RuntimeError(
            f"Local model '{alias}' is not downloaded and auto-download is disabled "
            f"in this context (no TTY). Run: jac model pull {alias}"
        );
    }

    _download(alias, spec, force=gguf_path(alias, spec).exists());
    if not is_downloaded(alias, spec) {
        raise RuntimeError(
            f"Download for '{alias}' completed but file is missing or not a GGUF file: "
            f"{gguf_path(alias, spec)}"
        );
    }
    return str(gguf_path(alias, spec));
}

impl force_pull(alias: str, spec: dict[str, any]) -> str {
    return ensure_model(alias, spec, auto_download=True);
}

impl remove_alias(alias: str) -> bool {
    import shutil;
    d = alias_dir(alias);
    if not d.exists() {
        return False;
    }
    shutil.rmtree(d);
    return True;
}

impl list_downloaded -> list[dict[str, any]] {
    cache_root = get_cache_dir();
    if not cache_root.exists() {
        return [];
    }
    out: list[dict[str, any]] = [];
    for child in cache_root.iterdir() {
        if not child.is_dir() {
            continue;
        }
        total = 0;
        files: list[str] = [];
        for f in child.rglob("*") {
            if f.is_file() and not f.name.startswith(".jac_") {
                total += f.stat().st_size;
                files.append(f.name);
            }
        }
        if files {
            out.append({"alias": child.name, "size_bytes": total, "files": files});
        }
    }
    return out;
}
