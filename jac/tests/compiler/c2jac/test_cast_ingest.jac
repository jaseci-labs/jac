"""C as a first-class compiler input (phase1 #7145).

`test_cast_slice`/`test_cast_breadth` drive the lifter through the `cfront.lift`
helper API. These tests instead prove the deeper wiring: a `.c`/`.h`/`.i` path
handed straight to `JacProgram.compile` is dispatched to `CastBuildPass` by
`JacCompiler.parse_str` (mirroring the `.py` -> `PyastBuildPass` branch), not
fed to the Jac reader. That makes C a first-class source language rather than a
CLI-only sidecar transpile.
"""

import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

def _compile_src(basename: str, src: str) -> tuple {
    # Write `src` to a temp file named `basename` and compile it. Returns
    # (prog, module) so tests can inspect errors and the lifted output.
    out_dir = tempfile.mkdtemp();
    path = os.path.join(out_dir, basename);
    with open(path, "w") as f {
        f.write(src);
    }
    prog = JacProgram();
    mod = prog.compile(file_path=path);
    return (prog, mod);
}

test "a .c file compiles through the front-end as C (parse_str dispatch)" {
    (prog, mod) = _compile_src("add.c", "int add(int a, int b) { return a + b; }\n");
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    out = mod.unparse();
    # lifted to a Jac ability, not parsed as (invalid) Jac source
    assert "def add(a: int, b: int) -> int" in out , out;
}

test "a .c file is preprocessed on the way in (system include resolves)" {
    src = "#include <stddef.h>\nint two(void) { return 2; }\n";
    (prog, mod) = _compile_src("inc.c", src);
    # <stddef.h> resolves through the vendored fake-libc include path; without
    # preprocessing pycparser would choke on the directive.
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    assert "def two() -> int" in mod.unparse();
}

test "a .i file is taken as already-preprocessed C" {
    (prog, mod) = _compile_src("mul.i", "int mul(int a, int b) { return a * b; }\n");
    assert not prog.errors_had , f"errors: {[str(e) for e in prog.errors_had]}";
    assert "def mul(a: int, b: int) -> int" in mod.unparse();
}

test "an unfaithful C construct lifts leniently (warning, still a usable module)" {
    # A variadic function has no faithful lowering; ingestion is lenient, so it
    # lifts to a usable module and records a warning rather than hard-failing.
    src = "int sum(int n, ...) { return n; }\n";
    (prog, mod) = _compile_src("vararg.c", src);
    assert not prog.errors_had , f"lenient ingest should not error: {[
        str(e) for e in prog.errors_had
    ]}";
    assert "def sum(" in mod.unparse();
    assert any([w.code and w.code.code == "W4207" for w in prog.warnings_had]) , f"expected a W4207 variadic warning, got {[
        str(w) for w in prog.warnings_had
    ]}";
}
