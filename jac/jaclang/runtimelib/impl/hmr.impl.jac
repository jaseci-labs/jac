import json;
import logging;
import os;
import sys;
import time;
import shutil;
import from pathlib { Path }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.bccache { discover_base_file }
import from jaclang.cli.console { console }

glob logger = logging.getLogger(__name__);

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
    dev_error = self._dev_status_error();
    with HotReloader._build_lock {
        status = self._build_status;
        if status is BuildStatus.ERROR {
            return {
                "status": status.value,
                "error": {
                    "file": self._build_error_file,
                    "message": self._build_error,
                    "source": "jac"
                }
            };
        }
        if status is BuildStatus.OK and dev_error {
            return {"status": BuildStatus.ERROR.value, "error": dev_error};
        }
        return {"status": status.value, "error": None};
    }
}

impl HotReloader._dev_status_error -> (dict | None) {
    status_file = self._error_file_path().parent / '.jac-dev-status.json';
    try {
        data = json.loads(status_file.read_text(encoding='utf-8'));
    } except (OSError, ValueError) {
        return None;
    }
    if not isinstance(data, dict) {
        return None;
    }
    for source in ('vite', 'client') {
        slot = data.get(source);
        if isinstance(slot, dict) and slot.get('message') {
            return {
                "file": str(slot.get('file') or ''),
                "message": str(slot['message']),
                "source": source
            };
        }
    }
    return None;
}

impl HotReloader.record_ok -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.OK;
        self._build_error_file = "";
        self._build_error = "";
    }
    self._sync_error_file();
}

impl HotReloader.record_error(file_path: str, message: str) -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.ERROR;
        self._build_error_file = file_path;
        self._build_error = message;
    }
    self._sync_error_file();
}

impl HotReloader._error_file_path -> Path {
    if self.client_compiler {
        try {
            compiled = Path(str(self.client_compiler.jac_client_compiler.compiled_dir));
            return compiled.parent / '.jac-build-error.json';
        } except Exception { }
    }
    return Path(self.base_path) / '.jac' / 'client' / '.jac-build-error.json';
}

impl HotReloader._sync_error_file -> None {
    try {
        with HotReloader._build_lock {
            is_error = self._build_status is BuildStatus.ERROR;
            payload = {"file": self._build_error_file, "message": self._build_error};
        }
        error_file = self._error_file_path();
        if is_error {
            if error_file.parent.is_dir() {
                error_file.write_text(json.dumps(payload), encoding='utf-8');
            }
        } elif error_file.exists() {
            error_file.unlink();
        }
    } except OSError { }
}

impl get_build_status -> dict {
    reloader = HotReloader._active;
    if not reloader {
        return {"status": BuildStatus.UNAVAILABLE.value, "error": None};
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

    (has_client, has_server) = self._classify_declarations(target_path);

    if has_server {
        self._reload_server_module(target_path);
    }

    if has_client {
        visited: set = set();
        self._recompile_client_code(target_path, visited);
    }

    self._refresh_routing(target_path);
}

impl HotReloader._entry_module_path -> Path {
    return Path(self.base_path) / f"{self.module_name}.jac";
}

impl HotReloader._remove_compiled_output(file_path: str) -> None {
    base_dir = Path(self.base_path).resolve();
    source_path = Path(file_path);
    try {
        source_path = source_path.resolve();
    } except OSError { }
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
            Path(self.base_path) / self._client_output_dir / rel_dir / self._get_js_filename(
                file_path
            )
        );
    }
    removed = False;
    for target in (Path(str(output_path)), Path(str(output_path) + '.map')) {
        try {
            if target.exists() {
                target.unlink();
                removed = True;
            }
        } except OSError { }
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
    } except OSError { }
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
    } except OSError { }
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
    } except OSError { }
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
        has_pages = jcc.rescan_pages();
        self.client_compiler._has_pages = has_pages;
        self.client_compiler.create_entry_file(self._entry_module_path());
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
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    sys.modules.pop(self.module_name, None);
    for key in list(Jac.program.mod.hub.keys()) {
        sys.modules.pop(self._path_to_module(key), None);
    }

    try {
        if file_path in Jac.program.mod.hub {
            del Jac.program.mod.hub[file_path];
        }

        resolved_path = str(Path(file_path).resolve());
        if resolved_path in Jac.program.mod.hub {
            del Jac.program.mod.hub[resolved_path];
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
        line_info = f":{e.lineno}" if e?.lineno and e.lineno else "";
        console.error(
            f"Syntax error in {file_path}{line_info}: {e?.msg or str(e)}",
            hint="Fix the error and save to retry"
        );
        self.record_error(file_path, f"Syntax error{line_info}: {e?.msg or str(e)}");
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
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.runtimelib.client_bundle { ClientBundleError }
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
                if key in program.mod.hub {
                    del program.mod.hub[key];
                }
            }
            program.errors_had.clear();
        }
        jcc = self.client_compiler.jac_client_compiler;
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
        self.record_error(file_path, errors);
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
    signal_file = self._error_file_path().parent / '.jac-force-reload';
    try {
        if signal_file.parent.is_dir() {
            signal_file.write_text(str(self._reload_nonce), encoding='utf-8');
        }
    } except OSError { }
}

impl HotReloader._recompile_client_code(
    file_path: str, visited: set | None = None, force: bool = True
) -> None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
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

        Jac.program.errors_had.clear();

        if source_key in Jac.program.mod.hub {
            del Jac.program.mod.hub[source_key];
        }

        mod = Jac.program.compile(source_key);

        if Jac.program.errors_had {
            if force {
                base_prefix = str(base_dir) + '/';
                errors = '\n'.join(
                    str(err).replace(base_prefix, '') for err in Jac.program.errors_had
                );
                console.error(f"Compile error in {file_path}:\n{errors}");
                self.record_error(file_path, errors);
            } else {
                console.warning(f"Errors compiling dependency {file_path}, skipping");
            }
            Jac.program.errors_had.clear();
            return;
        }

        js_code = mod.gen.js or '';
        if not js_code {
            if force {
                console.warning(f"No client JS generated for {file_path}");
            }
            return;
        }

        import from jaclang.runtimelib.client_surface { prepend_active_runtime_globals }
        js_code = prepend_active_runtime_globals(js_code);

        manifest = mod.gen.client_manifest if mod else None;
        if manifest and manifest.imports {
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

impl HotReloader._classify_declarations(file_path: str) -> tuple[bool, bool] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.unitree { ClientBlock, ServerBlock }
    has_client = False;
    has_server = False;
    try {
        prog = JacProgram();
        mod = prog.compile(file_path, no_cgen=True);

        for nd in mod.body {
            if isinstance(nd, ClientBlock) {
                has_client = True;
            } elif isinstance(nd, ServerBlock) {
                has_server = True;
            } elif nd?.code_context {
                if nd.code_context == CodeContext.CLIENT {
                    has_client = True;
                } else {
                    has_server = True;
                }
            }
        }

        if not has_client and not has_server {
            has_server = True;
        }
    } except SyntaxError as e {
        line_info = f" at line {e.lineno}" if e?.lineno and e.lineno else "";
        console.error(f"Syntax error in {file_path}{line_info}: {e?.msg or str(e)}");

        has_server = True;
    } except Exception as e {
        error_type = type(e).__name__;
        console.error(f"{error_type} in {file_path}: {e}");
        has_server = True;
    }
    return (has_client, has_server);
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
            rel_path = source_path.name;
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
        } except (FileNotFoundError, OSError) { }
        console.success(f"Copied: {rel_path}");
    } except Exception as e {
        console.error(f"Copy error in {file_path}: {e}");
        self.record_error(file_path, f"Copy error: {e}");
    }
}
