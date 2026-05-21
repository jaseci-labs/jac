"""Positive-pass tests for the JSX slot extensions shipped in this PR.

Each test verifies one of the four #6082 items implemented on this branch:

  - rec 1.4: item 1 priority 4 fallback (W2021 when no key derivable)
  - rec 1.5: item 2 (keyless for-loop diagnostic; accepts W2019 or W2021)
  - rec 3:   item 4 (E2024 -- has-in-slot)
  - rec 5:   item 6 ({name} prop shorthand)

The ten still-failing tests for the unimplemented #6082 items live on
the companion spec branch -- see PR #6088. That PR is deliberately RED
in CI as an executable spec; this PR keeps CI green.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     SLOT_EXT = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "ecmascript",
         "fixtures",
         "slot_extensions"
     );

"""Compile a fixture to ESTree and assert no errors were emitted."""
def compile_to_esast(filename: str) -> es.Program {
    path = os.path.join(SLOT_EXT, filename);
    prog = JacProgram();
    ir = prog.compile(file_path=path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {filename}: " + str([str(e) for e in prog.errors_had])
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    return es_pass.ir_out.gen.es_ast;
}

"""Compile a fixture, returning the JacProgram so diagnostics can be inspected."""
def compile_for_diag(filename: str) -> JacProgram {
    path = os.path.join(SLOT_EXT, filename);
    prog = JacProgram();
    prog.compile(file_path=path);
    return prog;
}

"""True iff `program` emitted a diagnostic with the given code."""
def has_code(program: JacProgram, code: str, in_warnings: bool = False) -> bool {
    alerts = program.warnings_had if in_warnings else program.errors_had;
    for alert in alerts {
        if alert.code is not None and alert.code.code == code {
            return True;
        }
    }
    return False;
}

test "rec 1.4: for-loop slot fires W2021 when no key is derivable" {
    # Issue #6082 item 1 priority 4: when the loop var isn't a Jac obj,
    # the loop isn't counted, and no child carries an explicit `key=`,
    # the lowering has no priority to fall back to and must fire W2021.
    # Today the diagnostic emission lives in `_check_body` -- any
    # keyless for-loop fires it. When item 1's auto-fragment lands,
    # priorities 1-3 will short-circuit before W2021 reaches the loops
    # that *do* have a derivable key.
    prog = compile_for_diag("loop_no_derivable_key.cl.jac");
    assert has_code(prog, "W2021", in_warnings=True) , (
        "a keyless for-loop with no auto-derivable key must fire W2021; "
        "warnings were: " + str(
            [
                (w.code.code if w.code else "?") + ": " + str(w)
                for w in prog.warnings_had
            ]
        )
    );
}

test "rec 1.5: keyless for-loop in a slot fires a warning (#6082 item 2)" {
    # Issue #6082 item 2: today `_emits_keyless_jsx` in `_check_body`
    # only runs on `WhileStmt` -- for-loops slip through silently. The
    # fix should extend the check to cover for-loops too. The issue
    # body explicitly leaves the code open: "reusing W2019 (rename
    # 'while' -> 'loop') or as a new W2021 if (1) lands first." This
    # test therefore accepts EITHER code.
    prog = compile_for_diag("keyless_for_diag.jac");
    has_warning = (
        has_code(prog, "W2019", in_warnings=True)
        or has_code(prog, "W2021", in_warnings=True)
    );
    assert has_warning , (
        "a keyless `for` slot must fire either W2019 (extended from "
        "while) or W2021 (new); warnings were: " + str(
            [
                (w.code.code if w.code else "?") + ": " + str(w)
                for w in prog.warnings_had
            ]
        )
    );
}

test "rec 3: E2024 -- `has` declared inside a JSX slot body is rejected" {
    # A `has`-field inside a `{...}` slot's statement template would
    # compile to a conditional useState -- a rules-of-hooks violation.
    # ViewLowerPass's `_check_body` matches `uni.HasVar` recursively
    # and emits E2024.
    prog = compile_for_diag("has_in_slot.jac");
    assert has_code(prog, "E2024") , (
        "declaring `has` inside a JSX slot body must raise E2024; " "errors were: " + str(
            [(e.code.code if e.code else "?") + ": " + str(e) for e in prog.errors_had]
        )
    );
}

test "rec 5: `{name}` JSX attribute shorthand expands to name={name}" {
    # New JSX attribute production `jsx_short_attr ::= "{" NAME "}"` --
    # `<Box {title} {count} {onClick}/>` is equivalent to
    # `<Box title={title} count={count} onClick={onClick}/>`. Parser-
    # level addition only; the lowering target is the same
    # `JsxNormalAttribute` as the explicit form.
    es_ast = compile_to_esast("prop_shorthand.cl.jac");
    js_code = es_to_js(es_ast);

    # The shorthand props must reach the __jacJsx call as named keys
    # whose values are the same-named local bindings.
    assert '"title": title' in js_code , (
        "shorthand `{title}` should lower to `title: title`:\n" + js_code
    );
    assert '"count": count' in js_code , (
        "shorthand `{count}` should lower to `count: count`:\n" + js_code
    );
    assert '"onClick": onClick' in js_code , (
        "shorthand `{onClick}` should lower to `onClick: onClick`:\n" + js_code
    );
}
