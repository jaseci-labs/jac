"""Gap #41: AssertStmt condition and message not type-checked.

No exit_assert_stmt handler exists. The condition expression and
error_msg expression are never type-evaluated, so type errors in
assert statements are silently missed.

Expected errors:
  1. Wrong argument type in condition function call
  2. Wrong argument type in error message function call
  3. Calling nonexistent method in condition
  4. Both condition and message have errors (2 errors)
  5. Type error in binary expression within condition
"""

def check_positive(x: int) -> bool {
    return x > 0;
}

def format_msg(code: int) -> str {
    return f"Error code: {code}";
}

obj Validator {
    has threshold: int = 0;

    def validate(value: int) -> bool {
        return value > self.threshold;
    }
}

with entry {
    v = Validator(threshold=10);

    # Case 1: Wrong argument type in condition
    assert check_positive("not_a_number");          # Error: str -> int param

    # Case 2: Wrong argument type in error message expression
    assert True, format_msg("not_an_int");           # Error: str -> int param

    # Case 3: Calling nonexistent method in condition
    assert v.nonexistent();                          # Error: no such method

    # Case 4: Both condition and message have errors
    assert check_positive("bad"), format_msg("also_bad");  # Error x2

    # Case 5: Type error in binary expression within condition
    x: str = "hello";
    assert x > 5;                                    # Error: str > int

    # --- Cases that SHOULD be valid ---
    assert check_positive(42);                       # Ok
    assert True, "simple message";                   # Ok
    assert v.validate(20), format_msg(404);          # Ok
    assert len([1, 2, 3]) > 0;                       # Ok
}
