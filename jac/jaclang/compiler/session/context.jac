import type from jaclang.compiler.session.services { AnalysisServices }
import type from jaclang.compiler.analysis.placement.products { NativeEligibility }
import copy;
import from pathlib { Path }
import type from jaclang.compiler.session.workspace { AppSpec }
import hashlib;
import os;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from collections.abc { Iterator }
import from jaclang.compiler.session.options { CompileOptions }
import type from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.pass_base { Alert }

glob _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     ),
     _cache_context: ContextVar[str] = ContextVar('jac_compilation_cache', `default=''),
     _active_program: ContextVar[AnalysisServices | None] = ContextVar(
         'jac_active_program', `default=None
     );

@contextmanager
def cache_scope(
    identity: str,
    options: CompileOptions | None = None,
    program: AnalysisServices | None = None
) -> Iterator[None] {
    token = _cache_context.set(identity);
    option_token = _active_options.set(options);
    program_token = _active_program.set(program or _active_program.get());
    try {
        if program is not None {
            import from jaclang.compiler.backends.common.artifact_store {
                artifact_scope
            }
            with artifact_scope(program.analysis.artifacts) {
                yield ;
            }
        } else {
            yield ;
        }
    } finally {
        _cache_context.reset(token);
        _active_options.reset(option_token);
        _active_program.reset(program_token);
    }
}

def active_program -> AnalysisServices | None {
    return _active_program.get();
}


@contextmanager
def compilation_scope(
    identity: str,
    options: CompileOptions | None = None,
    program: AnalysisServices | None = None
) -> Iterator[None] {
    import from jaclang.compiler.session.workspace { workspace_scope }
    with cache_scope(identity, options, program), workspace_scope() {
        yield ;
    }
}

def cache_identity -> str {
    return _cache_context.get();
}

def bind_options(
    path: str, program: JacProgram, options: CompileOptions, select_app: bool = True
) -> CompileOptions {
    import from jaclang.compiler.session.workspace { workspace_for_path }
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
    if not select_app {
        return bound;
    }
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
    import from jaclang.compiler.session.target_options { effective_default_codespace }
    return hashlib.sha256(
        repr(
            (
                options.analysis_identity(),
                options.codegen_identity(),
                options.aot_mode,
                options.force_codespace,
                options.default_codespace or effective_default_codespace(),
                options.ui,
                options.project_root,
                options.entry_point
            )
        ).encode()
    ).hexdigest()[:20];
}

def context_program(program: JacProgram, options: CompileOptions) -> JacProgram {
    import from jaclang.compiler.session.session { JacProgram }
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
        selected.deps.tracking = context_root.deps.tracking;
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
    import from jaclang.compiler.session.workspace { workspace_for_path }
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
    import from jaclang.compiler.session.cache.artifact_codec { get_module_cache_path }
    selected = program_for(path, program);
    identity = ''
        if selected._get_compiler().selfhost.is_selfhost(selected)
        else selected.context_key;
    with cache_scope(identity, selected.options, selected) {
        return get_module_cache_path(path);
    }
}
