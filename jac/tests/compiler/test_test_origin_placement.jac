"""Test code must not constrain its module's placement.

A `*.test.jac` annex is merged into the module it tests, so a test that
touches a native blocker -- `root`, an async ability, an endpoint -- used to
push the module under test off the native lane, or, when the module did seal
native, left the test calling into a demoted function's abort() stub. Tests
run in the server codespace either way, so nodes originating in a
`*.test.jac` file -- or inside an inline `test` block -- are excluded from
the native blocker scan.
"""

import os;
import shutil;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.placement { scan_native_blockers }

glob CALC: str = "def add(a: int, b: int) -> int { return a + b; }\n"
         + "with entry { print(add(1, 2)); }\n",
     ROOT_TEST: str = "test \"reaches the graph\" {\n"
         + "    assert root is not None;\n"
         + "}\n",
     ASYNC_TEST: str = "async def probe() -> int { return 1; }\n"
         + "test \"async helper\" {\n"
         + "    assert True;\n"
         + "}\n";

def _proj(annex: str) -> str {
    d = tempfile.mkdtemp(prefix="jactestorigin_");
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"t\"\nentry-point = \"main\"\n");
    }
    with open(os.path.join(d, "main.jac"), "w") as f {
        f.write("with entry {}\n");
    }
    with open(os.path.join(d, "calc.jac"), "w") as f {
        f.write(CALC);
    }
    if annex {
        with open(os.path.join(d, "calc.test.jac"), "w") as f {
            f.write(annex);
        }
    }
    return d;
}

def _compile(annex: str) -> tuple[JacProgram, uni.Module, str] {
    d = _proj(annex);
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(d, "calc.jac"), options=CompileOptions(no_ir_cache=True)
    );
    return (prog, mod, d);
}


test "a module with no test annex keeps its native preference" {
    (prog, mod, d) = _compile("");
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , blocker;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a test annex touching root does not push its module off native" {
    (prog, mod, d) = _compile(ROOT_TEST);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , (f"test-origin code entered the blocker scan: {blocker}");
        assert mod.decided_codespace == "native" , (
            f"a test annex demoted the module under test: " f"{mod.decided_codespace}"
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "an async ability written in a test annex is not a module blocker" {
    (prog, mod, d) = _compile(ASYNC_TEST);
    try {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , blocker;
        assert mod.decided_codespace == "native" , mod.decided_codespace;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "an inline test block touching root does not push its module off native" {
    d = _proj("");
    try {
        with open(os.path.join(d, "calc.jac"), "a") as f {
            f.write(ROOT_TEST);
        }
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(d, "calc.jac"), options=CompileOptions(no_ir_cache=True)
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        (blocker, _deps) = scan_native_blockers(mod, d);
        assert not blocker , f"inline test code entered the blocker scan: {blocker}";
        assert mod.decided_codespace == "native" , mod.decided_codespace;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
