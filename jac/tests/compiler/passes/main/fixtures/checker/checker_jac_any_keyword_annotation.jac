def passthrough(value: any) -> any {
    return value;
}

def test_any_annotation_and_builtin_escape() -> str {
    # Inferred destination is the strict-Any escape valve: `from_any`
    # gets type `any` and stays permissive for downstream use.
    from_any = passthrough("hi");
    print(from_any);
    builtin_any: bool = `any([0, 1]);  # Ok: `any is Python's any().
    builtin_any_bad: str = `any([0]);  # Error: Python any() returns bool.
    return "hello";
}
