impl GeneratedPythonRejected.__str__ -> str {
    where = f"{self.path}:{self.line}:{self.col}" if self.line else self.path;
    return f"JacPython's compiler rejected the generated Python of {where}: {self.reason}";
}

impl python_tree(module: uni.Module) -> Module {
    recipe = module.gen.py_recipe;
    if not isinstance(recipe, CgNode) {
        raise KernelError(
            f"{module.loc.mod_path} has no Python codegen recipe: the Python code "
            "generator did not run on it"
        );
    }
    return build_module_ast(recipe, module.loc.mod_path);
}

impl kernel_code_object(module: uni.Module) -> ptr[PyObject] {
    gen = module.gen;
    if gen.py_code is not None {
        return gen.py_code;
    }
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
        raise KernelError(
            f"JacPython's compiler returned a {compiled.tp_type_name()} for {path}, "
            "not a code object"
        );
    }
    code = constant_object(compiled);
    gen.py_code = code;
    gen.py_bytecode = code_bytes(code);
    return code;
}

impl kernel_python_ast(module: uni.Module) -> any {
    gen = module.gen;
    if gen.py_ast {
        return gen.py_ast[0];
    }
    written = ast_write_node(python_tree(module));
    gen.py_ast = [written];
    return written;
}

impl code_bytes(code: ptr[PyObject]) -> bytes {
    return take_buffer(PyMarshal_WriteObjectToString(code, CODE_MARSHAL_VERSION));
}

impl code_from_bytes(data: bytes) -> ptr[PyObject] {
    held = required(write_buffer(data));
    try {
        return required(
            PyMarshal_ReadObjectFromString(PyBytes_AsString(held), i64(len(data)))
        );
    } finally {
        jacpy_release(held);
    }
}
