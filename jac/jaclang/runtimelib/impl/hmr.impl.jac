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
    with HotReloader._build_lock {
        error = {"file": self._build_error_file, "message": self._build_error}
            if self._build_status is BuildStatus.ERROR
            else None;
        return {"status": self._build_status.value, "error": error};
    }
}

impl HotReloader.record_ok -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.OK;
        self._build_error_file = "";
        self._build_error = "";
    }
}

impl HotReloader.record_error(file_path: str, message: str) -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.ERROR;
        self._build_error_file = file_path;
        self._build_error = message;
    }
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

    self._process_change(event.path);
}

impl HotReloader._process_change(file_path: str) -> None {
    with HotReloader._build_lock {
        self._build_status = BuildStatus.COMPILING;
    }
    try {
        self._dispatch_change(file_path);
    } except Exception as e {
        self.record_error(file_path, f"{type(e).__name__}: {e}");
        raise;
    }

    if self._build_status is BuildStatus.COMPILING {
        self.record_ok();
    }
}

impl HotReloader._dispatch_change(file_path: str) -> None {
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

    (has_client, has_server) = self._classify_declarations(target_path);

    if has_server {
        self._reload_server_module(target_path);
    }

    if has_client {
        visited: set = set();
        self._recompile_client_code(target_path, visited);
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

        if self._overlay_entry {
            self._update_entry_point();
        }
    } except SyntaxError as e {
        line_info = f":{e.lineno}" if e?.lineno and e.lineno else "";
        console.error(
            f"Syntax error in {file_path}{line_info}: {e?.msg or str(e)}",
            hint="Fix the error and save to retry"
        );
        self.record_error(file_path, f"Syntax error{line_info}: {e?.msg or str(e)}");
    } except ImportError as e {
        console.error(f"Import error in {file_path}: {e}");
        self._emit_client_error_overlay(file_path, str(e));
        self.record_error(file_path, f"Import error: {e}");
    } except Exception as e {
        error_type = type(e).__name__;
        console.error(f"{error_type} in {file_path}: {e}");
        self._emit_client_error_overlay(file_path, str(e));
        self.record_error(file_path, f"{error_type}: {e}");
    }
}

impl HotReloader._recompile_client_code(
    file_path: str, visited: set | None = None, force: bool = True
) -> None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
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
                self._emit_client_error_overlay(file_path, errors);
                self.record_error(file_path, errors);
            } else {
                console.warning(f"Errors compiling dependency {file_path}, skipping");
            }
            Jac.program.errors_had.clear();
            return;
        }

        if force and self._overlay_entry {
            self._update_entry_point();
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

impl HotReloader._emit_client_error_overlay(file_path: str, errors: str) -> None {
    import from jaclang.runtimelib.react_entry { build_web_error_overlay_entry_script }
    output_base = Path(self.base_path) / self._client_output_dir;
    output_dir = output_base;
    output_dir.mkdir(parents=True, exist_ok=True);
    js_filename = "_entry.js";
    output_path = output_dir / js_filename;
    entry_content = build_web_error_overlay_entry_script(file_path, errors);

    output_path.write_text(entry_content, encoding='utf-8');

    self._overlay_entry = True;
    return;
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
            self._emit_client_error_overlay(file_path, f"No module in {rel_path}");
            self.record_error(file_path, f"No module in {rel_path}");
            return;
        }
        try {
            if self._overlay_entry {
                self._update_entry_point();
            }
            output_path.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(source_path, output_path);
        } except (FileNotFoundError, OSError) { }
        console.success(f"Copied: {rel_path}");
    } except Exception as e {
        console.error(f"Copy error in {file_path}: {e}");
        self.record_error(file_path, f"Copy error: {e}");
    }
}

impl HotReloader._update_entry_point -> None {
    import from jaclang.compiler.passes.ecmascript.backends.registry {
        resolve_active_backend
    }
    backend = resolve_active_backend();
    output_base = Path(self.base_path) / self._client_output_dir;
    output_base.mkdir(parents=True, exist_ok=True);
    output_path = output_base / "_entry.js";

    entry_content = backend.build_entry_script(
        self.module_name, install_global_handlers=False
    );
    output_path.write_text(entry_content, encoding='utf-8');
    self._overlay_entry = False;
}
