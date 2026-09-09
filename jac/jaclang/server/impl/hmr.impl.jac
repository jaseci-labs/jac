import json;
import logging;
import os;
import sys;
import time;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.driver.bccache { discover_base_file }
import from jaclang.cli.console { console }

glob logger = logging.getLogger(__name__);

def _syntax_error_line(file_path: str, err: SyntaxError) -> str {
    where = f":{err.lineno}" if err?.lineno and err.lineno else "";
    return f"Syntax error in {file_path}{where}: {err?.msg or str(err)}";
}

impl HotReloader.start -> None {
    if self._running {
        return;
    }

    self.watcher.add_callback(self.on_file_change);

    self.watcher.start();
    self._running = True;
    HotReloader._active = self;
    logger.debug(f"Hot reloader started for module: {self.module_name}");
}

impl HotReloader.stop -> None {
    if not self._running {
        return;
    }
    self._running = False;
    if HotReloader._active is self {
        HotReloader._active = None;
    }

    self.watcher.stop();
    logger.debug("Hot reloader stopped");
}

impl HotReloader.build_status -> dict {
    diags = self.diagnostics();
    if diags {
        return {
            "status": BuildStatus.ERROR.value,
            "diagnostics": [diag.to_dict() for diag in diags]
        };
    }
    return {"status": self._build_status.value, "diagnostics": []};
}

impl HotReloader.diagnostics -> list {
    with HotReloader._build_lock {
        if self._build_status is BuildStatus.ERROR {
            return list(self._diagnostics);
        }
        if self._build_status is not BuildStatus.OK {
            return [];
        }
        return list(self._vite_diagnostics) + list(self._client_diagnostics);
    }
}

impl HotReloader.attach_client_bundler(bundler: any) -> None {
    if bundler is None {
        return;
    }
    bundler.on_client_event = self.record_client_event;
}

impl HotReloader.record_client_event(slot: str, payload: (dict | None)) -> None {
    import from jaclang.client.client_diagnostics { classify_client_payload }
    import from jaclang.client.source_mapping { _error_rate_limiter }
    if slot not in ('vite', 'client', 'runtime', 'ready') {
        return;
    }
    fresh: list = [];
    if slot != 'ready' and isinstance(payload, dict) and payload.get('message') {
        channel = 'vite' if slot == 'vite' else 'browser';
        try {
            fresh = [classify_client_payload(self.base_path, payload, channel)];
        } except Exception as e {
            logger.debug(f"Could not classify client event: {e}");
            return;
        }
    }
    with HotReloader._build_lock {
        if slot == 'ready' {
            self._client_diagnostics = [];
            self._runtime_diagnostics = [];
        } elif slot == 'vite' {
            self._vite_diagnostics = fresh;
        } elif slot == 'client' {
            self._client_diagnostics = fresh;
        } else {
            self._runtime_diagnostics = fresh;
        }
    }
    for diag in fresh {
        if _error_rate_limiter.should_log(diag.key()) {
            console.error(diag.render());
        }
    }
    self._sync_status_file();
}

impl HotReloader.record_ok -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.OK;
        self._diagnostics = [];
    }
    self._sync_status_file();
}

impl HotReloader.record_error(
    file_path: str,
    message: str,
    alerts: (list | None) = None,
    line: int = 0,
    column: int = 0
) -> None {
    import from jaclang.client.client_diagnostics {
        build_failure_diagnostic,
        diagnostics_from_alerts
    }
    diags = diagnostics_from_alerts(alerts, self.base_path) if alerts else [];
    if not diags {
        diags = [
            build_failure_diagnostic(self.base_path, file_path, message, line, column)
        ];
    }
    with HotReloader._build_lock {
        self._build_status = BuildStatus.ERROR;
        self._diagnostics = diags;
    }
    self._sync_status_file();
}

impl HotReloader._status_file_path -> Path {
    if self.client_compiler {
        try {
            compiled = Path(str(self.client_compiler.jac_client_compiler.compiled_dir));
            return compiled.parent / '.jac-status.json';
        } except Exception {}
    }
    return Path(self.base_path) / '.jac' / 'client' / '.jac-status.json';
}

impl HotReloader._sync_status_file -> None {
    try {
        payload = self.build_status();
        status_file = self._status_file_path();
        if payload["status"] == BuildStatus.ERROR.value {
            status_file.parent.mkdir(parents=True, exist_ok=True);
            status_file.write_text(json.dumps(payload), encoding='utf-8');
        } elif status_file.exists() {
            status_file.unlink();
        }
    } except OSError {}
}

impl get_build_status -> dict {
    reloader = HotReloader._active;
    if not reloader {
        return {"status": BuildStatus.UNAVAILABLE.value, "diagnostics": []};
    }
    return reloader.build_status();
}

impl HotReloader.on_file_change(event: any) -> None {
    if not self._running {
        return;
    }

    self._process_change(event.path, bool(getattr(event, 'is_directory', False)));
}

impl HotReloader._process_change(file_path: str, is_directory: bool = False) -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.COMPILING;
    }
    try {
        self._dispatch_change(file_path, is_directory);
    } except Exception as e {
        self.record_error(file_path, f"{type(e).__name__}: {e}");
        raise;
    }

    if self._build_status is BuildStatus.COMPILING {
        self.record_ok();
    }
}

impl HotReloader._dispatch_change(file_path: str, is_directory: bool = False) -> None {
    if is_directory {
        if not Path(file_path).exists() {
            self._remove_compiled_dir(file_path);
        }
        self._refresh_routing(file_path);
        return;
    }
    if file_path.endswith(
        tuple(
            p[1:] if p.startswith("*") else p for p in self.watcher.additional_patterns
        )
    ) {
        self._copy_frontend_files(file_path);
        return;
    }

    import from jaclang.jac0core.ext_registry { is_impl }
    target_path = file_path;
    if is_impl(file_path) {
        base = discover_base_file(file_path);
        if base {
            target_path = base;
        }
    }

    if not Path(target_path).exists() {
        self._remove_compiled_output(target_path);
        self._reload_server_module(target_path);
        self._refresh_routing(target_path);
        return;
    }

    (has_client, has_server, _has_native) = self._classify_declarations(target_path);

    if has_server {
        self._reload_server_module(target_path);
    }

    if has_client {
        visited: set = set();
        self._recompile_client_code(target_path, visited);
    }

    if self._tracked_wasm_module(target_path) {
        self._reemit_native_wasm(target_path);
    }

    self._refresh_routing(target_path);
}


impl HotReloader._tracked_wasm_module(file_path: str) -> bool {
    if not self.client_compiler {
        return False;
    }
    try {
        tracked = self.client_compiler.jac_client_compiler?.na_wasm_modules or set();
        target = str(Path(file_path).resolve());
        for known in tracked {
            if str(Path(known).resolve()) == target {
                return True;
            }
        }
    } except OSError {
        return False;
    }
    return False;
}


impl HotReloader._reemit_native_wasm(file_path: str) -> None {
    if not self.client_compiler {
        return;
    }
    try {
        emitted = self.client_compiler._emit_wasm_module(Path(file_path).resolve());
    } except Exception as e {
        console.error(f"na wasm re-emit failed for {file_path}: {e}");
        self.record_error(file_path, f"na wasm re-emit failed: {e}");
        return;
    }
    if emitted {
        self._signal_full_reload();
    }
}

impl HotReloader._entry_module_path -> Path {
    return Path(self.base_path) / f"{self.module_name}.jac";
}

impl HotReloader._remove_compiled_output(file_path: str) -> None {
    base_dir = Path(self.base_path).resolve();
    source_path = Path(file_path);
    try {
        source_path = source_path.resolve();
    } except OSError {}
    if self.client_compiler {
        output_path = self.client_compiler.jac_client_compiler._output_path_for(
            source_path, base_dir
        );
    } else {
        try {
            rel_dir = source_path.parent.relative_to(base_dir);
        } except ValueError {
            rel_dir = Path('.');
        }
        output_path = (
            Path(self.base_path)
            / self._client_output_dir
            / rel_dir
            / self._get_js_filename(file_path)
        );
    }
    removed = False;
    for target in (Path(str(output_path)), Path(str(output_path) + '.map')) {
        try {
            if target.exists() {
                target.unlink();
                removed = True;
            }
        } except OSError {}
    }
    if removed {
        console.warning(f"Removed compiled output for deleted {file_path}");
    }
}

impl HotReloader._remove_compiled_dir(file_path: str) -> None {
    base_dir = Path(self.base_path).resolve();
    source_path = Path(file_path);
    try {
        source_path = source_path.resolve();
    } except OSError {}
    try {
        rel = source_path.relative_to(base_dir);
    } except ValueError {
        return;
    }
    if self.client_compiler {
        compiled_root = Path(
            str(self.client_compiler.jac_client_compiler.compiled_dir)
        );
    } else {
        compiled_root = Path(self.base_path) / self._client_output_dir;
    }
    target = compiled_root / rel;
    try {
        if str(target.resolve()) == str(compiled_root.resolve()) {
            return;
        }
        if target.is_dir() {
            shutil.rmtree(target);
            console.warning(
                f"Removed compiled output for deleted directory {file_path}"
            );
        }
    } except OSError {}
}

impl HotReloader._refresh_routing(file_path: str) -> None {
    if not self.client_compiler {
        return;
    }
    base_dir = Path(self.base_path).resolve();
    pages_dir = base_dir / 'pages';
    changed = Path(file_path);
    try {
        changed = changed.resolve();
    } except OSError {}
    under_pages = (
        str(changed) == str(pages_dir)
        or str(changed).startswith(str(pages_dir) + os.sep)
    );
    jcc = self.client_compiler.jac_client_compiler;
    routes_file = Path(str(jcc.compiled_dir)) / '_routes.js';
    routes_missing = pages_dir.is_dir() and not routes_file.exists();

    routes_stale = routes_file.exists() and not pages_dir.is_dir();
    if not (under_pages or routes_missing or routes_stale) {
        return;
    }
    try {
        jcc.routes_manifest_changed = False;
        has_pages = jcc.rescan_pages();
        self.client_compiler._has_pages = has_pages;
        self.client_compiler.create_entry_file(self._entry_module_path());
        if jcc.routes_manifest_changed {
            console.print("  ↻ Route table changed; full reload");
            self._signal_full_reload();
        }
        if not has_pages {
            if routes_file.exists() {
                routes_file.unlink();
            }
            compiled_pages = Path(str(jcc.compiled_dir)) / 'pages';
            if compiled_pages.is_dir() {
                shutil.rmtree(compiled_pages);
            }
            console.warning("Routing deactivated: pages/ no longer exists");
        }
    } except Exception as e {
        console.error(f"Routing refresh failed for {file_path}: {e}");
        self.record_error(file_path, f"Routing refresh failed: {e}");
    }
}

impl HotReloader._reload_server_module(file_path: str) -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    sys.modules.pop(self.module_name, None);
    program = Jac.program;
    if program is not None {
        for key in list(program.mod.hub.keys()) {
            sys.modules.pop(self._path_to_module(key), None);
        }
    }

    try {
        resolved_path = str(Path(file_path).resolve());
        for key in (file_path, resolved_path) {
            if program is not None {
                program.invalidate_module(key);
                program.drop_module_alerts(key);
            }
        }
    } except Exception as e {
        console.warning(f"Could not clear module hub: {e}");
    }

    try {
        Jac.jac_import(
            target=self.module_name, base_path=self.base_path, reload_module=True
        );
        console.print(f"[HMR] Reloaded: {file_path}");
    } except SyntaxError as e {
        console.error(
            _syntax_error_line(file_path, e), hint="Fix the error and save to retry"
        );
        self.record_error(
            file_path,
            f"Syntax error: {e?.msg or str(e)}",
            line=int(e.lineno or 0),
            column=int(e.offset or 0)
        );
    } except ImportError as e {
        console.error(f"Import error in {file_path}: {e}");
        self.record_error(file_path, f"Import error: {e}");
    } except Exception as e {
        error_type = type(e).__name__;
        console.error(f"{error_type} in {file_path}: {e}");
        self.record_error(file_path, f"{error_type}: {e}");
    }
}

impl HotReloader._recompile_client_unified(file_path: str) -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.client.client_bundle { ClientBundleError }
    try {
        source_path = Path(file_path).resolve();
        if not source_path.exists() {
            return;
        }

        js_path = self._client_js_path(file_path);
        old_exports: set[str] = set();
        had_js = False;
        if js_path is not None and js_path.exists() {
            had_js = True;
            old_exports = self._extract_js_exports(js_path);
        }

        program = Jac.program;
        if program is not None {
            for key in {file_path, str(source_path)} {
                program.invalidate_module(key);
                program.drop_module_alerts(key);
            }
        }
        jcc = self.client_compiler.jac_client_compiler;
        mark = len(program.errors_had) if program is not None else 0;
        jcc.compile_dependencies_recursively(
            source_path, source_root=Path(self.base_path).resolve(), skip_existing=True
        );
        console.success(
            f"Recompiled: {file_path} -> {self._get_js_filename(file_path)}"
        );

        if had_js
            and js_path is not None
            and self._extract_js_exports(js_path) != old_exports {
            console.print(
                f"  ↻ Export set of {self._get_js_filename(
                    file_path
                )} changed; full reload"
            );
            self._signal_full_reload();
        }
    } except ClientBundleError as e {
        base_prefix = str(Path(self.base_path).resolve()) + '/';
        errors = str(e).replace(base_prefix, '');
        console.error(f"Compile error in {file_path}:\n{errors}");
        self.record_error(
            file_path,
            errors,
            alerts=(program.errors_had[mark:] if program is not None else None)
        );
    } except Exception as e {
        console.error(f"Compile error in {file_path}: {e}");
        self.record_error(file_path, str(e));
    }
}

impl HotReloader._client_js_path(file_path: str) -> (Path | None) {
    if not self.client_compiler {
        return None;
    }
    try {
        jcc = self.client_compiler.jac_client_compiler;
        source_path = Path(file_path).resolve();
        return Path(
            str(jcc._output_path_for(source_path, Path(self.base_path).resolve()))
        );
    } except Exception {
        return None;
    }
}

impl HotReloader._extract_js_exports(js_path: Path) -> set[str] {
    import re;
    names: set[str] = set();
    try {
        code = js_path.read_text(encoding='utf-8');
    } except OSError {
        return names;
    }
    for block in re.findall(r'export\s*\{([^}]*)\}', code) {
        for part in block.split(',') {
            token = part.strip();
            if token {
                names.add(token.split(' as ')[-1].strip());
            }
        }
    }
    return names;
}

impl HotReloader._signal_full_reload -> None {
    self._reload_nonce += 1;
    signal_file = self._status_file_path().parent / '.jac-force-reload';
    try {
        if signal_file.parent.is_dir() {
            signal_file.write_text(str(self._reload_nonce), encoding='utf-8');
        }
    } except OSError {}
}

impl HotReloader._recompile_client_code(
    file_path: str, visited: set | None = None, force: bool = True
) -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    if self.client_compiler {
        self._recompile_client_unified(file_path);
        return;
    }
    try {
        source_path = Path(file_path).resolve();
        source_key = str(source_path);

        if visited is None {
            visited = set();
        }
        if source_key in visited {
            return;
        }
        visited.add(source_key);

        base_dir = Path(self.base_path).resolve();
        output_base = Path(self.base_path) / self._client_output_dir;

        try {
            rel_dir = source_path.parent.relative_to(base_dir);
        } except ValueError {
            rel_dir = Path('.');
        }
        output_dir = output_base / rel_dir;
        js_filename = self._get_js_filename(file_path);
        output_path = output_dir / js_filename;

        if not force and output_path.exists() {
            return;
        }
        if not source_path.exists() {
            return;
        }

        program = Jac.program;
        if program is None {
            return;
        }
        program.invalidate_module(source_key);
        program.drop_module_alerts(source_key);

        mark = len(program.errors_had);
        artifact = program.get_client_artifact(source_key);

        new_errors = program.errors_had[mark:];
        if new_errors {
            if force {
                base_prefix = str(base_dir) + '/';
                errors = '\n'.join(
                    str(err).replace(base_prefix, '') for err in new_errors
                );
                console.error(f"Compile error in {file_path}:\n{errors}");
                self.record_error(file_path, errors, alerts=new_errors);
            } else {
                console.warning(f"Errors compiling dependency {file_path}, skipping");
            }
            return;
        }
        if artifact is None {
            if force {
                console.warning(f"No client JS generated for {file_path}");
            }
            return;
        }

        import from jaclang.client.client_surface { prepend_active_runtime_globals }
        js_code = prepend_active_runtime_globals(artifact.js);

        manifest = artifact.manifest;
        if manifest.imports {
            for (import_key, import_path) in manifest.imports.items() {
                if import_key.startswith('@jac/') {
                    continue;
                }
                dep_path = Path(import_path).resolve();
                if str(dep_path).endswith('.jac') {
                    self._recompile_client_code(str(dep_path), visited, force=False);
                }
            }
        }

        output_dir.mkdir(parents=True, exist_ok=True);
        output_path.write_text(js_code, encoding='utf-8');

        if force {
            console.success(f"Recompiled: {file_path} -> {js_filename}");
        } else {
            console.success(f"Compiled dependency: {file_path} -> {js_filename}");
        }
    } except Exception as e {
        if force {
            console.error(f"Compile error in {file_path}: {e}");
            self.record_error(file_path, str(e));
        } else {
            console.warning(f"Could not compile dependency {file_path}: {e}");
        }
    }
}

impl HotReloader._get_js_filename(file_path: str) -> str {
    import from jaclang.jac0core.ext_registry { base_stem }
    path = Path(file_path);

    return base_stem(path.name) + ".js";
}

impl HotReloader._classify_declarations(file_path: str) -> tuple[bool, bool, bool] {
    import from jaclang.compiler.driver.program { JacProgram }
    has_client = False;
    has_server = False;
    has_native = False;
    try {
        prog = JacProgram();
        mod = prog.compile(file_path, no_cgen=True);

        for nd in mod.body {
            nd_context = nd?.code_context;
            if nd_context {
                if nd_context == CodeContext.CLIENT {
                    has_client = True;
                } elif nd_context == CodeContext.NATIVE {
                    has_native = True;
                } else {
                    has_server = True;
                }
            }
        }

        if not has_client and not has_server and not has_native {
            has_server = True;
        }
    } except SyntaxError as e {
        console.error(_syntax_error_line(file_path, e));
        has_server = True;
    } except Exception as e {
        error_type = type(e).__name__;
        console.error(f"{error_type} in {file_path}: {e}");
        has_server = True;
    }
    return (has_client, has_server, has_native);
}

impl HotReloader._path_to_module(file_path: str) -> str {
    import from jaclang.jac0core.ext_registry { base_stem }

    path = Path(file_path);
    base = Path(self.base_path).resolve();
    try {
        rel_path = path.relative_to(base);
    } except ValueError {
        rel_path = path;
    }

    module_parts = [];
    for part in rel_path.parts {
        module_parts.append(base_stem(part));
    }
    return ".".join(module_parts);
}

impl HotReloader._copy_frontend_files(file_path: str) -> None {
    try {
        source_path = Path(file_path).resolve();
        base_dir = Path(self.base_path).resolve();
        try {
            rel_path = source_path.relative_to(base_dir);
        } except ValueError {
            rel_path = Path(source_path.name);
        }
        output_base = Path(self.base_path) / self._client_output_dir;
        output_path = output_base / rel_path;

        if not source_path.exists() {
            if output_path.exists() {
                output_path.unlink();
                console.warning(f"Removed deleted frontend file: {rel_path}");
            }
            return;
        }
        try {
            output_path.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(source_path, output_path);
        } except (FileNotFoundError, OSError) {}
        console.success(f"Copied: {rel_path}");
    } except Exception as e {
        console.error(f"Copy error in {file_path}: {e}");
        self.record_error(file_path, f"Copy error: {e}");
    }
}
