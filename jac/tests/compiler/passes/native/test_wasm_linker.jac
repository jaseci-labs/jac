"""Tests for the wasm32 link path.

These exercise the wasm *infra* -- the pure-Jac `WasmLinker`'s relocatable
object -> instantiable module transformation (LEB encoding, dropping placeholder
env imports, synthesizing memory / __stack_pointer / __heap_base / the
indirect-function table+elem, and rewriting relocations) and the
`nacompile --target wasm32` CLI -- not LLVM codegen, which the rest of the
native suite already covers. One representative fixture (objects + lists + a
mutable global) drives the linker's whole transform: it pulls in every
supported relocation kind, the malloc/memcpy import surface, a data segment,
and the indirect-call table.
"""

import os;
import subprocess;
import sys;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.wasm_linker {
    WasmLinker,
    _uleb,
    _uleb5,
    _sleb_bytes,
    _rd_uleb,
    _rd_sleb,
    _u32le
}
import llvmlite.binding as llvm;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     WASM_TRIPLE = "wasm32-unknown-unknown",
     FIXTURE = "wasm_objects.na.jac";

# ─── helpers ─────────────────────────────────────────────────────────────────
"""Compile a fixture to a relocatable wasm object the way `nacompile` does."""
def emit_wasm_object(fixture: str) -> bytes {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = WASM_TRIPLE;
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        assert not prog.errors_had , f"compile errors: {[
            str(e) for e in prog.errors_had
        ]}";
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        mod = llvm.parse_assembly(str(ir.gen.llvm_ir));
        mod.verify();
        tm = llvm.Target.from_triple(WASM_TRIPLE).create_target_machine(opt=2);
        pto = llvm.create_pipeline_tuning_options(speed_level=2, size_level=0);
        pb = llvm.create_pass_builder(tm, pto);
        pb.getModulePassManager().run(mod, pb);
        relobj = tm.emit_object(mod);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return relobj;
}

"""Top-level section spans -> list of (id, payload_start, payload_end)."""
def sections(b: bytes) -> list {
    o = 8;
    out = [];
    while o < len(b) {
        sid = b[o];
        o += 1;
        (sz, o) = _rd_uleb(b, o);
        out.append((sid, o, o + sz));
        o += sz;
    }
    return out;
}

def has_section(b: bytes, want: int) -> bool {
    for (sid, s, e) in sections(b) {
        if sid == want {
            return True;
        }
    }
    return False;
}

"""Names of imported functions (kind 0) in the module's import section."""
def func_imports(b: bytes) -> list {
    out = [];
    for (sid, s, e) in sections(b) {
        if sid != 2 {
            continue;
        }
        (n, o) = _rd_uleb(b, s);
        i = 0;
        while i < n {
            (mlen, o) = _rd_uleb(b, o);
            o += mlen;
            (flen, o) = _rd_uleb(b, o);
            fld = b[o:o + flen].decode("latin1");
            o += flen;
            k = b[o];
            o += 1;
            if k == 0 {
                (ti, o) = _rd_uleb(b, o);
                out.append(fld);
            } elif k == 1 {
                o += 2;
                (mn, o) = _rd_uleb(b, o);
            } elif k == 2 {
                fl = b[o];
                o += 1;
                (mn, o) = _rd_uleb(b, o);
                if fl & 1 {
                    (mx, o) = _rd_uleb(b, o);
                }
            } elif k == 3 {
                o += 2;
            }
            i += 1;
        }
    }
    return out;
}

"""Names exported by the module."""
def export_names(b: bytes) -> list {
    out = [];
    for (sid, s, e) in sections(b) {
        if sid != 7 {
            continue;
        }
        (n, o) = _rd_uleb(b, s);
        i = 0;
        while i < n {
            (ln, o) = _rd_uleb(b, o);
            out.append(b[o:o + ln].decode("latin1"));
            o += ln;
            o += 1;
            (idx, o) = _rd_uleb(b, o);
            i += 1;
        }
    }
    return out;
}

# ─── tests ───────────────────────────────────────────────────────────────────
test "LEB and fixed-width byte encoders round-trip" {
    for v in [0, 1, 63, 64, 127, 128, 300, 16384, 1 << 28, (1 << 31) - 1] {
        assert _rd_uleb(_uleb(v), 0)[0] == v;
        assert len(_uleb5(v)) == 5;  # always 5 bytes (in-place reloc safe)
        assert _rd_uleb(_uleb5(v), 0)[0] == v;  # padded form still decodes to v
    }
    for v in [-1, -64, -8192, 0, 12345, -123456] {
        assert _rd_sleb(_sleb_bytes(v), 0)[0] == v;
    }
    assert _u32le(0x01020304) == bytes([4, 3, 2, 1]);
}

test "linker emits a well-formed module with synthesized memory/globals/exports" {
    mod = WasmLinker.link(emit_wasm_object(FIXTURE), [], 256);

    # valid wasm header
    assert mod[0:4] == b"\x00asm";
    assert mod[4:8] == bytes([1, 0, 0, 0]);

    # placeholder env imports are resolved by the linker, not left as imports;
    # genuine undefined externs stay as imports for the JS host to satisfy.
    imps = func_imports(mod);
    assert "__linear_memory" not in imps;
    assert "__stack_pointer" not in imps;
    assert "malloc" in imps and "free" in imps and "memcpy" in imps;
    # the JS-unshimmable libc never gets pulled in (would force a wasi runtime)
    assert "setjmp" not in imps and "longjmp" not in imps;

    # synthesized exports: linear memory, the magic globals, and every defined fn
    exps = export_names(mod);
    for name in [
        "memory",
        "__stack_pointer",
        "__heap_base",
        "demo",
        "make",
        "sum_x",
        "call_count"
    ] {
        assert name in exps , f"missing export {name}";
    }

    # the transform synthesizes memory + globals + a data segment, and -- because
    # the objects use vtable dispatch (an indirect call) -- a table + elem segment.
    assert has_section(mod, 5);  # memory
    assert has_section(mod, 6);  # global (__stack_pointer / __heap_base)
    assert has_section(mod, 11);  # data
    assert has_section(mod, 4);  # table
    assert has_section(mod, 9);  # elem
}

test "linking is deterministic" {
    relobj = emit_wasm_object(FIXTURE);
    assert WasmLinker.link(relobj, [], 256) == WasmLinker.link(relobj, [], 256);
}

test "nacompile --target wasm32 writes a valid module via the CLI" {
    out = os.path.join(tempfile.mkdtemp(), "game.wasm");
    proc = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            "--target",
            "wasm32",
            os.path.join(FIXTURES, FIXTURE),
            "-o",
            out
        ],
        capture_output=True,
        text=True,
        timeout=300
    );
    assert proc.returncode == 0 , f"nacompile failed: {proc.stderr}\n{proc.stdout}";
    assert os.path.exists(out);
    data = Path(out).read_bytes();
    assert data[0:4] == b"\x00asm";
    assert "demo" in export_names(data);
}

test "linked module instantiates and runs under node" {
    node_bin = shutil.which("node");
    if not node_bin {
        import pytest;
        pytest.skip("node not available");
    }
    mod = WasmLinker.link(emit_wasm_object(FIXTURE), [], 256);
    d = tempfile.mkdtemp();
    wpath = os.path.join(d, "m.wasm");
    Path(wpath).write_bytes(mod);
    # JS host: a bump allocator over exported memory + the small runtime surface.
    harness = """
import { readFileSync } from "fs";
const M = {};
const env = {
  malloc: (n) => { n = Number(n); const p = M.h; M.h = (M.h + n + 7) & ~7; return p; },
  calloc: (c, s) => { const n = Number(c) * Number(s); const p = M.h; M.h = (M.h + n + 7) & ~7;
                      new Uint8Array(M.mem.buffer).fill(0, p, p + n); return p; },
  free: () => {}, malloc_usable_size: () => 0,
  memcpy: (d, s, n) => { new Uint8Array(M.mem.buffer).copyWithin(d, s, s + Number(n)); return d; },
  memcmp: (a, b, n) => { const m = new Uint8Array(M.mem.buffer); n = Number(n);
    for (let i = 0; i < n; i++) { const e = m[a+i] - m[b+i]; if (e) return e; } return 0; },
  puts: () => 0, printf: () => 0, snprintf: () => 0, getenv: () => 0, fflush: () => 0,
  abort: () => { throw new Error("abort"); },
  __multi3: (res, al, ah, bl, bh) => { const K = (1n<<64n)-1n;
    const a = (BigInt.asUintN(64,ah)<<64n)|BigInt.asUintN(64,al);
    const b = (BigInt.asUintN(64,bh)<<64n)|BigInt.asUintN(64,bl);
    const p = BigInt.asUintN(128, a*b); const dv = new DataView(M.mem.buffer);
    dv.setBigUint64(res, p & K, true); dv.setBigUint64(res+8, (p>>64n) & K, true); },
};
const { instance } = await WebAssembly.instantiate(readFileSync(process.argv[2]), { env });
const e = instance.exports;
M.mem = e.memory; M.h = e.__heap_base.value;
e.__jac_glob_init();
const d1 = Number(e.demo(5n));   // sum of x over Pt(0..4) = 10
e.demo(5n);                       // second call bumps the persisted global
console.log(`demo=${d1} calls=${Number(e.call_count())}`);
""";
    hpath = os.path.join(d, "run.mjs");
    Path(hpath).write_text(harness);
    proc = subprocess.run(
        [node_bin, hpath, wpath], capture_output=True, text=True, timeout=60
    );
    assert proc.returncode == 0 , f"node failed: {proc.stderr}";
    last = proc.stdout.strip().splitlines()[-1];
    # demo(5)==10 proves data/memory-addr relocs + heap layout; calls==2 proves the
    # mutable global persists across calls (global load/store resolved correctly).
    assert last == "demo=10 calls=2" , f"unexpected output: {last}";
}
