import threading;

import from collections.abc { Callable, Generator, Iterable }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, Root }
import from jaclang.runtimelib.changeset { ApplyReport, ChangeSet, WriteIntent }
import from jaclang.runtimelib.memory { PersistentMemory }

glob __all__ = ["SqlAlchemyMemory"];


obj SqlAlchemyMemory(PersistentMemory) {
    has url: str,
        __mem__: dict[UUID, Anchor] by postinit,
        __lock__: threading.RLock by postinit,
        _engine: (object | None) by postinit,
        _anchors: object by postinit;

    def postinit -> None;
    def is_available -> bool;
    def close -> None;
    def commit(anchor: (Anchor | None) = None) -> None;
    def get(id: UUID) -> (Anchor | None);
    def `has(id: UUID) -> bool;
    def exists(id: UUID) -> bool;
    def get_mem -> dict[UUID, Anchor];
    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def put(anchor: Anchor) -> None;
    def put_if_exists(anchor: Anchor) -> bool;
    def delete(id: UUID) -> None;
    def invalidate(id: UUID) -> None;
    def _row_values(anchor: Anchor) -> (dict | None);
    def _write(conn: object, anchor: Anchor) -> None;
    def apply(changeset: ChangeSet) -> ApplyReport;
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

    def is_recoverable_quarantine(id: UUID) -> bool;
    def fsck(repair: bool = False) -> dict;
}
