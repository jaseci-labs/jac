import hashlib;
import os;
import sys;
import from pathlib { Path }
import from jaclang.dist.fused.trailer {
    MAGIC,
    OVERLAY_MAGIC,
    TRAILER_LEN,
    Trailer,
    build_trailer,
    parse_trailer,
    region_start,
    rt_key
}

def fused_base_length(data: bytes) -> int {
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

def has_runtime(path: str = "") -> bool {
    exe = Path(path or os.path.realpath(sys.executable));
    if not exe.is_file() {
        return False;
    }
    return fused_base_length(exe.read_bytes()) >= 0;
}

def append_overlay(base_path: str, jab_path: str, out_path: str) -> bool {
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

def graft_runtime(self_path: str, host_path: str) -> bool {
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


def runtime_trailer(exe: str) -> (Trailer | None) {
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
    return parse_trailer(tail, MAGIC);
}


def running_executable -> str {
    return os.environ.get("JAC_EXECUTABLE", "") or os.path.realpath(sys.executable);
}


def running_runtime_key(path: str = "") -> str {
    t = runtime_trailer(path or running_executable());
    return rt_key(t.hash16()) if t is not None else "";
}


def interpreter_runtime_dir -> (str | None) {
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


def _runtime_dir_for_key(key: str) -> (str | None) {
    import from jaclang.cache.registry { bucket }
    if not key {
        return None;
    }
    roots = [str(bucket("rt").path())];
    legacy = os.path.join(
        os.environ.get("XDG_CACHE_HOME", "")
            or os.path.join(os.path.expanduser("~"), ".cache"),
        "jac",
        "rt"
    );
    if legacy not in roots {
        roots.append(legacy);
    }
    tmp = os.environ.get("TMPDIR", "") or "/tmp";
    roots.append(os.path.join(tmp, f"jac-cache-{os.getuid()}", "rt"));
    for r in roots {
        cand = os.path.join(r, key);
        if os.path.isfile(os.path.join(cand, ".ok")) {
            return cand;
        }
    }
    return None;
}


def materialized_runtime_dir(path: str = "") -> (str | None) {
    if not path {
        here = interpreter_runtime_dir();
        if here is not None {
            return here;
        }
    }
    return _runtime_dir_for_key(running_runtime_key(path));
}


def running_runtime_entries -> set[str] {
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


def bundled_floor_roots(pkg_root: str) -> list[str] {
    roots: list[str] = [os.path.join(os.path.dirname(pkg_root), "python", "floor")];
    dev_src = os.environ.get("JAC_DEV_SOURCE", "");
    if dev_src and os.path.realpath(dev_src) == os.path.realpath(pkg_root) {
        rt = materialized_runtime_dir();
        if rt is not None {
            roots.append(os.path.join(rt, "python", "floor"));
        }
    }
    return roots;
}
