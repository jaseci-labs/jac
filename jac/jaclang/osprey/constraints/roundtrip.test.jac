import from jaclang.osprey.constraints.algebra {
    Constraint,
    Expression,
    StrengthTier,
    Term,
    Variable,
}
import from jaclang.osprey.constraints.results { SolveError, }
import from jaclang.osprey.constraints.solver { Solver, }
import from jaclang.osprey.constraints.layout_relations {
    affine_constraint,
    align_bottom,
    height_nonnegative,
    node_vars,
    preferred_height,
    vertical_flow,
    width_nonnegative,
}


glob TOL: float = 1e-6;


def _pin_zero(v: Variable) -> Constraint;


def _assert_near(actual: float, expected: float);


def _value(s: Solver, v: Variable) -> float;


def _add_all(s: Solver, cs: list[Constraint], tag: str);


test "vertical_flow solves end-to-end with framework default strengths" {
    s = Solver();
    parent = node_vars(100);
    first = node_vars(200);
    second = node_vars(300);

    for n in [parent, first, second] {
        _add_all(s, width_nonnegative(n), "invariant");
        _add_all(s, height_nonnegative(n), "invariant");
    }
    _add_all(s, preferred_height(first, 3.0), "intrinsic");
    _add_all(s, preferred_height(second, 4.0), "intrinsic");

    _add_all(s, [_pin_zero(parent["left"]), _pin_zero(parent["top"])], "viewport");
    _add_all(
        s,
        [
            affine_constraint(
                Expression(
                    terms=[Term(variable=parent["width"], coefficient=1.0)],
                    constant=-40.0,
                )
            )
        ],
        "viewport"
    );
    _add_all(s, vertical_flow(parent, [first, second], 2.0, True), "flow",);

    _assert_near(_value(s, first["top"]), 0.0);
    _assert_near(_value(s, first["height"]), 3.0);

    _assert_near(_value(s, second["top"]), 5.0);
    _assert_near(_value(s, second["height"]), 4.0);

    _assert_near(_value(s, first["left"]), 0.0);
    _assert_near(_value(s, first["width"]), 40.0);
    _assert_near(_value(s, second["left"]), 0.0);
    _assert_near(_value(s, second["width"]), 40.0);
}


test "weak size preferences yield to a required container bound" {
    s = Solver();
    parent = node_vars(100);
    first = node_vars(200);
    second = node_vars(300);

    for n in [first, second] {
        _add_all(s, height_nonnegative(n), "invariant");
    }
    _add_all(s, preferred_height(first, 3.0), "intrinsic");
    _add_all(s, preferred_height(second, 4.0), "intrinsic");

    _add_all(s, [_pin_zero(parent["top"])], "viewport");
    _add_all(
        s,
        [
            affine_constraint(
                Expression(
                    terms=[Term(variable=parent["height"], coefficient=1.0)],
                    constant=-6.0,
                )
            )
        ],
        "viewport"
    );
    _add_all(s, vertical_flow(parent, [first, second], 2.0), "flow");
    _add_all(s, align_bottom(second, parent, StrengthTier.REQUIRED), "flow");

    h1 = _value(s, first["height"]);
    h2 = _value(s, second["height"]);
    _assert_near(h1 + h2, 4.0);
    assert h1 >= 0.0 and h2 >= 0.0;
    assert abs(h1 - 3.0) > TOL or abs(h2 - 4.0) > TOL;

    _assert_near(_value(s, first["top"]), 0.0);
    _assert_near(_value(s, second["top"]), h1 + 2.0);
}


test "re-expanded flow patterns dedupe by content hash" {
    s = Solver();
    parent = node_vars(100);
    child = node_vars(200);

    expanded = vertical_flow(parent, [child], 1.0, True);
    first_add = s.add_constraint(expanded[0], "flow");
    assert first_add.ok;

    second_add = s.add_constraint(vertical_flow(parent, [child], 1.0, True)[0], "flow");
    assert not second_add.ok;
    assert second_add.error == SolveError.DUPLICATE_CONSTRAINT;
    assert second_add.witness_provenance == ["flow"];

    _add_all(s, [_pin_zero(child["top"])], "pin");
    _assert_near(_value(s, child["top"]), 0.0);
}

impl _pin_zero(v: Variable) -> Constraint {
    return affine_constraint(
        Expression(terms=[Term(variable=v, coefficient=1.0)], constant=0.0)
    );
}


impl _assert_near(actual: float, expected: float) {
    assert abs(actual - expected) < TOL;
}


impl _value(s: Solver, v: Variable) -> float {
    snap = s.snapshot();
    return snap.values[v.id];
}


impl _add_all(s: Solver, cs: list[Constraint], tag: str) {
    for c in cs {
        r = s.add_constraint(c, tag);
        assert r.ok;
    }
}
