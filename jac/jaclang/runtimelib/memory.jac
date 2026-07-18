import logging;
import sqlite3;
import threading;
import from collections.abc { Callable, Generator, Iterable }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.changeset { ApplyReport, ChangeSet, WriteIntent }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.typecache { get_field_types }

glob logger = logging.getLogger(__name__),
     DANGLING_REF = 'DANGLING_REF',
     __all__ = [
         'Memory',
         'CacheMemory',
         'PersistentMemory',
         'VolatileMemory',
         'LocalCacheMemory',
         'SqliteMemory',
         'TieredMemory',
         'DANGLING_REF'
     ];

obj Memory {
    def is_available -> bool abst;
    def get(id: UUID) -> (Anchor | None) abst;
    def put(anchor: Anchor) -> None abst;
    def delete(id: UUID) -> None abst;
    def close -> None abst;
    def `has(id: UUID) -> bool abst;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None] abst;

    def get_roots -> Generator[Root, None, None] abst;
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None abst;
    def abort -> None;
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None;
    def is_recoverable_quarantine(id: UUID) -> bool;
    def get_mem -> dict[UUID, Anchor] abst;
    def capabilities -> set[str];
    def execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None];
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
    async def adelete(id: UUID) -> None;
    async def ahas(id: UUID) -> bool;
    async def acommit(anchor: (Anchor | None) = None) -> None;
}

obj CacheMemory(Memory) {
    def exists(id: UUID) -> bool abst;
    def put_if_exists(anchor: Anchor) -> bool abst;
    def invalidate(id: UUID) -> None abst;
}

obj PersistentMemory(Memory) {
    def apply(changeset: ChangeSet) -> ApplyReport abst;
    def inspect_summary -> dict abst;
    def list_quarantined(limit: int = 50) -> list abst;
    def show_quarantined(id_prefix: str) -> (dict | None) abst;
    def recover_one(id_prefix: str) -> tuple abst;
    def recover_all -> tuple abst;
    def list_aliases -> list abst;
    def add_alias(old_name: str, new_name: str) -> None abst;
    def remove_alias(old_name: str) -> bool abst;
    def quarantine_dangling(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None abst;

    def is_recoverable_quarantine(id: UUID) -> bool abst;
    def fsck(repair: bool = False) -> dict abst;
}

obj VolatileMemory(Memory) {
    has __mem__: dict[UUID, Anchor] postinit;

    def postinit -> None;
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def commit(anchor: (Anchor | None) = None) -> None;
    def get_mem -> dict[UUID, Anchor];
}

obj LocalCacheMemory(VolatileMemory, CacheMemory) {
    def exists(id: UUID) -> bool;
    def put_if_exists(anchor: Anchor) -> bool;
    def invalidate(id: UUID) -> None;
}

obj SqliteMemory(PersistentMemory) {
    has path: str,
        __mem__: dict[UUID, Anchor] postinit,
        __conn__: (sqlite3.Connection | None) postinit,
        __lock__: threading.RLock postinit,
        l3_fetch_count: int postinit;

    def postinit -> None;
    def _ensure_connection -> None;
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def commit(anchor: (Anchor | None) = None) -> None;
    def apply(changeset: ChangeSet) -> ApplyReport;
    def _apply_one(conn: sqlite3.Connection, intent: WriteIntent) -> None;
    def _merge_write(conn: sqlite3.Connection, intent: WriteIntent) -> None;
    def inspect_summary -> dict;
    def list_quarantined(limit: int = 50) -> list;
    def show_quarantined(id_prefix: str) -> (dict | None);
    def recover_one(id_prefix: str) -> tuple;
    def recover_all -> tuple;
    def list_aliases -> list;
    def add_alias(old_name: str, new_name: str) -> None;
    def remove_alias(old_name: str) -> bool;
    def quarantine_dangling(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None;

    def fsck(repair: bool = False) -> dict;
    def is_recoverable_quarantine(id: UUID) -> bool;
    def get_mem -> dict[UUID, Anchor];
}

obj TieredMemory(VolatileMemory) {
    has base_path: (str | None) = None,
        target_path: (str | None) = None,
        l2: (CacheMemory | None) postinit,
        l3: (PersistentMemory | None) postinit,
        changes: ChangeSet postinit,
        use_cache: bool = False;

    def get_l3_fetch_count -> int;
    def reset_l3_fetch_count -> None;
    def postinit -> None;
    def _resolve_l3_backend(db_path: str) -> PersistentMemory;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def get_roots -> Generator[Root, None, None];
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def commit(anchor: (Anchor | None) = None) -> None;
    def abort -> None;
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None;
    def is_recoverable_quarantine(id: UUID) -> bool;
    def _collect_into(changes: ChangeSet) -> None;
    def _post_apply(apply_report: ApplyReport) -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def capabilities -> set[str];
    def execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None];
}
