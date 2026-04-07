# ===========================================================================
# JS-to-Jac Sanitization Pipeline
# ===========================================================================

# JS built-in classes that need Reflect.construct() to get an object instance.
# Date()        -> returns a string  (no methods)
# new Date()    -> returns Date object (has .getFullYear(), .toISOString(), etc.)
# Jac has no `new` keyword, so: Reflect.construct(Date, [])
glob _JS_CONSTRUCTORS: list = [
         "Date",
         "WebSocket",
         "TextDecoder",
         "TextEncoder",
         "Uint8Array",
         "Int8Array",
         "Uint16Array",
         "Float32Array",
         "Float64Array",
         "ArrayBuffer",
         "DataView",
         "Map",
         "Set",
         "WeakMap",
         "WeakSet",
         "Error",
         "TypeError",
         "RangeError",
         "SyntaxError",
         "ReferenceError",
         "URL",
         "URLSearchParams",
         "FormData",
         "Blob",
         "File",
         "FileReader",
         "Headers",
         "Request",
         "Response",
         "RegExp",
         "Promise",
         "AbortController",
         "MutationObserver",
         "ResizeObserver",
         "IntersectionObserver",
         "BroadcastChannel",
         "MessageChannel",
         "Worker"
     ];

# Browser globals that should not be used as function names inside components.
glob _BROWSER_GLOBALS: list = [
         "open",
         "close",
         "print",
         "focus",
         "blur",
         "scroll",
         "fetch",
         "stop",
         "find",
         "alert",
         "confirm",
         "prompt"
     ];


def _fix_template_literal(m: Any) -> str {
    inner = m.group(1);
    inner = inner.replace("${", "{");
    return "f\"" + inner + "\"";
}


def _sanitize_jac(content: str, file_path: str) -> tuple {
    fixes: list = [];
    is_client = file_path.endswith(".cl.jac");

    # --- const / let / var declarations -> bare assignment ---
    before = content;
    content = re.sub(r'(?m)^(\s*)(const|let|var)\s+', r'\1', content);
    if content != before {
        n = len(re.findall(r'(?m)^(\s*)(const|let|var)\s+', before));
        fixes.append(
            "Removed " + str(n) + " JS declaration keyword(s) (const/let/var)"
        );
    }

    # --- def: pub / def: priv -> def:pub / def:priv (no space) ---
    before = content;
    content = re.sub(r'\bdef:\s+pub\b', 'def:pub', content);
    content = re.sub(r'\bdef:\s+priv\b', 'def:priv', content);
    if content != before {
        fixes.append("Fixed 'def: pub' to 'def:pub' (no space after colon)");
    }

    # --- for p: Type in ... -> for p in ... (no type on loop var) ---
    before = content;
    content = re.sub(r'\bfor\s+(\w+)\s*:\s*\w+\s+in\b', r'for \1 in', content);
    if content != before {
        fixes.append("Fixed typed loop variable: 'for p: Type in ...' to 'for p in ...' (Jac doesn't support type annotation on loop var)");
    }

    # --- Tuple unpacking: for i, k in ... -> for (i, k) in ... ---
    before = content;
    content = re.sub(r'\bfor\s+(\w+)\s*,\s*(\w+)\s+in\b', r'for (\1, \2) in', content);
    if content != before {
        fixes.append("Fixed tuple unpacking: added parentheses (Jac requires `for (a, b) in ...`)");
    }

    # --- Strict equality: === -> ==, !== -> != ---
    before = content;
    content = content.replace("!==", "!=");
    content = content.replace("===", "==");
    if content != before {
        fixes.append("Fixed strict equality (===/!==) to Jac equality (==/!=)");
    }

    # --- Arrow functions: (params) => { -> lambda params: any -> any { ---
    before = content;
    content = re.sub(r'\((\w+)\)\s*=>\s*\{', r'lambda \1: any -> any {', content);
    content = re.sub(r'(?<![.\w])(\w+)\s*=>\s*\{', r'lambda \1: any -> any {', content);
    content = re.sub(
        r'\((\w+),\s*(\w+)\)\s*=>\s*\{', r'lambda \1: any, \2: any -> any {', content
    );
    if content != before {
        fixes.append("Converted JS arrow function(s) to Jac lambda syntax");
    }

    # --- Template literals: `...${x}...` -> f"...{x}..." ---
    before = content;
    content = re.sub(r'`([^`]*)`', _fix_template_literal, content);
    if content != before {
        fixes.append("Converted JS template literal(s) to Jac f-string(s)");
    }

    # --- new ClassName(args) -> Reflect.construct(ClassName, [args]) ---
    # Only match PascalCase class names (start with uppercase)
    before = content;
    content = re.sub(
        r'\bnew\s+([A-Z]\w*)\(([^)]*)\)', r'Reflect.construct(\1, [\2])', content
    );
    if content != before {
        fixes.append("Converted new ClassName() to Reflect.construct()");
    }

    # --- export default / export -> remove ---
    before = content;
    content = re.sub(r'\bexport\s+default\s+', '', content);
    content = re.sub(r'\bexport\s+(?=function|class|const|let|var|def)', '', content);
    if content != before {
        fixes.append("Removed JS export keyword(s)");
    }

    # --- Import path slashes -> dots (CRITICAL: Jac uses dots, not slashes) ---
    # import from .ui/card { Card } -> import from .ui.card { Card }
    # import from ..components/ui/button -> import from ..components.ui.button
    before = content;
    content = re.sub(
        r'(import\s+from\s+"[.]*)["]',
        lambda m: m.group(0),  # no-op anchor
        content
    );
    # Fix slashes inside quoted import paths: "...anything/with/slashes"
    def _fix_import_slashes(m: Any) -> str {
        prefix = m.group(1);
        path = m.group(2);
        fixed_path = path.replace("/", ".");
        return prefix + fixed_path + '"';
    }
    content = re.sub(
        r'(import\s+from\s+")((?:[.]*)[^"]*)"',
        _fix_import_slashes,
        content
    );
    if content != before {
        fixes.append("Fixed import path slashes to dots (Jac uses dots, not slashes)");
    }

    # --- dict.get() not valid in .cl.jac — warn agent ---
    if is_client {
        get_calls = re.findall(r'\w+\.get\s*\(\s*"[^"]*"', content);
        if get_calls {
            fixes.append(
                "WARNING: .get('key') is not valid in .cl.jac — use d[\"key\"] with guard: "
                + "value = d[\"key\"] if \"key\" in d else default;"
            );
        }
    }

    # --- type(x) == dict not valid in .cl.jac ---
    if is_client {
        type_checks = re.findall(r'type\s*\(\s*\w+\s*\)\s*==\s*(?:dict|list|str|int|float|bool)', content);
        if type_checks {
            fixes.append(
                "WARNING: type(x) == dict is not valid in .cl.jac (Python types don't exist in JS runtime). "
                + "Use 'key' in x to guard dict access, or typeof for JS type checks."
            );
        }
    }

    # --- Reflect.globalThis → globalThis (Reflect doesn't have globalThis) ---
    if is_client {
        before = content;
        content = content.replace("Reflect.globalThis.", "globalThis.");
        if content != before {
            fixes.append("Fixed Reflect.globalThis to globalThis (Reflect is only for construct())");
        }
    }

    # --- Inline def/lambda in JSX attributes (CRITICAL .cl.jac error) ---
    if is_client {
        inline_defs = re.findall(r'=\{(?:def|lambda)\s*\(', content);
        inline_lambdas = re.findall(r'=\{lambda\s', content);
        if inline_defs or inline_lambdas {
            fixes.append(
                "WARNING: Found inline def(...) or lambda inside JSX attributes. "
                + "Extract to a named def handler ABOVE the return statement. "
                + "Example: def handle_click() -> None { ... } then onClick={handle_click}"
            );
        }
    }

    # --- ! operator → not (in .cl.jac, Jac uses 'not' not '!') ---
    if is_client {
        before = content;
        # Replace !variable but not !== (already handled) and not !important (CSS)
        content = re.sub(r'(?<!=)!(?!=)(?!important)(\w)', r'not \1', content);
        if content != before {
            fixes.append("Fixed ! operator to 'not' (Jac uses 'not', not '!')");
        }
    }

    # --- Missing def:pub on .cl.jac component functions ---
    if is_client {
        # Find def FunctionName() -> JsxElement without :pub
        missing_pub = re.findall(r'^def\s+[A-Z]\w*\s*\(.*\)\s*->\s*JsxElement', content, re.MULTILINE);
        if missing_pub {
            fixes.append(
                "WARNING: Component function missing def:pub — .cl.jac components must use def:pub to be importable. "
                + "Example: def:pub Layout() -> JsxElement { ... }"
            );
        }
    }

    # --- JS constructor().method() pattern for known built-ins ---
    # e.g. Date().getFullYear() -> Reflect.construct(Date, []).getFullYear()
    # Only when NOT already wrapped in Reflect.construct
    if is_client {
        for cls in _JS_CONSTRUCTORS {
            pattern = r'(?<!construct\()(?<!\w)' + cls + r'\(([^)]*)\)\.';
            if re.search(pattern, content) {
                replacement = "Reflect.construct(" + cls + r", [\1]).";
                content = re.sub(pattern, replacement, content);
                fixes.append(
                    "Fixed " + cls + "().method() to Reflect.construct(" + cls + ", [...]).method()"
                );
            }
        }
    }

    # --- Browser global name conflicts ---
    if is_client {
        for global_name in _BROWSER_GLOBALS {
            if re.search(r'\bdef\s+' + global_name + r'\s*\(', content) {
                cap_name = global_name[0].upper() + global_name[1:];
                fixes.append(
                    "WARNING: def " + global_name + "() shadows browser global window." + global_name + " - rename to handle" + cap_name + "()"
                );
            }
        }
    }

    return (content, fixes);
}


# ===========================================================================
# Quick Parse Check — syntax only, no type checking (fast, in-process)
# ===========================================================================
def _quick_parse_check(file_path: str, result_msg: str) -> str {
    try {
        import from jaclang.jac0core.program { JacProgram }
        prog = JacProgram();
        module = prog.compile(file_path=file_path, type_check=False, no_cgen=True);
        if module is None and prog.errors_had {
            error_lines: list = [];
            for e in prog.errors_had[:10] {
                error_lines.append(str(e));
            }
            errors = "\n".join(error_lines);
            hints = _get_fix_hints(errors);
            result_msg = result_msg + "\n\nSYNTAX ERRORS:\n" + errors;
            if hints {
                result_msg = result_msg + "\n\nFIX HINTS:\n" + hints;
            }
            result_msg = result_msg + "\nFix syntax errors before continuing.";
        }
    } except Exception { }
    return result_msg;
}


def _get_fix_hints(errors: str) -> str {
    hints: list = [];
    err_lower = errors.lower();

    if "?" in errors and ("unexpected" in err_lower or "ternary" in err_lower) {
        hints.append("- Replace `cond ? a : b` with `(a if cond else b)`");
    }
    if "=>" in errors {
        hints.append("- Replace `(x) => {` with `lambda x: any -> any {`");
    }
    if "const " in errors or "let " in errors or "var " in errors {
        hints.append("- Remove const/let/var keywords. Just use: x = value;");
    }
    if "new " in errors {
        hints.append("- Replace `new X(args)` with `Reflect.construct(X, [args])`");
    }
    if "semicolon" in err_lower or "expected `;`" in err_lower {
        hints.append("- Every statement must end with `;`");
    }
    if "import" in err_lower and ("error" in err_lower or "not found" in err_lower) {
        hints.append("- Never include .cl or .jac extensions in import paths");
        hints.append("- Use: import from .components.Name { Name }");
    }
    if "component" in err_lower and "unexpected" in err_lower {
        hints.append(
            "- No `component` keyword. Use: def:pub Name(props: dict) -> JsxElement { }"
        );
    }
    if "export" in err_lower {
        hints.append(
            "- Remove `export`/`export default`. Use def:pub for public functions"
        );
    }
    if "return type" in err_lower or "type" in err_lower and "expected" in err_lower {
        hints.append(
            "- Components return JsxElement, hooks return dict, handlers return None"
        );
    }

    return "\n".join(hints) if hints else "";
}


# ===========================================================================
# Runtime Error Detection (Preview Log)
# ===========================================================================
def _get_preview_log_pos(file_path: str) -> tuple {
    if not file_path.endswith(".cl.jac") {
        return ("", 0);
    }
    if not os.environ.get("JACCODER_WEB_MODE", "") {
        return ("", 0);
    }
    search_dir = os.path.dirname(file_path);
    for _ in range(5) {
        candidate = os.path.join(search_dir, ".jac-preview.log");
        if os.path.isfile(candidate) {
            return (candidate, os.path.getsize(candidate));
        }
        parent = os.path.dirname(search_dir);
        if parent == search_dir {
            break;
        }
        search_dir = parent;
    }
    return ("", 0);
}


def _check_preview_log(
    file_path: str, result_msg: str, log_path: str = "", log_pos: int = 0
) -> str {
    if not file_path.endswith(".cl.jac") {
        return result_msg;
    }
    if not log_path {
        return result_msg;
    }

    # Give Vite HMR time to process the file change
    time.sleep(1.5);

    if not os.path.isfile(log_path) {
        return result_msg;
    }

    try {
        # Only read NEW log lines that appeared after the write
        with open(log_path, "r", encoding="utf-8") as f {
            f.seek(log_pos);
            new_content = f.read();
        }
        if not new_content.strip() {
            return result_msg;
        }
        recent = new_content.strip().splitlines();

        # Filter "Failed to resolve import" only if the source .cl.jac file exists
        # (transient HMR timing issue). If the source file is missing, it's a REAL error.
        filtered: list = [];
        project_dir = os.path.dirname(file_path);
        # Walk up to find project root (where jac.toml lives)
        search_dir = project_dir;
        for _ in range(5) {
            if os.path.isfile(os.path.join(search_dir, "jac.toml")) {
                project_dir = search_dir;
                break;
            }
            parent = os.path.dirname(search_dir);
            if parent == search_dir {
                break;
            }
            search_dir = parent;
        }
        for line in recent {
            if "Failed to resolve import" in line {
                # Extract the import path from the error message
                # Format: Failed to resolve import "../components/ui/badge.js" from "..."
                import_match = re.search(r'Failed to resolve import "([^"]+)"', line);
                if import_match {
                    import_path = import_match.group(1);
                    # Convert .js import to .cl.jac source path
                    source_path = import_path.replace(".js", ".cl.jac");
                    # Resolve relative to the file being written
                    abs_source = os.path.normpath(
                        os.path.join(os.path.dirname(file_path), source_path)
                    );
                    if os.path.isfile(abs_source) {
                        # Source exists — transient HMR timing, skip it
                        continue;
                    }
                    # Also check from project root (compiled/ paths)
                    stripped = source_path.lstrip("./");
                    if os.path.isfile(os.path.join(project_dir, stripped)) {
                        continue;
                    }
                }
                # Source doesn't exist — real error, keep it
                filtered.append(
                    f"MISSING IMPORT: {line.strip()} — Create the missing .cl.jac file FIRST."
                );
            } else {
                filtered.append(line);
            }
        }
        recent = filtered;

        error_patterns = [
            "is not a function",
            "is not defined",
            "is not a constructor",
            "Cannot read properties of",
            "Cannot read property",
            "Unexpected token",
            "TypeError:",
            "ReferenceError:",
            "SyntaxError:",
            "Uncaught Error"
        ];

        found_errors: list = [];
        for line in recent {
            for pattern in error_patterns {
                if pattern in line and line.strip() not in found_errors {
                    found_errors.append(line.strip());
                    break;
                }
            }
        }

        if found_errors {
            result_msg = result_msg + "\n\nRUNTIME ERRORS (from live preview):";
            for err in found_errors[:5] {
                result_msg = result_msg + "\n  " + err;
            }
            if len(found_errors) > 5 {
                result_msg = result_msg + "\n  ... and " + str(len(found_errors) - 5) + " more";
            }

            # Add targeted fix hints based on error content
            hint_set: set = set();
            for err in found_errors {
                if "is not a function" in err {
                    hint_set.add(
                        "- Method on constructor result? Use Reflect.construct(ClassName, [args]).method()"
                    );
                }
                if "is not defined" in err {
                    hint_set.add("- Check imports: missing import or wrong path?");
                }
                if "is not a constructor" in err {
                    hint_set.add(
                        "- Use Reflect.construct(Class, [args]) instead of Class(args)"
                    );
                }
                if "Cannot read properties of undefined" in err
                or "Cannot read property" in err {
                    hint_set.add(
                        "- Accessing property on undefined. Check variable initialization and async timing"
                    );
                }
                if "Unexpected token" in err {
                    hint_set.add(
                        "- Syntax error in compiled output. Check for JS-only syntax (ternary, arrow fn, spread)"
                    );
                }
            }
            if hint_set {
                result_msg = result_msg + "\n\nRUNTIME FIX HINTS:";
                for hint in hint_set {
                    result_msg = result_msg + "\n" + hint;
                }
            }
            result_msg = result_msg + "\nCall jac_docs(query) to look up correct syntax BEFORE fixing. Do NOT guess.";
        }
    } except Exception { }

    return result_msg;
}


# ===========================================================================
# Tool Implementations
# ===========================================================================
impl read_file(file_path: str, offset: int = 0, limit: int = 2000) -> str {
    (file_path, err) = sandbox_path(file_path);
    if err {
        return err;
    }
    tool_status("read", file_path);
    p = Path(file_path);

    if not p.exists() {
        return f"Error: File not found: {file_path}";
    }

    if p.is_dir() {
        entries = sorted(os.listdir(str(p)));
        listing = [];
        for entry in entries {
            full = os.path.join(str(p), entry);
            if os.path.isdir(full) {
                listing.append(f"  {entry}/");
            } else {
                size = os.path.getsize(full);
                listing.append(f"  {entry} ({size} bytes)");
            }
        }
        return f"Directory: {file_path}\n" + "\n".join(listing);
    }

    (mime, _) = mimetypes.guess_type(str(p));
    if mime and not mime.startswith("text/") and mime != "application/json" {
        size = os.path.getsize(str(p));
        return f"Binary file: {file_path} ({size} bytes, type: {mime})";
    }

    try {
        content = p.read_text();
    } except Exception as e {
        return f"Error reading {file_path}: {str(e)}";
    }

    lines = content.splitlines();
    total = len(lines);

    if offset > 0 {
        lines = lines[offset:offset + limit];
        start_num = offset + 1;
    } else {
        lines = lines[:limit];
        start_num = 1;
    }

    numbered = [f"{i + start_num}: {line}" for (i, line) in enumerate(lines)];
    result = "\n".join(numbered);

    (result, was_truncated) = truncate_output(result);

    if was_truncated {
        result = result + "\n\n⚠ Output truncated. Use offset/limit to read remaining lines.";
    }
    if total > len(lines) {
        result = result + f"\n\n({total} total lines)";
    }

    tool_end(f"-> {total} lines");
    return result;
}


impl write_file(file_path: str, content: str) -> str {
    (file_path, err) = sandbox_path(file_path);
    if err {
        return err;
    }
    tool_status("write", file_path);
    p = Path(file_path);
    try {
        p.parent.mkdir(parents=True, exist_ok=True);

        # Snapshot preview log position BEFORE writing
        (log_path, log_pos) = _get_preview_log_pos(file_path);

        # Stage 1: Pre-write sanitization for .jac files
        auto_fixes: list = [];
        if file_path.endswith(".jac") {
            (content, auto_fixes) = _sanitize_jac(content, file_path);
        }

        p.write_text(content);
        line_count = len(content.splitlines());
        emit_event("file_written", {"path": file_path, "lines": line_count});
        if os.environ.get("JACCODER_WEB_MODE", "") {
            time.sleep(0.3);
        }
        result_msg = f"Written {line_count} lines to {file_path}";

        # Report auto-fixes so the LLM learns to avoid these patterns
        if auto_fixes {
            result_msg = result_msg + "\n\nAUTO-FIXED JS syntax:";
            for fix in auto_fixes {
                result_msg = result_msg + "\n  - " + fix;
            }
            result_msg = result_msg + "\nAvoid these JS patterns in future writes.";
        }

        # Write succeeded — close the Write step as success
        tool_end(f"-> {line_count} lines");

        # Stage 2: Compiler validation (separate step so errors show on "Check", not "Write")
        if file_path.endswith(".jac") {
            tool_status("jac_check", file_path);
            result_msg = _quick_parse_check(file_path, result_msg);
        }

        # Stage 3: Runtime error detection (only NEW log lines since write)
        result_msg = _check_preview_log(file_path, result_msg, log_path, log_pos);

        has_errors = "VALIDATION ERRORS" in result_msg or "RUNTIME ERRORS" in result_msg;
        if file_path.endswith(".jac") {
            tool_end(
                "-> " + ("errors found" if has_errors else "ok"), error=has_errors
            );
        }
        return result_msg;
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error writing {file_path}: {str(e)}";
    }
}


impl edit_file(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str {
    (file_path, err) = sandbox_path(file_path);
    if err {
        return err;
    }
    tool_status("edit", file_path);
    p = Path(file_path);

    if not p.exists() {
        return f"Error: File not found: {file_path}";
    }
    if not old_string {
        return "Error: old_string is required";
    }
    if old_string == new_string {
        return "Error: old_string and new_string must be different";
    }

    try {
        content = p.read_text();
    } except Exception as e {
        return f"Error reading {file_path}: {str(e)}";
    }

    content = content.replace("\r\n", "\n");
    old_string = old_string.replace("\r\n", "\n");
    new_string = new_string.replace("\r\n", "\n");

    # Stage 1: Sanitize the new_string before replacement
    auto_fixes: list = [];
    if file_path.endswith(".jac") {
        (new_string, auto_fixes) = _sanitize_jac(new_string, file_path);
    }

    count = content.count(old_string);

    if count == 0 {
        return "Error: old_string not found in file. Make sure it matches exactly (including whitespace/indentation).";
    }

    if count > 1 and not replace_all {
        return f"Error: old_string found {count} times. Use replace_all=true or provide more context to make the match unique.";
    }

    # Snapshot preview log position BEFORE writing
    (log_path, log_pos) = _get_preview_log_pos(file_path);

    if replace_all {
        new_content = content.replace(old_string, new_string);
    } else {
        new_content = content.replace(old_string, new_string, 1);
    }

    try {
        p.write_text(new_content);
    } except Exception as e {
        return f"Error writing {file_path}: {str(e)}";
    }

    replacements = count if replace_all else 1;
    emit_event("file_edited", {"path": file_path, "replacements": replacements});
    result_msg = f"Replaced {replacements} occurrence(s) in {file_path}";

    # Report auto-fixes
    if auto_fixes {
        result_msg = result_msg + "\n\nAUTO-FIXED JS syntax in new_string:";
        for fix in auto_fixes {
            result_msg = result_msg + "\n  - " + fix;
        }
        result_msg = result_msg + "\nAvoid these JS patterns in future edits.";
    }

    # Edit succeeded — close the Edit step as success
    tool_end(f"-> {replacements} edit(s)");

    # Stage 2: Compiler validation (separate step)
    if file_path.endswith(".jac") {
        tool_status("jac_check", file_path);
        result_msg = _quick_parse_check(file_path, result_msg);
    }

    # Stage 3: Runtime error detection (only NEW log lines since edit)
    result_msg = _check_preview_log(file_path, result_msg, log_path, log_pos);

    has_errors = "VALIDATION ERRORS" in result_msg or "RUNTIME ERRORS" in result_msg;
    if file_path.endswith(".jac") {
        tool_end("-> " + ("errors found" if has_errors else "ok"), error=has_errors);
    }
    return result_msg;
}


impl list_files(directory: str = ".", pattern: str = "**/*") -> str {
    (directory, err) = sandbox_path(directory);
    if err {
        return err;
    }
    tool_status("list", f"{directory} ({pattern})");
    p = Path(directory);
    if not p.exists() {
        return f"Error: Directory not found: {directory}";
    }
    try {
        files = sorted(
            [
                str(f)
                for f in p.glob(pattern)
                if f.is_file() and ".git" not in f.parts
            ]
        );
    } except Exception as e {
        return f"Error: {str(e)}";
    }
    if not files {
        tool_end("-> 0 files");
        return f"No files matching '{pattern}' in {directory}";
    }
    total = len(files);
    tool_end(f"-> {total} files");
    if total > 200 {
        return "\n".join(files[:200]) + f"\n\n... and {total - 200} more files ({total} total)";
    }
    return "\n".join(files);
}
