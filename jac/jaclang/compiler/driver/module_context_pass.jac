import os;
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.driver.boundary_classify {
    _coerce_client_module,
    _coerce_native_module,
    _default_codespace_for
}
import from jaclang.compiler.driver.na_coverage { na_coverage_record }

walker ModuleContextPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def transform(ir_in: uni.Module) -> uni.Module {
        if ir_in.is_raised_from_py or ir_in.stub_only {
            return ir_in;
        }
        compiler = self.prog._get_compiler();
        target_program = self.prog;
        file_path = ir_in.loc.mod_path;
        mod = ir_in;
        run_codespace_infer = False;
        codespace = '';
        import from jaclang.compiler.frontend.codeinfo {
            is_client_by_location as _cbl,
            is_native_by_location as _nbl
        }
        if _nbl(file_path) {
            codespace = 'native';
        }
        if not codespace and _cbl(file_path) {
            codespace = 'client';
        }
        if not codespace {
            import from jaclang.compiler.placement.placement_pins {
                effective_module_pin as _mod_pin
            }
            _pinned_space = _mod_pin(file_path);
            if _pinned_space in ('client', 'native') {
                codespace = _pinned_space;
            }
        }
        if not codespace {
            import from jaclang.compiler.native_scope {
                in_native_scope_path as _in_scope,
                scope_lowering_active as _scope_on
            }
            if _scope_on() and _in_scope(file_path) {
                codespace = 'native';
            }
        }
        if not codespace {
            _p_opts = target_program.options;
            _forced_pre = _p_opts.force_codespace if _p_opts is not None else '';
            if (
                not _forced_pre
                and _p_opts is not None
                and _p_opts.aot_mode
                and not compiler.selfhost.is_selfhost(target_program)
                and _default_codespace_for(target_program) == 'native'
            ) {
                _forced_pre = 'native';
            }
            if _forced_pre and not compiler.selfhost.is_selfhost(target_program) {
                codespace = _forced_pre;
            }
        }
        if not codespace and not compiler.selfhost.is_selfhost(target_program) {
            import from jaclang.compiler.placement.placement_pins {
                config_kind_space as _kind_space_of
            }
            _k_opts = target_program.options;
            _kind_space = _kind_space_of(
                file_path, _k_opts.app_kind if _k_opts is not None else ''
            );
            if _kind_space in ('client', 'native') {
                codespace = _kind_space;
            }
        }
        if (codespace == 'client') {
            _coerce_client_module(mod);
        } elif (codespace == 'native') {
            _coerce_native_module(mod);
            na_coverage_record(mod.loc.mod_path, 'native');
        } elif codespace == 'server' {
            mod.set_code_context(CodeContext.SERVER);
        } else {
            run_codespace_infer = True;
        }
        if run_codespace_infer {
            _opts = target_program.options;
            _analysis_only = _opts is not None and _opts.no_cgen;
            import from jaclang.compiler.native_scope {
                in_native_scope_path,
                scope_lowering_active
            }
            _scope_native = (
                scope_lowering_active() and in_native_scope_path(mod.loc.mod_path or '')
            );
            _native_eligible = (
                not _analysis_only
                and (
                    _scope_native
                    or (
                        not compiler.selfhost.is_selfhost(target_program)
                        and _default_codespace_for(target_program) == 'native'
                    )
                )
            );
            if _native_eligible {
                (_na_ok, _na_why) = native_default_verdict(mod, target_program);
                if _na_ok {
                    _coerce_native_module(mod);
                    mod.codespace_inferred = True;
                    na_coverage_record(mod.loc.mod_path, 'native');
                } elif _na_why == 'previously-demoted' {
                    import from jaclang.compiler.placement.placement_pins {
                        _demoted_native_code
                    }
                    na_coverage_record(
                        mod.loc.mod_path,
                        'demoted',
                        _demoted_native_code(os.path.realpath(mod.loc.mod_path)),
                        _na_why
                    );
                } else {
                    na_coverage_record(mod.loc.mod_path, 'server', '', _na_why);
                }
            }
        }
        return ir_in;
    }
}

def native_default_verdict(module: uni.Module, prog: JacProgram) -> tuple[bool, str] {
    import from jaclang.compiler.driver.pipeline { native_pipeline_available }
    import from jaclang.compiler.placement.placement_pins { _is_demoted_native }

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
    import from jaclang.compiler.native_scope {
        in_native_scope_path,
        scope_lowering_active
    }
    if in_native_scope_path(mod_path) and not scope_lowering_active() {
        return (False, "compiler frontend module: native only inside the kernel build");
    }
    if not any([isinstance(e, uni.ElementStmt) for e in module.body]) {
        return (False, "empty module: nothing to lower");
    }
    import from jaclang.compiler.placement.placement { scan_native_blockers }
    import from jaclang.compiler.driver.pipeline { native_closure_eligible }
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
