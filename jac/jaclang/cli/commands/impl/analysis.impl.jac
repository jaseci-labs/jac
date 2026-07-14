import from pathlib { Path }
import from fnmatch { fnmatch }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report {
    print_file_progress,
    print_failures,
    print_failed_summary,
    print_final_summary
}

def _maybe_malloc_trim {
    try {
        import ctypes;
        ctypes.CDLL("libc.so.6").malloc_trim(0);
    } except (ImportError, OSError, AttributeError, ValueError) { }
}

impl check(
    paths: list,
    print_errs: bool = True,
    ignore: (list | None) = None,
    disable_error_code: (list | None) = None,
    parse_only: bool = False,
    nowarn: bool = False,
    lint_only: bool = False,
    fix: bool = False
) -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.diagnostic_utils { resolve_diagnostic_tokens }
    import from time { time }
    if lint_only {
        return lint(paths=paths, fix=fix, ignore=ignore);
    }
    if isinstance(paths, str) {
        paths = [paths];
    }
    start_time = time();
    ignore_list = _normalize_ignore_patterns(ignore or []);
    (suppressed_codes, unknown_codes) = resolve_diagnostic_tokens(
        disable_error_code or []
    );
    if unknown_codes {
        console.warning(
            "Ignoring unknown diagnostic codes in --disable-error-code: " + ", ".join(
                unknown_codes
            )
        );
    }

    def process_file_result(file_path: str, idx: int, total: int) {
        nonlocal total_files , total_errors , total_warnings , failed_files;
        total_files += 1;
        (success, errs, warns, errors_list, warnings_list) = check_single_file(
            prog, file_path
        );
        total_errors += errs;
        total_warnings += warns;

        print_file_progress(file_path, success, idx, total);

        if not success {
            failed_files += 1;
        }
        if not success or (warns > 0 and not nowarn) {
            failed_results.append(
                {'path': file_path, 'errors': errors_list, 'warnings': warnings_list}
            );
        }
    }

    failed_results: list[dict] = [];
    def check_single_file(
        prog: JacProgram, file_path: str
    ) -> tuple[bool, int, int, list, list] {
        import os;
        import from jaclang.jac0core.bccache { discover_base_file }
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1, 0, [], []);
        }

        annex_filter_path: (str | None) = None;
        base_path = discover_base_file(file_path);
        if base_path is not None {
            annex_filter_path = os.path.realpath(file_path);
            file_path = base_path;
        }
        try {
            import from jaclang.jac0core.compile_options { CompileOptions }
            console.print(f"  Checking {file_path}...");
            (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
            prog.compile(
                file_path=file_path,
                options=CompileOptions(
                    type_check=not parse_only,
                    no_cgen=True,
                    force_target_program=True,
                    suppress_codes=suppressed_codes
                )
            );

            for m in prog.mod.hub.values() {
                m.terminals = [];
                m.src_terminals = [];
            }
            new_errors = prog.errors_had[err_start:];
            new_warnings = prog.warnings_had[warn_start:];

            def filter_issues(issues: list) -> list {
                return [
                    i
                    for i in issues
                    if i.loc
                    and i.loc.mod_path
                    and i.loc.mod_path.endswith(".jac")
                    and not _should_ignore(i.loc.mod_path, ignore_list)
                ];
            }
            filtered_errors = filter_issues(new_errors);
            filtered_warnings = filter_issues(new_warnings);

            if annex_filter_path is not None {
                filtered_errors = [
                    e
                    for e in filtered_errors
                    if e.loc and e.loc.mod_path == annex_filter_path
                ];
                filtered_warnings = [
                    w
                    for w in filtered_warnings
                    if w.loc and w.loc.mod_path == annex_filter_path
                ];
            }
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
        } finally {
            prog.release_compile_closure();
        }
    }
    total_files = failed_files=total_errors=total_warnings=0;
    prog = JacProgram();
    (all_files, had_path_errors) = _iter_jac_files(paths, ignore_list);
    total_to_check = len(all_files);
    for (idx, jac_file_path) in enumerate(all_files, 1) {
        process_file_result(jac_file_path, idx, total_to_check);

        _maybe_malloc_trim();
    }

    if print_errs and len(failed_results) > 0 {
        print_failures(failed_results, nowarn);
    }
    if failed_files > 0 {
        print_failed_summary(failed_results);
    }

    elapsed = time() - start_time;
    print_final_summary(total_files - failed_files, failed_files, elapsed);
    return 1 if (total_errors > 0 or had_path_errors) else 0;
}

impl lint(paths: list, fix: bool = False, ignore: (list | None) = None) -> int {
    import from jaclang.jac0core.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    ignore_list = _normalize_ignore_patterns(ignore or []);
    def lint_report_file(file_path: str) -> tuple[bool, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1);
        }
        console.print(f"  Linting {file_path}...");
        try {
            prog = JacProgram.jac_file_linter(str(path_obj));
            error_count = 0;
            for warning in prog.warnings_had {
                console.warning(f"{warning}");
            }
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
    def lint_fix_file(file_path: str, covered: set[str]) -> tuple[bool, int, int] {
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

            has_format_error = any(
                e.code is not None and e.code.code == "E5051" for e in prog.errors_had
            );
            if has_format_error {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                err_count = len(prog.errors_had);
                return (False, err_count, err_count);
            }

            fixed_count = 0;
            unfixable_count = 0;
            for warning in prog.warnings_had {
                console.warning(f"{warning}");
                fixed_count += 1;
            }
            for error in prog.errors_had {
                console.error(f"{error}");
                unfixable_count += 1;
            }
            error_count = fixed_count + unfixable_count;

            if fixed_count > 0 {
                changed = formatted_code != original_code;
                if changed {
                    with open(str(path_obj), 'w', encoding='utf-8') as f {
                        f.write(formatted_code);
                    }
                }
            }

            import from jaclang.jac0core.bccache { discover_annex_files }
            import os;
            annex_paths = (
                discover_annex_files(str(path_obj), '.impl.jac') + discover_annex_files(
                    str(path_obj), '.test.jac'
                )
            );
            for annex_path in annex_paths {
                if os.path.realpath(annex_path) in covered {
                    continue;
                }
                try {
                    annex_prog = JacProgram.jac_file_formatter(
                        annex_path, auto_lint=True
                    );
                    annex_formatted = annex_prog.mod.main.gen.jac;
                    annex_original = annex_prog.mod.main.source.code;
                } except Exception {
                    continue;
                }
                for warning in annex_prog.warnings_had {
                    console.warning(f"{warning}");
                    error_count += 1;
                }
                for error in annex_prog.errors_had {
                    console.error(f"{error}");
                    error_count += 1;
                    unfixable_count += 1;
                }
                if (annex_formatted and annex_formatted != annex_original) {
                    with open(annex_path, 'w', encoding='utf-8') as f {
                        f.write(annex_formatted);
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
    (all_files, had_path_errors) = _iter_jac_files(paths, ignore_list);
    import os;
    covered: set[str] = {os.path.realpath(f) for f in all_files};
    for file_path in all_files {
        total_files += 1;
        if fix {
            (success, errors, unfixable) = lint_fix_file(file_path, covered);
            total_unfixable += unfixable;
        } else {
            (success, errors) = lint_report_file(file_path);
        }
        total_errors += errors;
        if not success {
            failed_files += 1;
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
    if failing_errors > 0 or had_path_errors {
        console.error(summary_msg);
        return 1;
    }
    console.success(summary_msg);
    return 0;
}

def _format_single_file_worker(
    file_path: str, lintfix: bool, check: bool, covered: (set[str] | None) = None
) -> dict {
    import from jaclang.jac0core.program { JacProgram }
    path_obj = Path(file_path);
    result: dict = {
        'path': file_path,
        'success': False,
        'changed': False,
        'errors': 0,
        'syntax_errors': [],
        'warnings_strs': [],
        'errors_strs': [],
        'formatted_code': None,
        'impl_results': []
    };
    if not path_obj.exists() {
        result['syntax_errors'] = [f"File '{file_path}' does not exist."];
        return result;
    }
    try {
        prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=lintfix);
        if prog.errors_had {
            has_format_error = any(
                e.code is not None and e.code.code == "E5051" for e in prog.errors_had
            );
            if has_format_error or not lintfix {
                result['syntax_errors'] = [str(e) for e in prog.errors_had];
                return result;
            }
        }
        try {
            formatted_code = prog.mod.main.gen.jac;
            original_code = prog.mod.main.source.code;
            if not formatted_code or len(formatted_code.strip()) == 0 {
                if prog.errors_had {
                    result['syntax_errors'] = [str(e) for e in prog.errors_had];
                    return result;
                }
            }
            changed = formatted_code != original_code;
            result['changed'] = changed;

            if changed and not check {
                result['formatted_code'] = formatted_code;
            }

            if lintfix {
                import from jaclang.jac0core.bccache { discover_annex_files }
                import os;
                annex_paths = (
                    discover_annex_files(file_path, '.impl.jac') + discover_annex_files(
                        file_path, '.test.jac'
                    )
                );
                for annex_path in annex_paths {
                    if covered is not None
                    and (os.path.realpath(annex_path) in covered) {
                        continue;
                    }
                    try {
                        annex_prog = JacProgram.jac_file_formatter(
                            annex_path, auto_lint=True
                        );
                        annex_formatted = annex_prog.mod.main.gen.jac;
                        annex_original = annex_prog.mod.main.source.code;
                    } except Exception {
                        continue;
                    }
                    if (annex_formatted and annex_formatted != annex_original) {
                        result['changed'] = True;
                        if not check {
                            result['impl_results'].append(
                                (annex_path, annex_formatted)
                            );
                        }
                    }
                }
            }
        } except Exception {
            result['syntax_errors'] = [str(e) for e in prog.errors_had];
            return result;
        }

        lint_errors = 0;
        if lintfix {
            for warning in prog.warnings_had {
                result['warnings_strs'].append(str(warning));
            }
            for error in prog.errors_had {
                result['errors_strs'].append(str(error));
                lint_errors += 1;
            }
        }
        result['success'] = True;
        result['errors'] = lint_errors;
        return result;
    } except Exception as e {
        result['syntax_errors'] = [f"Error formatting '{file_path}': {e}"];
        return result;
    }
}

impl format(
    paths: list, to_screen: bool = False, lintfix: bool = False, check: bool = False
) -> int {
    import from concurrent.futures { ProcessPoolExecutor, as_completed }
    import os;
    if isinstance(paths, str) {
        paths = [paths];
    }

    unformatted_files: list[str] = [];
    failed_results: list = [];

    (all_files, had_path_errors) = _iter_jac_files(paths);
    total_files = len(all_files);

    if total_files == 0 {
        return 1 if had_path_errors else 0;
    }

    import os;
    covered: set[str] = {os.path.realpath(f) for f in all_files};

    use_parallel = total_files > 1 and not to_screen;
    max_workers = min(os.cpu_count() or 4, total_files, 8);

    results: list[dict] = [];

    if use_parallel {
        try {
            import multiprocessing as mp;
            ctx = mp.get_context("fork") if os.name != "nt" else None;
            pool_cls = (
                ProcessPoolExecutor
                    if ctx is None
                    else lambda (**kw) { ProcessPoolExecutor(mp_context=ctx, **kw); }
            );
            with pool_cls(max_workers=max_workers) as executor {
                futures = {
                    executor.submit(
                        _format_single_file_worker, fp, lintfix, check, covered
                    ): fp for fp in all_files
                };
                completed = 0;
                for future in as_completed(futures) {
                    completed += 1;
                    fp = futures[future];
                    console.print(
                        f"Formatting [{completed}/{total_files}] completed..."
                    );
                    try {
                        results.append(future.result());
                    } except Exception as e {
                        results.append(
                            {
                                'path': fp,
                                'success': False,
                                'changed': False,
                                'errors': 0,
                                'syntax_errors': [f"Worker error: {e}"],
                                'warnings_strs': [],
                                'errors_strs': [],
                                'formatted_code': None,
                                'impl_results': []
                            }
                        );
                    }
                }
            }
        } except Exception {
            use_parallel = False;
        }
    }
    if not use_parallel {
        for fp in all_files {
            console.print(f"Formatting {fp}...");
            results.append(_format_single_file_worker(fp, lintfix, check, covered));
        }
    }

    failed_files = 0;
    changed_files = 0;
    total_errors = 0;

    for res in results {
        for w in res['warnings_strs'] {
            console.warning(w);
        }
        for e in res['errors_strs'] {
            console.error(e);
        }

        total_errors += res['errors'];

        if not res['success'] {
            failed_files += 1;
            failed_results.append(
                {'path': res['path'], 'errors': res['syntax_errors'], 'warnings': []}
            );
        } elif res['changed'] {
            changed_files += 1;
            if check {
                unformatted_files.append(res['path']);
            } else {
                if res['formatted_code'] is not None {
                    try {
                        if to_screen {
                            console.print(
                                res['formatted_code'], markup=False, highlight=False
                            );
                        } else {
                            with open(res['path'], 'w', encoding='utf-8') as f {
                                f.write(res['formatted_code']);
                            }
                        }
                    } except Exception as e {
                        console.error(f"Error writing to '{res['path']}': {e}");
                    }
                }
                for (impl_path, impl_code) in res['impl_results'] {
                    try {
                        if to_screen {
                            console.print(impl_code, markup=False, highlight=False);
                        } else {
                            with open(impl_path, 'w', encoding='utf-8') as f {
                                f.write(impl_code);
                            }
                        }
                    } except Exception as e {
                        console.error(f"Error writing to '{impl_path}': {e}");
                    }
                }
            }
        }
    }

    if failed_results {
        import from jaclang.cli.check_report { separator }
        console.print("");
        console.print(separator("FAILURES"));
        for r in failed_results {
            console.print(separator(str(r['path']), char='_'));
            for e in r['errors'] {
                console.error(e);
            }
            console.print("");
        }
        print_failed_summary(failed_results);
    }

    if check {
        has_errors = False;
        if len(unformatted_files) > 0 {
            console.error("The following files are not properly formatted:");
            for file in unformatted_files {
                console.error(f"  jac fmt --lintfix {file}");
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

    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        summary_msg = f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).";
        if failed_files > 0 {
            console.error(summary_msg);
        } else {
            console.success(summary_msg);
        }
    }
    if failed_files > 0 or had_path_errors {
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

impl precommit(
    paths: (list | None) = None,
    staged: bool = False,
    verify: bool = False,
    install: bool = False,
    force: bool = False
) -> int {
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.project.config { get_config }
    if install {
        return _install_precommit_hook(force);
    }
    targets: list[str] = [];
    rel_targets: list[str] = [];
    git_root = "";
    if staged {
        try {
            git_root = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                check=True
            ).stdout.strip();
            completed = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                capture_output=True,
                text=True,
                check=True
            );
        } except Exception as e {
            console.error(f"Could not read staged files from git: {e}");
            return 1;
        }
        for line in completed.stdout.splitlines() {
            candidate = line.strip();
            if not candidate.endswith(".jac") {
                continue;
            }
            abs_candidate = os.path.join(git_root, candidate);
            if os.path.exists(abs_candidate) {
                rel_targets.append(candidate);
                targets.append(abs_candidate);
            }
        }
        if not targets {
            console.success("No staged '.jac' files to check.");
            return 0;
        }
    } elif paths {
        targets = list(paths);
    } else {
        config = get_config();
        targets = [str(config.project_root)] if config?.project_root else ["."];
    }

    fmt_targets = targets;
    tmp_root: (str | None) = None;
    if staged and verify {
        dirty = _staged_dirty_files(git_root, rel_targets);
        if dirty {
            tmp_root = tempfile.mkdtemp(prefix="jac-precommit-");
            try {
                subprocess.run(
                    [
                        "git",
                        "checkout-index",
                        "-f",
                        f"--prefix={tmp_root}{os.sep}",
                        "--"
                    ] + rel_targets,
                    check=True,
                    cwd=git_root
                );
                fmt_targets = [os.path.join(tmp_root, rel) for rel in rel_targets];
                console.print("[precommit] Verifying staged content (index checkout).");
            } except Exception as e {
                shutil.rmtree(tmp_root, ignore_errors=True);
                tmp_root = None;
                fmt_targets = targets;
                console.warning(
                    f"[precommit] Could not check out the staged blobs ({e}); "
                    "verifying the WORKTREE copies instead -- staged content "
                    "that differs from the worktree was NOT verified."
                );
            }
        }
    }
    console.print("[precommit] Running format (--lintfix)...");
    fmt_ret = format(fmt_targets, to_screen=False, lintfix=True, check=verify);
    if tmp_root {
        shutil.rmtree(tmp_root, ignore_errors=True);
    }
    run_typecheck = True;
    pc_config = get_config();
    if pc_config {
        run_typecheck = pc_config.precommit.typecheck;
    }
    if run_typecheck {
        console.print("[precommit] Running check...");
        check_ret = check(targets);
    } else {
        console.print("[precommit] Skipping check ([precommit] typecheck = false).");
        check_ret = 0;
    }
    if not verify
    and check_ret == 0
    and fmt_ret == 0
    and staged
    and _staged_dirty_files(git_root, rel_targets) {
        fmt_ret = 1;
    }
    if not verify and check_ret == 0 and fmt_ret != 0 {
        console.warning(
            "Pre-commit applied formatting/lint fixes — review the changes, "
            "re-stage them, and commit again."
        );
        return 1;
    }
    if fmt_ret != 0 or check_ret != 0 {
        console.error("Pre-commit checks failed.");
        if verify and fmt_ret != 0 {
            console.error(
                "Run 'jac precommit' (without --verify) to apply formatting "
                "fixes, then re-stage."
            );
        }
        return 1;
    }
    console.success("Pre-commit checks passed.");
    return 0;
}

def _staged_dirty_files(git_root: str, rel_targets: list[str]) -> list[str] {
    import subprocess;
    if not git_root or not rel_targets {
        return [];
    }
    try {
        out = subprocess.run(
            ["git", "diff", "--name-only", "--"] + rel_targets,
            capture_output=True,
            text=True,
            check=True,
            cwd=git_root
        ).stdout;
    } except Exception {
        return [];
    }
    return [
        line.strip()
        for line in out.splitlines()
        if line.strip()
    ];
}

def _install_precommit_hook(force: bool = False) -> int {
    import os;
    import stat;
    import subprocess;
    try {
        completed = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            check=True
        );
    } except Exception as e {
        console.error(f"Not a git repository (or git unavailable): {e}");
        return 1;
    }
    git_dir = completed.stdout.strip();
    hooks_dir = os.path.join(git_dir, "hooks");
    os.makedirs(hooks_dir, exist_ok=True);
    hook_path = os.path.join(hooks_dir, "pre-commit");
    if os.path.exists(hook_path) {
        try {
            with open(hook_path, encoding="utf-8", errors="replace") as f {
                existing = f.read();
            }
        } except Exception {
            existing = "";
        }

        is_framework = "generated by pre-commit" in existing;
        if not (is_framework or force) {
            console.warning(f"A pre-commit hook already exists at '{hook_path}'.");
            console.warning(
                "Re-run 'jac precommit --install --force' to replace it "
                "(the old hook is kept as pre-commit.bak)."
            );
            return 1;
        }
        backup_path = hook_path + ".bak";
        try {
            os.replace(hook_path, backup_path);
        } except Exception as e {
            console.error(f"Could not back up the existing hook: {e}");
            return 1;
        }
        kind = "pre-commit framework hook" if is_framework else "existing hook";
        console.print(f"Replaced {kind} (backup at '{backup_path}').");
    }
    hook_body = (
        "#!/bin/sh\n"
        "# Installed by `jac precommit --install`\n"
        "exec jac precommit --staged --verify\n"
    );
    try {
        with open(hook_path, "w", encoding="utf-8") as f {
            f.write(hook_body);
        }
        mode = os.stat(hook_path).st_mode;
        os.chmod(hook_path, mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH);
    } except Exception as e {
        console.error(f"Failed to write hook: {e}");
        return 1;
    }
    console.success(f"Installed git pre-commit hook at '{hook_path}'.");
    console.print("It runs: jac precommit --staged --verify");
    return 0;
}

impl `test(
    paths: list = [],
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    verbose: bool = False,
    ignore: str = ""
) -> int {
    import os;
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    if isinstance(paths, str) {
        paths = [paths];
    }

    if (not paths and not directory) {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if (cfg and cfg.test.directory) {
            directory = cfg.test.directory;
            if (cfg.project_root and not os.path.isabs(directory)) {
                directory = os.path.join(str(cfg.project_root), directory);
            }
            if not Path(directory).is_dir() {
                console.error(
                    f"Error: [test] directory '{cfg.test.directory}' "
                    f"(resolved to '{directory}') does not exist."
                );
                return 1;
            }
        }
    }

    if (test_name and not paths) {
        console.error(
            "Error: --test_name requires a filepath. "
            "Running by name across all files is ambiguous.\n"
            "Usage: jac test <file.jac> --test_name <name>"
        );
        return 1;
    }

    for fp in paths {
        if not Path(fp).exists() {
            console.error(
                f"Error: File not found: '{fp}'\n"
                "Make sure you are in the correct directory or provide the full path.\n"
                f"Usage: jac test /full/path/to/{fp}"
            );
            return 1;
        }
    }

    run_pytest = not os.environ.get('JAC_TEST_NATIVE', '');
    if run_pytest {
        try {
            import pytest;
        } except ImportError {
            run_pytest = False;
        }
        if run_pytest {
            pargs: list[str] = [];

            targets = paths or ([directory] if directory else []);
            for target in targets {
                pargs.append(target);
            }

            if directory and not paths {
                pargs.append('--jac-test-dir');
                pargs.append(str(Path(directory).resolve()));
            }

            if ignore {
                pargs.append('--ignore=' + ignore);
            }

            jobs = os.environ.get('JAC_TEST_JOBS', '');
            if not jobs {
                import from jaclang.project.config { get_config }
                jobs_cfg = get_config();
                jobs = jobs_cfg.dev.test_jobs if jobs_cfg else 'auto';
            }

            if jobs and jobs != '0' and not test_name {
                pargs.append('-n');
                pargs.append(jobs);
            }
            if xit {
                pargs.append('-x');
            }
            if maxfail {
                pargs.append('--maxfail');
                pargs.append(str(maxfail));
            }
            if test_name {
                pargs.append('-k');
                pargs.append(' and '.join(test_name.split()) or test_name);
            } elif filter {
                pargs.append('-k');
                pargs.append(filter);
            }
            if verbose {
                pargs.append('-vv');
            }
            return int(pytest.main(pargs));
        }
    }
    normalized_name = test_name.strip().replace(' ', '_') if test_name else '';
    func_name = ('test_' + normalized_name) if normalized_name else None;

    run_targets = paths or [""];
    failcount = 0;
    for fp in run_targets {
        failcount += Jac.run_test(
            filepath=fp,
            func_name=func_name,
            filter=filter,
            xit=xit,
            maxfail=maxfail,
            directory=directory,
            verbose=verbose
        );

        if xit and failcount > 0 {
            break;
        }
    }
    if failcount {
        console.error(f"Tests failed: {failcount}");
        return 1;
    }
    return 0;
}

impl gen_parser -> int {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    console.success('Parser generated.');
    return 0;
}

impl grammar(output: str = "") -> int {
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
    text = pass_.emit_ebnf();
    if output {
        with open(output, "w", encoding="utf-8") as f {
            f.write(text);
            f.write("\n");
        }
        console.success(f"EBNF grammar ({len(pass_.rules)} rules) written to {output}");
    } else {
        console.print(text);
    }
    return 0;
}

def _iter_jac_files(
    paths: list, ignore_list: (list | None) = None
) -> tuple[list[str], bool] {
    ignore_list = ignore_list or [];
    result: list[str] = [];
    had_errors = False;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not _should_ignore(path, ignore_list) {
                result.append(path);
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                if not _should_ignore(str(jac_file), ignore_list) {
                    result.append(str(jac_file));
                }
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            had_errors = True;
        }
    }
    return (result, had_errors);
}

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

def _should_ignore(file_path: str, ignore_patterns: list) -> bool {
    import from jaclang.jac0core.helpers { path_matches_exclude }
    return path_matches_exclude(file_path, ignore_patterns);
}
