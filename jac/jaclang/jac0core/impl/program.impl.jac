"""Implementation for program constructs."""

impl JacProgram.init(
    self: JacProgram, main_mod: (uni.ProgramModule | None) = None
) -> None {
    self.mod: uni.ProgramModule = main_mod or uni.ProgramModule();
    self.py_raise_map: dict[(str, str)] = {};
    self.mtir_map: dict[(str, Info)] = {};
    self.errors_had: list[Alert] = [];
    self.warnings_had: list[Alert] = [];
    self.type_evaluator: (TypeEvaluator | None) = None;
    self._compiler: (JacCompiler | None) = None;
    self._compile_options: CompileOptions = CompileOptions();
    self._native_cache: dict = {};
    # See `hub_cache_stamp` / `is_hub_entry_fresh`.
    self._hub_cache_times: dict[str, float] = {};
    # See `record_dependency` / `transitive_dependents`.
    self._dependents: dict[str, set[str]] = {};
}

impl JacProgram.hub_cache_stamp(self: JacProgram, resolved_path: str) -> None {
    import time;
    self._hub_cache_times[resolved_path] = time.time();
}

impl JacProgram.is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool {
    import os;
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files
    }
    cached_at = self._hub_cache_times.get(resolved_path);
    if cached_at is None {
        # No stamp recorded for this path. The caller's eviction policy
        # depends on context: paths that go through `_import_module_from_path`
        # always get stamped, but `TypeEvaluator._module_type_cache` also
        # caches external (.js/.ts/asset) modules and special namespace
        # placeholders that never reach the import resolver. Treat the
        # absence of a stamp as "trust the existing cache" so we do not
        # churn those entries on every type-of query.
        return True;
    }
    try {
        if os.path.getmtime(resolved_path) > cached_at {
            return False;
        }
        # Annex (.impl.jac/.test.jac) and variant (.cl.jac/.sv.jac/.na.jac)
        # files are spliced into the parent module by the compiler, so
        # editing them must invalidate the parent's cache too. This
        # mirrors `is_module_cache_valid` in jac0core.jir.
        for related in discover_annex_files(resolved_path) {
            if os.path.getmtime(related) > cached_at {
                return False;
            }
        }
        for related in discover_variant_files(resolved_path) {
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
    # Drop hub IR + freshness stamp.
    if resolved_path in self.mod.hub {
        del (self.mod.hub[resolved_path], );
    }
    if resolved_path in self._hub_cache_times {
        del (self._hub_cache_times[resolved_path], );
    }
    # Drop native artifacts referencing this module.
    if resolved_path in self._native_cache {
        del (self._native_cache[resolved_path], );
    }
    # Drop the type-evaluator's per-path caches; if the evaluator does not
    # exist yet (no compile has run on this program) there is nothing to do.
    te = self.type_evaluator;
    if te is not None {
        try {
            te.forget_module(resolved_path);
        } except AttributeError {
            # Older TypeEvaluator instances without forget_module. Fall
            # back to the coarse reset; correctness over performance.
            self.type_evaluator = None;
        }
    }
    # Drop edges where this module is the importer; they will be re-added
    # when the module is re-parsed and the import resolver runs again.
    # Edges where this module is the target (i.e., its dependents) stay,
    # so future invalidations of this module still fan out correctly.
    for bucket in self._dependents.values() {
        bucket.discard(resolved_path);
    }
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
            for nd in mod.get_all_sub_nodes(uni.Expr, brute_force=True) {
                nd.type = None;
            }
        }
    }
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
    return self._get_compiler().parse_str(source_str, file_path, self, cancel_token);
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
    return self._get_compiler().compile(
        file_path=file_path, target_program=self, use_str=use_str, options=options
    );
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
