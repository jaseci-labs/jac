import from jaclang.osprey.constraints.algebra { constraint_key }


def _coefficients(c: Constraint) -> dict[int, float];


def _assert_coefficients(c: Constraint, expected: dict[int, float]);


def _assert_single(
    constraints: list[Constraint],
    expected: dict[int, float],
    constant: float,
    relation: Relation,
    strength: StrengthTier,
);


test "node_vars uses four deterministic geometry variables" {
    vars_a: dict[str, Variable] = node_vars(10);
    assert vars_a["left"].id == 10;
    assert vars_a["top"].id == 11;
    assert vars_a["width"].id == 12;
    assert vars_a["height"].id == 13;
    vars_b: dict[str, Variable] = node_vars(10);
    assert vars_b["top"].id == vars_a["top"].id;
    assert vars_b["width"].id == vars_a["width"].id;
    assert vars_b["height"].id == vars_a["height"].id;
}


test "directional relations encode affine geometry and gap" {
    a: dict[str, Variable] = node_vars(10);
    b: dict[str, Variable] = node_vars(20);

    _assert_single(
        above(a, b, 2.0),
        {11: 1.0, 13: 1.0, 21: -1.0},
        2.0,
        Relation.EQ,
        StrengthTier.REQUIRED,
    );
    _assert_single(
        below(a, b, 2.0),
        {11: 1.0, 21: -1.0, 23: -1.0},
        -2.0,
        Relation.EQ,
        StrengthTier.REQUIRED,
    );
    _assert_single(
        left_of(a, b, 3.0),
        {10: 1.0, 12: 1.0, 20: -1.0},
        3.0,
        Relation.EQ,
        StrengthTier.REQUIRED,
    );
    _assert_single(
        right_of(a, b, 3.0),
        {10: 1.0, 20: -1.0, 22: -1.0},
        -3.0,
        Relation.EQ,
        StrengthTier.REQUIRED,
    );
}


test "alignment and size relations use strong defaults" {
    a: dict[str, Variable] = node_vars(10);
    b: dict[str, Variable] = node_vars(20);
    _assert_single(
        align_left(a, b), {10: 1.0, 20: -1.0}, 0.0, Relation.EQ, StrengthTier.STRONG
    );
    _assert_single(
        align_right(a, b),
        {10: 1.0, 12: 1.0, 20: -1.0, 22: -1.0},
        0.0,
        Relation.EQ,
        StrengthTier.STRONG
    );
    _assert_single(
        align_top(a, b), {11: 1.0, 21: -1.0}, 0.0, Relation.EQ, StrengthTier.STRONG
    );
    _assert_single(
        align_bottom(a, b),
        {11: 1.0, 13: 1.0, 21: -1.0, 23: -1.0},
        0.0,
        Relation.EQ,
        StrengthTier.STRONG
    );
    _assert_single(
        center_x(a, b),
        {10: 1.0, 12: 0.5, 20: -1.0, 22: -0.5},
        0.0,
        Relation.EQ,
        StrengthTier.STRONG
    );
    _assert_single(
        center_y(a, b),
        {11: 1.0, 13: 0.5, 21: -1.0, 23: -0.5},
        0.0,
        Relation.EQ,
        StrengthTier.STRONG
    );
    _assert_single(
        same_width(a, b), {12: 1.0, 22: -1.0}, 0.0, Relation.EQ, StrengthTier.STRONG
    );
    _assert_single(
        same_height(a, b), {13: 1.0, 23: -1.0}, 0.0, Relation.EQ, StrengthTier.STRONG
    );

    assert len(fill_width(a, b)) == 2;
    assert len(fill_height(a, b)) == 2;
    combined: list[Constraint] = fill_width(a, b) + fill_height(a, b);
    for c in combined {
        assert c.strength == StrengthTier.STRONG;
    }
}


test "size defaults expose required bounds and weak preferences" {
    a: dict[str, Variable] = node_vars(10);
    _assert_single(
        width_nonnegative(a), {12: 1.0}, 0.0, Relation.GEQ, StrengthTier.REQUIRED
    );
    _assert_single(
        height_nonnegative(a), {13: 1.0}, 0.0, Relation.GEQ, StrengthTier.REQUIRED
    );
    _assert_single(
        preferred_width(a, 40.0), {12: 1.0}, -40.0, Relation.EQ, StrengthTier.WEAK
    );
    _assert_single(
        preferred_height(a, 5.0), {13: 1.0}, -5.0, Relation.EQ, StrengthTier.WEAK
    );
}


test "raw affine escape hatch normalizes duplicate variables" {
    x: Variable = Variable(id=7);
    c: Constraint = affine_constraint(
        Expression(
            terms=[
                Term(variable=x, coefficient=1.0),
                Term(variable=Variable(id=7), coefficient=2.0),

            ],
            constant=-9.0,
        )
    );
    _assert_single([c], {7: 3.0}, -9.0, Relation.EQ, StrengthTier.REQUIRED);
    assert constraint_key(c)
        == constraint_key(
            affine_constraint(
                Expression(terms=[Term(variable=x, coefficient=3.0)], constant=-9.0)
            )
        );
}


test "vertical_flow is transparent and stacks with gap" {
    parent: dict[str, Variable] = node_vars(100);
    first: dict[str, Variable] = node_vars(200);
    second: dict[str, Variable] = node_vars(300);
    third: dict[str, Variable] = node_vars(400);
    children: list[dict[str, Variable]] = [first, second, third];

    expanded: list[Constraint] = vertical_flow(parent, children, 2.0);
    assert len(expanded) == 3;
    assert constraint_key(expanded[0])
        == constraint_key(align_top(first, parent, StrengthTier.REQUIRED)[0]);
    assert constraint_key(expanded[1]) == constraint_key(above(first, second, 2.0)[0]);
    assert constraint_key(expanded[2]) == constraint_key(above(second, third, 2.0)[0]);
    assert expanded[1].expression.constant == 2.0;
    assert expanded[2].expression.constant == 2.0;

    filled: list[Constraint] = vertical_flow(parent, children, 2.0, True);
    assert len(filled) == 9;
    for i in range(3) {
        assert filled[3 + i * 2].strength == StrengthTier.STRONG;
        assert filled[4 + i * 2].strength == StrengthTier.STRONG;
    }
    assert vertical_flow(parent, [], 2.0) == [];
}


test "horizontal_flow and aliases preserve transparent expansion" {
    parent: dict[str, Variable] = node_vars(100);
    first: dict[str, Variable] = node_vars(200);
    second: dict[str, Variable] = node_vars(300);
    children: list[dict[str, Variable]] = [first, second];

    expanded: list[Constraint] = horizontal_flow(parent, children, 4.0, True);
    assert len(expanded) == 6;
    assert constraint_key(expanded[0])
        == constraint_key(align_left(first, parent, StrengthTier.REQUIRED)[0]);
    assert constraint_key(expanded[1])
        == constraint_key(left_of(first, second, 4.0)[0]);
    assert constraint_key(expanded[2]) == constraint_key(fill_height(first, parent)[0]);
    assert constraint_key(expanded[5])
        == constraint_key(fill_height(second, parent)[1]);
    column_result: list[Constraint] = column(parent, children, 1.0);
    vertical_result: list[Constraint] = vertical_flow(parent, children, 1.0);
    assert len(column_result) == len(vertical_result);
    for i in range(len(column_result)) {
        assert constraint_key(column_result[i]) == constraint_key(vertical_result[i]);
    }
    row_result: list[Constraint] = row(parent, children, 1.0);
    horizontal_result: list[Constraint] = horizontal_flow(parent, children, 1.0);
    assert len(row_result) == len(horizontal_result);
    for i in range(len(row_result)) {
        assert constraint_key(row_result[i]) == constraint_key(horizontal_result[i]);
    }
}

impl _coefficients(c: Constraint) -> dict[int, float] {
    result: dict[int, float] = {};
    for t in c.expression.terms {
        result[t.variable.id] = t.coefficient;
    }
    return result;
}


impl _assert_coefficients(c: Constraint, expected: dict[int, float]) {
    assert _coefficients(c) == expected;
}


impl _assert_single(
    constraints: list[Constraint],
    expected: dict[int, float],
    constant: float,
    relation: Relation,
    strength: StrengthTier,
) {
    assert len(constraints) == 1;
    c: Constraint = constraints[0];
    _assert_coefficients(c, expected);
    assert c.expression.constant == constant;
    assert c.relation == relation;
    assert c.strength == strength;
}
