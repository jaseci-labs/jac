import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
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

glob _active_program: ContextVar[JacProgram | None] = ContextVar(
         'jac_active_program', `default=None
     ),
     _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     ),
     _cache_context: ContextVar[str] = ContextVar('jac_compilation_cache', `default='');

def active_program -> JacProgram | None {
    return _active_program.get();
}

@contextmanager
def program_scope(program: JacProgram | None) -> Iterator[None] {
    token = _active_program.set(program or _active_program.get());
    try {
        yield ;
    } finally {
        _active_program.reset(token);
    }
}

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
    identity: str,
    options: CompileOptions | None = None,
    program: JacProgram | None = None
) -> Iterator[None] {
    import from jaclang.project.workspace { workspace_scope }
    with program_scope(program), cache_scope(identity, options), workspace_scope() {
        yield ;
    }
}

def cache_identity -> str {
    return _cache_context.get();
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
    new_entry = bool(options.entry_point);
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
    product: CompilationProduct = CompilationProduct.ANALYSIS,
    cancel_token: Event | None = None,
) -> list[CompileOptions] {
    import from jaclang.project.workspace { workspace_for_path }
    workspace = workspace_for_path(path);
    declared = workspace.app_for_path(path) if workspace is not None else None;
    apps = [declared]
        if workspace is None or declared is not None
        else list(workspace.apps.values()) or [None];
    return [
        bind_options(
            path,
            program,
            CompileOptions(
                no_cgen=True,
                symtab_ir_only=product == CompilationProduct.SYMBOLS,
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
