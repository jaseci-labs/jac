import type from jaclang.compiler.session.services { AnalysisServices }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.session.session { JacProgram }

import from jaclang.compiler.pipeline.program_pass { ProgramTransform }

walker AppContextPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        stamp_app_facts(ir_in, self.prog);
        stamp_access_check_facts(ir_in);
        return ir_in;
    }
}

def stamp_app_facts(mod: uni.Module, target_program: AnalysisServices) {
    import from jaclang.compiler.session.resolver { find_jac_project_root }
    import from jaclang.compiler.session.workspace { workspace_for_path }
    opts = target_program.options;
    mod_path = mod.loc.mod_path if mod.loc else '';
    mod.jac_project_root = find_jac_project_root(mod_path) if mod_path else None;
    ws = workspace_for_path(mod_path) if mod_path else None;
    app = ws.app_for_path(mod_path) if ws is not None else None;
    if app is None and ws is not None and opts.target_app {
        app = ws.apps.get(opts.target_app);
    }
    mod.app = app.name if app is not None else None;
    mod.app_root = ws.project_root if (app is not None and ws is not None) else None;
    target_kind = opts.app_kind if (opts is not None and opts.app_kind) else '';
    if app is not None {
        mod.app_kind = app.kind;
    } elif target_kind {
        mod.app_kind = target_kind;
    } else {
        mod.app_kind = '';
    }
    import from jaclang.compiler.session.workspace { UI_MOBUI }
    override_ui = opts.ui if (opts is not None and opts.ui) else '';
    ui = override_ui or (app.ui if app is not None else '');
    if ui == UI_MOBUI {
        enforced_root: (str | None) = None;
        if override_ui and opts.project_root {
            enforced_root = opts.project_root;
        }
        if enforced_root is None and ws is not None {
            enforced_root = ws.project_root;
        }
        if enforced_root is None {
            enforced_root = mod.jac_project_root;
        }
        mod.mobui_enforced_root = enforced_root;
    } else {
        mod.mobui_enforced_root = None;
    }
}

def stamp_access_check_facts(mod: uni.Module) {
    enforce = False;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if (config and config.check) {
            enforce = config.check.enforce_access;
        }
    } except Exception {
        enforce = False;
    }
    mod.access_enforced = enforce;
}
