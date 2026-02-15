"""Implementation for program constructs."""

"""Initialize the JacProgram object.

    Args:
        main_mod: Optional main module to initialize with.
        bytecode_cache: Optional custom bytecode cache. If None, uses default.
    """
impl JacProgram.init(
    self: JacProgram,
    main_mod: (uni.ProgramModule | None) = None,
    bytecode_cache: (BytecodeCache | None) = None
) -> None {
    self.mod: uni.ProgramModule = main_mod or uni.ProgramModule();
    self.py_raise_map: dict[(str, str)] = {};
    self.mtir_map: dict[(str, Info)] = {};
    self.errors_had: list[Alert] = [];
    self.warnings_had: list[Alert] = [];
    self.type_evaluator: (TypeEvaluator | None) = None;
    self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache();
    self._compiler: (JacCompiler | None) = None;
    self._compile_options: CompileOptions = CompileOptions();
}

"""Get a JacCompiler instance configured with this program's cache."""
impl JacProgram._get_compiler(self: JacProgram) -> JacCompiler {
    if self._compiler {
        return self._compiler;
    }
    import from jaclang.jac0core.compiler { JacCompiler }
    self._compiler = JacCompiler(bytecode_cache=self._bytecode_cache);
    return self._compiler;
}

"""Return the type evaluator, creating one if needed."""
impl JacProgram.get_type_evaluator(self: JacProgram) -> TypeEvaluator {
    import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
    if not self.type_evaluator {
        self.type_evaluator = TypeEvaluator(program=self);
    }
    return self.type_evaluator;
}

"""Clear all type information from the program."""
impl JacProgram.clear_type_system(self: JacProgram, clear_hub: bool = False) -> None {
    self.type_evaluator = None;
    if clear_hub {
        self.mod.hub.clear();
    } else {
        for mod in self.mod.hub.values() {
            for nd in mod.get_all_sub_nodes(uni.Expr, brute_force=True) {
                nd.type = None;
            }
        }
    }
}

"""Get the bytecode for a specific module."""
impl JacProgram.get_bytecode(
    self: JacProgram, full_target: str
) -> (types.CodeType | None) {
    return self._get_compiler().get_bytecode(full_target, self);
}

"""Parse source string into an AST module."""
impl JacProgram.parse_str(
    self: JacProgram,
    source_str: str,
    file_path: str,
    cancel_token: (Event | None) = None
) -> uni.Module {
    return self._get_compiler().parse_str(source_str, file_path, self, cancel_token);
}

"""Compile a Jac file into a module AST."""
impl JacProgram.compile(
    self: JacProgram,
    file_path: str,
    use_str: (str | None) = None,
    no_cgen: bool = False,
    type_check: bool = False,
    symtab_ir_only: bool = False,
    cancel_token: (Event | None) = None,
    options: (CompileOptions | None) = None
) -> uni.Module {
    if (options is None) {
        options = CompileOptions(
            type_check=type_check,
            symtab_ir_only=symtab_ir_only,
            no_cgen=no_cgen,
            cancel_token=cancel_token
        );
    }
    return self._get_compiler().compile(
        file_path=file_path, target_program=self, use_str=use_str, options=options
    );
}

"""Build a Jac file with import dependency resolution."""
impl JacProgram.build(
    self: JacProgram,
    file_path: str,
    use_str: (str | None) = None,
    type_check: bool = False
) -> uni.Module {
    return self._get_compiler().build(file_path, self, use_str, type_check=type_check);
}

"""Run a schedule of passes on a module."""
impl JacProgram.run_schedule(
    self: JacProgram,
    mod: uni.Module,
    passes: list[type[Transform[(uni.Module, uni.Module)]]],
    cancel_token: (Event | None) = None
) -> None {
    self._get_compiler().run_schedule(mod, self, passes, cancel_token);
}
