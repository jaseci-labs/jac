"""Positive-pass tests for the JSX slot extensions from #6082.

Each test verifies one implemented #6082 item:

  - rec 1.4: item 1 priority 4 fallback (W2021 when no key derivable)
  - rec 1.5: item 2 (keyless for-loop diagnostic; accepts W2019 or W2021)
  - rec 3:   item 4 (E2024 -- has-in-slot)
  - rec 5:   item 6 ({name} prop shorthand)
  - rec 9:   item 10 (.style.css annex auto-scoping)

The remaining still-failing tests for unimplemented #6082 items live on
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

test "rec 9: a .style.css annex is auto-scoped and rewrites JSX className refs" {
    # #6082 item 10 -- files sharing a base name form one logical module.
    # A `.style.css` annex (`style_annex.style.css`) declares scoped classes
    # for `style_annex.cl.jac`; the compiler hashes each declared selector
    # per-module, rewrites the CSS rule, and rewrites JSX `className`
    # literals that match a declared class to the same hashed form. The
    # rewritten CSS is emitted as `gen.css` plus a side-effect import.
    import re;
    prog = JacProgram();
    path = os.path.join(SLOT_EXT, "style_annex.cl.jac");
    ir = prog.compile(file_path=path, no_cgen=True);
    assert not prog.errors_had , (
        "Compilation errors: " + str([str(e) for e in prog.errors_had])
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    mod = es_pass.ir_out;
    js_code = es_to_js(mod.gen.es_ast);

    # Declared class names are hashed to `card-<8 hex>` and the bare form
    # must not survive in the bundle.
    assert re.search(r'"className":\s*"card-[0-9a-f]{8}"', js_code) , (
        "annex-declared class names should be hashed in the JSX className "
        "literal:\n" + js_code
    );
    assert '"className": "card"' not in js_code , (
        "the unrewritten bare class name must not survive in the bundle"
    );

    # The rewritten CSS sidecar is emitted, its selectors hashed with the
    # same digest as the JSX refs, and `:global(...)` is unwrapped verbatim.
    css = mod.gen.css;
    card_match = re.search(r'"className":\s*"(card-[0-9a-f]{8})"', js_code);
    assert (card_match and ("." + card_match.group(1)) in css) , (
        "CSS selector must be hashed to match the JSX className ref:\n" + css
    );
    assert ".card {" not in css , "the bare `.card` selector must be rewritten";
    assert "html {" in css and ":global(html)" not in css , (
        "`:global(html)` should be unwrapped to a verbatim `html` selector:\n" + css
    );

    # A side-effect import wires the sidecar stylesheet to the module.
    assert 'import "./style_annex.css"' in js_code , (
        "a side-effect import of the rewritten CSS should be injected:\n" + js_code
    );
}
