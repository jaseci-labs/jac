import os;
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;

obj SelfHostCache {
    has _program: (JacProgram | None) = None,
        _jaclang_root: (str | None) = None,
        _bytecode_depth: int = 0;

    has program: JacProgram { getter; }

    def peek_program -> (JacProgram | None) {
        return self._program;
    }

    def is_selfhost(prog: (JacProgram | None)) -> bool {
        return self._program is not None and prog is self._program;
    }

    def jaclang_root -> str {
        resolved = self._jaclang_root;
        if (resolved is None) {
            import jaclang;
            resolved = os.path.realpath(os.path.dirname(str(jaclang.__file__)));
            self._jaclang_root = resolved;
        }
        return resolved;
    }

    def owns(file_path: str) -> bool {
        normalized_path = os.path.realpath(file_path);
        return normalized_path.startswith((self.jaclang_root() + os.sep));
    }

    """Which program compiles `file_path`.

    Compiler-tree modules belong to the selfhost program, except the ones
    a native-unit compile owns: the native standard library, and the
    kernel's scope units when `native_unit` is set. Those compile in the
    target program, which is what lets one JIR entry carry both the
    bytecode the compiler runs and the native unit the kernel links.
    """
    def resolve(
        file_path: str,
        target_program: JacProgram,
        force: bool = False,
        native_unit: bool = False
    ) -> JacProgram {
        if not force and self.owns(file_path) {
            if self.is_selfhost(target_program) {
                return self.program;
            }
            import from jaclang.compiler.frontend.codeinfo {
                is_native_by_location,
                native_unit_compile_active
            }
            if is_native_by_location(file_path) {
                return target_program;
            }
            import from jaclang.compiler.native_scope { in_native_scope_path }
            if (native_unit or native_unit_compile_active()) and in_native_scope_path(file_path) {
                return target_program;
            }
            return self.program;
        }
        return target_program;
    }

    def evict_unit(
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
        self.program.release_compile_closure(collect=collect);
    }

    def enter_bytecode {
        self._bytecode_depth += 1;
    }

    def exit_bytecode {
        self._bytecode_depth -= 1;
    }

    def at_outermost_bytecode -> bool {
        return self._bytecode_depth == 1;
    }
}

impl SelfHostCache.program.getter -> JacProgram {
    if (self._program is None) {
        import from jaclang.runtime.runtime { JacRuntime }
        prog = JacProgram();
        prog._compiler = JacRuntime.get_compiler();
        self._program = prog;
    }
    return self._program;
}
