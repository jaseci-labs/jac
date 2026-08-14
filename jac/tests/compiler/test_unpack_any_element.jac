"""Unpacking an `Any` element binds `Any`, not `Unknown`.

Iterating a generic left unparameterized yields `Any`, and unpacking `Any`
should bind `Any` to every target. Jac agreed on the first half but not the
second: `_extract_tuple_element_type` returned None for anything that was
not a `ClassType`, `Any` included, so each destructured target fell through
to `Unknown`, and every *use* of such a target then errored (E1053/E1055).

The fixture spells its containers `tuple[any, any]` / `list[any]` rather than
the bare `tuple`/`list` it was written with: those are E1036 since #8080 and
their elements are now `Unknown` by design. The explicit spelling reaches the
same code path only because the `is_any_instance()` fix below landed -- before
it, an explicit `any` element destructured to `Unknown`.

The follow-up that #8039 flagged and left open -- unpacking a value whose
*declared* annotation is `any` (`pair: any; (nm, ty) = pair;`) raising E1020
and binding Unknown -- is now closed here too. The cause was the same shape in
two places: an explicit `any` is not a `types.AnyType`, it is a `ClassType` for
builtin `Any`, so both the E1020 guard in `type_checker_pass` and the
`isinstance(tuple_type, types.AnyType)` early return in
`_extract_tuple_element_type` looked straight past it. Both now ask
`is_any_instance()`, which is the predicate that spans both spellings.

This also covers the bare-generic chain that surfaced it in the compiler
itself: `_gen_ctx: (dict | None)` indexed twice yields builtin `Any`, so
`(_sn, _soff, _st) = _gc["slots"][-1];` in `closures.impl.jac` was E1020.

Still out of scope, and reproducible with no unpacking at all: operators on an
explicit `any` (`x: any = "a"; x + "b";`) report E1055. The binary-op checker
does not consult `is_any_type`, which is a separate fix -- hence `str(nm)`
rather than `nm + ...` below.

Refs #8039
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "fixtures");

"""Type-check a fixture and return its errors."""
def check_errors(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=CompileOptions(type_check=True, no_cgen=True)
    );
    return [str(e) for e in (prog.errors_had or [])];
}

test "unpacking elements of an Any-erased container type-checks clean" {
    errs = check_errors("unpack_any_element.jac");
    assert not errs , f"expected no type errors, got {errs}";
}

test "a destructured Any target is usable where its type is constrained" {
    errs = check_errors("unpack_any_element.jac");
    # `takes_type(ty)` constrains a destructured target to `type`, and
    # `str(nm)` constrains the other. Both were E1053/E1055 before.
    joined = " ".join(errs);
    assert "E1053" not in joined , f"Unknown leaked into a parameter: {errs}";
    assert "E1055" not in joined , f"Unknown leaked into an operator: {errs}";
}

test "unpacking an explicitly `any`-annotated value is not E1020" {
    errs = check_errors("unpack_any_element.jac");
    # `pair: any = (...); (nm, ty) = pair;` -- an explicit `any` is a ClassType
    # for builtin `Any`, which the old `isinstance(.., types.AnyType)` guard
    # missed, so the unpack was reported as non-iterable.
    joined = " ".join(errs);
    assert "E1020" not in joined , f"explicit `any` reported non-iterable: {errs}";
}

test "unpacking through an any-valued chain binds Any, not Unknown" {
    errs = check_errors("unpack_any_element.jac");
    # `ctx: dict[str, any]` indexed twice yields builtin `Any`; each target
    # must bind `Any` so `takes_type(ty)` stays clean. This is the compiler's
    # own `_gc["slots"][-1]` shape from na_ir_gen_pass closures.
    joined = " ".join(errs);
    assert "E1020" not in joined , f"any-valued chain unpack errored: {errs}";
    assert "E1053" not in joined , f"Unknown leaked out of the chain: {errs}";
}
