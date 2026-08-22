import hashlib;
import os;
import shutil;
import tarfile;
import time;
import from compression.zstd { ZstdFile }
import from io { BytesIO }
import from .trailer {
    MAGIC,
    OVERLAY_MAGIC,
    TRAILER_LEN,
    Trailer,
    parse_trailer,
    region_start,
    rt_key,
    rt_key_pathhash
}
import from ._libc { read_at, getuid, listdir }
import from .report { die, say }

obj Overlay {
    has off: int = 0,
        length: int = 0;
}

def trailer_at(path: str, end: int, magic: bytes) -> Trailer | None {
    if end < TRAILER_LEN {
        return None;
    }
    return parse_trailer(read_at(path, end - TRAILER_LEN, TRAILER_LEN), magic);
}

def:pub peek_overlay(exe_path: str, total: int) -> Overlay | None {
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

def:pub overlay_for_path(exe_path: str) -> Overlay | None {
    total = os.path.getsize(exe_path);
    if total < TRAILER_LEN {
        return None;
    }
    return peek_overlay(exe_path, total);
}

def dir_writable(path: str) -> bool {
    os.makedirs(path, exist_ok=True);
    if not os.path.isdir(path) {
        return False;
    }
    probe = path + "/.jac-write-probe";
    with open(probe, "wb") as f {
        f.write(b"");
    }
    if not os.path.isfile(probe) {
        return False;
    }
    os.remove(probe);
    return True;
}

def:pub cache_root -> str {
    base: str = os.environ.get("XDG_CACHE_HOME", "");
    if base == "" {
        home: str = os.environ.get("HOME", "");
        if home != "" {
            base = home + "/.cache";
        }
    }
    if base != "" {
        preferred: str = base + "/jac";
        if dir_writable(preferred) {
            return preferred;
        }
    }
    tmp: str = os.environ.get("TMPDIR", "");
    if tmp == "" {
        tmp = "/tmp";
    }
    fallback: str = f"{tmp}/jac-cache-{getuid()}";
    if not dir_writable(fallback) {
        die("no writable cache directory (set XDG_CACHE_HOME or TMPDIR)");
        return "";
    }
    return fallback;
}

def:pub materialize(exe_path: str) -> str {
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
    key = rt_key(trailer.hash16(), exe_path);
    rt = f"{cache_dir}/rt/{key}";
    if os.path.isfile(rt + "/.ok") {
        return rt;
    }

    t0 = time.monotonic();
    say("first run, performing one-time setup...");
    say(f"  runtime cache: {rt}");
    say(f"  reading embedded payload ({trailer.payload_len // 1048576} MiB)...");
    poff = region_start(total, trailer.payload_len);
    if poff < 0 {
        die("corrupt payload trailer (length exceeds the binary)");
        return "";
    }
    zbuf = read_at(exe_path, poff, trailer.payload_len);
    if len(zbuf) != trailer.payload_len {
        die("short read of the embedded payload");
        return "";
    }
    say("  verifying payload (sha256)...");
    if hashlib.sha256(zbuf).hexdigest() != trailer.hash_hex {
        die("payload integrity check failed (truncated or tampered binary)");
        return "";
    }
    extract_payload(zbuf, rt);
    gc_stale(cache_dir, key);
    secs = time.monotonic() - t0;
    say(f"one-time setup complete ({secs:.1f}s).");
    return rt;
}

def:pub extract_payload(zbuf: bytes, rt: str) {
    tmp = f"{rt}.tmp.{os.getpid()}";
    if os.path.isdir(tmp) {
        shutil.rmtree(tmp);
    }
    os.makedirs(tmp, exist_ok=True);
    say("  extracting runtime...");
    tf = tarfile.open(fileobj=ZstdFile(BytesIO(zbuf)), mode="r|");
    tf.extractall(tmp);
    tf.close();
    with open(tmp + "/.ok", "wb") as f {
        f.write(b"");
    }
    os.makedirs(os.path.dirname(rt), exist_ok=True);
    os.rename(tmp, rt);
    if not os.path.isfile(rt + "/.ok") {
        if os.path.isdir(tmp) {
            shutil.rmtree(tmp);
        }
        die("could not publish the extracted runtime");
    }
}

def:pub gc_stale(cache_dir: str, keep_key: str) {
    rtdir = cache_dir + "/rt";
    mine = rt_key_pathhash(keep_key);
    for name in listdir(rtdir) {
        if name == keep_key or ".tmp." in name {
            continue;
        }
        if rt_key_pathhash(name) != mine {
            continue;
        }
        full = f"{rtdir}/{name}";
        if not os.path.isdir(full) {
            continue;
        }
        say(f"  removing stale runtime {full}...");
        shutil.rmtree(full);
    }
}
