"""Implementation of analysis commands (check, lint, format, test, gen_parser).

Direct implementations - no delegation to cli.jac.
"""

import from pathlib { Path }
import from fnmatch { fnmatch }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report {
    print_file_progress,
    print_failures,
    print_failed_summary,
    print_final_summary
}

"""Run type checker for specified .jac files."""
impl check(
    paths: list,
    print_errs: bool = True,
    ignore: list = [],
    parse_only: bool = False,
    nowarn: bool = False
) -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from time { time }
    if isinstance(paths, str) {
        paths = [paths];
    }
    start_time = time();
    ignore_list = _normalize_ignore_patterns(ignore);
    # Helper to process and store single file result
    def process_file_result(file_path: str, idx: int, total: int) -> None {
        nonlocal total_files , total_errors , total_warnings , failed_files ;
        total_files += 1;
        (success, errs, warns, errors_list, warnings_list) = check_single_file(
            prog, file_path
        );
        total_errors += errs;
        total_warnings += warns;

        # Print progress line
        print_file_progress(file_path, success, idx, total);

        # Store only failed results
        if not success {
            failed_files += 1;
            failed_results.append(
                {'path': file_path, 'errors': errors_list, 'warnings': warnings_list}
            );
        }
    }
    # Store failed file results for later detailed output
    failed_results: list[dict] = [];
    def check_single_file(
        prog: JacProgram, file_path: str
    ) -> tuple[bool, int, int, list, list] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1, 0, [], []);
        }
        try {
            (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
            prog.compile(file_path=file_path, type_check=not parse_only, no_cgen=True);
            new_errors = prog.errors_had[err_start:];
            new_warnings = prog.warnings_had[warn_start:];
            # Filter out errors/warnings from ignored files and non-.jac files
            # By default, only show errors from .jac files (not from Python stdlib, stubs, etc.)
            # TODO: This is ad-hoc, need proper error handling across
            # different file types; will be addressed in future refactor.
            def filter_issues(issues: list) -> list {
                return [
                    i
                    for i in issues
                    if i.loc
                    and i.loc.mod_path
                    and i.loc.mod_path.endswith(".jac")
                    and not any(p in i.loc.mod_path for p in ignore_list)
                ];
            }
            filtered_errors = filter_issues(new_errors);
            filtered_warnings = filter_issues(new_warnings);
            err_count = len(filtered_errors);
            warn_count = len(filtered_warnings);

            return (
                err_count == 0,
                err_count,
                warn_count,
                filtered_errors,
                filtered_warnings
            );
        } except Exception as e {
            console.error(f"Error checking '{file_path}': {e}");
            return (False, 1, 0, [], []);
        }
    }
    total_files = failed_files=total_errors=total_warnings=0;
    prog = JacProgram();
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not _should_ignore(path, ignore_list) {
                process_file_result(path, 1, 1);
            }
        } elif path_obj.is_dir() {
            all_files = [
                str(jac_file)
                for jac_file in path_obj.glob('**/*.jac')
                if jac_file.is_file()
                and not _should_ignore(str(jac_file), ignore_list)
            ];
            total_to_check = len(all_files);
            for (idx, jac_file_path) in enumerate(all_files, 1) {
                process_file_result(jac_file_path, idx, total_to_check);
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            failed_files += 1;
            total_errors += 1;
        }
    }
    # Print FAILURES section and summary
    if failed_files > 0 {
        if print_errs {
            print_failures(failed_results, nowarn);
        }
        print_failed_summary(failed_results);
    }
    # Print final summary line
    elapsed = time() - start_time;
    print_final_summary(total_files - failed_files, failed_files, elapsed);
    return 1 if total_errors > 0 else 0;
}

"""Lint .jac files and report violations."""
impl lint(paths: list, fix: bool = False, ignore: list = []) -> int {
    import from jaclang.jac0core.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    ignore_list = _normalize_ignore_patterns(ignore);
    def lint_report_file(file_path: str) -> tuple[bool, int] {
        # Lint-only: report errors without formatting or writing files
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1);
        }
        console.print(f"  Linting {file_path}...");
        try {
            prog = JacProgram.jac_file_linter(str(path_obj));
            error_count = 0;
            for error in prog.errors_had {
                console.error(f"{error}");
                error_count += 1;
            }
            return (True, error_count);
        } except Exception as e {
            console.error(f"Error linting '{file_path}': {e}");
            return (False, 1);
        }
    }
    def lint_fix_file(file_path: str) -> tuple[bool, int, int] {
        # Lint+fix: apply fixes and write files back
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1, 1);
        }
        console.print(f"  Lint-fixing {file_path}...");
        try {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=True);
            try {
                formatted_code = prog.mod.main.gen.jac;
                original_code = prog.mod.main.source.code;
            } except Exception {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                err_count = len(prog.errors_had) or 1;
                return (False, err_count, err_count);
            }
            error_count = 0;
            unfixable_count = 0;
            for error in prog.errors_had {
                console.error(f"{error}");
                error_count += 1;
                if "[no-print]" in str(error) {
                    unfixable_count += 1;
                }
            }
            # Only write if there were lint violations to fix
            if error_count > unfixable_count {
                changed = formatted_code != original_code;
                if changed {
                    with open(str(path_obj), 'w', encoding='utf-8') as f {
                        f.write(formatted_code);
                    }
                }
                for impl_mod in prog.mod.main.impl_mod {
                    impl_path = impl_mod.loc.mod_path;
                    impl_formatted = impl_mod.gen.jac;
                    impl_original = impl_mod.source.code;
                    if (impl_formatted != impl_original) {
                        with open(impl_path, 'w', encoding='utf-8') as f {
                            f.write(impl_formatted);
                        }
                    }
                }
            }
            return (True, error_count, unfixable_count);
        } except Exception as e {
            console.error(f"Error linting '{file_path}': {e}");
            return (False, 1, 1);
        }
    }
    total_files = 0;
    failed_files = 0;
    total_errors = 0;
    total_unfixable = 0;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not _should_ignore(path, ignore_list) {
                total_files += 1;
                if fix {
                    (success, errors, unfixable) = lint_fix_file(path);
                    total_unfixable += unfixable;
                } else {
                    (success, errors) = lint_report_file(path);
                }
                total_errors += errors;
                if not success {
                    failed_files += 1;
                }
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                if not _should_ignore(str(jac_file), ignore_list) {
                    total_files += 1;
                    if fix {
                        (success, errors, unfixable) = lint_fix_file(str(jac_file));
                        total_unfixable += unfixable;
                    } else {
                        (success, errors) = lint_report_file(str(jac_file));
                    }
                    total_errors += errors;
                    if not success {
                        failed_files += 1;
                    }
                }
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            failed_files += 1;
            total_errors += 1;
        }
    }
    failing_errors = total_unfixable if fix else total_errors;
    if fix and total_errors > 0 {
        fixed_count = total_errors - total_unfixable;
        parts: list[str] = [];
        if fixed_count > 0 {
            parts.append(f"{fixed_count} fixed");
        }
        if total_unfixable > 0 {
            parts.append(f"{total_unfixable} unfixable");
        }
        detail = ", ".join(parts);
        summary_msg = f"Linted {total_files} '.jac' files: {total_errors} errors ({detail}).";
    } else {
        summary_msg = f"Linted {total_files} '.jac' files: {total_errors} errors found.";
    }
    if failing_errors > 0 {
        console.error(summary_msg);
        return 1;
    }
    console.success(summary_msg);
    return 0;
}

"""Format .jac files with improved code style."""
impl format(
    paths: list, to_screen: bool = False, lintfix: bool = False, check: bool = False
) -> int {
    import from jaclang.jac0core.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    # Track unformatted files for check mode
    unformatted_files: list[str] = [];
    def write_formatted_code(code: str, target_path: str) -> None {
        if to_screen {
            console.print(code);
        } elif not check {
            try {
                with open(target_path, 'w', encoding='utf-8') as f {
                    f.write(code);
                }
            } except Exception as e {
                console.error(f"Error writing formatted code to '{target_path}': {e}");
            }
        }
    }
    def format_single_file(file_path: str) -> tuple[bool, bool, int] {
        # Returns (success, changed, lint_error_count)
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, False, 0);
        }
        try {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=lintfix);
            if prog.errors_had {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                return (False, False, 0);
            }
            try {
                formatted_code = prog.mod.main.gen.jac;
                original_code = prog.mod.main.source.code;
                changed = formatted_code != original_code;
                write_formatted_code(formatted_code, str(path_obj));

                # Write impl modules (.impl.jac files)
                for impl_mod in prog.mod.main.impl_mod {
                    impl_path = impl_mod.loc.mod_path;
                    impl_formatted = impl_mod.gen.jac;
                    impl_original = impl_mod.source.code;
                    if (impl_formatted != impl_original) {
                        write_formatted_code(impl_formatted, impl_path);
                        changed = True;
                    }
                }
            } except Exception {
                # Can't produce formatted output (parse error)
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                return (False, False, 0);
            }
            # Report unfixable lint errors (e.g. [no-print])
            lint_errors = 0;
            if lintfix {
                for error in prog.errors_had {
                    console.error(f"{error}");
                    lint_errors += 1;
                }
            }
            return (True, changed, lint_errors);
        } except Exception as e {
            console.error(f"Error formatting '{file_path}': {e}");
            return (False, False, 0);
        }
    }
    total_files = 0;
    failed_files = 0;
    changed_files = 0;
    total_errors = 0;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            total_files += 1;
            (success, changed, errors) = format_single_file(path);
            total_errors += errors;
            if not success {
                failed_files += 1;
            } elif changed {
                changed_files += 1;
                if check {
                    unformatted_files.append(path);
                }
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                total_files += 1;
                (success, changed, errors) = format_single_file(str(jac_file));
                total_errors += errors;
                if not success {
                    failed_files += 1;
                } elif changed {
                    changed_files += 1;
                    if check {
                        unformatted_files.append(str(jac_file));
                    }
                }
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            failed_files += 1;
        }
    }
    # In check mode, report all issues together
    if check {
        has_errors = False;
        if len(unformatted_files) > 0 {
            console.error("The following files are not properly formatted:");
            for file in unformatted_files {
                console.error(f"  jac format --lintfix {file}");
            }
            has_errors = True;
        }
        if failed_files > 0 {
            console.error(
                f"\n{failed_files} file(s) have syntax errors (see errors above)."
            );
            console.error(
                "Fix the syntax errors or rename files with '*_err.jac' suffix to exclude them."
            );
            has_errors = True;
        }
        if has_errors {
            return 1;
        }
        if (len(paths) == 1) and Path(paths[0]).is_dir() {
            console.success(
                f"Checked {total_files}/{total_files} '.jac' files - all formatted correctly."
            );
        }
        return 0;
    }
    # Non-check mode summary
    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        summary_msg = f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).";
        if failed_files > 0 {
            console.error(summary_msg);
        } else {
            console.success(summary_msg);
        }
    }
    if failed_files > 0 {
        return 1;
    }
    if total_errors > 0 {
        return 1;
    }
    if changed_files > 0 {
        return 1;
    }
    return 0;
}

"""Run the test suite in the specified .jac file or directory."""
impl `test(
    filepath: str = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    verbose: bool = False
) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    Jac.setup();
    failcount = Jac.run_test(
        filepath=filepath,
        func_name=('test_' + test_name) if test_name else None,
        filter=filter,
        xit=xit,
        maxfail=maxfail,
        directory=directory,
        verbose=verbose
    );
    if failcount {
        console.error(f"Tests failed: {failcount}");
        return 1;
    }
    return 0;
}

"""Generate static parser."""
impl gen_parser -> int {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    console.success('Parser generated.');
    return 0;
}

"""Extract grammar from the Jac parser."""
impl grammar(lark: bool = False, output: str = "") -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.tool.grammar_extract_pass { GrammarExtractPass }
    import jaclang;
    parser_path = str(
        Path(jaclang.__file__).parent / "jac0core" / "parser" / "parser.jac"
    );
    prog = JacProgram();
    mod = prog.compile(parser_path, no_cgen=True);
    if prog.errors_had {
        console.error("Failed to compile parser module.");
        for e in prog.errors_had {
            console.error(f"  {e}");
        }
        return 1;
    }
    pass_ = GrammarExtractPass(ir_in=mod, prog=prog);
    if len(pass_.rules) == 0 {
        console.error("No grammar rules extracted.");
        return 1;
    }
    text = pass_.emit_lark() if lark else pass_.emit_ebnf();
    if output {
        with open(output, "w", encoding="utf-8") as f {
            f.write(text);
            f.write("\n");
        }
        fmt_name = "Lark" if lark else "EBNF";
        console.success(
            f"{fmt_name} grammar ({len(pass_.rules)} rules) written to {output}"
        );
    } else {
        console.print(text);
    }
    return 0;
}

"""Normalize ignore patterns by stripping whitespace and trailing slashes."""
def _normalize_ignore_patterns(ignore: list) -> list {
    normalized = [];
    for p in (ignore or []) {
        stripped = p.strip();
        if stripped {
            normalized.append(stripped.rstrip('/'));
        }
    }
    return normalized;
}

"""Check if a file path should be ignored based on patterns.
Supports both exact matches and wildcard patterns (e.g., 'jac-*').
"""
def _should_ignore(file_path: str, ignore_patterns: list) -> bool {
    if not ignore_patterns {
        return False;
    }
    path_parts = Path(file_path).parts;
    # Patterns are already normalized in ignore_list
    for pattern in ignore_patterns {
        # fnmatch handles both exact and wildcard matches
        for part in path_parts {
            if fnmatch(part, pattern) {
                return True;
            }
        }
    }
    return False;
}
