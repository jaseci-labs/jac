"""Child-position stability for JSX statement slots (issue #7859).

Each statement in a slot body owns a reserved index, so a child's position is
fixed by where it is written rather than by what ran before it.
"""

import os;
import re;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { run_pass }

glob SLOT_POS = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "ecmascript",
         "fixtures",
         "slot_positions"
     ),
     ACC = "__jac_view_kids";

"""Compile a fixture to JavaScript and assert no errors were emitted."""
def compile_fixture(filename: str) -> str {
    path = os.path.join(SLOT_POS, filename);
    prog = JacProgram();
    ir = prog.compile(file_path=path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {filename}: " + str([str(e) for e in prog.errors_had])
    );
    return es_to_js(run_pass(EsastGenPass, ir, prog).ir_out.gen.es_ast);
}

"""Assert the slot accumulator's reserved length and the indices written to it."""
def assert_positions(js_code: str, reserved: int, indices: list[int], msg: str) {
    found = re.search(r"let " + ACC + r" = \[([^\]]*)\];", js_code);
    assert found , (f"no `let {ACC} = [...]` initializer:\n" + js_code);
    body = found.group(1).strip();
    assert (len(body.split(",")) if body else 0) == reserved , (
        f"{msg}: expected {reserved} reserved positions\n" + js_code
    );
    written = [int(m) for m in re.findall(ACC + r"\[(\d+)\] = ", js_code)];
    assert written == indices , (f"{msg}: expected writes at {indices}\n" + js_code);
}

"""The one appending accumulator a loop declares, asserting there is only one."""
def loop_acc(js_code: str) -> str {
    found = re.findall(r"let (__jac_view_kids_\d+) = \[\];", js_code);
    assert len(found) == 1 , (
        "expected exactly one appending accumulator:\n" + js_code
    );
    return found[0];
}

test "sibling conditionals keep their own child positions" {
    # The reconciliation bug: appending made a child vanish when its branch was
    # not taken, so B slid from index 1 to 0 and React remounted it. The same
    # slot also proves the fragment shape: `__jacJsx(null, {}, [acc])` hands
    # React one child whose value is an array, which is what it key-validates.
    js_code = compile_fixture("two_conditionals.jac");

    assert f"__jacJsx(null, {{}}, [{ACC}])" not in js_code , (
        "the accumulator must not be nested inside another array:\n" + js_code
    );
    assert f"__jacJsx(null, {{}}, {ACC})" in js_code , (
        "its contents should be the fragment's positional children:\n" + js_code
    );
    assert f"{ACC}.push(" not in js_code , (
        "a counted slot must not append:\n" + js_code
    );
    assert_positions(js_code, 2, [0, 1], "two conditionals own distinct indices");
}

test "an if reserves one range for every arm, sized by its widest" {
    # Both arms restart at 0, so a toggle reuses the element the way hand-written
    # `{cond ? <a/> : <b/>}` does, and the sibling starts past the whole range
    # rather than landing on the wide arm's second child.
    assert_positions(
        compile_fixture("if_else_uneven.jac"),
        3,
        [0, 1, 0, 2],
        "arms share a range, the sibling follows it"
    );
}

test "a loop keeps its own array and occupies one parent position" {
    # A loop's count is only known at run time, so it appends into an array of
    # its own, returned raw so React still requires the author's per-item keys.
    # An inner loop opening a second accumulator would group the children into
    # unkeyed sub-arrays, which React pairs by position, so reordering the outer
    # list would rebuild every item even though each key is correct.
    js_code = compile_fixture("nested_loops.jac");
    inner = loop_acc(js_code);

    assert len(re.findall(inner + r"\.push\(", js_code)) == 1 , (
        "only the innermost element appends; no nested sub-array:\n" + js_code
    );
    assert f"return {inner};" in js_code , (
        "the loop accumulator stays a raw array, so keys stay required:\n" + js_code
    );
    assert_positions(js_code, 2, [0, 1], "the whole nest occupies one position");
}

test "a while loop is routed like every other loop form" {
    # `for` is not the only dynamic construct, and each loop form is a separate
    # node type in the walker.
    js_code = compile_fixture("while_slot.jac");

    loop_acc(js_code);
    assert_positions(js_code, 2, [0, 1], "a `while` loop occupies one position");
}

test "an elif chain keeps every arm on the same footing" {
    # `ElseIf` subclasses `IfStmt`. Any lowering that treats an arm as its own
    # chain root can put one arm out of step with the rest, and a stranded
    # `} else (<expr>)` is valid JavaScript that renders nothing.
    blocked = compile_fixture("elif_chain_blocked.jac");
    clean = compile_fixture("elif_chain_clean.jac");

    for js_code in [blocked, clean] {
        assert re.search(r"\} else if \(", js_code) , (
            "every arm stays a statement:\n" + js_code
        );
        assert re.search(r"\} else \(", js_code) is None , (
            "an `else` holding a bare expression discards its children:\n" + js_code
        );
    }
    assert_positions(clean, 1, [0, 0, 0], "all three arms share one position");
    # The blocked chain carries a `skip`. Lifting an arm into an expression puts
    # its body in a closure, so the `skip` would return from that closure rather
    # than the loop it was written in.
    assert re.search(r'if \(\(t === "x"\)\) \{\s*return ', blocked) , (
        "`skip` must stay an early return inside the loop body:\n" + blocked
    );
    assert "? (() =>" not in blocked , (
        "no arm may be lifted into a conditional expression:\n" + blocked
    );
}
