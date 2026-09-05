"""A no-argument `set()` / `list()` in a ternary arm learns its element flavor.

`{"a"} if flag else {"b"}` lowered, and `["a"] if flag else []` lowered, but
`collect_generics() if is_p('<') else set()` did not: the empty *literal*
already had `_empty_list_dest_spec` to walk out to a destination and read the
flavor off it, while the empty *constructor* had only whatever inference had
put on the call node. In a ternary arm inference has nothing to put there --
nothing on that side of the branch mentions an element -- so the arm lowered
to nothing and the whole `IfElseExpr` was refused. That single shape accounts
for five of the six lowering failures in `types/ts_decl_parser.jac`.

The missing constraint is the sibling arm, and it is asked for in two ways
because one of them is not always available. Inference answers when the
sibling is annotated (`-> set[str]`). It cannot when the sibling is declared
bare (`-> set`), which is what `collect_generics` actually is -- and there the
arm the backend has *already lowered* answers exactly, because its handle
carries the helper table the flavor is named by.

`grows_after_empty` is the load-bearing one: picking a flavor that merely
type-checks is not enough, since a set built with one helper table and
inserted into through another corrupts. Taking the empty branch and then
adding to it proves the two arms really do share a representation.
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
        file_path=os.path.join(FIXTURES, "empty_ctor_ternary.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the empty-ctor fixture";
    _ENGINE.append(eng);
    return eng;
}


"""A fixture function taking one bool and returning an i64."""
def flag_fn(name: str) -> any {
    addr = native_address(engine(), name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_bool)(addr);
}


test "an empty set arm lowers when inference types the sibling" {
    fn = flag_fn("typed_arm");
    assert fn(True) == 2 , f"populated arm returned {fn(True)}, expected 2";
    assert fn(False) == 0 , f"empty arm returned {fn(False)}, expected 0";
}


test "an empty set arm lowers when the sibling is declared bare" {
    fn = flag_fn("bare_arm");
    assert fn(True) == 3 , f"populated arm returned {fn(True)}, expected 3";
    assert fn(False) == 0 , f"empty arm returned {fn(False)}, expected 0";
}


test "an empty list arm lowers the same way" {
    fn = flag_fn("bare_list_arm");
    assert fn(True) == 4 , f"populated arm returned {fn(True)}, expected 4";
    assert fn(False) == 0 , f"empty arm returned {fn(False)}, expected 0";
}


test "the empty arm shares the sibling's element representation" {
    fn = flag_fn("grows_after_empty");
    assert fn(False) == 1 , (
        f"inserting into the empty arm gave {fn(False)}, expected 1 -- the "
        "two arms were built with different helper tables"
    );
    assert fn(True) == 3 , (
        f"inserting into the populated arm gave {fn(True)}, expected 3"
    );
}
