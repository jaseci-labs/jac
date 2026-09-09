impl Alert.postinit -> None {
    if (self.help_text is None) and self.code {
        self.help_text = self.code.help_text;
    }
    if self.owner == '' and self.loc.mod_path != '' {
        import os;
        try {
            self.owner = os.path.realpath(self.loc.mod_path);
        } except OSError {
            self.owner = self.loc.mod_path;
        }
    }
}

impl Alert.__str__ -> str {
    return f"{self.loc.mod_path}, line {self.loc.first_line}, col {self.loc.col_start}: {self.msg}";
}

impl Alert.__repr__ -> str {
    return self.as_log();
}

impl Alert.as_log(*, colors: bool = False) -> str {
    import from jaclang.compiler.frontend.helpers { render_diagnostic_header }
    return render_diagnostic_header(
        self.msg,
        self.code.code if self.code else '',
        self.code.severity.value if self.code else 'error',
        self.loc,
        colors=colors
    );
}

impl Alert.pretty_print(*, colors: bool = False) -> str {
    import from jaclang.compiler.frontend.helpers { render_diagnostic }
    return render_diagnostic(
        self.msg,
        self.code.code if self.code else '',
        self.code.severity.value if self.code else 'error',
        self.loc,
        self.related,
        self.help_text,
        colors=colors
    );
}

impl DiagnosticPolicy.is_suppressed(
    diag: DiagnosticInfo,
    loc: (CodeLocInfo | Span | None) = None,
    source: (Source | None) = None
) -> bool {
    if loc is not None and self._inline_suppressed(diag, loc, source) {
        return True;
    }
    if diag.code in self.suppress_codes {
        return True;
    }
    if diag.category.value in self.suppress_categories {
        return True;
    }
    if self.lint_active and diag.category.value == "lint" {
        reverse_aliases: dict[str, str] = {v: k for (k, v) in LINT_ALIASES.items()};
        kebab_name = reverse_aliases.get(diag.code, None);
        code_in_select = (
            diag.code in self.lint_select
            or (kebab_name is not None and kebab_name in self.lint_select)
        );
        code_in_ignore = (
            diag.code in self.lint_ignore
            or (kebab_name is not None and kebab_name in self.lint_ignore)
        );

        non_default_codes: set[str] = {"E3012"};

        explicit_only_codes: set[str] = {"W3050", "W3051"};
        enabled = False;
        if diag.code in explicit_only_codes {
            enabled = code_in_select;
        } elif "all" in self.lint_select {
            enabled = True;
        } elif "default" in self.lint_select {
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
    return False;
}

impl DiagnosticPolicy._inline_suppressed(
    diag: DiagnosticInfo, loc: (CodeLocInfo | Span), source: (Source | None) = None
) -> bool {
    if isinstance(loc, CodeLocInfo) {
        source = loc.orig_src;
    }
    if source is None
        or source.file_path != loc.mod_path
        or not source.inline_suppressions {
        return False;
    }
    line = loc.first_line;
    if line not in source.inline_suppressions {
        return False;
    }
    cache_key = (loc.mod_path, line, );
    if cache_key not in self._inline_cache {
        (resolved_inline_codes, _) = resolve_diagnostic_tokens(
            list(source.inline_suppressions[line])
        );
        self._inline_cache[cache_key] = resolved_inline_codes;
    }
    return diag.code in self._inline_cache[cache_key];
}

impl BaseTransform.postinit -> None {
    completed = self.completed;
    if completed is not None {
        self.ir_out = self.ir_in;
        self.errors_had.extend(completed.errors_had);
        self.warnings_had.extend(completed.warnings_had);
        self.time_taken = completed.time_taken;
        self.completed = None;
        return;
    }
    self.pre_transform();
    self.ir_out = self.timed_transform(ir_in=self.ir_in);
    self.post_transform();
}

impl BaseTransform.pre_transform -> None {}

impl BaseTransform.post_transform -> None {}

impl BaseTransform.log_info(msg: str) -> None {
    import logging;
    logging.getLogger(type(self).__name__).info(msg);
}

impl BaseTransform.is_canceled -> bool {
    return self.cancel_requested;
}

impl Transform.postinit -> None {
    self.cur_node = self.ir_in;
    super.postinit();
}

impl Transform.emit(
    diag: DiagnosticInfo,
    node_override: (UniNode | None) = None,
    related: (list[tuple[str, UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: object
) -> bool {
    loc = node_override.loc if node_override else self.cur_node.loc;

    if self.policy is not None and self.policy.is_suppressed(diag, loc) {
        return False;
    }

    msg = diag.format_message(**kwargs);
    resolved_help = help_text if help_text is not None else diag.format_help(**kwargs);

    related_locs: list[tuple[str, Span]] = [];
    if related {
        for (label, node) in related {
            related_locs.append((label, node.loc.span()));
        }
    }
    alrt = Alert(
        msg=msg,
        loc=loc.span(),
        from_pass=type(self),
        code=diag,
        related=related_locs,
        help_text=resolved_help
    );

    if (diag.severity == Severity.ERROR) {
        self.errors_had.append(alrt);
    } else {
        self.warnings_had.append(alrt);
    }
    return True;
}

impl Transform._is_suppressed(
    diag: DiagnosticInfo, loc: CodeLocInfo | None = None
) -> bool {
    return self.policy is not None and self.policy.is_suppressed(diag, loc);
}

impl Transform.ice(msg: str = 'Something went horribly wrong!') -> str {
    self.emit(E9001, pass_name=type(self).__name__, details=msg);
    return f"Internal Compiler Error: Pass {type(self).__name__} - {msg}";
}
