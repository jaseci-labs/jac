"""Tests for the na->wasm build contract (#7048).

The vendored wasm_rt libc folds pure-compute libc INTO the module, the
remaining host surface rides the versioned jac_host1 import module, app FFI
stays under "env", and anything else is a build-time error instead of a
browser LinkError. These tests skip when the vendored bitcode is absent
(`zig build vendor-wasm-libc` populates .pbs-build/wasm32/libc).
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.wasm_build {
    emit_wasm_from_ir,
    _wasm_libc_dir
}
import from jaclang.compiler.backends.native.wasm_artifact { wasm_import_map }
import from jaclang.compiler.backends.native.wasm_host_abi {
    WASM_HOST_ABI,
    WASM_HOST_MODULE
}
import from jaclang.compiler.backends.native.wasm_build { app_declared_imports }
import from jaclang.compiler.frontend.codeinfo { InteropBinding, InteropContext }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "wasm_host_probe.jac";

# ─── helpers ─────────────────────────────────────────────────────────────────
"""A wasm libc floor that carries its source manifest: this checkout's (a kit
lane downloads it beside the tree), else the one the router resolves. A
sealed image's own floor has no manifest to check against wasm_rt/."""
def _manifested_libc_dir -> (str | None) {
    import from jaclang.compiler.backends.native.floors { WASM_FLOOR_MANIFEST }
    checkout = os.path.join(os.path.dirname(TESTS_DIR), ".pbs-build", "wasm32", "libc");
    if os.path.isfile(os.path.join(checkout, WASM_FLOOR_MANIFEST)) {
        return checkout;
    }
    return _wasm_libc_dir();
}

def _require_libc {
    if _wasm_libc_dir() is None {
        testskip("vendored wasm libc not present (run `zig build vendor-wasm-libc`)");
    }
}

"""The fixture's whole program for wasm: its unit merged with the runtime
units it links and the glue that defines `jac_entry` and `__jac_glob_init`,
the text `compile_to_wasm` hands the emitter."""
def fixture_ir -> str {
    import from jaclang.compiler.backends.native.link_plan {
        build_link_plan,
        wasm_program_ir
    }
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, FIXTURE),
            options=CompileOptions(aot_mode=True)
        );
        assert not prog.errors_had;
        plan = build_link_plan(prog, [ir.loc.mod_path], prog.options);
        return wasm_program_ir(plan);
    } finally {
        pop_native_target(prev);
    }
}

# ─── tests ───────────────────────────────────────────────────────────────────

"""Serve the wasm libc from `floor` (an empty string for none) while `fn` runs:
the checkout tier probes that directory, and no sealed image or kit
competes."""
def _with_floor(floor: str, fn: any) -> any {
    import from unittest.mock { patch }
    import jaclang.artifacts.router as router;
    import jaclang.compiler.backends.native.floors as floors;
    import from jaclang.artifacts.model { Probe, Source }
    probe = floors._wasm_probe(floor, Source.CHECKOUT) if floor else Probe.missing();
    router.forget();
    try {
        with patch.object(floors.WasmLibcArtifact, "probe_sealed", return_value=None), patch.object(
            floors.WasmLibcArtifact, "probe_checkout", return_value=probe
        ), patch.object(
            floors.WasmLibcArtifact, "probe_kit", return_value=Probe.missing()
        ) {
            return fn();
        }
    } finally {
        router.forget();
    }
}

test "wasm links retain their target in a host application context" {
    import from jaclang.compiler.driver.pipeline_runner { wasm_ir }
    import from jaclang.compiler.driver.compilation_context { context_program }
    prog = JacProgram();
    prog.options = CompileOptions(native_target="");
    context_program(prog, prog.options);
    for attempt in range(2) {
        (llvm_ir, _) = wasm_ir(prog, os.path.join(FIXTURES, FIXTURE));
        assert 'target triple = "wasm32-unknown-unknown"' in llvm_ir;
        assert "pthread_key_create" not in llvm_ir;
        assert "pthread_getspecific" not in llvm_ir;
    }
}

test "wasm app imports use the qualified interop provider symbol" {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, FIXTURE), options=CompileOptions()
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    symbol = "__jac_na_import_pkg_helper_answer";
    mod.gen.interop_manifest.bindings["local_alias"] = InteropBinding(
        name="answer",
        source_context=InteropContext.SERVER,
        callers={InteropContext.NATIVE},
        source_module="helper.jac",
        symbol=symbol
    );
    imports = app_declared_imports(mod);
    assert symbol in imports , f"the declared callback provider must be allowed: {imports}";
    assert "local_alias" not in imports , f"a local alias is not an import provider: {imports}";
}

test "libc folds in-module; the host surface is jac_host1 only" {
    _require_libc();
    mod = emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
    imports = wasm_import_map(mod);
    # nothing left under env: malloc/memcpy/etc are now inside the module
    assert "env" not in imports , f"unexpected env imports: {imports.get('env')}";
    for fld in imports.get(WASM_HOST_MODULE, []) {
        assert fld in WASM_HOST_ABI , f"{fld} not in the declared host ABI";
    }
}

test "app FFI stays under env; undeclared imports are a build-time error" {
    _require_libc();
    app_ir = (
        "target triple = \"wasm32-unknown-unknown\"\n"
        "declare i32 @MyThing(i32)\n"
        "define i32 @use(i32 %x) {\n"
        "  %r = call i32 @MyThing(i32 %x)\n"
        "  ret i32 %r\n"
        "}\n"
    );
    mod = emit_wasm_from_ir(app_ir, ["use"], app_imports={"MyThing"});
    imports = wasm_import_map(mod);
    assert imports.get("env") == ["MyThing"];

    with testraises(RuntimeError) as exc {
        emit_wasm_from_ir(app_ir, ["use"], app_imports=set());
    }
    assert "MyThing" in str(exc.value);
}

test "floor-style i64 libc declarations bind through the __jac64 adapters" {
    _require_libc();
    # the native floor declares strlen as (ptr) -> i64; wasm32 libc is i32 —
    # a raw bind would trap as `unreachable` at the first call (#7048)
    app_ir = (
        "target triple = \"wasm32-unknown-unknown\"\n"
        "@.s = private constant [4 x i8] c\"abc\\00\"\n"
        "declare i64 @strlen(ptr)\n"
        "define i64 @slen() {\n"
        "  %r = call i64 @strlen(ptr @.s)\n"
        "  ret i64 %r\n"
        "}\n"
    );
    mod = emit_wasm_from_ir(app_ir, ["slen"], app_imports=set());
    imports = wasm_import_map(mod);
    assert "env" not in imports;
    node_bin = shutil.which("node");
    if not node_bin {
        testskip("node not available");
    }
    d = tempfile.mkdtemp();
    wpath = os.path.join(d, "m.wasm");
    Path(wpath).write_bytes(mod);
    harness = """
import { readFileSync } from "fs";
const jac_host1 = new Proxy({}, { get: (t, k) => (...a) => 0 });
const { instance } = await WebAssembly.instantiate(readFileSync(process.argv[2]), { jac_host1 });
console.log(`slen=${Number(instance.exports.slen())}`);
""";
    hpath = os.path.join(d, "run.mjs");
    Path(hpath).write_text(harness);
    proc = subprocess.run(
        [node_bin, hpath, wpath], capture_output=True, text=True, timeout=60
    );
    assert proc.returncode == 0 , f"node failed: {proc.stderr}";
    assert proc.stdout.strip().splitlines()[-1] == "slen=3";
}

"""The stdlib declares the runtime floor's functions as C imports, so a wasm
module that reaches them (math's fmadd, for one) names them as app imports.
wasm_rt/jac_floor.c must define every one in the module, with the
signature the stdlib declares, or the module imports what no host supplies."""
test "the runtime floor's functions resolve inside a wasm module" {
    _require_libc();
    floor_decls = {
        "__jac_errno": "declare i64 @__jac_errno()",
        "__jac_platform_id": "declare i32 @__jac_platform_id()",
        "__jac_at_fdcwd": "declare i32 @__jac_at_fdcwd()",
        "__jac_clock_id": "declare i64 @__jac_clock_id(i32)",
        "__jac_sleep_ns": "declare i32 @__jac_sleep_ns(i64)",
        "__jac_fmadd": "declare double @__jac_fmadd(double, double, double)",
        "__jac_opendir": "declare i64 @__jac_opendir(ptr)",
        "__jac_readdir": "declare i64 @__jac_readdir(i64)",
        "__jac_closedir": "declare i32 @__jac_closedir(i64)",
        "__jac_dirent_name": "declare i64 @__jac_dirent_name(i64)",
        "__jac_home_dir": "declare i64 @__jac_home_dir(ptr, ptr, i64)",
        "__jac_executable_path": "declare i64 @__jac_executable_path(ptr, i64)",
        "__jac_addrinfo_layout": "declare i64 @__jac_addrinfo_layout(i32)",
        "__jac_sockaddr_family": "declare i32 @__jac_sockaddr_family(ptr)"
    };
    calls = [
        "  %fm = call double @__jac_fmadd(double 2.0, double 3.0, double 1.0)",
        "  %ck = call i64 @__jac_clock_id(i32 5)",
        "  %ai = call i64 @__jac_addrinfo_layout(i32 3)",
        "  %e0 = call i64 @__jac_errno()",
        "  %e1 = call i32 @__jac_platform_id()",
        "  %e2 = call i32 @__jac_at_fdcwd()",
        "  %e3 = call i32 @__jac_sleep_ns(i64 0)",
        "  %e4 = call i64 @__jac_opendir(ptr null)",
        "  %e5 = call i64 @__jac_readdir(i64 0)",
        "  %e6 = call i32 @__jac_closedir(i64 0)",
        "  %e7 = call i64 @__jac_dirent_name(i64 0)",
        "  %e8 = call i64 @__jac_home_dir(ptr null, ptr null, i64 0)",
        "  %e9 = call i64 @__jac_executable_path(ptr null, i64 0)",
        "  %ea = call i32 @__jac_sockaddr_family(ptr @family)",
        "  %fc = sitofp i64 %ck to double",
        "  %fa = sitofp i64 %ai to double",
        "  %ff = sitofp i32 %ea to double",
        "  %s1 = fadd double %fm, %fc",
        "  %s2 = fadd double %s1, %fa",
        "  %s3 = fadd double %s2, %ff",
        "  ret double %s3"
    ];
    app_ir = (
        "target triple = \"wasm32-unknown-unknown\"\n"
        + "\n".join(floor_decls.values())
        + "\n@family = private constant [2 x i8] c\"\\0A\\00\"\n"
        + "define double @probe() {\n"
        + "\n".join(calls)
        + "\n}\n"
    );
    mod = emit_wasm_from_ir(app_ir, ["probe"], app_imports=set(floor_decls));
    imports = wasm_import_map(mod);
    leaked = sorted(set(imports.get("env", [])) & set(floor_decls));
    assert not leaked , f"floor functions became host imports: {leaked}";
    node_bin = shutil.which("node");
    if not node_bin {
        testskip("node not available");
    }
    d = tempfile.mkdtemp();
    wpath = os.path.join(d, "m.wasm");
    Path(wpath).write_bytes(mod);
    harness = """
import { readFileSync } from "fs";
const jac_host1 = new Proxy({}, { get: (t, k) => (...a) => 0 });
const { instance } = await WebAssembly.instantiate(readFileSync(process.argv[2]), { jac_host1 });
console.log(`probe=${instance.exports.probe()}`);
""";
    hpath = os.path.join(d, "run.mjs");
    Path(hpath).write_text(harness);
    proc = subprocess.run(
        [node_bin, hpath, wpath], capture_output=True, text=True, timeout=60
    );
    assert proc.returncode == 0 , f"node failed: {proc.stderr}";
    """fmadd 7, the Python monotonic clock id 1, sizeof(addrinfo) 48 and the
    family AF_INET6 (10) read from a little-endian sockaddr.""";
    assert proc.stdout.strip().splitlines()[-1] == "probe=66";
}

test "a missing wasm libc is an error that names the build command" {
    import from jaclang.artifacts.model { ArtifactUnavailable }
    def emit -> str {
        try {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    message = _with_floor("", emit);
    assert "jac native build wasm-libc" in message , message;
}

test "the fixture runs under node with ONLY the jac_host1 host object" {
    _require_libc();
    node_bin = shutil.which("node");
    if not node_bin {
        testskip("node not available");
    }
    mod = emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
    d = tempfile.mkdtemp();
    wpath = os.path.join(d, "m.wasm");
    Path(wpath).write_bytes(mod);
    # No env object, no JS malloc, no printf emulation: everything libc-shaped
    # lives inside the module; the host supplies only the jac_host1 contract.
    harness = """
import { readFileSync } from "fs";
let mem;
let out = "";
const dec = new TextDecoder();
const jac_host1 = new Proxy({
  write: (fd, ptr, n) => { out += dec.decode(new Uint8Array(mem.buffer, ptr, n)); return n; },
  fflush: () => 0, getenv: () => 0,
  abort: () => { throw new Error("abort"); },
}, { get: (t, k) => t[k] ?? ((...a) => 0) });
const { instance } = await WebAssembly.instantiate(readFileSync(process.argv[2]), { jac_host1 });
const e = instance.exports;
mem = e.memory;
e.__jac_glob_init();
e.jac_entry();
const c = Number(e.compute(20n));
console.log(`out=${JSON.stringify(out)} compute=${c}`);
""";
    hpath = os.path.join(d, "run.mjs");
    Path(hpath).write_text(harness);
    proc = subprocess.run(
        [node_bin, hpath, wpath], capture_output=True, text=True, timeout=60
    );
    assert proc.returncode == 0 , f"node failed: {proc.stderr}";
    last = proc.stdout.strip().splitlines()[-1];
    # float repr, alloc-churning concat, and str.lower all format in-module and
    # arrive through jac_host1.write — the exact #7048 breakage surface.
    assert last == 'out="3.14\\n11\\nup\\nfinished\\n7\\n" compute=21' , f"unexpected: {last}";
}

test "vtable dispatch works in a wasm module: data relocations are applied" {
    # A vtable is data holding function-table indices. The wasm linker used to
    # apply only the code section's relocations, so every function pointer or
    # address stored in data kept the object file's placeholder, and a call
    # through a vtable trapped with "table index is out of bounds".
    _require_libc();
    node_bin = shutil.which("node");
    if not node_bin {
        testskip("node not available");
    }
    import from tests.support { jac_command }
    d = tempfile.mkdtemp();
    wpath = os.path.join(d, "vt.wasm");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "wasm_vtable_dispatch.jac"),
            "--target-triple",
            "wasm32",
            "--memory",
            "nogc",
            "-o",
            wpath
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , comp.stderr[-1500:];
    harness = """
import { readFileSync } from "fs";
const jac_host1 = new Proxy({ abort: () => { throw new Error("abort"); } },
  { get: (t, k) => t[k] ?? ((...a) => 0) });
const { instance } = await WebAssembly.instantiate(readFileSync(process.argv[2]), { jac_host1 });
const e = instance.exports;
if (e.__jac_glob_init) e.__jac_glob_init();
const f = Object.keys(e).find(k => k.endsWith(".compute") || k === "compute");
console.log(`compute=${Number(e[f](5n))}`);
""";
    hpath = os.path.join(d, "run.mjs");
    Path(hpath).write_text(harness);
    proc = subprocess.run(
        [node_bin, hpath, wpath], capture_output=True, text=True, timeout=60
    );
    assert proc.returncode == 0 , f"node failed: {proc.stderr}";
    assert proc.stdout.strip().splitlines()[-1] == "compute=5050" , proc.stdout;
}

# ─── stale-floor detection ───────────────────────────────────────────────────
# The vendored bitcode is a build artifact with no recorded link to
# wasm_rt/*.c. When an adapter is added to jac_abi64.c and the floor is not
# rebuilt, the rename in _link_wasm_libc emits __jac64_<name> against a libc
# that never defined it, and the failure used to surface much later in the
# linker as "compiler drift ... add it to wasm_rt or to wasm_host_abi.jac" --
# advice that is wrong twice over (it IS in wasm_rt, and the host ABI is
# syscalls only). These pin the two guards that now catch it up front.
test "abi64 adapter gap is reported against the floor, not the app" {
    _require_libc();
    src = _manifested_libc_dir();
    assert src is not None;
    d = tempfile.mkdtemp();
    floor = os.path.join(d, "libc");
    shutil.copytree(src, floor);
    # Drop the one object carrying the __jac64_* widening adapters, leaving an
    # otherwise complete floor: exactly the shape of a pre-adapter build.
    abi = os.path.join(floor, "jac_abi64.bc");
    if not os.path.exists(abi) {
        testskip("floor has no jac_abi64.bc to remove");
    }
    os.remove(abi);
    merged = os.path.join(floor, "_merged.bc");
    if os.path.exists(merged) {
        os.remove(merged);
    }
    def emit -> str {
        try {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        } except RuntimeError as e {
            return str(e);
        }
        return "";
    }
    try {
        msg = _with_floor(floor, emit);
        assert "is stale" in msg , msg;
        assert "__jac64_" in msg , msg;
        # Names the floor, never tells the reader to touch the host ABI.
        assert floor in msg , msg;
        assert "wasm_host_abi" not in msg , msg;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "every adapted libc name has a floor adapter" {
    _require_libc();
    import from jaclang.compiler.backends.native.wasm_build { _ABI64_ADAPTED }
    import from jaclang.compiler.backends.native.floors { wasm_rt_src_dir }
    src = os.path.join(wasm_rt_src_dir(), "jac_abi64.c");
    text = Path(src).read_text();
    missing = sorted(
        [
            nm
            for nm in _ABI64_ADAPTED
            if ("__jac64_" + nm) not in text
        ]
    );
    assert not missing , f"_ABI64_ADAPTED names with no adapter in jac_abi64.c: {missing}";
}

"""The built floor, not just its C source, defines every adapted symbol.

This is the check that was missing when #7149 added __jac64_realloc: the
source test above passed, the fixtures linked (none of them reached realloc),
and the gap only showed up in a user's project. Scanning the bitcode catches a
floor compiled from an older tree no matter what any fixture happens to call.
"""
test "the built floor defines every abi64 adapter" {
    _require_libc();
    import from jaclang.compiler.backends.native.wasm_build { _ABI64_ADAPTED }
    libc_dir = _wasm_libc_dir();
    assert libc_dir is not None;
    blobs = [
        Path(os.path.join(libc_dir, f)).read_bytes()
        for f in os.listdir(libc_dir)
        if f.endswith(".bc")
    ];
    assert blobs , f"no bitcode in {libc_dir}";
    missing = [];
    for nm in sorted(_ABI64_ADAPTED) {
        needle = ("__jac64_" + nm).encode();
        if not any([needle in b for b in blobs]) {
            missing.append(nm);
        }
    }
    assert not missing , f"floor at {libc_dir} defines no adapter for {missing}; rebuild it with `zig build vendor-wasm-libc`";
}

# ─── source-manifest verification ────────────────────────────────────────────
# The adapter and import checks are symbol-presence checks: a floor whose
# jac_alloc.c changed behaviour but kept its symbols links cleanly and ships
# the old code. SOURCES.sha256 is what closes that, and it is the same file
# the payload tool uses as its incremental-rebuild key.
test "a floor built from different wasm_rt sources is refused" {
    _require_libc();
    import from jaclang.compiler.backends.native.floors {
        WASM_FLOOR_MANIFEST as FLOOR_MANIFEST
    }
    src = _manifested_libc_dir();
    assert src is not None;
    if not os.path.isfile(os.path.join(src, FLOOR_MANIFEST)) {
        testskip("no floor with a SOURCES.sha256 here");
    }
    d = tempfile.mkdtemp();
    floor = os.path.join(d, "libc");
    shutil.copytree(src, floor);
    # Rewrite one entry's digest rather than editing the real tree: the check
    # compares recorded bytes against what is on disk, so a wrong record is
    # indistinguishable from a source that moved underneath the floor.
    man = os.path.join(floor, FLOOR_MANIFEST);
    rows = Path(man).read_text().splitlines();
    patched = [];
    hit = "";
    for row in rows {
        if row.endswith(" jac_alloc.c") and not hit {
            hit = "jac_alloc.c";
            patched.append(("0" * 64) + " jac_alloc.c");
        } else {
            patched.append(row);
        }
    }
    assert hit , "manifest has no jac_alloc.c entry";
    Path(man).write_text("\n".join(patched) + "\n");

    import from jaclang.artifacts.model { ArtifactUnavailable }
    def emit -> str {
        try {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    try {
        msg = _with_floor(floor, emit);
        assert "wasm_rt/jac_alloc.c changed" in msg , msg;
        assert "jac native build wasm-libc" in msg , msg;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

"""A checkout or kit floor with no manifest cannot be checked against wasm_rt/,
so the router reports it stale instead of linking it unverified."""
test "a floor without a manifest is refused until it is rebuilt" {
    _require_libc();
    import from jaclang.compiler.backends.native.floors {
        WASM_FLOOR_MANIFEST as FLOOR_MANIFEST
    }
    src = _wasm_libc_dir();
    assert src is not None;
    d = tempfile.mkdtemp();
    floor = os.path.join(d, "libc");
    shutil.copytree(src, floor);
    man = os.path.join(floor, FLOOR_MANIFEST);
    if os.path.exists(man) {
        os.remove(man);
    }
    import from jaclang.artifacts.model { ArtifactUnavailable }
    def emit -> str {
        try {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    try {
        msg = _with_floor(floor, emit);
        assert "no source manifest" in msg , msg;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

"""[memory] profile = "nogc" promises an RC-free artifact; the audit is what makes
compile_to_wasm fail loudly instead of shipping RC machinery the shim then has
to service. Pure-IR checks -- no vendored libc needed."""
test "rc audit passes clean IR and rejects rc machinery" {
    import from jaclang.compiler.backends.native.wasm_build { _assert_ir_rc_free }
    _assert_ir_rc_free("define void @jac_entry() {\nret void\n}", "clean.jac");
    dirty = "declare void @__rc_retain(ptr)\ndefine void @jac_entry() {\nret void\n}";
    raised = False;
    try {
        _assert_ir_rc_free(dirty, "dirty.jac");
    } except RuntimeError as e {
        raised = True;
        assert "__rc_retain" in str(e);
    }
    assert raised;
}

test "rc audit rejects entry-point gc env probes" {
    import from jaclang.compiler.backends.native.wasm_build { _assert_ir_rc_free }
    probing = '@.s = constant [7 x i8] c"JAC_GC\\00"';
    raised = False;
    try {
        _assert_ir_rc_free(probing, "probe.jac");
    } except RuntimeError {
        raised = True;
    }
    assert raised;
}
