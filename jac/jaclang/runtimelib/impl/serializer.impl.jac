"""Helper: get type metadata dict."""
impl Serializer._type_info(`obj: object, `include: bool) -> dict[str, object] {
    return {'__type__': type(`obj).__name__, '__module__': type(`obj).__module__}
        if `include
        else {};
}

"""Helper: serialize object attributes (non-private, non-callable)."""
impl Serializer._serialize_attrs(
    `obj: object,
    include_type: bool,
    api_mode: bool,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None
) -> dict[str, object] {
    return {
        a: Serializer._serialize_value(
            getattr(`obj, a), include_type, api_mode, ref_mode, _seen
        )
        for a in dir(`obj)
        if not a.startswith('_') and not callable(getattr(`obj, a, None))
    };
}

"""Serialize any object to JSON-compatible format."""
impl Serializer.serialize(
    `obj: object,
    include_type: bool = False,
    api_mode: bool = False,
    ref_mode: bool = False
) -> object {
    _seen = (set(), set()) if ref_mode else None;
    return Serializer._serialize_value(`obj, include_type, api_mode, ref_mode, _seen);
}

"""Serialize a value recursively."""
impl Serializer._serialize_value(
    val: object,
    include_type: bool,
    api_mode: bool = False,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None
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
        return [
            Serializer._serialize_value(v, include_type, api_mode, ref_mode, _seen)
            for v in val
        ];
    }
    if isinstance(val, dict) {
        return {
            str(k): Serializer._serialize_value(
                v, include_type, api_mode, ref_mode, _seen
            ) for (k, v) in val.items()
        };
    }
    # Access types
    if isinstance(val, Access) {
        return {'anchors': {str(k): v.value for (k, v) in val.anchors.items()}};
    }
    if isinstance(val, Permission) {
        return {
            'all': val.all.value,
            'roots': Serializer._serialize_value(
                val.roots, include_type, api_mode, ref_mode, _seen
            )
        };
    }
    # Anchor (NodeAnchor, EdgeAnchor)
    if isinstance(val, Anchor) {
        result = Serializer._type_info(val, include_type);
        result |= {
            'id': str(val.id),
            'root': str(val.root) if val.root else None,
            'persistent': val.persistent,
            'access': Serializer._serialize_value(
                val.access, include_type, api_mode, ref_mode, _seen
            )
        };
        if val.is_populated() {
            arch = val.archetype;
            result['archetype'] = Serializer._type_info(arch, include_type) | Serializer._serialize_attrs(
                arch, include_type, api_mode, ref_mode, _seen
            );
        }
        if isinstance(val, NodeAnchor) {
            result['edges'] = [str(e.id) for e in val.edges];
            # Topology index lives only on root anchors
            if val.topology_index_data is not None
            and isinstance(val.archetype, Root) {
                import from base64 { b64encode }
                result['topology_index_data'] = b64encode(
                    val.topology_index_data
                ).decode(
                    'ascii'
                );
            }
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
        if _seen is not None {
            jac_anchor = val?.__jac__;
            if jac_anchor {
                jac_id = jac_anchor.id;
                (jac_uuids, _) = _seen;
                if jac_id in jac_uuids {
                    ref_type = (
                        'node'
                            if isinstance(jac_anchor, NodeAnchor)
                            else 'edge'
                                if isinstance(jac_anchor, EdgeAnchor)
                                else 'walker'
                                    if isinstance(jac_anchor, WalkerAnchor)
                                    else 'object'
                    );
                    return {'$ref': jac_id.hex, '$type': ref_type};
                }
                jac_uuids.add(jac_id);
                # Register in memory so _deserialize_jac_ref can resolve
                # $ref placeholders back to the live archetype.
                try {
                    import from jaclang { JacRuntimeInterface as Jac }
                    Jac.get_context().mem.put(jac_anchor);
                } except Exception as e {
                    logger.warning(
                        f"ref_mode: failed to register {jac_id.hex} in memory: {e}"
                    );
                }
            }
        }
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
        return result | Serializer._serialize_attrs(
            val, include_type, api_mode, ref_mode, _seen
        );
    }
    # Generic object with __dict__
    if val?.__dict__ {
        # Cycle guard for non-Jac objects (tracked by identity, not UUID).
        if _seen is not None {
            (_, obj_ids) = _seen;
            obj_identity = id(val);
            if obj_identity in obj_ids {
                return str(val);
            }
            obj_ids.add(obj_identity);
        }
        result = Serializer._type_info(val, include_type);
        if api_mode {
            result['__type__'] = type(val).__name__;
            result['__module__'] = type(val).__module__;
        }
        for (k, v) in val.__dict__.items() {
            if not k.startswith('_') {
                result[k] = Serializer._serialize_value(
                    v, include_type, api_mode, ref_mode, _seen
                );
            }
        }
        return result;
    }
    logger.warning(
        f"Falling back to str() for {type(val).__module__}.{type(val).__name__}"
    );
    return str(val);
}

"""Deserialize a $ref placeholder back to the live archetype, typed stub, or None."""
impl Serializer._deserialize_jac_ref(data: dict[str, object]) -> (object | None) {
    id_str = data.get('$ref');
    if not isinstance(id_str, str) {
        return None;
    }
    try {
        ref_uuid = UUID(id_str);
    } except (ValueError, AttributeError) {
        logger.error(f"Invalid UUID in $ref: {id_str}");
        return None;
    }
    try {
        import from jaclang { JacRuntimeInterface as Jac }
        anchor = Jac.get_context().mem.get(ref_uuid);
        if anchor {
            if not anchor.is_populated() {
                anchor.populate();
            }
            if anchor.is_populated() {
                return anchor.archetype;
            }
        }
    } except Exception as e {
        logger.warning(f"Failed to resolve $ref {id_str} from context: {e}");
    }
    ref_type = data.get('$type');
    stub_cls = cast(
        type,
        (
            NodeAnchor
                if ref_type == 'node'
                else EdgeAnchor
                    if ref_type == 'edge'
                    else WalkerAnchor if ref_type == 'walker' else ObjectAnchor
        )
    );
    return Serializer._id_to_stub(stub_cls, id_str);
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
        if '$ref' in val and val.keys() <= {'$ref','$type'} {
            return Serializer._deserialize_jac_ref(val);
        }
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

"""Helper: Convert string ID to unpopulated anchor stub."""
impl Serializer._id_to_stub(anchor_cls: type, id_str: str) -> (Anchor | None) {
    try {
        stub = anchor_cls.__new__(anchor_cls);
        stub.id = UUID(id_str);
        return stub;
    } except Exception as e {
        logger.error(
            f"Failed to create stub for {anchor_cls.__name__} with id {id_str}: {e}"
        );
        return None;
    }
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
            # Restore edges from serialized edge IDs
            edge_ids = data.get('edges');
            if not edge_ids {
                anchor.edges = [];
            } else {
                edges = [];
                for eid in edge_ids {
                    if (stub := Serializer._id_to_stub(EdgeAnchor, eid)) {
                        edges.append(stub);
                    }
                }
                anchor.edges = edges;
            }
            # Topology index lives only on root anchors
            anchor.topology_index_data = None;
            if isinstance(anchor.__dict__.get('archetype'), Root) {
                if (topo_b64 := data.get('topology_index_data')) {
                    import from base64 { b64decode }
                    anchor.topology_index_data = b64decode(topo_b64);
                }
            }
        }
        if isinstance(anchor, EdgeAnchor) {
            anchor.is_undirected = data.get('is_undirected', False);
            # Restore source and target from serialized IDs
            if (source_id := data.get('source')) {
                anchor.source = Serializer._id_to_stub(NodeAnchor, source_id);
            }
            if (target_id := data.get('target')) {
                anchor.target = Serializer._id_to_stub(NodeAnchor, target_id);
            }
        }

        anchor.hash = Serializer._compute_hash(anchor);
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
    perm.all = access_level_cast(data.get('all', -1));
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
        access.anchors = {k: access_level_cast(v) for (k, v) in anchors.items()};
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

"""Compute a hash of the anchor's serialized state for dirty checking."""
impl Serializer._compute_hash(anchor: Anchor) -> int {
    import from json { dumps }
    try {
        data = Serializer.serialize(anchor, include_type=True);
        # Exclude topology_index_data from hash — it's a derived cache,
        # not user-mutable state. Including it would double the cost of
        # every serialize round-trip for large graphs.
        if isinstance(data, dict) {
            data.pop('topology_index_data', None);
        }
        return hash(dumps(data, sort_keys=True));
    } except Exception {
        return 0;
    }
}
