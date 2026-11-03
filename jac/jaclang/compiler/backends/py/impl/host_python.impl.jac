impl host_python_ast(module: uni.Module) -> ast.Module {
    recipe = module.gen.py_recipe;
    if not isinstance(recipe, CgNode) or recipe.cls != "Module" {
        raise RuntimeError(
            f"{module.loc.mod_path} has no Python codegen recipe: the Python code "
            "generator did not run on it"
        );
    }
    tree = host_node(recipe);
    if not isinstance(tree, ast.Module) {
        raise RuntimeError(f"{module.loc.mod_path}: the recipe did not build a module");
    }
    ast.fix_missing_locations(tree);
    return tree;
}

impl host_node(cg: CgNode) -> ast.AST {
    built = getattr(ast, cg.cls)();
    for (key, value) in zip(cg.keys, cg.vals) {
        setattr(built, key, host_value(value));
    }
    if cg.l1 {
        built.lineno = cg.l1;
        built.col_offset = cg.c1;
        built.end_lineno = cg.l2 or cg.l1;
        built.end_col_offset = cg.c2;
    }
    return built;
}

impl host_value(value: any) -> any {
    if isinstance(value, CgNode) {
        return host_node(value);
    }
    if isinstance(value, list) {
        items: list[any] = [];
        for item in value {
            if isinstance(item, CgSplice) {
                items.extend(ast.parse(item.src).body);
            } else {
                items.append(host_value(item));
            }
        }
        return items;
    }
    if isinstance(value, CgEllipsis) {
        return Ellipsis;
    }
    if isinstance(value, CgWideInt) {
        magnitude = int.from_bytes(value.magnitude, "little");
        return -magnitude if value.negative else magnitude;
    }
    return value;
}

impl HostPython.code_bytes(module: uni.Module) -> bytes {
    gen = module.gen;
    if gen.py_bytecode is None {
        path = module.loc.mod_path;
        try {
            code = compile(host_python_ast(module), path, "exec");
        } except SyntaxError as rejected {
            raise GeneratedPythonRejected(
                path=path,
                reason=f"{type(rejected).__name__}: {rejected.msg}",
                line=rejected.lineno or 0,
                col=rejected.offset or 0
            );
        }
        gen.py_code = code;
        gen.py_bytecode = marshal.dumps(code);
    }
    return gen.py_bytecode;
}

impl HostPython.python_source(module: uni.Module) -> str {
    gen = module.gen;
    if gen.py_text is None {
        gen.py_text = ast.unparse(host_python_ast(module));
    }
    return gen.py_text;
}

impl HostPython.parse_module(source: str, path: str) -> PyModule {
    return host_parsed_module(source, path);
}
