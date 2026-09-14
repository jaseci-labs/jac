import copy;
import from pathlib { Path }
import from threading { Event }
import type from jaclang.project.workspace { AppSpec }
import hashlib;
import os;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.progstate { DepGraph }

obj CompilationContext {
    has deps: DepGraph,
        program: JacProgram | None = None;
}

obj AnalysisCacheBudget {
    has max_contexts: int = 8,
        max_nodes: int = 100000;
}

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

def source_bytes(path: str) -> bytes | None {
    try {
        return Path(path).read_bytes();
    } except OSError {
        return None;
    }
}

def content_digest(data: bytes | None) -> str | None {
    return hashlib.sha256(data).hexdigest() if data is not None else None;
}

obj InputManifest {
    has files: dict[str, str | None],
        annexes: dict[str, list[str]];

    def is_current(store: SourceStore | None = None) -> bool {
        for (path, digest) in self.files.items() {
            snapshot = store.snapshot if store is not None else None;
            actual = snapshot.digest(path)
                if snapshot is not None
                else content_digest(
                    store.overrides[path].encode('utf-8')
                        if store is not None and path in store.overrides
                        else source_bytes(path)
                );
            if actual != digest {
                return False;
            }
        }
        discovery = store if store is not None else SourceStore();
        for (path, paths) in self.annexes.items() {
            actual_paths = discovery.discover_annex_paths(path);
            if discovery.snapshot is not None {
                actual_paths = discovery.snapshot.annex_paths.setdefault(
                    path, actual_paths
                );
            }
            if actual_paths != paths {
                return False;
            }
        }
        return True;
    }

    def to_dict -> dict {
        return {'files': self.files, 'annexes': self.annexes};
    }

    static def from_dict(data: dict) -> InputManifest {
        return InputManifest(
            {
                str(path): str(value) if value is not None else None
                for (path, value) in data['files'].items()
            },
            {
                str(path): [str(item) for item in paths]
                for (path, paths) in data['annexes'].items()
            }
        );
    }
}

obj SourceSnapshot {
    has overrides: dict[str, str],
        files: dict[str, str] = {},
        disk: dict[str, bytes | None] = {},
        annex_paths: dict[str, list[str]] = {},
        modules: set[str] = set(),
        read_paths: set[str] = set(),
        digests: dict[str, str | None] = {};

    def digest(path: str) -> str | None {
        self.read_paths.add(path);
        if path not in self.digests {
            if path not in self.overrides {
                self.watch(path);
            }
            self.digests[path] = content_digest(
                self.overrides[path].encode('utf-8')
                    if path in self.overrides
                    else self.disk[path]
            );
        }
        return self.digests[path];
    }

    def manifest -> InputManifest {
        paths = self.disk.keys() | self.modules | self.read_paths;
        return InputManifest(
            {
                path: content_digest(
                    self.overrides[path].encode('utf-8')
                        if path in self.overrides
                        else self.disk.get(path)
                ) for path in paths
            },
            {path: list(paths) for (path, paths) in self.annex_paths.items()}
        );
    }

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
        self.read_paths.add(path);
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
    has overrides: dict[str, str] = {},
        parses: int = 0,
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

    def clear {
        self.overrides.clear();
    }

    def parse(
        source: str, path: str, program: JacProgram, annexes: list[tuple[str, str]]
    ) -> tuple[Module, bool] {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven }

        self.parses += 1;
        return parse_woven(source, os.path.realpath(path), program, annexes);
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

def analysis_options(
    path: str,
    program: JacProgram,
    symbols_only: bool = False,
    cancel_token: Event | None = None,
    shared_app_limit: int = 4
) -> list[CompileOptions] {
    import from jaclang.project.workspace { workspace_for_path }
    workspace = workspace_for_path(path);
    declared = workspace.app_for_path(path) if workspace is not None else None;
    apps = [declared]
        if workspace is None or declared is not None
        else list(workspace.apps.values())[:shared_app_limit];
    return [
        bind_options(
            path,
            program,
            CompileOptions(
                no_cgen=True,
                symtab_ir_only=symbols_only,
                need_full_ast=True,
                force_target_program=True,
                cancel_token=cancel_token,
                target_app=app.name if app is not None else '',
                app_kind=app.kind if app is not None else '',
                ui=app.ui if app is not None else '',
                entry_point=app.`entry if app is not None else path,
                project_root=workspace.project_root if workspace is not None else None
            )
        ) for app in apps
    ];
}

def context_program(program: JacProgram, options: CompileOptions) -> JacProgram {
    import from jaclang.compiler.driver.program { JacProgram }
    context_root = program.context_root
        if program.context_root is not None
        else program;
    identity = context_identity(options);
    existing = context_root.contexts.get(identity);
    if existing is not None and existing.program is not None {
        del context_root.contexts[identity];
        context_root.contexts[identity] = existing;
        return existing.program;
    }
    if identity == program.context_key {
        selected = program;
    } elif not context_root.context_key {
        selected = context_root;
    } else {
        selected = JacProgram();
        selected.context_root = context_root;
        selected._compiler = context_root._get_compiler();
        selected.source_store = context_root.source_store;
        selected.deps.tracking = context_root.deps.tracking;
        selected.options = options;
    }
    if existing is not None {
        selected.deps = existing.deps;
    }
    selected.options = options;
    selected.context_key = identity;
    context_root.contexts[identity] = CompilationContext(selected.deps, selected);
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
