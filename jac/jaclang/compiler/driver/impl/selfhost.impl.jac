impl SelfHostCache.peek_program -> (JacProgram | None) {
    return self._program;
}

impl SelfHostCache.is_selfhost(prog: (JacProgram | None)) -> bool {
    return prog is not None and prog.internal;
}

impl SelfHostCache.jaclang_root -> str {
    resolved = self._jaclang_root;
    if (resolved is None) {
        import jaclang;
        resolved = os.path.realpath(os.path.dirname(str(jaclang.__file__)));
        self._jaclang_root = resolved;
    }
    return resolved;
}

impl SelfHostCache.owns(file_path: str) -> bool {
    return is_compiler_source_path(file_path);
}

impl SelfHostCache.resolve(
    file_path: str,
    target_program: JacProgram,
    force: bool = False,
    native_unit: bool = False,
    execution: bool = False
) -> JacProgram {
    if not force and self.owns(file_path) {
        if self.is_selfhost(target_program) {
            return self.program;
        }
        if target_program.options.native_required_for(file_path) {
            return target_program;
        }
        directory = os.path.dirname(os.path.realpath(file_path));
        package_root = self.jaclang_root();
        while directory.startswith(package_root + os.sep) {
            if os.path.isfile(os.path.join(directory, 'jac.toml')) {
                return target_program;
            }
            directory = os.path.dirname(directory);
        }
        import from jaclang.compiler.frontend.codeinfo {
            is_native_by_location,
            native_unit_compile_active,
            is_shared_runtime_module
        }
        if is_native_by_location(file_path) or is_shared_runtime_module(file_path) {
            return target_program;
        }
        import from jaclang.compiler.native_scope { in_native_scope_path }
        if not execution
            and (native_unit or native_unit_compile_active())
            and in_native_scope_path(file_path) {
            return target_program;
        }
        return self.program;
    }
    return target_program;
}

impl SelfHostCache.evict_unit(
    full_target: str, result: (uni.Module | None), collect: bool = True
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    if result is not None and result.gen.native_engine is not None {
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
        slim = CodeGenTarget();
        slim.native_engine = result.gen.native_engine;
        slim.native_layout = result.gen.native_layout;
        slim.native_iface = result.gen.native_iface;
        slim.native_deps = list(result.gen.native_deps or []);
        slim.interop_py_funcs = result.gen.interop_py_funcs;
        slim._interop_callbacks = result.gen._interop_callbacks;
        slim.interop_manifest = result.gen.interop_manifest;
        self.program.hub.artifacts[full_target] = slim;
    }
    if self._execution_depth > 0 {
        self._release_pending = True;
        self._collect_pending = self._collect_pending or collect;
    } else {
        self.program.release_compile_closure(collect=collect);
    }
}

impl SelfHostCache.enter_execution {
    self._execution_depth += 1;
}

impl SelfHostCache.exit_execution {
    self._execution_depth -= 1;
    if self._execution_depth == 0 and self._release_pending {
        collect = self._collect_pending;
        self._release_pending = False;
        self._collect_pending = False;
        self.program.release_compile_closure(collect=collect);
    }
}

impl SelfHostCache.enter_bytecode {
    self._bytecode_depth += 1;
}

impl SelfHostCache.exit_bytecode {
    self._bytecode_depth -= 1;
}

impl SelfHostCache.at_outermost_bytecode -> bool {
    return self._bytecode_depth == 1;
}

impl SelfHostCache.program.getter -> JacProgram {
    if (self._program is None) {
        import from jaclang.runtime.runtime { JacRuntime }
        prog = JacProgram();
        prog._compiler = JacRuntime.get_compiler();
        prog.internal = True;
        self._program = prog;
    }
    return self._program;
}
