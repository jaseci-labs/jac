impl python_source(path: str, program: JacProgram) -> tuple[str, bool] {
    if Path(path).suffix == '.py' {
        return (Path(path).read_text(encoding='utf-8'), False);
    }
    real = os.path.realpath(path);
    options = program.options if program.options is not None else CompileOptions();
    compiled = kernel_compile(program, [real], options, products=["python_ast"]);
    if not compiled.ok() {
        raise RuntimeError(
            '\n'.join([diagnostic_text(error) for error in compiled.errors])
        );
    }
    unit = compiled.unit(real);
    if unit.python_ast is None {
        raise RuntimeError(f'No Python source product for {path}');
    }
    return (ast.unparse(unit.python_ast), bool(unit.native_ir));
}

impl python_text(path: str, program: JacProgram) -> str {
    if Path(path).suffix == '.py' {
        return Path(path).read_text(encoding='utf-8');
    }
    real = os.path.realpath(path);
    cache_path = get_module_cache_path(real);
    if is_module_cache_valid(real, cache_path) {
        cached = read_section_bytes(read_jir(cache_path), SEC_PYSRC);
        if cached is not None {
            return cached.decode('utf-8');
        }
    }
    text = python_source(path, program)[0];
    if is_module_cache_valid(real, get_module_cache_path(real)) {
        write_module_cache(real, None, extra_sections={SEC_PYSRC: text.encode('utf-8')});
    }
    return text;
}
