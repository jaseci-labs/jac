"""Durable type names and app-local resolution. Runtime import names stay private.

The compiler embeds module facts in executable code and prepared manifests.
No configuration or source files are read while resolving stored data.
"""
import json;
import sys;
import type from jaclang.runtime.prepared { PreparedApplication }
import threading;
import from weakref { WeakValueDictionary }
import from contextlib { contextmanager }
import from contextvars { ContextVar }

class TypeResolutionError(ValueError) {}
class ForeignType(TypeResolutionError) {}
class UnavailableType(TypeResolutionError) {}

obj ResolutionScope {
    has application: PreparedApplication | None = None;
}

glob _scope: ContextVar[ResolutionScope | None] = ContextVar(
         'jac_persistence_scope', `default=None
     ),
     _types: dict[str, WeakValueDictionary[str, type]] = {},
     _lock: threading.RLock = threading.RLock();

def module_identity(facts: tuple[str, ...]) -> str {
    return 'jac:' + json.dumps(list(facts), separators=(',', ':'));
}

def class_facts(cls: type) -> tuple[str, ...] {
    module = sys.modules.get(cls.__module__);
    facts = cls.__dict__.get(
        '__jac_persistence__', getattr(module, '__jac_persistence__', ())
    );
    if cls.__module__.startswith('jaclang.') {
        return ();
    }
    if isinstance(facts, tuple)
        and len(facts) == 2
        and all(isinstance(x, str) for x in facts) {
        return facts;
    }
    return ();
}

def type_module(cls: type) -> str {
    facts = class_facts(cls);
    if facts {
        return module_identity(facts);
    }
    if cls.__module__.startswith('_jac_app_') {
        raise UnavailableType(
            f'Type {cls.__module__}.{cls.__name__} has no compiled persistence identity; rebuild the application'
        );
    }
    return cls.__module__;
}

def register_type(cls: type) {
    facts = class_facts(cls);
    if facts {
        setattr(cls, '__jac_persistence__', facts);
        key = module_identity(facts) + '.' + cls.__name__;
        with _lock {
            _types.setdefault(key, WeakValueDictionary())[cls.__module__] = cls;
        }
    }
}

@contextmanager
def resolution_scope(application: PreparedApplication | None) -> Iterator[None] {
    token = _scope.set(ResolutionScope(application));
    try {
        yield ;
    } finally {
        _scope.reset(token);
    }
}

def resolve_type(module_name: str, name: str) -> type {
    key = module_name + '.' + name;
    scope = _scope.get();
    application = scope.application if scope is not None else None;
    if application is not None and module_name not in application.persistence_modules {
        namespace = identity_namespace(module_name);
        if namespace in application.persistence_namespaces {
            raise UnavailableType(
                f'Persistent schema module {module_name} is missing from the active application'
            );
        }
        raise ForeignType(
            f'Persistent type {key} is outside the active application namespace'
        );
    }
    with _lock {
        candidates: dict[str, type] = {};
        for (runtime_module, registered) in _types.get(key, {}).items() {
            candidate = getattr(sys.modules.get(runtime_module), name, None);
            candidates[runtime_module] = candidate
                if isinstance(candidate, type) and type_module(candidate) == module_name
                else registered;
        }
    }
    if application is not None {
        import from jaclang.runtime.prepared { load_prepared_module }
        module = load_prepared_module(
            application.persistence_modules[module_name], application
        );
        candidate = getattr(module, name, None);
        if isinstance(candidate, type) and type_module(candidate) == module_name {
            register_type(candidate);
            return candidate;
        }
    } elif len(candidates) == 1 {
        return next(iter(candidates.values()));
    }
    raise UnavailableType(
        f'Cannot resolve persistent type {key} in the active app; prepare its schema and select a persistence scope'
    );
}

# SQL type filters and ancestry use the same identity as serialized archetypes.
# Runtime builtins and external Python classes retain their established names.
def storage_type(cls: type) -> str {
    return type_module(cls) + '.' + cls.__name__ if class_facts(cls) else cls.__name__;
}

def schema_type(value: object) -> str {
    import from typing { get_args, get_origin }
    origin = get_origin(value);
    if origin is not None {
        return schema_type(origin)
            + '['
            + ','.join(schema_type(arg) for arg in get_args(value))
            + ']';
    }
    if isinstance(value, type) {
        return type_module(value) + '.' + value.__qualname__;
    }
    return str(value);
}


def resolution_required -> bool {
    return _scope.get() is not None;
}


def identity_namespace(module_name: str) -> str {
    try {
        parts = json.loads(module_name[4:]);
    } except ValueError {
        raise TypeResolutionError(
            f'Malformed persistent module identity: {module_name}'
        );
    }
    if not isinstance(parts, list)
        or len(parts) != 2
        or not all(isinstance(p, str) and p for p in parts) {
        raise TypeResolutionError(
            f'Malformed persistent module identity: {module_name}'
        );
    }
    return str(parts[0]);
}

def index_application(application: PreparedApplication) {
    modules: dict[str, str] = {};
    namespaces: set[str] = set();
    for (source, metadata) in application.manifests.items() {
        facts = metadata.get('persistence', ());
        if not facts {
            continue;
        }
        if not isinstance(facts, (tuple, list))
            or len(facts) != 2
            or not all(isinstance(p, str) and p for p in facts) {
            raise TypeResolutionError(
                f'Invalid compiled persistence metadata for {source}; rebuild the application'
            );
        }
        identity = module_identity(tuple(facts));
        if identity in modules and modules[identity] != source {
            raise TypeResolutionError(
                f'Duplicate persistent module identity {identity}'
            );
        }
        modules[identity] = source;
        namespaces.add(identity_namespace(identity));
    }
    application.persistence_modules = modules;
    application.persistence_namespaces = namespaces;
}
