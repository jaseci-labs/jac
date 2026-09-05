"""Exhaustive coverage of the intrinsic registry (#7871 workstream D).

INTRINSIC_REGISTRY is the single authority for the reserved `__` intrinsic
namespace: classification (CallKind.INTRINSIC), type facts, and native
dispatch all read it.  The exhaustive test below iterates every registry
intr programmatically and asserts its lowering fired, so a refactor that
strands an intrinsic (the #6244 failure mode) breaks this suite instead of
silently demoting the call.  The negative tests pin the no-fallbacks bar:
intrinsic misuse is E5095, never a silent constant, and a user definition
colliding with a registered name is W6008, never a silent hijack.
"""

import ctypes;
import os;
import shutil;
import tempfile;
import from tests.support { TESTS_DIR, native_address }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.diagnostics { E5095, W6008 }
import from jaclang.compiler.intrinsic_registry {
    INTRINSIC_REGISTRY,
    IntrinsicDispatch
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

# IEEE-754 double bit patterns, as signed i64 (what ctypes.c_int64 yields).
glob BITS_1_5 = 4609434218613702656,  # 0x3FF8000000000000
     BITS_NEG_ZERO = -9223372036854775808;  # 0x8000000000000000


def _native_opts(gc_mode: str | None = None) -> any {
    kwargs: dict = {"force_codespace": "native", "force_target_program": True};
    if gc_mode is not None {
        kwargs["na_gc_mode"] = gc_mode;
    }
    return CompileOptions(**kwargs);
}

"""Compile a probe source in an isolated tempdir; return (prog, module)."""
def _compile_src(source: str, gc_mode: str | None = None) -> tuple {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "intrinsic_probe.jac");
        with open(src, "w") as f {
            f.write(source);
        }
        prog = JacProgram();
        ir_mod = prog.compile(file_path=src, options=_native_opts(gc_mode));
        return (prog, ir_mod);
    }
}

def _get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function {name} not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Call-site lines referencing `name` (definitions/declarations excluded)."""
def _call_lines(ir_text: str, name: str) -> list[str] {
    hits: list[str] = [];
    for line in ir_text.splitlines() {
        stripped = line.strip();
        if name not in stripped {
            continue;
        }
        if stripped.startswith("define") or stripped.startswith("declare") {
            continue;
        }
        if "call" in stripped {
            hits.append(stripped);
        }
    }
    return hits;
}

glob RAW_MEM_IMPORTS = "import from c { def malloc(n: int) -> int; def free(p: int) -> None; }\n",
     RAW_MEM_MARKERS = {
         IntrinsicDispatch.MEM_LOAD: "mem.ld",
         IntrinsicDispatch.MEM_STORE: "mem.p",
         IntrinsicDispatch.ATOMIC_XCHG: "atomicrmw xchg",
         IntrinsicDispatch.CALL_DTOR: "dtor.fn"
     };

"""Probe source per dispatch kind; a new dispatch kind must add one here."""
def _probe_source(intr: any) -> str {
    if intr.dispatch == IntrinsicDispatch.FLOAT_BITS {
        return "def probe(x: f64) -> i64 { return " + intr.name + "(x); }\n";
    }
    if intr.dispatch == IntrinsicDispatch.BITS_FLOAT {
        return "def probe(b: i64) -> f64 { return " + intr.name + "(b); }\n";
    }
    if intr.dispatch == IntrinsicDispatch.RC_RUNTIME {
        return "def probe(x: int) -> int { " + intr.name + "(); return x + 7; }\n";
    }
    if intr.dispatch in (IntrinsicDispatch.MEM_LOAD, IntrinsicDispatch.MEM_STORE) {
        return (
            RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); __mem_store_i64(p, x + 7); "
            "v = __mem_load_i64(p); free(p); return v; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.ATOMIC_XCHG {
        return (
            RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); __mem_store_i64(p, 0); "
            "old = __atomic_xchg_i64(p, x + 7); v = __mem_load_i64(p); free(p); "
            "return v + old; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.CALL_DTOR {
        return (
            "def probe(x: int) -> int { if x == 0 { __mem_call_dtor(x, x); } "
            "return x + 7; }\n"
        );
    }
    assert False , (
        f"no probe strategy for dispatch {intr.dispatch}: add one so this "
        "exhaustive gate keeps covering every registered intrinsic"
    );
    return "";
}

test "every registry intrinsic lowers through its registered emitter" {
    entries = INTRINSIC_REGISTRY.entries();
    assert len(entries) >= 7 , "registry lost entries";
    for intr in entries {
        (prog, ir_mod) = _compile_src(_probe_source(intr), gc_mode=intr.gc_mode_gate);
        errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not errs , f"{intr.name}: compile errors: {errs}";
        eng = ir_mod.gen.native_engine;
        assert eng is not None , f"{intr.name}: no native engine produced";
        if intr.dispatch == IntrinsicDispatch.FLOAT_BITS {
            fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_double);
            assert fn(1.5) == BITS_1_5 , f"{intr.name}(1.5) != IEEE-754 bits";
            assert fn(-0.0) == BITS_NEG_ZERO , f"{intr.name}(-0.0) lost sign bit";
        } elif intr.dispatch == IntrinsicDispatch.BITS_FLOAT {
            fn = _get_func(eng, "probe", ctypes.c_double, ctypes.c_int64);
            assert fn(BITS_1_5) == 1.5 , f"{intr.name}(bits(1.5)) != 1.5";
        } elif intr.dispatch in RAW_MEM_MARKERS {
            ir_text = str(ir_mod.gen.llvm_ir);
            marker = RAW_MEM_MARKERS[intr.dispatch];
            assert marker in ir_text , (
                f"{intr.name}: the raw-memory lowering ({marker!r}) is missing "
                "from the emitted IR - the intrinsic was stranded"
            );
            fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
            assert fn(35) == 42 , f"{intr.name}: probe did not execute cleanly";
        } else {
            ir_text = str(ir_mod.gen.llvm_ir);
            assert _call_lines(ir_text, intr.name) , (
                f"{intr.name}: no call site in emitted IR - the intrinsic "
                "was stranded"
            );
            fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
            assert fn(35) == 42 , f"{intr.name}: probe did not execute cleanly";
        }
    }
}

test "gc-gated intrinsic is a declared no-op outside its gc mode" {
    gated = [
        e
        for e in INTRINSIC_REGISTRY.entries()
        if e.gc_mode_gate is not None
    ];
    assert gated , "expected at least one gc-gated intrinsic in the registry";
    for intr in gated {
        off_mode = "rc" if intr.gc_mode_gate != "rc" else "none";
        (prog, ir_mod) = _compile_src(_probe_source(intr), gc_mode=off_mode);
        errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not errs , f"{intr.name}: compile errors: {errs}";
        ir_text = str(ir_mod.gen.llvm_ir);
        assert not _call_lines(ir_text, intr.name) , (
            f"{intr.name}: gated intrinsic still emitted a call under "
            f"gc mode {off_mode}"
        );
        eng = ir_mod.gen.native_engine;
        assert eng is not None;
        fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
        assert fn(35) == 42;
    }
}

test "wrong intrinsic arity is E5095, never a silent constant" {
    (prog, _mod) = _compile_src(
        "def probe(x: f64) -> i64 { return __float_bits(); }\n"
    );
    hits = [
        e
        for e in prog.errors_had
        if e.code is E5095
    ];
    assert hits , (
        "zero-arg __float_bits() must be an E5095 diagnostic, got: "
        + str([str(e) for e in prog.errors_had])
    );
    (prog2, _mod2) = _compile_src(
        "def probe(x: f64) -> i64 { return __float_bits(x, x); }\n"
    );
    assert [
        e
        for e in prog2.errors_had
        if e.code is E5095
    ] , ("two-arg __float_bits must be an E5095 diagnostic");
    (prog3, _mod3) = _compile_src(
        "def probe(x: int) -> int { __rc_debug_enable(x); return x; }\n"
    );
    assert [
        e
        for e in prog3.errors_had
        if e.code is E5095
    ] , ("__rc_debug_enable with an argument must be an E5095 diagnostic");
}

test "keyword arguments on an intrinsic are E5095" {
    (prog, _mod) = _compile_src(
        "def probe(x: f64) -> i64 { return __float_bits(f=x); }\n"
    );
    assert [
        e
        for e in prog.errors_had
        if e.code is E5095
    ] , ("keyword-arg intrinsic call must be an E5095 diagnostic");
}

test "non-numeric intrinsic operand is E5095" {
    src = (
        "def probe() -> i64 {\n"
        + "    s: str = \"nope\";\n"
        + "    return __float_bits(s);\n"
        + "}\n"
    );
    (prog, ir_mod) = _compile_src(src);
    assert not prog.errors_had , (
        "the E5095 refusal is owned by probe(), which must demote to a "
        + f"seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir_mod.gen.native_layout is not None , (
        "whole-module native compile aborted"
    );
    assert "probe" not in ir_mod.gen.native_layout.functions , (
        "a str operand to __float_bits must demote the function out of the "
        + "native layout, never lower wrongly"
    );
}

test "user stubs colliding with intrinsics warn W6008 and never hijack" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "float_bits_intrinsic.jac");
        shutil.copyfile(os.path.join(FIXTURES, "float_bits_intrinsic.jac"), src);
        prog = JacProgram();
        ir_mod = prog.compile(file_path=src, options=_native_opts());
        errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not errs , f"stub fixture must still compile: {errs}";
        w_hits = [
            w
            for w in prog.warnings_had
            if w.code is W6008
        ];
        assert len(w_hits) >= 2 , (
            "both stub defs must draw the W6008 collision warning, got: "
            + str([str(w) for w in prog.warnings_had])
        );
        eng = ir_mod.gen.native_engine;
        assert eng is not None;
        bits_of = _get_func(eng, "bits_of", ctypes.c_int64, ctypes.c_double);
        assert bits_of(1.5) == BITS_1_5 , "call reached the stub body";
    }
}
