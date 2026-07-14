"""Tests for the na->wasm build contract (#7048).

The vendored wasm_rt libc folds pure-compute libc INTO the module, the
remaining host surface rides the versioned jac_host1 import module, app FFI
stays under "env", and anything else is a build-time error instead of a
browser LinkError. These tests skip when the vendored bitcode is absent
(`zig build vendor-wasm-libc` populates .pbs-build/wasm32/libc).
"""

import os;
import subprocess;
import shutil;
import tempfile;
import pytest;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.wasm_build {
    emit_wasm_from_ir,
    wasm_import_map,
    _wasm_libc_dir
}
import from jaclang.compiler.passes.native.wasm_host_abi {
    WASM_HOST_ABI,
    WASM_HOST_MODULE
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = "wasm_host_probe.na.jac";

# ─── helpers ─────────────────────────────────────────────────────────────────
def _require_libc {
    if _wasm_libc_dir() is None {
        pytest.skip(
            "vendored wasm libc not present (run `zig build vendor-wasm-libc`)"
        );
    }
}

"""Compile the shared fixture to LLVM IR text (the emit_wasm_from_ir input)."""
def fixture_ir -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, FIXTURE),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        assert not prog.errors_had;
        return str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
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

    with pytest.raises(RuntimeError) as exc {
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
        pytest.skip("node not available");
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
        pytest.skip("node not available");
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
    assert last == 'out="3.14\\n11\\nup\\n" compute=21' , f"unexpected: {last}";
}
