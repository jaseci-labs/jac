"""Implementation of diagnostics module."""
import os;
import from pathlib { Path }

# ============== Diagnostic ==============

impl Diagnostic.init(
    self: Diagnostic,
    code: str,
    severity: Severity,
    title: str,
    message: str,
    file_path: str = "",
    line: int = 0,
    column: int = 0,
    source_snippet: str = "",
    hint: str = "",
    quick_fix: str = ""
) {
    self.code = code;
    self.severity = severity;
    self.title = title;
    self.message = message;
    self.file_path = file_path;
    self.line = line;
    self.column = column;
    self.source_snippet = source_snippet;
    self.hint = hint;
    self.quick_fix = quick_fix;
}

# ============== BuildContext ==============

impl BuildContext.init(
    self: BuildContext,
    error_output: str,
    project_dir: Path,
    source_map: dict[str, str] = {},
    jac_files: list[Path] = [],
    installed_packages: set[str] = set()
) {
    self.error_output = error_output;
    self.project_dir = project_dir;
    self.source_map = source_map;
    self.jac_files = jac_files;
    self.installed_packages = installed_packages;
}

impl BuildContext.read_source_lines(self: BuildContext, file_path: str, line: int, context_lines: int = 2) -> str {
    try {
        path = Path(file_path);
        if not path.exists() { return ""; }
        lines = path.read_text(encoding="utf-8").splitlines();
        start = max(0, line - context_lines - 1);
        end = min(len(lines), line + context_lines);
        snippet_lines: list[str] = [];
        for i in range(start, end) {
            line_num = i + 1;
            prefix = " -> " if line_num == line else "    ";
            snippet_lines.append(f"{prefix}{line_num:4} | {lines[i]}");
        }
        return "\n".join(snippet_lines);
    } except Exception { return ""; }
}

# ============== DiagnosticCollection ==============

impl DiagnosticCollection.add(self: DiagnosticCollection, diagnostic: Diagnostic) -> None {
    self.items.append(diagnostic);
}

impl DiagnosticCollection.add_all(self: DiagnosticCollection, diagnostics: list[Diagnostic]) -> None {
    self.items.extend(diagnostics);
}

# ============== BaseDetector ==============

impl BaseDetector.handle(self: BaseDetector, error: str) -> bool {
    if not self.patterns { return False; }
    error_lower = error.lower();
    for pattern in self.patterns {
        if pattern.lower() in error_lower { return True; }
    }
    return False;
}

impl BaseDetector.detect(self: BaseDetector, ctx: BuildContext) -> list[Diagnostic] {
    return [Diagnostic(
        code=self.code,
        severity=Severity.ERROR,
        title=self.title,
        message="An error occurred during build.",
        hint="Check the error output for details."
    )];
}

impl BaseDetector.create_diagnostic(
    self: BaseDetector,
    message: str,
    severity: Severity = Severity.ERROR,
    file_path: str = "",
    line: int = 0,
    hint: str = "",
    quick_fix: str = ""
) -> Diagnostic {
    return Diagnostic(
        code=self.code,
        severity=severity,
        title=self.title,
        message=message,
        file_path=file_path,
        line=line,
        hint=hint,
        quick_fix=quick_fix
    );
}

impl BaseDetector.extract_between(self: BaseDetector, text: str, start_delim: str, end_delim: str = "") -> str {
    if not end_delim { end_delim = start_delim; }
    parts = text.split(start_delim);
    if len(parts) < 2 { return ""; }
    end_parts = parts[1].split(end_delim);
    return end_parts[0] if end_parts else "";
}

impl BaseDetector.find_importing_file(self: BaseDetector, module_name: str, ctx: BuildContext) -> tuple[str, int] {
    import_patterns = [
        f'import from "{module_name}"',
        f"import from '{module_name}'",
        f'from "{module_name}"',
        f"from '{module_name}'"
    ];
    for jac_file in ctx.jac_files {
        try {
            content = jac_file.read_text(encoding="utf-8");
            lines = content.splitlines();
            for (line_num, line) in enumerate(lines, 1) {
                for pattern in import_patterns {
                    if pattern in line { return (str(jac_file), line_num); }
                }
            }
        } except Exception { continue; }
    }
    return ("", 0);
}

# ============== MissingDependencyDetector ==============

# Core runtime dependencies bundled in jac-client-node
glob CORE_DEPS = {
    "react", "react-dom", "react-router-dom", "react-error-boundary",
    "react-hook-form", "zod", "@hookform/resolvers"
};

# Dev dependencies bundled in @jac-client/dev-deps
glob DEV_DEPS = {
    "vite", "@vitejs/plugin-react", "typescript",
    "@types/react", "@types/react-dom"
};

impl MissingDependencyDetector.detect(self: MissingDependencyDetector, ctx: BuildContext) -> list[Diagnostic] {
    parts = ctx.error_output.split('"');
    module_name = parts[1] if len(parts) > 1 else "";
    if not module_name or module_name.startswith(".") or module_name.startswith("/") {
        parts = ctx.error_output.split("'");
        module_name = parts[1] if len(parts) > 1 else "";
    }
    if not module_name {
        return [self.create_diagnostic(
            message="A required npm module could not be found.",
            hint="Check import statements for missing packages.",
            quick_fix="jac add --npm <package-name>"
        )];
    }

    # Check if this is a bundled dependency
    is_core_dep = module_name in CORE_DEPS;
    is_dev_dep = module_name in DEV_DEPS;

    (jac_file, line_num) = self.find_importing_file(module_name, ctx);

    if is_core_dep {
        # Core runtime dependency - suggest jac-client-node
        diag = self.create_diagnostic(
            message=f'Core dependency "{module_name}" is missing.',
            file_path=jac_file,
            line=line_num,
            hint="This is bundled in jac-client-node.\n  Verify jac-client-node is in your jac.toml [dependencies.npm].",
            quick_fix="jac add --npm jac-client-node"
        );
    } elif is_dev_dep {
        # Dev dependency - suggest @jac-client/dev-deps
        diag = self.create_diagnostic(
            message=f'Dev dependency "{module_name}" is missing.',
            file_path=jac_file,
            line=line_num,
            hint="This is bundled in @jac-client/dev-deps.\n  Verify @jac-client/dev-deps is in your jac.toml [dependencies.npm.dev].",
            quick_fix="jac add --npm-dev @jac-client/dev-deps"
        );
    } else {
        # Regular dependency
        diag = self.create_diagnostic(
            message=f'Module "{module_name}" is not installed.',
            file_path=jac_file,
            line=line_num,
            hint="Add this package to your project.",
            quick_fix=f"jac add --npm {module_name}"
        );
    }

    if jac_file and line_num > 0 {
        diag.source_snippet = ctx.read_source_lines(jac_file, line_num);
    }
    return [diag];
}

# ============== CompilationErrorDetector ==============

impl CompilationErrorDetector.detect(self: CompilationErrorDetector, ctx: BuildContext) -> list[Diagnostic] {
    file_path = "";
    line_num = 0;
    col_num = 0;
    error_detail = "";

    error_lower = ctx.error_output.lower();

    # Pattern 1: "Failed to compile '..path..' for client bundle:..path.., line X, col Y: Error"
    if "failed to compile" in error_lower {
        # Extract file path from between quotes
        if "'" in ctx.error_output {
            parts = ctx.error_output.split("'");
            if len(parts) >= 2 {
                file_path = parts[1];
            }
        }
        # Extract line number
        if ", line " in error_lower {
            idx = error_lower.find(", line ");
            rest = ctx.error_output[idx + 7:];
            # Get the number before the next comma or colon
            num_str = "";
            for ch in rest {
                if ch.isdigit() { num_str += ch; }
                else { break; }
            }
            if num_str { line_num = int(num_str); }
        }
        # Extract column
        if ", col " in error_lower {
            idx = error_lower.find(", col ");
            rest = ctx.error_output[idx + 6:];
            num_str = "";
            for ch in rest {
                if ch.isdigit() { num_str += ch; }
                else { break; }
            }
            if num_str { col_num = int(num_str); }
        }
        # Extract error detail (after the last colon)
        if ": " in ctx.error_output {
            # Find the last ": " which contains the actual error
            last_colon = ctx.error_output.rfind(": ");
            if last_colon > 0 {
                error_detail = ctx.error_output[last_colon + 2:].strip();
                # Clean up - get first line only
                if "\n" in error_detail {
                    error_detail = error_detail.split("\n")[0].strip();
                }
            }
        }
    }

    # Pattern 2: "No bytecode found for ..path.."
    if not file_path and "no bytecode found for" in error_lower {
        idx = error_lower.find("no bytecode found for");
        start = idx + len("no bytecode found for");
        rest = ctx.error_output[start:].strip();
        if "\n" in rest {
            file_path = rest.split("\n")[0].strip();
        } else {
            file_path = rest.strip();
        }
    }

    # Build message
    if error_detail {
        message = error_detail;
    } elif file_path {
        filename = file_path.split("/")[-1] if "/" in file_path else file_path;
        message = f"Failed to compile '{filename}'.";
    } else {
        message = "Jac compilation failed.";
    }

    hint = "Check your Jac syntax:\n  - Missing semicolons\n  - Unclosed braces or parentheses\n  - Invalid syntax in cl {{ }} blocks";

    diag = self.create_diagnostic(
        message=message,
        file_path=file_path,
        line=line_num,
        hint=hint,
        quick_fix="jac check"
    );

    # Add source snippet if we have file and line
    if file_path and line_num > 0 {
        diag.source_snippet = ctx.read_source_lines(file_path, line_num);
        diag.column = col_num;
    }

    return [diag];
}

# ============== SyntaxErrorDetector ==============

impl SyntaxErrorDetector.detect(self: SyntaxErrorDetector, ctx: BuildContext) -> list[Diagnostic] {
    hint = "Check for:\n  - Missing or extra braces { }\n  - Unclosed JSX tags\n  - Missing semicolons";
    return [self.create_diagnostic(message="Syntax error in client code.", hint=hint)];
}

# ============== ImportNotFoundDetector ==============

impl ImportNotFoundDetector.detect(self: ImportNotFoundDetector, ctx: BuildContext) -> list[Diagnostic] {
    import_path = self.extract_between(ctx.error_output, '"');
    if not import_path { import_path = self.extract_between(ctx.error_output, "'"); }
    if not import_path or not import_path.startswith(".") { return []; }
    hint = "Check the import path for:\n  - Correct spelling and case\n  - File extension (.jac not needed)";
    return [self.create_diagnostic(message=f'Cannot find module "{import_path}".', hint=hint)];
}

# ============== DiagnosticEngine ==============

impl DiagnosticEngine.register_all(self: DiagnosticEngine, detectors: list[BaseDetector]) -> None {
    self.detectors.extend(detectors);
}

impl DiagnosticEngine.analyze(self: DiagnosticEngine, ctx: BuildContext) -> DiagnosticCollection {
    self.detectors.sort(key=lambda d: BaseDetector : d.priority);
    collection = DiagnosticCollection();
    for detector in self.detectors {
        if detector.handle(ctx.error_output) {
            try {
                collection.add_all(detector.detect(ctx));
            } except Exception as e {
                collection.add(Diagnostic(
                    code="JAC_CLIENT_INTERNAL",
                    severity=Severity.WARNING,
                    title="Detector Error",
                    message=f"Detector {detector.code} failed: {str(e)}"
                ));
            }
        }
    }
    if len(collection.items) == 0 and ctx.error_output {
        collection.add(Diagnostic(
            code="JAC_CLIENT_999",
            severity=Severity.ERROR,
            title="Build Failed",
            message="Client bundle build failed.",
            hint="Run with debug=true in jac.toml for details."
        ));
    }
    return collection;
}

# ============== DiagnosticFormatter ==============

impl DiagnosticFormatter.format_diagnostic(self: DiagnosticFormatter, diag: Diagnostic) -> str {
    lines: list[str] = [];
    inner = self.width - 2;
    header = f" {diag.code}: {diag.title} ";
    lines.append(BOX_TL + header + (BOX_H * (inner - len(header))) + BOX_TR);
    lines.append(BOX_V + (BOX_H * inner) + BOX_V);
    lines.append(self._pad(""));
    for msg_line in self._wrap(diag.message, inner - 4) {
        lines.append(self._pad(f"  {msg_line}"));
    }
    if diag.file_path {
        lines.append(self._pad(""));
        loc = f"  File: {diag.file_path}" + (f":{diag.line}" if diag.line > 0 else "");
        lines.append(self._pad(loc));
    }
    if diag.source_snippet {
        lines.append(self._pad(""));
        for sl in diag.source_snippet.splitlines() {
            if len(sl) > inner - 4 { sl = sl[:inner - 7] + "..."; }
            lines.append(self._pad(f"  {sl}"));
        }
    }
    if diag.quick_fix {
        lines.append(self._pad(""));
        lines.append(self._pad("  Quick fix:"));
        lines.append(self._pad(f"     $ {diag.quick_fix}"));
    }
    if diag.hint {
        lines.append(self._pad(""));
        for hl in diag.hint.splitlines() {
            for w in self._wrap(hl, inner - 4) {
                lines.append(self._pad(f"  {w}"));
            }
        }
    }
    lines.append(self._pad(""));
    lines.append(BOX_BL + (BOX_H * inner) + BOX_BR);
    return "\n".join(lines);
}

impl DiagnosticFormatter.format_collection(self: DiagnosticFormatter, collection: DiagnosticCollection) -> str {
    if len(collection.items) == 0 { return ""; }
    parts: list[str] = [];
    for diag in collection.items {
        parts.append(self.format_diagnostic(diag));
        parts.append("");
    }
    return "\n".join(parts);
}

impl DiagnosticFormatter._pad(self: DiagnosticFormatter, content: str) -> str {
    inner = self.width - 2;
    if len(content) > inner { content = content[:inner - 3] + "..."; }
    return BOX_V + content + (" " * (inner - len(content))) + BOX_V;
}

impl DiagnosticFormatter._wrap(self: DiagnosticFormatter, text: str, max_w: int) -> list[str] {
    if len(text) <= max_w { return [text]; }
    lines: list[str] = [];
    words = text.split(" ");
    current = "";
    for word in words {
        if not current { current = word; }
        elif len(current) + 1 + len(word) <= max_w { current += " " + word; }
        else { lines.append(current); current = word; }
    }
    if current { lines.append(current); }
    return lines;
}

# ============== Module Functions ==============

impl get_default_detectors() -> list[BaseDetector] {
    return [CompilationErrorDetector(), MissingDependencyDetector(), ImportNotFoundDetector(), SyntaxErrorDetector()];
}

impl is_debug_mode(config: object = None) -> bool {
    if config {
        try {
            client_cfg = config.get_plugin_config("client");
            if client_cfg and client_cfg.get("debug", False) { return True; }
        } except Exception { ; }
    }
    return os.environ.get("JAC_DEBUG", "").lower() in ("1", "true", "yes");
}

impl format_build_error(error_output: str, project_dir: Path, source_map: dict[str, str] = {}, config: object = None) -> str {
    # Build context
    jac_files: list[Path] = [];
    try {
        for jac_file in project_dir.rglob("*.jac") {
            parts = jac_file.parts;
            if ".jac" not in parts and "node_modules" not in parts {
                jac_files.append(jac_file);
            }
        }
    } except Exception { ; }

    installed_packages: set[str] = set();
    node_modules = project_dir / ".jac" / "client" / "node_modules";
    if node_modules.exists() {
        try {
            for item in node_modules.iterdir() {
                if item.is_dir() and not item.name.startswith(".") {
                    if item.name.startswith("@") {
                        for subitem in item.iterdir() {
                            if subitem.is_dir() {
                                installed_packages.add(f"{item.name}/{subitem.name}");
                            }
                        }
                    } else {
                        installed_packages.add(item.name);
                    }
                }
            }
        } except Exception { ; }
    }

    ctx = BuildContext(
        error_output=error_output,
        source_map=source_map,
        project_dir=project_dir,
        jac_files=jac_files,
        installed_packages=installed_packages
    );

    # Run detectors
    engine = DiagnosticEngine();
    engine.register_all(get_default_detectors());
    diagnostics = engine.analyze(ctx);

    # Format output
    formatter = DiagnosticFormatter();
    formatted = formatter.format_collection(diagnostics);

    if is_debug_mode(config) {
        formatted += "\n\n--- Raw Error (debug=true) ---\n";
        formatted += error_output;
        formatted += "\n--- End Raw Error ---\n";
    }
    return formatted;
}
