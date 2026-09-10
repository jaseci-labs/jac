"""Type checking is on the critical path of every compilation (#8398).

The compiler used to accept `type_check` as an option, defaulted it off at the
entry points the runtime actually used, and assembled its schedule from
option-shaped fragments. A plain server module therefore reached code
generation with no inference and none of the checker passes, so a type error
became a runtime crash instead of a compile failure.

These tests pin the three properties that replace that arrangement: the option
is gone, the analysis stage runs without being asked, and a module-scoped error
stops code generation for every codespace rather than only for native modules.
"""

import os;
import shutil;
import tempfile;

import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob _BAD_SRC: str = "def widen(a: int, b: int) -> int {\n    return a * b;\n}\n\nwith entry {\n    total: int = widen(\"alpha\", \"beta\");\n}\n",
     _GOOD_SRC: str = "def widen(a: int, b: int) -> int {\n    return a * b;\n}\n\nwith entry {\n    total: int = widen(6, 7);\n}\n";


def _compile_src(src: str) -> tuple[any, list] {
    proj = tempfile.mkdtemp(prefix="tc_path_");
    try {
        target = os.path.join(proj, "main.jac");
        Path(target).write_text(src);
        prog = JacProgram();
        mod = prog.compile(target);
        codes = [
            e.code.code
            for e in prog.errors_had
            if e.code is not None
        ];
        return (mod, codes);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}


test "the type_check option no longer exists" {
    opts = CompileOptions();
    assert not hasattr(opts, "type_check") , "CompileOptions still carries a type_check switch";
    assert not hasattr(opts, "emit_diagnostics") , "CompileOptions still carries an emit_diagnostics switch";
}


test "a plain module is type-checked without being asked" {
    (_mod, codes) = _compile_src(_BAD_SRC);
    assert codes , "compiling a module with a type error produced no diagnostics";
}


test "a type error blocks code generation for a server module" {
    (mod, codes) = _compile_src(_BAD_SRC);
    assert codes , "expected diagnostics for the bad module";
    assert not mod.gen.py_bytecode , "a type error still produced bytecode";
}


test "a clean module still reaches code generation" {
    (mod, codes) = _compile_src(_GOOD_SRC);
    assert not codes , f"clean source reported diagnostics: {codes}";
    assert mod.gen.py_bytecode , "a clean module produced no bytecode";
}


test "type inference is a hard requirement of the environment" {
    import from jaclang.compiler.driver.pipeline {
        TypeshedUnavailableError,
        require_typeshed_stubs,
        typeshed_stubs_available
    }

    assert typeshed_stubs_available() , "vendored typeshed stubs are missing, so no module can compile";
    require_typeshed_stubs();
    assert issubclass(TypeshedUnavailableError, RuntimeError);
}


test "a type error blocks a natively lowered module too" {
    src = "obj Point {\n"
        + "    has x: int, y: int;\n"
        + "}\n"
        + "with entry {\n"
        + "    p = Point(x=3, y=4);\n"
        + "    bad: int = \"not an int\";\n"
        + "    total: int = p.x + p.y;\n"
        + "}\n";
    (mod, codes) = _compile_src(src);
    assert codes , "a natively lowered module swallowed its type error";
    assert not mod.gen.py_bytecode , "a type error still produced bytecode";
}
