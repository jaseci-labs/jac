"""Multi-module emit conformance for the jac2c Emit leg of #7145.

`mod_main.jac` imports a ref-type `Counter` and a free function `add` from
`mod_lib.jac` and uses them across the module boundary. jac2c must emit each
module as its own C translation unit: the importing unit forward-declares the
imported struct and `extern`s its constructor, methods, and the free function,
then resolves every cross-module `Counter(...)` / `c.bump()` / `c.get()` /
`add(...)` to the same mangled `Counter__new` / `Counter__bump` / `Counter__get`
/ `add` symbols the defining unit emits.

Differential oracle: the two emitted translation units are linked with jacrt and
a generated driver, and their runtime output is compared against the stock Jac
interpreter running the same importing module (which resolves the import
natively). The expected output is derived from one shared `CALLS` list on both
sides, so nothing is hand-asserted.
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

glob MAIN: str = "mod_main.jac",
     LIB: str = "mod_lib.jac",
     CALLS: list[str] = ["run_cross", "run_get"];


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


# Emit BOTH translation units, link them with jacrt + a generated driver that
# prints each call as a space-separated int, run it, return stdout.
def _c_output -> str {
    main_c = _emit_c(os.path.join(FIXTURES, MAIN));
    lib_c = _emit_c(os.path.join(FIXTURES, LIB));
    work = tempfile.mkdtemp();
    mainp = os.path.join(work, "main.c");
    libp = os.path.join(work, "lib.c");
    with open(mainp, "w") as f {
        f.write(main_c);
    }
    with open(libp, "w") as f {
        f.write(lib_c);
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
        [cc, "-std=c11", "-I", RUNTIME, mainp, libp, rt, drv, "-o", binp], check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    return proc.stdout.strip();
}


# Run the importing module (which imports the lib) through the stock interpreter
# with a synthesized entry printing the same calls. Both fixtures are copied into
# the temp dir so the interpreter resolves the import.
def _cpython_output -> str {
    work = tempfile.mkdtemp();
    for fx in [MAIN, LIB] {
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


test "jac2c cross-module emission resolves imported types and functions" {
    main_c = _emit_c(os.path.join(FIXTURES, MAIN));
    # The importing TU forward-declares the imported struct and externs its
    # constructor, methods, and the free function, then calls the mangled
    # cross-module symbols rather than emitting raw Jac names.
    for needle in [
        "struct Counter {",
        "extern struct Counter *Counter__new(int start);",
        "extern int Counter__bump(struct Counter *self);",
        "extern int add(int x, int y);",
        "Counter__new(10)",
        "Counter__bump(",
        "add("
    ] {
        assert needle in main_c , f"missing {needle!r} in:\n{main_c}";
    }
    assert "unsupported" not in main_c , f"unsupported nodes remain:\n{main_c}";
}


test "jac2c multi-module linked binary matches the stock interpreter" {
    if _cc() is None {
        return;
    }
    c_out = _c_output();
    py_out = _cpython_output();
    assert c_out == py_out , f"multi-module emitted-C {c_out!r} != interpreter {py_out!r}";
}
