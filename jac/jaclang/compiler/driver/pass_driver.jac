import atexit;
import os;
import sys;
import from collections.abc { Callable, Iterator }
import from contextlib { contextmanager }
import from jaclang.compiler.passes.transform { DiagnosticPolicy }
import from jaclang.compiler.driver.program { JacProgram }

def diagnostic_policy_for(
    config: any, extra_suppress_tokens: (list | None) = None
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

def build_diagnostic_policy(prog: JacProgram) -> DiagnosticPolicy {
    config: any = None;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
    } except Exception {
        config = None;
    }
    opts = prog.options;
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
    errors: list,
    warnings: list,
    prog: JacProgram,
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

def run_pass(
    pass_cls: type,
    ir_in: any,
    prog: JacProgram,
    cancel_token: any = None,
    policy: (DiagnosticPolicy | None) = None,
    **kwargs: any
) -> any {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    errors: list = [];
    warnings: list = [];
    inst: any = None;
    if getattr(pass_cls, 'HOST_PASS', False) {
        kwargs['prog'] = prog;
    }
    try {
        inst = pass_cls(
            ir_in=ir_in,
            cancel_token=cancel_token,
            cancel_requested=bool(cancel_token is not None and cancel_token.is_set()),
            policy=pol,
            errors_had=errors,
            warnings_had=warnings,
            **kwargs
        );
    } finally {
        eff = inst.policy if (inst is not None and inst.policy is not None) else pol;
        deliver_alerts(errors, warnings, prog, eff);
        try {
            ledger = prog.analysis;
            pass_name = pass_cls.__name__;
            ledger.pass_runs[pass_name] = ledger.pass_runs.get(pass_name, 0) + 1;
            if inst is not None {
                ledger.pass_time[pass_name] = (
                    ledger.pass_time.get(pass_name, 0.0) + inst.time_taken
                );
            }
        } except Exception {}
    }
    return inst;
}

obj _SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _seen_files: set[str] postinit,
        _jaclang_root: (str | None) = None,
        _first_compile_at: (float | None) = None;

    def postinit -> None;
    def _get_jaclang_root -> str;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;
    def on_kernel_build(lib_path: str) -> None;
    def _precompile_limit -> int;
    def _halt_at_limit -> None;

    has is_active: bool { getter; }
}

glob setup_progress = _SetupProgress();

obj CompileProgress {
    has _listeners: list[Callable[[str], None]] postinit;

    def postinit -> None;
    def notify(file_path: str) -> None;
    @contextmanager
    def listen(callback: Callable[[str], None]) -> Iterator[None];
}

glob compile_progress = CompileProgress();
