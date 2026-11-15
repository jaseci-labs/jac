impl module_identity(facts: tuple[str, ...]) -> str {
    return 'jac:' + json.dumps(list(facts), separators=(',', ':'));
}

impl class_facts(cls: type) -> tuple[str, ...] {
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
    if facts {
        raise UnavailableType(
            f'Type {cls.__module__}.{cls.__name__} has obsolete persistence metadata; rebuild the application'
        );
    }
    return ();
}

impl type_module(cls: type) -> str {
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

impl register_type(cls: type) {
    facts = class_facts(cls);
    if facts {
        setattr(cls, '__jac_persistence__', facts);
        key = module_identity(facts) + '.' + cls.__name__;
        with _lock {
            _types.setdefault(key, WeakValueDictionary())[cls.__module__] = cls;
        }
    }
}

impl resolution_scope(application: PreparedApplication | None) -> Iterator[None] {
    token = _scope.set(ResolutionScope(application));
    try {
        yield ;
    } finally {
        _scope.reset(token);
    }
}

impl _cached_type(
    application: PreparedApplication, key: str, name: str
) -> (type | None) {
    slot = _resolved.get(id(application));
    if slot is None or slot[0]() is not application {
        return None;
    }
    cls = slot[1].get(key);
    if cls is not None
        and getattr(sys.modules.get(cls.__module__), name, None) is cls {
        return cls;
    }
    return None;
}

impl _forget_resolved(application_id: int) {
    with _lock {
        _resolved.pop(application_id, None);
    }
}

impl _remember_type(application: PreparedApplication, key: str, cls: type) {
    with _lock {
        slot = _resolved.get(id(application));
        if slot is None or slot[0]() is not application {
            slot = (ref(application), WeakValueDictionary());
            _resolved[id(application)] = slot;
            finalize(application, _forget_resolved, id(application));
        }
        slot[1][key] = cls;
    }
}

impl resolve_type(module_name: str, name: str) -> type {
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
    if application is not None {
        cached = _cached_type(application, key, name);
        if cached is not None {
            return cached;
        }
        import from jaclang.runtime.prepared { load_prepared_module }
        module = load_prepared_module(
            application.persistence_modules[module_name], application
        );
        candidate = getattr(module, name, None);
        if isinstance(candidate, type) and type_module(candidate) == module_name {
            register_type(candidate);
            _remember_type(application, key, candidate);
            return candidate;
        }
    } else {
        with _lock {
            candidates: dict[str, type] = {};
            for (runtime_module, registered) in _types.get(key, {}).items() {
                candidate = getattr(sys.modules.get(runtime_module), name, None);
                candidates[runtime_module] = candidate
                    if isinstance(candidate, type)
                        and type_module(candidate) == module_name
                    else registered;
            }
        }
        if len(candidates) == 1 {
            return next(iter(candidates.values()));
        }
    }
    raise UnavailableType(
        f'Cannot resolve persistent type {key} in the active app; prepare its schema and select a persistence scope'
    );
}

impl storage_type(cls: type) -> str {
    return type_module(cls) + '.' + cls.__name__ if class_facts(cls) else cls.__name__;
}

impl schema_type(value: object) -> str {
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

impl resolution_required -> bool {
    return _scope.get() is not None;
}

impl identity_namespace(module_name: str) -> str {
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

impl index_application(application: PreparedApplication) {
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
