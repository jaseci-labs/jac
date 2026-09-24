"""A JIT unit learns its linked units' demotion verdicts before it emits.

A free function that demotes to its Python fallback is renamed
`f.__jac_demoted`, so a native caller must refuse the call (E5092) and demote
with it instead of referencing `f`. The aot lane has learned the verdict
before emission since #8272; the JIT lane -- `jac run`, `jac test`, any module
that gets its own engine -- answered "no verdict" and forward-declared every
imported function as live. With a cold cache the importer emitted `call f`,
the link brought in only `f.__jac_demoted`, and MCJIT resolved the dangling
reference (and the rest of that relocation batch) to null: the first native
call segfaulted with no diagnostic. A warm cache hid it, because the
dependency's cached metadata carries the verdict.

A unit the JIT link compiles anyway now has its verdict taken first, from the
memoized compile the link then consumes. That memo can outlive a compile
whose importer fails and falls back to the server codespace; releasing it
must evict the tree from the context program whose hub holds it, or a later
JIT import finds that tree with its native products cleared and demotes a
healthy module.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import ctypes;
import from tests.support { get_func, jac_command, TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.na_compile_pass {
    native_demoted_ir_symbols
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""The JIT lane with nothing cached: the importer gets an engine and must
learn each linked unit's verdict before it emits."""
def cold_jit_opts -> CompileOptions {
    return CompileOptions(
        force_codespace='native', force_target_program=True, no_ir_cache=True
    );
}

"""Every `declare` line in the IR that names `symbol` as a callee."""
def dangling_declares(llvm_ir_text: str, symbol: str) -> list[str] {
    return [
        line.strip()
        for line in llvm_ir_text.splitlines()
        if line.lstrip().startswith("declare")
            and (f"@{symbol}(" in line or f'@"{symbol}"(' in line)
    ];
}

"""Compile a fixture on the cold JIT lane; return (program, module, linked IR)."""
def compile_cold(fixture: str) -> tuple[JacProgram, any, str] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=cold_jit_opts()
    );
    assert not prog.errors_had , f"{[e.pretty_print() for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir is not None , f"no native IR for {fixture}";
    assert ir.gen.native_engine is not None , f"no JIT engine for {fixture}";
    return (prog, ir, str(ir.gen.llvm_ir));
}

"""Copy fixtures into a fresh directory and `jac run` the first one there, so
no module cache from an earlier run can supply the verdicts."""
def cold_run(*fixtures: str) -> subprocess.CompletedProcess {
    work = os.path.realpath(tempfile.mkdtemp(prefix="jac_jit_verdicts_"));
    try {
        for name in fixtures {
            shutil.copy(os.path.join(FIXTURES, name), os.path.join(work, name));
        }
        return subprocess.run(
            jac_command("run", os.path.join(work, fixtures[0])),
            cwd=work,
            capture_output=True,
            text=True,
            timeout=900
        );
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
}

def stdout_lines(proc: subprocess.CompletedProcess) -> list[str] {
    return [
        line.strip()
        for line in proc.stdout.splitlines()
        if line.strip()
    ];
}

test "a cold JIT importer demotes a caller of a demoted linked function" {
    (prog, ir, text) = compile_cold("xmod_demote_main.jac");
    assert not dangling_declares(text, "pyonly_len") , (
        "the importer emitted a call to 'pyonly_len' before learning that "
        f"xmod_demote_lib demotes it: {dangling_declares(text, 'pyonly_len')}"
    );
    demoted = native_demoted_ir_symbols(text);
    assert "pyonly_len" in demoted , f"the callee lowered after all: {demoted}";
    assert "call_seam" in demoted , (
        f"the caller of the demoted function stayed native: {demoted}"
    );
    assert "call_clean" not in demoted , f"the clean caller demoted: {demoted}";
    call_clean = get_func(
        ir.gen.native_engine, "call_clean", ctypes.c_int64, ctypes.c_int64
    );
    assert call_clean(2) == 4;
}

test "a cold JIT importer sees a demotion only the callee's emitter discovers" {
    (prog, ir, text) = compile_cold("xmod_demote_dyn_main.jac");
    assert not dangling_declares(text, "from_code") , (
        "the importer emitted a call to 'from_code' before its unit refused it: "
        f"{dangling_declares(text, 'from_code')}"
    );
    demoted = native_demoted_ir_symbols(text);
    assert "call_dyn" in demoted , f"the caller of 'from_code' stayed native: {demoted}";
    assert "call_double" not in demoted , f"the clean caller demoted: {demoted}";
    call_double = get_func(
        ir.gen.native_engine, "call_double", ctypes.c_int64, ctypes.c_int64
    );
    assert call_double(2) == 5;
}

test "jac run with a cold cache runs a caller of a demoted import" {
    proc = cold_run("xmod_demote_main.jac", "xmod_demote_lib.jac");
    assert proc.returncode == 0 , (
        f"exit {proc.returncode}: {proc.stderr[-900:] or '(no stderr)'}"
    );
    assert stdout_lines(proc) == ["4"] , f"printed {stdout_lines(proc)}";
}

test "an importer's fallback leaves its dependencies native for their own import" {
    proc = cold_run(
        "jit_release_main.jac", "jit_release_mid.jac", "jit_release_leaf.jac"
    );
    assert proc.returncode == 0 , (
        f"exit {proc.returncode}: {proc.stderr[-900:] or '(no stderr)'}"
    );
    assert stdout_lines(proc) == ["2", "13"] , f"printed {stdout_lines(proc)}";
    assert "jit_release_main.jac preferred native but did not lower" in proc.stderr , (
        f"the entry's call into the seam lowered: {proc.stderr[-900:]}"
    );
    assert "jit_release_mid.jac preferred native but did not lower"
        not in proc.stderr , (
        "the released dependency tree stayed in its context hub with its native "
        f"products cleared, so the module's own import demoted: {proc.stderr[-900:]}"
    );
}
