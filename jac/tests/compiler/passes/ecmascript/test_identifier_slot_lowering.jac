"""Codegen contract: client state lowering is position-aware (#8167).

`has` fields on a client function lower every READ of the name to a state cell
(`__jacS_<name>.val`). That rewrite is a *reference* lowering, so it must fire
only where the name denotes a value in the enclosing scope. Names that sit in
an identifier slot -- a keyword-argument key, an attribute after a dot, a
parameter name, an import name, a declaration name -- name something in another
namespace entirely and must be emitted verbatim.

The rewrite used to be position-blind, so `theme=theme` inside a component that
declares `has theme` had its KEY rewritten alongside its value. That produced
`new Box({__jacS_theme.val: __jacS_theme.val})` (unparseable JavaScript) for a
constructor and, worse, `label(undefined, 2, ...__jacS_theme.val)` for a plain
call: the argument resolver did not recognize the mangled key, silently demoted
the pair to a trailing spread, and shipped a bundle that passed `undefined`.

These tests pin:
  - a kwarg key stays the plain parameter/field name on both call shapes
  - the state read lands in the parameter's positional slot, with no
    `undefined` filler and no trailing spread
  - attribute names after `.` are never rewritten
  - an unrecognized kwarg key shape is a hard codegen error (E5099), never a
    silent demotion to a spread
"""

import os;
import re;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { run_pass }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

"""Compile a fixture through the React ES backend, returning pass and JS."""
def compile_fixture(fixture_name: str) -> tuple[EsastGenPass, JacProgram, str] {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture_name), no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = run_pass(EsastGenPass, ir, prog, backend=ReactBackend());
    assert not prog.errors_had , (
        f"ES codegen errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    return (es_pass, prog, es_to_js(es_pass.ir_out.gen.es_ast));
}

"""Slice out the body of the named emitted function for focused assertions."""
def function_body(js: str, name: str) -> str {
    start = js.find(f"function {name}(");
    assert start >= 0 , f"emitted bundle has no function {name}:\n{js}";
    depth = 0;
    seen = False;
    for i in range(start, len(js)) {
        if js[i] == '{' {
            depth += 1;
            seen = True;
        } elif js[i] == '}' {
            depth -= 1;
            if seen and depth == 0 {
                return js[start:i + 1];
            }
        }
    }
    return js[start:];
}

test "constructor kwarg key survives client state lowering" {
    (es_pass, prog, js) = compile_fixture("kwarg_key_state_ctor.jac");
    body = function_body(js, "use_thing");

    assert re.search(r"theme:\s*__jacS_theme\.val", body) , (
        f"the kwarg key must stay the plain field name `theme`: {body}"
    );
    assert "__jacS_theme.val:" not in body , (
        f"a state cell read is not parseable in key position: {body}"
    );
}

test "plain-function kwarg lands in its parameter slot, not a trailing spread" {
    (es_pass, prog, js) = compile_fixture("kwarg_key_state_call.jac");
    body = function_body(js, "use_thing");

    assert re.search(r"label\(\s*__jacS_theme\.val\s*,\s*2\s*\)", body) , (
        f"the state read must fill `label`'s `theme` slot positionally: {body}"
    );
    assert "undefined" not in body , (
        f"no parameter slot may be left as an `undefined` filler: {body}"
    );
    assert "..." not in body , (
        f"a recognized kwarg must never be demoted to a trailing spread: {body}"
    );
}

test "attribute names after a dot are never rewritten to state reads" {
    (es_pass, prog, js) = compile_fixture("kwarg_key_state_ctor.jac");
    body = function_body(js, "App");

    assert "use_thing().theme" in body , (
        f"an attribute name must be emitted verbatim after `.`: {body}"
    );
    assert ".__jacS_theme" not in js , (
        f"no attribute may be rewritten into a state cell: {js}"
    );
}

test "an unrecognized kwarg key shape is a hard error, not a silent spread" {
    (es_pass, prog, js) = compile_fixture("kwarg_key_state_call.jac");
    calls = [
        nd
        for nd in es_pass.ir_out.get_all_sub_nodes(uni.FuncCall)
        if isinstance(nd.target, uni.Name) and nd.target.sym_name == "label"
    ];
    assert calls , "fixture must contain a call to `label`";

    es_pass.errors_had.clear();
    bogus = es.Property(
        key=es.MemberExpression(
            object=es.Identifier(name="__jacS_theme"),
            property=es.Identifier(name="val"),
            computed=False
        ),
        value=es.Identifier(name="x"),
        kind='init',
        method=False,
        shorthand=False,
        computed=False
    );
    slots = es_pass._resolve_call_arg_slots(
        calls[0], [], [bogus], ["theme", "size"], "label", None
    );

    codes = [
        alrt.code.code
        for alrt in es_pass.errors_had
        if alrt.code is not None
    ];
    assert "E5099" in codes , (
        "an unrecognized kwarg key must raise E5099, got "
        + str([str(e) for e in es_pass.errors_had])
    );
    assert not any(isinstance(slot.value, es.SpreadElement) for slot in slots) , (
        "the failing kwarg must not be laundered into a spread argument"
    );
}
