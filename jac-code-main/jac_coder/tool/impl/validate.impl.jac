impl validate_project(directory: str = "") -> str {
    tool_status("validate_project", directory or os.getcwd());

    project_dir = directory if directory else os.getcwd();
    if not os.path.isdir(project_dir) {
        tool_end("-> not found", error=True);
        return f"Error: directory not found: {project_dir}";
    }

    # Find all .jac files (skip .cl.jac for now — jac check doesn't support them)
    jac_files: list = [];
    for (dirpath, dirnames, filenames) in os.walk(project_dir) {
        # Skip hidden dirs, node_modules, __pycache__
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in ["node_modules", "__pycache__", "venv"]];
        for fname in filenames {
            if fname.endswith(".jac") and not fname.endswith(".cl.jac") {
                jac_files.append(os.path.join(dirpath, fname));
            }
        }
    }

    if not jac_files {
        tool_end("-> no .jac files");
        return "No .jac files found in " + project_dir;
    }

    # Phase 1: Auto-fix mechanical patterns before checking
    auto_fixes_total = 0;
    for fp in jac_files {
        fixes = _auto_fix_mechanical(fp);
        auto_fixes_total += fixes;
    }

    # Phase 2: Run full jac check on each file, collect ALL errors
    all_errors: list = [];
    files_checked = 0;
    files_clean = 0;

    for fp in jac_files {
        rel_path = os.path.relpath(fp, project_dir);
        try {
            result = subprocess.run(
                ["jac", "check", fp],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=30
            );
            files_checked += 1;

            if result.returncode == 0 {
                files_clean += 1;
            } else {
                output = (result.stderr or result.stdout or "").strip();
                if output {
                    # Parse individual errors
                    for line in output.split("\n") {
                        line = line.strip();
                        if line.startswith("✖ Error:") or line.startswith("⚠ warning:") {
                            all_errors.append(f"  {rel_path}: {line}");
                        }
                    }
                }
            }
        } except subprocess.TimeoutExpired {
            all_errors.append(f"  {rel_path}: TIMEOUT (>30s)");
            files_checked += 1;
        } except Exception as e {
            all_errors.append(f"  {rel_path}: CHECK FAILED - {str(e)}");
            files_checked += 1;
        }
    }

    # Phase 3: Build structured report
    parts: list = [];

    if auto_fixes_total > 0 {
        parts.append(f"Auto-fixed {auto_fixes_total} mechanical issues (root()->root(), deprecated syntax).");
    }

    parts.append(f"Checked {files_checked} files: {files_clean} clean, {files_checked - files_clean} with issues.");

    if all_errors {
        # Categorize errors vs warnings
        errors = [e for e in all_errors if "Error:" in e];
        warnings = [e for e in all_errors if "warning:" in e];

        if errors {
            parts.append(f"\nErrors ({len(errors)}):");
            for e in errors[:30] {
                parts.append(e);
                # Add fix hint
                hint = _get_error_hint(e);
                if hint {
                    parts.append(f"    → {hint}");
                }
            }
            if len(errors) > 30 {
                parts.append(f"  ... and {len(errors) - 30} more errors");
            }
        }

        if warnings {
            parts.append(f"\nWarnings ({len(warnings)}):");
            for w in warnings[:10] {
                parts.append(w);
            }
            if len(warnings) > 10 {
                parts.append(f"  ... and {len(warnings) - 10} more warnings");
            }
        }

        track_error();
        tool_end(f"-> {len(errors)} errors, {len(warnings)} warnings", error=len(errors) > 0);
    } else {
        parts.append("\nAll files pass type-check.");
        tool_end(f"-> all clean");
    }

    return "\n".join(parts);
}


def _auto_fix_mechanical(file_path: str) -> int {
    try {
        with open(file_path, "r", encoding="utf-8") as f {
            content = f.read();
        }
    } except Exception {
        return 0;
    }

    original = content;
    is_client = file_path.endswith(".cl.jac");

    # Fix 1: bare root → root() (deprecated)
    # Only match lowercase 'root' not followed by '(' — skip Root (type name)
    content = re.sub(r'(?<!\w)root(?!\s*\()(?!\w)', 'root()', content);

    # Fix 2: (?:Type) → [?:Type] (deprecated filter syntax)
    content = re.sub(r'\(\?:(\w+)\)', r'[?:\1]', content);

    # Fix 3: (?:Type, cond) → [?:Type, cond] (deprecated with condition)
    content = re.sub(r'\(\?:(\w+),([^)]+)\)', r'[?:\1,\2]', content);

    # Fix 4: def: pub → def:pub (no space after colon)
    content = re.sub(r'\bdef:\s+pub\b', 'def:pub', content);
    content = re.sub(r'\bdef:\s+priv\b', 'def:priv', content);

    # Fix 5: for p: Type in → for p in (no type annotation on loop var)
    content = re.sub(r'\bfor\s+(\w+)\s*:\s*\w+\s+in\b', r'for \1 in', content);

    # Fix 6: import path slashes → dots (.cl.jac files)
    if is_client {
        def _fix_slashes(m: Any) -> str {
            prefix = m.group(1);
            path = m.group(2);
            return prefix + path.replace("/", ".") + '"';
        }
        content = re.sub(
            r'(import\s+from\s+")((?:[.]*)[^"]*)"',
            _fix_slashes,
            content
        );
    }

    # Fix 7: className → class (in .cl.jac JSX)
    if is_client {
        content = re.sub(r'\bclassName\s*=', 'class=', content);
    }

    # Count fixes and write if changed
    if content != original {
        fix_count = 0;
        # Count each type of change
        for (old_pat, new_pat) in [
            ("root()", "root()"), ("def:pub", "def:pub"),
            ("[?:", "[?:"), ("class=", "class=")
        ] {
            fix_count += content.count(new_pat) - original.count(new_pat);
        }
        fix_count = max(fix_count, 1);
        try {
            with open(file_path, "w") as f {
                f.write(content);
            }
        } except Exception {
            return 0;
        }
        return fix_count;
    }

    return 0;
}


def _get_error_hint(error_line: str) -> str {
    e = error_line.lower();

    if "has no attribute" in e {
        return "Field was removed or renamed. Check the object definition.";
    }
    if "type is unknown" in e and "cannot access" in e {
        return "Add type annotation to the variable or cast with str()/int()/list().";
    }
    if "cannot return" in e and "expected" in e {
        return "Return type doesn't match. Add explicit type annotation or cast.";
    }
    if "missing from nonetype" in e {
        return "Variable might be None. Add null check: if var { var.field }";
    }
    if "cannot assign" in e and "unknown" in e {
        return "Add type annotation: var: str = expression;";
    }
    if "bare 'root()'" in e {
        return "Use root() instead of root (auto-fixable by validate_project).";
    }
    if "deprecated" in e and "(?:" in e {
        return "Use [?:Type] instead of [?:Type] (auto-fixable by validate_project).";
    }
    if "parameter" in e and "type annotation" in e {
        return "Add type annotation to parameter: param: Type.";
    }
    if "expected 'with'" in e and "can" in e {
        return "Use 'def' for regular methods in obj. 'can' is only for walker/node abilities with 'with Type entry'.";
    }
    if "import:py" in e or "import: py" in e {
        return "import:py is deprecated. Use 'import from module { name }' instead.";
    }
    if "self" in e and "missing" in e and "type" in e {
        return "self is implicit in Jac — remove it from method parameters.";
    }
    if "pass" in e and "unexpected" in e {
        return "'pass' is not a keyword in Jac. Use a no-op statement or empty block.";
    }
    return "";
}
