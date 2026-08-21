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
    import from jaclang.jac0core.jir { read_source_shared }
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
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.compiler { run_pass }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.compiler.passes.main.graphmend.scope_facts {
        module_binds_torch
    }
    try {
        parsed = ast3.parse(src);
        ret = run_pass(
            PyastBuildPass,
            uni.PythonModuleAst(parsed, orig_src=uni.Source(src, mod_path=file_path)),
            JacProgram()
        );
    } except Exception {
        return False;
    }
    return module_binds_torch(ret.ir_out);
}

def _jac_binds_torch(src: str, file_path: str) -> bool {
    import from jaclang.jac0core.parser { parse as rd_parse }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.main.graphmend.scope_facts {
        module_binds_torch
    }
    try {
        (mod, _had_error) = rd_parse(src, file_path, prog=JacProgram());
    } except Exception {
        return False;
    }
    return module_binds_torch(mod);
}
