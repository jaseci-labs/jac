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
`*` import) and the import has to bind (not typed, comptime, or caught as
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

"""The diagnostic codes a check-only compile of `main_rel` reports, in a fresh
project holding `files`."""
def check_codes(files: dict[str, str], main_rel: str) -> list[str] {
    base = Path(tempfile.mkdtemp(prefix="jac_missing_name_"));
    (base / "jac.toml").write_text("[project]\nname = \"missingname\"\n");
    for (rel, text) in files.items() {
        (base / rel).parent.mkdir(parents=True, exist_ok=True);
        (base / rel).write_text(text);
    }
    prog = JacProgram();
    prog.compile(file_path=str(base / main_rel), options=CompileOptions(no_cgen=True));
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
    guarded = (
        "def load -> object {\n"
        "    try {\n"
        "        import from lib { missing_fn }\n"
        "        return missing_fn;\n"
        "    } except ImportError {\n"
        "        return None;\n"
        "    }\n"
        "}\n"
    );
    cases = [
        (
            "E1145",
            {"lib.jac": lib, "main.jac": "import from lib { present_fn, missing_fn }\n"}
        ),
        (
            "E1145",
            {"feat/lib.jac": lib, "feat/main.jac": "import from .lib { missing_fn }\n"}
        ),
        (
            "E1145",
            {"pkg/__init__.jac": lib, "main.jac": "import from pkg { missing_fn }\n"}
        ),
        (
            "E1145",
            {
                "lib.jac": "import from main { main_val }\nglob lib_val: int = 1;\n",
                "main.jac": "import from lib { lib_val, missing_fn }\nglob main_val: int = 2;\n"
            }
        ),
        (
            "W1101",
            {
                "lib.py": "globals()['missing_fn'] = 1\n",
                "main.jac": "import from lib { missing_fn }\n"
            }
        ),
        (
            "W1101",
            {
                "pkg/__init__.py": "X = 1\n",
                "main.jac": "import from pkg { missing_fn }\n"
            }
        ),
        (
            "W1101",
            {
                "lib.jac": "def __getattr__(name: str) -> int {\n    return 42;\n}\n",
                "main.jac": "import from lib { missing_fn }\n"
            }
        ),
        (
            "W1101",
            {
                "base.jac": lib,
                "lib.jac": "include base;\n",
                "main.jac": "import from lib { missing_fn }\n"
            }
        ),
        ("W1101", {"lib.jac": lib, "main.jac": guarded}),
        (
            "W1101",
            {"lib.jac": lib, "main.jac": "import type from lib { MissingType }\n"}
        ),

    ];
    for (expected, files) in cases {
        main_rel = [
            rel
            for rel in files
            if rel.endswith("main.jac")
        ][0];
        codes = check_codes(files, main_rel);
        other = "W1101" if expected == "E1145" else "E1145";
        assert expected in codes and other not in codes , (
            f"{files[main_rel]!r}: expected {expected}, got {codes}"
        );
    }
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
