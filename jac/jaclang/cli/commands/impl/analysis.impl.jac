import from pathlib { Path }
import from fnmatch { fnmatch }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report {
    print_file_progress,
    print_failures,
    print_failed_summary,
    print_final_summary,
    print_native_coverage,
    print_placement_report
}

def _maybe_malloc_trim {
    import from jaclang.cli.workpool { maybe_malloc_trim }
    maybe_malloc_trim();
}

glob _CHECK_STATE: dict[(str, any)] = {"prog": None, "coverage_on": False};

def _wire_list(value: any) -> list {
    return value if isinstance(value, list) else [];
}

def _wire_dict(value: any) -> dict {
    return value if isinstance(value, dict) else {};
}

def _message_diag(text: str, path: str) -> dict[(str, any)] {
    return {
        'text': text,
        'pretty': text,
        'code': None,
        'category': None,
        'mod_path': path
    };
}

def _diag_wire(alert: any) -> dict[(str, any)] {
    info = alert.code;
    return {
        'text': str(alert),
        'pretty': alert.pretty_print(),
        'code': info.code if info is not None else None,
        'category': info.category.value if info is not None else None,
        'mod_path': alert.loc.mod_path if alert.loc else ''
    };
}

def _check_rss_cap_mb -> int {
    import from jaclang.cli.workpool { env_int }
    return env_int("JAC_CHECK_RECYCLE_MB", 3072);
}

def _check_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int, should_retire }
    return should_retire(
        served, env_int("JAC_CHECK_RECYCLE", 0), rss_mb, _check_rss_cap_mb()
    );
}

def _reached_by_imports(prog: any, root_mod: any) -> list[str] {
    import os;
    import from jaclang.compiler.frontend.unitree { Import as _Imp }
    seen: set[str] = set();
    for m in prog.mod.hub.values() {
        if m.loc and m.loc.mod_path {
            seen.add(os.path.realpath(str(m.loc.mod_path)));
        }
    }
    stack: list = [root_mod] if root_mod is not None else [];
    visited: set[int] = set();
    while stack {
        mod = stack.pop();
        if id(mod) in visited {
            continue;
        }
        visited.add(id(mod));
        for imp in mod.get_all_sub_nodes(_Imp) {
            if imp.from_loc is None {
                continue;
            }
            try {
                target = imp.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if not isinstance(target, str) or not target.endswith('.jac') {
                continue;
            }
            rp = os.path.realpath(target);
            seen.add(rp);
            nxt = prog.find_module(target) or prog.mod.hub.get(target);
            if nxt is not None and id(nxt) not in visited {
                stack.append(nxt);
            }
        }
    }
    return sorted(seen);
}

def _check_unit(
    path: str, app_name: str, kind: str, target: str, root_dir: str
) -> dict[(str, any)] {
    return {
        'path': path,
        'app': app_name,
        'kind': kind,
        'target': target,
        'root_dir': root_dir,
        'label': app_name or 'shared'
    };
}

def _is_app_name(target: str) -> bool {
    return bool(target)
        and not target.endswith('.jac')
        and '/' not in target
        and '\\' not in target;
}

def _check_file_job(request: dict[(str, any)]) -> dict[(str, any)] {
    import os;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    opts = _wire_dict(request.get("opts"));
    file_path = str(request["path"]);
    result: dict[(str, any)] = {
        'path': file_path,
        'success': False,
        'errors': [],
        'warnings': [],
        'placements': {},
        'coverage': {},
        'reached': []
    };
    if not Path(file_path).exists() {
        result['errors'] = [
            _message_diag(f"File '{file_path}' does not exist.", file_path)
        ];
        return result;
    }
    prog = _CHECK_STATE["prog"];
    if prog is None {
        prog = JacProgram();
        _CHECK_STATE["prog"] = prog;
    }
    if opts.get("native_coverage") and not _CHECK_STATE["coverage_on"] {
        import from jaclang.compiler.driver.na_coverage { na_coverage_begin }
        na_coverage_begin();
        _CHECK_STATE["coverage_on"] = True;
    }
    ignore_list = _wire_list(opts.get("ignore"));
    annex_filter_path: (str | None) = None;
    base_path = discover_base_file(file_path);
    if base_path is not None {
        annex_filter_path = os.path.realpath(file_path);
        file_path = base_path;
    }
    try {
        (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
        if opts.get("parse_only") {
            import from jaclang.compiler.frontend.parser.frontend {
                parse_diags,
                _replay_diags
            }
            import from jaclang.compiler.frontend.parser.lexer { Lexer }
            import from jaclang.compiler.frontend.parser.parser {
                Parser as _SyntaxParser
            }
            import from jaclang.compiler.frontend.unitree { Source as _Src }
            import from jaclang.compiler.frontend.helpers {
                read_file_with_encoding as _read_src
            }
            _src_txt = _read_src(file_path);
            (_had, _pd, _ld) = parse_diags(_src_txt, file_path);
            if _pd or _ld {
                _dsrc = _Src(_src_txt, mod_path=file_path);
                _replay_diags(_ld, Lexer, prog, _dsrc);
                _replay_diags(_pd, _SyntaxParser, prog, _dsrc);
            }
        } else {
            prog.compile(
                file_path=file_path,
                options=CompileOptions(
                    no_cgen=not bool(opts.get("native_coverage")),
                    native_parity=True,
                    force_target_program=True,
                    iface_ok=True,
                    suppress_codes=list(opts.get("suppress_codes") or []),
                    target_app=str(opts.get("target_app") or ""),
                    app_kind=str(opts.get("app_kind") or ""),
                    project_root=(
                        str(opts["project_root"]) if opts.get("project_root") else None
                    )
                )
            );
        }
        import from jaclang.compiler.driver.compiler { JacCompiler as _JC }
        root_mod = prog.find_module(file_path) or prog.mod.hub.get(file_path);
        result['reached'] = _reached_by_imports(prog, root_mod);
        result['owned_elements'] = bool(
            root_mod is not None and _JC._module_defines_owned_elements(root_mod)
        );
        if opts.get("placements") {
            import from jaclang.compiler.placement.placement { collect_placement_rows }
            result['placements'] = collect_placement_rows(prog);
        }
        if opts.get("native_coverage") {
            import from jaclang.compiler.driver.na_coverage { _na_coverage }
            result['coverage'] = dict(_na_coverage);
        }
        for m in prog.mod.hub.values() {
            m.terminals = [];
            m.src_terminals = [];
        }
        new_errors = prog.errors_had[err_start:];
        new_warnings = prog.warnings_had[warn_start:];

        def keep(issue: any) -> bool {
            return bool(
                issue.loc
                    and issue.loc.mod_path
                    and issue.loc.mod_path.endswith(".jac")
                    and not _should_ignore(issue.loc.mod_path, ignore_list)
                    and (
                        annex_filter_path is None
                        or issue.loc.mod_path == annex_filter_path
                    )
            );
        }
        result['errors'] = [
            _diag_wire(e)
            for e in new_errors
            if keep(e)
        ];
        result['warnings'] = [
            _diag_wire(w)
            for w in new_warnings
            if keep(w)
        ];
        result['success'] = len(result['errors']) == 0;
        return result;
    } except Exception as e {
        result['errors'] = [
            _message_diag(f"Error checking '{file_path}': {e}", file_path)
        ];
        result['success'] = False;
        return result;
    } finally {
        prog.release_compile_closure(collect=bool(request.get("collect")));
        _maybe_malloc_trim();
    }
}

impl check(
    paths: list,
    print_errs: bool = True,
    ignore: (list | None) = None,
    disable_error_code: (list | None) = None,
    parse_only: bool = False,
    nowarn: bool = False,
    lint_only: bool = False,
    fix: bool = False,
    native_coverage: bool = False,
    placements: bool = False,
    jobs: str = "",
    app: str = ""
) -> int {
    import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    import from jaclang.project.config { get_config }
    import from time { time }
    if lint_only {
        return lint(paths=paths, fix=fix, ignore=ignore);
    }
    import gc;
    import os;
    import from jaclang.compiler.driver.compiler { COMPILE_GC_THRESHOLDS }
    if (
        not os.environ.get('JAC_GC_NO_COMPILE_BOOST')
        and gc.get_threshold()[0] < COMPILE_GC_THRESHOLDS[0]
    ) {
        gc.set_threshold(*COMPILE_GC_THRESHOLDS);
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
            "Ignoring unknown diagnostic codes in --disable-error-code: "
                + ", ".join(unknown_codes)
        );
    }

    import from jaclang.compiler.placement.workspace { workspace_for_path }
    ws = workspace_for_path(os.getcwd()) if not paths else None;
    units: list[dict[(str, any)]] = [];
    had_path_errors = False;
    if ws is not None {
        selected = [
            a
            for a in ws.apps.values()
            if (not app) or a.name == app
        ];
        if app and not selected {
            console.error(
                f"Error: no app named '{app}' in {ws.toml_path} "
                f"(apps: {', '.join(ws.apps)})."
            );
            return 2;
        }
        for a in selected {
            if not os.path.isfile(a.`entry) {
                console.error(
                    f"Error: entry '{a.`entry}' of app '{a.name}' does not exist."
                );
                had_path_errors = True;
                continue;
            }
            units.append(
                _check_unit(a.`entry, a.name, a.kind, a.name, ws.project_root)
            );
        }
    } else {
        (explicit_files, had_path_errors) = _iter_jac_files(
            paths, ignore_list, include_annex=False
        );
        for f in explicit_files {
            f_ws = workspace_for_path(f);
            owner: any = None;
            if f_ws is not None {
                owner = f_ws.app(app) if app else f_ws.app_for_path(f);
            }
            units.append(
                _check_unit(
                    f,
                    owner.name if owner is not None else '',
                    owner.kind if owner is not None else '',
                    owner.name if owner is not None else '',
                    f_ws.project_root if f_ws is not None else ''
                )
            );
        }
    }
    cfg = get_config();
    raw_jobs = jobs_setting("check", jobs, cfg.dev if cfg else None);

    workers = resolve_jobs(
        raw_jobs,
        env_var="JAC_CHECK_JOBS",
        worker_bytes=_check_rss_cap_mb() * 1024 * 1024
    );
    opts: dict[(str, any)] = {
        'parse_only': parse_only,
        'native_coverage': native_coverage,
        'placements': placements,
        'suppress_codes': list(suppressed_codes),
        'ignore': list(ignore_list)
    };

    results: list[dict[(str, any)]] = [];
    reached: set[str] = set();
    plan: dict[(str, int)] = {'total': len(units)};
    placement_report: dict = {};
    coverage_report: dict = {};

    def run_units(batch: list[dict[(str, any)]]) -> None {
        if not batch {
            return;
        }
        total = len(batch);
        use_pool = (
            pool_available()
            and not forced_serial(raw_jobs)
            and workers > 1
            and total > 1
        );

        def request_extra(idx: int, path: str) -> dict[(str, any)] {
            unit = batch[idx];
            job_opts = dict(opts);
            job_opts['target_app'] = unit['target'];
            job_opts['app_kind'] = unit['kind'];
            job_opts['project_root'] = unit['root_dir'];
            return {'opts': job_opts, 'collect': (not use_pool) and (idx < total - 1)};
        }

        def on_dispatch(idx: int, path: str) {
            console.print(f"  Checking {path}...");
        }

        def on_record(idx: int, record: dict[(str, any)]) {
            unit = batch[idx];
            path = unit['path'];
            res = _wire_dict(record.get('result'));
            if not res {
                detail = record.get('crash') or record.get('error') or 'no result';
                res = {
                    'path': path,
                    'success': False,
                    'errors': [
                        _message_diag(f"Error checking '{path}': {detail}", path)
                    ],
                    'warnings': [],
                    'placements': {},
                    'coverage': {},
                    'reached': []
                };
            }
            res['label'] = unit['label'];
            res['_unit'] = unit;
            for m in _wire_list(res.get('reached')) {
                reached.add(os.path.realpath(str(m)));
            }
            results.append(res);
            print_file_progress(
                path, bool(res.get('success')), len(results), plan['total']
            );
            if placements {
                placement_report.update(_wire_dict(res.get('placements')));
            }
            if native_coverage {
                coverage_report.update(_wire_dict(res.get('coverage')));
            }
        }

        pool = WorkPool(
            items=[u['path'] for u in batch],
            job=_check_file_job,
            on_record=on_record,
            jobs=min(workers, max(1, total)),
            request_extra=request_extra,
            retire=_check_retire,
            on_dispatch=on_dispatch,
            rss_log_env="JAC_CHECK_RSS_LOG",
            crash_prefix="jac-check-crash-"
        );
        if use_pool {
            import from jaclang.runtime.runtime { JacRuntime }
            try {
                JacRuntime.get_compiler().ensure_stub_catalog();
            } except Exception {}
            pool.run();
        } else {
            pool.run_inline();
        }
    }

    run_units(units);
    if ws is not None {
        ws_root = os.path.realpath(ws.project_root);
        shared_units: list[dict[(str, any)]] = [];
        shared_seen: set[tuple[(str, str)]] = set();
        for res in list(results) {
            unit = res.get('_unit');
            if not unit or not unit.get('target') {
                continue;
            }
            for m in _wire_list(res.get('reached')) {
                rp = os.path.realpath(str(m));
                if (
                    not rp.endswith('.jac')
                    or not rp.startswith(ws_root + os.sep)
                    or _should_ignore(rp, ignore_list)
                    or ws.app_for_path(rp) is not None
                ) {
                    continue;
                }
                key = (rp, str(unit['target']));
                if key in shared_seen {
                    continue;
                }
                shared_seen.add(key);
                shared_units.append(
                    _check_unit(
                        rp,
                        unit['target'],
                        unit['kind'],
                        unit['target'],
                        unit['root_dir']
                    )
                );
            }
        }
        if shared_units {
            plan['total'] += len(shared_units);
            run_units(shared_units);
        }
        serving_names = {a.name for a in ws.serving_apps()};
        reach_map: dict[(str, set[str])] = {};
        owned_paths: set[str] = set();
        for res in list(results) {
            unit = res.get('_unit');
            if not unit {
                continue;
            }
            tgt = str(unit.get('target') or '');
            if not tgt {
                continue;
            }
            unit_path = os.path.realpath(str(unit['path']));
            reach_map.setdefault(unit_path, set()).add(tgt);
            for m in _wire_list(res.get('reached')) {
                reach_map.setdefault(os.path.realpath(str(m)), set()).add(tgt);
            }
            if res.get('owned_elements') and ws.app_for_path(unit_path) is None {
                owned_paths.add(unit_path);
            }
        }
        for rp in sorted(owned_paths) {
            reaching = sorted(
                [
                    a
                    for a in reach_map.get(rp, set())
                    if a in serving_names
                ]
            );
            if len(reaching) < 2 {
                continue;
            }
            (owner, ambiguous) = ws.owner_app_for_path(rp);
            if owner is not None or not ambiguous {
                continue;
            }
            import from jaclang.compiler.frontend.diagnostics { E5107 }
            msg = E5107.format_message(
                module=os.path.basename(rp), apps=', '.join(reaching)
            );
            results.append(
                {
                    'path': rp,
                    'success': False,
                    'errors': [_message_diag(f"error[E5107]: {msg}", rp)],
                    'warnings': [],
                    'placements': {},
                    'coverage': {},
                    'reached': [],
                    'label': 'shared'
                }
            );
            plan['total'] += 1;
        }
        sweep_roots = [ws.project_root];
        sel = ws.app(app) if app else None;
        if sel is not None and sel.root_dir {
            sweep_roots = [sel.root_dir];
        }
        (candidates, _sweep_errs) = _iter_jac_files(
            sweep_roots, ignore_list, include_annex=False
        );
        rooted = {os.path.realpath(u['path']) for u in units};
        orphans: list[dict[(str, any)]] = [];
        for f in candidates {
            real = os.path.realpath(f);
            if real in rooted {
                continue;
            }
            owner = ws.app_for_path(f);
            if owner is None and real in reached {
                continue;
            }
            if app and (owner is None or owner.name != app) {
                continue;
            }
            orphans.append(
                _check_unit(
                    f,
                    owner.name if owner is not None else '',
                    owner.kind if owner is not None else '',
                    owner.name if owner is not None else '',
                    ws.project_root
                )
            );
        }
        plan['total'] += len(orphans);
        run_units(orphans);
    }
    if native_coverage {
        import from jaclang.compiler.driver.na_coverage { na_coverage_end }
        coverage_report.update(na_coverage_end());
        _CHECK_STATE["coverage_on"] = False;
    }

    multi = len({r['label'] for r in results}) > 1;
    failed_results: list[dict] = [];
    total_errors = failed_files=0;
    for res in results {
        errs = _wire_list(res.get('errors'));
        warns = _wire_list(res.get('warnings'));
        if multi {
            prefix = f"[{res['label']}] ";
            for d in errs + warns {
                if isinstance(d, dict) {
                    d['pretty'] = prefix + str(d.get('pretty') or '');
                    d['text'] = prefix + str(d.get('text') or '');
                }
            }
        }
        total_errors += len(errs);
        if not res.get('success') {
            failed_files += 1;
        }
        if not res.get('success') or (len(warns) > 0 and not nowarn) {
            failed_results.append(
                {
                    'path': (f"[{res['label']}] " if multi else '')
                        + str(res.get('path')),
                    'errors': errs,
                    'warnings': warns
                }
            );
        }
    }
    if native_coverage {
        print_native_coverage(coverage_report);
    }
    if placements {
        print_placement_report(placement_report);
    }
    if print_errs and len(failed_results) > 0 {
        print_failures(failed_results, nowarn);
    }
    if failed_files > 0 {
        print_failed_summary(failed_results);
    }

    elapsed = time() - start_time;
    print_final_summary(len(results) - failed_files, failed_files, elapsed);
    return 1 if (total_errors > 0 or had_path_errors) else 0;
}

impl lint(paths: list, fix: bool = False, ignore: (list | None) = None) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
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

            import from jaclang.compiler.driver.bccache { discover_annex_files }
            import os;
            annex_paths = (
                discover_annex_files(str(path_obj), '.impl.jac')
                + discover_annex_files(str(path_obj), '.test.jac')
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
    file_path: str,
    lintfix: bool,
    check: bool,
    covered: (set[str] | None) = None,
    cache_stamp: str = "",
    cache_anchor: str = "",
    logical_path: str = ""
) -> dict {
    import os;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
    path_obj = Path(file_path);

    effective_logical = logical_path or file_path;
    result: dict = {
        'path': file_path,
        'success': False,
        'changed': False,
        'errors': 0,
        'syntax_errors': [],
        'warnings_strs': [],
        'errors_strs': [],
        'formatted_code': None,
        'impl_results': [],
        'cache_status': 'off'
    };
    if not path_obj.exists() {
        result['syntax_errors'] = [f"File '{file_path}' does not exist."];
        return result;
    }

    fcache = None;
    cache_key = "";
    cfg_fp = "";
    cfg: any = None;
    key_logical = "";
    annex_ok = True;
    annex_error_count = 0;

    annex_paths: list[str] = [];
    annex_formatted_map: dict[str, str] = {};
    annex_logical_map: dict[str, str] = {};
    if lintfix {
        import from jaclang.compiler.driver.bccache { discover_annex_files }

        annex_paths = (
            discover_annex_files(file_path, '.impl.jac')
            + discover_annex_files(file_path, '.test.jac')
        );
        if logical_path {
            phys_parent = str(Path(file_path).resolve().parent);
            log_parent = str(Path(logical_path).parent);
            for ap in annex_paths {
                try {
                    rel = os.path.relpath(ap, phys_parent);
                    annex_logical_map[ap] = str(Path(log_parent) / rel);
                } except ValueError {
                    annex_logical_map[ap] = ap;
                }
            }
        }
    }
    if cache_stamp {
        try {
            import from jaclang.cli.format_cache {
                FormatCache,
                config_fingerprint,
                frame_unit,
                canonical_logical_path,
                default_format_cache_dir
            }
            import from jaclang.project.config { get_config_for_path }

            cfg = get_config_for_path(Path(effective_logical));
            if cfg is not None {
                cache_dir = cfg.get_cache_dir();
            } else {
                anchor = Path(cache_anchor) if cache_anchor else path_obj;
                cache_dir = default_format_cache_dir(anchor);
                cfg = None;
            }

            fcache = FormatCache(cache_dir, enabled=True, formatter_stamp=cache_stamp);

            unit_parts = [path_obj.read_bytes()];
            for ap in annex_paths {
                ap_obj = Path(ap);
                if ap_obj.exists() {
                    unit_parts.append(ap_obj.read_bytes());
                }
            }
            unit_bytes = frame_unit(unit_parts);
            cfg_fp = config_fingerprint(cfg, lintfix);
            project_root = str(cfg.project_root)
                if (cfg is not None and cfg.project_root)
                else (cache_anchor);
            key_logical = (
                canonical_logical_path(effective_logical, project_root)
                    if lintfix
                    else ""
            );
            cache_key = fcache.make_key(
                unit_bytes,
                lintfix=lintfix,
                config_fingerprint=cfg_fp,
                logical_path=key_logical
            );
            if fcache.is_clean(cache_key) {
                result['cache_status'] = 'hit';
                result['success'] = True;
                result['changed'] = False;
                result['errors'] = 0;
                return result;
            }
            result['cache_status'] = 'miss';
        } except (OSError, ValueError, TypeError, ImportError, AttributeError) {
            fcache = None;
            cache_key = "";
        }
    }

    try {
        if logical_path {
            source_str = read_file_with_encoding(str(path_obj));
            prog = JacProgram.jac_str_formatter(
                source_str, effective_logical, auto_lint=lintfix
            );
        } else {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=lintfix);
        }
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
                for annex_path in annex_paths {
                    if covered is not None
                        and (os.path.realpath(annex_path) in covered) {
                        continue;
                    }
                    annex_logical = annex_logical_map.get(annex_path, annex_path);
                    try {
                        if logical_path {
                            annex_src = read_file_with_encoding(annex_path);
                            annex_prog = JacProgram.jac_str_formatter(
                                annex_src, annex_logical, auto_lint=True
                            );
                        } else {
                            annex_prog = JacProgram.jac_file_formatter(
                                annex_path, auto_lint=True
                            );
                        }
                        annex_formatted = annex_prog.mod.main.gen.jac;
                        annex_original = annex_prog.mod.main.source.code;
                    } except (OSError, ValueError, TypeError, AttributeError) as e {
                        annex_ok = False;
                        annex_error_count += 1;
                        result['errors_strs'].append(
                            f"Error formatting annex '{annex_path}': {e}"
                        );
                        continue;
                    }
                    for warning in annex_prog.warnings_had {
                        result['warnings_strs'].append(str(warning));
                    }
                    for error in annex_prog.errors_had {
                        result['errors_strs'].append(str(error));
                        annex_ok = False;
                        annex_error_count += 1;
                    }
                    annex_formatted_map[annex_path] = (
                        annex_formatted if annex_formatted is not None else ""
                    );
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
        } except (OSError, ValueError, TypeError, AttributeError) {
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
            lint_errors += annex_error_count;
        }
        result['success'] = True;
        result['errors'] = lint_errors;

        if (
            fcache is not None
            and cache_key
            and result['success']
            and not result['syntax_errors']
            and result['errors'] == 0
            and annex_ok
        ) {
            try {
                import from jaclang.cli.format_cache { frame_unit }

                if not result['changed'] {
                    fcache.mark_clean(cache_key);
                } elif not check {
                    main_clean = (
                        formatted_code.encode() if changed else path_obj.read_bytes()
                    );
                    new_parts = [main_clean];
                    for ap in annex_paths {
                        if ap in annex_formatted_map {
                            new_parts.append(annex_formatted_map[ap].encode());
                        } elif Path(ap).exists() {
                            new_parts.append(Path(ap).read_bytes());
                        } else {
                            annex_ok = False;
                            break;
                        }
                    }
                    if annex_ok {
                        new_unit = frame_unit(new_parts);
                        fcache.mark_clean(
                            fcache.make_key(
                                new_unit,
                                lintfix=lintfix,
                                config_fingerprint=cfg_fp,
                                logical_path=key_logical
                            )
                        );
                    }
                }
            } except (OSError, ValueError, TypeError, AttributeError) {}
        }

        return result;
    } except Exception as e {
        result['syntax_errors'] = [f"Error formatting '{file_path}': {e}"];
        return result;
    }
}

impl format(
    paths: list,
    to_screen: bool = False,
    lintfix: bool = False,
    check: bool = False,
    cache: bool = False,
    cache_anchor: str = "",
    path_map: dict | None = None,
    cache_stats: dict | None = None,
    jobs: str = ""
) -> int {
    import os;
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    import from jaclang.project.config { get_config }
    if isinstance(paths, str) {
        paths = [paths];
    }

    cache_stamp = "";

    if cache and not to_screen {
        import from jaclang.cli.format_cache {
            FORMAT_CACHE_SCHEMA_VERSION,
            formatter_pipeline_revision
        }
        import from jaclang.cli.cli { jac_version }
        try {
            rev = formatter_pipeline_revision();
            cache_stamp = f"jfmt:{FORMAT_CACHE_SCHEMA_VERSION}:{jac_version()}:{rev}";
        } except (OSError, ValueError, TypeError, ImportError, AttributeError) {
            cache_stamp = "";
        }
    }

    unformatted_files: list[str] = [];
    failed_results: list = [];

    (all_files, had_path_errors) = _iter_jac_files(paths);
    total_files = len(all_files);

    if total_files == 0 {
        return 1 if had_path_errors else 0;
    }

    remap = path_map if path_map is not None else {};
    covered: set[str] = {os.path.realpath(f) for f in all_files};

    cfg = get_config();
    raw_jobs = jobs_setting("fmt", jobs, cfg.dev if cfg else None);
    workers = resolve_jobs(raw_jobs, env_var="JAC_FMT_JOBS");
    use_pool = (
        pool_available()
        and not to_screen
        and not forced_serial(raw_jobs)
        and workers > 1
        and total_files > 1
    );

    results_by_idx: dict[(int, dict)] = {};

    progress: dict[(str, any)] = {"pooled": use_pool, "done": 0};

    def fmt_job(request: dict[(str, any)]) -> dict {
        fp = str(request["path"]);
        return _format_single_file_worker(
            fp, lintfix, check, covered, cache_stamp, cache_anchor, remap.get(fp, "")
        );
    }

    def on_dispatch(idx: int, path: str) {
        if not progress["pooled"] {
            console.print(f"Formatting {path}");
        }
    }

    def on_record(idx: int, record: dict[(str, any)]) -> None {
        if progress["pooled"] {
            progress["done"] += 1;
            console.print(
                f"Formatting [{progress['done']}/{total_files}] completed..."
            );
        }
        res = _wire_dict(record.get('result'));
        if res {
            results_by_idx[idx] = res;
            return;
        }
        detail = record.get('crash') or record.get('error') or 'no result';
        results_by_idx[idx] = {
            'path': all_files[idx],
            'success': False,
            'changed': False,
            'errors': 0,
            'syntax_errors': [f"Worker error: {detail}"],
            'warnings_strs': [],
            'errors_strs': [],
            'formatted_code': None,
            'impl_results': [],
            'cache_status': 'off'
        };
    }

    pool = WorkPool(
        items=list(all_files),
        job=fmt_job,
        on_record=on_record,
        jobs=min(workers, total_files),
        on_dispatch=on_dispatch,
        rss_log_env="JAC_FMT_RSS_LOG",
        crash_prefix="jac-fmt-crash-"
    );
    if use_pool {
        try {
            pool.run();
        } except Exception as e {
            console.print(
                f"Parallel formatting unavailable ({type(e).__name__}: {e}); "
                "falling back to serial."
            );
            results_by_idx.clear();
            progress["pooled"] = False;
            pool.run_inline();
        }
    } else {
        pool.run_inline();
    }
    results: list[dict] = [];
    for idx in range(total_files) {
        if idx not in results_by_idx {
            on_record(idx, {'error': 'no result'});
        }
        results.append(results_by_idx[idx]);
    }

    if cache_stamp {
        hits = sum(
            1
            for r in results
            if r.get('cache_status') == 'hit'
        );
        misses = sum(
            1
            for r in results
            if r.get('cache_status') == 'miss'
        );
        if cache_stats is not None {
            cache_stats["hits"] = hits;
            cache_stats["misses"] = misses;
            cache_stats["examined"] = hits + misses;
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
                impl_pairs: list[tuple[str, str]] = res['impl_results'];
                for (impl_path, impl_code) in impl_pairs {
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
    force: bool = False,
    cache_stats: dict | None = None
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
        if config is not None and config.project_root {
            targets = [str(config.project_root)];
        } else {
            targets = ["."];
        }
    }

    fmt_targets = targets;
    tmp_root: (str | None) = None;
    path_map: dict = {};
    if staged and verify {
        dirty = _staged_dirty_files(git_root, rel_targets);
        if dirty {
            tmp_root = tempfile.mkdtemp(prefix="jac-precommit-");
            try {
                checkout_paths = list(rel_targets);
                try {
                    import from jaclang.compiler.driver.bccache { discover_annex_files }
                    rel_set = {r for r in rel_targets};
                    annex_rel: list[str] = [];
                    for rel in rel_targets {
                        abs_t = os.path.join(git_root, rel);
                        if not os.path.exists(abs_t) {
                            continue;
                        }
                        for ap in (
                            discover_annex_files(abs_t, '.impl.jac')
                            + discover_annex_files(abs_t, '.test.jac')
                        ) {
                            ap_rel = os.path.relpath(ap, git_root).replace(os.sep, "/");
                            if ap_rel not in rel_set {
                                annex_rel.append(ap_rel);
                            }
                        }
                    }
                    if annex_rel {
                        ls_out = subprocess.run(
                            ["git", "ls-files", "--"] + annex_rel,
                            capture_output=True,
                            text=True,
                            cwd=git_root,
                            check=True
                        ).stdout;
                        for line in ls_out.splitlines() {
                            tracked = line.strip();
                            if tracked and tracked not in rel_set {
                                rel_set.add(tracked);
                                checkout_paths.append(tracked);
                            }
                        }
                    }
                } except Exception {}
                subprocess.run(
                    [
                        "git",
                        "checkout-index",
                        "-f",
                        f"--prefix={tmp_root}{os.sep}",
                        "--"
                    ]
                        + checkout_paths,
                    check=True,
                    cwd=git_root
                );
                fmt_targets = [os.path.join(tmp_root, rel) for rel in rel_targets];

                path_map = {
                    os.path.join(tmp_root, rel): os.path.join(git_root, rel)
                    for rel in rel_targets
                };
                console.print("[precommit] Verifying staged content (index checkout).");
            } except Exception as e {
                shutil.rmtree(tmp_root, ignore_errors=True);
                tmp_root = None;
                fmt_targets = targets;
                path_map = {};
                console.warning(
                    f"[precommit] Could not check out the staged blobs ({e}); "
                    "verifying the WORKTREE copies instead -- staged content "
                    "that differs from the worktree was NOT verified."
                );
            }
        }
    }
    console.print("precommit: formatting (--lintfix)", style="muted");
    fmt_ret = format(
        fmt_targets,
        to_screen=False,
        lintfix=True,
        check=verify,
        cache=True,
        cache_anchor=git_root,
        path_map=path_map,
        cache_stats=cache_stats
    );
    if tmp_root {
        shutil.rmtree(tmp_root, ignore_errors=True);
    }
    console.print("[precommit] Running check...");
    check_ret = check(targets);
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
    precommit_body = (
        "#!/bin/sh\n"
        "# Installed by `jac precommit --install`\n"
        "exec jac precommit --staged --verify\n"
    );
    commit_msg_body = (
        "#!/bin/sh\n"
        "# Installed by `jac precommit --install`\n"
        "if grep -iEq 'co-authored-by:.*\\b(claude|anthropic|openai|copilot"
        "|composer|cursor|gpt|gemini|ai|bot)\\b' \"$1\"; then\n"
        "  echo 'commit-msg: AI co-author attribution is not allowed.' >&2\n"
        "  exit 1\n"
        "fi\n"
    );
    for pair in [("pre-commit", precommit_body), ("commit-msg", commit_msg_body)] {
        ret = _write_git_hook(os.path.join(hooks_dir, pair[0]), pair[1], force);
        if ret != 0 {
            return ret;
        }
    }
    console.success(f"Installed git hooks in '{hooks_dir}': pre-commit, commit-msg.");
    console.print("pre-commit runs: jac precommit --staged --verify");
    console.print("commit-msg blocks AI co-author attribution lines.");
    return 0;
}

def _write_git_hook(hook_path: str, body: str, force: bool) -> int {
    import os;
    import stat;
    if os.path.exists(hook_path) {
        try {
            with open(hook_path, encoding="utf-8", errors="replace") as f {
                existing = f.read();
            }
        } except Exception {
            existing = "";
        }
        is_ours = "Installed by `jac precommit --install`" in existing;
        is_framework = "generated by pre-commit" in existing;
        if not (is_ours or is_framework or force) {
            console.warning(f"A hook already exists at '{hook_path}'.");
            console.warning(
                "Re-run 'jac precommit --install --force' to replace it "
                "(the old hook is kept as a .bak backup)."
            );
            return 1;
        }
        if not is_ours {
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
    }
    try {
        with open(hook_path, "w", encoding="utf-8") as f {
            f.write(body);
        }
        mode = os.stat(hook_path).st_mode;
        os.chmod(hook_path, mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH);
    } except Exception as e {
        console.error(f"Failed to write hook: {e}");
        return 1;
    }
    return 0;
}

impl `test(
    target: str = "",
    paths: list = [],
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    collect_only: bool = False,
    pct_range: str = "",
    resume: bool = False,
    verbose: bool = False,
    ignore: (list | None) = None,
    jobs: str = ""
) -> int {
    import os;
    import from jaclang.project.config { get_config }
    import from jaclang.testing.test_runner { run_tests }
    import from jaclang.cli.workpool { jobs_setting }
    if isinstance(paths, str) {
        paths = [paths];
    }
    cfg = get_config();
    cfg_root = str(cfg.project_root) if (cfg and cfg.project_root) else "";
    app_root = "";
    app_cfg: any = None;
    explicit_app = False;
    if target {
        if cfg is not None and _is_app_name(target) and target in cfg.apps {
            app_cfg = cfg.app(target);
            explicit_app = True;
        } elif _is_app_name(target) and not Path(target).exists() {
            console.error(
                f"Error: '{target}' is neither an app of jac.toml nor a path."
            );
            return 1;
        } else {
            paths = [target] + list(paths);
        }
    } elif cfg is not None and not paths and not directory {
        try {
            app_cfg = cfg.resolve_app("");
        } except ValueError {
            app_cfg = None;
        }
    }
    re_root = explicit_app
        or (app_cfg is not None and cfg is not None and cfg.is_workspace);
    if app_cfg is not None and cfg is not None and app_cfg.name in cfg.apps {
        cfg = cfg.effective_for_app(app_cfg.name);
        app_root = app_cfg.root_dir(cfg_root) or cfg_root;
        if app_cfg.is_file_rooted() and not paths {
            paths = [app_cfg.entry_path(cfg_root)];
        }
    }
    def _rooted(raw: str) -> str {
        base = app_root or cfg_root;
        if base and not os.path.isabs(raw) {
            return os.path.join(base, raw);
        }
        return raw;
    }
    if (test_name and not paths) {
        console.error(
            "Error: --test_name requires a filepath. "
            "Running by name across all files is ambiguous.\n"
            "Usage: jac test <file.jac> --test_name <name>"
        );
        return 1;
    }

    roots: (str | list[str]) = directory;
    if (not paths and not directory and re_root and app_root) {
        roots = [app_root];
    }
    if (not paths and not directory) {
        cfg_dirs: list[str] = [];
        if cfg {
            cfg_dirs = cfg.`test.directories
                or ([cfg.`test.directory] if cfg.`test.directory else []);
        }
        resolved: list[str] = [];
        for raw in cfg_dirs {
            rt = _rooted(raw);
            if (
                app_root
                and cfg_root
                and not os.path.isabs(raw)
                and not Path(rt).is_dir()
                and Path(os.path.join(cfg_root, raw)).is_dir()
            ) {
                rt = os.path.join(cfg_root, raw);
            }
            if not Path(rt).is_dir() {
                console.error(
                    f"Error: [test] directory '{raw}' "
                    f"(resolved to '{rt}') does not exist."
                );
                return 1;
            }
            resolved.append(rt);
        }
        if resolved {
            roots = resolved;
        } elif not roots {
            paths = [cfg_root or os.getcwd()];
        }
    }
    iso_pats = [_rooted(p) for p in (cfg.`test.isolate if cfg else [])];
    ser_pats = [_rooted(p) for p in (cfg.`test.serial if cfg else [])];
    for fp in paths {
        if not Path(fp).exists() {
            console.error(
                f"Error: File not found: '{fp}'\n"
                "Make sure you are in the correct directory or provide the "
                f"full path.\nUsage: jac test /full/path/to/{fp}"
            );
            return 1;
        }
    }
    jobs = jobs_setting("test", jobs, cfg.dev if cfg else None);
    rc = 0;
    try {
        rc = run_tests(
            paths=paths,
            directory=roots,
            test_name=test_name,
            filter=filter,
            xit=xit,
            maxfail=maxfail,
            collect_only=collect_only,
            pct_range=pct_range,
            resume=resume,
            verbose=verbose,
            ignore=[
                p
                for p in (ignore or [])
                if p
            ],
            jobs=jobs,
            isolate=iso_pats,
            serial=ser_pats
        );
    } except (ValueError, FileNotFoundError) as exc {
        console.error(f"Error: {exc}");
        return 1;
    }
    if rc == 5 {
        console.error("No tests ran.");
    } elif rc {
        console.error("Tests failed.");
    }
    return rc;
}

impl gen_parser -> int {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    console.success('Parser generated.');
    return 0;
}

impl grammar(output: str = "", strict: bool = False) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
    import jaclang;
    parser_path = str(
        Path(jaclang.__file__).parent
            / "compiler"
            / "frontend"
            / "parser"
            / "parser.jac"
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
    import from jaclang.compiler.driver.pass_driver { run_pass }
    pass_ = run_pass(GrammarExtractPass, mod, prog);
    if len(pass_.rules) == 0 {
        console.error("No grammar rules extracted.");
        return 1;
    }
    text = pass_.emit_ebnf();
    if output {
        banner = (
            "# Auto-generated EBNF snapshot of the Jac grammar.\n"
            + "# DO NOT EDIT MANUALLY - regenerate with"
            + " `jac tool grammar -o <path>`.\n\n"
        );
        with open(output, "w", encoding="utf-8") as f {
            f.write(banner);
            f.write(text);
            f.write("\n");
        }
        console.success(f"EBNF grammar ({len(pass_.rules)} rules) written to {output}");
    } elif not strict {
        console.print(text);
    }
    if strict {
        console.print(pass_.emit_diagnostics());
    }
    return 0;
}

def _iter_jac_files(
    paths: list, ignore_list: (list | None) = None, include_annex: bool = True
) -> tuple[list[str], bool] {
    import os;
    ignore_list = ignore_list or [];
    result: list[str] = [];
    explicit: set[str] = set();
    had_errors = False;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not _should_ignore(path, ignore_list) {
                result.append(path);
                explicit.add(os.path.realpath(path));
            }
        } elif path_obj.is_dir() {
            walked: list[str] = [];
            for jac_file in path_obj.`glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                if not _should_ignore(str(jac_file), ignore_list) {
                    walked.append(str(jac_file));
                }
            }
            if _drop_git_ignored([str(path_obj)]) {
                result.extend(_drop_git_ignored(walked));
            } else {
                result.extend(walked);
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            had_errors = True;
        }
    }
    if not include_annex {
        result = _drop_covered_annexes(result, explicit);
    }
    return (result, had_errors);
}

def _drop_covered_annexes(files: list[str], explicit: set[str]) -> list[str] {
    import os;
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.jac0core.ext_registry { is_annex }
    modules = {
        os.path.realpath(f)
        for f in files
        if not is_annex(f)
    };
    kept: list[str] = [];
    for f in files {
        if is_annex(f) and (os.path.realpath(f) not in explicit) {
            base = discover_base_file(f);
            if (base is not None) and (os.path.realpath(base) in modules) {
                continue;
            }
        }
        kept.append(f);
    }
    return kept;
}

def _normalize_ignore_patterns(ignore: list) -> list {
    import from jaclang.compiler.frontend.helpers { normalize_exclude_patterns }
    return normalize_exclude_patterns(ignore);
}

def _drop_git_ignored(paths: list[str]) -> list[str] {
    import subprocess;
    if not paths {
        return paths;
    }
    try {
        proc = subprocess.run(
            ['git', 'check-ignore', '--stdin'],
            input="\n".join(paths),
            capture_output=True,
            text=True,
            check=False
        );
    } except (OSError, ValueError) {
        return paths;
    }

    if proc.returncode not in (0, 1) {
        return paths;
    }
    ignored = {
        line
        for line in proc.stdout.splitlines()
        if line
    };
    if not ignored {
        return paths;
    }
    return [
        p
        for p in paths
        if p not in ignored
    ];
}


def _should_ignore(file_path: str, ignore_patterns: list) -> bool {
    import from jaclang.compiler.frontend.helpers { path_matches_exclude }
    return path_matches_exclude(file_path, ignore_patterns);
}
