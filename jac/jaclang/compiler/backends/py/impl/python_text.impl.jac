impl generated_python(module: uni.Module) -> str {
    gen = module.gen;
    if gen.py_text is None {
        if gen.py_recipe is None {
            return "";
        }
        gen.py_text = ast.unparse(kernel_python_ast(module));
    }
    return gen.py_text;
}
