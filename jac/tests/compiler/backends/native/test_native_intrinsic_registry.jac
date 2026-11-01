"""Exhaustive coverage of the intrinsic registry (#7871 workstream D).

INTRINSIC_REGISTRY is the single authority for the reserved `__` intrinsic
namespace: classification (CallKind.INTRINSIC), the signature the type
checker checks calls against, and native dispatch all read it.  The
exhaustive test below iterates every registry intr programmatically and
asserts the decision step lowered its probe and the probe runs, so a refactor
that strands an intrinsic (the #6244 failure mode) breaks this suite instead
of silently demoting the call.
The negative tests pin the no-fallbacks bar: a misused intrinsic is a type
error at check time, never a silent constant, and a user definition
colliding with a registered name is W6008, never a silent hijack.
"""

import ctypes;
import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support {
    KernelFixture,
    TESTS_DIR,
    adopt_native_units,
    compile_mir,
    compile_native_unit,
    diagnostics_text,
    error_codes,
    kernel_compile_file,
    native_address,
    remember_native_unit,
    warning_codes,
    write_case
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.diagnostics {
    E5095,
    E1050,
    E1051,
    E1052,
    E1053,
    W1051,
    W6008
}
import from jaclang.compiler.intrinsic_registry {
    INTRINSIC_REGISTRY,
    IntrinsicDispatch
}
import type from jaclang.compiler.kernel_api { CompileResult }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

# IEEE-754 double bit patterns, as signed i64 (what ctypes.c_int64 yields).
glob BITS_1_5 = 4609434218613702656,  # 0x3FF8000000000000
     BITS_NEG_ZERO = -9223372036854775808;  # 0x8000000000000000


def _native_opts(gc_mode: str | None = None) -> any {
    kwargs: dict[str, any] = {"force_codespace": "native"};
    if gc_mode is not None {
        kwargs["na_gc_mode"] = gc_mode;
    }
    return CompileOptions(**kwargs);
}

"""Compile `path` through the kernel under `options` and JIT its native
units here; return (engine, fixture)."""
def _jit_path(path: Path, options: CompileOptions) -> tuple[any, KernelFixture] {
    fx = compile_native_unit(path.name, str(path.parent), options, ["bytecode"]);
    prog = JacProgram();
    prog.options = options;
    adopt_native_units(prog, fx.result, options);
    prog._get_compiler()._load_native_from_cache(
        fx.path, prog, json.loads(fx.unit.interop) if fx.unit.interop else None
    );
    carrier = prog.hub.artifacts.get(fx.path);
    eng = carrier.native_engine if carrier is not None else None;
    assert eng is not None , f"no native engine produced for {path.name}";
    remember_native_unit(eng, fx);
    return (eng, fx);
}

"""JIT a probe source written to its own directory; return (engine, fixture)."""
def _jit_src(source: str, gc_mode: str | None = None) -> tuple[any, KernelFixture] {
    return _jit_path(Path(write_case(source, "intrinsic_probe.jac")), _native_opts(gc_mode));
}

"""The decision step's verdict on a probe source: its MIR, demoted set and
emitted IR, with no JIT."""
def _mir_src(source: str, gc_mode: str | None = None) -> KernelFixture {
    path = Path(write_case(source, "intrinsic_probe.jac"));
    return compile_mir(path.name, str(path.parent), _native_opts(gc_mode));
}

"""The kernel's compile result for a probe source, errors and all."""
def _compile_result(
    source: str, options: (CompileOptions | None) = None
) -> CompileResult {
    return kernel_compile_file(
        write_case(source, "intrinsic_probe.jac"),
        options if options is not None else _native_opts()
    );
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

glob RAW_MEM_IMPORTS = "import from c { def malloc(n: int) -> int; def free(p: int) -> None; }\n";

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
        spec = intr.result_spec
            if intr.dispatch == IntrinsicDispatch.MEM_LOAD
            else intr.param_specs[1];
        return (
            RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); __mem_store_"
            + spec
            + "(p, "
            + spec
            + "(x + 7)); "
            + "v = __mem_load_"
            + spec
            + "(p); free(p); return int(v); }\n"
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
    if intr.dispatch == IntrinsicDispatch.ALLOCA {
        return (
            "def probe(x: int) -> int { p = __alloca(8); "
            "__mem_store_i64(p, x + 7); return int(__mem_load_i64(p)); }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.LIST_DATA {
        return (
            "def probe(x: int) -> int { l: list[int] = [0, 0]; "
            "__mem_store_i64(__list_data_ptr(l) + 8, x + 7); return l[1]; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.BUFFER_DATA {
        arg = "b\"jac\"" if intr.name == "__bytes_data" else "bytearray(4)";
        return (
            "def probe(x: int) -> int { p = "
            + intr.name
            + "("
            + arg
            + "); " "return x + 7 if p != 0 else 0; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.REF_ADDR {
        return (
            "def probe(x: int) -> int { l = [x, 2]; "
            "return x + 7 if __ref_addr(l) != 0 else 0; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.STR_DATA {
        return (
            "def probe(x: int) -> int { s = str(x) + \"jac\"; "
            "return x + 7 if __str_data(s) != 0 else 0; }\n"
        );
    }
    if intr.dispatch
        in (
            IntrinsicDispatch.ATOMIC_LOAD,
            IntrinsicDispatch.ATOMIC_STORE,
            IntrinsicDispatch.ATOMIC_CAS,
            IntrinsicDispatch.ATOMIC_RMW
        ) {
        width = intr.name.rsplit("_", 1)[1];
        return (
            RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); __mem_store_i64(p, 0); "
            + f"__atomic_store_{width}(p, {width}(5), 3); "
            + f"old = __atomic_cas_{width}(p, {width}(5), {width}(9), 5); "
            + f"before = __atomic_add_{width}(p, {width}(x - 9), 4); "
            + f"v = __atomic_load_{width}(p, 2); free(p); "
            + "return int(v) + int(old) - int(before) + 11; }\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.ATOMIC_FENCE {
        return "def probe(x: int) -> int { __atomic_fence(5); return x + 7; }\n";
    }
    if intr.dispatch == IntrinsicDispatch.C_THREAD_LOCAL {
        size_arg = ", 40" if intr.name == "__thread_local_block" else "";
        return (
            "def probe(x: int) -> int { "
            + f"return x + 7 if {intr.name}(\"jac_probe_tls\"{size_arg}) != 0 else 0; }}\n"
        );
    }
    if intr.dispatch == IntrinsicDispatch.REGION_TLS {
        return (
            "def probe(x: int) -> int { old = __jac_region_tls_get(); "
            "__jac_region_tls_set(x + 7); v = __jac_region_tls_get(); "
            "__jac_region_tls_set(old); "
            "return v if __jac_region_gbl_get() != 0 else 0; }\n"
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
        probe = _mir_src(_probe_source(intr), gc_mode=intr.gc_mode_gate);
        assert not probe.demoted() , (
            f"{intr.name}: the decision step refused the probe - the intrinsic "
            f"was stranded: {probe.demoted()}"
        );
        if intr.dispatch == IntrinsicDispatch.C_THREAD_LOCAL {
            # The JIT links no initial-exec TLS reference to a host symbol;
            # the declaration and the address it yields are the lowering.
            ir_text = probe.llvm_ir();
            declared = "weak thread_local(initialexec) global i64 0"
                if intr.name == "__thread_local"
                else (
                    "weak thread_local(initialexec) global [5 x i64] zeroinitializer"
                        if intr.name == "__thread_local_block"
                        else "external thread_local(initialexec) global i8"
                );
            assert f"@\"jac_probe_tls\" = {declared}" in ir_text
                or f"@jac_probe_tls = {declared}" in ir_text , ir_text;
            continue;
        }
        (eng, _) = _jit_src(_probe_source(intr), gc_mode=intr.gc_mode_gate);
        if intr.dispatch == IntrinsicDispatch.FLOAT_BITS {
            fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_double);
            assert fn(1.5) == BITS_1_5 , f"{intr.name}(1.5) != IEEE-754 bits";
            assert fn(-0.0) == BITS_NEG_ZERO , f"{intr.name}(-0.0) lost sign bit";
        } elif intr.dispatch == IntrinsicDispatch.BITS_FLOAT {
            fn = _get_func(eng, "probe", ctypes.c_double, ctypes.c_int64);
            assert fn(BITS_1_5) == 1.5 , f"{intr.name}(bits(1.5)) != 1.5";
        } else {
            fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
            assert fn(35) == 42 , f"{intr.name}: probe did not execute cleanly";
        }
    }
}

test "32 bit memory operations preserve adjacent storage and signed values" {
    (eng, _) = _jit_src(
        RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); "
            + "__mem_store_i32(p, 123); __mem_store_i32(p + 4, i32(x)); "
            + "lo = int(__mem_load_i32(p)); hi = int(__mem_load_i32(p + 4)); "
            + "free(p); return lo + hi; }\n"
    );
    fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
    assert fn(-123) == 0;
    assert fn(2147483647) == 2147483770;
    assert fn(-2147483648) == -2147483525;
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
        (eng, fx) = _jit_src(_probe_source(intr), gc_mode=off_mode);
        assert not _call_lines(fx.llvm_ir(), intr.name) , (
            f"{intr.name}: gated intrinsic still emitted a call under "
            f"gc mode {off_mode}"
        );
        fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
        assert fn(35) == 42;
    }
}

"""The diagnostic codes a compile of `source` reported."""
def _error_codes(source: str) -> list[str] {
    return error_codes(_compile_result(source));
}

test "intrinsic calls are typed from their registry signature" {
    result = _compile_result(
        RAW_MEM_IMPORTS
            + "def probe(x: int) -> int { p = malloc(8); "
            + "__mem_store_i64(p, x); v = __mem_load_i64(p); free(p); return v; }\n"
    );
    assert not result.errors , diagnostics_text(result);
    assert W1051.code not in warning_codes(result) , (
        f"intrinsic calls left untyped: {diagnostics_text(result)}"
    );
}

test "wrong intrinsic arity is a call error, never a silent constant" {
    missing = _error_codes("def probe(x: f64) -> i64 { return __float_bits(); }\n");
    assert E1050.code in missing , "zero-arg __float_bits() must report the missing argument";
    extra = _error_codes("def probe(x: f64) -> i64 { return __float_bits(x, x); }\n");
    assert E1051.code in extra , "two-arg __float_bits must report the extra argument";
    nullary = _error_codes(
        "def probe(x: int) -> int { __rc_debug_enable(x); return x; }\n"
    );
    assert E1051.code in nullary , "__rc_debug_enable takes no arguments";
}

test "keyword arguments on an intrinsic are a call error" {
    codes = _error_codes("def probe(x: f64) -> i64 { return __float_bits(f=x); }\n");
    assert E1052.code in codes , "intrinsic parameters are positional-only";
}

test "a non-numeric intrinsic operand is a type error at check time" {
    source = "def probe() -> i64 {\n    s: str = \"nope\";\n    return __float_bits(s);\n}\n";
    codes = _error_codes(source);
    assert E1053.code in codes , f"a str operand to __float_bits must be rejected, got {codes}";
}

test "user stubs colliding with intrinsics warn W6008 and never hijack" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "float_bits_intrinsic.jac");
        shutil.copyfile(os.path.join(FIXTURES, "float_bits_intrinsic.jac"), src);
        (eng, fx) = _jit_path(Path(src), _native_opts());
        w_hits = [
            w
            for w in fx.result.warnings
            if w.code == W6008.code
        ];
        assert len(w_hits) >= 2 , (
            "both stub defs must draw the W6008 collision warning, got: "
            + diagnostics_text(fx.result)
        );
        bits_of = _get_func(eng, "bits_of", ctypes.c_int64, ctypes.c_double);
        assert bits_of(1.5) == BITS_1_5 , "call reached the stub body";
    }
}

test "a C thread-local is named by a string literal" {
    result = _compile_result(
        "def probe(name: str) -> int { return __c_thread_local(name); }\n",
        CompileOptions(
            force_codespace="native", native_required=True, skip_native_engine=True
        )
    );
    assert any(
        e.code == E5095.code and "string literal" in e.message for e in result.errors
    ) , diagnostics_text(result);
}

test "atomic read-modify-write returns the old value at each width" {
    for width in ["i8", "i16", "i32", "i64"] {
        (eng, _) = _jit_src(
            RAW_MEM_IMPORTS
                + "def probe(x: int) -> int { p = malloc(8); __mem_store_i64(p, 0); "
                + f"__atomic_store_{width}(p, {width}(12), 0); "
                + f"a = __atomic_sub_{width}(p, {width}(2), 5); "
                + f"o = __atomic_or_{width}(p, {width}(1), 5); "
                + f"n = __atomic_and_{width}(p, {width}(6), 5); "
                + f"z = __atomic_xor_{width}(p, {width}(3), 5); "
                + f"s = __atomic_swap_{width}(p, {width}(x), 5); "
                + f"miss = __atomic_cas_{width}(p, {width}(0), {width}(1), 5); "
                + f"v = __atomic_load_{width}(p, 5); free(p); "
                + "return int(a) * 1000000 + int(o) * 10000 + int(n) * 100 + int(z) "
                + "+ int(s) - int(v) + int(miss) - int(v); }\n"
        );
        fn = _get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
        # 12 -2-> 10 |1-> 11 &6-> 2 ^3-> 1, swapped for x = 7; the CAS misses and reads 7.
        assert fn(7)
            == 12 * 1000000 + 10 * 10000 + 11 * 100 + 2 + 1 - 7 + 7 - 7 , width;
    }
}

test "a load cannot release and a memory order is a constant" {
    for source in [
        "def probe(p: int) -> int { return int(__atomic_load_i64(p, 3)); }\n",
        "def probe(p: int, o: i32) -> int { return int(__atomic_load_i64(p, o)); }\n"
    ] {
        result = _compile_result(
            source,
            CompileOptions(
                force_codespace="native", native_required=True, skip_native_engine=True
            )
        );
        assert E5095.code in error_codes(result) , source;
    }
}
