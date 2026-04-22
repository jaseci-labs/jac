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

"""Register a class for safe deserialization and attach its fingerprint."""
impl Serializer.register(cls: type) -> None {
    Serializer._registry[f"{cls.__module__}.{cls.__name__}"] = cls;
    try {
        cls.__jac_fingerprint__ = Serializer.fingerprint(cls);
    } except Exception as e {
        logger.debug(f"Failed to compute fingerprint for {cls.__name__}: {e}");
        cls.__jac_fingerprint__ = '';
    }
}

"""Register an alias mapping `old_name` -> current registry key for `cls`."""
impl Serializer.register_alias(old_name: str, cls: type) -> None {
    new_name = f"{cls.__module__}.{cls.__name__}";
    if old_name == new_name {
        # No-op alias; likely a copy/paste error. Warn but don't fail.
        logger.debug(f"archetype_alias: {old_name} == current name; alias is a no-op");
        return;
    }
    Serializer._aliases[old_name] = new_name;
}

"""Return {field_name: resolved_annotation} for a dataclass (empty otherwise)."""
impl Serializer._get_field_types(cls: type) -> dict[str, object] {
    if not is_dataclass(cls) {
        return {};
    }
    # Prefer resolved hints (unwraps string forward-refs); fall back to raw.
    try {
        hints = get_type_hints(cls);
    } except Exception {
        hints = getattr(cls, '__annotations__', {}) or {};
    }
    out: dict[str, object] = {};
    for f in fields(cls) {
        if f.name in hints {
            out[f.name] = hints[f.name];
        }
    }
    return out;
}

"""Best-effort coercion table. Returns (value, ok)."""
impl Serializer.coerce(val: object, target_type: object) -> tuple {
    # Unresolved or missing annotation: caller falls back to raw.
    if target_type is None or isinstance(target_type, str) {
        return (val, False);
    }
    # Unwrap Optional[X] / X | None at this layer: None passes through;
    # a non-None val is coerced against the non-None branch.
    (origin, args) = (get_origin(target_type), get_args(target_type));
    if origin is Union or origin is UnionType {
        non_none = [
            a
            for a in args
            if a is not NoneType
        ];
        if val is None {
            return (None, True);
        }
        # Try each non-None variant; first success wins.
        for variant in non_none {
            (coerced, ok) = Serializer.coerce(val, variant);
            if ok {
                return (coerced, True);
            }
        }
        return (val, False);
    }
    # Strip parameterized generics to their origin for isinstance checks.
    base = origin if origin is not None else target_type;
    if not isinstance(base, type) {
        # e.g. ParamSpec, TypeVar, Literal: we can't isinstance-check;
        # leave the value alone and call it "ok" (don't spam coercion warnings).
        return (val, True);
    }
    if val is None {
        return (None, False);
    }
    if isinstance(val, base) {
        return (val, True);
    }
    # Ordered coercion attempts — the first that raises or returns wrong type
    # falls through to the next. The outer try/except catches everything so
    # coercion is never worse than a no-op.
    try {
        # Booleans must be checked before int/float because bool is a subclass
        # of int and isinstance(True, int) == True would short-circuit above.
        if base is bool {
            if isinstance(val, (int, float)) {
                return (bool(val), True);
            }
            if isinstance(val, str) {
                lowered = val.strip().lower();
                if lowered in ('true', '1', 'yes', 'y', 'on') {
                    return (True, True);
                }
                if lowered in ('false', '0', 'no', 'n', 'off', '') {
                    return (False, True);
                }
            }
            return (val, False);
        }
        if base is int {
            if isinstance(val, bool) {
                return (int(val), True);
            }
            if isinstance(val, (str, float)) {
                return (int(val), True);
            }
        }
        if base is float {
            if isinstance(val, (bool, int, str)) {
                return (float(val), True);
            }
        }
        if base is str {
            return (str(val), True);
        }
        if base is UUID and isinstance(val, str) {
            return (UUID(val), True);
        }
        # ISO-string coercions to datetime/date/time use getattr dispatch to
        # sidestep typeshed gaps on `fromisoformat` in some Python versions.
        if base is datetime and isinstance(val, str) {
            return (getattr(datetime, 'fromisoformat')(val), True);
        }
        if base is date and isinstance(val, str) {
            return (getattr(date, 'fromisoformat')(val), True);
        }
        if base is time and isinstance(val, str) {
            return (getattr(time, 'fromisoformat')(val), True);
        }
        if isinstance(base, type) and issubclass(base, Enum) {
            # Try value-based construction (Enum(val)); if that fails, name lookup.
            try {
                return (base(val), True);
            } except (ValueError, KeyError) {
                members = getattr(base, '__members__', {});
                if isinstance(val, str) and val in members {
                    return (members[val], True);
                }
            }
        }
        # Container widening: list <-> tuple, keep contents as-is
        # (deep container coercion is Layer 4 territory).
        if base is tuple and isinstance(val, list) {
            return (tuple(val), True);
        }
        if base is list and isinstance(val, tuple) {
            return (list(val), True);
        }
    } except Exception as e {
        logger.debug(
            f"Serializer.coerce fallback: {type(val).__name__} -> "
            f"{getattr(base, '__name__', base)}: {e}"
        );
    }
    return (val, False);
}

"""Compute an archetype schema fingerprint."""
impl Serializer.fingerprint(cls: type) -> str {
    field_pairs: list[list[str]] = [];
    if is_dataclass(cls) {
        for f in fields(cls) {
            # str() on the type annotation handles typing generics, unions,
            # and forward refs uniformly. It's not perfectly stable across
            # Python versions, but it's stable within a given version — and
            # the fingerprint is recomputed at class-load time, so version
            # drift of type reprs just produces a new fingerprint, which
            # migration layer will treat as drift (conservative, safe).
            field_pairs.append([f.name, str(f.type)]);
        }
    }
    field_pairs.sort(key=lambda p: list : p[0]);
    payload = {'module': cls.__module__, 'name': cls.__name__, 'fields': field_pairs};
    encoded = _json_dumps(payload, sort_keys=True, default=str).encode('utf-8');
    return sha256(encoded).hexdigest()[:FINGERPRINT_LENGTH];
}

"""Look up a class by module.name, consulting the alias registry on miss.

Order:
  1. Direct hit in `_registry`.
  2. Alias resolution: follow one level (an alias can point only to a
     registered class; chains are not supported to keep resolution O(1)
     and prevent cycles).
  3. Log and return None (caller quarantines).
"""
impl Serializer._get_class(module_name: str, class_name: str) -> (type | None) {
    if not module_name or not class_name {
        return None;
    }
    key = f"{module_name}.{class_name}";
    if (cls := Serializer._registry.get(key)) {
        return cls;
    }
    # Alias miss-path: resolve one level.
    if (aliased_key := Serializer._aliases.get(key)) {
        if (cls := Serializer._registry.get(aliased_key)) {
            logger.info(f"Serializer: resolving aliased class {key} -> {aliased_key}");
            return cls;
        }
        # Alias pointed at something that isn't registered either. Log once
        # with the specific alias context; don't also emit the generic
        # "unregistered class" warning since that would be misleading (the
        # original key IS known, via the alias — it's the target that's gone).
        logger.warning(
            f"Serializer: alias {key} -> {aliased_key} has no registered "
            "target; cannot resolve."
        );
        return None;
    }
    logger.warning(f"Refused to deserialize unregistered class: {key}");
    return None;
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
            if not isinstance(arch_data, dict) {
                logger.warning(
                    "Serializer: archetype field is not a dict "
                    f"({type(arch_data).__name__}); dropping anchor."
                );
                return None;
            }
            archetype = Serializer._deserialize_archetype(arch_data, anchor);
            if archetype is None {
                # Class resolution or reconstruction failed. Don't leave a
                # half-constructed shell with archetype=None — every caller
                # (SqliteMemory, MongoBackend, direct test uses) would then
                # cache an unusable anchor and NPE later on attribute access.
                # Signal the failure with a single return None and let the
                # caller quarantine.
                logger.warning(
                    "Serializer: archetype reconstruction failed for "
                    f"{arch_data.get('__module__')}.{arch_data.get('__type__')}; "
                    "dropping anchor (caller should quarantine)."
                );
                return None;
            }
            anchor.archetype = archetype;
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
            # Snapshot initial edge IDs for merge-based conflict resolution
            setattr(
                anchor,
                '_initial_edge_ids',
                frozenset(UUID(eid) for eid in (edge_ids or []))
            );
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

"""Deserialize Archetype with Layer 3 coercion.

For each field in the stored data:
  - `__*` keys are skipped (metadata).
  - Fields NOT declared on the current class are silently dropped; the
    stale value doesn't carry forward on re-save. This cleans up removed
    fields across schema drift.
  - Fields declared on the current class run through `Serializer.coerce`
    against the resolved annotation. Successful coercions setattr the
    converted value; unsuccessful ones log at debug and setattr the raw
    value (never lose data — if a field is un-coercible, downstream code
    will notice, but the anchor still loads).
"""
impl Serializer._deserialize_archetype(
    data: dict[str, object], anchor: Anchor
) -> (object | None) {
    raw_type_name = data.get('__type__');
    raw_module_name = data.get('__module__');
    if not isinstance(raw_type_name, str) or not isinstance(raw_module_name, str) {
        return None;
    }
    type_name = raw_type_name;
    module_name = raw_module_name;
    resolved = Serializer._get_class(module_name, type_name);
    if not resolved {
        return None;
    }
    cls = cast(type, resolved);
    try {
        arch: object = cls.__new__(cls);
        field_types = Serializer._get_field_types(cls);
        known = set(field_types.keys());
        dropped: list[str] = [];
        for (k, v) in data.items() {
            if k.startswith('__') {
                continue;
            }
            deser_v = Serializer._deserialize_value(v);
            if k not in known {
                # Field not on current class; drop silently (Layer 3 removed-field path).
                dropped.append(k);
                continue;
            }
            target = field_types[k];
            (coerced, ok) = Serializer.coerce(deser_v, target);
            setattr(arch, k, coerced);
            if not ok {
                logger.debug(
                    f"Serializer: coercion fallback on {module_name}."
                    f"{type_name}.{k}: stored={type(deser_v).__name__}, "
                    f"target={target}; stored value kept as-is."
                );
            }
        }
        if dropped {
            logger.debug(
                f"Serializer: dropped removed fields on {module_name}."
                f"{type_name}: {sorted(dropped)}"
            );
        }
        setattr(arch, '__jac__', anchor);
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
