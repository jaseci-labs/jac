import type from jaclang.project.config { JacConfig }
import type from jaclang.compiler.session.services { AnalysisServices }
import os;
import from collections.abc { Sequence }
import from jaclang.compiler.pipeline.pass_base { Alert, DiagnosticPolicy }
import from jaclang.compiler.session.session { JacProgram }


def diagnostic_policy_for(
    config: JacConfig | None, extra_suppress_tokens: (list[str] | None) = None
) -> DiagnosticPolicy {
    import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
    tokens: list[str] = [];
    categories: list[str] = [];
    lint_active = False;
    lint_select: list[str] = [];
    lint_ignore: list[str] = [];
    check = config.check if (config and config.check) else None;
    if check is not None {
        if check.suppress {
            tokens = list(check.suppress);
        }
        if check.suppress_categories {
            categories = list(check.suppress_categories);
        }
        lint = check.lint;
        if lint {
            lint_active = True;
            lint_select = list(lint.select);
            lint_ignore = list(lint.ignore);
        }
    }
    if extra_suppress_tokens {
        tokens.extend(extra_suppress_tokens);
    }
    resolved: list[str] = [];
    if tokens {
        (resolved, _unknown) = resolve_diagnostic_tokens(tokens);
    }
    return DiagnosticPolicy(
        suppress_codes=resolved,
        suppress_categories=categories,
        lint_active=lint_active,
        lint_select=lint_select,
        lint_ignore=lint_ignore
    );
}

def config_for_app(config: JacConfig | None, app_name: str) -> JacConfig | None {
    if config is None or not app_name {
        return config;
    }
    apps = config?.apps;
    if not isinstance(apps, dict) or app_name not in apps {
        return config;
    }
    try {
        return config.effective_for_app(app_name);
    } except Exception {
        return config;
    }
}

def build_diagnostic_policy(prog: AnalysisServices) -> DiagnosticPolicy {
    config: JacConfig | None = None;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
    } except Exception {
        config = None;
    }
    opts = prog.options;
    config = config_for_app(config, opts.target_app if opts is not None else '');
    extra: list[str] = (
        list(opts.suppress_codes) if (opts is not None and opts.suppress_codes) else []
    );
    return diagnostic_policy_for(config, extra);
}

def _alert_in_internal_stub(loc_path: str) -> bool {
    if not loc_path.endswith('.pyi') {
        return False;
    }
    _p = os.path.realpath(loc_path);
    _pkg = os.path.realpath(
        os.path.dirname(os.path.dirname(os.path.abspath(str(__file__))))
    );
    if _p.startswith(_pkg + os.sep) {
        return True;
    }
    return (os.sep + 'typeshed' + os.sep) in _p;
}

def deliver_alerts(
    errors: Sequence[Alert],
    warnings: Sequence[Alert],
    prog: AnalysisServices,
    policy: (DiagnosticPolicy | None) = None
) {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    for alrt in errors {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        if alrt.code is not None
            and not alrt.code.code.startswith("E9")
            and _alert_in_internal_stub(str(alrt.loc.mod_path or "")) {
            continue;
        }
        prog.errors_had.append(alrt);
    }
    for alrt in warnings {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        if alrt.code is not None
            and _alert_in_internal_stub(str(alrt.loc.mod_path or "")) {
            continue;
        }
        prog.warnings_had.append(alrt);
    }
}
