impl generated_python(module: uni.Module) -> str {
    if module.gen.py_recipe is None {
        return "";
    }
    return active_engine().python_source(module);
}
