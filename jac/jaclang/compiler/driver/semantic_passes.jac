import type from jaclang.compiler.types.types { TypeBase }
import os;
import from jaclang.compiler.driver.context_passes { ProgramTransform }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.semantic_facts {
    NativeEligibility,
    PlacementSpaces,
    ImportEdge,
    ServingFacts,
    ServingBinding
}
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }

walker DependencyFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        if ir_in.stub_only
            and os.path.realpath(ir_in.loc.mod_path) in self.prog.deps.imports {
            return ir_in;
        }
        edges: list[ImportEdge] = [];
        for imp in ir_in.get_all_sub_nodes(uni.Import) {
            if imp.is_virtual_jac {
                continue;
            }
            paths = [imp.from_loc]
                if imp.from_loc is not None
                else [
                    item
                    for item in imp.items
                    if isinstance(item, uni.ModulePath)
                ];
            for path in paths {
                try {
                    target = path.resolve_relative_path();
                } except Exception {
                    continue;
                }
                if not isinstance(target, str) or not target {
                    continue;
                }
                target = os.path.realpath(target);
                edges.append(
                    ImportEdge(
                        target,
                        imp.is_jac,
                        imp.is_comptime,
                        imp.code_context,
                        imp.parent is ir_in,
                        imp.from_loc is not None
                    )
                );
                self.prog.record_dependency(ir_in.loc.mod_path, target);
            }
        }
        self.prog.deps.imports[os.path.realpath(ir_in.loc.mod_path)] = edges;
        return ir_in;
    }
}

walker ComptimeImportsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        if self.prog._get_compiler().selfhost.is_selfhost(self.prog) {
            return ir_in;
        }
        path = os.path.realpath(ir_in.loc.mod_path);
        saved = self.prog.options;
        try {
            for edge in self.prog.deps.imports.get(path, []) {
                if edge.is_comptime
                    and edge.target.endswith('.jac')
                    and edge.target != path
                    and os.path.isfile(edge.target) {
                    self.prog.load_dependency_module(
                        edge.target, importer_path=path, need_tree=True
                    );
                }
            }
        } finally {
            self.prog.options = saved;
        }
        return ir_in;
    }
}

walker PlacementSummaryPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.placement.placement { summarize_module }
        key = os.path.abspath(ir_in.loc.mod_path)
            if ir_in.loc.mod_path
            else f'@{id(ir_in)}';
        self.prog.analysis.placement_summaries[key] = summarize_module(ir_in);
        return ir_in;
    }
}

walker ProgramPlacementPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.placement.placement_solver {
            refresh_placement_module,
            solve_program_placement
        }
        refresh_placement_module(ir_in, self.prog);
        solve_program_placement(ir_in, self.prog);
        return ir_in;
    }
}

walker ClientDependenciesPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.driver.pipeline {
            require_product,
            CompilationProduct
        }
        import from jaclang.compiler.driver.compile_options { CompileOptions }
        if not ir_in.loc.mod_path {
            return ir_in;
        }
        seen: set[str] = set();
        root_path = os.path.realpath(ir_in.loc.mod_path);
        pending: list[str] = [root_path];
        options = self.prog.options;
        dependency_options = CompileOptions(
            no_cgen=True, force_target_program=True, cancel_token=options.cancel_token
        );
        registry = self.prog.iface_registry();
        try {
            while pending {
                path = pending.pop();
                if path in seen {
                    continue;
                }
                seen.add(path);
                module = self.prog.find_module(path);
                manifest = module.gen.interop_manifest if module is not None else None;
                if not (manifest and manifest.bindings) and path != root_path {
                    cached = registry.client_boundary_facts(path);
                    if cached is not None {
                        pending.extend(cached);
                        continue;
                    }
                    if self.prog.has_failed_parse(path) {
                        continue;
                    }
                    module = self.prog.compile(path, options=dependency_options);
                }
                if module is not None {
                    require_product(self.prog, module, CompilationProduct.IMPORTS);
                    pending.extend(
                        edge.target
                        for edge in self.prog.deps.imports.get(path, [])
                        if edge.context == CodeContext.CLIENT
                            and edge.target.endswith('.jac')
                    );
                }
            }
        } finally {
            self.prog.options = options;
        }
        return ir_in;
    }
}

walker ServingFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        facts = ServingFacts();
        manifest = ir_in.gen.interop_manifest;
        if manifest {
            facts.func_access.update(manifest.func_access);
            facts.walker_access.update(manifest.walker_access);
            facts.effects.update(manifest.endpoint_effects);
            for binding in manifest.server_exports_to_client {
                decl = binding.ast_node;
                if decl is None or not decl.loc.mod_path {
                    continue;
                }
                access = decl?.access;
                facts.cross_bindings.append(
                    ServingBinding(
                        binding.name,
                        binding.kind,
                        os.path.realpath(decl.loc.mod_path),
                        not (access is not None and access.tag.name == Tok.KW_PUB)
                    )
                );
            }
        }
        self.prog.analysis.serving_facts[os.path.realpath(ir_in.loc.mod_path)] = facts;
        return ir_in;
    }
}

walker InterfaceFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.driver.pipeline_types { ProductUnavailable }
        if not self.prog.iface_registry().prepare_interface(
            os.path.realpath(ir_in.loc.mod_path), ir_in
        ) {
            raise ProductUnavailable('Module has no cacheable interface');
        }
        return ir_in;
    }
}

walker PlacementSpacesPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.frontend.module_facts { ModuleFacts }
        facts = PlacementSpaces();
        facts.native_module = ir_in.declares_codespace(
            CodeContext.NATIVE, path_hint=ir_in.loc.mod_path
        );
        facts.has_native = ModuleFacts.has_native_context_stmts(ir_in);
        for stmt in ir_in.body {
            if isinstance(stmt, uni.ContextAwareNode) {
                facts.spaces.add(stmt.code_context);
            }
        }
        if not facts.spaces {
            facts.spaces.add(CodeContext.SERVER);
        }
        self.prog.analysis.module_spaces[os.path.realpath(ir_in.loc.mod_path)] = facts;
        return ir_in;
    }
}

walker NativeEligibilityPass(ProgramTransform) {
    has hold_exempt: bool = False,
        result: NativeEligibility = NativeEligibility();

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.placement.placement { scan_native_blockers }
        (reason, dependencies) = scan_native_blockers(
            ir_in,
            os.path.dirname(os.path.abspath(ir_in.loc.mod_path)),
            allow_pub=True,
            hold_exempt=self.hold_exempt
        );
        self.result = NativeEligibility(reason, dependencies);
        return ir_in;
    }
}

walker NativeClosurePass(ProgramTransform) {
    has dependencies: list[str],
        hold_exempt: bool = False,
        eligible: bool = True;

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.frontend.codeinfo { effective_native_closure_cap }
        import from jaclang.compiler.driver.na_coverage { _note_native_closure_cap }
        import from jaclang.compiler.native_scope {
            in_native_scope_path,
            scope_lowering_active
        }
        import from jaclang.compiler.driver.pipeline { native_dependency_facts }
        path = ir_in.loc.mod_path;
        seen: set[str] = {path};
        pending = list(self.dependencies);
        cap = effective_native_closure_cap();
        while pending {
            if len(seen) > cap {
                _note_native_closure_cap(path, cap);
                self.eligible = False;
                break;
            }
            target = pending.pop();
            if target in seen {
                continue;
            }
            if in_native_scope_path(target) and not scope_lowering_active() {
                self.eligible = False;
                break;
            }
            facts = native_dependency_facts(self.prog, target, self.hold_exempt);
            if facts.reason {
                self.eligible = False;
                break;
            }
            seen.add(target);
            pending.extend(facts.dependencies);
        }
        return ir_in;
    }
}

walker TypeQueryPass(ProgramTransform) {
    has query: uni.Expr | uni.Symbol,
        result: TypeBase | None = None;

    def transform(ir_in: uni.Module) -> uni.Module {
        evaluator = self.prog.get_type_evaluator();
        if isinstance(self.query, uni.Expr) {
            self.result = evaluator.get_type_of_expression(self.query);
        } else {
            provider = self.query.provider;
            self.result = provider.resolve_type(self.query)
                if provider is not None
                else evaluator.get_type_of_symbol(self.query);
        }
        return ir_in;
    }
}

walker PlacementReportPass(ProgramTransform) {
    has rows: dict = {};

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.placement.placement { _collect_placement_rows }
        self.rows = _collect_placement_rows(self.prog);
        return ir_in;
    }
}

walker NativeDemotionPass(ProgramTransform) {
    has path: str;

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.driver.pipeline { invalidate_client_product }
        import from jaclang.compiler.driver.na_coverage {
            _drop_demoted_native_bindings
        }
        for importer in self.prog.deps.dependents.get(
            os.path.realpath(self.path), set()
        ) {
            module = self.prog.find_module(importer);
            if module is not None {
                invalidate_client_product(self.prog, module);
                _drop_demoted_native_bindings(module, self.path);
            }
        }
        return ir_in;
    }
}
