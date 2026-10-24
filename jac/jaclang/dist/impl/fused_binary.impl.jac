impl fused_base_length(data: bytes) -> int {
    total = len(data);
    if total < TRAILER_LEN {
        return -1;
    }
    ovl = parse_trailer(data[total - TRAILER_LEN:], OVERLAY_MAGIC);
    if ovl is not None {
        total = region_start(total, ovl.payload_len);
        if total < TRAILER_LEN {
            return -1;
        }
    }
    if parse_trailer(data[total - TRAILER_LEN:], MAGIC) is None {
        return -1;
    }
    return total;
}

impl has_runtime(path: str = "") -> bool {
    exe = Path(path or os.path.realpath(sys.executable));
    if not exe.is_file() {
        return False;
    }
    return fused_base_length(exe.read_bytes()) >= 0;
}

impl append_overlay(base_path: str, jab_path: str, out_path: str) -> bool {
    base = Path(base_path).read_bytes();
    if len(base) < TRAILER_LEN or parse_trailer(base[-TRAILER_LEN:], MAGIC) is None {
        return False;
    }
    jab = Path(jab_path).read_bytes();
    out = Path(out_path);
    out.write_bytes(
        base
            + jab
            + build_trailer(OVERLAY_MAGIC, len(jab), hashlib.sha256(jab).hexdigest())
    );
    out.chmod(0o755);
    return True;
}

impl graft_runtime(self_path: str, host_path: str) -> bool {
    data = Path(self_path).read_bytes();
    base_total = fused_base_length(data);
    if base_total < 0 {
        return False;
    }
    t = parse_trailer(data[base_total - TRAILER_LEN:base_total], MAGIC);
    if t is None {
        return False;
    }
    start = region_start(base_total, t.payload_len);
    if start < 0 {
        return False;
    }
    with open(host_path, "ab") as f {
        f.write(data[start:base_total]);
    }
    return True;
}

impl _runtime_tail(exe: str) -> (tuple[int, Trailer] | None) {
    if not os.path.isfile(exe) {
        return None;
    }
    total = os.path.getsize(exe);
    if total < TRAILER_LEN {
        return None;
    }
    with open(exe, "rb") as f {
        f.seek(total - TRAILER_LEN);
        tail = f.read(TRAILER_LEN);
        ovl = parse_trailer(tail, OVERLAY_MAGIC);
        if ovl is not None {
            total = region_start(total, ovl.payload_len);
            if total < TRAILER_LEN {
                return None;
            }
            f.seek(total - TRAILER_LEN);
            tail = f.read(TRAILER_LEN);
        }
    }
    found = parse_trailer(tail, MAGIC);
    return (total, found) if found is not None else None;
}

impl runtime_trailer(exe: str) -> (Trailer | None) {
    found = _runtime_tail(exe);
    return found[1] if found is not None else None;
}

impl stubcat_region(exe: str = "") -> (Region | None) {
    path = exe or running_executable();
    found = _runtime_tail(path);
    if found is None {
        return None;
    }
    (total, trailer) = found;
    payload_start = region_start(total, trailer.payload_len);
    if payload_start < REGION_DESC_LEN {
        return None;
    }
    with open(path, "rb") as f {
        f.seek(payload_start - REGION_DESC_LEN);
        desc = parse_region_desc(f.read(REGION_DESC_LEN));
    }
    if desc is None or desc.length <= 0 or desc.off + desc.length > payload_start {
        return None;
    }
    return desc;
}

impl running_executable -> str {
    return process_executable();
}

impl jac_binary -> str {
    """This process's executable when it is a fused jac binary, else empty.""";
    exe = running_executable();
    return exe if runtime_trailer(exe) is not None else "";
}

impl running_runtime_key(path: str = "") -> str {
    t = runtime_trailer(path or running_executable());
    return rt_key(t.hash16()) if t is not None else "";
}

impl interpreter_runtime_dir -> (str | None) {
    try {
        cand = Path(sys.prefix).resolve().parent;
    } except OSError {
        return None;
    }
    if (cand / ".ok").is_file() and (cand / "python").is_dir() {
        return str(cand);
    }
    return None;
}

impl _runtime_dir_for_key(key: str) -> (str | None) {
    if not key {
        return None;
    }
    roots = [str(bucket("rt").path())];
    if os.name == "posix" {
        tmp = os.environ.get("TMPDIR", "") or "/tmp";
        roots.append(os.path.join(tmp, f"jac-cache-{os.getuid()}", "rt"));
    }
    for r in roots {
        cand = os.path.join(r, key);
        if os.path.isfile(os.path.join(cand, ".ok")) {
            return cand;
        }
    }
    return None;
}

impl materialized_runtime_dir(path: str = "") -> (str | None) {
    if not path {
        here = interpreter_runtime_dir();
        if here is not None {
            return here;
        }
    }
    return _runtime_dir_for_key(running_runtime_key(path));
}

impl running_runtime_entries -> set[str] {
    names: set[str] = set();
    here = interpreter_runtime_dir();
    if here is not None {
        names.add(os.path.basename(here));
    }
    key = running_runtime_key();
    if key {
        names.add(key);
    }
    return names;
}
