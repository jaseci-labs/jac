"""Executable spec — client components forward refs via `forwardRef` (#6520).

This is the *producer* side of refs. The consumer side — `Ref[T]` has-fields +
`useRef`, and `ref=` JSX attributes — already works (see test_jsx_ref_spec.jac).
The gap was that a jac component could not *be* a ref target: the ecmascript
backend never emitted `React.forwardRef`, so any radix `asChild` composition over
a jac component (DropdownMenu / Tooltip / Popover triggers) silently dropped the
anchor ref and never positioned.

A client JSX component opts in by declaring a trailing parameter typed `Ref` —
a 1:1 match with React's `forwardRef((props, ref) => ...)` render signature. It
must lower to `const C = forwardRef(function C(props, ref) {...})`, with `ref`
threaded as the 2nd positional arg (never destructured out of `props`), and
`forwardRef` auto-imported from react (mirroring how `useRef` is taken straight
from react for `Ref[T]` has-fields).
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }

glob SLOT_EXT = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "ecmascript",
         "fixtures",
         "slot_extensions"
     );

"""Compile a fixture to JS, asserting no compilation errors were emitted."""
def compile_to_js(filename: str) -> str {
    path = os.path.join(SLOT_EXT, filename);
    prog = JacProgram();
    ir = prog.compile(file_path=path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {filename}: " + str([str(e) for e in prog.errors_had])
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

test "props+ref component lowers to forwardRef with a (props, ref) signature" {
    import re;
    js = compile_to_js("forward_ref_button.cl.jac");

    # Wrapped in forwardRef and bound to a const of the component's name, with
    # the React render signature `(props, ref)`.
    assert re.search(
        r'const\s+Button\s*=\s*forwardRef\(\s*function\s+Button\s*\(\s*props\s*,\s*ref\s*\)',
        js
    ) , (
        "a component with a trailing `ref: Ref` param should lower to "
        "`const Button = forwardRef(function Button(props, ref) {...})`:\n" + js
    );
    # `ref` must be the 2nd positional arg, NOT destructured out of `props`
    # (the pre-fix bug produced `const {props, ref} = props;`).
    assert "const {props, ref} = props" not in js , (
        "`ref` must be the 2nd positional arg, not destructured from props:\n" + js
    );
    # `forwardRef` is taken straight from react, mirroring `useRef`.
    assert re.search(
        r'import\s*\{[^}]*\bforwardRef\b[^}]*\}\s*from\s*[\'"]react[\'"]', js
    ) , ("forwardRef should be auto-imported from react:\n" + js);
    # The forwarded ref reaches the host node.
    assert '"ref": ref' in js , (
        "the forwarded ref should pass through to the host element:\n" + js
    );
}

test "named props alongside a ref: props destructure, ref stays positional" {
    import re;
    js = compile_to_js("forward_ref_named.cl.jac");

    assert re.search(
        r'const\s+Card\s*=\s*forwardRef\(\s*function\s+Card\s*\(\s*props\s*,\s*ref\s*\)',
        js
    ) , (
        "a named-param component with a trailing `ref: Ref` should still lower "
        "to `forwardRef(function Card(props, ref) {...})`:\n" + js
    );
    # The named props destructure from `props` as exactly `{title, body}` --
    # `ref` is not among them (it is the trailing positional arg instead).
    assert re.search(r'const\s*\{\s*title\s*,\s*body\s*\}\s*=\s*props', js) , (
        "named props should destructure from the props bundle:\n" + js
    );
    # The forwarded ref reaches the host node.
    assert '"ref": ref' in js , (
        "the forwarded ref should pass through to the host element:\n" + js
    );
}
