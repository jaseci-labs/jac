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
import from jaclang.jac0core.compiler { JacCompiler, get_lint_sched }
import from jaclang.compiler.passes.tool.jac_auto_lint_pass {
    JacAutoLintPass,
    JacLintCheckPass
}

# SECOND_ORDER_FIXTURES are fixtures where the report path is a *strict subset*
# of the mutation pass. The mutation pass surfaces some warnings only *after* it
# has rewritten the tree, i.e. follow-on autofixes on nodes it synthesized:
#   - combine-glob on `glob`s extracted from `with entry` assignments
#     (`class_entry`, `extractable`),
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
         "usestate_to_has.jac"
     };

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
    rep_keys = _warn_keys(prog);
    full_keys = _full_pass_warnings(src, path);
    return (rep_keys, full_keys);
}

def _assert_report_matches_full(path: str, source: str | None = None) {
    (rep_keys, full_keys) = _report_and_full(path, source);
    assert rep_keys == full_keys , (
        f"warning set diverged for {path}: " f"report={rep_keys} full={full_keys}"
    );
}

def _assert_report_subset_of_full(path: str, source: str | None = None) {
    (rep_keys, full_keys) = _report_and_full(path, source);
    extra = sorted(set(rep_keys) - set(full_keys));
    assert not extra , (
        f"report path over-reported for {path}: "
        f"warnings not emitted by the full pass: {extra}"
    );
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
        try {
            _assert_report_matches_full(path, src);
        } finally {
            os.remove(path);
        }
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
