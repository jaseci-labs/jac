impl python_tree(module: uni.Module) -> Module {
    recipe = module.gen.py_recipe;
    if not isinstance(recipe, CgNode) {
        raise RuntimeError(
            f"{module.loc.mod_path} has no Python codegen recipe: the Python code "
            "generator did not run on it"
        );
    }
    return build_module_ast(recipe, module.loc.mod_path);
}

impl kernel_code_object(module: uni.Module) -> ptr[PyObject] {
    path = module.loc.mod_path;
    compiled = compile_ast(python_tree(module), path, "exec");
    if isinstance(compiled, PyError) {
        failure = compiled.exception;
        line = 0;
        col = 0;
        located = failure.type_fields.get("lineno");
        if isinstance(located, PyInt) {
            line = located.val;
        }
        offset = failure.type_fields.get("offset");
        if isinstance(offset, PyInt) {
            col = offset.val;
        }
        raise GeneratedPythonRejected(
            path=path,
            reason=f"{failure.type_name}: {failure.message}",
            line=line,
            col=col
        );
    }
    if not isinstance(compiled, PyCode) {
        raise RuntimeError(
            f"JacPython's compiler returned a {compiled.tp_type_name()} for {path}, "
            "not a code object"
        );
    }
    return constant_object(compiled);
}

impl KernelPython.code_bytes(module: uni.Module) -> bytes {
    gen = module.gen;
    if gen.py_bytecode is None {
        code = kernel_code_object(module);
        try {
            gen.py_bytecode = take_buffer(
                PyMarshal_WriteObjectToString(code, CODE_MARSHAL_VERSION)
            );
        } finally {
            jacpy_release(code);
        }
    }
    return gen.py_bytecode;
}

impl KernelPython.python_source(module: uni.Module) -> str {
    gen = module.gen;
    if gen.py_text is None {
        tree = ast_write_node(python_tree(module));
        ast_module: ptr[PyObject] = NULL;
        text: ptr[PyObject] = NULL;
        try {
            ast_module = required(PyImport_ImportModule(ptr[u8]("ast")));
            text = required(PyObject_CallMethod(ast_module, "unparse", "O", tree));
            gen.py_text = text_value(text);
        } finally {
            jacpy_release(text);
            jacpy_release(ast_module);
            jacpy_release(tree);
        }
    }
    return gen.py_text;
}

impl KernelPython.parse_module(source: str, path: str) -> Module {
    tree = parse_file(source, path);
    if tree is None {
        raise RuntimeError(f"{path}: the Python parser returned no module");
    }
    return tree;
}
