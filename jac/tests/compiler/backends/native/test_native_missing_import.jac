"""Importing a name a Jac module does not define is an error, not a null.

`bindings/select.jac` imported `poll_methods` from its clinic module after
the clinic module stopped defining it. The checker only warned (`W1101`),
and native lowering bound every use of the missing global to nothing: the
`TypeDefinition("select.poll", "", poll_methods, ...)` glob initializer got a
literal NULL, and the interpreter crashed at load.

Native lowering refuses the binding itself: a name the bound Jac module's
symbol table does not hold is `E1145`, naming the module and the name, and the
build stops. The checker reports the same `E1145` once the source is a parsed
`.jac` module whose names are closed (no module `__getattr__`, no `include` or
`*` import, no `globals()`/`vars()`/`exec()` call, no platform variant, not part
of the toolchain) and the import has to bind (not typed, comptime, or caught as
`ImportError`), since the Python runtime then fails the import at load. A
Python source, an open namespace, or a guarded import keeps `W1101` (#10740).
"""

import subprocess;
import from pathlib { Path }
import tempfile;
import from tests.support { jac_command }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

"""The diagnostic codes a check-only compile of `path` reports."""
def check_codes(path: Path) -> list[str] {
    prog = JacProgram();
    prog.compile(file_path=str(path), options=CompileOptions(no_cgen=True));
    codes: list[str] = [];
    for alert in list(prog.errors_had) + list(prog.warnings_had) {
        if alert.code is not None {
            codes.append(alert.code.code);
        }
    }
    return codes;
}

test "the checker makes a name a Jac module does not define E1145 and keeps W1101 where it cannot be sure" {
    lib = "def present_fn(x: int) -> int {\n    return x + 1;\n}\n";
    guarded = "def load {\n    try {\n        import from lib { missing_fn }\n    } except EXC { }\n}\n";
    cases = [
        ("package __init__.jac", "E1145", {"lib/__init__.jac": lib}),
        ("python module", "W1101", {"lib.py": "globals()['missing_fn'] = 1\n"}),
        (
            "module __getattr__",
            "W1101",
            {"lib.jac": "def __getattr__(name: str) -> int {\n    return 42;\n}\n"}
        ),
        ("include", "W1101", {"base.jac": lib, "lib.jac": "include base;\n"}),
        (
            "platform variant",
            "W1101",
            {"lib.jac": lib, "lib.linux.jac": lib, "lib.darwin.jac": lib}
        ),
        (
            "globals() write",
            "W1101",
            {"lib.jac": "with entry {\n    globals()['missing_fn'] = 1;\n}\n"}
        ),
        (
            "try/except ImportError",
            "W1101",
            {"lib.jac": lib, "main.jac": guarded.replace("EXC", "ImportError")}
        ),
        (
            "try/except ModuleNotFoundError",
            "E1145",
            {"lib.jac": lib, "main.jac": guarded.replace("EXC", "ModuleNotFoundError")}
        ),
        (
            "import type",
            "W1101",
            {"lib.jac": lib, "main.jac": "import type from lib { MissingType }\n"}
        ),
        (
            "comptime import",
            "W1101",
            {"lib.jac": lib, "main.jac": "comptime import from lib { missing_fn }\n"}
        ),

    ];
    failures: list[str] = [];
    with tempfile.TemporaryDirectory() as tmp {
        checks = [("absolute module", "E1145", FIXTURES / "missing_import_main.jac")];
        for (idx, (label, expected, files)) in enumerate(cases) {
            base = Path(tmp) / str(idx);
            for (rel, text) in (
                {
                    "jac.toml": "[project]\nname = \"missingname\"\n",
                    "main.jac": "import from lib { missing_fn }\n"
                }
                | files
            ).items() {
                (base / rel).parent.mkdir(parents=True, exist_ok=True);
                (base / rel).write_text(text);
            }
            checks.append((label, expected, base / "main.jac"));
        }
        for (run, rows) in [("cold", checks), ("warm", checks[:2])] {
            for (label, expected, path) in rows {
                codes = check_codes(path);
                other = "W1101" if expected == "E1145" else "E1145";
                if expected not in codes or other in codes {
                    failures.append(
                        f"{label} ({run}): expected {expected}, got {codes}"
                    );
                }
            }
        }
    }
    assert not failures , failures;
}

test "a native build importing a missing name fails with the name and module" {
    out_bin = str(Path(tempfile.mkdtemp()) / "missing_import");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            str(FIXTURES / "missing_import_main.jac"),
            "-o",
            out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    text = comp.stdout + comp.stderr;
    assert comp.returncode != 0 , text[-1500:];
    assert "E1145" in text , text[-1500:];
    assert "missing_table" in text and "missing_import_lib" in text , text[-1500:];
    assert not Path(out_bin).exists() , "no binary may be written";
}
