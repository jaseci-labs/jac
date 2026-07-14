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
    backend twice. Structurally we assert it produces LLVM IR and is
    `native_compat`, proving the na backend accepts every construct the jac2c
    backend emits. Behaviorally we emit the na object in-process and link it
    with the same system `cc` the C leg already needs, producing a runnable
    binary whose output must equal the jac2c-emitted C. This links dynamically
    against the host libc, so it runs anywhere a `cc` is on PATH -- locally and
    in CI alike -- rather than depending on a vendored musl to statically link
    a standalone binary (the `jac nacompile` default path, which used to gate
    this leg to CI only).

Both the C output and the CPython output are derived from one `calls` list per
fixture, so nothing is hand-asserted -- the oracle is machine-computed on both
sides and the test fails if either implementation drifts.
"""

import os;
import subprocess;
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
# A plain `@main` that runs the module init array then calls `jac_entry`.
# Injected into the na LLVM IR so the host `cc`'s own crt/_start can drive it
# and resolve libc dynamically -- no static musl, no custom ELF linker.
glob SPECS: list[tuple[str, list[str]]] = [
         ("obj_rc.jac", ["run_counter", "run_box"]),
         ("obj_poly.jac", ["run_base", "run_derived"]),
         ("str_ops.jac", ["run_len", "run_eq", "run_greet_len"]),
         ("exceptions.jac", ["run_catch", "run_propagate", "run_nothrow"]),
         ("obj_move.jac", ["run_move"]),
         ("obj_alias.jac", ["run_alias", "run_transfer"]),
         ("obj_value_alias.jac", ["run_mutate_alias"]),

     ],
     _NA_MAIN_IR: str = "\n".join(
         [
             "define i32 @main(i32 %argc, ptr %argv) {",
             "entry:",
             "  store i32 %argc, ptr @__jac_argc",
             "  store ptr %argv, ptr @__jac_argv",
             "  %ia = load ptr, ptr @__jac_init_array",
             "  %ic = load i64, ptr @__jac_init_count",
             "  br label %ia.cond",
             "ia.cond:",
             "  %i = phi i64 [ 0, %entry ], [ %inext, %ia.body ]",
             "  %more = icmp ult i64 %i, %ic",
             "  br i1 %more, label %ia.body, label %ia.done",
             "ia.body:",
             "  %slot = getelementptr ptr, ptr %ia, i64 %i",
             "  %fn = load ptr, ptr %slot",
             "  call void %fn()",
             "  %inext = add i64 %i, 1",
             "  br label %ia.cond",
             "ia.done:",
             "  call void @jac_entry()",
             "  ret i32 0",
             "}",
             ""
         ]
     );


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


# Emit the na backend's LLVM IR for the fixture to an object file, link it with
# the system `cc` into a dynamically-libc-linked binary, run it, and return its
# int-tuple line. Unlike `jac nacompile` (which static-links a vendored musl and
# so only runs in CI), this reuses the C leg's already-required `cc`, so the
# na-vs-C runtime comparison runs everywhere a compiler is on PATH. Returns None
# only if the object cannot be linked here (caller records that, never silent).
def _na_binary_output(fixture: str, calls: list[str]) -> (str | None) {
    (compat, ir) = _na_codegen(fixture, calls);
    assert compat , f"{fixture}: not native_compat";

    globals_ir = ""
        if "__jac_argc" in ir
        else "@__jac_argc = global i32 0\n@__jac_argv = global ptr null\n\n";
    initarr_ir = ""
        if "__jac_init_array" in ir
        else "@__jac_init_array = global ptr null\n@__jac_init_count = global i64 0\n\n";
    ir = ir + "\n" + globals_ir + initarr_ir + _NA_MAIN_IR;

    import jaclang.compiler.passes.native.llvm.binding as llvm;
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir);
    mod.verify();
    tm = llvm.Target.from_default_triple().create_target_machine(
        opt=2, codemodel="small", reloc="pic"
    );
    obj_bytes = tm.emit_object(mod);

    work = tempfile.mkdtemp();
    obj_path = os.path.join(work, "na.o");
    with open(obj_path, "wb") as f {
        f.write(obj_bytes);
    }
    binp = os.path.join(work, "na_bin");
    build = subprocess.run(
        [cc(), obj_path, "-o", binp, "-lm"], capture_output=True, text=True
    );
    if build.returncode != 0 or not os.path.exists(binp) {
        return None;
    }
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return int_tuple_line(proc.stdout, len(calls));
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


test "na native binary and emitted C agree at run time" {
    if cc() is None {
        return;
    }
    ran_any = False;
    for (fixture, calls) in SPECS {
        na_out = _na_binary_output(fixture, calls);
        assert na_out is not None , f"{fixture}: na object failed to link with cc";
        ran_any = True;
        c_out = link_and_run(emit_units(fixture), calls);
        assert na_out == c_out , f"{fixture}: na-binary {na_out!r} != emitted-C {c_out!r}";
    }
    # With a `cc` on PATH every fixture links here, so the two compiled backends
    # are always compared -- no CI-only gating. Recorded so a run that somehow
    # linked nothing is visible rather than a silent green.
    assert ran_any , "na-vs-C runtime leg ran no fixtures despite cc present";
}
