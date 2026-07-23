impl Serializer._type_info(`obj: object, `include: bool) -> dict[str, object] {
    return {'__type__': type(`obj).__name__, '__module__': type(`obj).__module__}
        if `include
        else {};
}

impl Serializer._serialize_attrs(
    `obj: object,
    include_type: bool,
    api_mode: bool,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None
) -> dict[str, object] {
    result = {
        a: Serializer._serialize_value(
            getattr(`obj, a), include_type, api_mode, ref_mode, _seen
        )
        for a in dir(`obj)
        if not a.startswith('_') and not callable(getattr(`obj, a, None))
    };

    if include_type and not api_mode {
        if hasattr(type(`obj), '__jac_schema__') {
            import from jaclang.runtimelib.schema_rules {
                merged_rules_for,
                repair_mode
            }
            if repair_mode() == 'repair' and (rules := merged_rules_for(type(`obj))) {
                for a in rules.aliases {
                    if a.new_name in result and a.stored_name not in result {
                        result[a.stored_name] = result[a.new_name];
                    }
                }
            }
        }

        attic = `obj?.__jac_attic__;
        if isinstance(attic, dict) and attic {
            result['__jac_attic__'] = Serializer._serialize_value(
                attic, include_type, api_mode, ref_mode, _seen
            );
        }
    }
    return result;
}

impl Serializer.serialize(
    `obj: object,
    include_type: bool = False,
    api_mode: bool = False,
    ref_mode: bool = False
) -> object {
    _seen = (set(), set()) if ref_mode else None;
    return Serializer._serialize_value(`obj, include_type, api_mode, ref_mode, _seen);
}

impl Serializer._serialize_value(
    val: object,
    include_type: bool,
    api_mode: bool = False,
    ref_mode: bool = False,
    _seen: (tuple[set, set] | None) = None
) -> object {
    if val is None or isinstance(val, (str, int, float, bool)) {
        return val;
    }
    if isinstance(val, UUID) {
        return str(val);
    }
    if isinstance(val, Enum) {
        return val.value;
    }

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

            result['version'] = val.version;

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

    if val?.__dict__ {
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

    if (cls := Serializer._get_class(data.get('__module__'), type_name)) {
        try {
            instance = cls.__new__(cls);
            field_types = get_field_types(cls);
            for (k, v) in data.items() {
                if not k.startswith('__') {
                    deser_v = Serializer._deserialize_value(v);
                    if (target := field_types.get(k)) is not None {
                        (coerced, ok) = Serializer.coerce(deser_v, target);
                        if ok {
                            deser_v = coerced;
                        }
                    }
                    setattr(instance, k, deser_v);
                }
            }
            return instance;
        } except Exception as e {
            logger.error(f"Failed to deserialize {type_name}: {e}");
        }
    }
    return None;
}

impl Serializer._deserialize_value(val: object) -> object {
    if val is None or isinstance(val, (str, int, float, bool)) {
        return val;
    }
    if isinstance(val, list) {
        return [Serializer._deserialize_value(v) for v in val];
    }
    if isinstance(val, dict) {
        if '$ref' in val and val.keys() <= {'$ref', '$type'} {
            return Serializer._deserialize_jac_ref(val);
        }
        return Serializer.deserialize(val)
            if '__type__' in val
            else {k: Serializer._deserialize_value(v) for (k, v) in val.items()};
    }
    return val;
}

impl Serializer.register(cls: type) -> None {
    Serializer._registry[f"{cls.__module__}.{cls.__name__}"] = cls;
    import from jaclang.runtimelib.typecache {
        invalidate as _invalidate_typecache,
        warm as _warm_typecache
    }
    _invalidate_typecache(cls);

    _warm_typecache(cls);
    try {
        cls.__jac_fingerprint__ = Serializer.fingerprint(cls);
    } except Exception as e {
        logger.debug(f"Failed to compute fingerprint for {cls.__name__}: {e}");
        cls.__jac_fingerprint__ = '';
    }

    import from jaclang.runtimelib.schema_rules { collect_rules }
    if (rules := collect_rules(cls)) {
        for old_name in rules.was_names {
            Serializer.register_alias(old_name, cls);
        }
    }
}

impl Serializer.register_alias(old_name: str, cls: type) -> None {
    new_name = f"{cls.__module__}.{cls.__name__}";
    if old_name == new_name {
        logger.debug(f"archetype_alias: {old_name} == current name; alias is a no-op");
        return;
    }
    Serializer._aliases[old_name] = new_name;
}

impl Serializer.repair(data: dict[str, object], cls: type) -> tuple {
    import from jaclang.runtimelib.schema_rules {
        apply_rules,
        merged_rules_for,
        repair_mode
    }
    mode = repair_mode();
    if mode == 'off' {
        return (data, []);
    }
    rules = merged_rules_for(cls);
    if rules is None {
        return (data, []);
    }
    (repaired, steps) = apply_rules(data, rules);
    if repaired is data and not steps {
        return (data, []);
    }
    if mode == 'detect' {
        if steps {
            logger.info(
                f"Serializer: drift detected on {cls.__module__}.{cls.__name__} "
                f"(JAC_SCHEMA_REPAIR=detect; steps not applied: {steps})"
            );
        }
        return (data, []);
    }
    if steps {
        logger.info(f"Serializer: repaired {cls.__module__}.{cls.__name__}: {steps}");
    }

    return (repaired, steps);
}

impl Serializer.coerce(val: object, target_type: object) -> tuple {
    if target_type is None or isinstance(target_type, str) {
        return (val, False);
    }

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

        for variant in non_none {
            (coerced, ok) = Serializer.coerce(val, variant);
            if ok {
                return (coerced, True);
            }
        }
        return (val, False);
    }

    base = origin if origin is not None else target_type;
    if not isinstance(base, type) {
        return (val, True);
    }
    if val is None {
        return (None, False);
    }
    if isinstance(val, base) {
        return (val, True);
    }

    try {
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
            try {
                return (base(val), True);
            } except (ValueError, KeyError) {
                members = getattr(base, '__members__', {});
                if isinstance(val, str) and val in members {
                    return (members[val], True);
                }
            }
        }

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

impl Serializer.fingerprint(cls: type) -> str {
    field_pairs: list[list[str]] = [];
    if is_dataclass(cls) {
        for f in fields(cls) {
            field_pairs.append([f.name, str(f.type)]);
        }
    }
    field_pairs.sort(key=lambda (p: list) { p[0]; });
    payload = {'module': cls.__module__, 'name': cls.__name__, 'fields': field_pairs};
    encoded = _json_dumps(payload, sort_keys=True, default=str).encode('utf-8');
    return sha256(encoded).hexdigest()[:FINGERPRINT_LENGTH];
}

impl Serializer._get_class(module_name: str, class_name: str) -> (type | None) {
    if not module_name or not class_name {
        return None;
    }
    key = f"{module_name}.{class_name}";
    if (cls := Serializer._registry.get(key)) {
        return cls;
    }

    if (aliased_key := Serializer._aliases.get(key)) {
        if (cls := Serializer._registry.get(aliased_key)) {
            logger.info(f"Serializer: resolving aliased class {key} -> {aliased_key}");
            return cls;
        }

        if Serializer._should_warn_once("alias-missing", key) {
            logger.warning(
                f"Serializer: alias {key} -> {aliased_key} has no registered "
                "target; cannot resolve."
            );
        }
        return None;
    }
    if Serializer._should_warn_once("unregistered", key) {
        logger.warning(f"Refused to deserialize unregistered class: {key}");
    }
    return None;
}

impl Serializer._should_warn_once(scope: str, key: str) -> bool {
    dedup_key = f"{scope}:{key}";
    seen = Serializer._warned_class_keys;
    if dedup_key in seen {
        return False;
    }
    if Serializer._warn_dedup_saturated {
        if logger.isEnabledFor(logging.DEBUG) {
            logger.debug(
                f"Serializer: warning suppressed (dedup cap reached): {dedup_key}"
            );
        }
        return False;
    }
    with Serializer._warn_lock {
        if dedup_key in seen {
            return False;
        }
        if len(seen) >= _MAX_WARNED_CLASS_KEYS {
            if not Serializer._warn_dedup_saturated {
                Serializer._warn_dedup_saturated = True;
                logger.warning(
                    f"Serializer: warning dedup cache reached {_MAX_WARNED_CLASS_KEYS} "
                    "distinct keys; further first-occurrence warnings are suppressed "
                    "(enable DEBUG to still see suppressed keys)."
                );
            }
            return False;
        }
        seen.add(dedup_key);
        return True;
    }
}

impl Serializer._reset_warn_cache -> None {
    with Serializer._warn_lock {
        Serializer._warned_class_keys.clear();
        Serializer._warn_dedup_saturated = False;
    }
}

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
                arch_key = f"{arch_data.get('__module__')}.{arch_data.get('__type__')}";
                if Serializer._should_warn_once("archetype-failed", arch_key) {
                    logger.warning(
                        "Serializer: archetype reconstruction failed for "
                        f"{arch_key}; dropping anchor (caller should quarantine)."
                    );
                }
                return None;
            }
            anchor.archetype = archetype;
        }
        if isinstance(anchor, NodeAnchor) {
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

            setattr(
                anchor,
                '_initial_edge_ids',
                frozenset(UUID(eid) for eid in (edge_ids or []))
            );

            anchor.version = data.get('version', 0);

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

impl Serializer._deserialize_archetype(
    data: dict[str, object], anchor: Anchor
) -> (object | None) {
    import from jaclang.runtimelib.schema_rules { ATTIC_KEY, REPAIRS_ATTR, repair_mode }
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
    mode = repair_mode();
    (data, repair_steps) = Serializer.repair(data, cls);
    try {
        arch: object = cls.__new__(cls);
        field_types = get_field_types(cls);
        known = set(field_types.keys());
        attic: dict = {};

        stored_attic = data.get(ATTIC_KEY);
        if isinstance(stored_attic, dict) {
            attic.update(stored_attic);
        }
        dropped: list[str] = [];
        assigned: set[str] = set();
        for (k, v) in data.items() {
            if k.startswith('__') {
                continue;
            }
            deser_v = Serializer._deserialize_value(v);
            if k not in known {
                dropped.append(k);
                if mode == 'repair' {
                    attic[k] = {'value': deser_v, 'reason': 'unknown'};
                }
                continue;
            }
            target = field_types[k];
            (coerced, ok) = Serializer.coerce(deser_v, target);
            if not ok {
                field_key = f"{module_name}.{type_name}.{k}";
                origin = get_origin(target);
                args = get_args(target);
                is_optional = (
                    (origin is Union or origin is UnionType) and NoneType in args
                );
                if deser_v is None and not is_optional {
                    recovered: object = None;
                    has_default = False;
                    for fd in fields(cls) {
                        if fd.name == k {
                            if fd.default_factory is not MISSING {
                                recovered = fd.default_factory();
                                has_default = True;
                            } elif fd.default is not MISSING {
                                recovered = fd.default;
                                has_default = True;
                            }
                            break;
                        }
                    }
                    if not has_default {
                        if Serializer._should_warn_once(
                            "stored-none-no-default", field_key
                        ) {
                            logger.warning(
                                f"Serializer: {module_name}.{type_name}.{k}: stored None "
                                f"on non-Optional field {target} and no class default "
                                "available; cannot recover."
                            );
                        }
                        return None;
                    }
                    if Serializer._should_warn_once(
                        "stored-none-defaulted", field_key
                    ) {
                        logger.warning(
                            f"Serializer: {module_name}.{type_name}.{k}: stored None "
                            f"on non-Optional field {target}; restored class default."
                        );
                    }
                    setattr(arch, k, recovered);
                    assigned.add(k);
                    continue;
                }
                if Serializer._should_warn_once("coercion-fallback", field_key) {
                    logger.warning(
                        f"Serializer: coercion fallback on {module_name}."
                        f"{type_name}.{k}: stored={type(deser_v).__name__}, "
                        f"target={target}; stored value kept as-is."
                    );
                }
            }
            setattr(arch, k, coerced);
            assigned.add(k);
        }
        if dropped {
            if mode == 'repair' {
                logger.info(
                    f"Serializer: preserved unknown fields in attic on "
                    f"{module_name}.{type_name}: {sorted(dropped)}"
                );
            } else {
                logger.debug(
                    f"Serializer: dropped removed fields on {module_name}."
                    f"{type_name}: {sorted(dropped)}"
                );
            }
        }

        for fd in fields(cls) {
            if fd.name in assigned {
                continue;
            }
            if fd.default_factory is not MISSING {
                setattr(arch, fd.name, fd.default_factory());
            } elif fd.default is MISSING {
                if Serializer._should_warn_once(
                    "required-missing", f"{module_name}.{type_name}.{fd.name}"
                ) {
                    logger.warning(
                        f"Serializer: {module_name}.{type_name}.{fd.name}: "
                        "required field missing from stored data and no default "
                        "available; attribute left unset."
                    );
                }
            }
        }
        if attic {
            setattr(arch, ATTIC_KEY, attic);
        }
        if repair_steps {
            setattr(arch, REPAIRS_ATTR, repair_steps);
        }
        setattr(arch, '__jac__', anchor);
        return arch;
    } except Exception as e {
        logger.error(f"Failed to deserialize archetype {type_name}: {e}");
        return None;
    }
}

impl Serializer.serialize_fields(
    anchor: object, field_names: set[str]
) -> dict[str, object] {
    if not hasattr(anchor, 'is_populated') or not anchor.is_populated() {
        return {};
    }
    arch = anchor.archetype;
    if arch is None {
        return {};
    }
    known = set(get_field_types(type(arch)).keys());
    _seen: tuple[set, set] = (set(), set());
    result: dict[str, object] = {};
    for name in field_names & known {
        val = getattr(arch, name, None);
        result[name] = Serializer._serialize_value(val, include_type=True, _seen=_seen);
    }

    if result and hasattr(type(arch), '__jac_schema__') {
        import from jaclang.runtimelib.schema_rules { merged_rules_for, repair_mode }
        if repair_mode() == 'repair' and (rules := merged_rules_for(type(arch))) {
            for a in rules.aliases {
                if a.new_name in result {
                    result[a.stored_name] = result[a.new_name];
                }
            }
        }
    }
    return result;
}

impl Serializer._compute_hash(anchor: Anchor) -> int {
    import from json { dumps }
    try {
        data = Serializer.serialize(anchor, include_type=True);
        return hash(dumps(data, sort_keys=True));
    } except Exception {
        return 0;
    }
}
