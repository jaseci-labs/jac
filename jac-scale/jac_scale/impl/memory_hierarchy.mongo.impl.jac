"""MongoDB PersistenceBackend Implementation."""

"""Post-initialization: connect to MongoDB and load DB-resident aliases.

On connect we also ensure the companion collections exist as logical
concepts: `<collection>_quarantine` holds unloadable anchors, and
`<collection>_aliases` holds DB-resident class-rename aliases that the
Serializer consults on every class lookup. Mongo auto-creates
collections on first write, so all we do here is load any existing
aliases into the in-process Serializer map.
"""
impl MongoBackend.postinit -> None {
    if self.mongo_url is None {
        self.mongo_url = _get_db_config().get('mongodb_uri');
    }
    if self.mongo_url {
        if 'mongo_client' not in _process_cache {
            try {
                _process_cache['mongo_client'] = MongoClient(self.mongo_url);
            } except Exception as e {
                logger.warning(f"MongoDB connection failed: {e}");
            }
        }
        self.client = _process_cache.get('mongo_client');
        if self.client {
            self.db = self.client[self.db_name];
            self.collection = self.db[self.collection_name];
        }
    }
    if self.client is not None {
        try {
            self._load_db_aliases();
        } except Exception as e {
            logger.debug(f"MongoBackend: alias preload skipped: {e}");
        }
    }
}

"""Get the `_quarantine` companion collection."""
def _mongo_q_collection(backend: MongoBackend) -> Any {
    return backend.db[backend.collection_name + '_quarantine'];
}

"""Get the `_aliases` companion collection."""
def _mongo_a_collection(backend: MongoBackend) -> Any {
    return backend.db[backend.collection_name + '_aliases'];
}

"""Return True when the anchor's outer document must be fully rewritten."""
def _anchor_has_structural_change(anchor: Anchor) -> bool {
    return anchor.hash == 0;
}

"""Stable hash of any serialized field value (dict, list, or scalar)."""
def _field_hash(val: object) -> int {
    import from json { dumps }
    try {
        return hash(dumps(val, sort_keys=True, default=str));
    } except Exception {
        return hash(str(val));
    }
}

"""Snapshot per-field hashes onto the archetype after a successful save or load."""
def _snapshot_field_hashes(anchor: Anchor) -> None {
    if not anchor.is_populated() or anchor.archetype is None {
        return;
    }
    arch = anchor.archetype;
    known = Serializer._get_field_types(type(arch)).keys();
    _seen: tuple[set, set] = (set(), set());
    hashes: dict[str, int] = {};
    for name in known {
        val = getattr(arch, name, None);
        serialized = Serializer._serialize_value(val, include_type=True, _seen=_seen);
        hashes[name] = _field_hash(serialized);
    }
    object.__setattr__(arch, '__jac_field_hashes__', hashes);
}

"""Derive the dirty field set by comparing current field hashes to the stored snapshot."""
def _derive_dirty_from_field_hashes(anchor: Anchor) -> set[str] {
    if not anchor.is_populated() or anchor.archetype is None {
        return set();
    }
    arch = anchor.archetype;
    stored: dict[str, int] = arch.__dict__.get('__jac_field_hashes__', {});
    known = Serializer._get_field_types(type(arch)).keys();
    dirty: set[str] = set();
    _seen: tuple[set, set] = (set(), set());
    for name in known {
        val = getattr(arch, name, None);
        serialized = Serializer._serialize_value(val, include_type=True, _seen=_seen);
        if _field_hash(serialized) != stored.get(name) {
            dirty.add(name);
        }
    }
    return dirty;
}

"""Build a stored document for an anchor, including Layer 2 fingerprint
and Layer 1 archetype identity fields. Parallels _anchor_to_row in
SqliteMemory; kept here so schema evolution stays per-backend."""
def _anchor_to_doc(anchor: Anchor) -> dict {
    data = Serializer.serialize(anchor, include_type=True);
    anchor_type = type(anchor).__name__;
    arch_module: (str | None) = None;
    arch_type: (str | None) = None;
    fingerprint: (str | None) = None;
    if anchor.is_populated() and anchor.archetype is not None {
        arch = anchor.archetype;
        arch_module = type(arch).__module__;
        arch_type = type(arch).__name__;
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) and fp else None;
    }
    return {
        'type': anchor_type,
        'arch_module': arch_module,
        'arch_type': arch_type,
        'fingerprint': fingerprint,
        'data': data,
        'format_version': 1,
        'updated_at': datetime.now(timezone.utc).isoformat()
    };
}

"""Move an unreadable document into the quarantine collection.

Never raises: we'd rather fail loud on load (caller quarantines + None)
than leak exceptions into walker traversal.
"""
def _mongo_quarantine(
    backend: MongoBackend,
    id_str: str,
    anchor_type: (str | None),
    arch_module: (str | None),
    arch_type: (str | None),
    fingerprint: (str | None),
    data: Any,
    error: str,
    from_format_version: (int | None) = None
) {
    try {
        _mongo_q_collection(backend).update_one(
            {'_id': id_str},
            {
                '$set': {
                    'type': anchor_type,
                    'arch_module': arch_module,
                    'arch_type': arch_type,
                    'fingerprint': fingerprint,
                    'data': data,
                    'error': error,
                    'quarantined_at': datetime.now(timezone.utc).isoformat(),
                    'from_format_version': from_format_version
                }
            },
            upsert=True
        );
        backend.collection.delete_one({'_id': id_str});
    } except Exception as e {
        logger.error(f"MongoBackend: failed to quarantine {id_str}: {e}");
    }
}

"""Set reference to parent TieredMemory's __mem__ for sync()."""
impl MongoBackend.set_memory_ref(mem: dict[UUID, Anchor]) -> None {
    self._mem_ref = mem;
}

"""Check if MongoDB is available and connected."""
impl MongoBackend.is_available -> bool {
    # Only cache a confirmed True — caching False would prevent later contexts
    # (e.g. test files that configure MongoDB after others that don't) from ever
    # reaching MongoDB in the same process.
    if _process_cache.get('mongo_available') is True {
        return True;
    }
    if not self.mongo_url {
        self.mongo_url = _get_db_config().get('mongodb_uri');
    }
    if not self.mongo_url or self.client is None {
        return False;
    }
    try {
        self.client.admin.command('ping', maxTimeMS=100);
        _process_cache['mongo_available'] = True;
        return True;
    } except ConnectionFailure {
        _process_cache['mongo_available'] = False;
        return False;
    } except Exception as e {
        logger.debug(f"MongoDB availability check failed: {e}");
        _process_cache['mongo_available'] = False;
        return False;
    }
}

"""Get anchor by UUID from MongoDB.

On any deserialization failure or unresolvable archetype class, the row
is moved to the `_quarantine` collection (never silently dropped) so an
operator can inspect and recover with `jac db` — parallel to the
SqliteMemory contract.
"""
impl MongoBackend.get(id: UUID) -> (Anchor | None) {
    if self.client is None {
        return None;
    }
    _id = to_uuid(id);
    try {
        db_obj = self.collection.find_one({'_id': str(_id)});
    } except Exception as e {
        logger.debug(f"MongoDB get failed: {e}");
        return None;
    }
    if not db_obj {
        return None;
    }
    anchor_type = db_obj.get('type');
    arch_module = db_obj.get('arch_module');
    arch_type = db_obj.get('arch_type');
    fingerprint = db_obj.get('fingerprint');
    data = db_obj.get('data');
    fmt_version = db_obj.get('format_version');
    # Fingerprint drift check (INFO-only; best-effort load proceeds below).
    if arch_module and arch_type and fingerprint {
        cls = Serializer._get_class(arch_module, arch_type);
        current_fp = cls?.__jac_fingerprint__ if cls else None;
        if current_fp and current_fp != fingerprint {
            logger.info(
                f"MongoBackend: schema drift on {arch_module}.{arch_type} "
                f"(stored={fingerprint}, current={current_fp}, id={id}); "
                "attempting best-effort load."
            );
        }
    }
    try {
        anchor = Serializer.deserialize(data) if data is not None else None;
    } except Exception as e {
        logger.warning(
            f"MongoBackend: failed to deserialize anchor {id} "
            f"({arch_module}.{arch_type}): {type(e).__name__}: {e}. "
            "Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            str(_id),
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"deserialize error: {type(e).__name__}: {e}",
            from_format_version=fmt_version
        );
        return None;
    }
    if anchor is None {
        logger.warning(
            f"MongoBackend: class {arch_module}.{arch_type} unresolvable "
            f"for anchor {id}. Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            str(_id),
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"class {arch_module}.{arch_type} unresolvable",
            from_format_version=fmt_version
        );
        return None;
    }
    _snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}

"""Stage anchor for persistence — all writes are deferred to sync()."""
impl MongoBackend.put(anchor: Anchor) -> None { }

"""Full document upsert for an anchor. Used by sync() when no partial or
atomic-edge path applies (first insert, or non-NodeAnchor full rewrite)."""
impl MongoBackend._write_to_db(anchor: Anchor) -> None {
    if self.client is None or not anchor.persistent {
        return;
    }
    _id = to_uuid(anchor.id);
    arch = anchor.archetype if anchor.is_populated() else None;
    try {
        doc = _anchor_to_doc(anchor);
        self.collection.update_one({'_id': str(_id)}, {'$set': doc}, upsert=True);
        anchor.hash = Serializer._compute_hash(anchor);
        if arch is not None {
            arch.__dict__.pop('__jac_dirty_fields__', None);
        }
        _snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB _write_to_db failed: {e}");
    }
}

"""Persist only the specified archetype fields without replacing the full document."""
impl MongoBackend.put_partial(anchor: Anchor, field_names: set[str]) -> None {
    if self.client is None or not anchor.persistent or not field_names {
        return;
    }
    _id = to_uuid(anchor.id);
    try {
        partial_data = Serializer.serialize_fields(anchor, field_names);
        if not partial_data {
            return;
        }
        update: dict[str, object] = {
            f"data.archetype.{k}": v for (k, v) in partial_data.items()
        };
        update['updated_at'] = datetime.now(timezone.utc).isoformat();
        self.collection.update_one({'_id': str(_id)}, {'$set': update});
        anchor.hash = Serializer._compute_hash(anchor);
        arch = anchor.archetype if anchor.is_populated() else None;
        if arch is not None {
            arch.__dict__.pop('__jac_dirty_fields__', None);
        }
        _snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB put_partial failed: {e}");
    }
}

"""Delete anchor from MongoDB."""
impl MongoBackend.delete(id: UUID) -> None {
    if self.client is None {
        return;
    }
    _id = to_uuid(id);
    try {
        self.collection.delete_one({'_id': str(_id)});
    } except Exception as e {
        logger.debug(f"MongoDB delete failed: {e}");
    }
}

"""Flush pending writes and release local reference to the shared client."""
impl MongoBackend.close -> None {
    try {
        self.sync();
    } except Exception as e {
        logger.warning(f"MongoBackend.close sync failed: {e}");
    }
    # Don't close the shared process-level client; just drop local reference.
    self.client = None;
    self._mem_ref = None;
}

"""Check if an anchor exists in MongoDB."""
impl MongoBackend.`has(id: UUID) -> bool {
    if self.client is None {
        return False;
    }
    _id = to_uuid(id);
    try {
        return self.collection.count_documents({'_id': str(_id)}, limit=1) > 0;
    } except Exception {
        return False;
    }
}

"""Query all anchors with optional filter."""
impl MongoBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    if self.client is None {
        return;
    }
    try {
        for doc in self.collection.find() {
            if (anchor := self._load_anchor(doc)) {
                if filter is None or filter(anchor) {
                    yield anchor;
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB query failed: {e}");
    }
}

"""Get all root anchors."""
impl MongoBackend.get_roots -> Generator[Root, None, None] {
    for anchor in self.query() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl MongoBackend.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl MongoBackend.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Commit - no-op for MongoDB (writes are immediate)."""
impl MongoBackend.commit(anchor: (Anchor | None) = None) -> None {
# No-op: MongoDB writes are immediate
}

# PersistentMemory-specific methods
"""Sync - flush L1 memory to MongoDB (only changed anchors)."""
impl MongoBackend.sync -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    if not self._mem_ref or not self.client {
        return;
    }
    for (_, anchor) in list(self._mem_ref.items()) {
        if not anchor.persistent {
            continue;
        }
        # Check hash first — skip unchanged anchors without access check
        current_hash = Serializer._compute_hash(anchor);
        if current_hash == anchor.hash {
            continue;
        }
        if not Jac.check_write_access(anchor) {
            continue;
        }
        try {
            # NodeAnchors with a load snapshot: atomic edge-merge pipeline
            # preserves edge changes from sibling walkers.
            if isinstance(anchor, NodeAnchor) {
                delta = anchor.edge_delta();
                if delta is not None {
                    added = [str(eid) for eid in delta[0]];
                    removed = [str(eid) for eid in delta[1]];
                    self._put_node_atomic(anchor, added, removed);
                    continue;
                }
            }
            # Union __setattr__-tracked fields (direct assignments) with
            # field-hash-derived fields (in-place mutations) to get the complete
            # dirty set. Both must be combined — running only one silently drops
            # the other category (e.g. direct + in-place in the same request).
            if anchor.hash != 0 {
                arch = anchor.archetype if anchor.is_populated() else None;
                setattr_dirty: set[str] = (
                    arch.__dict__.get('__jac_dirty_fields__') or set()
                ).copy()
                    if arch is not None
                    else set();
                derived = _derive_dirty_from_field_hashes(anchor);
                dirty = setattr_dirty | derived;
                if dirty {
                    self.put_partial(anchor, dirty);
                    continue;
                }
            }
            # First insert (hash == 0) or no field changes found — full upsert.
            self._write_to_db(anchor);
        } except Exception as e {
            logger.warning(f"MongoDB sync failed for anchor {anchor.id}: {e}");
        }
    }
}

"""Atomically update a NodeAnchor, merging edge changes with DB state."""
impl MongoBackend._put_node_atomic(
    anchor: NodeAnchor, edges_added: list[str], edges_removed: list[str]
) -> None {
    if self.client is None {
        return;
    }
    _id = str(to_uuid(anchor.id));
    try {
        data: dict[str, object] = dict(Serializer.serialize(anchor, include_type=True));
        # Separate edge list from the rest of the serialized data
        data_no_edges = {
            k: v
            for (k, v) in data.items()
            if k != 'edges'
        };
        # Single atomic operation: merge non-edge fields + apply edge delta
        self.collection.update_one(
            {'_id': _id},
            [
                {
                    '$set': {
                        'data': {
                            '$mergeObjects': [
                                '$data',
                                data_no_edges,
                                {
                                    'edges': {
                                        '$setUnion': [
                                            {
                                                '$setDifference': [
                                                    {'$ifNull': ['$data.edges', []]},
                                                    edges_removed
                                                ]
                                            },
                                            edges_added
                                        ]
                                    }
                                }
                            ]
                        },
                        'type': 'NodeAnchor'
                    }
                }
            ],
            upsert=True
        );
        anchor.hash = Serializer._compute_hash(anchor);
        _snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB _put_node_atomic failed: {e}");
    }
}

"""Bulk store multiple anchors with Layer 1+2 fingerprint + metadata."""
impl MongoBackend.bulk_put(anchors: Iterable[Anchor]) -> None {
    if self.client is None {
        return;
    }
    ops: list = [];
    for anchor in anchors {
        if not anchor.persistent {
            continue;
        }
        _id = to_uuid(anchor.id);
        try {
            doc = _anchor_to_doc(anchor);
            ops.append(UpdateOne({'_id': str(_id)}, {'$set': doc}, upsert=True));
        } except Exception as e {
            logger.debug(f"MongoDB bulk_put serialization failed: {e}");
        }
    }
    if ops {
        try {
            self.collection.bulk_write(ops);
        } except Exception as e {
            logger.debug(f"MongoDB bulk_write failed: {e}");
        }
    }
}

"""Batch get multiple anchors by ID using MongoDB $in query."""
impl MongoBackend.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    if self.client is None or not ids {
        return result;
    }
    str_ids = [str(to_uuid(id)) for id in ids];
    try {
        for doc in self.collection.find({'_id': {'$in': str_ids}}) {
            if (anchor := self._load_anchor(doc)) {
                anchor.is_updated = False;
                result[UUID(doc['_id'])] = anchor;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB batch_get failed: {e}");
    }
    return result;
}

"""Load anchor from raw MongoDB document, quarantining on failure."""
impl MongoBackend._load_anchor(raw: dict[(str, Any)]) -> (Anchor | None) {
    if 'data' not in raw {
        return None;
    }
    doc_id = str(raw.get('_id', ''));
    anchor_type = raw.get('type');
    arch_module = raw.get('arch_module');
    arch_type = raw.get('arch_type');
    fingerprint = raw.get('fingerprint');
    fmt_version = raw.get('format_version');
    data = raw['data'];
    try {
        anchor = Serializer.deserialize(data);
    } except Exception as e {
        logger.warning(
            f"MongoBackend: failed to deserialize anchor (id={doc_id}, "
            f"type={anchor_type}): {type(e).__name__}: {e}. "
            "Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            doc_id,
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"deserialize error: {type(e).__name__}: {e}",
            from_format_version=fmt_version
        );
        return None;
    }
    if anchor is None {
        logger.warning(
            f"MongoBackend: class {arch_module}.{arch_type} unresolvable "
            f"for anchor {doc_id}. Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            doc_id,
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"class {arch_module}.{arch_type} unresolvable",
            from_format_version=fmt_version
        );
        return None;
    }
    _snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}


# ----------------------------------------------------------------------
# Layer 1+2+3 operator surface — parity with SqliteMemory.
# ----------------------------------------------------------------------
"""Attempt to re-deserialize one quarantined Mongo doc, re-stamped with
the live class's identity + fingerprint on success. Returns (ok, reason)."""
def _mongo_attempt_recover(backend: MongoBackend, doc: dict) -> tuple {
    doc_id = str(doc.get('_id', ''));
    data = doc.get('data');
    arch_module = doc.get('arch_module');
    arch_type = doc.get('arch_type');
    if data is None {
        return (False, "no data payload stored");
    }
    try {
        anchor = Serializer.deserialize(data);
    } except Exception as e {
        return (False, f"deserialize raised: {type(e).__name__}: {e}");
    }
    if anchor is None {
        return (False, f"class {arch_module}.{arch_type} still unresolvable");
    }
    # Re-stamp with live class metadata.
    re_doc = _anchor_to_doc(cast(Anchor, anchor));
    try {
        backend.collection.update_one({'_id': doc_id}, {'$set': re_doc}, upsert=True);
        _mongo_q_collection(backend).delete_one({'_id': doc_id});
    } except Exception as e {
        return (False, f"write-back failed: {type(e).__name__}: {e}");
    }
    return (True, "recovered");
}


"""Helper: shape a Mongo quarantine doc into the CLI-expected format."""
def _format_q_doc(d: dict) -> dict {
    return {
        'id': d.get('_id'),
        'type': d.get('type'),
        'arch_module': d.get('arch_module'),
        'arch_type': d.get('arch_type'),
        'fingerprint': d.get('fingerprint'),
        'error': d.get('error'),
        'quarantined_at': d.get('quarantined_at'),
        'from_format_version': d.get('from_format_version'),
        'data': d.get('data')
    };
}


"""Summary for `jac db inspect`."""
impl MongoBackend.inspect_summary -> dict {
    loc = (
        (self.mongo_url or '<no mongo url>') + '/' + self.db_name + '.' + self.collection_name
    );
    if self.client is None {
        return {
            'format_version': '?',
            'anchors_total': 0,
            'anchors_by_type': [],
            'quarantine_total': 0,
            'quarantine_by_type': [],
            'aliases_total': 0,
            'location': loc
        };
    }
    pipeline = [
        {'$group': {'_id': '$arch_type', 'count': {'$sum': 1}}},
        {'$sort': {'count': -1}}
    ];
    try {
        anchors_by = [
            (doc.get('_id') or '<none>', doc.get('count', 0))
            for doc in self.collection.aggregate(pipeline)
        ];
    } except Exception {
        anchors_by = [];
    }
    try {
        qby = [
            (doc.get('_id') or '<none>', doc.get('count', 0))
            for doc in _mongo_q_collection(self).aggregate(pipeline)
        ];
    } except Exception {
        qby = [];
    }
    try {
        alias_count = _mongo_a_collection(self).count_documents({});
    } except Exception {
        alias_count = 0;
    }
    return {
        'format_version': '1',
        'anchors_total': sum(r[1] for r in anchors_by),
        'anchors_by_type': anchors_by,
        'quarantine_total': sum(r[1] for r in qby),
        'quarantine_by_type': qby,
        'aliases_total': alias_count,
        'location': loc
    };
}


"""List the N most recent quarantined documents."""
impl MongoBackend.list_quarantined(limit: int = 50) -> list {
    if self.client is None {
        return [];
    }
    try {
        docs = list(
            _mongo_q_collection(self).find().sort('quarantined_at', -1).limit(limit)
        );
    } except Exception {
        return [];
    }
    return [
        {
            'id': str(d.get('_id', '')),
            'arch': ((d.get('arch_module') or '?') + '.' + (d.get('arch_type') or '?')),
            'fingerprint': str(d.get('fingerprint') or ''),
            'error': str(d.get('error') or ''),
            'quarantined_at': str(d.get('quarantined_at') or '')
        } for d in docs
    ];
}


"""Full detail of one quarantined document (by id or unique prefix)."""
impl MongoBackend.show_quarantined(id_prefix: str) -> (dict | None) {
    if self.client is None {
        return None;
    }
    try {
        exact = _mongo_q_collection(self).find_one({'_id': id_prefix});
        if exact {
            return _format_q_doc(exact);
        }
        import re;
        pattern = '^' + re.escape(id_prefix);
        docs = list(
            _mongo_q_collection(self).find({'_id': {'$regex': pattern}}).limit(2)
        );
    } except Exception {
        return None;
    }
    if not docs {
        return None;
    }
    if len(docs) > 1 {
        return {'error': 'ambiguous', 'count': len(docs)};
    }
    return _format_q_doc(docs[0]);
}


"""Recover a single quarantined document (by id or unique prefix)."""
impl MongoBackend.recover_one(id_prefix: str) -> tuple {
    if self.client is None {
        return (False, "no mongodb connection");
    }
    self._load_db_aliases();
    try {
        exact = _mongo_q_collection(self).find_one({'_id': id_prefix});
        if exact {
            return _mongo_attempt_recover(self, exact);
        }
        import re;
        pattern = '^' + re.escape(id_prefix);
        docs = list(
            _mongo_q_collection(self).find({'_id': {'$regex': pattern}}).limit(2)
        );
    } except Exception as e {
        return (False, f"mongo query failed: {e}");
    }
    if not docs {
        return (False, f"no quarantined row matching {id_prefix}");
    }
    if len(docs) > 1 {
        return (False, f"prefix {id_prefix} matches multiple rows");
    }
    return _mongo_attempt_recover(self, docs[0]);
}


"""Recover every quarantined document."""
impl MongoBackend.recover_all -> tuple {
    if self.client is None {
        return (0, []);
    }
    self._load_db_aliases();
    try {
        docs = list(_mongo_q_collection(self).find());
    } except Exception {
        return (0, []);
    }
    recovered = 0;
    still_stuck: list = [];
    for d in docs {
        (ok, reason) = _mongo_attempt_recover(self, d);
        if ok {
            recovered += 1;
        } else {
            still_stuck.append((str(d.get('_id', '')), reason));
        }
    }
    return (recovered, still_stuck);
}


"""List DB-resident aliases."""
impl MongoBackend.list_aliases -> list {
    if self.client is None {
        return [];
    }
    try {
        docs = list(_mongo_a_collection(self).find().sort('created_at', 1));
    } except Exception {
        return [];
    }
    return [
        {
            'old_name': str(d.get('_id', '')),
            'new_name': str(d.get('new_name', '')),
            'created_at': str(d.get('created_at', ''))
        } for d in docs
    ];
}


"""Add or replace a DB-resident alias; merge into Serializer registry."""
impl MongoBackend.add_alias(old_name: str, new_name: str) -> None {
    if self.client is None {
        return;
    }
    now = datetime.now(timezone.utc).isoformat();
    try {
        _mongo_a_collection(self).update_one(
            {'_id': old_name},
            {'$set': {'new_name': new_name, 'created_at': now}},
            upsert=True
        );
    } except Exception as e {
        logger.error(f"MongoBackend: add_alias failed: {e}");
        return;
    }
    Serializer._aliases[old_name] = new_name;
}


"""Remove a DB-resident alias. Returns True if an entry was deleted."""
impl MongoBackend.remove_alias(old_name: str) -> bool {
    if self.client is None {
        return False;
    }
    try {
        result = _mongo_a_collection(self).delete_one({'_id': old_name});
    } except Exception as e {
        logger.error(f"MongoBackend: remove_alias failed: {e}");
        return False;
    }
    removed = result.deleted_count > 0;
    if removed {
        Serializer._aliases.pop(old_name, None);
    }
    return removed;
}


"""Get anchor by UUID using native Motor (no asyncio.to_thread)."""
impl MongoBackend.aget(id: UUID) -> (Anchor | None) {
    import from jac_scale._optdeps.motor { AsyncIOMotorClient, HAS_MOTOR }
    if not HAS_MOTOR or AsyncIOMotorClient is None or self.mongo_url is None {
        return await super.aget(id);
    }
    motor_client = AsyncIOMotorClient(self.mongo_url);
    coll = motor_client[self.db_name][self.collection_name];
    try {
        db_obj = await coll.find_one({'_id': str(to_uuid(id))});
        if not db_obj {
            return None;
        }
        return self._load_anchor(db_obj);
    } except Exception as e {
        logger.debug(f"Motor aget failed: {e}");
        return None;
    } finally {
        motor_client.close();
    }
}

"""Store anchor using native Motor (no asyncio.to_thread)."""
impl MongoBackend.aput(anchor: Anchor) -> None { }

"""Flush dirty anchors via Motor (no asyncio.to_thread)."""
impl MongoBackend.acommit(anchor: (Anchor | None) = None) -> None {
    import from jac_scale._optdeps.motor { AsyncIOMotorClient, HAS_MOTOR }
    if not HAS_MOTOR or AsyncIOMotorClient is None or self.mongo_url is None {
        await super.acommit(anchor);
        return;
    }
    if self._mem_ref is None {
        await super.acommit(anchor);
        return;
    }
    motor_client = AsyncIOMotorClient(self.mongo_url);
    coll = motor_client[self.db_name][self.collection_name];
    dirty = [];
    targets = [anchor] if anchor is not None else list(self._mem_ref.values());
    for a in targets {
        if a.persistent and Jac.check_write_access(a) {
            dirty.append(a);
        }
    }
    if dirty {
        ops = [
            UpdateOne({'_id': str(a.id)}, {'$set': _anchor_to_doc(a)}, upsert=True)
            for a in dirty
        ];
        try {
            await coll.bulk_write(ops, ordered=False);
        } except Exception as e {
            logger.warning(f"Motor acommit bulk_write failed: {e}");
        }
    }
    motor_client.close();
}

"""Load DB-resident aliases into the in-process Serializer registry."""
impl MongoBackend._load_db_aliases -> int {
    if self.client is None {
        return 0;
    }
    count = 0;
    try {
        for doc in _mongo_a_collection(self).find() {
            old_name = doc.get('_id');
            new_name = doc.get('new_name');
            if isinstance(old_name, str) and isinstance(new_name, str) {
                Serializer._aliases[old_name] = new_name;
                count += 1;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoBackend: _load_db_aliases skipped: {e}");
    }
    return count;
}
