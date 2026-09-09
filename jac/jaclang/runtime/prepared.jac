"""Executable application revisions. This module must not import the compiler.

Preparation publishes a complete revision before module initialization begins.
The import hook and serving layer only read the published artifacts.
"""
import os;
import types;
import from jaclang.runtime.object_model { field }

obj PreparedApplication {
    has `root: str,
        `entry: str,
        code: dict[str, types.CodeType] = field(default_factory=`dict),
        manifests: dict[str, dict] = field(default_factory=`dict),
        client_compiler: any = None,
        client_enabled: bool = False,
        native: dict[str, tuple] = field(default_factory=`dict),
        services: tuple = (),
        dev: bool = True,
        client_dist: str = "";
}

glob _applications: dict[str, PreparedApplication] = {};

def publish(application: PreparedApplication) -> None {
    _applications[os.path.realpath(application.entry)] = application;
}

def application_for(path: str) -> (PreparedApplication | None) {
    resolved = os.path.realpath(path);
    for application in reversed(`list(_applications.values())) {
        if ((resolved in application.code) or (resolved in application.manifests)) {
            return application;
        }
    }
    return None;
}

def prepared_code(path: str) -> (types.CodeType | None) {
    application = application_for(path);
    return application.code.get(os.path.realpath(path)) if application else None;
}

def prepared_manifest(path: str) -> (dict | None) {
    application = application_for(path);
    return application.manifests.get(os.path.realpath(path)) if application else None;
}

def forget(`entry: str) -> None {
    _applications.pop(os.path.realpath(`entry), None);
}

def containing_application(path: str) -> (PreparedApplication | None) {
    resolved = os.path.realpath(path);
    candidates = [
        a
        for a in _applications.values()
        if resolved.startswith((a.root + os.sep))
    ];
    return max(candidates, key=lambda (a: any) { len(a.root); }, `default=None);
}

def load_prepared_module(path: str) -> types.ModuleType {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.ext_registry { base_stem }
    path = os.path.realpath(path);
    if (prepared_code(path) is None) {
        raise RuntimeError(f'No prepared executable artifact for {path}');
    }
    application = application_for(path);
    base = os.path.dirname(path);
    target = base_stem(path);
    if application is not None and path != application.entry {
        relative_dir = os.path.relpath(base, application.root);
        if relative_dir != '.' {
            target = relative_dir.replace(os.sep, '.') + '.' + target;
        }
        base = application.root;
    }
    modules = Jac.jac_import(target=target, base_path=base, lng='jac');
    if not modules {
        raise RuntimeError(f'Prepared module did not initialize: {path}');
    }
    return modules[0];
}

def initialize_application(
    application: PreparedApplication, config: any = None, served: any = None
) -> types.ModuleType {
    module = load_prepared_module(application.entry);
    if ((config is not None) and (served is not None)) {
        import from jaclang.server.assembly { assemble_served_program }
        assemble_served_program(config, served, application.root);
    }
    return module;
}

def clear() -> None {
    _applications.clear();
}
