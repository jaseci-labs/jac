"""Executable spec -- `.style.css` annex auto-scoping (#6082 item 10).

Expected to FAIL until the compiler learns to treat a same-base-name
`.style.css` file as a scoped-style annex: hash each declared class with
a per-module digest, rewrite the CSS rule selectors, and rewrite JSX
`className` literals in the module that match a declared class.

Cross-referenced with #6055 "Scoped styles". Split out of #6088 so CI
(`--exitfirst`) stays green on the implementation branch while the spec
remains a visible tracker.
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

test "rec 9: a .style.css annex is auto-scoped and rewrites JSX className refs" {
    # Files sharing a base name form one logical module. A `.style.css`
    # annex declares scoped classes for the module's components -- the
    # compiler hashes selectors and rewrites JSX `className` literals
    # that match a declared class.
    es_ast = compile_to_esast("style_annex.cl.jac");
    js_code = es_to_js(es_ast);

    # The bare class name `card` in the source must be rewritten to a
    # hashed form like `card-<8 hex>`.
    import re;
    assert re.search(r'"className":\s*"card-[0-9a-f]{8}"', js_code) , (
        "class names declared in the .style.css annex should be hashed "
        "and the JSX className literal rewritten:\n" + js_code
    );
    # A bare-name reference would mean no rewrite happened.
    assert '"className": "card"' not in js_code , (
        "the unrewritten bare class name must not survive in the bundle"
    );
}
