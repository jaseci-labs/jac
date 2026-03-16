"""Implementation for transform constructs."""

"""Initialize alert."""
impl Alert.init(
    self: Alert,
    msg: str,
    loc: CodeLocInfo,
    from_pass: type[Transform],
    code: DiagnosticInfo | None = None,
    related: list[tuple[str, CodeLocInfo]] | None = None,
    help_text: str | None = None
) -> None {
    self.msg = msg;
    self.loc: CodeLocInfo = loc;
    self.from_pass: type[Transform] = from_pass;
    self.code: DiagnosticInfo | None = code;
    self.related: list[tuple[str, CodeLocInfo]] = related or [];
    self.help_text: str | None = help_text or (code.help_text if code else None);
}

"""Return string representation of alert."""
impl Alert.__str__(self: Alert) -> str {
    return f"{self.loc.mod_path}, line {self.loc.first_line}, col {self.loc.col_start}: {self.msg}";
}

"""Return string representation of alert."""
impl Alert.__repr__(self: Alert) -> str {
    return self.as_log();
}

"""Return the alert as a single line log as opposed to the pretty print."""
impl Alert.as_log(self: Alert, *, colors: bool = False) -> str {
    import from jaclang.jac0core.helpers { ANSIColors }
    import from jaclang.jac0core.diagnostics { Severity }
    file_path: str = self.loc.mod_path;
    if self.code {
        # Structured format: error[E1001]: message
        sev_label = self.code.severity.value;
        code_str = self.code.code;
        if colors {
            color = ANSIColors.RED
                if (self.code.severity == Severity.ERROR)
                else ANSIColors.YELLOW;
            header = f"{color}{sev_label}[{code_str}]{ANSIColors.END}: {self.msg}";
        } else {
            header = f"{sev_label}[{code_str}]: {self.msg}";
        }
        if (file_path == '') {
            return header;
        }
        return f"{header}\n  --> {file_path}:{self.loc.first_line}:{self.loc.col_start}";
    }
    # Legacy format for un-migrated callsites
    if (file_path == '') {
        return self.msg;
    }
    line: int = self.loc.first_line;
    column: int = self.loc.col_start;
    msg = self.msg if not colors else f"{ANSIColors.RED}{self.msg}{ANSIColors.END}";
    return f"{file_path}:{line}:{column} {msg}";
}

"""Pretty prints the Alert to show the alert with source location."""
impl Alert.pretty_print(self: Alert, *, colors: bool = False) -> str {
    import from jaclang.jac0core.helpers {
        pretty_print_source_location,
        format_related_spans
    }
    pretty_dump = pretty_print_source_location(
        self.loc.mod_path,
        self.loc.orig_src.code,
        self.loc.first_line,
        self.loc.pos_start,
        self.loc.pos_end,
        colors=colors
    );
    if (pretty_dump != '') {
        pretty_dump = '\n' + pretty_dump;
    }
    result = self.as_log(colors=colors) + pretty_dump;
    # Render related spans
    if self.related {
        result += format_related_spans(self.related, colors=colors);
    }
    # Render help text
    if self.help_text {
        import from jaclang.jac0core.helpers { ANSIColors }
        if colors {
            result += f"\n{ANSIColors.CYAN}help{ANSIColors.END}: {self.help_text}";
        } else {
            result += f"\nhelp: {self.help_text}";
        }
    }
    return result;
}

"""Initialize pass."""
impl BaseTransform.init(
    self: BaseTransform,
    ir_in: T_in,
    prog: JacProgram,
    cancel_token: (Event | None) = None
) -> None {
    self.logger = logging.getLogger(self.__class__.__name__);
    self.errors_had: list[Alert] = [];
    self.warnings_had: list[Alert] = [];
    self.prog = prog;
    self.time_taken = 0.0;
    self.ir_in: T_in = ir_in;
    self.cancel_token = cancel_token;
    self.pre_transform();
    self.ir_out: T_out = self.timed_transform(ir_in=ir_in);
    self.post_transform();
}

"""Transform with time tracking."""
impl BaseTransform.timed_transform(self: BaseTransform, ir_in: T_in) -> T_out {
    start_time = time.time();
    ir_out = self.transform(ir_in=ir_in);
    self.time_taken = time.time() - start_time;
    return ir_out;
}

"""Pre-transform hook."""
impl BaseTransform.pre_transform(self: BaseTransform) -> None {
    ;
}

"""Post-transform hook."""
impl BaseTransform.post_transform(self: BaseTransform) -> None {
    ;
}

"""Transform interface."""
@abstractmethod
impl BaseTransform.transform(self: BaseTransform, ir_in: T_in) -> T_out {
    ;
}

"""Log info."""
impl BaseTransform.log_info(self: BaseTransform, msg: str) -> None {
    self.logger.info(msg);
}

"""Check if the pass has been canceled."""
impl BaseTransform.is_canceled(self: BaseTransform) -> bool {
    return ((self.cancel_token is not None) and self.cancel_token.is_set());
}

"""Initialize pass."""
impl Transform.init(
    self: Transform, ir_in: T, prog: JacProgram, cancel_token: (Event | None) = None
) -> None {
    self.cur_node: UniNode = ir_in;
    super.init(ir_in, prog, cancel_token);
}

"""Emit a structured diagnostic. Returns True if emitted (not suppressed)."""
impl Transform.emit(
    self: Transform,
    diag: DiagnosticInfo,
    node_override: (UniNode | None) = None,
    related: (list[tuple[str, UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: Any
) -> bool {
    import from jaclang.jac0core.diagnostics { Severity }
    # Determine location early (needed for inline suppression check)
    loc = node_override.loc if node_override else self.cur_node.loc;
    # Check suppression (project config + inline comments)
    if self._is_suppressed(diag, loc) {
        return False;
    }
    # Format message from template
    msg = diag.format_message(**kwargs);
    # Build related spans
    related_locs: list[tuple[str, CodeLocInfo]] = [];
    if related {
        for (label, node) in related {
            related_locs.append((label, node.loc));
        }
    }
    alrt = Alert(
        msg=msg,
        loc=loc,
        from_pass=self.__class__,
        code=diag,
        related=related_locs,
        help_text=help_text
    );
    # Route by severity
    if (diag.severity == Severity.ERROR) {
        self.errors_had.append(alrt);
        self.prog.errors_had.append(alrt);
    } else {
        self.warnings_had.append(alrt);
        self.prog.warnings_had.append(alrt);
    }
    return True;
}

"""Check if a diagnostic code is suppressed by project config or inline comment."""
impl Transform._is_suppressed(
    self: Transform, diag: DiagnosticInfo, loc: CodeLocInfo | None = None
) -> bool {
    import from jaclang.jac0core.diagnostics { LINT_ALIASES, DIAGNOSTICS }
    # Check inline suppression: # jac:ignore[CODE]
    if loc {
        try {
            source = loc.orig_src;
            if (source and source?.inline_suppressions and source.inline_suppressions) {
                line = loc.first_line;
                if line in source.inline_suppressions {
                    suppressed_codes = source.inline_suppressions[line];
                    if diag.code in suppressed_codes {
                        return True;
                    }
                    # Also check aliases (kebab names)
                    for alias in suppressed_codes {
                        if alias in LINT_ALIASES and LINT_ALIASES[alias] == diag.code {
                            return True;
                        }
                    }
                }
            }
        } except Exception {
            _ = 0;
        }
    }
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is None {
            return False;
        }
        check = config.check;
        # Check suppress list (supports codes, old kebab names, category names)
        if check?.suppress and check.suppress {
            for item in check.suppress {
                if (item == diag.code) {
                    return True;
                }
                # Check if it's an old lint alias
                if (item in LINT_ALIASES and LINT_ALIASES[item] == diag.code) {
                    return True;
                }
            }
        }
        # Check suppress_categories
        if check?.suppress_categories and check.suppress_categories {
            if (diag.category.value in check.suppress_categories) {
                return True;
            }
        }
        # For lint codes, check lint select/ignore config
        if diag.category.value == "lint" and check?.lint {
            lint = check.lint;
            reverse_aliases: dict[str, str] = {v: k for (k, v) in LINT_ALIASES.items()};
            kebab_name = reverse_aliases.get(diag.code, None);
            code_in_select = (
                diag.code in lint.select
                or (kebab_name is not None and kebab_name in lint.select)
            );
            code_in_ignore = (
                diag.code in lint.ignore
                or (kebab_name is not None and kebab_name in lint.ignore)
            );
            # no-print is the only non-default rule
            non_default_codes: set[str] = {"E3012"};
            enabled = False;
            if "all" in lint.select {
                enabled = True;
            } elif "default" in lint.select {
                enabled = (diag.code not in non_default_codes) or code_in_select;
            } else {
                enabled = code_in_select;
            }
            if code_in_ignore {
                enabled = False;
            }
            if not enabled {
                return True;
            }
        }
    } except Exception {
        # If config is not available, don't suppress
        return False;
    }
    return False;
}

"""Emit a structured diagnostic. Returns True if emitted (not suppressed)."""
impl Transform.emit(
    self: Transform,
    diag: DiagnosticInfo,
    node_override: (UniNode | None) = None,
    related: (list[tuple[str, UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: Any
) -> bool {
    import from jaclang.jac0core.diagnostics { Severity }
    # Determine location early (needed for inline suppression check)
    loc = node_override.loc if node_override else self.cur_node.loc;
    # Check suppression (project config + inline comments)
    if self._is_suppressed(diag, loc) {
        return False;
    }
    # Format message from template
    msg = diag.format_message(**kwargs);
    # Build related spans
    related_locs: list[tuple[str, CodeLocInfo]] = [];
    if related {
        for (label, node) in related {
            related_locs.append((label, node.loc));
        }
    }
    alrt = Alert(
        msg=msg,
        loc=loc,
        from_pass=self.__class__,
        code=diag,
        related=related_locs,
        help_text=help_text
    );
    # Route by severity
    if (diag.severity == Severity.ERROR) {
        self.errors_had.append(alrt);
        self.prog.errors_had.append(alrt);
    } else {
        self.warnings_had.append(alrt);
        self.prog.warnings_had.append(alrt);
    }
    return True;
}

"""Check if a diagnostic code is suppressed by project config or inline comment."""
impl Transform._is_suppressed(
    self: Transform, diag: DiagnosticInfo, loc: CodeLocInfo | None = None
) -> bool {
    import from jaclang.jac0core.diagnostics { LINT_ALIASES, DIAGNOSTICS }
    # Check inline suppression: # jac:ignore[CODE]
    if loc {
        try {
            source = loc.orig_src;
            if (source and source?.inline_suppressions and source.inline_suppressions) {
                line = loc.first_line;
                if line in source.inline_suppressions {
                    suppressed_codes = source.inline_suppressions[line];
                    if diag.code in suppressed_codes {
                        return True;
                    }
                    # Also check aliases (kebab names)
                    for alias in suppressed_codes {
                        if alias in LINT_ALIASES and LINT_ALIASES[alias] == diag.code {
                            return True;
                        }
                    }
                }
            }
        } except Exception {
            _ = 0;
        }
    }
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is None {
            return False;
        }
        check = config.check;
        # Check suppress list (supports codes, old kebab names, category names)
        if check?.suppress and check.suppress {
            for item in check.suppress {
                if (item == diag.code) {
                    return True;
                }
                # Check if it's an old lint alias
                if (item in LINT_ALIASES and LINT_ALIASES[item] == diag.code) {
                    return True;
                }
            }
        }
        # Check suppress_categories
        if check?.suppress_categories and check.suppress_categories {
            if (diag.category.value in check.suppress_categories) {
                return True;
            }
        }
        # For lint codes, check lint select/ignore config
        if diag.category.value == "lint" and check?.lint {
            lint = check.lint;
            reverse_aliases: dict[str, str] = {v: k for (k, v) in LINT_ALIASES.items()};
            kebab_name = reverse_aliases.get(diag.code, None);
            code_in_select = (
                diag.code in lint.select
                or (kebab_name is not None and kebab_name in lint.select)
            );
            code_in_ignore = (
                diag.code in lint.ignore
                or (kebab_name is not None and kebab_name in lint.ignore)
            );
            # no-print is the only non-default rule
            non_default_codes: set[str] = {"E3012"};
            enabled = False;
            if "all" in lint.select {
                enabled = True;
            } elif "default" in lint.select {
                enabled = (diag.code not in non_default_codes) or code_in_select;
            } else {
                enabled = code_in_select;
            }
            if code_in_ignore {
                enabled = False;
            }
            if not enabled {
                return True;
            }
        }
    } except Exception {
        # If config is not available, don't suppress
        return False;
    }
    return False;
}

"""Pass Error."""
impl Transform.ice(
    self: Transform, msg: str = 'Something went horribly wrong!'
) -> RuntimeError {
    self.emit(E9001, pass_name=self.__class__.__name__, details=msg);
    return RuntimeError(
        f"Internal Compiler Error: Pass {self.__class__.__name__} - {msg}"
    );
}
