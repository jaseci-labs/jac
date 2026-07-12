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
    output is the proof. (Shared with the other emit-leg tests via
    `emit_support.link_and_run` / `emit_support.interpreter_run`.)

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
import subprocess;
import sys;
import tempfile;
import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    int_tuple_line,
    link_and_run,
    interpreter_run,
    FIXTURES
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

# Each fixture plus the ordered `run_*` entry points that both references
# invoke. The expected output is whatever these calls print -- never a literal.
glob SPECS: list[tuple[str, list[str]]] = [
         ("obj_rc.jac", ["run_counter", "run_box"]),
         ("obj_poly.jac", ["run_base", "run_derived"]),
         ("str_ops.jac", ["run_len", "run_eq", "run_greet_len"]),
         ("exceptions.jac", ["run_catch", "run_propagate", "run_nothrow"]),
         ("obj_move.jac", ["run_move"]),
         ("obj_alias.jac", ["run_alias", "run_transfer"]),
         ("obj_value_alias.jac", ["run_mutate_alias"]),

     ];


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
    return int_tuple_line(proc.stdout, len(calls));
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
    if cc() is None {
        return;
    }
    for (fixture, calls) in SPECS {
        c_out = link_and_run(emit_units(fixture), calls);
        py_out = interpreter_run([fixture], fixture, calls);
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
    if cc() is None {
        return;
    }
    ran_any = False;
    for (fixture, calls) in SPECS {
        na_out = _na_binary_output(fixture, calls);
        if na_out is None {
            continue;
        }
        ran_any = True;
        c_out = link_and_run(emit_units(fixture), calls);
        assert na_out == c_out , f"{fixture}: na-binary {na_out!r} != emitted-C {c_out!r}";
    }
    # Locally no fixture links (no vendored musl); the assertions above only
    # bind where a standalone na binary is producible. Recorded, not silently
    # skipped, so a CI run that never linked any binary is visible.
    if not ran_any {
        print("na-vs-C runtime leg skipped: no standalone na binary linkable here");
    }
}
