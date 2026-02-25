"""Helper: get type metadata dict."""
impl Serializer._type_info(obj: object, include: bool) -> dict[str, object] {
    return {'__type__': type(obj).__name__, '__module__': type(obj).__module__}
    if include
    else {};
}

"""Helper: serialize object attributes (non-private, non-callable)."""
impl Serializer._serialize_attrs(
    obj: object, include_type: bool, api_mode: bool
) -> dict[str, object] {
    return {
        a: Serializer._serialize_value(getattr(obj, a), include_type, api_mode)
        for a in dir(obj)
        if not a.startswith('_') and not callable(getattr(obj, a, None))
    };
}

"""Serialize any object to JSON-compatible format."""
impl Serializer.serialize(
    `obj: object, include_type: bool = False, api_mode: bool = False
) -> object {
    return Serializer._serialize_value(`obj, include_type, api_mode);
}

"""Serialize a value recursively."""
impl Serializer._serialize_value(
    val: object, include_type: bool, api_mode: bool = False
) -> object {
    # Primitives & UUID & Enum
    if val is None or isinstance(val, (str, int, float, bool)) {
        return val;
    }
    if isinstance(val, UUID) {
        return str(val);
    }
    if isinstance(val, Enum) {
        return val.value;
    }
    # Collections
    if isinstance(val, (list, tuple)) {
        return [Serializer._serialize_value(v, include_type, api_mode) for v in val];
    }
    if isinstance(val, dict) {
        return {
            str(k): Serializer._serialize_value(v, include_type, api_mode)
            for (k, v) in val.items()
        };
    }
    # Access types
    if isinstance(val, Access) {
        return {'anchors': {str(k): v.value for (k, v) in val.anchors.items()}};
    }
    if isinstance(val, Permission) {
        return {
            'all': val.all.value,
            'roots': Serializer._serialize_value(val.roots, include_type, api_mode)
        };
    }
    # Anchor (NodeAnchor, EdgeAnchor)
    if isinstance(val, Anchor) {
        result = Serializer._type_info(val, include_type);
        result |= {
            'id': str(val.id),
            'root': str(val.root) if val.root else None,
            'persistent': val.persistent,
            'access': Serializer._serialize_value(val.access, include_type, api_mode)
        };
        if val.is_populated() {
            arch = val.archetype;
            result['archetype'] = Serializer._type_info(arch, include_type) | Serializer._serialize_attrs(
                arch, include_type, api_mode
            );
        }
        if isinstance(val, NodeAnchor) {
            result['edges'] = [str(e.id) for e in val.edges];
        }
        if isinstance(val, EdgeAnchor) {
            result |= {
                'source': str(val.source.id) if val.source else None,
                'target': str(val.target.id) if val.target else None,
                'is_undirected': val.is_undirected
            };
        }
        return result;
    }
    # Archetype (standalone)
    if isinstance(val, Archetype) {
        result = Serializer._type_info(val, include_type);
        if api_mode {
            result |= {
                '_jac_type': type(val).__name__,
                '_jac_id': val.__jac__.id.hex if val?.__jac__ else None,
                '_jac_archetype': 'node'
                if isinstance(val, NodeArchetype)
                else 'walker' if isinstance(val, WalkerArchetype) else 'archetype'
            };
        }
        return result | Serializer._serialize_attrs(val, include_type, api_mode);
    }
    # Generic object with __dict__
    if val?.__dict__ {
        result = Serializer._type_info(val, include_type);
        for (k, v) in val.__dict__.items() {
            if not k.startswith('_') {
                result[k] = Serializer._serialize_value(v, include_type, api_mode);
            }
        }
        return result;
    }
    logger.warning(
        f"Falling back to str() for {type(val).__module__}.{type(val).__name__}"
    );
    return str(val);
}

"""Deserialize data back to original object type."""
impl Serializer.deserialize(data: dict[str, object]) -> (object | None) {
    if not isinstance(data, dict) {
        return data;
    }
    type_name = data.get('__type__');
    if not type_name {
        return {k: Serializer._deserialize_value(v) for (k, v) in data.items()};
    }
    dispatch = {
        'Anchor': Serializer._deserialize_anchor,
        'NodeAnchor': Serializer._deserialize_anchor,
        'EdgeAnchor': Serializer._deserialize_anchor,
        'Permission': Serializer._deserialize_permission,
        'Access': Serializer._deserialize_access
    };
    if (handler := dispatch.get(type_name)) {
        return handler(data);
    }
    # Reconstruct from registry
    if (cls := Serializer._get_class(data.get('__module__'), type_name)) {
        try {
            instance = cls.__new__(cls);
            for (k, v) in data.items() {
                if not k.startswith('__') {
                    setattr(instance, k, Serializer._deserialize_value(v));
                }
            }
            return instance;
        } except Exception as e {
            logger.error(f"Failed to deserialize {type_name}: {e}");
        }
    }
    return None;
}

"""Deserialize a value recursively."""
impl Serializer._deserialize_value(val: object) -> object {
    if val is None or isinstance(val, (str, int, float, bool)) {
        return val;
    }
    if isinstance(val, list) {
        return [Serializer._deserialize_value(v) for v in val];
    }
    if isinstance(val, dict) {
        return Serializer.deserialize(val)
        if '__type__' in val
        else {k: Serializer._deserialize_value(v) for (k, v) in val.items()};
    }
    return val;
}

"""Register a class for safe deserialization."""
impl Serializer.register(cls: type) -> None {
    Serializer._registry[f"{cls.__module__}.{cls.__name__}"] = cls;
}

"""Look up a class by module.name (only registered classes for security)."""
impl Serializer._get_class(module_name: str, class_name: str) -> (type | None) {
    if not module_name or not class_name {
        return None;
    }
    key = f"{module_name}.{class_name}";
    if not (cls := Serializer._registry.get(key)) {
        logger.warning(f"Refused to deserialize unregistered class: {key}");
    }
    return cls;
}

"""Deserialize Anchor (Node/Edge)."""
impl Serializer._deserialize_anchor(data: dict[str, object]) -> (Anchor | None) {
    anchor_cls = {'NodeAnchor': NodeAnchor, 'EdgeAnchor': EdgeAnchor}.get(
        data.get('__type__', ''), Anchor
    );
    try {
        anchor = anchor_cls.__new__(anchor_cls);
        anchor.id = UUID(data['id']) if data.get('id') else None;
        anchor.root = UUID(data['root']) if data.get('root') else None;
        anchor.persistent = data.get('persistent', False);
        anchor.access = Serializer._deserialize_permission(data.get('access'));

        if (arch_data := data.get('archetype')) {
            anchor.archetype = Serializer._deserialize_archetype(arch_data, anchor);
        }
        if isinstance(anchor, NodeAnchor) {
            anchor.edges = [];  # Edges loaded lazily via populate()
        }
        if isinstance(anchor, EdgeAnchor) {
            anchor.is_undirected = data.get('is_undirected', False);
            # source/target loaded lazily via populate()
        }
        return anchor;
    } except Exception as e {
        logger.error(f"Failed to deserialize anchor: {e}");
        return None;
    }
}

"""Deserialize Permission."""
impl Serializer._deserialize_permission(data: object) -> Permission {
    if not isinstance(data, dict) {
        return Permission();
    }
    perm = Permission();
    perm.all = AccessLevel(data.get('all', -1));
    if (roots := data.get('roots')) {
        perm.roots = Serializer._deserialize_access(roots);
    }
    return perm;
}

"""Deserialize Access."""
impl Serializer._deserialize_access(data: object) -> Access {
    if not isinstance(data, dict) {
        return Access();
    }
    access = Access();
    if (anchors := data.get('anchors')) {
        access.anchors = {k: AccessLevel(v) for (k, v) in anchors.items()};
    }
    return access;
}

"""Deserialize Archetype."""
impl Serializer._deserialize_archetype(
    data: dict[str, object], anchor: Anchor
) -> (object | None) {
    type_name = data.get('__type__');
    module_name = data.get('__module__');
    if not type_name or not module_name {
        return None;
    }
    cls = Serializer._get_class(module_name, type_name);
    if not cls {
        return None;
    }
    try {
        arch = cls.__new__(cls);
        for (k, v) in data.items() {
            if not k.startswith('__') {
                setattr(arch, k, Serializer._deserialize_value(v));
            }
        }
        arch.__jac__ = anchor;
        return arch;
    } except Exception as e {
        logger.error(f"Failed to deserialize archetype {type_name}: {e}");
        return None;
    }
}
