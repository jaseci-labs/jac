impl host_parsed_module(source: str, path: str) -> ast_nodes.Module {
    try {
        tree = ast.parse(source, filename=path);
    } except SyntaxError as rejected {
        raise syntax_failure(
            msg=str(rejected.msg),
            filename=path,
            lineno=rejected.lineno or 0,
            offset=rejected.offset if rejected.offset is not None else -1,
            text=rejected.text,
            end_lineno=rejected.end_lineno or 0,
            end_offset=rejected.end_offset if rejected.end_offset is not None else -1,
            kind=type(rejected).__name__
        ) from rejected;
    }
    lifted = lifted_node(tree);
    if not isinstance(lifted, ast_nodes.Module) {
        raise RuntimeError(f"{path}: the host parser returned no module");
    }
    return lifted;
}

impl lifted_node(source_node: ast.AST) -> any {
    fields: dict[str, any] = {};
    for name in (*source_node._fields, *source_node._attributes) {
        fields[name] = lifted_value(getattr(source_node, name, None));
    }
    if isinstance(source_node, (ast.Constant, ast.MatchSingleton)) {
        fields["value"] = lifted_constant(source_node.value);
    }
    return getattr(ast_nodes, type(source_node).__name__)(**fields);
}

impl lifted_value(value: any) -> any {
    if isinstance(value, ast.AST) {
        return lifted_node(value);
    }
    if isinstance(value, list) {
        return [lifted_value(item) for item in value];
    }
    return value;
}

impl lifted_constant(value: any) -> PyObj {
    if value is None {
        return py_none();
    }
    if value is Ellipsis {
        return PyEllipsis(t="ellipsis");
    }
    if isinstance(value, bool) {
        return PyBool(t="bool", val=value);
    }
    if isinstance(value, int) {
        magnitude = abs(value);
        digits: list[int] = [];
        while magnitude {
            digits.append(magnitude & 32767);
            magnitude >>= 15;
        }
        return integer_from_digits(digits, value < 0);
    }
    if isinstance(value, float) {
        return PyFloat(t="float", val=value);
    }
    if isinstance(value, complex) {
        return PyComplex(t="complex", real=value.real, imag=value.imag);
    }
    if isinstance(value, str) {
        return PyStr(t="str", val=value);
    }
    if isinstance(value, bytes) {
        return PyBytes(t="bytes", val=list(value));
    }
    raise TypeError(f"the host parser produced a {type(value).__name__} constant");
}
