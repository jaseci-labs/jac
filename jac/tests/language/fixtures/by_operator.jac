"""Test file for by operator."""

with entry {
    # Test 1: Simple by expression
    result = "hello" by "world";
    print("Test 1:", result);

    # Test 2: Chained by expressions
    result2 = "a" by "b" by "c";
    print("Test 2:", result2);

    # Test 3: By with complex expressions
    result3 = (1 + 2) by (3 * 3) by (5 / 2 by 1);
    print("Test 3:", result3);

    # Test 4: By in assignment
    x = "input" by "output";
    print("Test 4:", x);
}
