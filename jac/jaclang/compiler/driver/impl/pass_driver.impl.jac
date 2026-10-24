impl CompileProgress.postinit -> None {
    self._listeners = [];
    self._finished_listeners = [];
}

impl CompileProgress.notify(file_path: str) -> None {
    for callback in list(self._listeners) {
        callback(file_path);
    }
}

@contextmanager
impl CompileProgress.track(file_path: str) -> Iterator[None] {
    finished = list(self._finished_listeners);
    self.notify(file_path);
    try {
        yield None;
    } finally {
        for callback in finished {
            if callback in self._finished_listeners {
                callback(file_path);
            }
        }
    }
}

@contextmanager
impl CompileProgress.listen(
    callback: Callable[[str], None], on_finished: Callable[[str], None] | None = None
) -> Iterator[None] {
    self._listeners.append(callback);
    if on_finished is not None {
        self._finished_listeners.append(on_finished);
    }
    try {
        yield None;
    } finally {
        self._listeners.remove(callback);
        if on_finished is not None {
            self._finished_listeners.remove(on_finished);
        }
    }
}

impl diagnostic_policy_for(
    check: CheckSettings, extra_suppress_tokens: (list[str] | None) = None
) -> DiagnosticPolicy {
    tokens: list[str] = list(check.suppress);
    if extra_suppress_tokens {
        tokens.extend(extra_suppress_tokens);
    }
    resolved: list[str] = [];
    if tokens {
        (resolved, _unknown) = resolve_diagnostic_tokens(tokens);
    }
    return DiagnosticPolicy(
        suppress_codes=resolved,
        suppress_categories=list(check.suppress_categories),
        lint_active=check.lint_active,
        lint_select=list(check.lint_select),
        lint_ignore=list(check.lint_ignore)
    );
}

impl build_diagnostic_policy(prog: JacProgram) -> DiagnosticPolicy {
    opts = prog.options;
    check = active_host().check_settings(opts.target_app if opts is not None else '');
    extra: list[str] = (
        list(opts.suppress_codes) if (opts is not None and opts.suppress_codes) else []
    );
    return diagnostic_policy_for(check, extra);
}

impl _alert_in_internal_stub(loc_path: str) -> bool {
    if not loc_path.endswith('.pyi') {
        return False;
    }
    _p = os.path.realpath(loc_path);
    _pkg = os.path.realpath(os.path.join(jaclang_pkg_root(), 'compiler'));
    if _p.startswith(_pkg + os.sep) {
        return True;
    }
    return (os.sep + 'typeshed' + os.sep) in _p;
}

impl deliver_alerts(
    errors: Sequence[Alert],
    warnings: Sequence[Alert],
    prog: JacProgram,
    policy: (DiagnosticPolicy | None) = None,
    module_path: str = ""
) {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    drop_toolchain = not prog.toolchain_dependency(module_path);
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
        if drop_toolchain and prog.toolchain_dependency(str(alrt.loc.mod_path or "")) {
            continue;
        }
        prog.warnings_had.append(alrt);
    }
}
