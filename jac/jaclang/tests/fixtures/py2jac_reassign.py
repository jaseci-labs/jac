"""Test variable reassignment in loops - catches py2jac let shadowing bug."""


def test_reassign_in_loop():
    """Variable reassigned in loop should modify outer scope."""
    found = False
    items = [1, 2, 3, 4, 5]
    for item in items:
        if item == 3:
            found = True
    return found


def test_reassign_in_conditional():
    """Variable reassigned in conditional should modify outer scope."""
    status = "initial"
    value = 10
    if value > 5:
        status = "high"
    else:
        status = "low"
    return status


def test_multiple_reassign():
    """Multiple variables reassigned in nested structures."""
    count = 0
    total = 0
    items = [1, 2, 3]
    for item in items:
        count = count + 1
        if item > 1:
            total = total + item
    return (count, total)


# Run tests at module level (not in __main__ block) so they execute on import
assert test_reassign_in_loop() == True, "Loop reassignment failed"
assert test_reassign_in_conditional() == "high", "Conditional reassignment failed"
assert test_multiple_reassign() == (3, 5), "Multiple reassignment failed"
print("All tests passed!")
