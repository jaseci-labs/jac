import os;
import re;
import from pathlib { Path }
import from jaclang.client.source_mapping { JacLocator, SourceLocation, _npm_specifier }

glob _EXPORT_MISS_RE = re.compile(
         r"does not provide an export named [\"']([^\"']+)[\"']"
     ),
     _QUOTED_RE = re.compile(r"[\"']([^\"']+)[\"']"),
     _RESOLVE_FAIL_RE = re.compile(
         r"[Ff]ailed to resolve import\s+[\"']([^\"']+)[\"']"
         r"(?:\s+from\s+[\"']([^\"']+)[\"'])?"
     ),
     _CANNOT_FIND_RE = re.compile(
         r"(?:Cannot find module|Could not resolve)\s+[\"']([^\"']+)[\"']"
         r"(?:\s+from\s+[\"']([^\"']+)[\"'])?"
     ),
     _BUILD_ERROR_RES = [_RESOLVE_FAIL_RE, _CANNOT_FIND_RE, _EXPORT_MISS_RE],
     _BUILD_FRAME_PREFIXES = ["at ", "^", "|"],
     _BUILD_FRAMING = ["error during build", "error", "build failed"],
     _JAC_COMPILE_MARKER = "failed to compile",
     _NO_BYTECODE_MARKER = "no bytecode found for",
     _LINE_MARKER = ", line ",
     _COL_MARKER = ", col ",
     _RAW_HEADER = "--- Raw Error (debug=true) ---",
     _RAW_FOOTER = "--- End Raw Error ---";

def _diag(code: str) -> any {
    import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
    return DIAGNOSTICS.get(code);
}

def _text(value: any) -> str {
    return "" if value is None else str(value);
}

def _number(value: any) -> int {
    try {
        return int(value or 0);
    } except (TypeError, ValueError) {
        return 0;
    }
}

impl related_location(
    label: str, file: str, line: int = 0, column: int = 0
) -> dict[str, any] {
    return {"label": label, "file": file, "line": line, "column": column};
}

impl ClientDiagnostic.key -> str {
    return f"{self.code}|{self.file}|{self.line}|{self.column}|{self.message}";
}

impl ClientDiagnostic.abs_file -> str {
    if not self.file {
        return "";
    }
    if os.path.isabs(self.file) or not self.base_path {
        return self.file;
    }
    return os.path.join(self.base_path, self.file);
}

impl ClientDiagnostic.render(colors: bool = False) -> str {
    import from jaclang.compiler.frontend.helpers {
        render_diagnostic,
        span_for_file,
        read_file_with_encoding
    }
    if self.rendered_cache and not self.base_path {
        return self.rendered_cache;
    }
    span: any = None;
    if self.file and self.line > 0 {
        source = "";
        try {
            source = read_file_with_encoding(self.abs_file());
        } except Exception {
            source = "";
        }
        span = span_for_file(self.file, self.line, self.column, 0, source);
    }
    related: list[tuple[str, any]] = [];
    for note in self.related {
        note_file = _text(note.get("file"));
        note_line = _number(note.get("line"));
        note_source = "";
        if note_file and note_line > 0 {
            note_abs = note_file;
            if not os.path.isabs(note_abs) and self.base_path {
                note_abs = os.path.join(self.base_path, note_abs);
            }
            try {
                note_source = read_file_with_encoding(note_abs);
            } except Exception {
                note_source = "";
            }
        }
        related.append(
            (
                _text(note.get("label")),
                span_for_file(
                    note_file, note_line, _number(note.get("column")), 0, note_source
                )
            )
        );
    }
    text = render_diagnostic(
        self.message,
        self.code,
        self.severity,
        span,
        related,
        self.help_text or None,
        colors=colors
    );
    if span is None and self.file {
        arrow = f"\n  --> {self.file}";
        head_end = text.find("\n");
        text = (text + arrow)
            if (head_end < 0)
            else (text[:head_end] + arrow + text[head_end:]);
    }
    if self.unmapped_reason {
        text += f"\nnote: {self.unmapped_reason}";
    }
    return text;
}

impl ClientDiagnostic.to_dict -> dict[str, any] {
    return {
        "code": self.code,
        "severity": self.severity,
        "category": self.category,
        "message": self.message,
        "help": self.help_text,
        "file": self.file,
        "line": self.line,
        "column": self.column,
        "channel": self.channel,
        "raw_location": self.raw_location,
        "unmapped_reason": self.unmapped_reason,
        "related": self.related,
        "stack": self.stack,
        "component_stack": self.component_stack,
        "resolved_stack": self.resolved_stack,
        "resolved_component_stack": self.resolved_component_stack,
        "rendered": self.render()
    };
}

impl ClientDiagnostic.from_dict(data: dict[str, any]) -> ClientDiagnostic {
    return ClientDiagnostic(
        code=_text(data.get("code")),
        severity=_text(data.get("severity")) or "error",
        category=_text(data.get("category")) or "runtime",
        message=_text(data.get("message")),
        help_text=_text(data.get("help")),
        file=_text(data.get("file")),
        line=_number(data.get("line")),
        column=_number(data.get("column")),
        channel=_text(data.get("channel")) or "jac",
        raw_location=_text(data.get("raw_location")),
        unmapped_reason=_text(data.get("unmapped_reason")),
        related=list(data.get("related") or []),
        stack=_text(data.get("stack")),
        component_stack=_text(data.get("component_stack")),
        resolved_stack=_text(data.get("resolved_stack")),
        resolved_component_stack=_text(data.get("resolved_component_stack")),
        rendered_cache=_text(data.get("rendered"))
    );
}

def _relative(base_path: str, path: str) -> str {
    if not path or not base_path {
        return path;
    }
    try {
        rel = Path(os.path.abspath(path)).relative_to(os.path.abspath(base_path));
    } except ValueError {
        return path;
    }
    posix = rel.as_posix();
    return path if posix in ("", ".") else posix;
}

impl diagnostic_from_alert(alert: Alert, base_path: str = "") -> ClientDiagnostic {
    info = alert.code;
    code = info.code if info is not None else "E7005";
    severity = info.severity.value if info is not None else "error";
    category = info.category.value if info is not None else "codegen";
    span = alert.loc;
    return ClientDiagnostic(
        code=code,
        severity=severity,
        category=category,
        message=str(alert.msg),
        help_text=_text(alert.help_text),
        file=_relative(base_path, span.mod_path if span is not None else ""),
        line=span.first_line if span is not None else 0,
        column=span.col_start if span is not None else 0,
        channel="jac",
        base_path=base_path
    );
}

impl diagnostics_from_alerts(
    alerts: list[Alert], base_path: str = ""
) -> list[ClientDiagnostic] {
    out: list[ClientDiagnostic] = [];
    for alert in alerts {
        try {
            out.append(diagnostic_from_alert(alert, base_path));
        } except Exception {
            continue;
        }
    }
    return out;
}

impl build_failure_diagnostic(
    base_path: str, file_path: str, message: str, line: int = 0, column: int = 0
) -> ClientDiagnostic {
    info = _diag("E7005");
    return ClientDiagnostic(
        code="E7005",
        severity="error",
        category="codegen",
        message=info.format_message(message=message) if info else message,
        help_text=_text(info.format_help(message=message)) if info else "",
        file=_relative(base_path, file_path),
        line=line,
        column=column,
        channel="jac",
        base_path=base_path
    );
}

impl render_diagnostics(
    diagnostics: list[ClientDiagnostic], colors: bool = False
) -> str {
    return "\n\n".join(diag.render(colors=colors) for diag in diagnostics);
}

def _raw_location(payload: dict[str, any]) -> str {
    where = _text(payload.get("source")) or _text(payload.get("id"));
    line = _number(payload.get("line"));
    column = _number(payload.get("column"));
    loc = payload.get("loc");
    if isinstance(loc, dict) {
        line = line or _number(loc.get("line"));
        column = column or _number(loc.get("column"));
    }
    if where and line {
        return f"{where}:{line}:{column}" if column else f"{where}:{line}";
    }
    return where;
}

def _payload_position(payload: dict[str, any]) -> tuple[int, int] {
    line = _number(payload.get("line"));
    column = _number(payload.get("column"));
    loc = payload.get("loc");
    if isinstance(loc, dict) {
        line = line or _number(loc.get("line"));
        column = column or _number(loc.get("column"));
    }
    return (line, column);
}

def _pin_location(
    diag: ClientDiagnostic,
    locator: JacLocator,
    loc: (SourceLocation | None),
    raw_location: str,
    reason: str
) -> None {
    if loc is not None and loc.line > 0 {
        diag.file = _relative(diag.base_path, loc.file);
        diag.line = loc.line;
        diag.column = loc.column;
        return;
    }
    owner = loc.file if loc is not None else "";
    if not owner {
        owner = locator.owner_for(raw_location);
    }
    if not owner {
        owner = locator.fallback_owner();
    }
    diag.file = _relative(diag.base_path, owner);
    diag.line = 0;
    diag.column = 0;
    diag.unmapped_reason = reason;
}

def _requested_module(message: str) -> str {
    found = _QUOTED_RE.search(message);
    return found.group(1) if found else "";
}

impl classify_client_payload(
    base_path: str,
    payload: dict[str, any],
    channel: str = "browser",
    verbose: bool = False
) -> ClientDiagnostic {
    message = _text(payload.get("message"));
    stack = _text(payload.get("stack"));
    where = _text(payload.get("source")) or _text(payload.get("id"));
    (line, column) = _payload_position(payload);
    raw_location = _raw_location(payload);
    locator = JacLocator.for_base(base_path);
    component_stack = _text(payload.get("componentStack"));
    diag = ClientDiagnostic(
        channel=channel,
        base_path=os.path.abspath(base_path or "."),
        raw_location=raw_location,
        stack=stack,
        component_stack=component_stack
    );
    if stack {
        diag.resolved_stack = locator.resolve_stack_trace(stack, verbose);
    }
    if component_stack {
        diag.resolved_component_stack = locator.resolve_stack_trace(
            component_stack, verbose
        );
    }

    miss = _EXPORT_MISS_RE.search(message);
    if miss {
        name = miss.group(1);
        module_url = _requested_module(message);
        specifier = _npm_specifier(module_url) or _npm_specifier(where);
        info = _diag("E7001");
        diag.code = "E7001";
        diag.category = "runtime";
        diag.message = info.format_message(module=specifier, name=name)
            if info
            else message;
        diag.help_text = _text(info.format_help(module=specifier, name=name))
            if info
            else "";
        diag.raw_location = module_url or raw_location;
        _pin_location(
            diag,
            locator,
            locator.locate_import(specifier, name),
            diag.raw_location,
            f"no compiled module under .jac/client/compiled imports '{name}' from "
            f"'{specifier}', so the import item could not be traced to a Jac line"
        );
        return diag;
    }

    fail = _RESOLVE_FAIL_RE.search(message);
    missing_name = fail.group(1) if fail else "";
    importer = (fail.group(2) or "") if fail else "";
    if not fail {
        alt = _CANNOT_FIND_RE.search(message);
        if alt {
            missing_name = alt.group(1);
            importer = alt.group(2) or "";
        }
    }
    if missing_name {
        importer = importer or where;
        info = _diag("E7002");
        diag.code = "E7002";
        diag.category = "runtime";
        diag.message = info.format_message(name=missing_name, importer=importer)
            if info
            else message;
        diag.help_text = _text(info.format_help(name=missing_name, importer=importer))
            if info
            else "";
        _pin_location(
            diag,
            locator,
            locator.importer_of(importer, missing_name),
            importer or raw_location,
            f"nothing under .jac/client/compiled imports '{missing_name}', so the "
            f"import could not be traced to a Jac line"
        );
        if not missing_name.startswith(".") and not missing_name.startswith("/") {
            npm_info = _diag("W1106");
            if npm_info is not None {
                diag.help_text = _text(npm_info.format_help(name=missing_name));
            }
            declared = locator.locate_npm_declaration(missing_name);
            if declared is not None {
                (toml_loc, note) = declared;
                label = note
                    or (
                        f"'{missing_name}' is declared under [dependencies.npm]; run "
                        f"'jac install' to fetch it"
                    );
                diag.related = [
                    related_location(
                        label,
                        _relative(diag.base_path, toml_loc.file),
                        toml_loc.line,
                        toml_loc.column
                    )
                ];
            }
        }
        return diag;
    }

    mapped: (SourceLocation | None) = None;
    if stack {
        mapped = locator.locate_stack(stack);
    }
    if mapped is None and where and line {
        mapped = locator.locate_compiled(where, line, column);
    }
    if mapped is not None {
        kind = _text(payload.get("type")) or "Error";
        info = _diag("E7003");
        diag.code = "E7003";
        diag.category = "runtime";
        diag.message = info.format_message(kind=kind, message=message)
            if info
            else message;
        diag.help_text = _text(info.format_help(kind=kind, message=message))
            if info
            else "";
        diag.file = _relative(diag.base_path, mapped.file);
        diag.line = mapped.line;
        diag.column = mapped.column;
        return diag;
    }

    if channel == DiagChannel.VITE.value {
        info = _diag("E7004");
        diag.code = "E7004";
        diag.category = "runtime";
        diag.message = info.format_message(message=message) if info else message;
        diag.help_text = _text(info.format_help(message=message)) if info else "";
        _pin_location(
            diag,
            locator,
            locator.locate_compiled(where, line, column) if (where and line) else None,
            where or raw_location,
            f"the dev server named '{where or 'no module'}', which no compiled Jac "
            f"artifact claims"
        );
        return diag;
    }

    info = _diag("E7006");
    diag.code = "E7006";
    diag.category = "runtime";
    diag.message = info.format_message(message=message) if info else message;
    diag.help_text = _text(info.format_help(message=message)) if info else "";
    _pin_location(
        diag,
        locator,
        None,
        where or raw_location,
        f"the browser reported '{raw_location or 'no location'}', which no compiled "
        f"Jac artifact and no source map claims"
    );
    return diag;
}

impl log_client_error(
    base_path: str, data: dict[str, any], verbose: bool = False
) -> ClientDiagnostic {
    import logging;
    diag = classify_client_payload(base_path, data, "browser", verbose);
    parts: list[str] = [diag.render()];
    if diag.resolved_stack {
        parts.append(f"  Stack: {diag.resolved_stack}");
    }
    if diag.resolved_component_stack {
        parts.append(f"  Component stack: {diag.resolved_component_stack}");
    }
    url = _text(data.get("url"));
    if url {
        parts.append(f"  URL: {url}");
    }
    logging.getLogger("jaclang.client_errors").error("\n".join(parts));
    return diag;
}

def _leading_number(text: str) -> int {
    digits = "";
    for ch in text {
        if not ch.isdigit() {
            break;
        }
        digits += ch;
    }
    return int(digits) if digits else 0;
}

def _marker_line(output: str, lowered: str, marker: str) -> str {
    at = lowered.find(marker);
    if at < 0 {
        return "";
    }
    start = output.rfind("\n", 0, at) + 1;
    end = output.find("\n", at);
    return output[start:] if end < 0 else output[start:end];
}

def _marked_number(line: str, marker: str) -> int {
    at = line.lower().find(marker);
    return 0 if at < 0 else _leading_number(line[at + len(marker):]);
}

def _first_quoted(text: str) -> str {
    for quote in ("'", '"') {
        parts = text.split(quote);
        if len(parts) >= 2 and parts[1] {
            return parts[1];
        }
    }
    return "";
}

def _trailing_detail(line: str) -> str {
    at = line.rfind(": ");
    return "" if at <= 0 else line[at + 2:].strip();
}

def _jac_compile_failure(base_path: str, output: str) -> (ClientDiagnostic | None) {
    lowered = output.lower();
    compile_line = _marker_line(output, lowered, _JAC_COMPILE_MARKER);
    file_path = _first_quoted(compile_line);
    line = _marked_number(compile_line, _LINE_MARKER);
    column = _marked_number(compile_line, _COL_MARKER);
    message = _trailing_detail(compile_line);
    if not file_path {
        bytecode_line = _marker_line(output, lowered, _NO_BYTECODE_MARKER);
        at = bytecode_line.lower().find(_NO_BYTECODE_MARKER);
        if at >= 0 {
            file_path = bytecode_line[at + len(_NO_BYTECODE_MARKER):].strip();
        }
        line = 0;
        column = 0;
        message = "";
    }
    if not file_path {
        return None;
    }
    return build_failure_diagnostic(
        base_path,
        file_path,
        message or f"could not compile '{os.path.basename(file_path)}'",
        line,
        column
    );
}

def _build_error_lines(output: str) -> list[str] {
    found: list[str] = [];
    seen: set[str] = set();
    for raw in output.splitlines() {
        line = raw.strip();
        if not line or line in seen {
            continue;
        }
        for pattern in _BUILD_ERROR_RES {
            if pattern.search(line) {
                seen.add(line);
                found.append(line);
                break;
            }
        }
    }
    return found;
}

def _condensed_build_message(output: str) -> str {
    for raw in output.splitlines() {
        line = raw.strip();
        if not line or any(line.startswith(p) for p in _BUILD_FRAME_PREFIXES) {
            continue;
        }
        if line.lower().rstrip(":") in _BUILD_FRAMING {
            continue;
        }
        return line;
    }
    return output.strip() or "the client bundle build produced no output";
}

impl classify_build_output(
    base_path: str, error_output: str, verbose: bool = False
) -> list[ClientDiagnostic] {
    output = error_output or "";
    out: list[ClientDiagnostic] = [];
    seen: set[str] = set();
    compile_failure = _jac_compile_failure(base_path, output);
    if compile_failure is not None {
        seen.add(compile_failure.key());
        out.append(compile_failure);
    }
    for line in _build_error_lines(output) {
        diag = classify_client_payload(
            base_path, {"message": line}, DiagChannel.VITE.value, verbose
        );
        if diag.key() in seen {
            continue;
        }
        seen.add(diag.key());
        out.append(diag);
    }
    if out {
        return out;
    }
    return [
        classify_client_payload(
            base_path,
            {"message": _condensed_build_message(output)},
            DiagChannel.VITE.value,
            verbose
        )
    ];
}

impl format_build_diagnostics(
    base_path: str, error_output: str, config: object = None
) -> str {
    rendered = render_diagnostics(classify_build_output(base_path, error_output));
    if not is_debug_mode(config) {
        return rendered;
    }
    return f"{rendered}\n\n{_RAW_HEADER}\n{error_output}\n{_RAW_FOOTER}";
}

impl is_debug_mode(config: object = None) -> bool {
    env_debug = os.environ.get("JAC_DEBUG", "").lower();
    if env_debug in ("1", "true", "yes") {
        return True;
    }
    if env_debug in ("0", "false", "no") {
        return False;
    }
    import from jaclang.project.config { JacConfig }
    if isinstance(config, JacConfig) {
        try {
            client_cfg = config.get_plugin_config("client");
            if client_cfg {
                return bool(client_cfg.get("debug", True));
            }
        } except Exception {}
    }
    return True;
}
