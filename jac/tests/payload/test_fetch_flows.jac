"""The fetch subcommands end to end, offline: `http_get` is swapped for an
in-memory server so fetch-pbs, fetch-typeshed, and fetch-bun run their real
verify + extract + idempotence logic against synthetic release assets."""

import contextlib;
import gzip;
import hashlib;
import io;
import os;
import shutil;
import tarfile;
import tempfile;
import zipfile;

import jaclang.payload.fetch as fetch_mod;
import from compression.zstd { compress }
import from jaclang.payload.cli { main }
import from jaclang.payload.fetch { BUN_VERSION, BUN_BASE, TYPESHED_TARBALL_BASE }
import from jaclang.payload.fsutil { PayloadDie, extract_tar }
import from jaclang.payload.pins { pins }

# tarfile/zipfile constants are `Final` in typeshed, which the checker cannot
# assign from; spell them as the values they are (pinned by the first test).
glob TAR_DIRTYPE: bytes = b"5",
     TAR_SYMTYPE: bytes = b"2",
     ZIP_DEFLATED: int = 8;

"""Build an in-memory tar of `(name, data, mode)` regular files (a `name`
ending in "/" is a directory; a `(name, target, "symlink")` row is a symlink)."""
def make_tar(rows: list) -> bytes {
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w") as tf {
        for row in rows {
            (name, data, mode) = row;
            ti = tarfile.TarInfo(name);
            ti.mtime = 1_700_000_000;
            ti.uid = 1000;
            ti.gid = 1000;
            if name.endswith("/") {
                ti.type = TAR_DIRTYPE;
                ti.mode = 0o755;
                tf.addfile(ti);
            } elif mode == "symlink" {
                ti.type = TAR_SYMTYPE;
                ti.linkname = data;
                tf.addfile(ti);
            } else {
                ti.size = len(data);
                ti.mode = mode;
                tf.addfile(ti, io.BytesIO(data));
            }
        }
    }
    return buf.getvalue();
}

def rf(path: str) -> bytes {
    with open(path, "rb") as f {
        return f.read();
    }
}

"""Swap fetch.http_get for a url -> bytes table for the duration of `body`."""
obj FakeHttp {
    has table: dict[str, bytes] = {},
        calls: list[str] = [],
        saved: object = None;

    def serve(url: str) -> bytes {
        self.calls.append(url);
        if url not in self.table {
            raise AssertionError(f"unexpected fetch: {url}");
        }
        return self.table[url];
    }

    def install {
        self.saved = fetch_mod.http_get;
        setattr(fetch_mod, "http_get", self.serve);
    }

    def uninstall {
        setattr(fetch_mod, "http_get", self.saved);
    }
}

test "archive constants mirror the stdlib" {
    assert TAR_DIRTYPE == tarfile.DIRTYPE;
    assert TAR_SYMTYPE == tarfile.SYMTYPE;
    assert ZIP_DEFLATED == zipfile.ZIP_DEFLATED;
}

test "extract_tar: strip_components, exec-bit-only modes, symlinks, parent dirs" {
    tar = make_tar(
        [
            ("top/", b"", 0),
            ("top/python/bin/python3.14", b"#!/bin/sh\n", 0o750),
            ("top/python/bin/python3", "python3.14", "symlink"),
            ("top/python/lib/README", b"readme\n", 0o600),
            ("top/python/PYTHON.json", b"{}", 0o644),
            ("shallow", b"dropped\n", 0o644)
        ]
    );
    base = tempfile.mkdtemp(prefix="jac-payload-extract-");
    try {
        dest = os.path.join(base, "d");
        extract_tar(tar, dest, 1, True);
        py = os.path.join(dest, "python", "bin", "python3.14");
        assert rf(py) == b"#!/bin/sh\n";
        assert (os.stat(py).st_mode & 0o111) == 0o111 , "owner exec bit -> all exec bits";
        readme = os.path.join(dest, "python", "lib", "README");
        assert (os.stat(readme).st_mode & 0o111) == 0 , "tar mode 0600 must not leak";
        assert (os.stat(readme).st_mode & 0o444) != 0 , "default mode is readable";
        link = os.path.join(dest, "python", "bin", "python3");
        assert os.path.islink(link) and os.readlink(link) == "python3.14";
        assert rf(link) == b"#!/bin/sh\n";
        assert os.path.isfile(os.path.join(dest, "python", "PYTHON.json"));
        assert not os.path.exists(os.path.join(dest, "shallow")) , "fewer components than stripped -> skipped";
        assert not os.path.exists(os.path.join(dest, "top"));

        dest2 = os.path.join(base, "e");
        extract_tar(tar, dest2, 0, False);
        py2 = os.path.join(dest2, "top", "python", "bin", "python3.14");
        assert (os.stat(py2).st_mode & 0o111) == 0 , "mode-ignoring extract keeps the default";
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "fetch-pbs verifies SHA256SUMS, extracts python/, and is idempotent" {
    p = pins().pbs;
    plat = "x86_64-unknown-linux-gnu";
    asset = f"cpython-{p.python}+{p.tag}-{plat}-{p.flavor}.tar.zst";
    tar = make_tar(
        [
            ("python/", b"", 0),
            ("python/PYTHON.json", b'{"python_version": "3.14.6"}\n', 0o644),
            ("python/install/bin/python3.14", b"#!/bin/sh\nexec real python\n", 0o755),
            ("python/install/bin/python3", "python3.14", "symlink"),
            ("python/install/lib/libpython3.14.so.1.0", b"\x7fELF", 0o755),
            ("python/install/lib/libpython3.14.so", "libpython3.14.so.1.0", "symlink")
        ]
    );
    tarzst = compress(tar);
    sums = (
        f"{hashlib.sha256(tarzst).hexdigest()}  {asset}\n"
        f"{'0' * 64}  cpython-other.tar.zst\n"
    ).encode();
    http = FakeHttp(
        table={
            f"{p.base}/{p.tag}/{asset}": tarzst,
            f"{p.base}/{p.tag}/SHA256SUMS": sums
        },
        calls=[]
    );
    base = tempfile.mkdtemp(prefix="jac-payload-pbs-");
    http.install();
    try {
        dest = os.path.join(base, "pbs");
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-pbs", "linux-x86_64", dest]) == 0;
        }
        assert f"fetch-pbs: downloading {asset}\n" in err.getvalue();
        assert f"fetch-pbs: ready at {dest}/python\n" in err.getvalue();
        marker = os.path.join(dest, "python", "PYTHON.json");
        assert os.path.isfile(marker);
        py = os.path.join(dest, "python", "install", "bin", "python3.14");
        assert (os.stat(py).st_mode & 0o111) == 0o111 , "the bundled python keeps its exec bit";
        assert os.path.islink(
            os.path.join(dest, "python", "install", "lib", "libpython3.14.so")
        );
        assert len(http.calls) == 2;

        # Idempotent: the marker short-circuits before any fetch.
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-pbs", "linux-x86_64", dest]) == 0;
        }
        assert err.getvalue() == f"fetch-pbs: already present at {dest}/python\n";
        assert len(http.calls) == 2;

        # A swapped asset is refused.
        http.table[f"{p.base}/{p.tag}/{asset}"] = tarzst + b"x";
        dest2 = os.path.join(base, "pbs2");
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-pbs", "linux-x86_64", dest2]) == 1;
        }
        assert err.getvalue().startswith(
            f"fetch-pbs: downloading {asset}\npayload: fetch-pbs: checksum mismatch for {asset}\n  expected "
        );
        assert not os.path.exists(os.path.join(dest2, "python"));
    } finally {
        http.uninstall();
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "fetch-typeshed pins the decompressed tar sha, lifts stdlib + LICENSE, stamps the commit" {
    commit = "0123456789abcdef0123456789abcdef01234567";
    tar = make_tar(
        [
            (f"typeshed-{commit}/", b"", 0),
            (f"typeshed-{commit}/LICENSE", b"Apache-2.0\n", 0o644),
            (f"typeshed-{commit}/README.md", b"nope\n", 0o644),
            (f"typeshed-{commit}/stdlib/VERSIONS", b"os: 3.0-\n", 0o644),
            (
                f"typeshed-{commit}/stdlib/os/__init__.pyi",
                b"def getcwd() -> str: ...\n",
                0o644
            ),
            (f"typeshed-{commit}/stdlib/@tests/test_os.py", b"assert False\n", 0o644),
            (f"typeshed-{commit}/stubs/requests/METADATA.toml", b"version = 1\n", 0o644)
        ]
    );
    gz = gzip.compress(tar, mtime=0);
    http = FakeHttp(table={f"{TYPESHED_TARBALL_BASE}/{commit}": gz}, calls=[]);
    base = tempfile.mkdtemp(prefix="jac-payload-ts-");
    http.install();
    try {
        vendor = os.path.join(base, "jaclang", "vendor", "typeshed");
        os.makedirs(vendor);
        with open(os.path.join(vendor, "PIN"), "w") as f {
            f.write(commit + "\n");
        }
        with open(os.path.join(vendor, "TARBALL_SHA256"), "w") as f {
            f.write(hashlib.sha256(tar).hexdigest() + "\n");
        }
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-typeshed", base]) == 0;
        }
        assert err.getvalue()
            == f"fetch-typeshed: fetching typeshed @ {commit}\nfetch-typeshed: ready ({commit})\n";
        assert rf(os.path.join(vendor, "stdlib", "VERSIONS")) == b"os: 3.0-\n";
        assert os.path.isfile(os.path.join(vendor, "stdlib", "os", "__init__.pyi"));
        assert not os.path.exists(os.path.join(vendor, "stdlib", "@tests"));
        assert rf(os.path.join(vendor, "LICENSE")) == b"Apache-2.0\n";
        assert rf(os.path.join(vendor, "stdlib", ".typeshed-sha")) == commit.encode();
        assert not os.path.exists(os.path.join(vendor, ".ts-extract"));
        assert not os.path.exists(os.path.join(vendor, "stubs"));
        assert len(http.calls) == 1;

        # At the pin: no fetch at all.
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-typeshed", base]) == 0;
        }
        assert err.getvalue() == "" and len(http.calls) == 1;

        # A bumped PIN re-fetches; a wrong TARBALL_SHA256 is refused.
        with open(os.path.join(vendor, "TARBALL_SHA256"), "w") as f {
            f.write("f" * 64);
        }
        with open(os.path.join(vendor, "stdlib", ".typeshed-sha"), "w") as f {
            f.write("stale");
        }
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-typeshed", base]) == 1;
        }
        assert err.getvalue().startswith(
            f"fetch-typeshed: fetching typeshed @ {commit}\npayload: fetch-typeshed: tarball checksum mismatch @ {commit}\n"
        );
        assert len(http.calls) == 2;
    } finally {
        http.uninstall();
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "fetch-bun verifies SHASUMS256.txt and writes the zip's bun member" {
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w") as zf {
        zf.writestr(
            "bun-linux-x64/bun", b"\x7fELF bun\n" * 2048, compress_type=ZIP_DEFLATED
        );
    }
    zip_bytes = buf.getvalue();
    sums = f"{hashlib.sha256(zip_bytes).hexdigest()}  bun-linux-x64.zip\n".encode();
    http = FakeHttp(
        table={
            f"{BUN_BASE}/bun-v{BUN_VERSION}/bun-linux-x64.zip": zip_bytes,
            f"{BUN_BASE}/bun-v{BUN_VERSION}/SHASUMS256.txt": sums
        },
        calls=[]
    );
    base = tempfile.mkdtemp(prefix="jac-payload-bun-");
    http.install();
    try {
        dest = os.path.join(base, "bun-build");
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-bun", "linux-x86_64", dest]) == 0;
        }
        out = os.path.join(dest, "bun");
        assert rf(out) == b"\x7fELF bun\n" * 2048;
        assert err.getvalue()
            == f"fetch-bun: downloading bun-linux-x64.zip\nfetch-bun: ready at {out} (0 MiB)\n";

        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-bun", "linux-x86_64", dest]) == 0;
        }
        assert err.getvalue() == f"fetch-bun: already present at {out}\n";
        assert len(http.calls) == 2;

        http.table[f"{BUN_BASE}/bun-v{BUN_VERSION}/SHASUMS256.txt"] = b"";
        err = io.StringIO();
        with contextlib.redirect_stderr(err) {
            assert main(["fetch-bun", "linux-x86_64", os.path.join(base, "other")])
                == 1;
        }
        assert "payload: fetch-bun: no checksum for bun-linux-x64.zip in SHASUMS256.txt\n"
            in err.getvalue();
    } finally {
        http.uninstall();
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "typeshed-sha prints the decompressed tar digest on stdout" {
    tar = make_tar([("typeshed-abc/stdlib/VERSIONS", b"x\n", 0o644)]);
    http = FakeHttp(
        table={f"{TYPESHED_TARBALL_BASE}/abc": gzip.compress(tar, mtime=0)}, calls=[]
    );
    http.install();
    try {
        out = io.StringIO();
        with contextlib.redirect_stdout(out) {
            assert main(["typeshed-sha", "abc"]) == 0;
        }
        assert out.getvalue() == hashlib.sha256(tar).hexdigest() + "\n";
    } finally {
        http.uninstall();
    }
}
