import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.typecache { get_field_types }
import from jaclang.runtimelib.exceptions { WriteConflict }


enum WriteOp {
    NODE_CREATE = 0,
    EDGE_CREATE = 1,
    EDGE_LIST_DELTA = 2,
    FIELD_UPDATE = 3,
    EDGE_DELETE = 4,
    NODE_DELETE = 5
}


obj WriteIntent {
    has op: WriteOp,
        anchor: Anchor,
        fields: set[str] by postinit,
        edges_added: list[UUID] by postinit,
        edges_removed: list[UUID] by postinit,
        depends_on: set[UUID] by postinit,
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


obj ApplyReport {
    has applied: list[UUID] by postinit,
        failed: dict[UUID, str] by postinit,
        skipped: dict[UUID, str] by postinit,
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

        if isinstance(anchor, EdgeAnchor) and anchor.is_populated() {
            for endp in (anchor.source, anchor.target) {
                if endp is not None {
                    existing.depends_on.add(endp.id);
                }
            }
        }
    }

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

    def record_edge_delta(
        anchor: NodeAnchor, added: list[UUID], removed: list[UUID]
    ) -> None {
        existing = self.intents.get(anchor.id);
        if existing is not None and (existing.is_delete() or existing.is_create()) {
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

    def staged -> list[list[WriteIntent]] {
        stages: list[list[WriteIntent]] = [[] for i in range(6)];
        for intent in self.intents.values() {
            stages[intent.op.value].append(intent);
        }
        return stages;
    }
}


def field_hash(serialized: object) -> int {
    import from json { dumps }
    try {
        return hash(dumps(serialized, sort_keys=True, default=str));
    } except Exception {
        return 0;
    }
}


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
