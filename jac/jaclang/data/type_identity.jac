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
    has modules: set[str] = set(),
        application: PreparedApplication | None = None;
}

glob _scope: ContextVar[ResolutionScope | None] = ContextVar(
         'jac_persistence_scope', `default=None
     ),
     _types: dict[str, WeakValueDictionary[str, type]] = {},
     _lock: threading.RLock = threading.RLock();

def module_identity(facts: tuple[str, ...]) -> str {
    return 'jac:' + json.dumps([facts[0], facts[2], facts[3]], separators=(',', ':'));
}

def class_facts(cls: type) -> tuple[str, ...] {
    module = sys.modules.get(cls.__module__);
    facts = getattr(module, '__jac_persistence__', ());
    if cls.__module__.startswith('jaclang.') {
        return ();
    }
    if isinstance(facts, tuple)
        and len(facts) == 5
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
        key = module_identity(facts) + '.' + cls.__name__;
        with _lock {
            _types.setdefault(key, WeakValueDictionary())[cls.__module__] = cls;
        }
    }
}

@contextmanager
def resolution_scope(application: PreparedApplication | None) -> Iterator[None] {
    modules: set[str] = set();
    if application is not None {
        for metadata in application.manifests.values() {
            facts = metadata.get('persistence', ());
            if facts {
                modules.add(module_identity(tuple(facts)));
            }
        }
    }
    token = _scope.set(ResolutionScope(modules, application));
    try {
        yield ;
    } finally {
        _scope.reset(token);
    }
}

def resolve_type(module_name: str, name: str) -> type {
    key = module_name + '.' + name;
    scope = _scope.get();
    if scope is not None
        and scope.application is not None
        and module_name not in scope.modules {
        raise ForeignType(
            f'Persistent type {key} is outside the active app persistence domains'
        );
    }
    with _lock {
        candidates = {
            runtime_module: cls
            for (runtime_module, cls) in _types.get(key, {}).items()
            if getattr(sys.modules.get(runtime_module), cls.__name__, None) is cls
        };
    }
    if scope is not None and scope.application is not None {
        # Lazy imports are resolved only from this app's compiled manifest.
        application = scope.application;
        if application is not None {
            import from jaclang.runtime.prepared { load_prepared_module }
            for (source, metadata) in application.manifests.items() {
                facts = metadata.get('persistence', ());
                if facts and module_identity(tuple(facts)) == module_name {
                    module = load_prepared_module(source, application);
                    candidate = getattr(module, name, None);
                    if isinstance(candidate, type)
                        and type_module(candidate) == module_name {
                        register_type(candidate);
                        return candidate;
                    }
                }
            }
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
