import ast as ast3;

def module_imports_torch(src: str, file_path: str) -> bool {
    if 'torch' not in src {
        return False;
    }
    if file_path.endswith('.py') {
        return _py_imports_torch(src, file_path);
    }
    return _jac_binds_torch(src, file_path);
}

def file_imports_torch(file_path: str) -> bool {
    try {
        src = read_source_shared(file_path);
        if src is None {
            return False;
        }
        return module_imports_torch(src, file_path);
    } except Exception {
        return False;
    }
}

def _py_imports_torch(src: str, file_path: str) -> bool {
    try {
        parsed = ast3.parse(src);
        built = run_utility(
            CompilationProduct.PYTHON_AST,
            uni.PythonModuleAst(parsed, orig_src=uni.Source(src, mod_path=file_path)),
            JacProgram()
        ).module;
    } except Exception {
        return False;
    }
    return isinstance(built, uni.Module) and module_binds_torch(built);
}

def _jac_binds_torch(src: str, file_path: str) -> bool {
    try {
        (mod, _had_error) = rd_parse(src, file_path, prog=JacProgram());
    } except Exception {
        return False;
    }
    return module_binds_torch(mod);
}
