"""Typed unit of work over the object graph.

Persisting one graph mutation touches several documents that reference each
other: node docs, edge docs (which cite their endpoints), and both endpoints'
edge-id lists. No backend is guaranteed transactions, so referential
integrity is preserved by ORDER:

    never write a reference before its referent exists;
    never delete a referent while a reference to it remains.

A flush truncated at any point (crash, OOM kill, eviction) may leave an
unreferenced document — an orphan, invisible to traversal and collectable —
but never a dangling reference. This module owns that invariant; backends
(`PersistentMemory.apply`) only execute it. Transactional backends may
collapse all stages into one transaction, where the order is a no-op.

One linear stage order satisfies both directions: creates need
nodes -> edges -> edge-list refs, deletes need refs-gone -> edges -> nodes,
and EDGE_LIST_DELTA (stage 2) is the pivot for both.

This module also hosts the field-hash dirty-detection helpers shared by the
runtime's collect pass and every backend's read path. In-place container
mutation (`node.items.append(x)`) never passes through a setattr hook, so
dirtiness is derived by comparing per-field content hashes against the
snapshot taken at load/persist time.
"""

import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.typecache { get_field_types }
import from jaclang.runtimelib.exceptions { WriteConflict }


enum WriteOp {
    NODE_CREATE = 0,  # new/full node docs first: nothing references them yet
    EDGE_CREATE = 1,  # edge docs next: both endpoints now exist
    EDGE_LIST_DELTA = 2,  # edge-id adds/removals on nodes: added edges exist,
    #   and removals land BEFORE the docs they unhook
    FIELD_UPDATE = 3,  # plain field writes: no topology impact
    EDGE_DELETE = 4,  # edge docs: no edge list cites them anymore
    NODE_DELETE = 5  # node docs last: no edge points at them anymore
}


"""One pending write. `depends_on` lists intents that must succeed before
this one may run — a NODE_DELETE depends on its incident EDGE_DELETEs, an
EDGE_DELETE on its endpoints' edge-list repairs — so "skip dependents when a
write fails" is data, not convention. An EDGE_LIST_DELTA intent may also
carry dirty `fields`; the backend applies both in one merged write."""
obj WriteIntent {
    has op: WriteOp,
        anchor: Anchor,
        fields: set[str] by postinit,
        edges_added: list[UUID] by postinit,
        edges_removed: list[UUID] by postinit,
        depends_on: set[UUID] by postinit,
        # Read-set OCC: the node version this request observed when it read a
        # traversal from this anchor, or None if the request never read it.
        # The backend CASes on it only when set, so a blind append (no read)
        # merges lock-free while a check-then-create conflicts and replays.
        cas_version: (int | None) = None;

    def postinit {
        self.fields = set();
        self.edges_added = [];
        self.edges_removed = [];
        self.depends_on = set();
    }

    def is_delete -> bool {
        return self.op in (WriteOp.EDGE_DELETE, WriteOp.NODE_DELETE);
    }

    def is_create -> bool {
        return self.op in (WriteOp.NODE_CREATE, WriteOp.EDGE_CREATE);
    }
}


"""Result of one `apply()`: which intents landed, which failed with what
error, and which were skipped because a dependency failed (id -> reason)."""
obj ApplyReport {
    has applied: list[UUID] by postinit,
        failed: dict[UUID, str] by postinit,
        skipped: dict[UUID, str] by postinit,
        # Optimistic-concurrency conflicts; commit() raises these so the
        # request boundary can abort + replay the walker (converge).
        conflicts: list[WriteConflict] by postinit;

    def postinit {
        self.applied = [];
        self.failed = {};
        self.skipped = {};
        self.conflicts = [];
    }

    def ok -> bool {
        return not self.failed and not self.skipped;
    }

    """First write conflict with the rest attached as siblings, or None."""
    def primary_conflict -> (WriteConflict | None) {
        if not self.conflicts {
            return None;
        }
        primary = self.conflicts[0];
        if len(self.conflicts) > 1 {
            primary.siblings = self.conflicts[1:];
        }
        return primary;
    }
}


"""The unit of work: at most one intent per anchor, merged as mutations are
recorded. Precedence on merge: delete supersedes everything; a full write
(create) absorbs deltas and field updates; deltas absorb field updates."""
obj ChangeSet {
    has intents: dict[UUID, WriteIntent] by postinit;

    def postinit {
        self.intents = {};
    }

    def is_empty -> bool {
        return not self.intents;
    }

    def clear {
        self.intents = {};
    }

    """Record a brand-new anchor (or an existing one needing a full merged
    rewrite — access/topology changes with no per-field signal)."""
    def record_create(anchor: Anchor) -> None {
        existing = self.intents.get(anchor.id);
        if existing is not None and existing.is_delete() {
            return;
        }
        op = WriteOp.EDGE_CREATE
            if isinstance(anchor, EdgeAnchor)
            else WriteOp.NODE_CREATE;
        if existing is not None {
            existing.op = op;
        } else {
            existing = WriteIntent(op=op, anchor=anchor);
            self.intents[anchor.id] = existing;
        }
        # An edge can't be written before its endpoints exist: a failed
        # endpoint create poisons it (mirrors the delete-direction wiring),
        # so a rejected unique node create never mints a dangling edge.
        if isinstance(anchor, EdgeAnchor) and anchor.is_populated() {
            for endp in (anchor.source, anchor.target) {
                if endp is not None {
                    existing.depends_on.add(endp.id);
                }
            }
        }
    }

    """Record dirty fields on an existing anchor."""
    def record_update(anchor: Anchor, fields: set[str]) -> None {
        existing = self.intents.get(anchor.id);
        if existing is not None {
            if existing.is_delete() {
                return;
            }
            existing.fields |= set(fields);
            return;
        }
        intent = WriteIntent(op=WriteOp.FIELD_UPDATE, anchor=anchor);
        intent.fields |= set(fields);
        self.intents[anchor.id] = intent;
    }

    """Record edge-id additions/removals on a node's edge list. An add and a
    remove of the same id within one unit cancel out."""
    def record_edge_delta(
        anchor: NodeAnchor, added: list[UUID], removed: list[UUID]
    ) -> None {
        existing = self.intents.get(anchor.id);
        if existing is not None and (existing.is_delete() or existing.is_create()) {
            # A delete supersedes; a full write already carries the final
            # edge list — no delta needed.
            return;
        }
        if existing is None {
            existing = WriteIntent(op=WriteOp.EDGE_LIST_DELTA, anchor=anchor);
            self.intents[anchor.id] = existing;
        } elif existing.op == WriteOp.FIELD_UPDATE {
            existing.op = WriteOp.EDGE_LIST_DELTA;
        }
        for eid in added {
            if eid in existing.edges_removed {
                existing.edges_removed.remove(eid);
            } elif eid not in existing.edges_added {
                existing.edges_added.append(eid);
                # The list-add depends on the edge's create; a failed edge
                # (poisoned by a rejected endpoint) skips this list entry too.
                existing.depends_on.add(eid);
            }
        }
        for eid in removed {
            if eid in existing.edges_added {
                existing.edges_added.remove(eid);
                existing.depends_on.discard(eid);
            } elif eid not in existing.edges_removed {
                existing.edges_removed.append(eid);
            }
        }
    }

    """Record a delete and wire its dependency edges. Deleting an edge first
    records the edge-list repair on each endpoint; deleting a node records a
    dependency on each incident edge. Supersedes any earlier intent for the
    same anchor (a created-then-deleted anchor nets out to a harmless
    delete of a row that never existed)."""
    def record_delete(anchor: Anchor) {
        op = WriteOp.EDGE_DELETE
            if isinstance(anchor, EdgeAnchor)
            else WriteOp.NODE_DELETE;
        intent = WriteIntent(op=op, anchor=anchor);
        if isinstance(anchor, EdgeAnchor) and anchor.is_populated() {
            for endp in (anchor.source, anchor.target) {
                if endp is not None {
                    intent.depends_on.add(endp.id);
                    if isinstance(endp, NodeAnchor) {
                        existing_endp = self.intents.get(endp.id);
                        if existing_endp is None or not existing_endp.is_delete() {
                            self.record_edge_delta(endp, added=[], removed=[anchor.id]);
                        }
                    }
                }
            }
        } elif isinstance(anchor, NodeAnchor) and anchor.is_populated() {
            for ed in anchor.edges {
                intent.depends_on.add(ed.id);
            }
        }
        self.intents[anchor.id] = intent;
    }

    """Bucket intents by stage, in flush order. Truncating the flat sequence
    at any point leaves at worst an orphan, never a dangling reference."""
    def staged -> list[list[WriteIntent]] {
        stages: list[list[WriteIntent]] = [[] for i in range(6)];
        for intent in self.intents.values() {
            stages[intent.op.value].append(intent);
        }
        return stages;
    }
}


# ---------------------------------------------------------------------------
# Field-hash dirty detection (shared by the collect pass and backend reads)
# ---------------------------------------------------------------------------
"""Stable content hash of one serialized field value."""
def field_hash(serialized: object) -> int {
    import from json { dumps }
    try {
        return hash(dumps(serialized, sort_keys=True, default=str));
    } except Exception {
        return 0;
    }
}


"""Snapshot per-field content hashes on the archetype. Taken at load and
after each successful persist; `derive_dirty_fields` diffs against it."""
def snapshot_field_hashes(anchor: Anchor) -> None {
    if not anchor.is_populated() or anchor.archetype is None {
        return;
    }
    arch = anchor.archetype;
    hashes: dict[str, int] = {};
    _seen: tuple[set, set] = (set(), set());
    for name in get_field_types(type(arch)).keys() {
        val = getattr(arch, name, None);
        serialized = Serializer._serialize_value(val, include_type=True, _seen=_seen);
        hashes[name] = field_hash(serialized);
    }
    object.__setattr__(arch, '__jac_field_hashes__', hashes);
}


"""Derive dirty fields by comparing current values against the snapshot."""
def derive_dirty_fields(anchor: Anchor) -> set[str] {
    if not anchor.is_populated() or anchor.archetype is None {
        return set();
    }
    arch = anchor.archetype;
    stored: dict[str, int] = arch.__dict__.get('__jac_field_hashes__', {});
    if not stored {
        return set();
    }
    dirty: set[str] = set();
    _seen: tuple[set, set] = (set(), set());
    for name in get_field_types(type(arch)).keys() {
        val = getattr(arch, name, None);
        serialized = Serializer._serialize_value(val, include_type=True, _seen=_seen);
        if field_hash(serialized) != stored.get(name) {
            dirty.add(name);
        }
    }
    return dirty;
}
