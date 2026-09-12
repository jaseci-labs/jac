import from jaclang.compiler.pipeline.executor { execute_passes }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }
import os;
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.session { JacProgram }
import type from jaclang.compiler.session.compiler { JacCompiler }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.frontend.source_io { read_file_with_encoding }
import from jaclang.compiler.bootstrap.source_failures { module_import_in_flight }

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
            and self.program.analysis.has_module(existing) {
            self.module = existing;
            return;
        }
        keep_str = self.source
            if self.source is not None
            else read_file_with_encoding(self.path);
        self.module = self.compiler.parse_str(
            keep_str, self.path, self.program, cancel_token=self.options.cancel_token
        );
        self.parse_failed = self.module.parse_failed;
    }

    def ir {
        import from jaclang.compiler.pipeline.schedule {
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
                gen_mtir=not self.options.no_cgen and not self.parse_failed
            );
        }

        self.full_head = AnalysisFact.CFG_SUCC in providers_of(_head_sched);
        execute_passes(
            module=self.module,
            program=self.program,
            passes=_head_sched,
            cancel_token=self.options.cancel_token
        );

        blocking_errs_post_ir = self.compiler._count_module_blocking_errors(
            self.program, self.module_path
        );
        self.blocked = blocking_errs_post_ir > blocking_errs_pre_ir
            or not self.program.analysis.has_module(self.module)
            or _head_sched[-1]
                not in self.program.analysis.module(self.module).completed;
    }

    def placement {
        if not self.parse_failed
            and not self.options.symtab_ir_only
            and not self.blocked {
            import from jaclang.compiler.pipeline.products {
                require_product,
                invalidate_product
            }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            invalidate_product(self.program, self.module, CompilationProduct.IMPORTS);
            require_product(self.program, self.module, CompilationProduct.PLACEMENT);
        }
    }

    def analysis {
        if self.blocked {
            return;
        }
        import from jaclang.compiler.pipeline.schedule { get_analysis_sched }
        import from jaclang.compiler.api { module_spaces }
        self.native = module_spaces(self.program, self.module).native_module;

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
            import from jaclang.compiler.session.cache.annexes {
                discover_base_file as _cc_base_file
            }
            _annex_of_base = _cc_base_file(str(self.path)) is not None;
        }
        _analyze = not self.blocked
            and self.full_head
            and self.program.analysis.provides(self.module, AnalysisFact.CFG_SUCC)
            and not _is_decl_stub
            and not _annex_of_base
            and (
                self.native
                or not self.compiler.selfhost.is_selfhost(self.program)
                or not module_import_in_flight(self.path)
            );

        if _analyze {
            if not self.program.analysis.provides(self.module, AnalysisFact.TYPE_OF) {
                import from jaclang.compiler.pipeline.products { require_product }
                import from jaclang.compiler.pipeline.contracts { CompilationProduct }
                require_product(self.program, self.module, CompilationProduct.ANALYSIS);
            }
        }

        if not self.blocked
            and self.compiler._count_module_errors(self.program, self.module_path)
                > 0 {
            self.blocked = True;
        }
    }

    def boundaries {
        import from jaclang.compiler.pipeline.schedule { get_boundary_analysis_sched }
        if (
            not self.parse_failed
            and not self.blocked
            and not self.options.symtab_ir_only
        ) {
            import from jaclang.compiler.pipeline.products { require_product }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            require_product(self.program, self.module, CompilationProduct.BOUNDARIES);
        }
    }

    def native_checks {
        import from jaclang.compiler.api { module_spaces }
        if (
            self.options.no_cgen
            and self.options.native_parity
            and not self.options.symtab_ir_only
            and not self.parse_failed
            and not self.blocked
            and self.program.analysis.provides(self.module, AnalysisFact.TYPE_OF)
        ) {
            import from jaclang.compiler.analysis.binding.module_facts {
                ModuleFacts as _PtyMcp
            }
            if self.native or module_spaces(self.program, self.module).has_native {
                import from jaclang.compiler.pipeline.products { require_product }
                import from jaclang.compiler.pipeline.contracts { CompilationProduct }
                require_product(
                    self.program, self.module, CompilationProduct.NATIVE_IR
                );
            }
        }
    }

    def client_dependencies {
        if not self.parse_failed
            and not self.blocked
            and not self.options.symtab_ir_only
            and not self.options.no_cgen {
            import from jaclang.compiler.pipeline.products { require_product }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            require_product(
                self.program, self.module, CompilationProduct.CLIENT_DEPENDENCIES
            );
        }
    }

    def interface {
        if not self.parse_failed
            and not self.blocked
            and self.source is None
            and self.options.no_cgen
            and not self.options.symtab_ir_only {
            import from jaclang.compiler.pipeline.products { require_product }
            import from jaclang.compiler.pipeline.contracts { CompilationProduct }
            require_product(self.program, self.module, CompilationProduct.INTERFACE);
        }
    }

    def codegen {
        import from jaclang.compiler.api { module_spaces }
        import from jaclang.compiler.pipeline.schedule {
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

            import from jaclang.compiler.analysis.binding.module_facts { ModuleFacts }
            needs_native = self.native
                or module_spaces(self.program, self.module).has_native;

            if needs_native
                and not self.program.analysis.provides(
                    self.module, AnalysisFact.TYPE_OF
                ) {
                import from jaclang.compiler.pipeline.products { require_product }
                import from jaclang.compiler.pipeline.contracts { CompilationProduct }
                require_product(self.program, self.module, CompilationProduct.ANALYSIS);
                if not self.program.analysis.provides(
                    self.module, AnalysisFact.TYPE_OF
                ) {
                    self.blocked = True;
                    return;
                }
            }
            execute_passes(
                module=self.module,
                program=self.program,
                passes=get_py_code_gen(
                    native=needs_native,
                    provided=self.program.analysis.provided(self.module)
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
    import from jaclang.compiler.session.options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    import from jaclang.compiler.analysis.placement.native_fallback {
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
        if (ir is None) or (artifact_for(ir).llvm_ir is None) {
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
