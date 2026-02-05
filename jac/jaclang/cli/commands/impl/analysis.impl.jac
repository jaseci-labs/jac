"""Implementation of analysis commands (check, lint, format, test, gen_parser).

Direct implementations - no delegation to cli.jac.
"""

import from pathlib { Path }
import from jaclang.cli.console { console }

"""Run type checker for specified .jac files."""
impl check(
    paths: list,
    print_errs: bool = True,
    warnonly: bool = False,
    ignore: str = "",
    parse_only: bool = False,
    nowarn: bool = False
) -> int {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    ignore_list = [
        pattern.strip()
        for pattern in ignore.split(",")
        if pattern.strip()
    ]
    if ignore
    else [];
    def ignore_check(file_path: str, ignore_patterns: list) -> bool {
        path_parts = Path(file_path).parts;
        for pattern in ignore_patterns {
            if str(pattern).strip() in path_parts {
                return True;
            }
        }
        return False;
    }
    def check_single_file(prog: JacProgram, file_path: str) -> tuple[bool, int, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1, 0);
        }
        try {
            (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
            prog.compile(file_path=file_path, type_check=not parse_only, no_cgen=True);
            new_errors = prog.errors_had[err_start:];
            new_warnings = prog.warnings_had[warn_start:];
            # Filter out errors/warnings from ignored files
            def filter_issues(issues: list) -> list {
                return [
                    i
                    for i in issues
                    if not (
                        i.loc
                        and i.loc.mod_path
                        and any(p in i.loc.mod_path for p in ignore_list)
                    )
                ];
            }
            filtered_errors = filter_issues(new_errors);
            filtered_warnings = filter_issues(new_warnings);

            if print_errs {
                for e in filtered_errors {
                    console.error(f"{e}");
                }
                if not nowarn {
                    for w in filtered_warnings {
                        console.warning(f"{w}");
                    }
                }
            }

            return (
                (len(filtered_errors) == 0),
                len(filtered_errors),
                len(filtered_warnings)
            );
        } except Exception as e {
            console.error(f"Error checking '{file_path}': {e}");
            return (False, 1, 0);
        }
    }
    total_files = failed_files=total_errors=total_warnings=0;
    prog = JacProgram();
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not ignore_check(path, ignore_list) {
                total_files += 1;
                (success, errs, warns) = check_single_file(prog, path);
                total_errors += errs;
                total_warnings += warns;
                if not success {
                    failed_files += 1;
                }
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                if not ignore_check(str(jac_file), ignore_list) {
                    total_files += 1;
                    (success, errs, warns) = check_single_file(prog, str(jac_file));
                    total_errors += errs;
                    total_warnings += warns;
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
    check_type = "Parsed" if parse_only else "Checked";
    summary_msg = f"{check_type} {total_files} '.jac' files: {(
        total_files - failed_files
    )} passed, {failed_files} with errors ({total_errors} errors, {total_warnings} warnings).";
    if total_errors {
        console.error(summary_msg);
    } else {
        console.success(summary_msg);
    }
    if (total_errors > 0 and not warnonly) {
        return 1;
    }
    return 0;
}

"""Lint .jac files and report violations."""
impl lint(paths: list, fix: bool = False, ignore: str = "") -> int {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    ignore_list = [
        pattern.strip()
        for pattern in ignore.split(",")
        if pattern.strip()
    ]
    if ignore
    else [];
    def ignore_check(file_path: str, ignore_patterns: list) -> bool {
        path_parts = Path(file_path).parts;
        for pattern in ignore_patterns {
            if str(pattern).strip() in path_parts {
                return True;
            }
        }
        return False;
    }
    def lint_report_file(file_path: str) -> tuple[bool, int] {
        # Lint-only: report errors without formatting or writing files
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1);
        }
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
                    with open(str(path_obj), 'w') as f {
                        f.write(formatted_code);
                    }
                }
                for impl_mod in prog.mod.main.impl_mod {
                    impl_path = impl_mod.loc.mod_path;
                    impl_formatted = impl_mod.gen.jac;
                    impl_original = impl_mod.source.code;
                    if (impl_formatted != impl_original) {
                        with open(impl_path, 'w') as f {
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
            if not ignore_check(path, ignore_list) {
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
                if not ignore_check(str(jac_file), ignore_list) {
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
impl format(paths: list, to_screen: bool = False, lintfix: bool = False) -> int {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    def write_formatted_code(code: str, target_path: str) -> None {
        if to_screen {
            console.print(code);
        } else {
            with open(target_path, 'w') as f {
                f.write(code);
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
            if prog.mod.main.has_syntax_errors {
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
                }
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            failed_files += 1;
        }
    }
    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        summary_msg = f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).";
        if failed_files > 0 {
            console.error(summary_msg);
        } else {
            console.success(summary_msg);
        }
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
impl test(
    filepath: str = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    verbose: bool = False
) -> int {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
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
