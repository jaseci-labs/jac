"""Test for InForStmt iteration variable symbol registration (simple and tuple unpacking)."""

with entry {
    # Test 1: Simple for loop
    for x in [1, 2, 3] {
        print(x);
    }

    # Test 2: Tuple unpacking in for loop
    items = [(1, 2), (3, 4), (5, 6)];
    for (k, v) in items {
        print(k, v);
    }
}
