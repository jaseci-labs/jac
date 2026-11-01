"""A JIT unit learns its linked units' demotion verdicts before it emits.

A free function that demotes to its Python fallback has no native body, so a
native caller must refuse the call and demote with it instead of referencing
the function. The aot lane has learned the verdict before emission since
#8272; the JIT lane -- `jac run`, `jac test`, any module that gets its own
engine -- once answered "no verdict" and forward-declared every imported
function as live. With a cold cache the importer emitted `call f`, the link
brought in no `f`, and MCJIT resolved the dangling reference (and the rest of
that relocation batch) to null: the first native call segfaulted with no
diagnostic. A warm cache hid it, because the dependency's cached metadata
carries the verdict.

The decision step now settles each native dependency's verdict before the
importer emits, whichever lane it runs in, and the link then consumes the
same unit. An importer that fails and falls back to the server codespace
leaves its dependencies' units intact, so their own imports stay native.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import ctypes;
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    names_function,
    source_spelled,
    TESTS_DIR
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Every `declare` line in the IR that names `name` as a callee."""
def dangling_declares(llvm_ir_text: str, name: str) -> list[str] {
    return [
        line.strip()
        for line in llvm_ir_text.splitlines()
        if line.lstrip().startswith("declare") and names_function(line, name)
    ];
}

"""The functions a linked unit's own compile demoted, by source spelling."""
def unit_demotions(fx: any, fixture: str) -> list[str] {
    unit = fx.result.unit(os.path.join(FIXTURES, fixture));
    return [source_spelled(demotion.symbol) for demotion in unit.demoted];
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
    fx = compile_native_ir("xmod_demote_main.jac");
    assert not dangling_declares(fx.llvm_ir(), "pyonly_len") , (
        "the importer emitted a call to 'pyonly_len' before learning that "
        f"xmod_demote_lib demotes it: {dangling_declares(fx.llvm_ir(), 'pyonly_len')}"
    );
    lib_demoted = unit_demotions(fx, "xmod_demote_lib.jac");
    assert any(sym.endswith(".pyonly_len") for sym in lib_demoted) , (
        f"the callee lowered after all: {lib_demoted}"
    );
    assert fx.is_demoted("call_seam") , (
        f"the caller of the demoted function stayed native: {fx.demoted()}"
    );
    assert not fx.is_demoted("call_clean") , f"the clean caller demoted: {fx.demoted()}";
    (eng, _) = compile_native("xmod_demote_main.jac");
    call_clean = get_func(eng, "call_clean", ctypes.c_int64, ctypes.c_int64);
    assert call_clean(2) == 4;
}

test "a cold JIT importer sees a demotion only the callee's body reveals" {
    fx = compile_native_ir("xmod_demote_dyn_main.jac");
    assert not dangling_declares(fx.llvm_ir(), "from_code") , (
        "the importer emitted a call to 'from_code' before its unit refused it: "
        f"{dangling_declares(fx.llvm_ir(), 'from_code')}"
    );
    assert fx.is_demoted("call_dyn") , (
        f"the caller of 'from_code' stayed native: {fx.demoted()}"
    );
    assert not fx.is_demoted("call_double") , f"the clean caller demoted: {fx.demoted()}";
    (eng, _) = compile_native("xmod_demote_dyn_main.jac");
    call_double = get_func(eng, "call_double", ctypes.c_int64, ctypes.c_int64);
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
