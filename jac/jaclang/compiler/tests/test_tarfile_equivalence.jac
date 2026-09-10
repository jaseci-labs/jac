"""Cross-backend `tarfile` extraction over `ZstdFile` equivalence.

Builds a PAX tar with CPython's `tarfile` (a >200-char path forcing a pax
extended header, an exec-bit script, nested dirs, an empty file, and a >1 MiB
file), wraps it in TWO concatenated zstd frames -- the single-binary launcher's
payload shape -- and extracts it with the launcher's exact sequence:
`ZstdFile(io.BytesIO(payload))` -> `tarfile.open(fileobj=..., mode="r|")` ->
`extractall(dest)` (default `data` filter).

The SAME fixture binds CPython's real modules on the sv reference and the
bundled `na_stdlib` (`tarfile.jac` / `compression/zstd.jac` / `io.jac`) on the na
backend, forced native (`default_codespace='native'`) so no `[placement.pins]`
entry is needed. Both extract into their own temp tree; the test then walks both
trees on the sv side and asserts an identical sorted listing of
(relative path, size, `mode & 0o777`, sha256-of-contents). ES/JS opts out."""

import ctypes;
import hashlib;
import io;
import os;
import shutil;
import tarfile;
import tempfile;
import from compression.zstd { ZstdCompressor, CompressionParameter }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.tests.xbackend_equiv {
    FIXTURES,
    run_py_fixture,
    get_func,
    remember_engine_unit
}


"""Build a deterministic PAX tar archive as bytes."""
def _build_tar -> bytes {
    buf = io.BytesIO();
    tf = tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT);
    _add_dir(tf, "pkg");
    _add_file(tf, "pkg/a.txt", b"hello\n", 0o644);
    _add_dir(tf, "pkg/bin");
    _add_file(tf, "pkg/bin/run.sh", b"#!/bin/sh\necho hi\n", 0o755);
    _add_file(tf, "pkg/" + "x" * 210 + "/deep.txt", b"deep payload\n", 0o644);
    _add_file(tf, "pkg/empty", b"", 0o644);
    _add_file(tf, "pkg/big.bin", bytes([i % 256 for i in range(1500000)]), 0o644);
    tf.close();
    return buf.getvalue();
}


def _add_dir(tf: tarfile.TarFile, name: str) {
    ti = tarfile.TarInfo(name);
    ti.type = tarfile.DIRTYPE;
    ti.mode = 0o755;
    ti.mtime = 1700000000;
    ti.uid = 1000;
    ti.gid = 1000;
    ti.uname = "builder";
    ti.gname = "builders";
    tf.addfile(ti);
}


def _add_file(tf: tarfile.TarFile, name: str, data: bytes, mode: int) {
    ti = tarfile.TarInfo(name);
    ti.size = len(data);
    ti.mode = mode;
    ti.mtime = 1700000000;
    ti.uid = 1000;
    ti.gid = 1000;
    ti.uname = "builder";
    ti.gname = "builders";
    tf.addfile(ti, io.BytesIO(data));
}


"""Compress one chunk into a single zstd frame (level 19, window log 24, no
frame checksum) -- the launcher's frame parameters."""
def _frame(data: bytes) -> bytes {
    c = ZstdCompressor(
        options={
            CompressionParameter.compression_level: 19,
            CompressionParameter.window_log: 24,
            CompressionParameter.checksum_flag: 0
        }
    );
    return c.compress(data, ZstdCompressor.FLUSH_FRAME);
}


"""Walk `root` into a sorted list of [relpath, size, mode&0o777, sha256]."""
def _tree(base: str) -> list {
    rows: list = [];
    for (dirpath, dirnames, filenames) in os.walk(base) {
        for d in dirnames {
            full = os.path.join(dirpath, d);
            rel = os.path.relpath(full, base);
            m = os.stat(full).st_mode & 0o777;
            rows.append([rel, -1, m, "dir"]);
        }
        for fn in filenames {
            full = os.path.join(dirpath, fn);
            rel = os.path.relpath(full, base);
            st = os.stat(full);
            h = hashlib.sha256(open(full, "rb").read()).hexdigest();
            rows.append([rel, st.st_size, st.st_mode & 0o777, h]);
        }
    }
    rows.sort();
    return rows;
}


def _compile_native_forced(fixture: str) -> tuple {
    prog = JacProgram();
    opts = CompileOptions(default_codespace="native");
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)), options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    remember_engine_unit(eng, ir);
    return (eng, ir);
}


test "tarfile extractall over ZstdFile (sv<->na congruent)" {
    work = tempfile.mkdtemp(prefix="jac_tarfile_eq_");
    payload_path = os.path.join(work, "payload.zst");
    dest_py = os.path.join(work, "out_py");
    dest_na = os.path.join(work, "out_na");
    try {
        raw = _build_tar();
        half = (len(raw) // 2) // 512 * 512;
        with open(payload_path, "wb") as pf {
            pf.write(_frame(raw[:half]) + _frame(raw[half:]));
        }
        os.environ["JAC_TARFILE_PAYLOAD"] = payload_path;
        os.environ["JAC_TARFILE_DEST_PY"] = dest_py;
        os.environ["JAC_TARFILE_DEST_NA"] = dest_na;

        # sv reference: CPython tarfile + compression.zstd, exact launcher path.
        py_count = run_py_fixture("prim_tarfile", "tarfile_extract_py");
        assert py_count == 7 , f"expected 7 members, got {py_count}";

        # na: bundled na_stdlib, forced native, driven through the JIT.
        (eng, ir) = _compile_native_forced("prim_tarfile.jac");
        init_addr = eng.get_function_address("jac_entry");
        if init_addr != 0 {
            ctypes.CFUNCTYPE(None)(init_addr)();
        }
        na_fn = get_func(eng, "tarfile_extract_na", ctypes.c_int64);
        na_count = int(na_fn());
        assert na_count == py_count , (
            f"member count mismatch: py={py_count} na={na_count}"
        );

        py_tree = _tree(dest_py);
        na_tree = _tree(dest_na);
        assert py_tree == na_tree , (f"tree mismatch:\n py={py_tree}\n na={na_tree}");
        # Guard that the exercise actually built the demanding members.
        names = [row[0] for row in py_tree];
        assert any("x" * 210 in n for n in names) , "long pax path missing";
        assert any(
            row[0].endswith("big.bin") and row[1] == 1500000 for row in py_tree
        ) , ("1.5 MiB file missing");
        assert any(row[0].endswith("run.sh") and row[2] == 0o755 for row in py_tree) , (
            "exec-bit script mode not preserved"
        );
    } finally {
        os.environ.pop("JAC_TARFILE_PAYLOAD", None);
        os.environ.pop("JAC_TARFILE_DEST_PY", None);
        os.environ.pop("JAC_TARFILE_DEST_NA", None);
        shutil.rmtree(work, ignore_errors=True);
    }
}
