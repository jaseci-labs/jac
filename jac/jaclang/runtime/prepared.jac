import hashlib;
import os;
import types;
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.runtime.object_model { field }
import type from jaclang.runtime.semantic { Info }
import type from jaclang.client.compiler { ViteCompiler }

obj PreparedApplication {
    has `root: str,
        `entry: str,
        code: dict[str, types.CodeType] = field(default_factory=`dict),
        manifests: dict[str, dict] = field(default_factory=`dict),
        semantic: dict[str, dict[str, Info]] = field(default_factory=`dict),
        origins: dict[str, str] = field(default_factory=`dict),
        name: str = '',
        namespace: str = '',
        scope_imports: bool = True,
        client_compiler: ViteCompiler | None = None,
        client_enabled: bool = False,
        native: dict[str, tuple] = field(default_factory=`dict),
        services: tuple = (),
        dev: bool = True,
        client_dist: str = "",
        applications: list[PreparedApplication] = field(default_factory=list);
}

glob _applications: dict[str, PreparedApplication] = {};

def publish(application: PreparedApplication) {
    import sys;
    import from jaclang.runtime.prepared_loader { PreparedFinder }
    if not any(isinstance(finder, PreparedFinder) for finder in sys.meta_path) {
        sys.meta_path.insert(0, PreparedFinder());
    }
    _applications[os.path.realpath(application.entry)] = application;
    for child in application.applications {
        _applications[os.path.realpath(child.entry)] = child;
    }
}

def application_for(path: str, module_name: str = "") -> (PreparedApplication | None) {
    resolved = os.path.realpath(path);
    for application in _applications.values() {
        if (
            module_name == application_namespace(application)
            or module_name.startswith(application_namespace(application) + '.')
        )
            and (resolved in application.code or resolved in application.manifests) {
            return application;
        }
    }
    exact = _applications.get(resolved);
    if exact is not None {
        return exact;
    }
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

def forget(`entry: str) {
    previous = _applications.pop(os.path.realpath(`entry), None);
    if previous is not None {
        for child in previous.applications {
            _applications.pop(os.path.realpath(child.entry), None);
        }
    }
}

def containing_application(
    path: str, module_name: str = ""
) -> (PreparedApplication | None) {
    resolved = os.path.realpath(path);
    for application in _applications.values() {
        if module_name.startswith(application_namespace(application) + '.') {
            if resolved.startswith(application.root + os.sep) {
                return application;
            }
        }
    }
    candidates = [
        a
        for a in _applications.values()
        if resolved.startswith((a.root + os.sep))
            and not any(
                part.startswith('.') or part in ('node_modules', 'venv', '__pycache__')
                for part in os.path.relpath(resolved, a.root).split(os.sep)
            )
    ];
    return max(candidates, key=lambda (a: any) { len(a.root); }, `default=None);
}

def load_prepared_module(path: str) -> types.ModuleType {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.sealed { image_for_bundle_dir }
    import from pathlib { Path }
    import sys;
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
    if application is not None {
        image = image_for_bundle_dir(Path(application.root) / '_precompiled');
        if image is None {
            return import_prepared(path, application);
        }
        if image is not None {
            relative = Path(path).relative_to(application.root).as_posix();
            target = image.manifest['modules'][relative]['module'];
            package = image.package;
            loaded = sys.modules.get(package);
            if loaded is not None
                and application.root not in getattr(loaded, '__path__', ())
                and not str(getattr(loaded, '__file__', '') or '').startswith(
                    application.root + os.sep
                ) {
                namespace = '_jac_app_'
                    + hashlib.sha256(application.root.encode()).hexdigest()[:16];
                for (source, info) in image.manifest['modules'].items() {
                    name = namespace + info['module'][len(package):];
                    image.index[name] = (info, source);
                }
                ensure_namespace(application, namespace);
                target = namespace + target[len(package):];
            } elif package not in image.index {
                ensure_namespace(application, package);
            }
        }
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
        assemble_served_program(config, served, application.root, application);
    }
    return module;
}

def clear {
    _applications.clear();
}


def application_namespace(application: PreparedApplication) -> str {
    if application.namespace {
        return application.namespace;
    }
    return '_jac_app_' + hashlib.sha256(application.entry.encode()).hexdigest()[:16];
}

def ensure_namespace(application: PreparedApplication, name: str = '') -> str {
    import sys;
    import importlib.machinery;
    import importlib.util;
    name = name or application_namespace(application);
    if name not in sys.modules {
        initializer = next(
            (
                p
                for p in application.code
                if os.path.dirname(p) == application.root
                    and os.path.basename(p).startswith('__init__.')
            ),
            ''
        );
        if initializer {
            import from jaclang.runtime.prepared_loader { PreparedLoader }
            loader = PreparedLoader(application);
            spec = importlib.util.spec_from_file_location(
                name,
                initializer,
                loader=loader,
                submodule_search_locations=[application.root]
            );
            if spec is None {
                raise ImportError(f"Cannot load prepared package {initializer}");
            }
            package = importlib.util.module_from_spec(spec);
            sys.modules[name] = package;
            try {
                loader.exec_module(package);
            } except BaseException {
                sys.modules.pop(name, None);
                raise;
            }
        } else {
            package = types.ModuleType(name);
            package.__path__ = [application.root];
            package.__package__ = name;
            package.__spec__ = importlib.machinery.ModuleSpec(
                name, loader=None, is_package=True
            );
            package.__spec__.submodule_search_locations = [application.root];
            sys.modules[name] = package;
        }
    }
    return name;
}

def qualified_module(path: str, application: PreparedApplication) -> str {
    relative = os.path.relpath(os.path.dirname(path), application.root);
    stem = base_stem(path);
    parts = [] if relative == '.' else relative.split(os.sep);
    if stem != '__init__' {
        parts.append(stem);
    }
    return '.'.join([application_namespace(application), *parts]);
}

def import_prepared(path: str, application: PreparedApplication) -> types.ModuleType {
    import importlib;
    ensure_namespace(application);
    return importlib.import_module(qualified_module(path, application));
}

def entry_alias(fullname: str) -> tuple[str, str] | None {
    if not fullname.startswith('_jac_app_') {
        return None;
    }
    for consumer in _applications.values() {
        prefix = application_namespace(consumer) + '.';
        if not fullname.startswith(prefix) {
            continue;
        }
        for provider in _applications.values() {
            if provider is consumer {
                continue;
            }
            origin = provider.origins.get(provider.entry, '');
            source = os.path.join(consumer.root, origin) if origin else provider.entry;
            local_name = qualified_module(source, consumer);
            if fullname == local_name {
                ensure_namespace(provider);
                return (qualified_module(provider.entry, provider), provider.entry);
            }
        }
    }
    return None;
}

def module_builtins(application: PreparedApplication, source: str) -> dict {
    import builtins;
    import importlib;
    if not application.scope_imports {
        return dict(vars(builtins));
    }
    original = builtins.__import__;
    def scoped_import(
        name: str,
        globals: any = None,
        locals: any = None,
        fromlist: any = (),
        level: int = 0
    ) -> any {
        if level or name.startswith('_jac_app_') {
            return original(name, globals, locals, fromlist, level);
        }
        for base in dict.fromkeys([os.path.dirname(source), application.root]) {
            candidate = os.path.join(base, *name.split('.'));
            selected = application;
            for suffix in ('.jac', '.py') {
                declared = _applications.get(os.path.realpath(candidate + suffix));
                if declared is not None {
                    selected = declared;
                    break;
                }
            }
            local = any(
                candidate + suffix in selected.code for suffix in ('.jac', '.py')
            )
                or any(p.startswith(candidate + os.sep) for p in selected.code);
            if not local {
                continue;
            }
            relative = os.path.relpath(candidate, selected.root).replace(os.sep, '.');
            prefix = ensure_namespace(selected);
            result = original(prefix + '.' + relative, globals, locals, fromlist, 0);
            if fromlist {
                return result;
            }
            first = relative.split('.')[:len(relative.split('.')) - len(name.split('.'))
                + 1];
            return importlib.import_module(prefix + '.' + '.'.join(first));
        }
        return original(name, globals, locals, fromlist, level);
    }
    result = dict(vars(builtins));
    result['__import__'] = scoped_import;
    return result;
}

def execute_module(module: types.ModuleType, application: PreparedApplication) {
    filename = module.__file__;
    if filename is None {
        raise ImportError(f'Prepared module {module.__name__} has no source path');
    }
    source = os.path.realpath(filename);
    code = application.code.get(source);
    if code is None {
        raise ImportError(f'No prepared executable artifact for {source}');
    }
    if not module.__name__.startswith('jaclang.') {
        import from jaclang.runtime.runtime { JacRuntime as Jac }
        Jac.load_module(module.__name__, module);
    }
    (native_engine, callbacks) = application.native.get(source, (None, None));
    if native_engine is not None {
        import from jaclang.runtime.interop_bridge { NativeLibrary }
        if isinstance(native_engine, NativeLibrary) {
            native_engine.initialize();
        }
        module.__dict__['__jac_native_engine__'] = native_engine;
    }
    if callbacks is not None {
        module.__dict__['__jac_interop_py_funcs__'] = callbacks;
    }
    module.__dict__['__builtins__'] = module_builtins(application, source);
    exec(code, module.__dict__);
}

def semantic_for_scope(scope: str) -> Info | None {
    import sys;
    import from jaclang.jac0core.ext_registry { base_stem }
    parts = scope.split('.');
    for end in range(len(parts) - 1, 0, -1) {
        name = '.'.join(parts[:end]);
        module = sys.modules.get(name);
        source = getattr(module, '__file__', '');
        if not source {
            continue;
        }
        application = application_for(source, name);
        if application is None {
            continue;
        }
        key = '.'.join([base_stem(source), *parts[end:]]);
        return application.semantic.get(os.path.realpath(source), {}).get(key);
    }
    return None;
}


def origin_for_source(path: str) -> str {
    application = application_for(path);
    if application is None {
        return path;
    }
    origin = application.origins.get(os.path.realpath(path));
    return os.path.realpath(os.path.join(application.root, origin)) if origin else path;
}

def source_for_origin(application: PreparedApplication, origin: str) -> str {
    for (path, original) in application.origins.items() {
        if original == origin {
            return path;
        }
    }
    return os.path.realpath(os.path.join(application.root, origin));
}
