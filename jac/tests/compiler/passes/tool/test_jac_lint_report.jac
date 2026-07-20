"""Jac lint *report* path tests.

The report path (`jac lint`, `JacProgram.jac_file_linter`) must run the
report-only lint pass (`JacLintCheckPass`, report_only=True) and never the
mutation pass (`JacAutoLintPass`). Going report-only skips the AST-rewriting
hooks and is much cheaper, but it must still surface every warning the full
mutation pass would — otherwise `jac lint` would silently under-report.
"""
import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { JacCompiler, get_lint_sched }
import from jaclang.compiler.passes.tool.jac_auto_lint_pass {
    JacAutoLintPass,
    JacLintCheckPass
}

def _warn_keys(prog: JacProgram) -> list[str] {
    keys: list[str] = [];
    for w in (prog.warnings_had or []) {
        keys.append(str(w));
    }
    return sorted(keys);
}

def _full_pass_warnings(source: str, path: str) -> list[str] {
    (p, m) = JacCompiler._prepare_tool_program(source, path);
    if m is None {
        return [];
    }
    JacAutoLintPass(ir_in=m, prog=p).ir_out;
    return _warn_keys(p);
}

def _write_tmp(src: str) -> str {
    (fd, path) = tempfile.mkstemp(suffix=".jac");
    os.close(fd);
    with open(path, "w") as f {
        f.write(src);
    }
    return path;
}

test "lint report scheduler uses JacLintCheckPass" {
    sched = get_lint_sched();
    assert len(sched) == 1;
    assert sched[0] is JacLintCheckPass;
}

test "lint report path preserves every warning the mutation pass emits" {
    sources = [
        # W3020 unnecessary pass in non-empty body
        "obj Foo {\n    has x: int = 5;\n    pass;\n}\n",
        # W3021 unnecessary else after return
        "def bad(x: int) -> int {\n    if x > 0 {\n        return x;\n    } else {\n        return -x;\n    }\n}\n",
        # W3036 mutable default argument
        "def bad_list(items: list = []) -> list {\n    items.append(1);\n    return items;\n}\n",
        # W3035 `is` with literal
        "with entry {\n    x = 5;\n    if x is 5 {\n        print(\"five\");\n    }\n}\n",
        # W3024 repeated condition in if/elif chain
        "with entry {\n    x = 5;\n    if x > 0 {\n        print(\"p\");\n    } elif x > 0 {\n        print(\"q\");\n    }\n}\n",

    ];
    for src in sources {
        path = _write_tmp(src);
        prog = JacProgram.jac_file_linter(path);
        rep_keys = _warn_keys(prog);
        full_keys = _full_pass_warnings(src, path);
        assert rep_keys == full_keys , (
            f"warning set diverged for {path}: " f"report={rep_keys} full={full_keys}"
        );
        os.remove(path);
    }
}
