import json;
import logging;
import threading;

import from collections.abc { Callable, Generator, Iterable }
import from uuid { UUID }

import from sqlalchemy {
    Column,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    create_engine,
    select,
    delete as sa_delete
}
import from jaclang.jac0core.archetype { Anchor, Root }
import from jaclang.runtimelib.changeset {
    ApplyReport,
    ChangeSet,
    snapshot_field_hashes
}
import from jaclang.runtimelib.memory { _anchor_to_row }
import from jaclang.runtimelib.serializer { Serializer }

glob logger = logging.getLogger(__name__);


impl SqlAlchemyMemory.postinit -> None {
    self.__mem__ = {};
    self.__lock__ = threading.RLock();
    metadata = MetaData();
    self._anchors = Table(
        "anchors",
        metadata,
        Column("id", String(64), primary_key=True),
        Column("type", String(64), nullable=False),
        Column("arch_module", Text),
        Column("arch_type", Text),
        Column("fingerprint", Text),
        Column("data", Text, nullable=False),
        Column("format_version", Integer, nullable=False, default=1),
        Column("updated_at", Text)
    );
    self._engine = create_engine(self.url, future=True);
    metadata.create_all(self._engine);
}


impl SqlAlchemyMemory.is_available -> bool {
    return self._engine is not None;
}


impl SqlAlchemyMemory.close -> None {
    if self._engine is not None {
        self._engine.dispose();
        self._engine = None;
    }
    self.__mem__.clear();
}


impl SqlAlchemyMemory.commit(anchor: (Anchor | None) = None) -> None {
    return;
}


impl SqlAlchemyMemory.get(id: UUID) -> (Anchor | None) {
    anchor = self.__mem__.get(id);
    if anchor is not None {
        return anchor;
    }
    tbl = self._anchors;
    with self._engine.connect() as conn {
        row = conn.execute(select(tbl.c.data).where(tbl.c.id == str(id))).fetchone();
    }
    if not row {
        return None;
    }
    try {
        anchor = Serializer.deserialize(json.loads(row[0]));
    } except Exception as e {
        logger.warning(f"SqlAlchemyMemory: failed to deserialize anchor {id}: {e}");
        return None;
    }
    if anchor is None {
        return None;
    }
    self.__mem__[id] = anchor;
    snapshot_field_hashes(anchor);
    return anchor;
}


impl SqlAlchemyMemory.`has(id: UUID) -> bool {
    if id in self.__mem__ {
        return True;
    }
    tbl = self._anchors;
    with self._engine.connect() as conn {
        row = conn.execute(select(tbl.c.id).where(tbl.c.id == str(id))).fetchone();
    }
    return row is not None;
}


impl SqlAlchemyMemory.exists(id: UUID) -> bool {
    return self.`has(id);
}


impl SqlAlchemyMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}


impl SqlAlchemyMemory.get_roots -> Generator[Root, None, None] {
    seen: set = set();
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.id);
            yield anchor.archetype;
        }
    }
    tbl = self._anchors;
    with self._engine.connect() as conn {
        rows = conn.execute(
            select(tbl.c.id, tbl.c.arch_module, tbl.c.arch_type).where(
                tbl.c.type == "NodeAnchor"
            )
        ).fetchall();
    }
    for (rid, arch_module, arch_type) in rows {
        if not arch_module or not arch_type {
            continue;
        }
        uid = UUID(rid);
        if uid in seen {
            continue;
        }
        cls = Serializer._get_class(arch_module, arch_type);
        if cls is not None and isinstance(cls, type) and issubclass(cls, Root) {
            anchor = self.get(uid);
            if anchor is not None and isinstance(anchor.archetype, Root) {
                seen.add(uid);
                yield anchor.archetype;
            }
        }
    }
}


impl SqlAlchemyMemory.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        anchor = self.get(id);
        if anchor is not None and (filter is None or filter(anchor)) {
            yield anchor;
        }
    }
}


impl SqlAlchemyMemory.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        anchor = self.get(id);
        if anchor is not None and (filter is None or filter(anchor)) {
            return anchor;
        }
    }
    return None;
}


impl SqlAlchemyMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    seen: set = set();
    for anchor in list(self.__mem__.values()) {
        seen.add(anchor.id);
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
    tbl = self._anchors;
    with self._engine.connect() as conn {
        rows = conn.execute(select(tbl.c.id)).fetchall();
    }
    for id_row in rows {
        uid = UUID(id_row[0]);
        if uid in seen {
            continue;
        }
        anchor = self.get(uid);
        if anchor is not None and (filter is None or filter(anchor)) {
            yield anchor;
        }
    }
}


impl SqlAlchemyMemory._row_values(anchor: Anchor) -> (dict | None) {
    (
        anchor_type,
        arch_module,
        arch_type,
        fingerprint,
        data_json,
        format_version,
        updated_at
    ) = _anchor_to_row(anchor);
    return {
        "id": str(anchor.id),
        "type": anchor_type,
        "arch_module": arch_module,
        "arch_type": arch_type,
        "fingerprint": fingerprint,
        "data": data_json,
        "format_version": format_version,
        "updated_at": updated_at
    };
}


impl SqlAlchemyMemory._write(conn: object, anchor: Anchor) -> None {
    row = self._row_values(anchor);
    tbl = self._anchors;
    existing = conn.execute(select(tbl.c.id).where(tbl.c.id == row["id"])).fetchone();
    if existing {
        conn.execute(tbl.update().where(tbl.c.id == row["id"]).values(**row));
    } else {
        conn.execute(tbl.insert().values(**row));
    }
}


impl SqlAlchemyMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
    if not anchor.persistent or not anchor.is_populated() {
        return;
    }
    try {
        self._row_values(anchor);
    } except (AttributeError, ModuleNotFoundError) {
        return;
    }
    try {
        with self._engine.begin() as conn {
            self._write(conn, anchor);
        }
    } except Exception as e {
        logger.warning(f"SqlAlchemyMemory.put: failed to persist {anchor.id}: {e}");
    }
}


impl SqlAlchemyMemory.put_if_exists(anchor: Anchor) -> bool {
    if self.`has(anchor.id) {
        self.put(anchor);
        return True;
    }
    return False;
}


impl SqlAlchemyMemory.delete(id: UUID) -> None {
    self.__mem__.pop(id, None);
}


impl SqlAlchemyMemory.invalidate(id: UUID) -> None {
    self.__mem__.pop(id, None);
}


impl SqlAlchemyMemory.apply(changeset: ChangeSet) -> ApplyReport {
    apply_report = ApplyReport();
    if changeset.is_empty() {
        return apply_report;
    }
    tbl = self._anchors;
    with self.__lock__ {
        try {
            with self._engine.begin() as conn {
                poisoned: set = set();
                for stage in changeset.staged() {
                    for intent in stage {
                        if intent.depends_on & poisoned {
                            apply_report.skipped[intent.anchor.id] = "dependency failed";
                            poisoned.add(intent.anchor.id);
                            continue;
                        }
                        try {
                            if intent.is_delete() {
                                conn.execute(
                                    sa_delete(tbl).where(
                                        tbl.c.id == str(intent.anchor.id)
                                    )
                                );
                            } else {
                                self._write(conn, intent.anchor);
                            }
                            apply_report.applied.append(intent.anchor.id);
                        } except (AttributeError, ModuleNotFoundError) as se {
                            poisoned.add(intent.anchor.id);
                            apply_report.failed[intent.anchor.id] = str(se);
                        } except Exception as e {
                            poisoned.add(intent.anchor.id);
                            apply_report.failed[intent.anchor.id] = str(e);
                            fail_op = intent.op.name;
                            logger.error(
                                f"SqlAlchemyMemory.apply: {fail_op} failed for {intent.anchor.id}: {e}"
                            );
                        }
                    }
                }
            }
        } except Exception as te {
            apply_report.applied = [];
            for stage in changeset.staged() {
                for intent in stage {
                    apply_report.failed[intent.anchor.id] = str(te);
                }
            }
            logger.error(f"SqlAlchemyMemory.apply: transaction rolled back: {te}");
        }
    }
    return apply_report;
}


impl SqlAlchemyMemory.inspect_summary -> dict {
    tbl = self._anchors;
    with self._engine.connect() as conn {
        count = len(conn.execute(select(tbl.c.id)).fetchall());
    }
    return {"backend": "sqlalchemy", "anchors": count, "quarantined": 0};
}


impl SqlAlchemyMemory.list_quarantined(limit: int = 50) -> list {
    return [];
}


impl SqlAlchemyMemory.show_quarantined(id_prefix: str) -> (dict | None) {
    return None;
}


impl SqlAlchemyMemory.recover_one(id_prefix: str) -> tuple {
    return (False, "the sqlalchemy backend does not quarantine anchors");
}


impl SqlAlchemyMemory.recover_all -> tuple {
    return (0, []);
}


impl SqlAlchemyMemory.list_aliases -> list {
    return [];
}


impl SqlAlchemyMemory.add_alias(old_name: str, new_name: str) -> None {
    raise NotImplementedError(
        "the sqlalchemy backend does not support archetype aliases"
    );
}


impl SqlAlchemyMemory.remove_alias(old_name: str) -> bool {
    return False;
}


impl SqlAlchemyMemory.quarantine_dangling(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    return;
}


impl SqlAlchemyMemory.is_recoverable_quarantine(id: UUID) -> bool {
    return False;
}


impl SqlAlchemyMemory.fsck(repair: bool = False) -> dict {
    return {"location": self.url, "supported": False};
}
