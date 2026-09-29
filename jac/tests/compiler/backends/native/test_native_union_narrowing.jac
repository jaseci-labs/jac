"""Flow-sensitive union narrowing has to survive native lowering (#8150).

#8052 sealed `unitree.jac` natively by rewriting six methods around shapes the
native backend could not lower. Each rewrite is a receipt for a distinct
narrowing form, and each is reproduced here against a fixture whose functions
answer by *value*, not by whether the module compiled:

  N1  a negated tuple-form `isinstance` inside an `or`-chain guard
      (`UniScopeNode.get_enclosing_captures`)
  N2  a narrow that has to reach a ternary arm (`UniScopeNode.insert`,
      `Archetype._get_impl_resolved_body`)
  N3  a narrow keyed on a subscript expression (`LambdaExpr.tail_return_expr`)
  N4  a field read and loop over a union-joined narrow
      (`UniScopeNode._fix_store_ctx`)
  N5  a field read off a narrowed `self` (`UniNode.codespace`)
  N6  a defensive copy taken on one member of a union field
      (`LambdaExpr.postinit`)

A narrowing that is dropped rather than mis-lowered still produces a
well-typed value, so every fixture carries both the idiomatic spelling and
the workaround #8052 used, and every function is additionally checked against
the sv/bytecode result of the same fixture -- the parity idiom
`test_native_union_slot_ops.jac` uses.

Refs #8150, #8027 (T1.1), #8039, #8052
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _ENGINES: dict[str, object] = {},
     _SV_MODS: dict[str, object] = {};


"""Compile a fixture natively and return its JIT engine, memoized per module.

A narrowing the backend cannot lower surfaces here first: the emitter raises,
the module carries diagnostics, and there is no engine to call into. That is
a real failure of the shape, so it is asserted rather than skipped.
"""
def _engine(fixture: str) -> any {
    hit = _ENGINES.get(fixture);
    if hit is not None {
        return hit;
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    _ENGINES[fixture] = eng;
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(fixture: str, name: str) -> any {
    addr = native_address(_engine(fixture), name);
    assert addr != 0 , f"Function '{name}' not found in the engine for {fixture}";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway, memoized."""
def _sv(fixture: str) -> any {
    hit = _SV_MODS.get(fixture);
    if hit is not None {
        return hit;
    }
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=fixture[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , f"sv import of {fixture} produced no module";
    _SV_MODS[fixture] = mods[0];
    return mods[0];
}


"""Assert every listed function agrees with sv over every flag."""
def _parity(fixture: str, names: list[str], flags: list[int]) {
    sv = _sv(fixture);
    for name in names {
        na_fn = _get(fixture, name);
        sv_fn = getattr(sv, name);
        for flag in flags {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{fixture}::{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


"""Assert two spellings of the same answer agree natively, flag by flag."""
def _agree(fixture: str, a: str, b: str, flags: list[int]) {
    fa = _get(fixture, a);
    fb = _get(fixture, b);
    for flag in flags {
        assert fa(flag) == fb(flag) , (
            f"{fixture}: {a}({flag}) = {fa(flag)} but {b}({flag}) = {fb(flag)}"
        );
    }
}


# --- N1: negated tuple-form isinstance over a union operand ---
glob N1 = "narrow_negated_isinstance_tuple.jac",
     N1_FNS = [
         "negated_tuple_guard",
         "negated_or_chain_guard",
         "bare_negated_tuple",
         "plain_tuple_guard",
         "negated_tuple_elif"
     ],
     N1_FLAGS = [0, 1, 2, 3, 4, 5, 6];


test "N1: a negated tuple-form isinstance guard admits exactly its members" {
    f = _get(N1, "negated_tuple_guard");
    assert f(0) == -1 , "an unset tab is skipped";
    assert f(1) == 11 , "the first listed class is admitted with its payload";
    assert f(2) == 22 , "the second listed class";
    assert f(3) == 33 , "the third listed class";
    assert f(4) == 44 , "the fourth listed class";
    assert f(5) == -1 , "a class outside the tuple must be skipped, not admitted";
    assert f(6) == -1 , "an unset tab is skipped";
}


test "N1: the tuple form and the four-or expansion answer identically" {
    _agree(N1, "negated_tuple_guard", "negated_or_chain_guard", N1_FLAGS);
    _agree(N1, "bare_negated_tuple", "negated_tuple_guard", N1_FLAGS);
}


test "N1: the negated form is the exact complement of the plain one" {
    neg = _get(N1, "bare_negated_tuple");
    pos = _get(N1, "plain_tuple_guard");
    for flag in N1_FLAGS {
        assert neg(flag) == pos(flag) , (
            f"flag {flag}: `not isinstance(...)` -> continue and "
            f"`isinstance(...)` -> use disagree ({neg(flag)} vs {pos(flag)})"
        );
    }
}


test "N1: every negated-tuple spelling agrees with sv" {
    _parity(N1, N1_FNS, N1_FLAGS);
}


# --- N2: narrowing through a ternary chain ---
glob N2 = "narrow_ternary_chain.jac",
     N2_FNS = [
         "resolve_ternary",
         "resolve_flat",
         "resolved_body_sum",
         "resolved_body_flat_sum"
     ],
     N2_FLAGS = [0, 1, 2, 3];


test "N2: a nested ternary resolves each arm to its own value" {
    f = _get(N2, "resolve_ternary");
    assert f(0) == 1 , "the absent spec falls to the innermost else (PUBLIC)";
    assert f(1) == 0 , "an already-resolved member is passed through (PRIVATE)";
    assert f(2) == 2 , "a node's member is read off the middle arm (PROTECTED)";
}


test "N2: the ternary and the flat resolution answer identically" {
    _agree(N2, "resolve_ternary", "resolve_flat", N2_FLAGS);
    _agree(N2, "resolved_body_sum", "resolved_body_flat_sum", N2_FLAGS);
}


test "N2: a ternary yielding a container keeps its elements" {
    f = _get(N2, "resolved_body_sum");
    assert f(0) == 0 , "an empty list resolves to nothing";
    assert f(1) == 7 , "a bare list arm keeps both elements";
    assert f(2) == 18 , "the node arm's inner list keeps all three";
    assert f(3) == 0 , "a node whose body is not a list resolves to empty";
}


test "N2: every ternary-chain spelling agrees with sv" {
    _parity(N2, N2_FNS, N2_FLAGS);
}


# --- N3: narrowing a subscript expression ---
glob N3 = "narrow_subscript.jac",
     N3_FNS = [
         "tail_value_inplace",
         "tail_value_bound",
         "first_elem_narrow",
         "last_elem_narrow"
     ],
     N3_FLAGS = [0, 1, 2, 3, 4];


test "N3: a narrow keyed on stmts[0] reaches the field read" {
    f = _get(N3, "tail_value_inplace");
    assert f(0) == -1 , "an empty body has no tail expression";
    assert f(1) == 17 , "the single expression statement's value";
    assert f(2) == 23 , "an implicit return's value";
    assert f(3) == -2 , "an explicit return is not a tail expression";
    assert f(4) == -1 , "two statements are not a tail expression";
}


test "N3: narrowing stmts[0] in place matches binding it to a local first" {
    _agree(N3, "tail_value_inplace", "tail_value_bound", N3_FLAGS);
}


test "N3: subscript narrows hold for constant and computed indices" {
    first = _get(N3, "first_elem_narrow");
    last = _get(N3, "last_elem_narrow");
    assert first(1) == 17 , "stmts[0] narrowed to the expression statement";
    assert first(2) == 0 , "a return statement falls through to the base field";
    assert last(3) == 29 , "stmts[len - 1] narrowed to the return statement";
    assert last(4) == 0 , "a non-return last element reads the base field";
}


test "N3: every subscript-narrow spelling agrees with sv" {
    _parity(N3, N3_FNS, N3_FLAGS);
}


# --- N4: field read and loop over a union-joined narrow ---
glob N4 = "narrow_union_join_field.jac",
     N4_FNS = [
         "fix_store_joined",
         "fix_store_split",
         "joined_field_len",
         "joined_field_and"
     ],
     N4_FLAGS = [0, 1, 2, 3, 4];


test "N4: a joined TupleVal | ListVal narrow reaches its shared field" {
    f = _get(N4, "fix_store_joined");
    assert f(0) == 0 , "an unset item touches nothing";
    assert f(1) == 3 , "the tuple arm sums its two values";
    assert f(2) == 60 , "the list arm sums its three values";
    assert f(3) == 7 , "the unary arm reads its single operand";
    assert f(4) == 106 , "the per-element narrow inside the loop still fires";
}


test "N4: the joined arm and the split-plus-helper form answer identically" {
    _agree(N4, "fix_store_joined", "fix_store_split", N4_FLAGS);
}


test "N4: a joined narrow supports a bare field read and an and-chain" {
    ln = _get(N4, "joined_field_len");
    an = _get(N4, "joined_field_and");
    assert ln(1) == 2 , "the tuple arm's length";
    assert ln(2) == 3 , "the list arm's length";
    assert ln(3) == -1 , "the unary arm has no values field";
    assert an(1) == 1 , "the first element off the and-chained narrow";
    assert an(2) == 10 , "the list arm's first element";
    assert an(3) == -1 , "the unary arm takes the else";
}


test "N4: every union-join spelling agrees with sv" {
    _parity(N4, N4_FNS, N4_FLAGS);
}


# --- N5: attribute access on a narrowed self ---
glob N5 = "narrow_self_attr.jac",
     # `space_walk_only` is compiled but not compared: the workaround
     # spelling is separately miscompiled by #8158 (move elision clears
     # `self`'s slot because its only later use is the right operand of an
     # `and`), which is a reason to retire it rather than a result to pin.
     N5_FNS = ["space", "ctx_or_zero"],
     N5_FLAGS = [0, 1, 2, 3, 4, 5, 6];


test "N5: a field read off a narrowed self answers before the walk" {
    f = _get(N5, "ctx_or_zero");
    assert f(0) == -1 , "a plain node is not context-aware";
    assert f(3) == 1 , "the narrowed self's own client context";
    assert f(4) == 0 , "the narrowed self's own server context";
    assert f(6) == 1 , "a module is context-aware too";
}


test "N5: the two spellings agree wherever #8158 does not corrupt the walk" {
    fast = _get(N5, "space");
    walk = _get(N5, "space_walk_only");
    for flag in [0, 1, 2, 3, 4, 6] {
        assert fast(flag) == walk(flag) , (
            f"flag {flag}: the `self` fast path answers {fast(flag)} and the "
            f"walk-from-self workaround {walk(flag)}"
        );
    }
    assert fast(5) == 0 , (
        "a module whose own context is unset resolves to SERVER, and the "
        "walk-from-self spelling gets this wrong for a different reason "
        "(#8158): its `nd is not self` guard reads a receiver slot that move "
        "elision already cleared"
    );
}


test "N5: the fast path does not change the walk's own scope" {
    f = _get(N5, "space");
    assert f(0) == 0 , "an unparented plain node has no context";
    assert f(1) == 2 , "the module ancestor decides";
    assert f(2) == 1 , "the nearer context-aware ancestor wins over the module";
    assert f(3) == 1 , "self's own context wins over every ancestor";
    assert f(5) == 0 , (
        "a module whose own context is unset must not read its own decided "
        "codespace -- the module rule is about ancestors"
    );
}


test "N5: every narrowed-self spelling agrees with sv" {
    _parity(N5, N5_FNS, N5_FLAGS);
}


# --- N6: a defensive copy taken on one member of a union field ---
glob N6 = "narrow_union_conditional_copy.jac",
     N6_FNS = [
         "shared_list_is_not_aliased",
         "expr_body_untouched",
         "copied_list_keeps_payload"
     ],
     N6_FLAGS = [0, 1, 2];


test "N6: a union-conditional copy actually breaks the alias" {
    f = _get(N6, "shared_list_is_not_aliased");
    assert f(0) == 2 , "the untouched list";
    assert f(1) == 2 , (
        "the caller appended once after construction; without the defensive "
        "copy the object's body aliases that list and reads back 3"
    );
    assert f(2) == 2 , "two appends after construction still must not show through";
}


test "N6: the copy is shallow but the slots are the object's own" {
    f = _get(N6, "copied_list_keeps_payload");
    assert f(0) == 7 , "replacing the caller's slot 0 must not move the object's";
    assert f(1) == 8 , "the same with a different payload";
    assert f(2) == 9 , "and again";
}


test "N6: the non-list member passes through the postinit untouched" {
    f = _get(N6, "expr_body_untouched");
    assert f(0) == 41 , "an expression body is not copied and is not lost";
    assert f(1) == 42 , "the payload survives the union-conditional branch";
    assert f(2) == 43 , "and again";
}


test "N6: every union-conditional-copy spelling agrees with sv" {
    _parity(N6, N6_FNS, N6_FLAGS);
}
