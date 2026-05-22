"""Regression guard -- `try`/`awaiting`/`except` view-lowering (#6082 item 3).

On the `cl` target, a slot `try` that pairs an `awaiting` clause with one
or more `except` arms lowers to a `<JacClientErrorBoundary>` (the error
fallback) wrapping a `<JacAwaiting>` (the loading fallback) around the
try body. Both components are auto-imported from `@jac/runtime`.

Before #6109, `_lower_try_with_awaiting` (view_lower_pass.jac) returned
early once it had built the `<JacAwaiting>` wrapper, so the `except` arms
were parsed and then silently discarded -- the emitted JS contained only
`<JacAwaiting>`, and the authored error UI never reached the runtime.
This file locks in the fixed shape so that gap cannot reopen.
"""

import os;
import pytest;
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

test "rec 2: try/awaiting with except synthesises a JacClientErrorBoundary wrapper" {
    # On the cl target, when a slot `try` carries both `awaiting` and at
    # least one `except` clause, ViewLowerPass should synthesize a
    # `<JacClientErrorBoundary fallback={...}>` around the existing
    # `<JacAwaiting fallback={...}>{...}</JacAwaiting>` wrapper. The
    # except-arm bodies feed the error-boundary's fallback the same way
    # the awaiting body feeds the suspense fallback.
    es_ast = compile_to_esast("try_awaiting_except.cl.jac");
    js_code = es_to_js(es_ast);

    assert "JacClientErrorBoundary" in js_code , (
        "an except-arm alongside awaiting should synthesize a "
        "<JacClientErrorBoundary> wrapper:\n" + js_code
    );
    import re;
    assert re.search(
        r'import\s*\{[^}]*\bJacClientErrorBoundary\b[^}]*\}\s*' + r'from\s*[\'"]@jac/runtime[\'"]',
        js_code
    ) , ("JacClientErrorBoundary should be auto-imported from @jac/runtime");
    # Both the awaiting body and the except body content survive.
    assert "Loading" in js_code;
    assert "Something went wrong" in js_code;

    # The boundary must WRAP the awaiting node, not sit beside it: the
    # error fallback has to be outside the suspense fallback so a throw in
    # the resolved try body is caught. The error-boundary call therefore
    # opens before the awaiting call in the emitted source.
    eb_at = js_code.index("__jacJsx(JacClientErrorBoundary,");
    aw_at = js_code.index("__jacJsx(JacAwaiting,");
    assert eb_at < aw_at , (
        "<JacClientErrorBoundary> must wrap <JacAwaiting>, not the other "
        "way around:\n" + js_code
    );

    # The except UI belongs to the boundary's fallback, not the awaiting
    # suspense fallback: "Something went wrong" must render before the
    # awaiting node opens.
    assert js_code.index("Something went wrong") < aw_at , (
        "the except body must lower into the error boundary's fallback, "
        "ahead of the awaiting wrapper:\n" + js_code
    );
}

test "rec 2: a body diagnostic in the except arm is emitted exactly once" {
    # The except arm is lowered into a synthetic slot to build the error
    # boundary's fallback. That synthetic slot must not re-run the body
    # checker -- `exit_jsx_slot` already validated the whole raw template
    # (with the correct loop context). A keyless `for` in the except arm
    # must therefore warn W2021 once, not once per validation pass.
    path = os.path.join(SLOT_EXT, "try_awaiting_except_loop.cl.jac");
    prog = JacProgram();
    prog.compile(file_path=path);
    w2021 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W2021"
    ];
    assert len(w2021) == 1 , (
        "a keyless for-loop in the except arm should warn W2021 exactly "
        f"once, got {len(w2021)}: " + str([str(w) for w in w2021])
    );
}
