"""Implementation of BundleErrorReporter for parsing and formatting bundling errors."""

# Error type configurations: patterns, identifier_regex, suggestion templates
glob ERROR_TYPES: dict = {
    'DuplicateImport': {
        'patterns': ['has already been declared', 'varredeclaration'],
        'id_regex': r"Identifier\s+'([^']+)'",
        'suggestion': "Remove duplicate 'cl import' of '{id}' in your .jac file.",
        'suggestion_generic': "Remove duplicate 'cl import' statements for the same symbol."
    },
    'ModuleNotFound': {
        'patterns': ['module not found', 'cannot find module'],
        'id_regex': r"(?:find|resolve)\s+module\s+['\"]([^'\"]+)['\"]",
        'suggestion': "Run 'jac add --npm {id}' or verify the import path.",
        'suggestion_generic': "Run 'jac add --npm <package>' or verify the import path."
    },
    'ExportNotFound': {
        'patterns': ['is not exported'],
        'id_regex': r"['\"]([^'\"]+)['\"].*(?:not exported|export.*not found)",
        'suggestion': "Verify '{id}' is exported from the source module.",
        'suggestion_generic': "Verify the symbol is exported from the source module."
    },
    'SyntaxError': {
        'patterns': ['unexpected token', 'syntaxerror'],
        'id_regex': None,
        'suggestion': "Check JSX syntax and JavaScript expressions in your .jac file.",
        'suggestion_generic': "Check JSX syntax and JavaScript expressions in your .jac file."
    }
};

"""Classify error type from raw output."""
impl BundleErrorReporter._classify_error(raw_error: str) -> str {
    error_lower = raw_error.lower();
    for (error_type, config) in ERROR_TYPES.items() {
        for pattern in config['patterns'] {
            if pattern in error_lower {
                return error_type;
            }
        }
    }
    # Special case: "export" + "not found" = ExportNotFound
    if 'export' in error_lower and 'not found' in error_lower {
        return 'ExportNotFound';
    }
    return 'CompilationError';
}

"""Extract identifier based on error type."""
impl BundleErrorReporter._extract_identifier(raw_error: str, error_type: str) -> (str | None) {
    config = ERROR_TYPES.get(error_type);
    if config and config.get('id_regex') {
        m = re.search(config['id_regex'], raw_error, re.IGNORECASE);
        if m {
            return m.group(1);
        }
    }
    return None;
}

"""Get actionable suggestion for error type."""
impl BundleErrorReporter._get_suggestion(error_type: str, identifier: (str | None)) -> (str | None) {
    config = ERROR_TYPES.get(error_type);
    if not config {
        return None;
    }
    if identifier and '{id}' in config.get('suggestion', '') {
        return config['suggestion'].replace('{id}', identifier);
    }
    return config.get('suggestion_generic');
}

"""Map compiled .js path to source .jac file."""
impl BundleErrorReporter._resolve_jac_source(compiled_path: str) -> (str | None) {
    try {
        for marker in ['/compiled/', '/build/'] {
            if marker in compiled_path {
                rel_part = compiled_path.split(marker)[-1];
                if rel_part.endswith('.js') {
                    jac_rel = rel_part[:-3] + '.jac';
                    potential_source = self.project_dir / jac_rel;
                    if potential_source.exists() {
                        return str(potential_source);
                    }
                }
                break;
            }
        }
    } except Exception {}
    return None;
}

"""Extract code context snippet from error output."""
impl BundleErrorReporter._extract_code_context(raw_error: str) -> (str | None) {
    lines = [];
    for line in raw_error.split('\n') {
        if re.match(r'^\s*>?\s*\d+\s*\|', line) {
            lines.append(line);
        } elif lines and re.match(r'^\s*\|?\s*\^', line) {
            lines.append(line);
            break;
        }
    }
    return '\n'.join(lines) if lines else None;
}

"""Parse raw error output into structured BundleError."""
impl BundleErrorReporter.parse_error(raw_error: str) -> BundleError {
    error_type = self._classify_error(raw_error);
    file_path: (str | None) = None;
    line: (int | None) = None;
    column: (int | None) = None;
    message: (str | None) = None;

    # Try multiple patterns to extract file path and location
    file_match = re.search(r'([^\s:]+\.jsx?):\s*(.+?)\s*\((\d+):(\d+)\)', raw_error);
    if file_match {
        compiled_path = file_match.group(1);
        message = file_match.group(2).strip();
        line = int(file_match.group(3));
        column = int(file_match.group(4));
        jac_source = self._resolve_jac_source(compiled_path);
        file_path = jac_source or compiled_path;
    }

    # Vite JSON format fallback
    if not file_path {
        vite_match = re.search(r'"file":\s*"([^"]+)".*?"line":\s*(\d+).*?"column":\s*(\d+)', raw_error, re.DOTALL);
        if vite_match {
            compiled_path = vite_match.group(1);
            line = int(vite_match.group(2));
            column = int(vite_match.group(3));
            jac_source = self._resolve_jac_source(compiled_path);
            file_path = jac_source or compiled_path;
        }
    }

    # Extract message if not found
    if not message {
        for err_line in raw_error.split('\n') {
            err_line = err_line.strip();
            if err_line and ('error' in err_line.lower() or 'cannot' in err_line.lower()
                or 'failed' in err_line.lower() or 'not found' in err_line.lower()) {
                message = re.sub(r'\x1b\[[0-9;]*m', '', err_line);
                message = re.sub(r'^(error:|npm error|npm ERR!)\s*', '', message, flags=re.IGNORECASE).strip();
                if message {
                    break;
                }
            }
        }
    }

    if not message {
        message = "Compilation failed";
    }

    identifier = self._extract_identifier(raw_error, error_type);

    return BundleError(
        error_type=error_type,
        message=message,
        file_path=file_path,
        line=line,
        column=column,
        identifier=identifier,
        code_context=self._extract_code_context(raw_error),
        suggestion=self._get_suggestion(error_type, identifier)
    );
}

"""Format BundleError as clean, readable string."""
impl BundleErrorReporter.format_error(error: BundleError) -> str {
    sep = "-" * 70;
    lines: list[str] = ["", sep, f"CLIENT BUNDLE ERROR [{error.error_type}]", sep];
    lines.append(f"  Error: {error.message}");

    if error.file_path {
        loc = f"  File:  {error.file_path}";
        if error.line {
            loc += f" (line {error.line}" + (f", col {error.column}" if error.column else "") + ")";
        }
        lines.append(loc);
    }

    if error.identifier {
        lines.append(f"  Symbol: '{error.identifier}'");
    }

    if error.code_context {
        lines.extend(["", "  Code:"] + [f"    {ctx}" for ctx in error.code_context.split('\n')]);
    }

    if error.suggestion {
        lines.extend(["", f"  Fix: {error.suggestion}"]);
    }

    lines.extend([sep, ""]);
    return '\n'.join(lines);
}

"""Parse and format error in single call."""
impl BundleErrorReporter.report_error(raw_error: str) -> str {
    return self.format_error(self.parse_error(raw_error));
}
