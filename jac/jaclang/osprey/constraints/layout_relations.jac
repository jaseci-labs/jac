def node_vars(base_id: int) -> dict[str, Variable];


def _term(v: Variable, coefficient: float = 1.0) -> Term;


def _constraint(
    terms: list[Term],
    constant: float = 0.0,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint;


def affine_constraint(
    expression: Expression,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint;


def above(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def below(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def left_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def right_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def align_left(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_right(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_top(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_bottom(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def fill_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def fill_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def same_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def same_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def width_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def height_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint];


def preferred_width(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint];


def preferred_height(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint];


def vertical_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def horizontal_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def column(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def row(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint];


def align_center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];


def align_center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint];

impl node_vars(base_id: int) -> dict[str, Variable] {
    return {
        "left": Variable(id=base_id),
        "top": Variable(id=base_id + 1),
        "width": Variable(id=base_id + 2),
        "height": Variable(id=base_id + 3),

    };
}


impl _term(v: Variable, coefficient: float = 1.0) -> Term {
    return Term(variable=v, coefficient=coefficient);
}


impl _constraint(
    terms: list[Term],
    constant: float = 0.0,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint {
    return Constraint(
        expression=normalize_expression(Expression(terms=terms, constant=constant)),
        relation=relation,
        strength=strength,
    );
}


impl affine_constraint(
    expression: Expression,
    relation: Relation = Relation.EQ,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> Constraint {
    return Constraint(
        expression=normalize_expression(expression),
        relation=relation,
        strength=strength,
    );
}


impl above(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["top"]),
                _term(source["height"]),
                _term(target["top"], -1.0),

            ],
            constant=gap,
            strength=strength
        )
    ];
}


impl below(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["top"]),
                _term(target["top"], -1.0),
                _term(target["height"], -1.0),

            ],
            constant=-gap,
            strength=strength
        )
    ];
}


impl left_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["left"]),
                _term(source["width"]),
                _term(target["left"], -1.0),

            ],
            constant=gap,
            strength=strength
        )
    ];
}


impl right_of(
    source: dict[str, Variable],
    target: dict[str, Variable],
    gap: float = 0.0,
    strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["left"]),
                _term(target["left"], -1.0),
                _term(target["width"], -1.0),

            ],
            constant=-gap,
            strength=strength
        )
    ];
}


impl align_left(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(source["left"]), _term(target["left"], -1.0), ], strength=strength
        )
    ];
}


impl align_right(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["left"]),
                _term(source["width"]),
                _term(target["left"], -1.0),
                _term(target["width"], -1.0),

            ],
            strength=strength
        )
    ];
}


impl align_top(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(source["top"]), _term(target["top"], -1.0), ], strength=strength
        )
    ];
}


impl align_bottom(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["top"]),
                _term(source["height"]),
                _term(target["top"], -1.0),
                _term(target["height"], -1.0),

            ],
            strength=strength
        )
    ];
}


impl center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["left"]),
                _term(source["width"], 0.5),
                _term(target["left"], -1.0),
                _term(target["width"], -0.5),

            ],
            strength=strength
        )
    ];
}


impl center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [
                _term(source["top"]),
                _term(source["height"], 0.5),
                _term(target["top"], -1.0),
                _term(target["height"], -0.5),

            ],
            strength=strength
        )
    ];
}


impl fill_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    result: list[Constraint] = [];
    result.extend(align_left(source, target, strength));
    result.extend(align_right(source, target, strength));
    return result;
}


impl fill_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    result: list[Constraint] = [];
    result.extend(align_top(source, target, strength));
    result.extend(align_bottom(source, target, strength));
    return result;
}


impl same_width(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(source["width"]), _term(target["width"], -1.0), ], strength=strength
        )
    ];
}


impl same_height(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(source["height"]), _term(target["height"], -1.0), ],
            strength=strength
        )
    ];
}


impl width_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(layout_node["width"])], relation=Relation.GEQ, strength=strength,
        )
    ];
}


impl height_nonnegative(
    layout_node: dict[str, Variable], strength: StrengthTier = StrengthTier.REQUIRED,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(layout_node["height"])], relation=Relation.GEQ, strength=strength,
        )
    ];
}


impl preferred_width(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(layout_node["width"])], constant=-preferred, strength=strength,
        )
    ];
}


impl preferred_height(
    layout_node: dict[str, Variable],
    preferred: float,
    strength: StrengthTier = StrengthTier.WEAK,
) -> list[Constraint] {
    return [
        _constraint(
            [_term(layout_node["height"])], constant=-preferred, strength=strength,
        )
    ];
}


impl vertical_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint] {
    result: list[Constraint] = [];
    if len(children) == 0 {
        return result;
    }
    result.extend(align_top(children[0], parent, StrengthTier.REQUIRED));
    for i in range(1, len(children)) {
        result.extend(above(children[i - 1], children[i], gap));
    }
    if fill {
        for child in children {
            result.extend(fill_width(child, parent));
        }
    }
    return result;
}


impl horizontal_flow(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint] {
    result: list[Constraint] = [];
    if len(children) == 0 {
        return result;
    }
    result.extend(align_left(children[0], parent, StrengthTier.REQUIRED));
    for i in range(1, len(children)) {
        result.extend(left_of(children[i - 1], children[i], gap));
    }
    if fill {
        for child in children {
            result.extend(fill_height(child, parent));
        }
    }
    return result;
}


impl column(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint] {
    return vertical_flow(parent, children, gap, fill);
}


impl row(
    parent: dict[str, Variable],
    children: list[dict[str, Variable]],
    gap: float = 0.0,
    fill: bool = False,
) -> list[Constraint] {
    return horizontal_flow(parent, children, gap, fill);
}


impl align_center_x(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return center_x(source, target, strength);
}


impl align_center_y(
    source: dict[str, Variable],
    target: dict[str, Variable],
    strength: StrengthTier = StrengthTier.STRONG,
) -> list[Constraint] {
    return center_y(source, target, strength);
}
