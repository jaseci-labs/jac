"""Regression fixture for jaseci-labs/jaseci#6458.

`isinstance(x, <builtin-type>)` used to crash ES codegen with a bare
`IndexError: list index out of range`.  Root cause: the ES pass had no
`exit_builtin_type` handler, so a builtin-type name (`str`, `int`, `list`,
...) used as a *value* produced no JS AST and was silently dropped from the
enclosing call's argument list.  `emit_isinstance` then received a single
argument and indexed `args[1]` off the end.

This fixture exercises isinstance against builtin types, a user archetype, and
a tuple of types, plus issubclass over builtin-type tags, so codegen must lower
each form to a correct runtime check.
"""

obj Widget {
    has name: str;
}

cl def classify(value: any) -> str {
    # `bool` must be checked before `int` because Python treats bool as a
    # subclass of int (isinstance(True, int) is True).
    if isinstance(value, str) {
        return "str:" + value;
    }
    if isinstance(value, bool) {
        return "bool";
    }
    if isinstance(value, int) {
        return "int";
    }
    if isinstance(value, float) {
        return "float";
    }
    if isinstance(value, list) {
        return "list";
    }
    if isinstance(value, Widget) {
        return "widget:" + value.name;
    }
    return "other";
}

cl def is_scalar(value: any) -> bool {
    # Tuple-of-types form: isinstance(x, (A, B, ...)).
    return isinstance(value, (int, float, str, bool));
}

cl def subclass_probe() -> list[bool] {
    # issubclass over builtin-type tags: bool is a subclass of int (Python
    # semantics), identity holds, and unrelated builtins are not subclasses.
    return [
        issubclass(bool, int),
        issubclass(int, int),
        issubclass(str, int),
        issubclass(int, str)
    ];
}
