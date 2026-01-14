"""Implementation of analysis commands.

Direct implementations - no delegation to cli.jac.
"""

import sys;
import from pathlib { Path }

"""Run type checker for specified .jac files."""
impl check(
    paths: list, print_errs: bool = True, warnonly: bool = False, ignore: str = ""
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
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr);
            return (False, 1, 0);
        }
        try {
            (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
            prog.compile(file_path=file_path, type_check=True, no_cgen=True);
            new_errors = prog.errors_had[err_start:];
            new_warnings = prog.warnings_had[warn_start:];
            if print_errs {
                for e in new_errors {
                    print(f"Error: {e}", file=sys.stderr);
                }
                for w in new_warnings {
                    print(f"Warning: {w}", file=sys.stderr);
                }
            }
            return ((len(new_errors) == 0), len(new_errors), len(new_warnings));
        } except Exception as e {
            print(f"Error checking '{file_path}': {e}", file=sys.stderr);
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
            print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr);
            failed_files += 1;
            total_errors += 1;
        }
    }
    print(
        f"Checked {total_files} '.jac' files: {(total_files - failed_files)} passed, {failed_files} with errors ({total_errors} errors, {total_warnings} warnings).",
        file=sys.stderr if total_errors else sys.stdout
    );
    if (total_errors > 0 and not warnonly) {
        return 1;
    }
    return 0;
}

"""Build the specified .jac file."""
impl build(filename: str, typecheck: bool = False) -> int {
    import pickle;
    import from jaclang.pycore.program { JacProgram }
    if not filename.endswith('.jac') {
        print('Not a .jac file.', file=sys.stderr);
        return 1;
    }
    (out := JacProgram()).compile(file_path=filename, type_check=typecheck);
    errs = len(out.errors_had);
    warnings = len(out.warnings_had);
    print(f"Errors: {errs}, Warnings: {warnings}");
    for alrt in (out.errors_had + out.warnings_had) {
        print(alrt.pretty_print(), file=sys.stderr);
    }
    if (errs > 0) {
        return 1;
    }
    with open((filename[:-4] + '.jir'), 'wb') as f {
        pickle.dump(out, f);
    }
    return 0;
}

"""Format .jac files with improved code style."""
impl format(paths: list, to_screen: bool = False, fix: bool = False) -> int {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    def write_formatted_code(code: str, target_path: str) -> None {
        if to_screen {
            print(code);
        } else {
            with open(target_path, 'w') as f {
                f.write(code);
            }
        }
    }
    def format_single_file(file_path: str) -> tuple[bool, bool] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr);
            return (False, False);
        }
        try {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=fix);
            if prog.errors_had {
                for error in prog.errors_had {
                    print(f"{error}", file=sys.stderr);
                }
                return (False, False);
            }
            # Write main module
            formatted_code = prog.mod.main.gen.jac;
            original_code = prog.mod.main.source.code;
            changed = formatted_code != original_code;
            write_formatted_code(formatted_code, str(path_obj));

            # Write impl modules (.impl.jac, .cl.jac files)
            for impl_mod in prog.mod.main.impl_mod {
                impl_path = impl_mod.loc.mod_path;
                impl_formatted = impl_mod.gen.jac;
                impl_original = impl_mod.source.code;
                if (impl_formatted != impl_original) {
                    write_formatted_code(impl_formatted, impl_path);
                    changed = True;
                }
            }
            return (True, changed);
        } except Exception as e {
            print(f"Error formatting '{file_path}': {e}", file=sys.stderr);
            return (False, False);
        }
    }
    total_files = 0;
    failed_files = 0;
    changed_files = 0;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            total_files += 1;
            (success, changed) = format_single_file(path);
            if not success {
                failed_files += 1;
            } elif changed {
                changed_files += 1;
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                total_files += 1;
                (success, changed) = format_single_file(str(jac_file));
                if not success {
                    failed_files += 1;
                } elif changed {
                    changed_files += 1;
                }
            }
        } else {
            print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr);
            failed_files += 1;
        }
    }
    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        print(
            f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).",
            file=sys.stderr
        );
    }
    if (changed_files > 0) {
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
        print(f"Tests failed: {failcount}", file=sys.stderr);
        return 1;
    }
    return 0;
}

"""Generate static parser."""
impl gen_parser -> int {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    print('Parser generated.');
    return 0;
}
