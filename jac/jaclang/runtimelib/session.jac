import logging;
import os;
import threading;
import from collections.abc { Callable, Generator, Iterable }
import from typing { Any }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store { AnchorRow, ConnInfo, PgStore, Store }

glob logger = logging.getLogger(__name__),
     MAX_RETRIES = 5,
     __all__ = [
         'Session',
         'promotions_for',
         'conninfo_from_url',
         'shared_pg_data_dir',
         'project_db_name',
         'takeover_project'
     ];


def promotions_for(base_path: (str | None)) -> dict[str, list[str]];
def shared_pg_data_dir -> str;
def project_db_name(base_path: str, target_path: (str | None)) -> str;
def conninfo_from_url(url: str) -> ConnInfo;
def takeover_project(base_path: str, target_path: (str | None) = None) -> int;


obj Session {
    has store: (Store | None) = None,
        base_path: (str | None) = None,
        target_path: (str | None) = None,
        __mem__: dict[UUID, Anchor] postinit,
        _dirty: dict[UUID, None] postinit,
        _deleted: set[UUID] postinit,
        _flushed_hash: dict[UUID, int] postinit,
        _on_commit: list[Callable] postinit,
        _txn_changed: set[UUID] postinit,
        _runtime: (Any | None) postinit,
        _lock: threading.RLock postinit,
        _fetch_count: int postinit,
        _active_units: int postinit;

    def postinit -> None;
    def data_location -> (str | None);
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def mark_dirty(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    def abort -> None;
    def get_mem -> dict[UUID, Anchor];
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None;
    def is_recoverable_quarantine(id: UUID) -> bool;
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
    async def adelete(id: UUID) -> None;
    async def ahas(id: UUID) -> bool;
    async def acommit(anchor: (Anchor | None) = None) -> None;
    def run_request(body: Callable) -> Any;
    def reset_fetch_count -> None;
    def get_fetch_count -> int;
    def unit_enter -> None;
    def unit_exit -> None;
    def on_commit(callback: Callable) -> None;
    def flush(full: bool = False) -> None;
    def read_barrier -> None;
    def _recover_conflict -> None;
    def _ensure_txn -> None;
    def _materialize(
        row: AnchorRow, edge_ids: (list[UUID] | None) = None
    ) -> (Anchor | None);

    def _serialize(anchor: Anchor) -> AnchorRow;
    def _fire_on_commit -> None;
    def _evict_uncommitted -> None;
}
