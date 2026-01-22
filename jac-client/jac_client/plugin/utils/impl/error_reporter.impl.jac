"""Implementation of BundleErrorReporter for parsing and formatting bundling errors."""

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
    } except Exception { }
    return None;
}

impl BundleErrorReporter._extract_identifier(
    raw_error: str, error_type: str
) -> (str | None) {
    # Generic: find first quoted string (single or double quotes)
    m = re.search(r'["\']([^"\']+)["\']', raw_error);
    return m.group(1) if m else None;
}

impl BundleErrorReporter._classify_error(raw_error: str) -> str {
    error_lower = raw_error.lower();
    if 'already been declared' in error_lower or 'redeclaration' in error_lower {
        return 'DuplicateImport';
    }
    if 'could not resolve' in error_lower {
        return 'ImportResolveError';
    }
    if 'module not found' in error_lower or 'cannot find module' in error_lower {
        return 'ModuleNotFound';
    }
    if 'not exported' in error_lower
    or ('export' in error_lower and 'not found' in error_lower) {
        return 'ExportNotFound';
    }
    if 'unexpected token' in error_lower or 'syntaxerror' in error_lower {
        return 'SyntaxError';
    }
    return 'CompilationError';
}

impl BundleErrorReporter._get_suggestion(
    error_type: str, identifier: (str | None)
) -> (str | None) {
    id_str = f"'{identifier}'" if identifier else "the symbol";
    suggestions = {
        'DuplicateImport': f"Remove duplicate 'cl import' of {id_str} in your .jac file.",
        'ImportResolveError': f"Check that {id_str} exists and the import path is correct.",
        'ModuleNotFound': f"Run 'jac add --npm <package>' or verify the import path for {id_str}.",
        'ExportNotFound': f"Verify {id_str} is exported from the source module.",
        'SyntaxError': "Check JSX syntax and JavaScript expressions in your .jac file."
    };
    return suggestions.get(error_type);
}

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

impl BundleErrorReporter._extract_file_info(raw_error: str) -> tuple {
    # Pattern 1: Babel - /path/file.js: Message (line:col)
    m = re.search(r'([^\s:]+\.jsx?):\s*.+?\s*\((\d+):(\d+)\)', raw_error);
    if m {
        return (m.group(1), int(m.group(2)), int(m.group(3)));
    }
    # Pattern 2: Vite JSON - "file": "path", "line": N, "column": N
    m = re.search(
        r'"file":\s*"([^"]+)".*?"line":\s*(\d+).*?"column":\s*(\d+)',
        raw_error,
        re.DOTALL
    );
    if m {
        return (m.group(1), int(m.group(2)), int(m.group(3)));
    }
    # Pattern 3: Rollup - file: /path/to/file.js
    m = re.search(r'^file:\s*(.+\.jsx?)\s*$', raw_error, re.MULTILINE);
    if m {
        return (m.group(1).strip(), None, None);
    }
    return (None, None, None);
}

impl BundleErrorReporter._extract_message(raw_error: str) -> str {
    skip_words = ['build failed', '✗', '✖', 'error during build', 'command:'];
    for line in raw_error.split('\n') {
        line = line.strip();
        if not line or any(s in line.lower() for s in skip_words) {
            continue;
        }
        # Skip stack trace lines
        if line.startswith('at ') or 'node_modules' in line {
            continue;
        }
        # Found a real error line
        if any(
            kw in line.lower()
            for kw in [
                'could not',
                'cannot',
                'error',
                'failed',
                'not found',
                'unexpected'
            ]
        ) {
            msg = re.sub(r'\x1b\[[0-9;]*m', '', line);  # Strip ANSI
            msg = re.sub(
                r'^(error:|npm error|npm ERR!)\s*', '', msg, flags=re.IGNORECASE
            );
            return msg.strip();
        }
    }
    return "Compilation failed";
}

impl BundleErrorReporter.parse_error(raw_error: str) -> BundleError {
    error_type = self._classify_error(raw_error);
    message = self._extract_message(raw_error);
    (compiled_path, line, column) = self._extract_file_info(raw_error);
    file_path = None;
    if compiled_path {
        jac_source = self._resolve_jac_source(compiled_path);
        file_path = jac_source or compiled_path;
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

impl BundleErrorReporter.format_error(error: BundleError) -> str {
    sep = "-" * 70;
    lines: list[str] = ["", sep, f"CLIENT BUNDLE ERROR [{error.error_type}]", sep];
    lines.append(f"  Error: {error.message}");
    if error.file_path {
        loc = f"  File:  {error.file_path}";
        if error.line {
            loc += f" (line {error.line}" + (
                f", col {error.column}" if error.column else ""
            ) + ")";
        }
        lines.append(loc);
    }
    if error.identifier {
        lines.append(f"  Symbol: '{error.identifier}'");
    }
    if error.code_context {
        lines.extend(
            ["", "  Code:"] + [f"    {ctx}" for ctx in error.code_context.split('\n')]
        );
    }
    if error.suggestion {
        lines.extend(["", f"  Fix: {error.suggestion}"]);
    }
    lines.extend([sep, ""]);
    return '\n'.join(lines);
}

impl BundleErrorReporter.report_error(raw_error: str) -> str {
    return self.format_error(self.parse_error(raw_error));
}
