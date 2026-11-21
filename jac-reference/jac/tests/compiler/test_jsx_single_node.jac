"""A JSX element is one node, and its diagnostics are reported once.

A paired tag used to parse into three JsxElement nodes: an opening and a
closing artifact holding the tag tokens, plus the wrapper holding the real
children. The artifacts were structurally indistinguishable from elements --
same node type, same fields -- so anything walking JsxElement saw three
elements where the source has one.

That cost two bugs. The opening artifact carries attributes but no children,
so every component declaring a required 'children' reported at every call
site that passed children as a body; and every per-element JSX diagnostic was
emitted twice, once for the wrapper and once for the opening artifact.

The tokens now live directly in the element's kid list, so one element is one
node and neither ambiguity exists to be worked around.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { JsxElement }

def _compile(src: str) -> tuple[any, list[str]] {
    prog = JacProgram();
    mod = prog.compile(
        file_path="jsxone.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return (mod, [str(e) for e in prog.errors_had]);
}

test "a paired tag produces exactly one element node" {
    src = "def:pub Page -> JsxElement {\n"
        + "    return <div className='a'>hello</div>;\n"
        + "}\n";
    (mod, _errs) = _compile(src);
    elems = mod.get_all_sub_nodes(JsxElement);
    assert len(elems) == 1 , f"one source element produced {len(
        elems
    )} JsxElement nodes";
}

test "a required children prop is satisfied by a body" {
    src = "def:pub Box(children: any) -> JsxElement {\n"
        + "    return <div>{children}</div>;\n"
        + "}\n"
        + "def:pub Page -> JsxElement {\n"
        + "    return <Box>hi</Box>;\n"
        + "}\n";
    (_mod, errs) = _compile(src);
    assert not errs , f"a JSX body did not satisfy children: {errs}";
}
