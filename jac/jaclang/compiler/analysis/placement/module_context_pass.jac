import type from jaclang.compiler.session.services { AnalysisServices }
import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import from jaclang.compiler.session.session { JacProgram }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.analysis.boundaries.classify {
    _coerce_client_module,
    _coerce_native_module,
    _default_codespace_for
}
import from jaclang.compiler.analysis.placement.native_fallback { na_coverage_record }

walker ModuleContextPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        if ir_in.is_raised_from_py or ir_in.stub_only {
            return ir_in;
        }
        import from jaclang.compiler.session.native_resolution {
            is_client_by_location,
            is_native_by_location
        }
        import from jaclang.compiler.analysis.placement.pins {
            effective_module_pin,
            config_kind_space,
            _demoted_native_code
        }
        import from jaclang.compiler.bootstrap.native_scope {
            in_native_scope_path,
            scope_lowering_active
        }
        options = self.prog.options;
        path = ir_in.loc.mod_path;
        internal = self.prog.is_bootstrap();
        space = 'native'
            if is_native_by_location(path)
            else (
                'client' if is_client_by_location(path) else effective_module_pin(path)
            );
        if space not in ('native', 'client') {
            space = '';
        }
        if not space and scope_lowering_active() and in_native_scope_path(path) {
            space = 'native';
        }
        if not space and not internal {
            space = options.force_codespace;
            if not space
                and options.aot_mode
                and _default_codespace_for(self.prog) == 'native' {
                space = 'native';
            }
            if not space {
                kind_space = config_kind_space(path, options.app_kind);
                if kind_space in ('native', 'client') {
                    space = kind_space;
                }
            }
        }
        if space == 'client' {
            _coerce_client_module(ir_in);
            return ir_in;
        }
        if space == 'native' {
            _coerce_native_module(ir_in);
            na_coverage_record(path, 'native');
            return ir_in;
        }
        if space == 'server' {
            ir_in.set_code_context(CodeContext.SERVER);
            return ir_in;
        }
        if internal
            or options.no_cgen
            or _default_codespace_for(self.prog) != 'native' {
            return ir_in;
        }
        (eligible, reason) = native_default_verdict(ir_in, self.prog);
        if eligible {
            _coerce_native_module(ir_in);
            ir_in.codespace_inferred = True;
            na_coverage_record(path, 'native');
        } elif reason == 'previously-demoted' {
            na_coverage_record(
                path, 'demoted', _demoted_native_code(os.path.realpath(path)), reason
            );
        } else {
            na_coverage_record(path, 'server', '', reason);
        }
        return ir_in;
    }
}


def native_default_verdict(
    module: uni.Module, prog: AnalysisServices
) -> tuple[bool, str] {
    import from jaclang.compiler.pipeline.schedule { native_pipeline_available }
    import from jaclang.compiler.analysis.placement.pins { _is_demoted_native }

    if module.app_kind == 'web-app' {
        return (False, "web-app project: native is opt-in");
    }
    (env_ok, env_reason) = native_pipeline_available();
    if not env_ok {
        return (False, env_reason);
    }
    mod_path = module.loc.mod_path if module.loc is not None else '';
    if not mod_path {
        return (False, "no module path");
    }
    if _is_demoted_native(os.path.realpath(mod_path)) {
        return (False, "previously-demoted");
    }
    import from jaclang.compiler.bootstrap.native_scope {
        in_native_scope_path,
        scope_lowering_active
    }
    if in_native_scope_path(mod_path) and not scope_lowering_active() {
        return (False, "compiler frontend module: native only inside the kernel build");
    }
    if not any([isinstance(e, uni.ElementStmt) for e in module.body]) {
        return (False, "empty module: nothing to lower");
    }
    import from jaclang.compiler.analysis.placement.evidence { scan_native_blockers }
    import from jaclang.compiler.api { native_closure_eligible }
    base_dir = os.path.dirname(os.path.abspath(mod_path)) or '.';
    (sv_reason, deps) = scan_native_blockers(module, base_dir);
    if sv_reason {
        return (False, sv_reason);
    }
    if not native_closure_eligible(prog, module, deps) {
        return (False, "import-closure (sv dep or cap)");
    }
    return (True, '');
}
