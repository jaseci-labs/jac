# Python source/AST -> PyCode through CPython's pipeline: parse, then
# _PyAST_Compile (future, preprocess, symtable, codegen, flowgraph, assemble).

def compile_source(
    source: str, filename: str, mode: str, optimize: int, flags: int = 0
) -> PyObj {
    if optimize not in (0, 1, 2) {
        return py_error("ValueError", "compile(): invalid optimize value");
    }
    tree: mod | None = None;
    if mode == "exec" {
        tree = parse_file(source, filename, flags);
    } elif mode == "eval" {
        e = parse_eval_expr(source, filename, flags);
        if e is not None {
            tree = Expression(body=e);
        }
    } elif mode == "single" {
        tree = parse_interactive(source, filename, flags);
    } else {
        return py_error(
            "ValueError", "compile() mode must be 'exec', 'eval' or 'single'"
        );
    }
    if tree is None {
        return py_error("SyntaxError", "invalid syntax");
    }
    try {
        return cpy_ast_compile(tree, filename, flags, optimize);
    } except syntax_failure as error {
        if error.text is not None {
            raise error;
        }
        lines = split_source_lines(source);
        line = error.lineno;
        text = lines[line - 1] if line > 0 and line <= len(lines) else None;
        raise syntax_failure(
            error.msg,
            filename=error.filename if error.filename != "<unknown>" else filename,
            lineno=error.lineno,
            offset=error.offset,
            text=text,
            end_lineno=error.end_lineno,
            end_offset=error.end_offset,
            kind=error.kind
        );
    }
}

def compile_ast(
    tree: mod, filename: str, mode: str, optimize: int = 0, flags: int = 0
) -> PyObj {
    if optimize not in (0, 1, 2) {
        return py_error("ValueError", "compile(): invalid optimize value");
    }
    if (mode == "eval" and isinstance(tree, Expression))
        or (mode == "exec" and isinstance(tree, Module))
        or (mode == "single" and isinstance(tree, Interactive)) {
        return cpy_ast_compile(tree, filename, flags, optimize);
    }
    return py_error("TypeError", "AST root does not match compilation mode");
}

def prepare_ast_output(
    tree: mod, filename: str, optimize: int, flags: int
) -> mod | PyObj {
    flags |= cpy_future_from_ast(tree, filename);
    return preprocess_node(tree, optimize, flags, bool(flags & 0x8000)) as mod;
}
