import logging;
import os;
import threading;
import from collections.abc { Generator }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtimelib.dbcatalog {
    DbKind,
    MAINTENANCE_DB,
    SCRATCH_PREFIX,
    stop_heartbeat
}
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store {
    AnchorRow,
    ConnInfo,
    PgStore,
    Store,
    TxnIsolation
}

glob logger = logging.getLogger(__name__),
     MAX_RETRIES = 5,
     SCRATCH_ENV = 'JAC_DB_SCRATCH',
     RETENTION_ENV = 'JAC_DB_RETENTION_DAYS',
     __all__ = [
         'Session',
         'promotions_for',
         'conninfo_from_url',
         'shared_pg_data_dir',
         'project_db_name',
         'takeover_project',
         'mark_scratch_base',
         'scratch_requested',
         'scratch_lease',
         'drop_scratch_database',
         'retention_days_for',
         'runtime_for_base',
         'SCRATCH_ENV',
         'RETENTION_ENV'
     ];


obj ScratchLease {
    has database: str,
        reset: bool = False;
}


obj RuntimeLease {
    has runtime: PgRuntime,
        reset: bool = False;
}


obj ScratchState {
    has database: str,
        base_path: str;
}


def promotions_for(base_path: (str | None)) -> dict[str, list[str]];
def shared_pg_data_dir -> str;
def project_db_name(base_path: str, target_path: (str | None)) -> str;
def conninfo_from_url(url: str) -> ConnInfo;
def takeover_project(base_path: str, target_path: (str | None) = None) -> int;
def mark_scratch_base(base_path: str) -> None;
def scratch_requested(base_path: (str | None)) -> bool;
def scratch_lease(base_path: str) -> ScratchLease;
def drop_scratch_database -> None;
def retention_days_for(base_path: (str | None)) -> int;
def runtime_for_base(base_path: str, target_path: (str | None) = None) -> RuntimeLease;


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
        _runtime: (any | None) postinit,
        _lock: threading.RLock postinit,
        _fetch_count: int postinit,
        _active_units: int postinit,
        _flushing: (int | None) postinit,
        _read_scopes: int postinit,
        _snapshot_reads: set[UUID] postinit;

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
    def run_request(body: Callable) -> any;
    def reset_fetch_count -> None;
    def get_fetch_count -> int;
    def unit_enter -> None;
    def unit_exit -> None;
    def read_scope_enter -> None;
    def read_scope_exit -> None;
    def on_commit(callback: Callable) -> None;
    def flush(full: bool = False) -> None;
    def _flush_locked(full: bool) -> None;
    def read_barrier -> None;
    def _recover_conflict -> None;
    def _ensure_txn -> None;
    def _txn_isolation -> TxnIsolation;
    def _drop_snapshot_reads -> None;
    def _materialize(
        row: AnchorRow, edge_ids: (list[UUID] | None) = None
    ) -> (Anchor | None);

    def _serialize(anchor: Anchor) -> AnchorRow;
    def _fire_on_commit -> None;
    def _evict_uncommitted -> None;
}
