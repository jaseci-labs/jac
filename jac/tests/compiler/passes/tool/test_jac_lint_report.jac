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
import from jaclang.project.config { JacConfig, CheckConfig, LintConfig, set_config }

def _diag_keys(prog: JacProgram) -> list[str] {
    keys: list[str] = [];
    for e in (prog.errors_had or []) {
        keys.append(str(e));
    }
    for w in (prog.warnings_had or []) {
        keys.append(str(w));
    }
    return sorted(keys);
}

def _full_pass_diags(source: str, path: str) -> list[str] {
    (p, m) = JacCompiler._prepare_tool_program(source, path);
    if m is None {
        return [];
    }
    JacAutoLintPass(ir_in=m, prog=p).ir_out;
    return _diag_keys(p);
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

test "lint report path preserves every diagnostic the mutation pass emits" {
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
        # W3005 empty parens on zero-arg function
        "def no_params() {\n    return;\n}\n",
        # W3006 unnecessary keyword escape on a non-reserved name
        "with entry {\n    `myvar = 5;\n}\n",
        # W3007 hasattr in boolean expression can become null-safe access
        "obj Instance {\n    has value: int = 1;\n}\n"
        "with entry {\n    instance = Instance();\n"
        "    ok = hasattr(instance, \"value\") and instance.value > 0;\n}\n",
        # E3012 bare print() (opt-in rule; enabled via select = ["all"] below)
        "def greet(name: str) -> None {\n    print(\"hi \" + name);\n}\n",
        # W3039 getattr(..., None) → null-safe access
        "obj Box {\n    has value: int = 0;\n}\n"
        "with entry {\n    b = Box();\n    x = getattr(b, \"value\", None);\n}\n",
        # W3042 map(lambda → JSX) → list comprehension
        "def render(items: list) -> JsxElement {\n"
        "    rows = items.map(\n"
        "        lambda (item: any) -> any {\n"
        "            return <li>{item}</li>;\n"
        "        }\n"
        "    );\n"
        "    return <ul>{rows}</ul>;\n"
        "}\n",
        # W3043 @property → native has-accessor
        "obj Counter {\n"
        "    @property\n"
        "    def val -> int {\n"
        "        return 1;\n"
        "    }\n"
        "}\n",

    ];

    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=["all"]));
    set_config(config);
    try {
        for src in sources {
            path = _write_tmp(src);
            try {
                prog = JacProgram.jac_file_linter(path);
                rep_keys = _diag_keys(prog);
                full_keys = _full_pass_diags(src, path);
                assert rep_keys == full_keys , (
                    f"diagnostic set diverged for {path}: "
                    f"report={rep_keys} full={full_keys}"
                );
            } finally {
                os.remove(path);
            }
        }
    } finally {
        set_config(None);
    }
}
