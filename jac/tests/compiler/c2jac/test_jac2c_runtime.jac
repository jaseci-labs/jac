"""Runtime-ABI conformance for the Emit leg (jac2c) of #7145.

Proves the C-codegen backend for reference-semantic Jac objects: heap objects
behind the jacrt RC header, `init` constructors, instance methods, member
access through the object pointer, and conservative retain/release. The emitted
C is compiled together with the canonical `jacrt.c` runtime by the system C
compiler and its behavior asserted. When no C compiler is present the structural
half still runs so the test stays meaningful in minimal environments.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     ),
     RUNTIME: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "passes", "c", "runtime"
     );

def _emit_c(jac_path: str) -> str {
    prog = JacProgram();
    mod = prog.compile(file_path=jac_path);
    assert not prog.errors_had , f"compile errors: {[str(e) for e in prog.errors_had]}";
    return mod.gen.c_src;
}

def _cc -> (str | None) {
    return shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
}

test "jac2c emits RC objects, constructors, methods, and balanced retain/release" {
    c_src = _emit_c(os.path.join(FIXTURES, "obj_rc.jac"));
    for needle in [
        "#include \"jacrt.h\"",
        "struct Counter *Counter__new(int start)",
        "jac_rc_alloc(sizeof(struct Counter)",
        "int Counter__bump(struct Counter *self)",
        "self->n = (self->n + 1)",
        "return Counter__get(self->c)",
        "jac_rc_retain(",
        "jac_rc_release(self->c)",
        "jac_rc_release(c)"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c reference objects compile with cc and behave correctly" {
    cc = _cc();
    if cc is None {
        return;
    }
    c_src = _emit_c(os.path.join(FIXTURES, "obj_rc.jac"));
    work = tempfile.mkdtemp();
    lib = os.path.join(work, "obj_rc.c");
    with open(lib, "w") as f {
        f.write(c_src);
    }
    drv = os.path.join(work, "driver.c");
    with open(drv, "w") as f {
        f.write(
            "#include <stdio.h>\n"
            "extern int run_counter(void);\n"
            "extern int run_box(void);\n"
            "int main(void) {\n"
            "    printf(\"%d %d\\n\", run_counter(), run_box());\n"
            "    return 0;\n"
            "}\n"
        );
    }
    binp = os.path.join(work, "bin");
    rt = os.path.join(RUNTIME, "jacrt.c");
    subprocess.run(
        [cc, "-std=c11", "-I", RUNTIME, lib, rt, drv, "-o", binp], check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    # run_counter: 11 + 12 == 23. run_box: peek of Counter(41) == 41.
    assert proc.stdout.strip() == "23 41" , f"got {proc.stdout.strip()!r}";
}

def _build_run(fixture: str, externs: str, call: str) -> str {
    cc = _cc();
    if cc is None {
        return "";
    }
    c_src = _emit_c(os.path.join(FIXTURES, fixture));
    work = tempfile.mkdtemp();
    lib = os.path.join(work, "lib.c");
    with open(lib, "w") as f {
        f.write(c_src);
    }
    drv = os.path.join(work, "driver.c");
    with open(drv, "w") as f {
        f.write(
            "#include <stdio.h>\n" + externs + "int main(void) {\n    printf(" + call + ");\n    return 0;\n}\n"
        );
    }
    binp = os.path.join(work, "bin");
    rt = os.path.join(RUNTIME, "jacrt.c");
    subprocess.run(
        [cc, "-std=c11", "-I", RUNTIME, lib, rt, drv, "-o", binp], check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return proc.stdout.strip();
}

test "jac2c emits per-class vtables and virtual dispatch for inheritance" {
    c_src = _emit_c(os.path.join(FIXTURES, "obj_poly.jac"));
    for needle in [
        "void **__vtable;",
        "static void *Animal__vtable[]",
        "static void *Dog__vtable[]",
        "(void *)Dog__speak",
        "(void *)Animal__who",
        "jac_vtable_slot(self->__vtable,",
        "self->__vtable = Dog__vtable;"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c inheritance dispatches to the most-derived override at run time" {
    if _cc() is None {
        return;
    }
    out = _build_run(
        "obj_poly.jac",
        "extern int run_base(void);\nextern int run_derived(void);\n",
        "\"%d %d\\n\", run_base(), run_derived()"
    );
    # run_base: Animal.speak()==1 + name 10 == 11.
    # run_derived: Dog.speak()==2 (virtual) + name 100 == 102.
    assert out == "11 102" , f"got {out!r}";
}

test "jac2c lowers string concat, equality, and length to the runtime" {
    c_src = _emit_c(os.path.join(FIXTURES, "str_ops.jac"));
    for needle in ["jac_str_concat(\"ab\", \"cd\")", "jac_str_len(", "jac_str_eq("] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c runtime strings compile with cc and behave correctly" {
    if _cc() is None {
        return;
    }
    out = _build_run(
        "str_ops.jac",
        "extern int run_len(void);\nextern int run_eq(void);\n"
        "extern int run_greet_len(void);\n",
        "\"%d %d %d\\n\", run_len(), run_eq(), run_greet_len()"
    );
    # len("abcd")==4; "foo"=="foo" -> 1; len("Hi Bob")==6.
    assert out == "4 1 6" , f"got {out!r}";
}

test "jac2c lowers try/except/raise to the setjmp runtime" {
    c_src = _emit_c(os.path.join(FIXTURES, "exceptions.jac"));
    for needle in [
        "jac_exc_frame ",
        "setjmp(",
        "jac_exc_push(",
        "jac_exc_throw(",
        "jac_exc_current_type()",
        "jac_exc_clear();"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c exceptions catch, propagate, and pass through with cc" {
    if _cc() is None {
        return;
    }
    out = _build_run(
        "exceptions.jac",
        "extern int run_catch(void);\nextern int run_propagate(void);\n"
        "extern int run_nothrow(void);\n",
        "\"%d %d %d\\n\", run_catch(), run_propagate(), run_nothrow()"
    );
    # catch: classify(-5)==2, classify(5)==1 -> 21.
    # propagate: raise in inner caught by outer -> 99. nothrow: outer(7) -> 7.
    assert out == "21 99 7" , f"got {out!r}";
}
