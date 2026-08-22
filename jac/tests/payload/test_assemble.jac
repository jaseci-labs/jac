"""mkpayload's tar + zstd stage: deterministic tar bytes, the deps/jac frame
split, the content-addressed layer cache with decompress-and-compare
verification, and the floor staging allow-list."""

import io;
import os;
import shutil;
import tarfile;
import tempfile;

import from compression.zstd {
    CompressionParameter,
    ZstdDecompressor,
    compress,
    decompress
}
import from jaclang.payload.assemble {
    PAYLOAD_WINDOW_LOG,
    TAR_DIRTYPE,
    TAR_PAX_FORMAT,
    TAR_REGTYPE,
    collect_stage_entries,
    is_volatile_path,
    stage_floor,
    tar_stage,
    tar_zst_dir
}
import from jaclang.payload.fsutil { host_os_arch }
import from jaclang.payload.pins { py_ver }

def wf(stage: str, rel: str, data: bytes, mode: int = 0o644) {
    p = os.path.join(stage, rel);
    os.makedirs(os.path.dirname(p), exist_ok=True);
    with open(p, "wb") as f {
        f.write(data);
    }
    os.chmod(p, mode);
}

def rf(path: str) -> bytes {
    with open(path, "rb") as f {
        return f.read();
    }
}

"""Extract a packed (multi-frame) payload the way the launcher does: decode
every frame, feed the concatenation to a tar reader."""
def extract_payload(packed: str, dest: str) {
    os.makedirs(dest, exist_ok=True);
    with tarfile.open(fileobj=io.BytesIO(decompress(rf(packed))), mode="r:") as tf {
        tf.extractall(dest, filter="data");
    }
}

"""The single `deps-*.tar.zst` in the layer cache (pruning keeps it single-entry)."""
def sole_cache_entry(cache: str) -> str {
    names = [
        n
        for n in os.listdir(cache)
        if os.path.isfile(os.path.join(cache, n))
    ];
    assert len(names) == 1 , f"expected a single cache entry, got {names}";
    assert names[0].startswith("deps-") and names[0].endswith(".tar.zst");
    return os.path.join(cache, names[0]);
}

def populate(stage: str) {
    wf(stage, "python/lib/marker.txt", b"pybytecode-marker\n");
    wf(stage, "python/bin/python3", b"#!/bin/sh\nexec fake python\n", 0o755);
    wf(stage, "site/watchdog/helper.py", b"helper = 1\n");
    wf(
        stage,
        "site/jaclang/compiler/passes/native/llvm/libjacllvm.so",
        b"fake-shim-bytes"
    );
    wf(stage, "site/jaclang/runtimelib/client/_bun/bun", b"fake-bun-bytes", 0o755);
    wf(stage, "site/jaclang/mod.py", b"version = 1\n");
    wf(stage, "site/_jac_finder.py", b"finder\n");
    os.makedirs(os.path.join(stage, "site", "empty_dir"), exist_ok=True);
}

test "tar constants mirror the stdlib" {
    assert TAR_PAX_FORMAT == tarfile.PAX_FORMAT;
    assert TAR_REGTYPE == tarfile.REGTYPE;
    assert TAR_DIRTYPE == tarfile.DIRTYPE;
}

test "tar_stage is byte-identical across two stagings and carries no host metadata" {
    base = tempfile.mkdtemp(prefix="jac-payload-tar-");
    try {
        a = os.path.join(base, "a");
        b = os.path.join(base, "b");
        populate(a);
        # Same tree, different creation order and different mtimes.
        wf(b, "site/_jac_finder.py", b"finder\n");
        wf(b, "site/jaclang/mod.py", b"version = 1\n");
        populate(b);
        for (cur, dirs, files) in os.walk(b) {
            for name in files {
                os.utime(os.path.join(cur, name), (1, 1));
            }
        }

        (deps_a, jac_a) = tar_stage(a);
        (deps_b, jac_b) = tar_stage(b);
        assert deps_a == deps_b , "deps tar must not depend on walk order or mtimes";
        assert jac_a == jac_b , "jac tar must not depend on walk order or mtimes";
        assert deps_a != jac_a;
        assert len(deps_a) % 512 == 0 and len(jac_a) % 512 == 0;

        entries = [e.path for e in collect_stage_entries(a)];
        assert entries == sorted(entries, key=lambda (p: str) { p.encode("utf-8"); });

        names: list[str] = [];
        with tarfile.open(fileobj=io.BytesIO(deps_a), mode="r:") as tf {
            for m in tf {
                names.append(m.name.rstrip("/"));
                assert m.mtime == 0 and m.uid == 0 and m.gid == 0;
                assert m.uname == "" and m.gname == "";
                if m.name.rstrip("/") == "python/bin/python3" {
                    assert m.mode == 0o755 , "real on-disk mode rides the header";
                }
                if m.name.rstrip("/") == "python/lib/marker.txt" {
                    assert m.mode == 0o644;
                }
                if m.isdir() {
                    assert m.mode == 0o755;
                }
            }
        }
        assert "python/lib/marker.txt" in names;
        assert "site/jaclang/compiler/passes/native/llvm/libjacllvm.so" in names;
        assert "site/jaclang/runtimelib/client/_bun/bun" in names;
        assert "site/empty_dir" in names;
        assert "site/jaclang/mod.py" not in names;
        assert "site/_jac_finder.py" not in names;

        jac_names: list[str] = [];
        with tarfile.open(fileobj=io.BytesIO(jac_a), mode="r:") as tf {
            jac_names = [m.name.rstrip("/") for m in tf];
        }
        assert "site/jaclang/mod.py" in jac_names;
        assert "site/_jac_finder.py" in jac_names;
        assert "site/jaclang" in jac_names;
        assert "python/lib/marker.txt" not in jac_names;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "is_volatile_path routes the compiler tree and site shims to the jac frame" {
    table = [
        ("site/jaclang/mod.py", True),
        ("site/jaclang", True),
        ("site/jaclang/jac0core/unitree.jac", True),
        ("site/jaclang/_precompiled/MANIFEST.json", True),
        ("site/jaclang-0.36.1.dist-info/METADATA", True),
        ("site/jaclang/compiler/passes/native/llvm/libjacllvm.so", False),
        ("site/jaclang/compiler/passes/native/llvm", False),
        ("site/jaclang/runtimelib/client/_bun/bun", False),
        ("site/jaclang/runtimelib/client/_bun", False),
        ("site/_jac_finder.py", True),
        ("site/sitecustomize.py", True),
        ("site/jac_linked_source", True),
        ("site/__pycache__", True),
        ("site/__pycache__/sitecustomize.cpython-314.pyc", True),
        ("site/watchdog/helper.py", False),
        ("site/tomlkit/__init__.py", False),
        ("site", False),
        ("python", False),
        ("python/lib/libpython3.14.so", False),
        ("python/floor/linux-x86_64/libssl.a", False),
        ("python/floor/wasm32/libc/string_strlen.bc", False),
        ("nvim/runtime/init.lua", False)
    ];
    for (path, expected) in table {
        assert is_volatile_path(path) == expected , f"{path}: expected {expected}";
    }
}

test "payload is two zstd frames whose concatenation is the full tar" {
    base = tempfile.mkdtemp(prefix="jac-payload-frames-");
    try {
        stage = os.path.join(base, "stage");
        populate(stage);
        out = os.path.join(base, "payload.tar.zst");
        tar_zst_dir(stage, out, None);
        blob = rf(out);
        (deps_tar, jac_tar) = tar_stage(stage);

        # Frame 1 decodes to exactly the deps tar; what follows is frame 2.
        d = ZstdDecompressor();
        first = d.decompress(blob);
        assert d.eof , "the first frame must end before the second begins";
        assert first == deps_tar;
        assert len(d.unused_data) > 0;
        assert decompress(d.unused_data) == jac_tar;
        assert decompress(blob) == deps_tar + jac_tar;

        # The zstd frame header must declare a window no larger than the
        # launcher's decode cap (PAYLOAD_WINDOW_LOG): a frame with a single
        # segment carries the content size instead, which is always <= that
        # cap here; otherwise the Window_Descriptor byte encodes the window.
        fhd = blob[4];
        if (fhd & 0x20) == 0 {
            wd = blob[5];
            exponent = (wd >> 3) + 10;
            assert exponent <= PAYLOAD_WINDOW_LOG , f"window log {exponent}";
        }

        dest = os.path.join(base, "x");
        extract_payload(out, dest);
        assert rf(os.path.join(dest, "python/lib/marker.txt"))
            == b"pybytecode-marker\n";
        assert rf(os.path.join(dest, "site/jaclang/mod.py")) == b"version = 1\n";
        assert rf(os.path.join(dest, "site/_jac_finder.py")) == b"finder\n";
        assert (os.stat(os.path.join(dest, "python/bin/python3")).st_mode & 0o100) != 0;
        assert (os.stat(os.path.join(dest, "python/lib/marker.txt")).st_mode & 0o100)
            == 0;
        assert os.path.isdir(os.path.join(dest, "site/empty_dir"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "layer cache: verified reuse, corruption falls back, deps edit rolls the key" {
    base = tempfile.mkdtemp(prefix="jac-payload-layers-");
    try {
        stage = os.path.join(base, "stage");
        cache = os.path.join(base, "layers");
        populate(stage);

        out1 = os.path.join(base, "p1.tar.zst");
        tar_zst_dir(stage, out1, cache);
        entry1 = sole_cache_entry(cache);
        frame1 = rf(entry1);
        p1 = rf(out1);
        assert len(p1) > len(frame1);
        assert p1[:len(frame1)] == frame1 , "the cached deps frame is the payload's byte prefix";
        extract_payload(out1, os.path.join(base, "x1"));
        assert rf(os.path.join(base, "x1", "site/jaclang/mod.py")) == b"version = 1\n";

        # (1) jaclang-only edit: deps frame identical, jac layer picks up the change.
        wf(stage, "site/jaclang/mod.py", b"version = 2\n");
        out2 = os.path.join(base, "p2.tar.zst");
        tar_zst_dir(stage, out2, cache);
        p2 = rf(out2);
        assert p2[:len(frame1)] == frame1;
        assert sole_cache_entry(cache) == entry1;
        extract_payload(out2, os.path.join(base, "x2"));
        assert rf(os.path.join(base, "x2", "site/jaclang/mod.py")) == b"version = 2\n";

        # (2) Reuse is verbatim: plant an alternative frame (different bytes,
        # same decoded tar) and expect it embedded as-is.
        deps_tar = decompress(frame1);
        alt = compress(
            deps_tar,
            options={
                CompressionParameter.compression_level: 1,
                CompressionParameter.window_log: PAYLOAD_WINDOW_LOG,
                CompressionParameter.checksum_flag: 1
            }
        );
        assert alt != frame1;
        assert decompress(alt) == deps_tar;
        with open(entry1, "wb") as f {
            f.write(alt);
        }
        out3 = os.path.join(base, "p3.tar.zst");
        tar_zst_dir(stage, out3, cache);
        p3 = rf(out3);
        assert p3[:len(alt)] == alt;
        extract_payload(out3, os.path.join(base, "x3"));
        assert rf(os.path.join(base, "x3", "python/lib/marker.txt"))
            == b"pybytecode-marker\n";

        # (3) Corrupt cache entry: verification rejects it and recompresses to
        # a correct payload, byte-identical to the honest pack.
        bad = bytearray(alt);
        bad[len(bad) // 2] ^= 0xFF;
        with open(entry1, "wb") as f {
            f.write(bytes(bad));
        }
        out4 = os.path.join(base, "p4.tar.zst");
        tar_zst_dir(stage, out4, cache);
        assert rf(out4) == p2;
        assert rf(entry1) == frame1 , "the honest frame overwrites the poisoned entry";

        # (4) Deps-side edit: new key, and the old entry is pruned away.
        wf(stage, "site/watchdog/helper.py", b"helper = 2\n");
        out5 = os.path.join(base, "p5.tar.zst");
        tar_zst_dir(stage, out5, cache);
        entry2 = sole_cache_entry(cache);
        assert entry2 != entry1;
        extract_payload(out5, os.path.join(base, "x5"));
        assert rf(os.path.join(base, "x5", "site/watchdog/helper.py"))
            == b"helper = 2\n";
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "stage_floor stages the floor allow-list + CA bundle, skips non-floor archives" {
    base = tempfile.mkdtemp(prefix="jac-payload-floor-");
    try {
        pbs = os.path.join(base, "pbs");
        for n in ("libz.a", "libssl.a", "libX11.a") {
            wf(pbs, "build/lib/" + n, b"!<arch>\n");
        }
        wf(
            pbs,
            f"install/lib/python{py_ver()}/site-packages/pip/_vendor/certifi/cacert.pem",
            b"# ca\n"
        );
        stage = os.path.join(base, "stage");
        stage_floor(pbs, stage);
        osarch = host_os_arch();
        floor = os.path.join(stage, "python", "floor");
        assert os.path.isfile(os.path.join(floor, osarch, "libz.a"));
        assert os.path.isfile(os.path.join(floor, osarch, "libssl.a"));
        assert os.path.isfile(os.path.join(floor, "cacert.pem"));
        assert not os.path.exists(os.path.join(floor, osarch, "libX11.a"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
