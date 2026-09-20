"""Zstd equivalence: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

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
    compare_results
}


"""Compile a fixture with the native codespace forced on and return
(engine, ir). Unlike the shared `compile_native`, this does not depend on a
`[placement.pins]` entry in the fixtures `jac.toml`: `default_codespace='native'`
plus `force_target_program` coerces the whole module into the native codespace,
which is exactly what these stdlib fixtures need."""
def _compile_native_forced(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    opts = CompileOptions(default_codespace="native", force_target_program=True);
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)), options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
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
