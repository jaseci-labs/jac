"""Language tools tests – migrated from test_lang_tools.py.

Tests for the AstTool utility: pass template generation, DOT file
generation, AST printing, Python AST printing, py2jac mode, symbol
table output, and uninode autodoc.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.utils.lang_tools { AstTool }

glob LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "pass template" {
    tool = AstTool();
    out = tool.pass_template();
    assert "target: Expr," in out;
    assert "self, node: ast.ReturnStmt" in out;
    assert "exprs: Sequence[ExprAsItem]," in out;
    assert "path: Sequence[Name | String] | None," in out;
    assert "value: str," in out;
    assert "def exit_module(self, node: ast.Module)" in out;
    assert out.count("def exit_") > 20;
}

test "gendotfile" {
    tool = AstTool();
    jac_file = os.path.join(LANG_FIXTURES, "simple_walk.jac");
    out = tool.ir(["ast.", jac_file]);
    forbidden_strings = ["<<", ">>", "init", "super"];
    for i in forbidden_strings {
        assert i not in out , f"Forbidden string '{i}' found in DOT output";
    }
}

test "print ast" {
    tool = AstTool();
    jac_file = os.path.join(LANG_FIXTURES, "hello.jac");
    msg = "error in " + jac_file;
    out = tool.ir(["ast", jac_file]);
    assert "+-- Token" in out , msg;
    assert out is not None , msg;
}

test "print py ast" {
    tool = AstTool();
    jac_file = os.path.join(LANG_FIXTURES, "hello.jac");
    msg = "error in " + jac_file;
    out = tool.ir(["pyast", jac_file]);
    assert "Module(" in out , msg;
    assert out is not None , msg;
}

test "py jac mode" {
    tool = AstTool();
    py_file = os.path.join(LANG_FIXTURES, "pyfunc.py");
    out = tool.ir(["unparse", py_file]);
    assert "def my_print(x: object) -> None" in out;
}

test "sym sym dot" {
    tool = AstTool();
    jac_file = os.path.join(LANG_FIXTURES, "hello.jac");
    out = tool.ir(["sym", jac_file]);
    assert (
        "\n|   +-- ConnectionAbortedError\n|   |   +-- public var\n|   +-- ConnectionError\n|"
        not in out
    );
    check_list = ["######", "# hello #", "######", "SymTable::Module(hello)"];
    for i in check_list {
        assert i in out , f"Expected '{i}' in sym output";
    }
    out = tool.ir(["sym.", jac_file]);
    assert '[label="' in out;
}

test "uninode doc" {
    tool = AstTool();
    auto_uni = tool.autodoc_uninode();
    assert (
        "## LambdaExpr\n```mermaid\nflowchart LR\nLambdaExpr -->|Expr , CodeBlockStmt| body"
        in auto_uni
    );
}

test "uni dispatch annexes in sync and unduplicated" {
    import from jaclang.jac0core.gen_uni_dispatch { verify_all, abs_path, UNI_PASS_SRC }
    stale = verify_all();
    assert stale == [] , f"stale dispatch artifacts: {stale}";
    src = open(abs_path(UNI_PASS_SRC), encoding="utf-8").read();
    decls: list[str] = [];
    for line in src.splitlines() {
        s = line.strip();
        if s.startswith("def enter_") or s.startswith("def exit_") {
            decls.append(s.split("(")[0]);
        }
    }
    assert len(decls) == len(set(decls)) , "duplicate visitor declarations in uni_pass.jac";
}
