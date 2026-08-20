"""Cross-module demotion is part of the link protocol (#8265).

The invariant: a lowered caller may only reference callees that also
lowered. Intra-module, #8206's partition settles every verdict before any
body is emitted. Across a unit boundary the verdict used to arrive too
late: the importer forward-declared every imported free function, emitted
call sites against the original names, and only later did
`_compile_and_link_native_imports` compile the dependency -- whose own
demotions renamed `f` to `f.__jac_demoted` so the Python fallback owns the
name. The already-emitted caller kept referencing `f`, the linked artifact
carried an undefined symbol, and the artifact failed its dlopen canary at
seal time (S5's `undefined symbol: build_type_var_solution`).

These tests pin the protocol that closes the gap: the importer learns the
dependency's demotion verdicts before its own emission (compiling the
dependency for them when nothing has cached a verdict yet), refuses call
sites into demoted callees with the same E5092 an intra-module refusal
gets, and cascades the caller into a coverage seam whose reason names the
cross-module callee. The linked IR must carry no declaration of the
renamed symbol, the importer's layout must not advertise the demoted
callee or its cascaded caller, and the artifact must pass the same
dlopen + initialize canary the seal runs -- subprocess-isolated, so a bad
artifact can only fail its own process.

Both demotion classes cross the boundary. `xmod_demote_lib.jac` is the
capability class: the partition sees the body-scoped Python import
statically. `xmod_demote_dyn_lib.jac` is the S5 class: an enum invoked as
a constructor, which only the backend's emitter refuses, so no AST-level
check can know the callee will demote -- the verdict exists only after the
dependency's own codegen has run. Since #8266 the int-valued spelling of
that call lowers, so the fixture carries the string-valued one, whose
runtime form is the ordinal rather than the value; the refusal is the same
emit-time-only class either way.
"""

import ctypes;
import os;
import subprocess;
import sys;
import tempfile;
import from jaclang.compiler.passes.native.shared_emit { emit_shared_library }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     _CANARY_DRIVER: str = (
         "import ctypes, sys\n"
         "lib, raw = sys.argv[1], sys.argv[2]\n"
         "syms = [s for s in raw.split(',') if s]\n"
         "try:\n"
         "    h = ctypes.CDLL(lib)\n"
         "except OSError as e:\n"
         "    print('dlopen failed:', e)\n"
         "    raise SystemExit(0)\n"
         "missing = []\n"
         "for s in syms + ['__jac_shared_init']:\n"
         "    try:\n"
         "        getattr(h, s)\n"
         "    except AttributeError:\n"
         "        missing.append(s)\n"
         "if missing:\n"
         "    print('missing exports:', ','.join(sorted(missing)))\n"
         "    raise SystemExit(0)\n"
         "init = ctypes.cast(getattr(h, '__jac_shared_init'), ctypes.c_void_p)\n"
         "ctypes.CFUNCTYPE(None)(init.value)()\n"
         "try:\n"
         "    raw_fn = getattr(h, 'jac_str_new')\n"
         "except AttributeError:\n"
         "    print('CANARY_OK')\n"
         "    raise SystemExit(0)\n"
         "addr = ctypes.cast(raw_fn, ctypes.c_void_p).value\n"
         "made = ctypes.CFUNCTYPE(\n"
         "    ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64\n"
         ")(addr)(b'jac', 3)\n"
         "print('CANARY_OK' if made else 'jac_str_new returned NULL')\n"
     );

"""The seal's compile options, up to the coverage."""
def _seal_opts -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        na_gc_mode='cycles',
        no_ir_cache=True
    );
}

"""Compile a fixture under the coverage; return (program, module, coverage)."""
def _compile_with_coverage(fixture: str) -> tuple {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture), options=_seal_opts()
        );
    } finally {
        coverage = na_coverage_end();
    }
    return (prog, ir, coverage);
}

"""The coverage seam list recorded for a fixture path."""
def _seams_of(coverage: dict, fixture: str) -> list[str] {
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}

"""Every `declare` line in the IR that names `symbol` as a callee."""
def _dangling_declares(llvm_ir_text: str, symbol: str) -> list[str] {
    return [
        line.strip()
        for line in llvm_ir_text.splitlines()
        if line.lstrip().startswith("declare")
            and (f"@{symbol}(" in line or f'@"{symbol}"(' in line)
    ];
}

"""Link the module the way the seal does and run the dlopen canary on it,
subprocess-isolated; returns the canary verdict line."""
def _link_and_canary(ir: object, stem: str) -> str {
    layout = ir.gen.native_layout;
    clib_syms = set((ir.gen._clib_symbol_lib or {}).keys());
    exports = sorted(
        fn_name
        for fn_name in layout.functions.keys()
        if fn_name not in clib_syms
    );
    manifest = ir.gen.interop_manifest;
    transitive = list(manifest.native_transitive_sources) if manifest else [];
    out_dir = tempfile.mkdtemp(prefix="jac_xmod_demote_");
    lib_path = os.path.join(out_dir, f"libjac_{stem}.so");
    (ok, err) = emit_shared_library(
        str(ir.gen.llvm_ir),
        transitive,
        exports,
        lib_path,
        clib_paths=list(ir.gen._clib_paths or []),
        clib_symbol_lib=dict(ir.gen._clib_symbol_lib or {})
    );
    assert ok , f"emit_shared_library failed: {err}";
    res = subprocess.run(
        [sys.executable, "-c", _CANARY_DRIVER, lib_path, ",".join(exports)],
        capture_output=True,
        text=True,
        timeout=300
    );
    if res.returncode != 0 {
        return f"canary subprocess died rc={res.returncode}: {res.stderr[-400:]}";
    }
    return (res.stdout.strip().splitlines() or ["no canary output"])[-1];
}

"""One full pass over a fixture pair: compile, assert the cascade, link,
canary. `callee` is the dependency function that demotes, `caller` the
importer function that must cascade, `clean_caller` the sibling that must
stay lowered."""
def _assert_link_protocol(
    fixture: str, stem: str, callee: str, caller: str, clean_caller: str
) {
    (prog, ir, coverage) = _compile_with_coverage(fixture);
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a cross-module demotion must cascade, not fail the compile: {errors}"
    );
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "the importer must keep its LLVM IR when one caller cascades"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert clean_caller in layout.functions , (
        f"clean sibling caller was lost: {sorted(layout.functions)}"
    );
    assert caller not in layout.functions , (
        f"'{caller}' calls demoted '{callee}' across the module boundary and "
        f"must cascade out of the native layout: {sorted(layout.functions)}"
    );
    assert callee not in layout.functions , (
        f"the importer must not advertise the demoted dependency function "
        f"'{callee}' as one of its own exports: {sorted(layout.functions)}"
    );
    dangling = _dangling_declares(str(ir.gen.llvm_ir), callee);
    assert not dangling , (
        f"the linked IR still declares the renamed symbol '{callee}', which "
        f"can never resolve: {dangling}"
    );
    seams = _seams_of(coverage, fixture);
    cascade = [
        s
        for s in seams
        if s.startswith(f"{caller}: ")
    ];
    assert cascade , (
        f"the coverage must record '{caller}' as a seam of the importer: {seams}"
    );
    assert callee in cascade[0] , (
        f"the cascade reason must name the cross-module callee '{callee}': "
        f"{cascade[0]}"
    );
    verdict = _link_and_canary(ir, stem);
    assert verdict == "CANARY_OK" , (
        f"the sealed-artifact canary must pass once the caller cascades: " f"{verdict}"
    );
}

test "a capability-demoted cross-module callee cascades its caller" {
    _assert_link_protocol(
        "xmod_demote_main.jac",
        "xmod_demote_main",
        "pyonly_len",
        "call_seam",
        "call_clean"
    );
}

test "an emit-time-demoted cross-module callee cascades its caller" {
    _assert_link_protocol(
        "xmod_demote_dyn_main.jac",
        "xmod_demote_dyn_main",
        "from_code",
        "call_dyn",
        "call_double"
    );
}

test "the dependency's demotion is still recorded as the dependency's seam" {
    (prog, ir, coverage) = _compile_with_coverage("xmod_demote_main.jac");
    dep_seams = _seams_of(coverage, "xmod_demote_lib.jac");
    assert any(s.startswith("pyonly_len: ") for s in dep_seams) , (
        f"the dependency's own seam must stay attributed to it: {dep_seams}"
    );
}
