"""Cross-backend `compression.zstd` + `io.BytesIO` equivalence.

`import from compression.zstd { ... }` binds the bundled
`na_stdlib/compression/zstd.jac` Mechanism-F surface (over the `libzstd` FFI
floor) on the na backend and CPython's real `compression.zstd` (zstd 1.5.7) on
the sv reference; `io.BytesIO` binds the bundled `na_stdlib/io.jac` on na and
CPython's `io` on sv. The fixture round-trips `compress`/`decompress` at levels
1/3/9/19, decodes a payload of TWO concatenated frames (the launcher's payload
shape) one-shot, incrementally through `ZstdDecompressor`, and streamed through
`ZstdFile(BytesIO(...)).read(chunk)`, pinning lengths + a poly digest of the
decompressed bytes.

The na fixture is compiled with the native codespace forced on
(`default_codespace='native'`), so no `[placement.pins]` entry is required, and
its per-key output is asserted equal to the CPython reference (a regression in
either backend is a hard failure). A second test pins the exact launcher decode
path -- `ZstdFile(io.BytesIO(payload))` over two frames -- byte-for-byte with a
sha256 on the sv side. ES/JS opts out (no zstd floor)."""

import hashlib;
import io;
import os;
import from compression.zstd { compress as _zc, decompress as _zd, ZstdFile }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.tests.xbackend_equiv {
    FIXTURES,
    run_py_fixture,
    run_native_function,
    compare_results,
    remember_engine_unit
}


"""Compile a fixture with the native codespace forced on and return
(engine, ir). Unlike the shared `compile_native`, this does not depend on a
`[placement.pins]` entry in the fixtures `jac.toml`: `default_codespace='native'`
coerces the whole module into the native codespace,
which is exactly what these bundled-stdlib fixtures need."""
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


test "zstd bundled (sv<->na congruent)" {
    py = run_py_fixture("prim_zstd", "zstd_py");
    (eng, ir) = _compile_native_forced("prim_zstd.jac");
    na = run_native_function(eng, "zstd_na", ir);
    assert len(set(py.keys()) & set(na.keys())) == len(py) , (
        f"key set mismatch: py={sorted(py.keys())} na={sorted(na.keys())}"
    );
    compare_results(py, na, "prim_zstd.jac [NA]");
}


test "zstd reference facts pinned" {
    py = run_py_fixture("prim_zstd", "zstd_py");
    assert py["rt3_ok"] == 1 , py;
    assert py["rt19_ok"] == 1 , py;
    assert py["two_ok"] == 1 , py;
    assert py["inc_ok"] == 1 , py;
    assert py["stream_ok"] == 1 , py;
    assert py["eof2"] == 1 , py;
    # A single ZstdDecompressor decodes exactly ONE frame, so after the first
    # frame the second concatenated frame is left as `unused_data`.
    assert py["unused2"] > 0 , py;
    assert py["inc_total"] == 2000 , py;
    assert py["c3_smaller"] == 1 , py;
    assert py["empty_ok"] == 1 , py;
}


test "zstd two-frame launcher decode path (CPython reference)" {
    a = b"alpha payload block " * 500;
    b = b"beta payload block " * 500;
    two = _zc(a, 19) + _zc(b, 19);
    # One-shot over two concatenated frames.
    assert _zd(two) == a + b , "one-shot two-frame decode";
    # Exactly the launcher's streaming path.
    zf = ZstdFile(io.BytesIO(two));
    got = b"";
    chunk = zf.read(9);
    while len(chunk) > 0 {
        got += chunk;
        chunk = zf.read(9);
    }
    zf.close();
    assert got == a + b , "ZstdFile chunked two-frame decode";
    assert hashlib.sha256(got).hexdigest() == hashlib.sha256(a + b).hexdigest() , (
        "sha256 mismatch"
    );
}
