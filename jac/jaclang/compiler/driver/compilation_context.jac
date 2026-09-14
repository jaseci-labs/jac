import copy;
import from pathlib { Path }
import type from jaclang.project.workspace { AppSpec }
import hashlib;
import os;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.transform { Alert }

glob _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     ),
     _cache_context: ContextVar[str] = ContextVar('jac_compilation_cache', `default='');

@contextmanager
def cache_scope(
    identity: str, options: CompileOptions | None = None
) -> Iterator[None] {
    token = _cache_context.set(identity);
    option_token = _active_options.set(options);
    try {
        yield ;
    } finally {
        _cache_context.reset(token);
        _active_options.reset(option_token);
    }
}

@contextmanager
def compilation_scope(
    identity: str, options: CompileOptions | None = None
) -> Iterator[None] {
    import from jaclang.project.workspace { workspace_scope }
    with cache_scope(identity, options), workspace_scope() {
        yield ;
    }
}

def cache_identity -> str {
    return _cache_context.get();
}

obj SourceUnit {
    has path: str,
        syntax: Module,
        failed: bool,
        errors: list[Alert],
        warnings: list[Alert],
        nodes: int;
}

def source_bytes(path: str) -> bytes | None {
    try {
        return Path(path).read_bytes();
    } except OSError {
        return None;
    }
}

obj SourceSnapshot {
    has overrides: dict[str, str],
        files: dict[str, str] = {},
        disk: dict[str, bytes | None] = {},
        annex_paths: dict[str, list[str]] = {},
        modules: set[str] = set();

    def watch(path: str) {
        if path not in self.disk {
            self.disk[path] = source_bytes(path);
        }
    }

    def watch_configuration(path: str) {
        for directory in Path(path).parents {
            for name in ('jac.toml', 'jac.lock', '.env') {
                self.watch(str(directory / name));
            }
        }
    }

    def read(path: str) -> str {
        import from jaclang.project.source { decode_source }
        path = os.path.realpath(path);
        if path in self.overrides {
            return self.overrides[path];
        }
        if path not in self.files {
            self.watch(path);
            data = self.disk[path];
            if data is None {
                raise OSError(f"Could not read file {path}");
            }
            self.files[path] = decode_source(data, path);
        }
        return self.files[path];
    }

    def is_current(store: SourceStore) -> bool {
        return self.overrides == store.overrides
            and all(source_bytes(path) == data for (path, data) in self.disk.items())
            and all(
                store.discover_annex_paths(path) == paths
                for (path, paths) in self.annex_paths.items()
            );
    }
}

obj SourceStore {
    has units: dict[str, SourceUnit] = {},
        revisions: dict[str, str] = {},
        overrides: dict[str, str] = {},
        max_units: int = 64,
        max_nodes: int = 100000,
        cached_nodes: int = 0,
        evictions: int = 0,
        parses: int = 0,
        hits: int = 0,
        snapshot: SourceSnapshot | None = None;

    @contextmanager
    def capture -> Iterator[SourceSnapshot] {
        import from jaclang.project.source { source_scope }
        if self.snapshot is not None {
            yield self.snapshot;
            return;
        }
        captured = SourceSnapshot(dict(self.overrides));
        self.snapshot = captured;
        try {
            with source_scope(captured.read) {
                yield captured;
            }
        } finally {
            self.snapshot = None;
        }
    }

    def record_module(path: str) {
        if self.snapshot is not None {
            path = os.path.realpath(path);
            self.snapshot.modules.add(path);
            self.snapshot.watch_configuration(path);
            if path not in self.snapshot.overrides {
                self.snapshot.watch(path);
            }
        }
    }

    def read(path: str) -> str {
        import from jaclang.project.source { read_file_with_encoding }
        if self.snapshot is not None {
            return self.snapshot.read(path);
        }
        source = self.overrides.get(os.path.realpath(path));
        return source if source is not None else read_file_with_encoding(path);
    }

    def discover_annex_paths(path: str) -> list[str] {
        import from jaclang.compiler.driver.bccache {
            discover_annex_files,
            discover_base_file
        }
        path = os.path.realpath(path);
        if not path.endswith('.jac') or discover_base_file(path) is not None {
            return [];
        }
        paths = set(discover_annex_files(path, '.impl.jac'));
        paths.update(discover_annex_files(path, '.test.jac'));
        paths.update(
            candidate
            for candidate in self.overrides
            if discover_base_file(candidate) == path
        );
        return sorted(paths);
    }

    def annexes(path: str) -> list[tuple[str, str]] {
        path = os.path.realpath(path);
        snapshot = self.snapshot;
        if snapshot is None {
            paths = self.discover_annex_paths(path);
        } else {
            if path not in snapshot.annex_paths {
                snapshot.annex_paths[path] = self.discover_annex_paths(path);
            }
            paths = snapshot.annex_paths[path];
        }
        return [(self.read(candidate), candidate) for candidate in paths];
    }

    def set_overrides(sources: dict[str, str]) -> set[str] {
        current = {
            os.path.realpath(path): source for (path, source) in sources.items()
        };
        changed = {
            path
            for path in self.overrides.keys() | current.keys()
            if self.overrides.get(path) != current.get(path)
        };
        self.overrides = current;
        return changed;
    }

    def fingerprint(path: str) -> str {
        try {
            inputs = (os.path.realpath(path), self.read(path), self.annexes(path));
            return hashlib.sha256(repr(inputs).encode()).hexdigest();
        } except OSError {
            return '';
        }
    }

    def forget(path: str) {
        previous = self.revisions.pop(os.path.realpath(path), None);
        if previous is not None {
            self.discard(previous);
        }
    }

    def discard(key: str) {
        previous = self.units.pop(key, None);
        if previous is not None {
            self.cached_nodes -= previous.nodes;
            if self.revisions.get(previous.path) == key {
                self.revisions.pop(previous.path, None);
            }
        }
    }

    def clear {
        self.units.clear();
        self.revisions.clear();
        self.overrides.clear();
        self.cached_nodes = 0;
    }

    def parse(
        source: str, path: str, program: JacProgram, annexes: list[tuple[str, str]]
    ) -> tuple[Module, bool] {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven }
        import from jaclang.compiler.driver.program { JacProgram }
        path = os.path.realpath(path);
        key = hashlib.sha256(repr((path, source, annexes)).encode()).hexdigest();
        unit = self.units.get(key);
        if unit is None {
            diagnostics = JacProgram();
            (syntax, failed) = parse_woven(source, path, diagnostics, annexes);
            unit = SourceUnit(
                path,
                syntax,
                failed,
                list(diagnostics.errors_had),
                list(diagnostics.warnings_had),
                len(syntax._in_mod_nodes)
            );
            previous = self.revisions.get(path);
            if previous is not None {
                self.discard(previous);
            }
            if self.max_units > 0 and unit.nodes <= self.max_nodes {
                while self.units
                    and (
                        len(self.units) >= self.max_units
                        or self.cached_nodes + unit.nodes > self.max_nodes
                    ) {
                    self.discard(next(iter(self.units)));
                    self.evictions += 1;
                }
                self.revisions[path] = key;
                self.units[key] = unit;
                self.cached_nodes += unit.nodes;
            }
            self.parses += 1;
        } else {
            del self.units[key];
            self.units[key] = unit;
            self.hits += 1;
        }
        syntax = copy.deepcopy(unit.syntax);
        assert isinstance(syntax, Module);
        program.errors_had.extend(unit.errors);
        program.warnings_had.extend(unit.warnings);
        return (syntax, unit.failed);
    }
}

def bind_options(
    path: str, program: JacProgram, options: CompileOptions
) -> CompileOptions {
    import from jaclang.project.workspace { workspace_for_path }
    bound = copy.copy(options);
    if bound.native_required_for(path) {
        bound.default_codespace = 'native';
        bound.force_codespace = 'native';
    }
    new_entry = bool(
        options.entry_point and options.entry_point != program.options.entry_point
    );
    if not new_entry and not (bound.nogc_enforce_all or bound.memory_enforce) {
        bound.nogc_enforce_all = program.options.nogc_enforce_all;
        bound.memory_enforce = list(program.options.memory_enforce or []);
        bound.memory_exempt = list(program.options.memory_exempt or []);
    }
    if not new_entry and not bound.default_codespace {
        bound.default_codespace = program.options.default_codespace;
    }
    if not new_entry and not bound.force_codespace {
        bound.force_codespace = program.options.force_codespace;
    }
    if not new_entry and not bound.project_root {
        bound.project_root = program.options.project_root;
    }
    if not new_entry {
        bound.target_app = bound.target_app or program.options.target_app;
        bound.app_kind = bound.app_kind or program.options.app_kind;
        bound.ui = bound.ui or program.options.ui;
    }
    bound.entry_point = bound.entry_point
        or program.options.entry_point
        or os.path.realpath(path);
    workspace = workspace_for_path(path);
    if workspace is None {
        return bound;
    }
    declared = workspace.app_for_path(path);
    if declared is None and not workspace.explicit and not bound.target_app {
        implicit = next(iter(workspace.apps.values()), None);
        if implicit is not None {
            bound.target_app = implicit.name;
            bound.app_kind = implicit.kind;
            bound.ui = bound.ui or implicit.ui;
            bound.project_root = bound.project_root or workspace.project_root;
        }
    }
    if declared is not None {
        bound.target_app = declared.name;
        bound.app_kind = declared.kind;
        bound.ui = (options.ui or declared.ui)
            if not options.target_app or options.target_app == declared.name
            else declared.ui;
        bound.project_root = workspace.project_root;
        bound.entry_point = declared.`entry;
    }
    return bound;
}

def context_identity(options: CompileOptions) -> str {
    return hashlib.sha256(
        repr(
            (
                options.analysis_identity(),
                options.codegen_identity(),
                options.aot_mode,
                options.force_codespace,
                options.default_codespace,
                options.ui,
                options.project_root,
                options.entry_point
            )
        ).encode()
    ).hexdigest()[:20];
}

def context_program(program: JacProgram, options: CompileOptions) -> JacProgram {
    import from jaclang.compiler.driver.program { JacProgram }
    context_root = program.context_root
        if program.context_root is not None
        else program;
    identity = context_identity(options);
    if identity == program.context_key {
        return program;
    }
    existing = context_root.contexts.get(identity);
    if existing is not None {
        return existing;
    }
    if not context_root.context_key {
        selected = context_root;
    } else {
        selected = JacProgram();
        selected.context_root = context_root;
        selected._compiler = context_root._get_compiler();
        selected.source_store = context_root.source_store;
        selected.options = options;
    }
    selected.options = options;
    selected.context_key = identity;
    context_root.contexts[identity] = selected;
    return selected;
}

def program_for(path: str, program: JacProgram) -> JacProgram {
    compiler = program._get_compiler();
    actual = compiler.selfhost.resolve(path, program);
    if compiler.selfhost.is_selfhost(actual) {
        return actual;
    }
    return context_program(actual, bind_options(path, actual, actual.options));
}

def context_app(path: str) -> AppSpec | None {
    import from jaclang.project.workspace { workspace_for_path }
    workspace = workspace_for_path(path);
    if workspace is None {
        return None;
    }
    declared = workspace.app_for_path(path);
    if declared is not None {
        return declared;
    }
    options = _active_options.get();
    if options is not None and options.project_root == workspace.project_root {
        return workspace.apps.get(options.target_app);
    }
    return None;
}

def artifact_cache_path(path: str, program: JacProgram) -> Path {
    import from jaclang.compiler.driver.jir { get_module_cache_path }
    selected = program_for(path, program);
    identity = ''
        if selected._get_compiler().selfhost.is_selfhost(selected)
        else selected.context_key;
    with cache_scope(identity, selected.options) {
        return get_module_cache_path(path);
    }
}
