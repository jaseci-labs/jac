"""Test type narrowing for boolean combinations.

Tests:
- and combinations
- or combinations
- not operator
- nested boolean expressions
- De Morgan's law patterns
"""

obj ClassA {
    def x {
        return;
    }
}


"""Test 1: Basic and narrowing - both must be truthy"""
def test_and_basic(a: ClassA | None, b: ClassA | None) {
    if a and b {
        # Both a and b should be narrowed to ClassA (non-None)
        val_a: ClassA = a;
        val_b: ClassA = b;
        a.x();
        b.x();
    }
}


"""Test 2: Basic or narrowing - at least one truthy
TODO: OR else branch narrowing requires tracking multiple symbols.
When `a or b` is false, BOTH must be falsy. Not yet implemented.
"""
def test_or_else(a: ClassA | None, b: ClassA | None) {
    if a or b {
        # In the if branch, at least one is truthy
        # Cannot narrow either to non-None specifically
        y: int = 1;
    } else {
        # Both must be None/falsy - requires advanced OR narrowing
        # none_a: None = a;  # TODO: needs OR false branch support
        # none_b: None = b;  # TODO: needs OR false branch support
        y: int = 2;
    }
}


"""Test 3: not with and - De Morgan
TODO: De Morgan patterns (not a or not b) else narrowing.
When `not a or not b` is false, equivalent to `a and b` being true.
"""
def test_not_or(a: ClassA | None, b: ClassA | None) {
    if not a or not b {
        # At least one is None/falsy
        y: int = 1;
    } else {
        # Both must be truthy - requires De Morgan support
        # val_a: ClassA = a;  # TODO: needs De Morgan support
        # val_b: ClassA = b;  # TODO: needs De Morgan support
        # a.x();
        # b.x();
        y: int = 2;
    }
}


"""Test 4: not with and - De Morgan inverse
TODO: `not a and not b` true branch needs special handling.
"""
def test_not_and(a: ClassA | None, b: ClassA | None) {
    if not a and not b {
        # Both are None/falsy - needs special NOT truthiness handling
        # none_a: None = a;  # TODO: needs not-truthiness support
        # none_b: None = b;  # TODO: needs not-truthiness support
        y: int = 1;
    } else {
        # At least one is truthy
        y: int = 2;
    }
}


"""Test 5: Double negation
TODO: Double negation like `not (not a or not b)` equivalent to `a and b`.
"""
def test_double_negation(a: ClassA | None, b: ClassA | None) {
    if not (not a or not b) {
        # Equivalent to: a and b - needs De Morgan normalization
        # val_a: ClassA = a;  # TODO: needs De Morgan normalization
        # val_b: ClassA = b;  # TODO: needs De Morgan normalization
        # a.x();
        # b.x();
        y: int = 1;
    }
}


"""Test 6: Double negation inverse
TODO: `not (not a and not b)` equivalent to `a or b`.
"""
def test_double_negation_inverse(a: ClassA | None, b: ClassA | None) {
    if not (not a and not b) {
        # Equivalent to: a or b
        y: int = 1;
    } else {
        # Both must be None - needs De Morgan support
        # none_a: None = a;  # TODO: needs De Morgan support
        # none_b: None = b;  # TODO: needs De Morgan support
        y: int = 2;
    }
}


"""Test 7: Chained and with isinstance"""
def test_and_isinstance(x: int | str | None) {
    if x is not None and isinstance(x, int) {
        # x should be int
        int_val: int = x;
    }
}


"""Test 8: Complex or with isinstance"""
def test_or_isinstance(x: int | str | float) {
    if isinstance(x, int) or isinstance(x, str) {
        # x should be int | str
        y: int = 1;
    } else {
        # x should be float
        float_val: float = x;
    }
}


"""Test 9: Truthiness narrowing"""
def test_truthiness(x: str | None) {
    if x {
        # x should be str (not None)
        str_val: str = x;
        upper: str = x.upper();
    }
}


"""Test 10: and short-circuit in expression"""
def test_and_expression(a: str | None) -> str | None | bool {
    # If a is falsy, returns falsy a (None); otherwise evaluates 'a in []' (bool)
    # So result type is: str | None | bool (short-circuit semantics)
    result: str | None | bool = a and (a in []);
    return result;
}
