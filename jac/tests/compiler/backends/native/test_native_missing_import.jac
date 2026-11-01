"""Importing a name a Jac module does not define is an error, not a null.

`bindings/select.jac` imported `poll_methods` from its clinic module after
the clinic module stopped defining it. The checker only warned (`W1101`),
and native lowering bound every use of the missing global to nothing: the
`TypeDefinition("select.poll", "", poll_methods, ...)` glob initializer got a
literal NULL, and the interpreter crashed at load.

The checker now refuses the binding on every backend: a name the source
Jac module does not define is `E1145`, naming the module and the name, and
the build stops. A module that defines a module-level `__getattr__` provides
every name, typed by that hook's return type.
"""

import subprocess;
import from pathlib { Path }
import tempfile;
import from tests.support { jac_command }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

"""The diagnostic codes a check-only compile of `fixture` reports."""
def check_codes(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(FIXTURES / fixture), options=CompileOptions(no_cgen=True)
    );
    codes: list[str] = [];
    for alert in list(prog.errors_had) + list(prog.warnings_had) {
        if alert.code is not None {
            codes.append(alert.code.code);
        }
    }
    return codes;
}

test "the checker reports a missing imported name as an error" {
    codes = check_codes("missing_import_main.jac");
    assert "E1145" in codes , codes;
    assert "W1101" not in codes , codes;
}

test "a module __getattr__ provides any name, typed by its return" {
    codes = check_codes("lazy_import_main.jac");
    assert "E1145" not in codes and "W1101" not in codes , codes;
    assert codes.count("E1001") == 1 , codes;
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
