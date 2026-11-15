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
