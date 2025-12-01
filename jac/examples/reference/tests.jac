# Tests - Unit testing with test blocks

# Named test with assertion
test test1 {
    assert almostEqual(4.99999, 4.99999);
}

# Another test
test test2 {
    assert 5 == 5;
}

# Test with membership check
test test3 {
    assert "e" in "qwerty";
}

with entry:__main__ {
    # Run tests using jac test command
    import subprocess;
    result = subprocess.run(
        ["jac", "test", f"{__file__}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    );
    print(result.stderr);
}
