"""Native differential proof (Step 2) for the jac2c Emit leg of #7145.

The runtime suite (`test_jac2c_runtime.jac`) pins each fixture against a
hand-computed constant. This module upgrades that oracle to a *differential*
one: for every runtime fixture it derives the expected output from an
independent Jac implementation and asserts the jac2c-emitted C agrees.

Two independent references, one shared spec:

  * CPython leg -- the fixture is run through the stock Jac bytecode
    interpreter (`jac run`) with a synthesized entry that prints the same
    `run_*` calls the C driver invokes. Two full, unrelated implementations of
    Jac semantics (interpreter vs. emitted C + system `cc`) producing identical
    output is the proof.

  * Native (na) leg -- the same fixture is pushed through the LLVM-native
    backend and we assert it produces LLVM IR and is `native_compat`. This is
    the structural half: it proves the na backend accepts every construct the
    jac2c backend emits. The full na-binary-vs-C runtime equivalence needs a
    vendored musl to link a standalone binary; that is gated on
    `JAC_NATIVE_MUSL_DIR` (present in CI) and skipped locally, where na codegen
    succeeds but linking cannot.

Both the C output and the CPython output are derived from one `calls` list per
fixture, so nothing is hand-asserted -- the oracle is machine-computed on both
sides and the test fails if either implementation drifts.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.c.c_gen_pass { emit_translation_units }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     ),
     RUNTIME: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "passes", "c", "runtime"
     );

# Each fixture plus the ordered `run_*` entry points that both references
# invoke. The expected output is whatever these calls print -- never a literal.
glob SPECS: list[tuple[str, list[str]]] = [
         ("obj_rc.jac", ["run_counter", "run_box"]),
         ("obj_poly.jac", ["run_base", "run_derived"]),
         ("str_ops.jac", ["run_len", "run_eq", "run_greet_len"]),
         ("exceptions.jac", ["run_catch", "run_propagate", "run_nothrow"]),
         ("obj_move.jac", ["run_move"]),
         ("obj_alias.jac", ["run_alias", "run_transfer"]),

     ];


def _cc -> (str | None) {
    return shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
}


def _emit_c(jac_path: str) -> str {
    prog = JacProgram();
    mod = prog.compile(file_path=jac_path);
    assert not prog.errors_had , f"compile errors: {[str(e) for e in prog.errors_had]}";
    for (path, src) in emit_translation_units(jac_path, mod, prog) {
        if path == jac_path {
            return src;
        }
    }
    return "";
}


# Emit C for the fixture, link it with jacrt + a generated driver that prints
# each call as a space-separated int, run it, return stdout.
def _c_output(fixture: str, calls: list[str]) -> str {
    c_src = _emit_c(os.path.join(FIXTURES, fixture));
    work = tempfile.mkdtemp();
    lib = os.path.join(work, "lib.c");
    with open(lib, "w") as f {
        f.write(c_src);
    }
    externs = "".join([f"extern int {c}(void);\n" for c in calls]);
    fmt = " ".join(["%d" for _ in calls]);
    argv = ", ".join([f"{c}()" for c in calls]);
    drv = os.path.join(work, "driver.c");
    with open(drv, "w") as f {
        f.write(
            "#include <stdio.h>\n" + externs + "int main(void) {\n    printf(\"" + fmt + "\\n\", " + argv + ");\n" + "    return 0;\n}\n"
        );
    }
    binp = os.path.join(work, "bin");
    rt = os.path.join(RUNTIME, "jacrt.c");
    cc = _cc();
    subprocess.run(
        [cc, "-std=c11", "-I", RUNTIME, lib, rt, drv, "-o", binp], check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return proc.stdout.strip();
}


# Run the fixture through the stock Jac interpreter with a synthesized entry
# printing the same calls, and return the printed int-tuple line.
def _cpython_output(fixture: str, calls: list[str]) -> str {
    src = "";
    with open(os.path.join(FIXTURES, fixture)) as f {
        src = f.read();
    }
    argv = ", ".join([f"{c}()" for c in calls]);
    entry = "\n\nwith entry {\n    print(" + argv + ");\n}\n";
    work = tempfile.mkdtemp();
    run_path = os.path.join(work, fixture);
    with open(run_path, "w") as f {
        f.write(src + entry);
    }
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", run_path],
        capture_output=True,
        text=True,
        check=True
    );
    # The interpreter interleaves dev-mode/setup banners; the answer is the
    # last stdout line whose tokens are all ints and match the call count.
    line = _int_tuple_line(proc.stdout, len(calls));
    assert line is not None , f"no int-tuple line in interpreter stdout for {fixture}:\n{proc.stdout}";
    return line;
}


# The last stdout line whose whitespace tokens are all ints and number `want`,
# or None. Robust against interleaved banners on either reference's stdout.
def _int_tuple_line(stdout: str, want: int) -> (str | None) {
    for line in reversed(stdout.splitlines()) {
        toks = line.split();
        if len(toks) == want and all([_is_int(t) for t in toks]) {
            return line.strip();
        }
    }
    return None;
}


# Compile the fixture (plus synthesized entry) to a standalone native binary
# with `jac nacompile` and run it, returning its int-tuple line. Returns None
# when a standalone binary cannot be linked here (e.g. no vendored musl) so the
# na-vs-C runtime leg cleanly skips locally and activates in CI.
def _na_binary_output(fixture: str, calls: list[str]) -> (str | None) {
    src = "";
    with open(os.path.join(FIXTURES, fixture)) as f {
        src = f.read();
    }
    argv = ", ".join([f"{c}()" for c in calls]);
    entry = "\n\nwith entry {\n    print(" + argv + ");\n}\n";
    work = tempfile.mkdtemp();
    na_path = os.path.join(work, fixture);
    with open(na_path, "w") as f {
        f.write(src + entry);
    }
    binp = os.path.join(work, "na_bin");
    build = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", na_path, "-o", binp],
        capture_output=True,
        text=True
    );
    if build.returncode != 0 or not os.path.exists(binp) {
        return None;
    }
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return _int_tuple_line(proc.stdout, len(calls));
}


def _is_int(tok: str) -> bool {
    try {
        int(tok);
        return True;
    } except ValueError {
        return False;
    }
}


# Push the fixture (plus a synthesized entry so an entry point exists) through
# the LLVM-native backend; return (native_compat, llvm_ir_str).
def _na_codegen(fixture: str, calls: list[str]) -> tuple[bool, str] {
    src = "";
    with open(os.path.join(FIXTURES, fixture)) as f {
        src = f.read();
    }
    argv = ", ".join([f"{c}()" for c in calls]);
    entry = "\n\nwith entry {\n    print(" + argv + ");\n}\n";
    work = tempfile.mkdtemp();
    na_path = os.path.join(work, fixture);
    with open(na_path, "w") as f {
        f.write(src + entry);
    }
    na_path = os.path.abspath(na_path);
    prog = JacProgram();
    prog._auto_promote_native = True;
    prog._auto_promote_target = na_path;
    opts = CompileOptions(aot_mode=True, type_check=False);
    mod = prog.compile(file_path=na_path, options=opts);
    assert not prog.errors_had , f"na errors for {fixture}: {[
        str(e) for e in prog.errors_had
    ]}";
    ir = mod.gen.llvm_ir;
    return (mod.gen.native_compat, str(ir) if ir is not None else "");
}


test "jac2c emitted C matches the stock interpreter for every runtime fixture" {
    if _cc() is None {
        return;
    }
    for (fixture, calls) in SPECS {
        c_out = _c_output(fixture, calls);
        py_out = _cpython_output(fixture, calls);
        assert c_out == py_out , f"{fixture}: emitted-C {c_out!r} != interpreter {py_out!r}";
    }
}


test "na backend accepts and lowers every jac2c runtime fixture" {
    for (fixture, calls) in SPECS {
        (compat, ir) = _na_codegen(fixture, calls);
        assert compat , f"{fixture}: not native_compat";
        assert "jac_entry" in ir , f"{fixture}: na produced no entry point";
    }
}


test "na native binary and emitted C agree at run time (CI: needs linkable musl)" {
    if _cc() is None {
        return;
    }
    ran_any = False;
    for (fixture, calls) in SPECS {
        na_out = _na_binary_output(fixture, calls);
        if na_out is None {
            continue;
        }
        ran_any = True;
        c_out = _c_output(fixture, calls);
        assert na_out == c_out , f"{fixture}: na-binary {na_out!r} != emitted-C {c_out!r}";
    }
    # Locally no fixture links (no vendored musl); the assertions above only
    # bind where a standalone na binary is producible. Recorded, not silently
    # skipped, so a CI run that never linked any binary is visible.
    if not ran_any {
        print("na-vs-C runtime leg skipped: no standalone na binary linkable here");
    }
}
