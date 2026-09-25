import copy;
import from jaclang.project.workspace_model { AppSpec }
import hashlib;
import os;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from collections.abc { Iterator }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo { is_package_keyed_path }
import type from jaclang.compiler.driver.program { JacProgram }

glob _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     );

@contextmanager
def cache_scope(options: CompileOptions | None = None) -> Iterator[None] {
    token = _active_options.set(options);
    try {
        yield ;
    } finally {
        _active_options.reset(token);
    }
}

@contextmanager
def compilation_scope(options: CompileOptions | None = None) -> Iterator[None] {
    import from jaclang.compiler.frontend.host { active_host }
    with cache_scope(options), active_host().session() {
        yield ;
    }
}

def active_options -> CompileOptions | None {
    return _active_options.get();
}

def owned_module_options(path: str, options: CompileOptions) -> CompileOptions {
    """A module the running compiler package owns is analyzed the way the
    package analyzes itself, whoever imports it. The consumer's application,
    codespace and entry are dropped: its placement default would otherwise
    be inferred over the runtime, its codespace flags would refuse the
    module's cached interface, and every consumer would key its own analysis
    of the same module. The consumer's memory model, target and placement
    policy stay, since they shape the native products the module can offer
    it.""";
    bound = copy.copy(options);
    bound.package_canonical = True;
    bound.default_codespace = '';
    bound.force_codespace = '';
    bound.target_app = '';
    bound.app_kind = '';
    bound.ui = '';
    bound.project_root = None;
    bound.entry_point = os.path.realpath(path);
    if bound.native_required_for(path) {
        bound.default_codespace = 'native';
        bound.force_codespace = 'native';
    }
    return bound;
}

def owner_scope_options(
    program: JacProgram, options: (CompileOptions | None) = None
) -> (CompileOptions | None) {
    """The options a cache scope projects: none for the compiler's own program
    and for a package module's canonical analysis, which then key their
    entries the way the package's precompile does, and the program's
    otherwise.""";
    chosen = options if options is not None else program.options;
    if program.internal or chosen.package_canonical {
        return None;
    }
    return chosen;
}

def package_owned(path: str, program: JacProgram, options: CompileOptions) -> bool {
    return is_package_keyed_path(path)
        and not (
            options.native_unit
            or options.aot_mode
            or program.options.native_unit
            or program.options.aot_mode
        );
}

def bind_options(
    path: str, program: JacProgram, options: CompileOptions
) -> CompileOptions {
    import from jaclang.compiler.frontend.host { active_host }
    if package_owned(path, program, options) {
        return owned_module_options(path, options);
    }
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
    workspace = active_host().workspace(path);
    if workspace is None {
        return bound;
    }
    declared = active_host().app_for_path(path);
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
    return hashlib.sha256(options.module_projection().encode()).hexdigest()[:20];
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
        import from jaclang.compiler.frontend.host { active_host }
        selected = JacProgram();
        selected.context_root = context_root;
        selected.options = options;
        active_host().bind_context_program(context_root, selected);
    }
    selected.options = options;
    selected.context_key = identity;
    context_root.contexts[identity] = selected;
    return selected;
}

def program_for(path: str, program: JacProgram) -> JacProgram {
    if program.internal {
        return program;
    }
    return context_program(program, bind_options(path, program, program.options));
}

def context_app(path: str) -> AppSpec | None {
    import from jaclang.compiler.frontend.host { active_host }
    workspace = active_host().workspace(path);
    if workspace is None {
        return None;
    }
    declared = active_host().app_for_path(path);
    if declared is not None {
        return declared;
    }
    options = _active_options.get();
    if options is not None and options.project_root == workspace.project_root {
        return workspace.apps.get(options.target_app);
    }
    return None;
}
