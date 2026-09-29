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
    import from jaclang.compiler.driver.jir { read_source_shared }
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
    import jaclang.compiler.frontend.unitree as uni;
    import from jaclang.compiler.driver.pipeline_runner { run_utility, UtilityProduct }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.graphmend.scope_facts { module_binds_torch }
    try {
        parsed = ast3.parse(src);
        built = run_utility(
            UtilityProduct.PYTHON_AST,
            uni.PythonModuleAst(parsed, orig_src=uni.Source(src, mod_path=file_path)),
            JacProgram()
        ).module;
    } except Exception {
        return False;
    }
    return isinstance(built, uni.Module) and module_binds_torch(built);
}

def _jac_binds_torch(src: str, file_path: str) -> bool {
    import from jaclang.compiler.frontend.parser { parse as rd_parse }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.graphmend.scope_facts { module_binds_torch }
    try {
        (mod, _had_error) = rd_parse(src, file_path, prog=JacProgram());
    } except Exception {
        return False;
    }
    return module_binds_torch(mod);
}
