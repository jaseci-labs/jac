"""Unused-variable (W2003) diagnostics: write-position rebinds still warn.

Issue #8535: a variable assigned in both branches of an if/else and never
read escapes W2003 because the symbol table records assignment targets as
uses, while the semantically equivalent ternary warns. These tests pin the
observable contract across syntax variants that must agree:

- Dead stores (re-assignment without any read), however spelled -- if/else
  dual assignment, sequential reassignment, ternary -- all emit exactly one
  W2003 for the dead name.
- Any genuine LOAD of the value (return, expression use) silences the
  warning; augmented assignment implies a read and also silences it.
- Single-branch if and while-loop assignment forms keep warning.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def unused_warnings(src: str, name: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="unused_var_src.jac",
        use_str=src,
        options=CompileOptions(no_cgen=True)
    );
    marker = "'" + name + "' is defined but never used";
    return [
        str(w)
        for w in prog.warnings_had
        if marker in str(w)
    ];
}

def error_count(src: str) -> int {
    prog = JacProgram();
    prog.compile(
        file_path="unused_var_src.jac",
        use_str=src,
        options=CompileOptions(no_cgen=True)
    );
    return len(prog.errors_had);
}

test "if else dual assignment without read emits unused warning" {
    src = "def probe -> int {\n"
    "    c = True;\n"
    "    if c {\n"
    "        x = 1;\n"
    "    } else {\n"
    "        x = 2;\n"
    "    }\n"
    "    return 0;\n"
    "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "x");
    assert len(warns) == 1 , warns;
}

test "ternary equivalent still emits unused warning" {
    src = "def probe -> int {\n"
    "    c = True;\n"
    "    x = 1 if c else 2;\n"
    "    return 0;\n"
    "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "x");
    assert len(warns) == 1 , warns;
}

test "if else dual assignment followed by read emits no warning" {
    src = "def probe -> int {\n"
    "    c = True;\n"
    "    if c {\n"
    "        x = 1;\n"
    "    } else {\n"
    "        x = 2;\n"
    "    }\n"
    "    return x;\n"
    "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "x");
    assert warns == [] , warns;
}

test "sequential reassignment without read emits unused warning" {
    src = "def probe -> int {\n" "    x = 1;\n" "    x = 2;\n" "    return 0;\n" "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "x");
    assert len(warns) == 1 , warns;
}

test "while loop single assignment without read emits unused warning" {
    src = "def probe -> int {\n"
    "    i = 0;\n"
    "    while i < 3 {\n"
    "        acc = 9;\n"
    "        i += 1;\n"
    "    }\n"
    "    return i;\n"
    "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "acc");
    assert len(warns) == 1 , warns;
}

test "augmented assignment as only later touch emits no warning" {
    src = "def probe -> int {\n" "    x = 1;\n" "    x += 2;\n" "    return 0;\n" "}\n";
    assert error_count(src) == 0 , src;
    warns = unused_warnings(src, "x");
    assert warns == [] , warns;
}
