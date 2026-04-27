def passthrough(value: any) -> any {
    return value;
}

def test_any_annotation_and_builtin_escape() -> str {
    from_any: str = passthrough(1);  # Ok: Jac any accepts and returns any.
    builtin_any: bool = `any([0, 1]);  # Ok: `any is Python's any().
    builtin_any_bad: str = `any([0]);  # Error: Python any() returns bool.
    return from_any;
}
