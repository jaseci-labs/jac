"""Behavioral tests for the C-FFI ABI seams (#7626 C2).

Covers: sign-extension of narrow signed C returns at the widening/boxing
seam, SysV by-value float-struct passing against a gcc-compiled
reference library, and the DT_RUNPATH/$ORIGIN entry in emitted dynamic
executables.
"""

import ctypes;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
import jaclang;

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "clib sext: negative C int return stays negative through int and any" {
    (eng, _) = compile_native("clib_sext.jac");
    f = get_func(eng, "neg_direct", ctypes.c_int64);
    assert f() < 0 , f"strcmp('a','b') must stay negative widened to i64, got {f()}";
    g = get_func(eng, "neg_thru_any", ctypes.c_int64);
    assert g() == 1 , "negative C int boxed to `any` must compare < 0";
    h = get_func(eng, "pos_direct", ctypes.c_int64);
    assert h() > 0 , "positive strcmp result unchanged";
}

test "JIT C imports bind to their declared library despite a process symbol collision" {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    cc = shutil.which("cc") or shutil.which("gcc");
    assert cc is not None , "a C compiler is required for the foreign library fixture";
    with tempfile.TemporaryDirectory() as tmpdir {
        symbol = "jac_declared_library_value";
        csrc = os.path.join(tmpdir, "value.c");
        libpath = os.path.join(
            tmpdir, "libvalue.dylib" if sys.platform == "darwin" else "libvalue.so"
        );
        with open(csrc, "w") as f {
            f.write(
                "long long jac_declared_library_value(long long x) { return x + 3; }\n"
            );
        }
        cp = subprocess.run(
            [cc, "-shared", "-fPIC", csrc, "-o", libpath],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert cp.returncode == 0 , cp.stderr;
        wrong = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(
            lambda (x: int) { -100; }
        );
        llvm.add_symbol(symbol, ctypes.cast(wrong, ctypes.c_void_p).value);
        try {
            code = f'import from "{libpath}" {{ def {symbol}(x: i64) -> i64; }}\n'
                + f'def value(x: int) -> int {{ return {symbol}(x); }}';
            prog = JacProgram();
            ir = prog.compile(
                file_path=os.path.join(tmpdir, "main.jac"),
                use_str=code,
                options=native_force_opts()
            );
            assert not prog.errors_had , [str(e) for e in prog.errors_had];
            eng = ir.gen.native_engine;
            assert eng is not None;
            assert get_func(eng, "value", ctypes.c_int64, ctypes.c_int64)(39) == 42;
        } finally {
            llvm.add_symbol(symbol, 0);
        }
    }
}

test "JIT reports a missing C library before exposing an executable engine" {
    with tempfile.TemporaryDirectory() as tmpdir {
        libpath = os.path.join(tmpdir, "libmissing.so");
        code = f'import from "{libpath}" {{ def jac_missing_library_value -> i64; }}\n'
            + 'def value -> int { return jac_missing_library_value(); }';
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(tmpdir, "main.jac"),
            use_str=code,
            options=native_force_opts()
        );
        assert ir.gen.native_engine is None;
        assert any("C library not found for JIT" in str(e) for e in prog.errors_had) , [
            str(e) for e in prog.errors_had
        ];
    }
}

test "clib SysV: by-value float structs pass and return in SSE registers" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        csrc = os.path.join(tmpdir, "ref.c");
        with open(csrc, "w") as fh {
            fh.write(
                "typedef struct { double x; double y; } PtD;\n"
                "typedef struct { float a; float b; } PtF;\n"
                "double ptd_sum(PtD p) { return p.x + 2.0 * p.y; }\n"
                "float ptf_sum(PtF p) { return p.a + 2.0f * p.b; }\n"
                "PtD ptd_make(double x, double y) { PtD r; r.x = x; r.y = y; return r; }\n"
            );
        }
        libpath = os.path.join(tmpdir, "libc2ref.so");
        cp = subprocess.run(
            [cc, "-shared", "-fPIC", "-O1", csrc, "-o", libpath],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert cp.returncode == 0 , f"cc failed: {cp.stderr}";
        code = (
            f"import from \"{libpath}\" {{\n"
            f"    obj PtD {{ has x: f64, y: f64; }}\n"
            f"    obj PtF {{ has a: f32, b: f32; }}\n"
            f"    def ptd_sum(p: PtD) -> f64;\n"
            f"    def ptf_sum(p: PtF) -> f32;\n"
            f"    def ptd_make(x: f64, y: f64) -> PtD;\n"
            f"}}\n"
            f"def use_ptd(x: f64, y: f64) -> f64 {{\n"
            f"    p = PtD(x=x, y=y);\n"
            f"    return ptd_sum(p);\n"
            f"}}\n"
            f"def use_ptf(a: f64, b: f64) -> f64 {{\n"
            f"    p = PtF(a=f32(a), b=f32(b));\n"
            f"    return ptf_sum(p);\n"
            f"}}\n"
            f"def roundtrip(x: f64, y: f64) -> f64 {{\n"
            f"    p = ptd_make(x, y);\n"
            f"    return ptd_sum(p);\n"
            f"}}\n"
        );
        path = os.path.join(FIXTURES, "_clib_sysv_float.jac");
        prog = JacProgram();
        ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not prog.errors_had , f"Compilation errors: {errors}";
        eng = ir.gen.native_engine;
        assert eng is not None;
        f = get_func(eng, "use_ptd", ctypes.c_double, ctypes.c_double, ctypes.c_double);
        assert abs(f(1.5, 2.25) - 6.0) < 1e-9 , f"ptd_sum(1.5, 2.25) = {f(1.5, 2.25)}";
        g = get_func(eng, "use_ptf", ctypes.c_double, ctypes.c_double, ctypes.c_double);
        assert abs(g(1.0, 0.5) - 2.0) < 1e-5 , f"ptf_sum(1.0, 0.5) = {g(1.0, 0.5)}";
        h = get_func(
            eng, "roundtrip", ctypes.c_double, ctypes.c_double, ctypes.c_double
        );
        assert abs(h(3.0, 4.5) - 12.0) < 1e-9 , f"roundtrip(3.0, 4.5) = {h(3.0, 4.5)}";
    }
}

test "clib rpath: emitted dynamic executables carry DT_RUNPATH $ORIGIN" {
    readelf = shutil.which("readelf");
    if not readelf {
        testskip("readelf not available");
    }
    fixture = str(os.path.join(FIXTURES, "clib_import.jac"));
    if not os.path.exists("/usr/lib/libm.so.6") {
        testskip("/usr/lib/libm.so.6 not present");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        out_bin = os.path.join(tmpdir, "rpath_probe");
        comp = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                fixture,
                "-o",
                out_bin
            ],
            capture_output=True,
            text=True,
            timeout=180
        );
        assert comp.returncode == 0 , (
            f"nacompile failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-500:] if comp.stderr else '(empty)'}"
        );
        rd = subprocess.run(
            [readelf, "-d", out_bin], capture_output=True, text=True, timeout=30
        );
        assert rd.returncode == 0 , f"readelf failed: {rd.stderr}";
        assert "RUNPATH" in rd.stdout and "$ORIGIN" in rd.stdout , (
            f"expected DT_RUNPATH with $ORIGIN in dynamic section, got:\n"
            f"{rd.stdout}"
        );
    }
}
