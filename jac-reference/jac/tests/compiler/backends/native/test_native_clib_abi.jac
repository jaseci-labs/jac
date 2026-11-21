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
import from tests.support {
    jac_command,
    TESTS_DIR,
    compile_native,
    get_func,
    native_force_opts
}
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
            jac_command("build", "--native", fixture, "-o", out_bin),
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

test "clib imported record returns preserve inferred fields and ABI" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        csrc = os.path.join(tmpdir, "records.c");
        with open(csrc, "w") as fh {
            fh.write(
                "#include <stdint.h>\n"
                "typedef struct { int64_t x, y; } Pair;\n"
                "typedef struct { int64_t a, b, c, d, e; } Record;\n"
                "Pair make_pair(int64_t n) { return (Pair){n, n+1}; }\n"
                "Record make_record(int64_t n) { return (Record){n,n+1,n+2,n+3,n+4}; }\n"
            );
        }
        library = os.path.join(tmpdir, "librecords.so");
        built = subprocess.run(
            [cc, "-shared", "-fPIC", csrc, "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        with open(os.path.join(tmpdir, "declarations.jac"), "w") as fh {
            fh.write(
                f"import from \"{library}\" {{\n"
                "obj Pair { has x:i64, y:i64; }\n"
                "obj Record { has a:i64, b:i64, c:i64, d:i64, e:i64; }\n"
                "def make_pair(n:i64) -> Pair;\n"
                "def make_record(n:i64) -> Record;\n}\n"
            );
        }
        code = (
            "import from declarations { make_pair, make_record }\n"
            "def fields(n:i64) -> i64 {\n"
            "pair = make_pair(n); record = make_record(n);\n"
            "return pair.x + pair.y + record.a + record.c + record.e;\n}\n"
        );
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(tmpdir, "consumer.jac"),
            use_str=code,
            options=native_force_opts()
        );
        assert not prog.errors_had , str(prog.errors_had);
        assert ir.gen.native_engine is not None;
        fields = get_func(
            ir.gen.native_engine, "fields", ctypes.c_int64, ctypes.c_int64
        );
        assert fields(10) == 57;
        assert fields(-10) == -43;
    }
}

test "clib record arguments read from an optional slot pass the record, not its tag" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        csrc = os.path.join(tmpdir, "optional.c");
        with open(csrc, "w") as fh {
            fh.write(
                "#include <stdint.h>\n"
                "typedef struct { int64_t x, y; } Pair;\n"
                "typedef struct { int64_t a, b, c, d, e; } Record;\n"
                "Pair make_pair(int64_t n) { return (Pair){n, n+1}; }\n"
                "Record make_record(int64_t n) { return (Record){n,n+1,n+2,n+3,n+4}; }\n"
                "static int64_t calls = 0;\n"
                "int64_t pair_sum(Pair p) { calls++; return p.x + p.y; }\n"
                "int64_t record_sum(Record r) { calls++; return r.a + r.b + r.c + r.d + r.e; }\n"
                "int64_t call_count(void) { return calls; }\n"
            );
        }
        library = os.path.join(tmpdir, "liboptional.so");
        built = subprocess.run(
            [cc, "-shared", "-fPIC", csrc, "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        # `pair` and `record` are narrowed to their records by the time C is
        # called, but each still lives in an optional's slot: one small enough
        # to pass in registers, one passed in memory.
        code = (
            f"import from \"{library}\" {{\n"
            "obj Pair { has x:i64, y:i64; }\n"
            "obj Record { has a:i64, b:i64, c:i64, d:i64, e:i64; }\n"
            "def make_pair(n:i64) -> Pair;\n"
            "def make_record(n:i64) -> Record;\n"
            "def pair_sum(p:Pair) -> i64;\n"
            "def record_sum(r:Record) -> i64;\n"
            "def call_count() -> i64;\n}\n"
            "obj Holder { has pair: Pair | None = None, record: Record | None = None;\n"
            "def clear { self.pair = None; self.record = None; }\n}\n"
            "def sums(n:i64, held:i64) -> i64 {\n"
            "holder = Holder();\n"
            "if held != 0 { holder.pair = make_pair(n); holder.record = make_record(n); }\n"
            "pair = holder.pair;\n"
            "if pair is None { pair = make_pair(100); }\n"
            "record = holder.record;\n"
            "if record is None { record = make_record(1000); }\n"
            "return pair_sum(pair) + record_sum(record);\n}\n"
            "def absent(n:i64, in_memory:i64) -> i64 {\n"
            "holder = Holder();\n"
            "holder.pair = make_pair(n); holder.record = make_record(n);\n"
            "before = call_count();\n"
            "if holder.pair is not None and holder.record is not None {\n"
            "holder.clear();\n"
            "try {\n"
            "if in_memory != 0 { return record_sum(holder.record); }\n"
            "return pair_sum(holder.pair);\n"
            "} except TypeError { return before - call_count() - 1; }\n"
            "}\n"
            "return -2;\n}\n"
        );
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(tmpdir, "consumer.jac"),
            use_str=code,
            options=native_force_opts()
        );
        assert not prog.errors_had , str(prog.errors_had);
        assert ir.gen.native_engine is not None;
        sums = get_func(
            ir.gen.native_engine, "sums", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
        );
        # held: (10+11) + (10+11+12+13+14); not held: (100+101) + (1000+...+1004).
        assert sums(10, 1) == 81;
        assert sums(10, 0) == 5211;
        # The checker keeps `holder.pair` narrowed across `holder.clear()`, so
        # the call is reached with nothing in the slot: it raises TypeError
        # before C is entered (-1 is "raised, and the call count did not move").
        absent = get_func(
            ir.gen.native_engine,
            "absent",
            ctypes.c_int64,
            ctypes.c_int64,
            ctypes.c_int64
        );
        assert absent(10, 0) == -1;
        assert absent(10, 1) == -1;
    }
}

test "clib record embedding another module's clib record lays the field out inline" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        csrc = os.path.join(tmpdir, "embedded.c");
        with open(csrc, "w") as fh {
            fh.write(
                "#include <stdint.h>\n"
                "typedef struct { int32_t id, w, h; } Inner;\n"
                "typedef struct { int32_t count; Inner inner; int64_t tail; } Outer;\n"
                "Inner make_inner(int64_t n) { return (Inner){(int32_t)n, (int32_t)(n+1), (int32_t)(n+2)}; }\n"
                "Outer make_outer(int64_t n) {\n"
                "  return (Outer){(int32_t)n, {(int32_t)(n+1), (int32_t)(n+2), (int32_t)(n+3)}, n+4};\n"
                "}\n"
                "int64_t sum_outer(Outer o) {\n"
                "  return o.count + o.inner.id + o.inner.w + o.inner.h + o.tail;\n"
                "}\n"
            );
        }
        library = os.path.join(tmpdir, "libembedded.so");
        built = subprocess.run(
            [cc, "-shared", "-fPIC", csrc, "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        # The embedded record is declared by another module; the unit that
        # embeds it lays its own records out before that module's are walked.
        with open(os.path.join(tmpdir, "inner_decl.jac"), "w") as fh {
            fh.write(
                f"import from \"{library}\" {{\n"
                "obj Inner { has id:i32, w:i32, h:i32; }\n"
                "def make_inner(n:i64) -> Inner;\n}\n"
            );
        }
        code = (
            "import from inner_decl { Inner, make_inner }\n"
            f"import from \"{library}\" {{\n"
            "obj Outer { has count:i32, inner:Inner, tail:i64; }\n"
            "def make_outer(n:i64) -> Outer;\n"
            "def sum_outer(o:Outer) -> i64;\n}\n"
            "def fields(n:i64) -> i64 {\n"
            "outer = make_outer(n);\n"
            "return int(outer.count) + int(outer.inner.w) + outer.tail + int(make_inner(n).h);\n}\n"
            "def round_trip(n:i64) -> i64 {\n"
            "return sum_outer(make_outer(n));\n}\n"
        );
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(tmpdir, "consumer.jac"),
            use_str=code,
            options=native_force_opts()
        );
        assert not prog.errors_had , str(prog.errors_had);
        assert ir.gen.native_engine is not None;
        fields = get_func(
            ir.gen.native_engine, "fields", ctypes.c_int64, ctypes.c_int64
        );
        # count n, inner.w n+2, tail n+4, make_inner(n).h n+2.
        assert fields(10) == 48;
        assert fields(-10) == -32;
        round_trip = get_func(
            ir.gen.native_engine, "round_trip", ctypes.c_int64, ctypes.c_int64
        );
        # n + (n+1) + (n+2) + (n+3) + (n+4).
        assert round_trip(10) == 60;
        assert round_trip(-3) == -5;
    }
}

test "clib records of two imported modules embed one another in either walk order" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        csrc = os.path.join(tmpdir, "nested.c");
        with open(csrc, "w") as fh {
            fh.write(
                "#include <stdint.h>\n"
                "typedef struct { int32_t id, w, h; } Inner;\n"
                "typedef struct { int32_t count; Inner inner; int64_t tail; } Outer;\n"
                "Inner make_inner(int64_t n) { return (Inner){(int32_t)n, (int32_t)(n+1), (int32_t)(n+2)}; }\n"
                "Outer make_outer(int64_t n) {\n"
                "  return (Outer){(int32_t)n, {(int32_t)(n+1), (int32_t)(n+2), (int32_t)(n+3)}, n+4};\n"
                "}\n"
                "int64_t sum_outer(Outer o) {\n"
                "  return o.count + o.inner.id + o.inner.w + o.inner.h + o.tail;\n"
                "}\n"
            );
        }
        library = os.path.join(tmpdir, "libnested.so");
        built = subprocess.run(
            [cc, "-shared", "-fPIC", csrc, "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        # Neither record is the consumer's own: `Outer` comes from one imported
        # module and the `Inner` it embeds from another, so which is laid out
        # first is up to the order the imported modules are walked in.
        with open(os.path.join(tmpdir, "inner_decl.jac"), "w") as fh {
            fh.write(
                f"import from \"{library}\" {{\n"
                "obj Inner { has id:i32, w:i32, h:i32; }\n"
                "def make_inner(n:i64) -> Inner;\n}\n"
            );
        }
        with open(os.path.join(tmpdir, "outer_decl.jac"), "w") as fh {
            fh.write(
                "import from inner_decl { Inner }\n"
                f"import from \"{library}\" {{\n"
                "obj Outer { has count:i32, inner:Inner, tail:i64; }\n"
                "def make_outer(n:i64) -> Outer;\n"
                "def sum_outer(o:Outer) -> i64;\n}\n"
            );
        }
        code = (
            "import from outer_decl { Outer, make_outer, sum_outer }\n"
            "import from inner_decl { Inner, make_inner }\n"
            "def fields(n:i64) -> i64 {\n"
            "outer = make_outer(n);\n"
            "return int(outer.count) + int(outer.inner.w) + outer.tail + int(make_inner(n).h);\n}\n"
            "def round_trip(n:i64) -> i64 {\n"
            "return sum_outer(make_outer(n));\n}\n"
        );
        for walk_order in (None, "reverse") {
            options = native_force_opts();
            options.native_module_walk_order = walk_order;
            prog = JacProgram();
            ir = prog.compile(
                file_path=os.path.join(tmpdir, "consumer.jac"),
                use_str=code,
                options=options
            );
            assert not prog.errors_had , f"{walk_order}: {prog.errors_had}";
            assert ir.gen.native_engine is not None , walk_order;
            fields = get_func(
                ir.gen.native_engine, "fields", ctypes.c_int64, ctypes.c_int64
            );
            assert fields(10) == 48 , walk_order;
            assert fields(-10) == -32 , walk_order;
            round_trip = get_func(
                ir.gen.native_engine, "round_trip", ctypes.c_int64, ctypes.c_int64
            );
            assert round_trip(10) == 60 , walk_order;
            assert round_trip(-3) == -5 , walk_order;
        }
    }
}
