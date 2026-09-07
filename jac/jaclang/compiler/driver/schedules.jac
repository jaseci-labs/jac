import os;
import from contextvars { ContextVar }
import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
import from jaclang.compiler.driver.source_failures { fail_loud_on_compiler_source }

def get_symtab_ir_sched -> list[type[Transform]] {
    if not schedule_tier_reason() {
        _tok = _ir_sched_loading.set(True);
        try {
            _import_all(SYMTAB_SCHED_DEPS);
        } except ImportError as e {
            fail_loud_on_compiler_source(e);
        } finally {
            _ir_sched_loading.reset(_tok);
        }
    }
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, PlacementApplyPass],
        origin='symtab-ir schedule'
    );
}

glob _ir_sched_loading = ContextVar('jac_ir_sched_loading', `default=False),
     _codegen_sched_loading = ContextVar('jac_codegen_sched_loading', `default=False),
     _analysis_sched_loading = ContextVar('jac_analysis_sched_loading', `default=False);

glob SYMTAB_SCHED_DEPS: tuple = ('jaclang.compiler.symbol_utils', ),
     IR_SCHED_DEPS: tuple = (
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.intrinsic_registry',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.types.stubcat.modiface',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.layout_pass',
         'jaclang.compiler.passes.cfg_build_pass',
         'jaclang.compiler.passes.sem_def_match_pass',
         'jaclang.compiler.passes.jsx_intrinsic_guard_pass',
         'jaclang.compiler.passes.mtir_gen_pass',
         'jaclang.compiler.passes.comptime_resolve_pass',
         'jaclang.project.mobui_scope'
     ),
     ANALYSIS_SCHED_DEPS: tuple = (
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.passes.type_checker_pass',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.types.type_utils',
         'jaclang.compiler.types.ts_decl_parser',
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.driver.bccache',
         'jaclang.compiler.frontend.codeinfo',
         'jaclang.compiler.frontend.diagnostic_utils',
         'jaclang.compiler.driver.modresolver',
         'jaclang.project.tomlio',
         'jaclang.project.mobui_scope',
         'jaclang.project.config',
         'jaclang.compiler.passes.static_analysis_pass',
         'jaclang.compiler.passes.access_check_pass',
         'jaclang.compiler.passes.variant_agreement_pass',
         'jaclang.compiler.passes.capability_check_pass',
         'jaclang.compiler.passes.ownership_check_pass',
         'jaclang.compiler.passes.region_infer_pass',
         'jaclang.compiler.tools.jac_auto_lint_pass'
     ),
     CODEGEN_SCHED_DEPS: tuple = (
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.passes.freeze_structure_pass'
     ),
     NATIVE_CODEGEN_DEPS: tuple = ('jaclang.compiler.backends.native', );

def module_in_flight(names: tuple) -> str {
    import sys;
    for name in names {
        spec = sys.modules.get(name)?.__spec__;
        if spec is not None and getattr(spec, '_initializing', False) {
            return name;
        }
    }
    return '';
}

def _import_all(names: tuple) {
    import importlib;
    for name in names {
        importlib.import_module(name);
    }
}

def schedule_tier_reason -> str {
    if _ir_sched_loading.get() {
        return 'the ir-gen schedule was still loading';
    }
    dep = module_in_flight(IR_SCHED_DEPS);
    if dep {
        return f"'{dep}', a dependency of the ir-gen schedule, was mid-import";
    }
    return '';
}

def _codegen_tier_reason -> str {
    if _codegen_sched_loading.get() {
        return 'the codegen schedule was still loading';
    }
    dep = module_in_flight(CODEGEN_SCHED_DEPS + NATIVE_CODEGEN_DEPS);
    if dep {
        return f"'{dep}', a dependency of the codegen schedule, was mid-import";
    }
    return schedule_tier_reason();
}

def pass_requires(p: type[Transform]) -> tuple {
    return getattr(p, 'REQUIRES', ()) or ();
}

def pass_provides(p: type[Transform]) -> tuple {
    return getattr(p, 'PROVIDES', ()) or ();
}

def validate_schedule(
    passes: list[type[Transform]],
    preprovided: (set[str] | None) = None,
    origin: str = 'schedule'
) -> list[type[Transform]] {
    provided: set[str] = set(preprovided) if preprovided is not None else set();
    for p in passes {
        for tag in pass_requires(p) {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.__name__} requires analysis "
                    f"'{tag}' which is neither provided by an earlier pass in "
                    f"the {origin} nor already available -- the schedule was "
                    f"constructed missing a declared dependency."
                );
            }
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
    return passes;
}

class TypeshedUnavailableError(RuntimeError) {}

glob _native_sched_failure: dict[str, str] = {};

def _note_native_schedule_failure(err: (BaseException | None)) {
    if err is None {
        _native_sched_failure.pop('reason', None);
    } else {
        _native_sched_failure['reason'] = f"{type(err).__name__}: {err}";
    }
}

def native_schedule_failure -> str {
    return _native_sched_failure.get('reason', '');
}

def get_boundary_analysis_sched -> list[type[Transform]] {
    return validate_schedule(
        [BoundaryAnalysisPass, EndpointEffectPass], origin='boundary-analysis schedule'
    );
}

def get_bootstrap_ir_sched -> list[type[Transform]] {
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass],
        origin='bootstrap-ir schedule'
    );
}

def get_ir_gen_sched(
    is_internal: bool = False, gen_mtir: bool = True
) -> list[type[Transform]] {
    if schedule_tier_reason() {
        return get_bootstrap_ir_sched();
    }
    _tok = _ir_sched_loading.set(True);
    try {
        _import_all(IR_SCHED_DEPS);
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
        import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }

        passes: list[type[Transform]] = [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass
        ];
        if gen_mtir {
            import from jaclang.compiler.passes.mtir_gen_pass { MTIRGenPass }
            passes.append(MTIRGenPass);
        }
        passes.append(JsxIntrinsicGuardPass);
        passes.append(PlacementApplyPass);
        import from jaclang.compiler.passes.comptime_resolve_pass {
            ComptimeResolvePass
        }
        passes.append(ComptimeResolvePass);
        return validate_schedule(passes, origin='ir-gen schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def typeshed_stubs_available -> bool {
    import jaclang;
    return os.path.exists(
        os.path.join(
            os.path.dirname(str(jaclang.__file__)),
            'vendor',
            'typeshed',
            'stdlib',
            'builtins.pyi'
        )
    );
}

def require_typeshed_stubs -> None {
    import from jaclang.jac0core.stubcat_hook { active }
    if active() is not None or typeshed_stubs_available() {
        return;
    }
    raise TypeshedUnavailableError(
        "type inference is on the critical path of every compilation, but this "
        "environment has neither a stub catalog nor the vendored typeshed stdlib "
        "stubs, so no module can be compiled. In a source checkout run "
        "'zig build fetch-typeshed'; in an installed environment reinstall the "
        "jac distribution, whose payload carries the catalog."
    );
}

def get_analysis_sched -> list[type[Transform]] {
    if _analysis_sched_loading.get() or module_in_flight(ANALYSIS_SCHED_DEPS) {
        return [];
    }
    require_typeshed_stubs();
    _tok = _analysis_sched_loading.set(True);
    try {
        _import_all(ANALYSIS_SCHED_DEPS);
        import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
        import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
        import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.variant_agreement_pass {
            VariantAgreementPass
        }
        import from jaclang.compiler.passes.capability_check_pass {
            ClientCapabilityCheckPass,
            NativeCapabilityCheckPass,
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
        import from jaclang.compiler.passes.region_infer_pass { RegionInferPass }
        import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
        return validate_schedule(
            [
                RegionInferPass,
                VariantAgreementPass,
                TypeCheckPass,
                StaticAnalysisPass,
                AccessCheckPass,
                OwnershipCheckPass,
                NativeCapabilityCheckPass,
                ClientCapabilityCheckPass,
                PortabilityWarnPass,
                JacLintCheckPass
            ],
            preprovided={'CfgSucc'},
            origin='analysis schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        raise;
    } finally {
        _analysis_sched_loading.reset(_tok);
    }
}

glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if (
        _analysis_sched_loading.get()
        or _ir_sched_loading.get()
        or _codegen_sched_loading.get()
    ) {
        return (True, '');
    }
    reason = '';
    try {
        import from jaclang.compiler.backends.native.llvm.binding.ffi { _find_shim }
        _find_shim();
    } except ModuleNotFoundError {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return (False, 'native pipeline undecided: the compiler is still initializing');
    } except Exception {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}

def _py_codegen_tail -> list[type[Transform]] {
    return [JcirGenPass, JcirBytecodeGenPass];
}

def get_py_code_gen(
    native: bool = True, provided: (set[str] | None) = None
) -> list[type[Transform]] {
    if _codegen_tier_reason() {
        return _py_codegen_tail();
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        _import_all(CODEGEN_SCHED_DEPS);
        import from jaclang.compiler.backends.es { EsastGenPass }
        import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }

        passes: list[type[Transform]] = [RcFactsPass, EsastGenPass];
        if native {
            _import_all(NATIVE_CODEGEN_DEPS);
            import from jaclang.compiler.backends.native {
                NaIRGenPass,
                NativeCompilePass
            }
            passes.extend([NaIRGenPass, NativeCompilePass]);
            _note_native_schedule_failure(None);
        }
        passes.extend(_py_codegen_tail());
        import from jaclang.compiler.passes.freeze_structure_pass {
            FreezeStructurePass
        }
        passes.append(FreezeStructurePass);
        return validate_schedule(
            passes,
            preprovided={'CfgSucc'} if provided is None else provided,
            origin='codegen schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if native {
            _note_native_schedule_failure(e);
        }
        return _py_codegen_tail();
    } finally {
        _codegen_sched_loading.reset(_tok);
    }
}

def get_compile_sched(
    gen_mtir: bool = True, native: bool = True
) -> list[type[Transform]] {
    analyzed = get_ir_gen_sched(gen_mtir=gen_mtir)
        + get_analysis_sched()
        + get_boundary_analysis_sched();
    return validate_schedule(
        analyzed + get_py_code_gen(native=native, provided=providers_of(analyzed)),
        origin='compile schedule'
    );
}

def providers_of(passes: list[type[Transform]]) -> set[str] {
    out: set[str] = set();
    for p in passes {
        for tag in pass_provides(p) {
            out.add(tag);
        }
    }
    return out;
}

def get_format_sched(auto_lint: bool = False) -> list[type[Transform]] {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return validate_schedule(
            [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass],
            origin='format schedule'
        );
    }
    return validate_schedule(
        [CommentAttachPass, DocIRGenPass, JacFormatPass], origin='format schedule'
    );
}

def get_lint_sched -> list[type[Transform]] {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
}
