"""`list[jacval] -> list[ptr]` is a rebuild, not a refusal.

A list flows from a ternary whose arms unify at the boxed universal flavor
into a slot that holds the pointer flavor. The backend used to refuse it, and
the refusal was right as far as it went: the two layouts store elements at
different slot widths, so casting the handle would leave pointer slots holding
boxed words. What was missing is that a coercion between them is expressible --
element by element, boxing or unboxing each one, which the container helpers
already do for spreads.

The shape is not exotic. `ownership_check_pass` reaches it four times
(`_nogc_fresh_scalar_list`, `_emit_flow_for_diagnostics`, `_flow_reduce_shape`,
`_collect_flow_reductions`), all through `([x] if p else []) + list(...)`, and
`unitree.impl.jac` carries a comment naming this exact refusal as the reason a
nested ternary there had to be rewritten flat.

The assertions are sums and lengths together on purpose. A length alone passes
even if the elements are garbage, because the rebuild loop copies the right
number of slots either way; reading a field back off each element is what
shows the boxing actually happened. Both element kinds that change width are
covered -- pointers to archetypes and to strings -- plus a scalar case, which
takes the opposite direction through the same code.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     _ENGINE: list = [];


"""JIT the fixture once; return its execution engine."""
def engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "list_reflavor.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the reflavor fixture";
    _ENGINE.append(eng);
    return eng;
}


"""A fixture function taking one bool and returning an i64."""
def flag_fn(name: str) -> any {
    addr = native_address(engine(), name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_bool)(addr);
}


test "the rebuilt list has the right length" {
    fn = flag_fn("count_ptr_elems");
    assert fn(True) == 3 , f"expected 3 elements, got {fn(True)}";
    assert fn(False) == 2 , f"expected 2 elements, got {fn(False)}";
}


test "archetype elements survive the reflavor" {
    fn = flag_fn("sum_ptr_elems");
    assert fn(True) == 17 , (
        f"reading .n back off the rebuilt list gave {fn(True)}, expected 17 -- "
        "the pointer slots do not hold usable pointers"
    );
    assert fn(False) == 7 , f"empty-arm case gave {fn(False)}, expected 7";
}


test "string elements survive the reflavor" {
    fn = flag_fn("join_str_elems");
    assert fn(True) == 6 , f"total string length {fn(True)}, expected 6";
    assert fn(False) == 3 , f"total string length {fn(False)}, expected 3";
}


test "scalar elements take the opposite direction cleanly" {
    fn = flag_fn("sum_scalar_elems");
    assert fn(True) == 17 , f"scalar sum {fn(True)}, expected 17";
    assert fn(False) == 7 , f"scalar sum {fn(False)}, expected 7";
}
