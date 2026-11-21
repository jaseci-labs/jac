"""Compile-time rejection for invalid `**=` assignments.

When the power result type does not fit the LHS storage type, the type
checker must emit E1001 (not silently allow truncation at codegen).
"""

def neg_literal_aug {
    x: int = 4;
    x **= -2;  # float result cannot assign to int
}

def dyn_neg_aug {
    x: int = 4;
    b: int = -2;
    x **= b;  # dynamic negative exponent -> float result
}
