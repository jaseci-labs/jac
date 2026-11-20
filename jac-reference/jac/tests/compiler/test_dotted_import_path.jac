"""`import a.b` binds `a`, and `a.b.C` resolves through it.

Python's AST gives `import a.b` as a single alias whose name is the dotted
string "a.b". Wrapping that string in one Name produced a module path with a
single segment literally spelled "a.b" -- a name no expression can reference --
so `a` was never bound and every `a.b.C` in that module went unresolved.

Base classes suffered worst: typeshed writes `class TextTestResult(
unittest.result.TestResult, ...)`, so the base resolved to nothing and every
inherited member vanished. E1030 then asserted a definite negative --
"has no attribute" -- for members that plainly exist.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="dotted.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "members inherited through a dotted base class stay visible" {
    src = "import unittest;\n"
        + "def probe(r: unittest.TextTestResult) -> bool {\n"
        + "    return r.wasSuccessful();\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"dotted base class lost its members: {errs}";
}

test "a dotted submodule reference resolves inside a loaded module" {
    src = "import unittest;\n"
        + "def probe(r: unittest.TextTestResult) -> int {\n"
        + "    return len(r.failures);\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"dotted submodule reference unresolved: {errs}";
}
