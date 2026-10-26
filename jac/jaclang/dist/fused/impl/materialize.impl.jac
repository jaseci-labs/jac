impl trailer_at(path: str, end: int, magic: bytes) -> Trailer | None {
    if end < TRAILER_LEN {
        return None;
    }
    return parse_trailer(read_at(path, end - TRAILER_LEN, TRAILER_LEN), magic);
}

impl peek_overlay(exe_path: str, total: int) -> Overlay | None {
    t = trailer_at(exe_path, total, OVERLAY_MAGIC);
    if t is None {
        return None;
    }
    off = region_start(total, t.payload_len);
    if off < 0 {
        die("corrupt app overlay (length exceeds the binary)");
        return None;
    }
    return Overlay(off=off, length=t.payload_len);
}

impl overlay_for_path(exe_path: str) -> Overlay | None {
    total = os.path.getsize(exe_path);
    if total < TRAILER_LEN {
        return None;
    }
    return peek_overlay(exe_path, total);
}

impl dir_writable(path: str) -> bool {
    os.makedirs(path, exist_ok=True);
    if not os.path.isdir(path) {
        return False;
    }
    probe = path + "/.jac-write-probe";
    if not write_file(probe, b"") {
        return False;
    }
    os.remove(probe);
    return True;
}

impl stamp_cachedir_tag(base: str) {
    tag = base + "/" + CACHEDIR_TAG;
    if not os.path.isfile(tag) {
        write_file(tag, CACHEDIR_TAG_TEXT);
    }
}

impl prepare_cache_root(base: str) {
    tag = base + "/" + CACHEDIR_TAG;
    if os.path.isfile(tag) {
        if read_at(tag, 0, len(CACHEDIR_TAG_TEXT)) == CACHEDIR_TAG_TEXT
            and os.path.getsize(tag) == len(CACHEDIR_TAG_TEXT) {
            os.remove(tag);
        }
    }

    rt = base + "/rt";
    os.makedirs(rt, exist_ok=True);
    stamp_cachedir_tag(rt);
}

impl cache_root -> str {
    home: str = os.environ.get("HOME", "");
    base: str = os.environ.get("JAC_CACHE_HOME", "");
    if base != "" {
        if base.startswith("~/") and home != "" {
            base = home + base[1:len(base)];
        }
    } else {
        xdg: str = os.environ.get("XDG_CACHE_HOME", "");
        if xdg != "" {
            base = xdg + "/jac";
        } elif home != "" {
            base = platform_cache_home(home);
        }
    }
    if base != "" and dir_writable(base) {
        prepare_cache_root(base);
        return base;
    }
    tmp: str = os.environ.get("TMPDIR", "");
    if tmp == "" {
        tmp = "/tmp";
    }
    fallback: str = f"{tmp}/jac-cache-{int(getuid())}";
    if not dir_writable(fallback) {
        die("no writable cache directory (set JAC_CACHE_HOME or TMPDIR)");
        return "";
    }
    prepare_cache_root(fallback);
    return fallback;
}

impl materialize(exe_path: str) -> str {
    total = os.path.getsize(exe_path);
    if total < TRAILER_LEN {
        die("binary too small to carry a runtime payload");
        return "";
    }
    ovl = peek_overlay(exe_path, total);
    if ovl is not None {
        total = ovl.off;
    }
    trailer = trailer_at(exe_path, total, MAGIC);
    if trailer is None {
        die("no runtime payload trailer (this is not a bundled jac binary)");
        return "";
    }
    cache_dir = cache_root();
    key = rt_key(trailer.hash16());
    rt = f"{cache_dir}/rt/{key}";
    if not os.path.isfile(rt + "/.ok") {
        first_run(exe_path, total, trailer, rt);
    }
    mark_used(rt);
    sweep_runtimes(cache_dir, key);
    return rt;
}

impl first_run(exe_path: str, total: int, trailer: Trailer, rt: str) {
    t0 = time.monotonic();
    say("first run, performing one-time setup...");
    say(f"  runtime cache: {rt}");
    say(f"  reading embedded payload ({trailer.payload_len // 1048576} MiB)...");
    poff = region_start(total, trailer.payload_len);
    if poff < 0 {
        die("corrupt payload trailer (length exceeds the binary)");
        return;
    }
    zbuf = read_at(exe_path, poff, trailer.payload_len);
    if len(zbuf) != trailer.payload_len {
        die("short read of the embedded payload");
        return;
    }
    say("  verifying payload (sha256)...");
    if hashlib.sha256(zbuf).hexdigest() != trailer.hash_hex {
        die("payload integrity check failed (truncated or tampered binary)");
        return;
    }
    extract_payload(zbuf, rt);
    secs = time.monotonic() - t0;
    say(f"one-time setup complete ({secs:.1f}s).");
}

impl extract_payload(zbuf: bytes, rt: str) {
    tmp = f"{rt}.tmp.{os.getpid()}";
    if os.path.isdir(tmp) {
        shutil.rmtree(tmp, ignore_errors=True);
    }
    os.makedirs(tmp, exist_ok=True);
    say("  extracting runtime...");
    tf = tarfile.open(fileobj=ZstdFile(BytesIO(zbuf)), mode="r|");
    tf.extractall(tmp);
    tf.close();
    if not write_file(tmp + "/.ok", b"") {
        shutil.rmtree(tmp, ignore_errors=True);
        die(f"could not mark the extracted runtime complete ({tmp}/.ok)");
    }
    os.makedirs(os.path.dirname(rt), exist_ok=True);
    os.rename(tmp, rt);
    if os.path.isdir(tmp) {
        shutil.rmtree(tmp, ignore_errors=True);
    }
    if not os.path.isfile(rt + "/.ok") {
        die("could not publish the extracted runtime");
    }
}

impl mark_used(rt: str) {
    write_file(rt + "/" + USED_MARKER, b"");
}

impl runtime_ttl_seconds -> float {
    raw: str = os.environ.get(TTL_ENV, "");
    days: int = RUNTIME_TTL_DAYS;
    if raw != "" {
        days = int(atoi(raw));
        if days < 0 {
            days = 0;
        }
    }
    return float(days) * 86400.0;
}

impl last_used(rt: str) -> float {
    for marker in [USED_MARKER, ".ok"] {
        stamp = rt + "/" + marker;
        if os.path.isfile(stamp) {
            return os.path.getmtime(stamp);
        }
    }
    return os.path.getmtime(rt);
}

impl sweep_runtimes(cache_dir: str, keep_key: str) {
    rtdir = cache_dir + "/rt";
    now = time.time();
    sentinel = rtdir + "/" + SWEEP_SENTINEL;
    if os.path.isfile(sentinel)
        and now - os.path.getmtime(sentinel) < SWEEP_INTERVAL_SECONDS {
        return;
    }
    if not write_file(sentinel, b"") {
        return;
    }
    ttl = runtime_ttl_seconds();
    for name in listdir(rtdir) {
        if name == keep_key or name.startswith(".") {
            continue;
        }
        full = f"{rtdir}/{name}";
        if not os.path.isdir(full) {
            continue;
        }
        if ".tmp." in name {
            if now - os.path.getmtime(full) > TMP_TTL_SECONDS {
                say(f"  removing abandoned extraction {full}...");
                shutil.rmtree(full, ignore_errors=True);
            }
            continue;
        }
        if ttl > 0.0 and now - last_used(full) > ttl {
            say(f"  removing unused runtime {full}...");
            shutil.rmtree(full, ignore_errors=True);
        }
    }
}
