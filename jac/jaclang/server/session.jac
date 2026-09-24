import logging;
import os;
import threading;
import from collections.abc { Generator }
import from uuid { UUID }

import from jaclang.runtime.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtime.memory { Memory }
import from jaclang.data.dbcatalog {
    DbKind,
    MAINTENANCE_DB,
    SCRATCH_PREFIX,
    stop_heartbeat
}
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.runtime.exceptions { ReadOnlyRetry, WriteConflict }
import from jaclang.data.store { AnchorRow, ConnInfo, PgStore, Store, TxnIsolation }

glob logger = logging.getLogger(__name__),
     MAX_RETRIES = 5,
     EDGE_PAGE = 1000,
     SCRATCH_ENV = 'JAC_DB_SCRATCH',
     SCRATCH_OWNER_ENV = 'JAC_DB_SCRATCH_OWNER',
     RETENTION_ENV = 'JAC_DB_RETENTION_DAYS',
     RO_UNITS_ENV = 'JAC_DB_RO_UNITS',
     RO_WRITER_TTL_ENV = 'JAC_DB_RO_WRITER_TTL_S',
     _unit_writers: dict[str, float] = {},
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
         'scratch_owner_pid',
         'own_child_databases',
         'drop_owned_databases',
         'drop_scratch_database',
         'retention_days_for',
         'runtime_for_base',
         'ro_units_enabled',
         'unit_writes_recorded',
         'record_unit_writes',
         'SCRATCH_ENV',
         'SCRATCH_OWNER_ENV',
         'RETENTION_ENV',
         'RO_UNITS_ENV'
     ];


def ro_units_enabled -> bool {
    return os.environ.get(RO_UNITS_ENV, '1').strip().lower()
        not in ('0', 'false', 'no', 'off');
}


def _writer_ttl -> float {
    try {
        return max(1.0, float(os.environ.get(RO_WRITER_TTL_ENV, '300') or 300));
    } except ValueError {
        return 300.0;
    }
}


def unit_writes_recorded(key: str) -> bool {
    import time;
    expiry = _unit_writers.get(key);
    if expiry is None {
        return False;
    }
    if time.monotonic() >= expiry {
        _unit_writers.pop(key, None);
        return False;
    }
    return True;
}


def record_unit_writes(key: str) {
    import time;
    _unit_writers[key] = time.monotonic() + _writer_ttl();
}


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
        base_path: str,
        owner_pid: int = 0;
}


def promotions_for(base_path: (str | None)) -> dict[str, list[str]];
def shared_pg_data_dir -> str;
def project_db_name(base_path: str, target_path: (str | None)) -> str;
def conninfo_from_url(url: str) -> ConnInfo;
def takeover_project(base_path: str, target_path: (str | None) = None) -> int;
def mark_scratch_base(base_path: str) -> None;
def scratch_requested(base_path: (str | None)) -> bool;
def scratch_lease(base_path: str) -> ScratchLease;
def scratch_owner_pid -> int;
def own_child_databases -> None;
def drop_owned_databases(data_dir: str = '') -> int;
def drop_scratch_database -> None;
def retention_days_for(base_path: (str | None)) -> int;
def runtime_for_base(base_path: str, target_path: (str | None) = None) -> RuntimeLease;


obj Session(Memory) {
    has _store: (Store | None) = None,
        _data_location: (str | None) = None,
        _lease: (RuntimeLease | None) = None,
        _flushed_hash: dict[UUID, int] postinit,
        _txn_changed: set[UUID] postinit,
        _fetch_count: int postinit,
        _active_units: int postinit,
        _flushing: (int | None) postinit,
        _read_scopes: int postinit,
        _ro_units: int postinit,
        _unit_stack: list[tuple[(str | None), bool]] postinit,
        _snapshot_reads: set[UUID] postinit,
        _version_seen: dict[UUID, int] postinit;

    has store: (Store | None) {
        getter {
            if self._store is None and self.base_path {
                with self._lock {
                    if self._store is None {
                        self._boot_store();
                    }
                }
            }
            return self._store;
        }
        setter(value: (Store | None)) {
            self._store = value;
            self._data_location = None;
        }
    }

    def postinit -> None;
    def _runtime_lease -> RuntimeLease;
    def _boot_store -> None;
    def data_location -> (str | None);
    def __repr__ -> str;
    def get(id: UUID) -> (Anchor | None);
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def get_roots -> Generator[Root, None, None];
    def commit(anchor: (Anchor | None) = None) -> None;
    def abort -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None;
    def run_request(body: Callable) -> any;
    def reset_fetch_count -> None;
    def get_fetch_count -> int;
    def unit_enter(key: (str | None) = None) -> None;
    def unit_exit -> None;
    def unit_depth -> int;
    def read_scope_enter -> None;
    def read_scope_exit -> None;
    def flush(full: bool = False) -> None;
    def _flush_locked(full: bool) -> None;
    def ensure_writable_txn -> None;
    def read_barrier -> None;
    def _recover_conflict -> None;
    def _rollback_quiet -> None;
    def _ensure_txn -> None;
    def _txn_isolation -> TxnIsolation;
    def _register_ro_writers -> str;
    def _raise_ro_retry -> None;
    def _drop_snapshot_reads -> None;
    def _materialize(row: AnchorRow) -> (Anchor | None);
    def _load_edges(nd: NodeAnchor) -> list[EdgeAnchor];
    def _serialize(anchor: Anchor, props: (any | None) = None) -> AnchorRow;
    def _evict_uncommitted -> None;
}
