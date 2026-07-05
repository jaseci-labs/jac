"""Cross-module virtual-dispatch conformance for the jac2c Emit leg of #7145.

`xmod_main.jac` imports `Shape` from `xmod_base.jac` and subclasses it as `Sq`,
overriding only `speak`. The base `who` is compiled in xmod_base's translation
unit yet calls `self.speak()` virtually, so a `Sq(100).who()` must re-dispatch
across the module boundary back into `Sq__speak` in the importing unit. That
only works when both translation units agree on the vtable slot numbering, which
is precisely what a single whole-program shared layout registry guarantees.

`emit_translation_units` is the backend orchestrator both the CLI and this test
consume: it discovers the import graph, builds one shared layout over every
module, then re-emits each unit against that shared layout. This test does NOT
mirror that orchestration — it calls the helper and links whatever units come
back.

Differential oracle: the emitted translation units are linked with jacrt and a
generated driver, and their runtime output is compared against the stock Jac
interpreter running the same importing module. The expected output is derived
from one shared `CALLS` list on both sides, so nothing is hand-asserted.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.c.c_gen_pass { emit_translation_units }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     ),
     RUNTIME: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "passes", "c", "runtime"
     );

glob MAIN: str = "xmod_main.jac",
     BASE: str = "xmod_base.jac",
     CALLS: list[str] = ["run_base", "run_derived"];


def _cc -> (str | None) {
    return shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
}


# Compile the importing module and run the shared-layout orchestrator, returning
# the list of (path, c_src) translation units it emits.
def _emit_units -> list {
    prog = JacProgram();
    main_path = os.path.join(FIXTURES, MAIN);
    ir = prog.compile(file_path=main_path);
    assert not prog.errors_had , f"compile errors: {[str(e) for e in prog.errors_had]}";
    return emit_translation_units(main_path, ir, prog);
}


# The last stdout line whose whitespace tokens are all ints and number `want`,
# robust against interleaved dev-mode/setup banners.
def _int_line(stdout: str, want: int) -> (str | None) {
    for line in reversed(stdout.splitlines()) {
        toks = line.split();
        if len(toks) != want {
            continue;
        }
        ok = True;
        for t in toks {
            try {
                int(t);
            } except ValueError {
                ok = False;
            }
        }
        if ok {
            return line.strip();
        }
    }
    return None;
}


# Emit every translation unit through the orchestrator, write each to its own .c,
# link them all with jacrt + a generated driver that prints each call as a
# space-separated int, run it, return stdout.
def _c_output -> str {
    units = _emit_units();
    work = tempfile.mkdtemp();
    cpaths: list = [];
    i = 0;
    for (_, src) in units {
        if not src.strip() {
            continue;
        }
        p = os.path.join(work, f"tu{i}.c");
        with open(p, "w") as f {
            f.write(src);
        }
        cpaths.append(p);
        i += 1;
    }
    externs = "".join([f"extern int {c}(void);\n" for c in CALLS]);
    fmt = " ".join(["%d" for _ in CALLS]);
    argv = ", ".join([f"{c}()" for c in CALLS]);
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
        [cc, "-std=c11", "-I", RUNTIME] + cpaths + [rt, drv, "-o", binp],
        check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return proc.stdout.strip();
}


# Run the importing module (which imports the base) through the stock interpreter
# with a synthesized entry printing the same calls. Both fixtures are copied into
# the temp dir so the interpreter resolves the import.
def _cpython_output -> str {
    work = tempfile.mkdtemp();
    for fx in [MAIN, BASE] {
        src = "";
        with open(os.path.join(FIXTURES, fx)) as f {
            src = f.read();
        }
        with open(os.path.join(work, fx), "w") as f {
            f.write(src);
        }
    }
    argv = ", ".join([f"{c}()" for c in CALLS]);
    entry = "\n\nwith entry {\n    print(" + argv + ");\n}\n";
    with open(os.path.join(work, MAIN), "a") as f {
        f.write(entry);
    }
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(work, MAIN)],
        capture_output=True,
        text=True,
        check=True
    );
    line = _int_line(proc.stdout, len(CALLS));
    assert line is not None , f"no int-tuple line in interpreter stdout:\n{proc.stdout}";
    return line;
}


test "jac2c cross-module vtable slots agree across translation units" {
    units = _emit_units();
    assert len(units) == 2 , f"expected 2 translation units, got {len(units)}";
    by_name: dict = {};
    for (path, src) in units {
        by_name[os.path.basename(path)] = src;
    }
    assert BASE in by_name , f"base TU {BASE!r} not emitted: {list(by_name.keys())}";
    assert MAIN in by_name , f"main TU {MAIN!r} not emitted: {list(by_name.keys())}";
    base_c = by_name[BASE];
    main_c = by_name[MAIN];

    # The defining unit emits the base's vtable; the whole-program shared layout
    # is what marks `Shape` vtable-bearing even though no subclass lives here.
    assert "Shape__vtable[" in base_c , f"base TU missing Shape__vtable:\n{base_c}";

    # The importing unit's extern struct must carry the vtable pointer as its
    # first member so the cross-TU object layout matches the defining unit.
    assert "struct Shape {" in main_c , f"main TU missing extern struct Shape:\n{main_c}";
    vptr_at = main_c.find("void **__vtable;");
    struct_at = main_c.find("struct Shape {");
    assert vptr_at != -1 , f"main TU extern struct Shape lacks vtable pointer:\n{main_c}";

    # The base `who`, compiled in the base TU, dispatches self.speak() virtually.
    assert "jac_vtable_slot(" in base_c , f"base TU has no virtual call site:\n{base_c}";
}


test "jac2c cross-module virtual dispatch matches the stock interpreter" {
    if _cc() is None {
        return;
    }
    c_out = _c_output();
    py_out = _cpython_output();
    assert c_out == py_out , f"cross-module emitted-C {c_out!r} != interpreter {py_out!r}";
}
