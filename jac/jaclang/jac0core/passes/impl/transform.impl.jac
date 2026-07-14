impl Alert.postinit -> None {
    if (self.help_text is None) and self.code {
        self.help_text = self.code.help_text;
    }
}

impl Alert.__str__ -> str {
    return f"{self.loc.mod_path}, line {self.loc.first_line}, col {self.loc.col_start}: {self.msg}";
}

impl Alert.__repr__ -> str {
    return self.as_log();
}

impl Alert.as_log(*, colors: bool = False) -> str {
    import from jaclang.jac0core.helpers { ANSIColors }
    import from jaclang.jac0core.diagnostics { Severity }
    file_path: str = self.loc.mod_path;
    if self.code {
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

    if (file_path == '') {
        return self.msg;
    }
    line: int = self.loc.first_line;
    column: int = self.loc.col_start;
    msg = self.msg if not colors else f"{ANSIColors.RED}{self.msg}{ANSIColors.END}";
    return f"{file_path}:{line}:{column} {msg}";
}

impl Alert.pretty_print(*, colors: bool = False) -> str {
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

    if self.related {
        result += format_related_spans(self.related, colors=colors);
    }

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

impl BaseTransform.postinit -> None {
    self.logger = logging.getLogger(self.__class__.__name__);
    self.pre_transform();
    self.ir_out = self.timed_transform(ir_in=self.ir_in);
    self.post_transform();
}

impl BaseTransform.timed_transform(ir_in: T_in) -> T_out {
    start_time = time.time();
    ir_out = self.transform(ir_in=ir_in);
    self.time_taken = time.time() - start_time;
    return ir_out;
}

impl BaseTransform.pre_transform -> None {
    ;
}

impl BaseTransform.post_transform -> None {
    ;
}

@abstractmethod
impl BaseTransform.transform(ir_in: T_in) -> T_out {
    ;
}

impl BaseTransform.log_info(msg: str) -> None {
    self.logger.info(msg);
}

impl BaseTransform.is_canceled -> bool {
    return ((self.cancel_token is not None) and self.cancel_token.is_set());
}

impl Transform.postinit -> None {
    self.cur_node = self.ir_in;
    self._cached_check_suppress_tokens = [];
    self._cached_check_suppress_codes = [];
    self._cached_inline_suppressions = {};
    super.postinit();
}

impl Transform.emit(
    diag: DiagnosticInfo,
    node_override: (UniNode | None) = None,
    related: (list[tuple[str, UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
    import from jaclang.jac0core.diagnostics { Severity }

    loc = node_override.loc if node_override else self.cur_node.loc;

    if self._is_suppressed(diag, loc) {
        return False;
    }

    loc = loc.snapshot();

    msg = diag.format_message(**kwargs);
    resolved_help = help_text if help_text is not None else diag.format_help(**kwargs);

    related_locs: list[tuple[str, CodeLocInfo]] = [];
    if related {
        for (label, node) in related {
            related_locs.append((label, node.loc.snapshot()));
        }
    }
    alrt = Alert(
        msg=msg,
        loc=loc,
        from_pass=self.__class__,
        code=diag,
        related=related_locs,
        help_text=resolved_help
    );

    if (diag.severity == Severity.ERROR) {
        self.errors_had.append(alrt);
        self.prog.errors_had.append(alrt);
    } else {
        self.warnings_had.append(alrt);
        self.prog.warnings_had.append(alrt);
    }
    return True;
}

impl Transform._is_suppressed(
    diag: DiagnosticInfo, loc: CodeLocInfo | None = None
) -> bool {
    import from jaclang.jac0core.diagnostics { LINT_ALIASES }
    import from jaclang.jac0core.diagnostic_utils { resolve_diagnostic_tokens }

    if loc {
        try {
            source = loc.orig_src;
            if (
                source and source?.inline_suppressions and source.inline_suppressions
            ) {
                line = loc.first_line;
                if line in source.inline_suppressions {
                    cache_key = (loc.mod_path, line);
                    if cache_key not in self._cached_inline_suppressions {
                        suppressed_codes = source.inline_suppressions[line];
                        (resolved_inline_codes, _) = resolve_diagnostic_tokens(
                            list(suppressed_codes)
                        );
                        self._cached_inline_suppressions[cache_key] = resolved_inline_codes;
                    }
                    resolved_inline_codes = self._cached_inline_suppressions[cache_key];
                    if diag.code in resolved_inline_codes {
                        return True;
                    }
                }
            }
        } except Exception {
            _ = 0;
        }
    }
    try {
        config = self._project_config;
        if config is None {
            import from jaclang.project.config { get_config }
            config = get_config();
        }
        suppress_tokens: list[str] = [];
        check = config.check if (config and config.check) else None;
        if check?.suppress and check.suppress {
            suppress_tokens = list(check.suppress);
        }
        prog_suppress_tokens = self.prog._compile_options.suppress_codes
            if (
                self.prog?._compile_options
                and self.prog._compile_options.suppress_codes
            )
            else [];
        if prog_suppress_tokens {
            suppress_tokens.extend(prog_suppress_tokens);
        }

        if suppress_tokens {
            if suppress_tokens != self._cached_check_suppress_tokens {
                (resolved_suppress_codes, _) = resolve_diagnostic_tokens(
                    suppress_tokens
                );
                self._cached_check_suppress_tokens = suppress_tokens;
                self._cached_check_suppress_codes = resolved_suppress_codes;
            }
            if diag.code in self._cached_check_suppress_codes {
                return True;
            }
        }

        if check?.suppress_categories and check.suppress_categories {
            if (diag.category.value in check.suppress_categories) {
                return True;
            }
        }

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

            non_default_codes: set[str] = {"E3012"};

            explicit_only_codes: set[str] = {"W3050", "W3051"};
            enabled = False;
            if diag.code in explicit_only_codes {
                enabled = code_in_select;
            } elif "all" in lint.select {
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
        return False;
    }
    return False;
}

impl Transform.ice(msg: str = 'Something went horribly wrong!') -> RuntimeError {
    self.emit(E9001, pass_name=self.__class__.__name__, details=msg);
    return RuntimeError(
        f"Internal Compiler Error: Pass {self.__class__.__name__} - {msg}"
    );
}
