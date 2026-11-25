impl generated_python(gen: CodeGenTarget) -> str {
    if gen.py_text is None {
        if not gen.py_ast {
            return "";
        }
        gen.py_text = ast.unparse(gen.py_ast[0]);
    }
    return gen.py_text;
}
