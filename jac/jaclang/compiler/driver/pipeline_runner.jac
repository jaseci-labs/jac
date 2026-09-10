import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
import from jaclang.compiler.driver.source_failures { module_import_in_flight }

obj ModuleCompilation {
    has compiler: JacCompiler,
        program: JacProgram,
        path: str,
        options: CompileOptions,
        source: str | None = None,
        module: uni.Module postinit,
        module_path: str = "",
        parse_failed: bool = False,
        blocked: bool = False,
        full_head: bool = False,
        native: bool = False;

    def postinit {
        self.module = uni.Module.make_stub();
    }

    def parse {
        existing = self.program.mod.hub.get(os.path.realpath(self.path));
        if self.source is None
            and not self.compiler.selfhost.is_selfhost(self.program)
            and existing is not None
            and not existing.stub_only
            and not existing.parse_failed
            and self.program.is_hub_entry_fresh(os.path.realpath(self.path))
            and id(existing) in self.program.analysis.completed_passes {
            self.module = existing;
            return;
        }
        keep_str = self.source
            if self.source is not None
            else read_file_with_encoding(self.path);
        errors_before = len(self.program.errors_had);
        self.module = self.compiler.parse_str(
            keep_str, self.path, self.program, cancel_token=self.options.cancel_token
        );
        self.parse_failed = len(self.program.errors_had) > errors_before;
        self.compiler._ingest_comptime_producers(self.module, self.program, self.path);
    }

    def ir {
        import from jaclang.compiler.driver.pipeline {
            get_symtab_ir_sched,
            get_ir_gen_sched,
            providers_of
        }
        self.module_path = os.path.normpath(self.path);
        blocking_errs_pre_ir = self.compiler._count_module_blocking_errors(
            self.program, self.module_path
        );
        if self.options.symtab_ir_only {
            _head_sched = get_symtab_ir_sched();
        } else {
            _head_sched = get_ir_gen_sched(
                is_internal=self.compiler.selfhost.is_selfhost(self.program),
                gen_mtir=not self.options.no_cgen
            );
        }

        self.full_head = AnalysisFact.CFG_SUCC in providers_of(_head_sched);
        self.compiler.run_schedule(
            mod=self.module,
            target_program=self.program,
            passes=_head_sched,
            cancel_token=self.options.cancel_token
        );

        blocking_errs_post_ir = self.compiler._count_module_blocking_errors(
            self.program, self.module_path
        );
        self.blocked = blocking_errs_post_ir > blocking_errs_pre_ir;
    }

    def placement {
        if not self.options.symtab_ir_only and not self.blocked {
            import from jaclang.compiler.placement.placement_solver {
                solve_program_placement,
                refresh_placement_module
            }
            refresh_placement_module(self.module, self.program);
            solve_program_placement(self.module, self.program);
        }
    }

    def analysis {
        import from jaclang.compiler.driver.pipeline { get_analysis_sched }
        import from jaclang.compiler.frontend.constant { CodeContext as _CodeCtx }
        self.native = self.module is not None
            and self.module.declares_codespace(_CodeCtx.NATIVE, path_hint=self.path);

        if self.native {
            self.options.need_full_ast = True;
        }

        _is_decl_stub = str(self.path).endswith('.pyi')
            or str(self.path).endswith('.py')
            or (self.module is not None and self.module.stub_only)
            or (self.module is not None and self.module.is_raised_from_py);
        import from jaclang.jac0core.ext_registry { is_annex as _cc_is_annex }
        _annex_of_base = False;
        if _cc_is_annex(self.path) {
            import from jaclang.compiler.driver.bccache {
                discover_base_file as _cc_base_file
            }
            _annex_of_base = _cc_base_file(str(self.path)) is not None;
        }
        _analyze = self.full_head
            and not _is_decl_stub
            and not _annex_of_base
            and (
                self.native
                or not self.compiler.selfhost.is_selfhost(self.program)
                or not module_import_in_flight(self.path)
            );

        if _analyze {
            if not self.program.analysis.analyses_run.provides(
                self.module, AnalysisFact.TYPE_OF
            ) {
                self.compiler.run_schedule(
                    mod=self.module,
                    target_program=self.program,
                    passes=get_analysis_sched(),
                    cancel_token=self.options.cancel_token
                );
            }
        }

        if not self.blocked
            and self.compiler._count_module_errors(self.program, self.module_path)
                > 0 {
            self.blocked = True;
        }
    }

    def boundaries {
        import from jaclang.compiler.driver.pipeline { get_boundary_analysis_sched }
        if (
            not self.parse_failed
            and not self.blocked
            and not self.options.symtab_ir_only
        ) {
            self.compiler.run_schedule(
                mod=self.module,
                target_program=self.program,
                passes=get_boundary_analysis_sched(),
                cancel_token=self.options.cancel_token
            );
        }
    }

    def native_checks {
        if (
            self.options.no_cgen
            and self.options.native_parity
            and not self.options.symtab_ir_only
            and not self.parse_failed
            and not self.blocked
            and self.program.analysis.analyses_run.provides(
                self.module, AnalysisFact.TYPE_OF
            )
        ) {
            import from jaclang.compiler.frontend.module_facts {
                ModuleFacts as _PtyMcp
            }
            if self.native or _PtyMcp.has_native_context_stmts(self.module) {
                import from jaclang.compiler.driver.pipeline {
                    require_product,
                    CompilationProduct
                }
                require_product(
                    self.program, self.module, CompilationProduct.NATIVE_IR
                );
            }
        }
    }

    def client_dependencies {
        if (
            not self.parse_failed
            and not self.blocked
            and not self.options.symtab_ir_only
            and not self.options.no_cgen
        ) {
            import os as _cb_os;
            cb_seen: set[str] = set();
            cb_worklist: list = [self.module];
            cb_paths: list[str] = [];

            cb_opts = CompileOptions(
                no_cgen=True,
                force_target_program=True,
                cancel_token=self.options.cancel_token
            );
            cb_reg = self.program.iface_registry();
            while cb_worklist or cb_paths {
                if cb_worklist {
                    cb_cur = cb_worklist.pop();
                    if cb_cur is None {
                        continue;
                    }
                    for cb_imp in cb_cur.get_all_sub_nodes(uni.Import) {
                        if not cb_imp.from_loc {
                            continue;
                        }

                        if cb_imp.is_virtual_jac {
                            continue;
                        }
                        try {
                            cb_src = cb_imp.from_loc.resolve_relative_path();
                        } except Exception {
                            continue;
                        }
                        cb_is_client_dep = isinstance(cb_src, str)
                            and cb_imp.code_context == CodeContext.CLIENT
                            and cb_src.endswith('.jac');
                        if not cb_is_client_dep {
                            continue;
                        }
                        cb_paths.append(_cb_os.path.abspath(cb_src));
                    }
                    continue;
                }
                cb_next = cb_paths.pop();
                if cb_next in cb_seen {
                    continue;
                }
                cb_seen.add(cb_next);

                cb_mod = self.program.find_module(cb_next);
                cb_has_facts = (
                    cb_mod is not None
                    and cb_mod.gen
                    and cb_mod.gen.interop_manifest
                    and bool(cb_mod.gen.interop_manifest.bindings)
                );

                cb_known_bad = self.program.has_failed_parse(cb_next);
                if not cb_has_facts and not cb_known_bad {
                    cb_served: (list[str] | None) = None;
                    try {
                        cb_served = cb_reg.client_boundary_facts(cb_next);
                    } except Exception {
                        cb_served = None;
                    }
                    if cb_served is not None {
                        for cb_edge in cb_served {
                            cb_paths.append(_cb_os.path.abspath(cb_edge));
                        }
                        continue;
                    }
                    cb_mod = self.compiler.compile(
                        file_path=cb_next, target_program=self.program, options=cb_opts
                    );
                }
                cb_worklist.append(cb_mod);
            }
            self.program.options = self.options;
        }
    }

    def interface {
        closure = self.compiler._closure_opts or self.options;
        if not self.parse_failed
            and not self.blocked
            and self.source is None
            and (
                (self.options.no_cgen and not self.options.symtab_ir_only)
                or (closure.no_cgen and not closure.symtab_ir_only)
            ) {
            import from jaclang.compiler.driver.pipeline {
                require_product,
                CompilationProduct
            }
            require_product(self.program, self.module, CompilationProduct.INTERFACE);
        }
    }

    def codegen {
        import from jaclang.compiler.driver.pipeline {
            get_analysis_sched,
            get_py_code_gen
        }
        if (
            not self.parse_failed
            and not self.blocked
            and not self.options.no_cgen
            and not self.options.symtab_ir_only
        ) {
            self.program.options = self.options;

            import from jaclang.compiler.frontend.module_facts { ModuleFacts }
            needs_native = self.native
                or ModuleFacts.has_native_context_stmts(self.module);

            if needs_native
                and not self.program.analysis.analyses_run.provides(
                    self.module, AnalysisFact.TYPE_OF
                ) {
                self.compiler.run_schedule(
                    mod=self.module,
                    target_program=self.program,
                    passes=get_analysis_sched(),
                    cancel_token=self.options.cancel_token
                );
            }
            self.compiler.run_schedule(
                mod=self.module,
                target_program=self.program,
                passes=get_py_code_gen(
                    native=needs_native,
                    provided=self.program.analysis.analyses_run.provided(self.module)
                ),
                cancel_token=self.options.cancel_token
            );
            if self.module.decided_codespace == 'native' {
                _scrubbed = self.compiler._scrub_native_artifacts_on_error(
                    self.program, self.module
                );
                if self.options.aot_mode and not _scrubbed {
                    self.compiler._report_missing_native_ir(self.program, self.module);
                }
            }
        }
    }
}

def wasm_artifact(program: JacProgram, file_path: str, exports: list[str]) -> bytes {
    import from jaclang.compiler.backends.native.wasm_build {
        _project_gc_settings,
        _assert_ir_rc_free,
        app_declared_imports,
        emit_wasm_from_ir
    }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    (gc_mode, enf_mods, enf_grand) = _project_gc_settings();
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        before = len(program.errors_had);
        na_coverage_begin();
        try {
            ir = program.compile(
                file_path=os.path.abspath(file_path),
                options=CompileOptions(
                    aot_mode=True,
                    default_codespace='native',
                    na_gc_mode=gc_mode,
                    memory_enforce=enf_mods,
                    memory_exempt=enf_grand,
                    native_target="wasm32-unknown-unknown"
                )
            );
        } finally {
            coverage = na_coverage_end();
        }
        if len(program.errors_had) > before {
            first = program.errors_had[before].pretty_print();
            more = len(program.errors_had) - before - 1;
            suffix = f" (+{more} more)" if more > 0 else "";
            raise RuntimeError(f"{first}{suffix}");
        }
        if (ir is None) or (ir.gen.llvm_ir is None) {
            rec = coverage.get(os.path.realpath(os.path.abspath(file_path)));
            reason = "the module did not lower to native IR"
                + " (no demotion recorded; it likely compiled as a"
                + " non-native codespace)";
            if rec {
                code = f" [{rec['code']}]" if rec['code'] else '';
                detail = f": {rec['detail']}" if rec['detail'] else '';
                reason = f"{rec['outcome']}{code}{detail}";
            }
            raise RuntimeError(
                f"native lowering produced no IR for '{file_path}': {reason}"
            );
        }
        import from jaclang.compiler.backends.native.na_compile_pass {
            native_linked_ir_text
        }
        llvm_ir_str = native_linked_ir_text(ir);
        app_imports = app_declared_imports(ir);
    } finally {
        pop_native_target(prev);
    }
    if gc_mode == "none" {
        _assert_ir_rc_free(llvm_ir_str, file_path);
    }
    return emit_wasm_from_ir(llvm_ir_str, exports, app_imports=app_imports);
}
