"""Test print with multiple arguments in native mode."""

def test_multiple_args -> int {
    # Test with multiple integers and strings
    print("Test 1:", 10, 20, 30);
    return 0;
}

def test_mixed_types -> int {
    # Test with mixed types
    print("Value:", 42, "Result:", 3.14);
    return 0;
}

def test_variables -> int {
    # Test with variables
    x = 100;
    y = 200;
    print("x =", x, "y =", y);
    return 0;
}

def test_single_arg -> int {
    # Test backwards compatibility with single arg
    print("Single arg");
    print(999);
    return 0;
}

def test_many_args -> int {
    # Test with many arguments
    print("a", "b", "c", 1, 2, 3);
    return 0;
}

with entry {
    test_multiple_args();
    test_mixed_types();
    test_variables();
    test_single_arg();
    test_many_args();
    print("All print tests passed!");
}
