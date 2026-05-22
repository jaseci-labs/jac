"""Executable spec -- `try`/`awaiting`/`except` view-lowering (#6082 item 3).

This test is expected to FAIL until the except-arm integration lands in
`ViewLowerPass`. The file is a tracker, not a regression guard -- the
failure shape codifies the contract the implementing PR must satisfy.

Today, when a slot `try` carries an `awaiting` clause, `_lower_one`
returns early through `_lower_try_with_awaiting` (view_lower_pass.jac)
before the `except` arms are lowered, so the except body is parsed and
then silently discarded. The emitted JS contains only `<JacAwaiting>`.

The implementing PR also has to introduce the `JacClientErrorBoundary`
runtime component (no analogue exists in @jac/runtime today) and the
auto-import wiring for it.
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
}
