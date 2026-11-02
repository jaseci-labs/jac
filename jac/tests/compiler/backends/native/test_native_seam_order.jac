"""Seam demotion reaches callers lowered before their callee demotes.

A function lowers against the demotions it has already seen. When a caller is
lowered first and its callee demotes later in the same unit, the caller holds
a direct call to the callee's abort stub; at run time the process died with
SIGABRT and no diagnostic. The pass now demotes every such caller (and test)
to a fixpoint once the unit's bodies are lowered.
"""

import os;
import subprocess;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.constant { CodeContext }
import jaclang.compiler.frontend.unitree as uni;
import from tests.support { TESTS_DIR, jac_command, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile `code` into the native codespace; return (program, module)."""
def compile_na(label: str, code: str) -> tuple[any, ...] {
    path = os.path.join(FIXTURES, f"_seam_order_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return (prog, ir, );
}

glob SEAM_SRC = (
         "def seam(n: int) -> int {\n"
         "    def same(x: int) -> int { return x; }\n"
         "    f: any = same;\n"
         "    return f(n);\n"
         "}\n"
     );

test "a caller lowered before its callee demotes becomes a seam too" {
    (prog, ir) = compile_na(
        "caller_first",
        "def early(n: int) -> int {\n"
        "    return seam(n) + 100;\n"
        "}\n"
        "\n"
        "def add(a: int, b: int) -> int {\n"
        "    return a + b;\n"
        "}\n"
        "\n"
            + SEAM_SRC
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    functions = ir.gen.native_layout.functions;
    assert "seam" not in functions , "the un-lowerable callee demotes";
    assert "early" not in functions , (
        "a caller lowered before its callee demoted must demote too, never keep "
        "a direct call into the callee's abort stub"
    );
    assert "add" in functions , "an unrelated neighbour still lowers";
}

test "demotion reaches earlier callers transitively" {
    (prog, ir) = compile_na(
        "transitive",
        "def first(n: int) -> int {\n"
        "    return second(n) * 2;\n"
        "}\n"
        "\n"
        "def second(n: int) -> int {\n"
        "    return seam(n) + 1;\n"
        "}\n"
        "\n"
            + SEAM_SRC
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    functions = ir.gen.native_layout.functions;
    assert "second" not in functions and "first" not in functions , sorted(functions);
}

test "a lambda reaching a later-demoted callee demotes its owner" {
    (prog, ir) = compile_na(
        "via_lambda",
        "def early(n: int) -> int {\n"
        "    f = lambda (x: int) -> int { return seam(x); };\n"
        "    return f(n);\n"
        "}\n"
        "\n"
            + SEAM_SRC
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert "early" not in ir.gen.native_layout.functions;
}

test "a test that reaches a later-demoted function runs in the server codespace" {
    (prog, ir) = compile_na(
        "test_first",
        "test \"reaches seam\" {\n"
        "    assert seam(7) == 7;\n"
        "}\n"
        "\n"
        "test \"stays native\" {\n"
        "    assert 2 + 3 == 5;\n"
        "}\n"
        "\n"
            + SEAM_SRC
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    contexts = {
        str(t.description.lit_value): t.code_context
        for t in ir.get_all_sub_nodes(uni.Test)
    };
    assert contexts["reaches seam"] == CodeContext.SERVER , contexts;
    assert contexts["stays native"] == CodeContext.NATIVE , contexts;
}

test "jac test runs annex tests that reach a demoted function" {
    tmp = tempfile.mkdtemp(prefix="jac_seam_order_");
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(
            '[project]\nname = "seam_order"\n\n[placement.pins]\n"calc" = "native"\n'
        );
    }
    with open(os.path.join(tmp, "calc.jac"), "w") as f {
        f.write(
            "def add(a: int, b: int) -> int {\n"
            "    return a + b;\n"
            "}\n"
            "\n"
            "def via_seam(n: int) -> int {\n"
            "    return seam(n) + 1;\n"
            "}\n"
            "\n"
                + SEAM_SRC
        );
    }
    with open(os.path.join(tmp, "calc.test.jac"), "w") as f {
        f.write(
            "test \"direct\" {\n"
            "    assert seam(7) == 7;\n"
            "}\n"
            "\n"
            "test \"transitive\" {\n"
            "    assert via_seam(7) == 8;\n"
            "}\n"
            "\n"
            "test \"native\" {\n"
            "    assert add(2, 3) == 5;\n"
            "}\n"
        );
    }
    proc = subprocess.run(
        jac_command("test", "calc.jac"),
        cwd=tmp,
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , (
        f"exit {proc.returncode} (134 is the abort stub)\n{proc.stdout}\n{proc.stderr}"
    );
    assert "3 passed" in proc.stdout , proc.stdout;
}
