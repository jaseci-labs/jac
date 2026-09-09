"""Unpacking an `Any` element binds `Any`, not `Unknown`.

PEP 484 treats a bare `tuple` as `tuple[Any, ...]` and a bare `list` as
`list[Any]`, so iterating one yields `Any` -- and unpacking `Any` binds
`Any` to every target. Jac agreed on the first half but not the second:
`_extract_tuple_element_type` returned None for anything that was not a
`ClassType`, `Any` included, so each destructured target fell through to
`Unknown`. Because `Unknown` is not assignable, every *use* of such a
target then errored.

    glob BARE: tuple = (("a", int),);
    for (nm, ty) in BARE {          # nm and ty were both Unknown
        out += nm + takes_type(ty); # E1055 on nm, E1053 on ty
    }

The tell was that the non-destructured form had always been fine --
`for ty in BARE { takes_type(ty) }` binds `Any` and checks clean. Only the
unpacking step dropped it, which is why this surfaced the moment a constant
table in `placement.jac` grew from a tuple of classes to a tuple of
(name, class) pairs.

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
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "fixtures");

"""Type-check a fixture and return its errors, each prefixed by its code."""
def check_errors(fixture: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=CompileOptions(no_cgen=True)
    );
    return [
        f"{e.code.code if e.code else '----'}: {e}" for e in (prog.errors_had or [])
    ];
}

test "unpacking elements of a bare tuple or list type-checks clean" {
    errs = check_errors("unpack_any_element.jac");
    assert not errs , f"expected no type errors, got {errs}";
}

test "a destructured Any target is usable where its type is constrained" {
    errs = check_errors("unpack_any_element.jac");
    # `takes_type(ty)` constrains a destructured target to `type`, and
    # `nm + ...` constrains the other to `str`. Both were E1053/E1055 before.
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

test "unpacking through a bare-generic chain binds Any, not Unknown" {
    errs = check_errors("unpack_any_element.jac");
    # `ctx: dict` indexed twice yields builtin `Any`; each destructured target
    # must bind `Any` so `takes_type(ty)` stays clean. This is the compiler's
    # own `_gc["slots"][-1]` shape from na_ir_gen_pass closures.
    joined = " ".join(errs);
    assert "E1020" not in joined , f"bare-generic chain unpack errored: {errs}";
    assert "E1053" not in joined , f"Unknown leaked out of the chain: {errs}";
}

test "destructuring over an explicitly `any` iterable binds `any`, not Unknown" {
    # #8982 item 11: `for (k, v) in cfg.apps.items()` with `cfg: any` bound
    # Unknown to both targets, so `v.kind` was E1032 while `a: any = cfg.apps;
    # a.kind` on the same value was accepted. `_get_iterable_element_type`
    # knew `types.AnyType` and `UnknownType` but not the explicit spelling.
    errs = check_errors("unpack_any_element.jac");
    joined = " ".join(errs);
    assert "E1032" not in joined , f"Unknown leaked out of an `any` iterable: {errs}";
}
