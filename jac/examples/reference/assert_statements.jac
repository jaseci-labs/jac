# Assert Statements

# Basic assert
with entry {
    assert True;
    print("assertion passed");
}

# Assert with expression
glob x = 10;

with entry {
    assert x > 5;
    print("x > 5");

    # Assert with message
    assert x < 100 , "x must be less than 100";
    print("x < 100");

    # Assert that fails
    try {
        assert False;
    } except AssertionError {
        print("assertion failed");
    }

    # Assert with message that fails
    try {
        assert 1 > 2 , "1 is not greater than 2";
    } except AssertionError as e {
        print(f"assertion failed: {e}");
    }

    # Assert with complex expression
    assert len([1, 2, 3]) == 3;
    print("list length is 3");

    # Assert with comparison
    assert "hello" != "world";
    print("strings are different");

    # Assert with membership
    assert 5 in [1, 2, 3, 4, 5];
    print("5 in list");

    # Assert with identity
    assert None is None;
    print("None is None");
}
