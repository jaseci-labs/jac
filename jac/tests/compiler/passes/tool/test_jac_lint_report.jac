"""Jac lint *report* path tests.

The report path (`jac lint`, `JacProgram.jac_file_linter`) must run the
report-only lint pass (`JacLintCheckPass`, report_only=True) and never the
mutation pass (`JacAutoLintPass`). Going report-only skips the AST-rewriting
hooks and is much cheaper, but it must still surface every warning the full
mutation pass would — otherwise `jac lint` would silently under-report.
"""
import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { JacCompiler, get_lint_sched, run_pass }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.tool.jac_auto_lint_pass {
    JacAutoLintPass,
    JacLintCheckPass
}
import from jaclang.project.config { JacConfig, CheckConfig, LintConfig, set_config }

# SECOND_ORDER_FIXTURES are fixtures where the report path is a *strict subset*
# of the mutation pass. The mutation pass surfaces some warnings only *after* it
# has rewritten the tree, i.e. follow-on autofixes on nodes it synthesized:
#   - combine-glob on `glob`s extracted from `with entry` assignments
#     (`class_entry`, `extractable`, `non_extractable` — upstream now extracts
#     every assignment out of unnamed `with entry` blocks, even calls and
#     attribute access, so that fixture's name is historical),
#   - simplify-ternary that only appears once `hasattr(...)` conditions are
#     rewritten to null-safe access (`hasattr_conversion`),
#   - combine-has on `has` declarations synthesized from `useState` hooks
#     (`usestate_to_has`).
# The report path never mutates, so it emits the *primary* warning (extract /
# hasattr-to-null-ok / usestate-to-has) and the follow-on surfaces on the next
# lint once the primary autofix is applied. This is normal iterative linting.
# These fixtures are exempt from exact parity but still held to the subset
# invariant (report must never emit a warning the full pass would not).
glob AUTO_LINT_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "tool", "fixtures", "auto_lint"
     ),
     SECOND_ORDER_FIXTURES = {
         "class_entry.jac",
         "extractable.jac",
         "hasattr_conversion.jac",
         "non_extractable.jac",
         "usestate_to_has.jac"
     };

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
    run_pass(JacAutoLintPass, m, p).ir_out;
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

def _report_and_full(
    path: str, source: str | None = None
) -> tuple[list[str], list[str]] {
    src = source;
    if src is None {
        with open(path) as f {
            src = f.read();
        }
    }
    prog = JacProgram.jac_file_linter(path);
    rep_keys = _diag_keys(prog);
    full_keys = _full_pass_diags(src, path);
    return (rep_keys, full_keys);
}

def _assert_report_matches_full(path: str, source: str | None = None) {
    (rep_keys, full_keys) = _report_and_full(path, source);
    assert rep_keys == full_keys , (
        f"diagnostic set diverged for {path}: " f"report={rep_keys} full={full_keys}"
    );
}

def _assert_report_subset_of_full(path: str, source: str | None = None) {
    (rep_keys, full_keys) = _report_and_full(path, source);
    extra = sorted(set(rep_keys) - set(full_keys));
    assert not extra , (
        f"report path over-reported for {path}: "
        f"diagnostics not emitted by the full pass: {extra}"
    );
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
        # W3007 hasattr in boolean expression can become null-safe access
        "obj Instance {\n    has value: int = 1;\n}\n"
        "with entry {\n    instance = Instance();\n"
        "    ok = hasattr(instance, \"value\") and instance.value > 0;\n}\n",
        # E3012 bare print() (opt-in rule; enabled via select = ["all"] below)
        "def greet(name: str) -> None {\n    print(\"hi \" + name);\n}\n",
        # W3039 getattr(..., None) → null-safe access
        "obj Box {\n    has value: int = 0;\n}\n"
        "with entry {\n    b = Box();\n"
        "    x = getattr(b, \"value\", None);\n}\n",
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
                _assert_report_matches_full(path, src);
            } finally {
                os.remove(path);
            }
        }
    } finally {
        set_config(None);
    }
}

test "lint report path matches mutation pass on auto_lint fixtures" {
    fixture_names = sorted(
        name
        for name in os.listdir(AUTO_LINT_FIXTURES)
        if name.endswith(".jac")
    );
    assert "empty_parens.jac" in fixture_names;
    for name in fixture_names {
        path = os.path.join(AUTO_LINT_FIXTURES, name);
        # The report path must never emit a warning the full pass would not,
        # on any fixture (no spurious or wrong warnings).
        _assert_report_subset_of_full(path);
        # And it must match the full pass exactly, except on fixtures whose
        # only divergence is a documented follow-on autofix warning.
        if name not in SECOND_ORDER_FIXTURES {
            _assert_report_matches_full(path);
        }
    }
}

test "exit_if_else_expr report_only does not mutate is_null_ok on trailers" {
    src = (
        "obj Foo { has val: int = 0; }\n"
        "with entry {\n"
        "    f: Foo | None = None;\n"
        "    x = f?.val if f is not None else f.val;\n"
        "}\n"
    );
    path = _write_tmp(src);
    try {
        (p, m) = JacCompiler._prepare_tool_program(src, path);
        assert m is not None;
        not_null_ok_before = {
            id(t)
            for t in m.get_all_sub_nodes(uni.AtomTrailer)
            if not t.is_null_ok
        };
        run_pass(JacLintCheckPass, m, p);
        trailers_after = m.get_all_sub_nodes(uni.AtomTrailer);
        mutated = [
            t
            for t in trailers_after
            if id(t) in not_null_ok_before and t.is_null_ok
        ];
        assert not mutated , (
            f"report_only pass mutated is_null_ok on {len(mutated)} AtomTrailer(s); "
            f"exit_if_else_expr must not call _make_null_ok in report_only mode"
        );
    } finally {
        os.remove(path);
    }
}
