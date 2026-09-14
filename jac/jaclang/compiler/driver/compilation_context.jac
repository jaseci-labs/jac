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
import type from jaclang.compiler.native_compiler { NativeSyntax }
import from jaclang.compiler.passes.transform { Alert }

glob _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     ),
     _cache_context: ContextVar[str] = ContextVar('jac_compilation_cache', `default='');

@contextmanager
def cache_scope(
    identity: str, options: CompileOptions | None = None
) -> Iterator[None] {
    if options is not None and options.project_root {
        project_root = os.path.realpath(options.project_root);
        options = copy.copy(options);
        options.project_root = project_root;
    }
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

def codegen_source_path(path: str) -> str {
    options = _active_options.get();
    if not path or options is None or not options.source_prefix_map {
        return path;
    }
    resolved = os.path.realpath(path);
    mappings: list[tuple[str, str]] = sorted(
        [
            (os.path.realpath(directory), prefix)
            for (directory, prefix) in sorted(options.source_prefix_map.items())
        ],
        key=lambda (item: tuple[str, str]) { len(item[0]); },
        reverse=True
    );
    for (directory, prefix) in mappings {
        if resolved == directory {
            return prefix;
        }
        if resolved.startswith(directory.rstrip(os.sep) + os.sep) {
            relative = os.path.relpath(resolved, directory).replace(os.sep, "/");
            return prefix.rstrip("/") + "/" + relative;
        }
    }
    return path;
}

obj SourceUnit {
    has syntax: Module | NativeSyntax,
        failed: bool,
        errors: list[Alert],
        warnings: list[Alert];

    def close {
        if not isinstance(self.syntax, Module) {
            self.syntax.close();
        }
    }

    def materialize -> Module {
        if isinstance(self.syntax, Module) {
            return copy.deepcopy(self.syntax);
        }
        parsed = self.syntax.materialize();
        assert parsed is not None;
        return parsed[0];
    }
}

obj SourceStore {
    has units: dict[str, SourceUnit] = {},
        revisions: dict[str, str] = {},
        parses: int = 0,
        hits: int = 0;

    def clear {
        for unit in self.units.values() {
            unit.close();
        }
        self.units.clear();
        self.revisions.clear();
    }

    def parse(
        source: str, path: str, program: JacProgram, annexes: list[tuple[str, str]]
    ) -> tuple[Module, bool] {
        import from jaclang.compiler.frontend.parser.frontend { parse_woven_snapshot }
        import from jaclang.compiler.driver.program { JacProgram }
        key = hashlib.sha256(repr((path, source, annexes)).encode()).hexdigest();
        unit = self.units.get(key);
        fresh: Module | None = None;
        if unit is None {
            diagnostics = JacProgram();
            (syntax, failed, snapshot) = parse_woven_snapshot(
                source, path, diagnostics, annexes
            );
            if snapshot is not None {
                fresh = syntax;
            }
            unit = SourceUnit(
                snapshot if snapshot is not None else syntax,
                failed,
                list(diagnostics.errors_had),
                list(diagnostics.warnings_had)
            );
            previous = self.revisions.get(path);
            if previous is not None {
                replaced = self.units.pop(previous, None);
                if replaced is not None {
                    replaced.close();
                }
            }
            self.revisions[path] = key;
            self.units[key] = unit;
            self.parses += 1;
        } else {
            self.hits += 1;
        }
        syntax = fresh if fresh is not None else unit.materialize();
        program.diags.extend(unit.errors, unit.warnings);
        return (syntax, unit.failed);
    }
}

def bind_options(
    path: str, program: JacProgram, options: CompileOptions
) -> CompileOptions {
    import from jaclang.project.workspace { workspace_for_path }
    bound = copy.copy(options);
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
                options.project_root
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
    program._get_compiler();
    return context_program(program, bind_options(path, program, program.options));
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
    identity = selected.context_key;
    with cache_scope(identity, selected.options) {
        return get_module_cache_path(path);
    }
}
