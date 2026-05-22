"""Executable spec -- ambient `Ref[T]` + `useRef` lowering (#6082 item 8).

Expected to FAIL until the `has`-field -> hook lowering in
`esast_gen_pass.impl.jac` learns to lower a `Ref[T]`-typed field to
`useRef(null)` (parallel to the existing `has x: int = 0;` ->
`useState(0)` path) and auto-import `useRef` from react.

Cross-referenced with #6055 "Refs". Split out of #6088 so CI
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

test "rec 7: Ref[T] field declared with has lowers to useRef(null) in client context" {
    # Ambient `Ref[T]` type -- `has buttonRef: Ref[HTMLButtonElement];`
    # in client context lowers to `useRef(null)`, mirroring how `has x:
    # int = 0;` lowers to `useState(0)`.
    es_ast = compile_to_esast("has_ref.cl.jac");
    js_code = es_to_js(es_ast);

    assert "useRef(null)" in js_code , (
        "`has buttonRef: Ref[...]` should lower to useRef(null):\n" + js_code
    );
    # `useRef` must be imported from react like `useState` is for has-state.
    import re;
    assert re.search(
        r'import\s*\{[^}]*\buseRef\b[^}]*\}\s*from\s*[\'"]react[\'"]', js_code
    ) , (
        "useRef should be auto-imported from react when a Ref-typed "
        "has-field is present:\n" + js_code
    );
}
