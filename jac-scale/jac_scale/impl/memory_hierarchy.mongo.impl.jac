"""MongoDB PersistenceBackend Implementation."""

import from jac_scale.microservices.runtime.tracing {
    start_memory_span,
    end_memory_span
}
import from jaclang.runtimelib.exceptions { WriteConflict }

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
        try {
            self.ensure_indexes();
        } except Exception as e {
            logger.debug(f"MongoBackend: index creation skipped: {e}");
        }
        # Deploy-the-fix-and-data-heals: with classes, aliases, and drift
        # rules now registered, re-attempt quarantined docs this deploy may
        # have fixed. Never blocks startup on failure.
        try {
            self._auto_retry_quarantine();
        } except Exception as e {
            logger.debug(f"MongoBackend: quarantine auto-retry skipped: {e}");
        }
    }
}


"""Create indexes that make type-based pushdown queries efficient.

Idempotent -- `create_index` is a no-op when an index of the same shape and
name already exists, so this can be called on every connect without cost.

The compound `(arch_type, type)` index is what makes `execute_plan`
worthwhile: queries that filter by archetype type (the common case, e.g.
"all `User` nodes connected to root R") become IXSCAN instead of COLLSCAN.
A descending `updated_at` index supports recency-based ops without forcing
a full sort.
"""
impl MongoBackend.ensure_indexes -> None {
    if self.collection is None {
        return;
    }
    import from pymongo { ASCENDING, DESCENDING }
    self.collection.create_index(
        [('arch_type', ASCENDING), ('type', ASCENDING)],
        name='arch_type_1_type_1',
        background=True
    );
    self.collection.create_index(
        [('updated_at', DESCENDING)], name='updated_at_-1', background=True
    );
}

"""Get the `_quarantine` companion collection."""
def _mongo_q_collection(backend: MongoBackend) -> any {
    return backend.db[backend.collection_name + '_quarantine'];
}

"""Get the `_aliases` companion collection."""
def _mongo_a_collection(backend: MongoBackend) -> any {
    return backend.db[backend.collection_name + '_aliases'];
}

"""Return True when the anchor's outer document must be fully rewritten."""
def _anchor_has_structural_change(anchor: Anchor) -> bool {
    return anchor.hash == 0;
}

# Field-hash dirty detection lives in jaclang.runtimelib.changeset -- one
# shared implementation for the runtime's collect pass and every backend.
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

"""Persist a read-repaired anchor back to its document (lazy migration).

The Serializer records applied drift-rule steps on the archetype
(`__jac_schema_repairs__`); when present, the upgraded form is written
back with compare-and-set on the originally stored fingerprint, so a
concurrent writer on an older code version cleanly wins and the doc
simply repairs again on its next read. Never raises -- a failed
write-back just means the repair re-runs next load (idempotent).
"""
def _mongo_persist_repairs(
    backend: MongoBackend, id_str: str, anchor: Anchor, stored_fp: (str | None)
) -> None {
    arch = anchor.archetype if anchor.is_populated() else None;
    if arch is None {
        return;
    }
    steps = arch.__dict__.get('__jac_schema_repairs__');
    if not steps {
        return;
    }
    try {
        doc = _anchor_to_doc(anchor);
        result = backend.collection.update_one(
            {'_id': id_str, 'fingerprint': stored_fp}, {'$set': doc}
        );
        if result.matched_count {
            logger.info(
                f"MongoBackend: persisted read-repair of {id_str} "
                f"({doc.get('arch_module')}.{doc.get('arch_type')}): {steps}"
            );
            if backend._l2_ref {
                backend._l2_ref.delete(to_uuid(anchor.id));
            }
        } else {
            logger.info(
                f"MongoBackend: read-repair write-back of {id_str} skipped "
                "(concurrent write since load); will repair on next read."
            );
        }
        # Either way the in-memory anchor is current; drop the marker so a
        # later full save doesn't re-log this as a fresh repair.
        arch.__dict__.pop('__jac_schema_repairs__', None);
    } except Exception as e {
        logger.warning(f"MongoBackend: read-repair write-back of {id_str} failed: {e}");
    }
}


"""Move an unreadable document into the quarantine collection.

Never raises: we'd rather fail loud on load (caller quarantines + None)
than leak exceptions into walker traversal.

`reason_code` is a stable, machine-readable classification used by the
startup auto-retry to decide which quarantined docs a new deploy might
fix: CLASS_MISSING (archetype unresolvable), FIELD_RECONSTRUCT (class
resolved but field deserialization failed), DESER_ERROR (deserialize
raised), CASCADE (edge orphaned by a quarantined node).

When quarantining a NodeAnchor, also cascade-quarantine every EdgeAnchor
whose data.source or data.target references this node, then strip those
edge IDs from all remaining live NodeAnchor data.edges arrays. This
prevents dangling edge references after schema drift removes a node type.
"""
def _mongo_quarantine(
    backend: MongoBackend,
    id_str: str,
    anchor_type: (str | None),
    arch_module: (str | None),
    arch_type: (str | None),
    fingerprint: (str | None),
    data: any,
    error: str,
    from_format_version: (int | None) = None,
    l2: (any | None) = None,
    reason_code: str = 'DESER_ERROR'
) {
    try {
        q_col = _mongo_q_collection(backend);
        now_ts = datetime.now(timezone.utc).isoformat();
        q_col.update_one(
            {'_id': id_str},
            {
                '$set': {
                    'type': anchor_type,
                    'arch_module': arch_module,
                    'arch_type': arch_type,
                    'fingerprint': fingerprint,
                    'data': data,
                    'error': error,
                    'reason_code': reason_code,
                    'quarantined_at': now_ts,
                    'from_format_version': from_format_version
                }
            },
            upsert=True
        );
        backend.collection.delete_one({'_id': id_str});
        if l2 {
            l2.delete(to_uuid(id_str));
            l2.publish_invalidation(str(to_uuid(id_str)), None);
        }
        # Cascade: when a NodeAnchor is quarantined, orphan its edges too.
        if anchor_type == 'NodeAnchor' {
            orphaned_edges = list(
                backend.collection.find(
                    {
                        'type': 'EdgeAnchor',
                        '$or': [{'data.source': id_str}, {'data.target': id_str}]
                    }
                )
            );
            if orphaned_edges {
                orphan_edge_ids = [e['_id'] for e in orphaned_edges];
                # Capture nodes whose edge lists will be mutated BEFORE the update_many
                # so we can invalidate their Redis entries after the Mongo write.
                affected_node_ids = [];
                if l2 {
                    affected_nodes = backend.collection.find(
                        {'type': 'NodeAnchor', 'data.edges': {'$in': orphan_edge_ids}},
                        {'_id': 1}
                    );
                    affected_node_ids = [doc['_id'] for doc in affected_nodes];
                }
                cascade_error = f"cascade quarantine: connected node {id_str} was quarantined";
                cascade_ops = [
                    UpdateOne(
                        {'_id': edge_doc['_id']},
                        {
                            '$set': {
                                'type': edge_doc.get('type'),
                                'arch_module': edge_doc.get('arch_module'),
                                'arch_type': edge_doc.get('arch_type'),
                                'fingerprint': edge_doc.get('fingerprint'),
                                'data': edge_doc.get('data'),
                                'error': cascade_error,
                                'reason_code': 'CASCADE',
                                'quarantined_at': now_ts,
                                'from_format_version': edge_doc.get('format_version')
                            }
                        },
                        upsert=True
                    ) for edge_doc in orphaned_edges
                ];
                q_col.bulk_write(cascade_ops, ordered=False);
                backend.collection.delete_many({'_id': {'$in': orphan_edge_ids}});
                if l2 {
                    for eid in orphan_edge_ids {
                        l2.delete(to_uuid(eid));
                        l2.publish_invalidation(str(to_uuid(eid)), None);
                    }
                }
                backend.collection.update_many(
                    {'type': 'NodeAnchor', 'data.edges': {'$in': orphan_edge_ids}},
                    {'$pullAll': {'data.edges': orphan_edge_ids}}
                );
                if l2 {
                    for nid in affected_node_ids {
                        l2.delete(to_uuid(nid));
                        l2.publish_invalidation(str(to_uuid(nid)), None);
                    }
                }
                logger.info(
                    f"MongoBackend: cascade-quarantined {len(orphan_edge_ids)} edge(s) "
                    f"connected to quarantined node {id_str}."
                );
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend: failed to quarantine {id_str}: {e}");
    }
}

"""Store a reference to the L2 cache so quarantine operations can invalidate it."""
impl MongoBackend.set_cache_ref(cache: (any | None)) -> None {
    self._l2_ref = cache;
}

"""Record the owning context's L1 id so this backend's broadcasts self-exclude."""
impl MongoBackend.set_l1_id(l1_id: str) -> None {
    self._l1_id = l1_id;
}

"""Check if MongoDB is available and connected."""
impl MongoBackend.is_available -> bool {
    # Only cache a confirmed True -- caching False would prevent later contexts
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
operator can inspect and recover with `jac db` -- parallel to the
SqliteMemory contract.
"""
impl MongoBackend.get(id: UUID) -> (Anchor | None) {
    if self.client is None {
        return None;
    }
    self.fetch_count += 1;
    _id = to_uuid(id);
    span = start_memory_span(
        "memory.get mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "get"}
    );
    try {
        db_obj = self.collection.find_one({'_id': str(_id)});
    } except Exception as e {
        logger.debug(f"MongoDB get failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
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
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code='DESER_ERROR'
        );
        return None;
    }
    if anchor is None {
        cls_resolved = (
            Serializer._get_class(arch_module, arch_type)
                if (arch_module and arch_type)
                else None
        );
        if cls_resolved is None {
            reason = f"class {arch_module}.{arch_type} unresolvable";
            code = 'CLASS_MISSING';
            logger.warning(
                f"MongoBackend: class {arch_module}.{arch_type} unresolvable "
                f"for anchor {id}. Moving to quarantine."
            );
        } else {
            reason = f"archetype field deserialization failed: {arch_module}.{arch_type}";
            code = 'FIELD_RECONSTRUCT';
            logger.warning(
                f"MongoBackend: archetype field deserialization failed for "
                f"{arch_module}.{arch_type} (anchor {id}). Moving to quarantine."
            );
        }
        _mongo_quarantine(
            self,
            str(_id),
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            reason,
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code=code
        );
        return None;
    }
    _mongo_persist_repairs(self, str(_id), cast(Anchor, anchor), fingerprint);
    snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}

"""Stage anchor for persistence -- all writes are deferred to sync()."""
impl MongoBackend.put(anchor: Anchor) -> None { }

"""Full document upsert for an anchor. Used by sync() when no partial or
atomic-edge path applies (first insert, or non-NodeAnchor full rewrite)."""
impl MongoBackend._write_to_db(anchor: Anchor) -> None {
    if self.client is None or not anchor.persistent {
        return;
    }
    self.put_count += 1;
    _id = to_uuid(anchor.id);
    arch = anchor.archetype if anchor.is_populated() else None;
    try {
        doc = _anchor_to_doc(anchor);
        self.collection.update_one({'_id': str(_id)}, {'$set': doc}, upsert=True);
        anchor.hash = Serializer._compute_hash(anchor);
        snapshot_field_hashes(anchor);
    } except Exception as e {
        # Propagate: apply() must know a structural write failed so it can
        # poison dependents instead of minting a dangling reference.
        logger.error(f"MongoDB _write_to_db failed: {e}");
        raise;
    }
}

"""Persist only the specified archetype fields without replacing the full document."""
impl MongoBackend.put_partial(anchor: Anchor, field_names: set[str]) -> None {
    if self.client is None or not anchor.persistent or not field_names {
        return;
    }
    _id = to_uuid(anchor.id);
    try {
        # Classic operator $set (below) accepts empty dicts; no strip needed.
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
        snapshot_field_hashes(anchor);
    } except Exception as e {
        logger.error(f"MongoDB put_partial failed: {e}");
        raise;
    }
}

"""Forget backend-local cache state for an anchor. MongoBackend keeps no
local cache, so this is a no-op: the document is removed by apply()
executing a delete intent, in dependency order with the edge-list repairs
that must precede it -- never inline (issue #6587)."""
impl MongoBackend.delete(id: UUID) -> None { }

"""Release local reference to the shared client. Flushing is the runtime's
job (commit -> apply); close must not write."""
impl MongoBackend.close -> None {
    # Don't close the shared process-level client; just drop local reference.
    self.client = None;
    self._l2_ref = None;
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

"""Get all root anchors using an indexed type filter (no full collection scan).

Uses the `(arch_type, type)` compound index -- IXSCAN, not COLLSCAN. The
Python-side `isinstance` check is kept as a defense-in-depth filter in case
schema drift left a non-Root archetype with `arch_type='Root'`.
"""
impl MongoBackend.get_roots -> Generator[Root, None, None] {
    if self.client is None {
        return;
    }
    try {
        for doc in self.collection.find({'arch_type': 'Root', 'type': 'NodeAnchor'}) {
            if (anchor := self._load_anchor(doc)) {
                if isinstance(anchor.archetype, Root) {
                    yield cast(Root, anchor.archetype);
                }
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB get_roots failed: {e}");
    }
}


"""Declare MongoDB's native pushdown capabilities.

MongoDB can apply: archetype-type filter (compound index), arbitrary
declarative field predicates (`data.archetype.<f>` paths), `_id IN (...)`
narrowing (primary index), and contiguous slicing (`skip`+`limit`).

The planner combines these with the topology_index narrowing automatically
-- see `jaclang.runtimelib.planner` for the strategy chooser.
"""
impl MongoBackend.capabilities -> set[str] {
    return {'type_pushdown', 'field_pushdown', 'id_in', 'slice'};
}


"""Translate a QueryPlan into the MongoDB filter dict + cursor options.

Filter shape (only includes keys the plan actually populates):
  - `arch_type`: archetype class name (final hop's `node_type` or `node_type_final`)
  - `type`: 'NodeAnchor' (we only push down node queries -- edges are handled
            via the source/target subdoc separately, not by execute_plan)
  - `_id`:  `{'$in': [...]}` when the planner narrowed via topology_index
  - `data.archetype.<f>`: each archetype-field predicate, value passed through
                          verbatim (MongoDB operator dicts like `{'$lt': 28}`
                          work as-is)

Returns (filter_dict, skip, limit). When slc has a step != 1 we leave skip/
limit at None and let the planner slice the result list (Mongo can't apply
strided slicing natively).
"""
def _plan_to_mongo_filter(plan: QueryPlan) -> tuple[dict, int, (int | None)] {
    filt: dict = {};
    # Prefer the explicit `node_type_final`; otherwise pick the final hop's
    # node_type so single-hop plans like `[root -->User]` push down cleanly.
    type_name = plan.node_type_final;
    if type_name is None and plan.chain {
        type_name = plan.chain[-1].node_type;
    }
    if type_name {
        filt['arch_type'] = type_name;
        filt['type'] = 'NodeAnchor';
    }
    if plan.id_in is not None {
        filt['_id'] = {'$in': [str(u) for u in plan.id_in]};
    }
    for (k, v) in plan.field_predicates.items() {
        filt[f'data.archetype.{k}'] = v;
    }
    skip_n: int = 0;
    limit_n: (int | None) = None;
    if plan.slc is not None {
        step = plan.slc.step;
        if step is None or step == 1 {
            start = plan.slc.start or 0;
            stop = plan.slc.stop;
            skip_n = start;
            if stop is not None {
                limit_n = max(0, stop - start);
            }
        }
    }
    return (filt, skip_n, limit_n);
}


"""Native MongoDB execution of a QueryPlan.

This is the backend's pushdown entry point. The planner only calls us when
`plan.needs() <= self.capabilities()`, so we can assume:
  - any chain in the plan has been already narrowed (`plan.id_in` carries
    the candidate UUIDs) OR there is no chain (a pure type/field query)
  - `field_predicates` use cross-backend operators (`$eq`, `$lt`, `$in`...)
  - `slc` is either absent or contiguous-step (we early-rejected stepped
    slices by leaving skip/limit as None -- caller applies them)

We never raise to the caller: any error logs at debug and returns an empty
generator so the planner can fall back if it wants to.
"""
impl MongoBackend.execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None] {
    if self.client is None {
        return;
    }
    (filt, skip_n, limit_n) = _plan_to_mongo_filter(plan);
    try {
        cursor = self.collection.find(filt);
        if skip_n {
            cursor = cursor.skip(skip_n);
        }
        if limit_n is not None {
            cursor = cursor.limit(limit_n);
        }
        for doc in cursor {
            if (anchor := self._load_anchor(doc)) {
                yield anchor;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB execute_plan failed ({filt}): {e}");
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
"""Flush a unit of work in dependency order -- the changeset's stages.

MongoDB multi-document transactions require a replica set, which many
deployments (and the standalone default) don't run, so crash-safety comes
from ORDER: truncating this sequence at any point can only leave an
unreferenced document (orphan), never a dangling reference. A failed
structural write poisons its dependents (e.g. a node delete after a failed
edge delete is skipped) instead of corrupting the graph. Decision logic
(what changed, access control) ran in the runtime's collect pass -- this
method only executes intents."""
impl MongoBackend.apply(changeset: ChangeSet) -> ApplyReport {
    apply_report = ApplyReport();
    if changeset.is_empty() or self.client is None {
        return apply_report;
    }
    span = start_memory_span(
        "memory.apply mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "apply"}
    );
    try {
        poisoned: set[UUID] = set();
        # OCC precheck: a read-gated intent (cas_version set) whose stored
        # version already moved means this request lost the race. Detect it
        # BEFORE staging any writes, so the loser's child/edge docs are never
        # written -- MongoDB has no cross-document rollback here, so prevention
        # beats compensation. The in-line CAS in _put_node_atomic stays as the
        # backstop for the narrow window where a winner commits *during* this
        # apply (after the precheck read); any orphan from that window is
        # collected by `jac db fsck` (half-linked-edge sweep).
        # Collect the read-gated intents (cas_version set) and read their stored
        # versions in ONE $in query, so a walker that read several nodes still
        # costs a single round-trip rather than one find per node.
        read_gated: dict[str, int] = {};
        for stage in changeset.staged() {
            for intent in stage {
                if intent.cas_version is not None {
                    read_gated[str(to_uuid(intent.anchor.id))] = intent.cas_version;
                }
            }
        }
        precheck: list = [];
        if read_gated {
            stored_versions: dict[str, int] = {};
            for vdoc in self.collection.find(
                {'_id': {'$in': list(read_gated.keys())}}, {'data.version': 1}
            ) {
                stored_versions[str(vdoc.get('_id'))] = int(
                    vdoc.get('data', {}).get('version', 0)
                );
            }
            # Absent docs are omitted from stored_versions -> skipped here, so
            # the staged CAS path (upsert=False -> no match -> conflict) is what
            # handles a node that vanished since this request read it.
            for (gid, expected) in read_gated.items() {
                if gid in stored_versions and stored_versions[gid] != expected {
                    precheck.append(
                        WriteConflict(
                            anchor_id=to_uuid(gid),
                            expected_version=expected,
                            actual_version=stored_versions[gid]
                        )
                    );
                }
            }
        }
        if precheck {
            # Abort the whole unit of work: write nothing. The request
            # boundary replays (retry) or fails (fail). A partial apply would
            # orphan the loser's just-written child.
            for wc in precheck {
                apply_report.failed[wc.anchor_id] = wc.message();
                apply_report.conflicts.append(wc);
            }
            if span {
                span.set_attribute("mem.count", 0);
            }
            return apply_report;
        }
        for stage in changeset.staged() {
            for intent in stage {
                if (deps := intent.depends_on & poisoned) {
                    dep = next(iter(deps));
                    apply_report.skipped[intent.anchor.id] = f"dependency {dep} failed";
                    poisoned.add(intent.anchor.id);
                    logger.error(
                        f"MongoDB apply: skipping {intent.op.name} on "
                        f"{intent.anchor.id}: dependency {dep} failed"
                    );
                    continue;
                }
                try {
                    self._apply_one(intent);
                    apply_report.applied.append(intent.anchor.id);
                } except WriteConflict as wc {
                    # Optimistic-concurrency miss: poison like any failed write
                    # (skips dependents), but carry the typed conflict so
                    # commit() can raise it and the boundary can replay. DEBUG,
                    # not ERROR: a losing racer is expected, not noise.
                    poisoned.add(intent.anchor.id);
                    apply_report.failed[intent.anchor.id] = wc.message();
                    apply_report.conflicts.append(wc);
                    logger.debug(
                        f"MongoDB apply: write conflict on {intent.anchor.id}: "
                        f"{wc.message()}"
                    );
                } except Exception as e {
                    poisoned.add(intent.anchor.id);
                    apply_report.failed[intent.anchor.id] = str(e);
                    logger.error(
                        f"MongoDB apply: {intent.op.name} failed for "
                        f"{intent.anchor.id}: {type(e).__name__}: {e}"
                    );
                }
            }
        }
        if span {
            span.set_attribute("mem.count", len(apply_report.applied));
        }
        return apply_report;
    } finally {
        end_memory_span(span);
    }
}

"""Execute one intent against MongoDB."""
impl MongoBackend._apply_one(intent: WriteIntent) -> None {
    anchor = intent.anchor;
    if intent.is_delete() {
        self.collection.delete_one({'_id': str(to_uuid(anchor.id))});
        return;
    }
    if intent.op == WriteOp.EDGE_LIST_DELTA {
        self._put_node_atomic(
            cast(NodeAnchor, anchor),
            [str(eid) for eid in intent.edges_added],
            [str(eid) for eid in intent.edges_removed],
            intent.fields,
            intent.cas_version
        );
        return;
    }
    if intent.op == WriteOp.FIELD_UPDATE {
        self.put_partial(anchor, intent.fields);
        return;
    }
    # NODE_CREATE / EDGE_CREATE (and full merged rewrites): whole-document upsert.
    self._write_to_db(anchor);
}

"""Atomically update a NodeAnchor, merging the intent's archetype fields and
edge delta with DB state. `fields` comes from the runtime's collect pass --
the single owner of dirty detection AND write-access decisions. Re-deriving
dirtiness here would persist fields the collect pass never authorized."""
impl MongoBackend._put_node_atomic(
    anchor: NodeAnchor,
    edges_added: list[str],
    edges_removed: list[str],
    fields: set[str],
    cas_version: (int | None) = None
) -> None {
    if self.client is None {
        return;
    }
    _id = str(to_uuid(anchor.id));
    try {
        # Serialize the intent's dirty archetype fields (`fields` = collect pass's dirty set, the sole owner of dirty detection).
        partial_data: dict[str, object] = Serializer.serialize_fields(anchor, fields)
            if fields
            else {};

        # Non-archetype top-level fields (e.g. access), whole-object replaced.
        # 'version' is excluded: it's bumped via $inc below, not $set verbatim.
        full = dict(Serializer.serialize(anchor, include_type=True));
        non_arch_top = {
            k: v
            for (k, v) in full.items()
            if k not in ('edges', 'archetype', 'version')
        };

        # Pipeline $set evaluates values as expressions (bare {} → error 40180, $-keys misread); wrap all data in $literal to store verbatim, leaving data.edges the only expression.
        set_doc: dict[str, object] = {
            'type': 'NodeAnchor',
            'updated_at': datetime.now(timezone.utc).isoformat()
        };
        for (k, v) in non_arch_top.items() {
            set_doc[f"data.{k}"] = {'$literal': v};
        }
        for (k, v) in partial_data.items() {
            set_doc[f"data.archetype.{k}"] = {'$literal': v};
        }
        # Order-preserving edge merge (issue #6785): out-edge order is part of
        # OSP semantics (connection/insertion order), so it must survive the
        # atomic merge. $setUnion / $setDifference return *sets* — they sort and
        # dedup, discarding array order — so they cannot be used here. Instead
        # keep existing edges in place ($filter out the removed ones) and append
        # only the genuinely-new added edges ($filter out any already present,
        # which keeps the merge idempotent under write retries).
        set_doc['data.edges'] = {
            '$let': {
                'vars': {'cur': {'$ifNull': ['$data.edges', []]}},
                'in': {
                    '$concatArrays': [
                        {
                            '$filter': {
                                'input': '$$cur',
                                'as': 'e',
                                'cond': {'$not': [{'$in': ['$$e', edges_removed]}]}
                            }
                        },
                        {
                            '$filter': {
                                'input': edges_added,
                                'as': 'e',
                                'cond': {'$not': [{'$in': ['$$e', '$$cur']}]}
                            }
                        }
                    ]
                }
            }
        };
        # Bump the OCC version as part of the same atomic update.
        set_doc['data.version'] = {'$add': [{'$ifNull': ['$data.version', 0]}, 1]};

        import from pymongo { ReturnDocument }
        # Read-set OCC: CAS on the version only when this request READ a
        # traversal from this node (cas_version set). A blind append takes no
        # dependency -> plain upsert + $setUnion merges lock-free (#5644).
        cas_filter: dict = {'_id': _id};
        if cas_version is not None {
            # A doc written before this feature shipped has no `data.version`;
            # MongoDB equality won't match a missing field, so when the request
            # expects v0 also accept the absent case (treat absent == 0). This
            # keeps legacy nodes from spuriously conflicting on first write.
            if cas_version == 0 {
                cas_filter = {
                    '_id': _id,
                    '$or': [{'data.version': 0}, {'data.version': {'$exists': False}}]
                };
            } else {
                cas_filter = {'_id': _id, 'data.version': cas_version};
            }
        }
        merged_doc = self.collection.find_one_and_update(
            cas_filter,
            [{'$set': set_doc}],
            projection={'data.edges': 1, 'data.version': 1},
            upsert=(cas_version is None),
            return_document=ReturnDocument.AFTER
            # upsert only on the no-CAS (blind append) path: a version miss must
            # NOT mint a spurious duplicate doc.
        );
        if merged_doc is None {
            # Version-gated path (upsert=False) with no match: the node moved or
            # vanished since this request read it. Either way the optimistic
            # assumption failed -> conflict, and the request boundary replays
            # (re-reading the now-current graph). We do NOT fall back to an
            # upsert here: that read-then-upsert was a TOCTOU window, and an
            # EDGE_LIST_DELTA only targets a node the request already loaded, so
            # a genuinely absent doc is itself a stale-read to converge on.
            # The find_one is diagnostic only (best-effort actual version).
            actual = -1;
            existing = self.collection.find_one({'_id': _id}, {'data.version': 1});
            if existing is not None {
                actual = existing.get('data', {}).get('version', -1);
            }
            raise WriteConflict(
                anchor_id=anchor.id, expected_version=cas_version, actual_version=actual
            );
        }

        if self._l2_ref {
            try {
                self._l2_ref.invalidate(anchor.id);
                # Evict siblings' stale pre-write edge list cross-pod.
                self._l2_ref.publish_invalidation(str(anchor.id), self._l1_id);
            } except Exception as inv_err {
                logger.debug(
                    f"MongoDB _put_node_atomic L2 invalidation failed: {inv_err}"
                );
            }
        }

        try {
            if merged_doc {
                merged_ids_str: list = merged_doc.get('data', {}).get('edges', [])
                or [];
                merged_ids: set = {
                    UUID(s)
                    for s in merged_ids_str
                    if s
                };
                object.__setattr__(anchor, '_initial_edge_ids', frozenset(merged_ids));
                anchor.edges = [
                    e
                    for e in anchor.edges
                    if e.id in merged_ids
                ];
                # Re-baseline the local OCC version to the just-committed one,
                # so a subsequent commit this request CASes on the right value.
                anchor.version = merged_doc.get('data', {}).get(
                    'version', anchor.version + 1
                );
            }
        } except Exception as rb_err {
            logger.debug(f"MongoDB _put_node_atomic read-back failed: {rb_err}");
        }

        anchor.hash = Serializer._compute_hash(anchor);
        try {
            snapshot_field_hashes(anchor);
        } except Exception as shf_err {
            logger.debug(
                f"MongoDB _put_node_atomic _snapshot_field_hashes failed: {shf_err}"
            );
        }
    } except WriteConflict {
        # Expected under contention; apply() records + commit() raises it.
        raise;
    } except Exception as e {
        logger.error(f"MongoDB _put_node_atomic failed: {e}");
        raise;
    }
}

"""Batch get multiple anchors by ID using MongoDB $in query."""
impl MongoBackend.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    if self.client is None or not ids {
        return result;
    }
    self.fetch_count += len(ids);
    str_ids = [str(to_uuid(id)) for id in ids];
    span = start_memory_span(
        "memory.batch_get mongodb",
        {
            "db.system": "mongodb",
            "mem.tier": "L3",
            "mem.op": "batch_get",
            "mem.count": len(ids)
        }
    );
    try {
        for doc in self.collection.find({'_id': {'$in': str_ids}}) {
            if (anchor := self._load_anchor(doc)) {
                anchor.is_updated = False;
                result[UUID(doc['_id'])] = anchor;
            }
        }
    } except Exception as e {
        logger.debug(f"MongoDB batch_get failed: {e}");
    } finally {
        end_memory_span(span);
    }
    return result;
}

"""Reset get/put counters (for instrumentation/tests)."""
impl MongoBackend.reset_counters -> None {
    self.fetch_count = 0;
    self.put_count = 0;
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
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code='DESER_ERROR'
        );
        return None;
    }
    if anchor is None {
        cls_resolved = (
            Serializer._get_class(arch_module, arch_type)
                if (arch_module and arch_type)
                else None
        );
        code = 'CLASS_MISSING' if cls_resolved is None else 'FIELD_RECONSTRUCT';
        logger.warning(
            f"MongoBackend: failed to load {arch_module}.{arch_type} "
            f"for anchor {doc_id} ({code}). Moving to quarantine."
        );
        _mongo_quarantine(
            self,
            doc_id,
            anchor_type,
            arch_module,
            arch_type,
            fingerprint,
            data,
            f"load failed for class {arch_module}.{arch_type}",
            from_format_version=fmt_version,
            l2=self._l2_ref,
            reason_code=code
        );
        return None;
    }
    _mongo_persist_repairs(self, doc_id, cast(Anchor, anchor), fingerprint);
    snapshot_field_hashes(cast(Anchor, anchor));
    return cast(Anchor, anchor);
}


# ----------------------------------------------------------------------
# Layer 1+2+3 operator surface -- parity with SqliteMemory.
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
    # Re-link: when recovering an EdgeAnchor that was cascade-quarantined, the
    # connected node(s)' data.edges was stripped. Re-add the edge ID to the
    # source (always) and also to the target for undirected edges.
    if doc.get('type') == 'EdgeAnchor' and isinstance(data, dict) {
        source_id = data.get('source');
        target_id = data.get('target');
        is_undirected = bool(data.get('is_undirected', False));
        relink_ids: list = [
            n
            for n in [source_id]
            if n
        ];
        if is_undirected and target_id and target_id != source_id {
            relink_ids.append(target_id);
        }
        for node_id in relink_ids {
            try {
                result = backend.collection.update_one(
                    {'_id': node_id, 'type': 'NodeAnchor'},
                    {'$addToSet': {'data.edges': doc_id}}
                );
                if result.matched_count == 0 {
                    logger.warning(
                        f"MongoBackend: recover re-link of edge {doc_id} "
                        f"to node {node_id} skipped: node not live in collection"
                    );
                }
            } except Exception as relink_err {
                logger.warning(
                    f"MongoBackend: recover re-link of edge {doc_id} "
                    f"to node {node_id} failed: {relink_err}"
                );
            }
        }
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
        'reason_code': d.get('reason_code'),
        'quarantined_at': d.get('quarantined_at'),
        'from_format_version': d.get('from_format_version'),
        'retry_count': d.get('retry_count'),
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
            'reason_code': str(d.get('reason_code') or ''),
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
    # Process NodeAnchors before EdgeAnchors so re-link finds live nodes.
    docs.sort(key=lambda d : 0 if d.get('type') == 'NodeAnchor' else 1);
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


"""File a dangling reference under DANGLING_REF (read-path healer hook).

Mirrors SqliteMemory.quarantine_dangling: upsert into the `_quarantine`
companion collection keyed by the missing referent's id, with the shared
DANGLING_REF reason_code so `jac db quarantine list/show` and the startup
auto-retry treat it uniformly. Idempotent; never raises."""
impl MongoBackend.quarantine_dangling(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    if self.client is None {
        return;
    }
    try {
        q_col = _mongo_q_collection(self);
        now_ts = datetime.now(timezone.utc).isoformat();
        anchor_type = 'EdgeAnchor' if kind == 'edge' else 'NodeAnchor';
        ref_str = str(to_uuid(referrer_id)) if referrer_id is not None else '?';
        mid = str(to_uuid(missing_id));
        err = f"DANGLING_REF: missing {kind} {mid} cited by {ref_str}";
        q_col.update_one(
            {'_id': mid},
            {
                '$set': {
                    'type': anchor_type,
                    'arch_module': None,
                    'arch_type': 'DANGLING_REF',
                    'fingerprint': None,
                    'data': {'referrer': ref_str, 'kind': kind},
                    'error': err,
                    'reason_code': 'DANGLING_REF',
                    'quarantined_at': now_ts,
                    'from_format_version': None
                }
            },
            upsert=True
        );
    } except Exception as e {
        logger.error(f"MongoBackend: failed to record dangling ref {missing_id}: {e}");
    }
}


"""True if `id` is quarantined under a recoverable reason. DANGLING_REF docs
are excluded (they are the read-path healer's own forensic records), so a
genuine dangler keeps being pruned instead of mistaken for schema drift."""
impl MongoBackend.is_recoverable_quarantine(id: UUID) -> bool {
    if self.client is None {
        return False;
    }
    try {
        return _mongo_q_collection(self).find_one(
            {'_id': str(to_uuid(id)), 'reason_code': {'$ne': 'DANGLING_REF'}},
            {'_id': 1}
        ) is not None;
    } except Exception {
        return False;
    }
}


"""Scan the anchor collection for referential-integrity violations; optionally
repair. See the PersistentMemory.fsck contract for the report shape. Repair
prunes dangling citations (`$pullAll`), files each under DANGLING_REF, and
collects orphan/broken edge + node docs (`delete_many`), invalidating L2."""
impl MongoBackend.fsck(repair: bool = False) -> dict {
    loc = (
        (self.mongo_url or '<no mongo url>') + '/' + self.db_name + '.' + self.collection_name
    );
    fsck_report: dict = {
        'location': loc,
        'dangling_node_edge': [],
        'dangling_edge_node': [],
        'orphan_edges': [],
        'orphan_nodes': [],
        # Edges cited by exactly one of their two (existing) endpoints -- the
        # optimistic-concurrency orphan signature (a loser's child + edge that
        # the root's edge-list CAS refused after the docs were written, in the
        # narrow window the apply() precheck can't cover). (edge, citing, rejecting).
        'half_linked_edges': [],
        'repaired': repair,
        'repaired_counts': {'pruned': 0, 'quarantined': 0, 'collected': 0}
    };
    if self.client is None {
        return fsck_report;
    }
    node_ids: set[str] = set();
    edge_ids: set[str] = set();
    node_edges: dict[str, list[str]] = {};
    edge_endpoints: dict[str, tuple[(str | None), (str | None)]] = {};
    node_is_root: dict[str, bool] = {};
    try {
        for doc in self.collection.find(
            {}, {'_id': 1, 'type': 1, 'arch_type': 1, 'data': 1}
        ) {
            rid = str(doc.get('_id'));
            rtype = doc.get('type');
            d = doc.get('data') or {};
            if rtype == 'NodeAnchor' {
                node_ids.add(rid);
                node_edges[rid] = [str(e) for e in (d.get('edges') or [])];
                node_is_root[rid] = doc.get('arch_type') == 'Root';
            } elif rtype == 'EdgeAnchor' {
                edge_ids.add(rid);
                src = d.get('source');
                tgt = d.get('target');
                edge_endpoints[rid] = (
                    (str(src) if src is not None else None),
                    (str(tgt) if tgt is not None else None)
                );
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend.fsck: scan failed: {e}");
        return fsck_report;
    }
    cited_edges: set[str] = set();
    for (nid, eids) in node_edges.items() {
        for eid in eids {
            cited_edges.add(eid);
            if eid not in edge_ids {
                fsck_report['dangling_node_edge'].append((nid, eid));
            }
        }
    }
    referenced_nodes: set[str] = set();
    broken_edge_ids: set[str] = set();  # cite a missing node (typed mirror)
    for (eid, endpoints) in edge_endpoints.items() {
        for endp in endpoints {
            if endp is not None {
                referenced_nodes.add(endp);
                if endp not in node_ids {
                    fsck_report['dangling_edge_node'].append((eid, endp));
                    broken_edge_ids.add(eid);
                }
            }
        }
    }
    orphan_edge_ids: set[str] = set();  # cited by nobody (typed mirror)
    for eid in edge_ids {
        if eid not in cited_edges {
            fsck_report['orphan_edges'].append(eid);
            orphan_edge_ids.add(eid);
        }
    }
    # Half-linked edge (OCC orphan signature): both endpoints exist, but only
    # one cites the edge. The non-citing endpoint authoritatively rejected the
    # link (an optimistic-concurrency loser whose root edge-list CAS was
    # refused after its child + edge docs were written). A symmetric edge is
    # healthy; an edge cited by neither endpoint is already an orphan_edge.
    half_linked_ids: set[str] = set();
    for (eid, ep) in edge_endpoints.items() {
        if (
            ep[0] is None
            or ep[1] is None
            or ep[0] not in node_ids
            or ep[1] not in node_ids
        ) {
            continue;  # missing endpoint -> dangling_edge_node, handled
        }
        src = cast(str, ep[0]);
        tgt = cast(str, ep[1]);
        src_cites = src in node_edges and eid in node_edges[src];
        tgt_cites = tgt in node_edges and eid in node_edges[tgt];
        if src_cites != tgt_cites {
            (citing, rejecting) = (src, tgt) if src_cites else (tgt, src);
            fsck_report['half_linked_edges'].append((eid, citing, rejecting));
            half_linked_ids.add(eid);
        }
    }
    # Edges collected on repair (orphan + half-linked + endpoint-missing): a
    # node left edgeless once these go, and unreferenced by any SURVIVING edge,
    # is itself an orphan to collect -- how an OCC loser's stranded child is
    # reclaimed once its half-linked edge is removed.
    collectible_edges: set[str] = orphan_edge_ids | half_linked_ids | broken_edge_ids;
    surviving_referenced: set[str] = set();
    for (eid, ep) in edge_endpoints.items() {
        if eid not in collectible_edges {
            if ep[0] is not None {
                surviving_referenced.add(ep[0]);
            }
            if ep[1] is not None {
                surviving_referenced.add(ep[1]);
            }
        }
    }
    for nid in node_ids {
        remaining = [
            e
            for e in node_edges.get(nid, [])
            if e not in collectible_edges
        ];
        if (
            not node_is_root.get(nid)
            and not remaining
            and nid not in surviving_referenced
        ) {
            fsck_report['orphan_nodes'].append(nid);
        }
    }
    if not repair {
        return fsck_report;
    }
    counts = fsck_report['repaired_counts'];
    try {
        remove_by_node: dict[str, set[str]] = {};
        for (nid, eid) in fsck_report['dangling_node_edge'] {
            remove_by_node.setdefault(nid, set()).add(eid);
            self.quarantine_dangling(to_uuid(eid), to_uuid(nid), 'edge');
            counts['quarantined'] += 1;
        }
        for (eid, nid) in fsck_report['dangling_edge_node'] {
            self.quarantine_dangling(to_uuid(nid), to_uuid(eid), 'node');
            counts['quarantined'] += 1;
        }
        # Broken (cites a missing node) + orphan + half-linked edges; pruning a
        # half-linked edge from its citing endpoint strands the loser's child
        # for the orphan-node collection below. (Typed mirrors built above.)
        collect_edges: set[str] = broken_edge_ids | orphan_edge_ids | half_linked_ids;
        for (nid, eids) in node_edges.items() {
            also = set(eids) & collect_edges;
            if also {
                remove_by_node.setdefault(nid, set()).update(also);
            }
        }
        for (nid, rem) in remove_by_node.items() {
            self.collection.update_one(
                {'_id': nid}, {'$pullAll': {'data.edges': list(rem)}}
            );
            counts['pruned'] += len(rem);
            if self._l2_ref {
                self._l2_ref.delete(to_uuid(nid));
                self._l2_ref.publish_invalidation(nid, None);
            }
        }
        to_collect: list[str] = list(collect_edges) + list(fsck_report['orphan_nodes']);
        if to_collect {
            res = self.collection.delete_many({'_id': {'$in': to_collect}});
            counts['collected'] += res.deleted_count or 0;
            if self._l2_ref {
                for cid in to_collect {
                    self._l2_ref.delete(to_uuid(cid));
                    self._l2_ref.publish_invalidation(cid, None);
                }
            }
        }
    } except Exception as e {
        logger.error(f"MongoBackend.fsck: repair failed: {e}");
        fsck_report['repaired'] = False;
    }
    return fsck_report;
}


"""Auto-retry quarantined documents that a new deploy plausibly fixed.

Runs once at backend startup (after class/alias registration). A doc is
eligible when its archetype class now resolves AND one of: its reason
code is CLASS_MISSING (the class/alias appearing IS the fix signal), the
class declares `__jac_schema__` drift rules (a rule may now repair it),
or it was CASCADE-quarantined (its node may have recovered). Each failed
attempt increments `retry_count`; docs give up loudly after 5. Recovery
itself reuses `_mongo_attempt_recover`, so repaired forms are re-stamped
with the live fingerprint. Gated off when JAC_SCHEMA_REPAIR=off.
"""
impl MongoBackend._auto_retry_quarantine(limit: int = 500) -> tuple {
    import from jaclang.runtimelib.schema_rules { merged_rules_for, repair_mode }
    if self.client is None or repair_mode() == 'off' {
        return (0, 0);
    }
    try {
        docs = list(
            _mongo_q_collection(self).find(
                {
                    '$or': [
                        {'retry_count': {'$exists': False}},
                        {'retry_count': {'$lt': 5}}
                    ]
                }
            ).limit(
                limit
            )
        );
    } except Exception as e {
        logger.debug(f"MongoBackend: quarantine auto-retry scan failed: {e}");
        return (0, 0);
    }
    if not docs {
        return (0, 0);
    }
    # Nodes before edges so cascade re-link finds live nodes.
    docs.sort(key=lambda d : 0 if d.get('type') == 'NodeAnchor' else 1);
    attempted = 0;
    recovered = 0;
    for d in docs {
        cls = Serializer._get_class(d.get('arch_module'), d.get('arch_type'));
        if cls is None {
            continue;
        }
        code = d.get('reason_code');
        if not (
            code == 'CLASS_MISSING'
            or code == 'CASCADE'
            or merged_rules_for(cls) is not None
        ) {
            continue;
        }
        attempted += 1;
        (ok, reason) = _mongo_attempt_recover(self, d);
        if ok {
            recovered += 1;
        } else {
            doc_id = str(d.get('_id', ''));
            try {
                _mongo_q_collection(self).update_one(
                    {'_id': doc_id}, {'$inc': {'retry_count': 1}}
                );
            } except Exception { }
            retries = int(d.get('retry_count') or 0) + 1;
            if retries >= 5 {
                logger.warning(
                    f"MongoBackend: quarantined doc {doc_id} still failing "
                    f"after {retries} auto-retries ({reason}); giving up "
                    "until `jac db recover` is run manually."
                );
            }
        }
    }
    if attempted {
        logger.info(
            f"MongoBackend: quarantine auto-retry attempted {attempted}, "
            f"recovered {recovered} (of {len(docs)} scanned)."
        );
    }
    return (attempted, recovered);
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


"""Get anchor by UUID using PyMongo AsyncMongoClient (no asyncio.to_thread)."""
impl MongoBackend.aget(id: UUID) -> (Anchor | None) {
    import from jac_scale._optdeps.pymongo { AsyncMongoClient }
    if AsyncMongoClient is None or self.mongo_url is None {
        return await super.aget(id);
    }
    if 'async_mongo_client' not in _process_cache {
        _process_cache['async_mongo_client'] = AsyncMongoClient(self.mongo_url);
    }
    coll = _process_cache['async_mongo_client'][self.db_name][self.collection_name];
    span = start_memory_span(
        "memory.get mongodb",
        {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "get"}
    );
    try {
        db_obj = await coll.find_one({'_id': str(to_uuid(id))});
        if not db_obj {
            return None;
        }
        return self._load_anchor(db_obj);
    } except Exception as e {
        logger.debug(f"Async aget failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
    }
}

"""Store anchor using PyMongo AsyncMongoClient (no asyncio.to_thread)."""
impl MongoBackend.aput(anchor: Anchor) -> None { }

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
