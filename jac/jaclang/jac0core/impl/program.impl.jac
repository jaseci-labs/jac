impl JacProgram.init(
    self: JacProgram, main_mod: (uni.ProgramModule | None) = None
) -> None {
    self.mod: uni.ProgramModule = main_mod or uni.ProgramModule();
    self.mtir_map: dict[(str, Info)] = {};
    self.errors_had: list[Alert] = [];
    self.warnings_had: list[Alert] = [];
    self.type_evaluator: (TypeEvaluator | None) = None;
    self._compiler: (JacCompiler | None) = None;
    self._compile_options: CompileOptions = CompileOptions();
    self._native_cache: dict = {};

    self._hub_cache_times: dict[str, float] = {};

    self._dependents: dict[str, set[str]] = {};

    self._track_dependencies: bool = False;

    self._inferred_mods: set = set();

    self._analyses_run: dict = {};

    self._placement_summaries: dict = {};

    self._placement_state: dict = {};
}

impl JacProgram.hub_cache_stamp(self: JacProgram, resolved_path: str) -> None {
    import time;
    self._hub_cache_times[resolved_path] = time.time();
}

impl JacProgram.is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool {
    import os;
    import from jaclang.jac0core.bccache { discover_annex_files }
    cached_at = self._hub_cache_times.get(resolved_path);
    if cached_at is None {
        return True;
    }
    try {
        if os.path.getmtime(resolved_path) > cached_at {
            return False;
        }

        for related in discover_annex_files(resolved_path) {
            if os.path.getmtime(related) > cached_at {
                return False;
            }
        }
        return True;
    } except OSError {
        return False;
    }
}

impl JacProgram.record_dependency(
    self: JacProgram, importer_path: str, target_path: str
) -> None {
    if importer_path == target_path {
        return;
    }
    bucket = self._dependents.get(target_path);
    if bucket is None {
        bucket = set();
        self._dependents[target_path] = bucket;
    }
    bucket.add(importer_path);
}

impl JacProgram.record_module_dependencies(self: JacProgram, mod: uni.Module) -> None {
    import from pathlib { Path }
    if mod.loc is None {
        return;
    }
    mod_path = mod.loc.mod_path;

    if not mod_path.endswith(".jac") {
        return;
    }
    try {
        importer = str(Path(mod_path).resolve());
    } except Exception {
        return;
    }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        paths: list[uni.ModulePath] = [];
        if imp.from_loc is not None {
            paths.append(imp.from_loc);
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    paths.append(item);
                }
            }
        }
        for mp in paths {
            try {
                target = str(Path(mp.resolve_relative_path()).resolve());
            } except Exception {
                continue;
            }
            self.record_dependency(importer, target);
        }
    }
}

impl JacProgram.transitive_dependents(self: JacProgram, target_path: str) -> set[str] {
    out: set[str] = set();
    frontier: list[str] = [target_path];
    while frontier {
        current = frontier.pop();
        for importer in self._dependents.get(current, set()) {
            if importer in out {
                continue;
            }
            out.add(importer);
            frontier.append(importer);
        }
    }
    return out;
}

impl JacProgram.invalidate_module(self: JacProgram, resolved_path: str) -> None {
    if resolved_path in self.mod.hub {
        del (self.mod.hub[resolved_path], );
    }
    if resolved_path in self._hub_cache_times {
        del (self._hub_cache_times[resolved_path], );
    }

    if resolved_path in self._native_cache {
        del (self._native_cache[resolved_path], );
    }

    if resolved_path in self._placement_summaries {
        del (self._placement_summaries[resolved_path], );
    }

    te = self.type_evaluator;
    if te is not None {
        try {
            te.forget_module(resolved_path);
        } except AttributeError {
            self.type_evaluator = None;
        }
    }

    for bucket in self._dependents.values() {
        bucket.discard(resolved_path);
    }
}

impl JacProgram.load_dependency_module(
    self: JacProgram,
    source_path: str,
    importer_path: (str | None) = None,
    use_str: (str | None) = None
) -> uni.Module {
    import from pathlib { Path }
    import from jaclang.jac0core.jir {
        jir_cacheable_source_path,
        read_module_jir_cache,
        write_module_jir_cache,
    }

    resolved_path = str(Path(source_path).resolve());
    compiler = self._get_compiler();
    target_program = compiler._resolve_program(resolved_path, self);
    target_hub = target_program.mod.hub;

    if (resolved_path in self.mod.hub and not self.is_hub_entry_fresh(resolved_path)) {
        self.invalidate_module(resolved_path);
    }
    if (
        resolved_path in target_hub
        and target_program is not self
        and not target_program.is_hub_entry_fresh(resolved_path)
    ) {
        target_program.invalidate_module(resolved_path);
    }

    mod: uni.Module;
    if resolved_path in self.mod.hub {
        mod = self.mod.hub[resolved_path];
    } elif resolved_path in target_hub {
        mod = target_hub[resolved_path];
    } else {
        jir_mod: (object | None) = None;
        if use_str is None {
            jir_mod = read_module_jir_cache(resolved_path);
        }
        if jir_mod is not None {
            mod = jir_mod;
        } elif resolved_path.endswith('.pyi') {
            import ast as py_ast;
            import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
            import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
            import from jaclang.jac0core.helpers { read_file_with_encoding }
            src = use_str or read_file_with_encoding(source_path);
            uni_source = uni.Source(src, source_path);
            mod = PyastBuildPass(
                ir_in=uni.PythonModuleAst(py_ast.parse(src), orig_src=uni_source,),
                prog=self,
            ).ir_out;
            SymTabBuildPass(ir_in=mod, prog=self);
            mod.stub_only = True;
            if jir_cacheable_source_path(resolved_path) {
                write_module_jir_cache(resolved_path, mod);
            }
        } else {
            mod = self.compile(
                source_path,
                use_str=use_str,
                no_cgen=True,
                type_check=False,
                symtab_ir_only=True
            );
            if jir_cacheable_source_path(resolved_path) {
                write_module_jir_cache(resolved_path, mod);
            }
        }
        target_hub[resolved_path] = mod;
        target_program.hub_cache_stamp(resolved_path);
    }

    if importer_path is not None {
        self.record_dependency(importer_path, resolved_path);
    }
    return mod;
}

impl JacProgram._get_compiler(self: JacProgram) -> JacCompiler {
    if self._compiler {
        return self._compiler;
    }
    import from jaclang.jac0core.compiler { JacCompiler }
    self._compiler = JacCompiler();
    return self._compiler;
}

impl JacProgram.get_type_evaluator(self: JacProgram) -> TypeEvaluator {
    import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
    if not self.type_evaluator {
        self.type_evaluator = TypeEvaluator(program=self);
    }
    return self.type_evaluator;
}

impl JacProgram.clear_type_system(self: JacProgram, clear_hub: bool = False) -> None {
    self.type_evaluator = None;
    if clear_hub {
        self.mod.hub.clear();
    } else {
        for mod in self.mod.hub.values() {
            for nd in mod.get_all_sub_nodes(uni.Expr) {
                nd.type = None;
            }
        }
    }
}

impl JacProgram.release_compile_closure(
    self: JacProgram, keep_stubs: bool = False
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    retained_stubs: dict = {};
    retained_times: dict[str, float] = {};
    if keep_stubs {
        for path in self.mod.hub.keys() {
            if path.endswith(".pyi") {
                retained_stubs[path] = self.mod.hub[path];
                if path in self._hub_cache_times {
                    retained_times[path] = self._hub_cache_times[path];
                }
            }
        }
    }
    self.mod = uni.ProgramModule();
    self.mod.hub.update(retained_stubs);
    self._hub_cache_times.clear();
    self._hub_cache_times.update(retained_times);
    self._dependents.clear();
    self.type_evaluator = None;
    self.errors_had.clear();
    self.warnings_had.clear();
}

impl JacProgram._search_hubs(self: JacProgram) -> list[dict[(str, uni.Module)]] {
    hubs: list[dict[(str, uni.Module)]] = [self.mod.hub];
    internal = self._get_compiler().internal_program;
    if internal is not self {
        hubs.append(internal.mod.hub);
    }
    return hubs;
}

impl JacProgram.find_module(self: JacProgram, path: str) -> (uni.Module | None) {
    import os;
    hubs = self._search_hubs();
    for hub in hubs {
        if path in hub {
            return hub[path];
        }
    }

    normalized = os.path.normcase(path);
    for hub in hubs {
        for (hub_path, mod) in hub.items() {
            if os.path.normcase(hub_path) == normalized {
                return mod;
            }
        }
    }
    return None;
}

impl JacProgram.get_bytecode(
    self: JacProgram, full_target: str
) -> (types.CodeType | None) {
    return self._get_compiler().get_bytecode(full_target, self);
}

impl JacProgram.parse_str(
    self: JacProgram,
    source_str: str,
    file_path: str,
    cancel_token: (Event | None) = None
) -> uni.Module {
    mod = self._get_compiler().parse_str(source_str, file_path, self, cancel_token);
    if self._track_dependencies {
        try {
            self.record_module_dependencies(mod);
        } except Exception {
            ;
        }
    }
    return mod;
}

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
    mod = self._get_compiler().compile(
        file_path=file_path, target_program=self, use_str=use_str, options=options
    );
    if self._track_dependencies {
        try {
            self.record_module_dependencies(mod);
        } except Exception {
            ;
        }
    }
    return mod;
}

impl JacProgram.build(
    self: JacProgram,
    file_path: str,
    use_str: (str | None) = None,
    type_check: bool = False
) -> uni.Module {
    return self._get_compiler().build(file_path, self, use_str, type_check=type_check);
}

impl JacProgram.run_schedule(
    self: JacProgram,
    mod: uni.Module,
    passes: list[type[Transform[uni.Module, uni.Module]]],
    cancel_token: (Event | None) = None
) -> None {
    self._get_compiler().run_schedule(mod, self, passes, cancel_token);
}
