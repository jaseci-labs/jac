"""Test: errors in impl files should be reported."""
obj Person {
    has name: str;

    def bad_names(x: Person);
    def unreachable_code -> None;
}
