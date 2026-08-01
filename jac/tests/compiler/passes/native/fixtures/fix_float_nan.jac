"""Fixture for IEEE 754 float != NaN fix test.

Before the fix, float != used fcmp_ordered which returns false when either
operand is NaN — so NaN != NaN evaluated to 0 (false), violating IEEE 754.
After the fix, != uses fcmp_unordered so NaN != NaN correctly returns 1 (true).

NaN is produced via Inf - Inf (since 0.0/0.0 causes SIGABRT in the current
runtime and math.nan resolves to 0.0 due to a separate Jac issue).
"""

def:pub nan_neq_self() -> int {
    # IEEE 754: NaN != NaN must be true (1)
    inf: f64 = 1e308 * 2.0;    # overflow to +Inf
    nan: f64 = inf - inf;      # Inf - Inf = NaN
    if nan != nan {
        return 1;
    }
    return 0;
}

def:pub nan_eq_self() -> int {
    # IEEE 754: NaN == NaN must be false (0)
    inf: f64 = 1e308 * 2.0;
    nan: f64 = inf - inf;
    if nan == nan {
        return 1;
    }
    return 0;
}

def:pub finite_ne_distinct() -> int {
    # Ordered semantics still required: 1.0 != 2.0 must be true (1)
    if 1.0 != 2.0 {
        return 1;
    }
    return 0;
}

def:pub finite_ne_self() -> int {
    # 1.0 != 1.0 must be false (0) — ordered comparison for non-NaN
    if 1.0 != 1.0 {
        return 1;
    }
    return 0;
}

def:pub finite_eq_self() -> int {
    # 3.14 == 3.14 must be true (1)
    if 3.14 == 3.14 {
        return 1;
    }
    return 0;
}

with entry {}
