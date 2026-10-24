glob EPSILON: float = 1e-8;


def near_zero(value: float) -> bool;


def is_finite(x: float) -> bool;


def require_finite(x: float);


enum Relation { LEQ = "leq", EQ = "eq", GEQ = "geq" }


enum StrengthTier {
    REQUIRED = "required",
    STRONG = "strong",
    MEDIUM = "medium",
    WEAK = "weak"
}


obj LexWeight {
    has tiers: list[float] = [0.0, 0.0, 0.0];
}


def lex_zero -> LexWeight;


def lex_add(a: LexWeight, b: LexWeight) -> LexWeight;


def lex_neg(a: LexWeight) -> LexWeight;


def lex_scale(a: LexWeight, factor: float) -> LexWeight;


def lex_compare(a: LexWeight, b: LexWeight) -> int;


def lex_is_zero(a: LexWeight) -> bool;


def lex_is_negative(a: LexWeight) -> bool;


def strength_weight(strength: StrengthTier) -> LexWeight;


obj Variable {
    has id: int;
}


obj Term {
    has variable: Variable,
        coefficient: float;
}


obj Expression {
    has terms: list[Term] = [],
        constant: float = 0.0;
}


obj Constraint {
    has expression: Expression,
        relation: Relation,
        strength: StrengthTier;
}


def normalize_expression(e: Expression) -> Expression;


def term(v: Variable, coefficient: float = 1.0) -> Expression;


def add_expressions(a: Expression, b: Expression) -> Expression;


def constraint_key(c: Constraint) -> str;


def eq(expr: Expression) -> Constraint;

impl near_zero(value: float) -> bool {
    return abs(value) < EPSILON;
}


impl is_finite(x: float) -> bool {
    return x == x and x < 1e308 and x > -1e308;
}


impl require_finite(x: float) {
    if not is_finite(x) {
        raise ValueError("non-finite value rejected at constraint interface");
    }
}


impl lex_zero -> LexWeight {
    return LexWeight(tiers=[0.0, 0.0, 0.0]);
}


impl lex_add(a: LexWeight, b: LexWeight) -> LexWeight {
    return LexWeight(
        tiers=[
            a.tiers[0] + b.tiers[0],
            a.tiers[1] + b.tiers[1],
            a.tiers[2] + b.tiers[2],

        ]
    );
}


impl lex_neg(a: LexWeight) -> LexWeight {
    return LexWeight(tiers=[-a.tiers[0], -a.tiers[1], -a.tiers[2]]);
}


impl lex_scale(a: LexWeight, factor: float) -> LexWeight {
    require_finite(factor);
    return LexWeight(
        tiers=[a.tiers[0] * factor, a.tiers[1] * factor, a.tiers[2] * factor, ]
    );
}


impl lex_compare(a: LexWeight, b: LexWeight) -> int {
    for i in range(3) {
        delta = a.tiers[i] - b.tiers[i];
        if not near_zero(delta) {
            return -1 if delta < 0.0 else 1;
        }
    }
    return 0;
}


impl lex_is_zero(a: LexWeight) -> bool {
    return lex_compare(a, lex_zero()) == 0;
}


impl lex_is_negative(a: LexWeight) -> bool {
    return lex_compare(a, lex_zero()) < 0;
}


impl strength_weight(strength: StrengthTier) -> LexWeight {
    if strength == StrengthTier.STRONG {
        return LexWeight(tiers=[1.0, 0.0, 0.0]);
    }
    if strength == StrengthTier.MEDIUM {
        return LexWeight(tiers=[0.0, 1.0, 0.0]);
    }
    if strength == StrengthTier.WEAK {
        return LexWeight(tiers=[0.0, 0.0, 1.0]);
    }
    return lex_zero();
}


impl normalize_expression(e: Expression) -> Expression {
    require_finite(e.constant);
    merged: dict[int, float] = {};
    for t in e.terms {
        require_finite(t.coefficient);
        vid = t.variable.id;
        merged[vid] = merged.get(vid, 0.0) + t.coefficient;

        require_finite(merged[vid]);
    }
    terms: list[Term] = [];
    for vid in sorted(merged.keys()) {
        c = merged[vid];
        if not near_zero(c) {
            terms.append(Term(variable=Variable(id=vid), coefficient=c));
        }
    }
    return Expression(terms=terms, constant=e.constant);
}


impl term(v: Variable, coefficient: float = 1.0) -> Expression {
    return Expression(terms=[Term(variable=v, coefficient=coefficient)]);
}


impl add_expressions(a: Expression, b: Expression) -> Expression {
    return normalize_expression(
        Expression(terms=a.terms + b.terms, constant=a.constant + b.constant,)
    );
}


impl constraint_key(c: Constraint) -> str {
    e = normalize_expression(c.expression);
    parts: list[str] = [];
    parts.append(c.relation.value);
    parts.append(c.strength.value);
    for t in e.terms {
        parts.append(str(t.variable.id) + ":" + repr(t.coefficient));
    }
    parts.append("|" + repr(e.constant));
    return ";".join(parts);
}


impl eq(expr: Expression) -> Constraint {
    return Constraint(
        expression=normalize_expression(expr),
        relation=Relation.EQ,
        strength=StrengthTier.REQUIRED,
    );
}
