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
    wasm_import_map,
    _wasm_libc_dir
}
import from jaclang.compiler.backends.native.wasm_host_abi {
    WASM_HOST_ABI,
    WASM_HOST_MODULE
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "wasm_host_probe.jac";

# ─── helpers ─────────────────────────────────────────────────────────────────
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

test "missing vendored libc falls back to the legacy env-import surface" {
    prev = os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", None);
    os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = os.path.join(
        tempfile.mkdtemp(), "definitely-missing"
    );
    try {
        mod = emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_WASM_LIBC_DIR", None);
        } else {
            os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = prev;
        }
    }
    imports = wasm_import_map(mod);
    # legacy single-namespace behavior: libc leaks as env imports, no jac_host1
    assert WASM_HOST_MODULE not in imports;
    assert "malloc" in imports.get("env", []);
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
    src = _wasm_libc_dir();
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
    prev = os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", None);
    os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = floor;
    try {
        with testraises(RuntimeError) as ei {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        }
        msg = str(ei.value);
        assert "is stale" in msg , msg;
        assert "__jac64_" in msg , msg;
        # Names the floor, never tells the reader to touch the host ABI.
        assert floor in msg , msg;
        assert "wasm_host_abi" not in msg , msg;
    } finally {
        if prev is None {
            del os.environ["JAC_NATIVE_WASM_LIBC_DIR"];
        } else {
            os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = prev;
        }
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "every adapted libc name has a floor adapter" {
    _require_libc();
    import from jaclang.compiler.backends.native.wasm_build {
        _ABI64_ADAPTED,
        _wasm_rt_src_dir
    }
    src = os.path.join(_wasm_rt_src_dir(), "jac_abi64.c");
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
    import from jaclang.compiler.backends.native.wasm_build { FLOOR_MANIFEST }
    src = _wasm_libc_dir();
    assert src is not None;
    if not os.path.isfile(os.path.join(src, FLOOR_MANIFEST)) {
        testskip("floor predates SOURCES.sha256");
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

    prev = os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", None);
    os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = floor;
    try {
        with testraises(RuntimeError) as ei {
            emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        }
        msg = str(ei.value);
        assert "different wasm_rt sources" in msg , msg;
        assert "jac_alloc.c" in msg , msg;
    } finally {
        if prev is None {
            del os.environ["JAC_NATIVE_WASM_LIBC_DIR"];
        } else {
            os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = prev;
        }
        shutil.rmtree(d, ignore_errors=True);
    }
}

"""A floor with no manifest is unverifiable, not wrong: older artifacts and
hand-built floors must keep working rather than hard-fail on a missing file."""
test "a floor without a manifest still links" {
    _require_libc();
    import from jaclang.compiler.backends.native.wasm_build { FLOOR_MANIFEST }
    src = _wasm_libc_dir();
    assert src is not None;
    d = tempfile.mkdtemp();
    floor = os.path.join(d, "libc");
    shutil.copytree(src, floor);
    man = os.path.join(floor, FLOOR_MANIFEST);
    if os.path.exists(man) {
        os.remove(man);
    }
    prev = os.environ.get("JAC_NATIVE_WASM_LIBC_DIR", None);
    os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = floor;
    try {
        mod = emit_wasm_from_ir(fixture_ir(), [], app_imports=set());
        assert mod and len(mod) > 0;
    } finally {
        if prev is None {
            del os.environ["JAC_NATIVE_WASM_LIBC_DIR"];
        } else {
            os.environ["JAC_NATIVE_WASM_LIBC_DIR"] = prev;
        }
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
