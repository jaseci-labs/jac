"""Test for walrus operator type narrowing.

Bug: Inside `if (x := get_optional()):`, x should be narrowed to non-None type.
"""

def get_optional -> str | None {
    return "hello";
}

def test_walrus_narrowing -> str {
    # greeting is str | None from walrus
    # but inside if block, truthiness check should narrow to str
    if (greeting := get_optional()) {
        return greeting;  # Should be str, not str | None

    }
    return "default";
}
