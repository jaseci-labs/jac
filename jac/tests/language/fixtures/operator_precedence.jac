"""Test that bitwise vs logical operator precedence matches Python.

Runs each expression in Jac and asserts the outputs match what CPython prints
for the same expressions.
"""

with entry {
    jac_results: list[str] = [];

    # Bitwise AND vs comparison: should be (3 & 1) == 1, not 3 & (1 == 1)
    jac_results.append(str(3 & 1 == 1));

    # Bitwise OR vs logical or: should be (3 | 0) or 4, not 3 | (0 or 4)
    jac_results.append(str(3 | 0 or 4));

    # Bitwise XOR vs logical and: should be (3 ^ 1) and 0, not 3 ^ (1 and 0)
    jac_results.append(str(3 ^ 1 and 0));

    # Comparison vs bitwise OR: should be 2 < (3 | 1), not (2 < 3) | 1
    jac_results.append(str(2 < 3 | 1));

    # Mixed: bitwise AND, comparison, logical and
    jac_results.append(str(7 & 3 == 3 and True));

    # Logical not vs bitwise AND: should be not (0 & 1), not (not 0) & 1
    jac_results.append(str(not 0 & 1));

    # Relative bitwise precedence preserved: | < ^ < &
    jac_results.append(str(5 | 3 ^ 1 & 2));

    # Shift vs arithmetic preserved: should be 1 << (2 + 1)
    jac_results.append(str(1 << 2 + 1));

    # Python's results for the same expressions, in order
    py_results: list[str] = ["True", "3", "0", "True", "True", "True", "7", "8"];

    # Compare and report
    for i in range(len(jac_results)) {
        assert jac_results[i] == py_results[i] , (
            f"Mismatch at expression {i}: jac={jac_results[i]} py={py_results[i]}"
        );
    }
    print("PASS");
}
