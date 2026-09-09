import json;
import logging;
import os;
import threading;
import from enum { StrEnum }
import from uuid { UUID }

import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.exceptions { WriteConflict }

glob logger = logging.getLogger(__name__),
     SCHEMA_VERSION = 1,
     SCHEMA_STAMP_KEY = 'schema_fingerprint',
     _schema_ready: dict[str, str] = {},
     _schema_gate = threading.Lock(),
     _schema_extensions: dict[str, list[str]] = {},
     __all__ = [
         'AnchorRow',
         'Store',
         'PgStore',
         'ConnInfo',
         'TxnIsolation',
         'SCHEMA_VERSION',
         'SCHEMA_STAMP_KEY',
         'SessionConflictError',
         'register_schema_extension'
     ];

def register_schema_extension(name: str, statements: list[str]) {
    _schema_extensions[name] = list(statements);
}

def _schema_extension_key -> str {
    return ",".join(sorted(_schema_extensions));
}


enum TxnIsolation(StrEnum) {
    SERIALIZABLE = 'ISOLATION LEVEL SERIALIZABLE',
    READ_COMMITTED = 'ISOLATION LEVEL READ COMMITTED',
    SNAPSHOT_READ_ONLY = 'ISOLATION LEVEL REPEATABLE READ READ ONLY'
}


class SessionConflictError(Exception) {
    def init(
        self: SessionConflictError,
        database: str = '',
        blockers: (list[dict] | None) = None
    ) -> None;
}


obj ConnInfo {
    has host: str = '',
        port: int = 5432,
        user: str = 'jac',
        password: str = '',
        database: str = 'jac',
        unix_socket_dir: (str | None) = None;

    def dsn -> str;
}


obj AnchorRow {
    has id: UUID,
        kind: str,
        arch_type: str = '',
        arch_module: str = '',
        fingerprint: str = '',
        root_id: (UUID | None) = None,
        `props: dict = {},
        src: (UUID | None) = None,
        dst: (UUID | None) = None,
        undirected: bool = False,
        ancestry: list[str] = [],
        version: int = 0,
        adjacency: (list[UUID] | None) = None;
}


obj ChannelListener {
    has channel: str,
        ident: str,
        callback: any;
}


obj ChannelMessage {
    has channel: str,
        payload: str;
}


obj Store {
    def is_available -> bool abst;
    def server_version -> int abst;
    def ensure_schema(promotions: dict[str, list[str]]) -> None abst;
    def reset_data -> None abst;
    def begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) -> None abst;
    def commit -> None abst;
    def rollback -> None abst;
    def in_txn -> bool abst;
    def txn_isolation -> (TxnIsolation | None) abst;
    def load_full(ids: list[UUID]) -> dict[UUID, AnchorRow] abst;
    def upsert(rows_in: list[AnchorRow]) -> None abst;
    def delete(ids: list[UUID]) -> None abst;
    def existing(ids: list[UUID]) -> set[UUID] abst;
    def root_ids -> list[UUID] abst;
    def subtype_names(type_name: str) -> list[str] abst;
    def rows(sql: str, params: dict) -> list[tuple] abst;
    def kv_get(key: str) -> (str | None) abst;
    def kv_put(key: str, value: str) -> None abst;
    def kv_put_ttl(key: str, value: str, ttl_seconds: int) -> None abst;
    def kv_delete(key: str) -> None abst;
    def kv_acquire_lease(key: str, ttl_seconds: int, owner: str) -> bool abst;
    def kv_release_lease(key: str, owner: str) -> bool abst;
    def quarantine(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None abst;

    def notify(channel: str, payload: str) -> None abst;
    def close -> None abst;
}


obj PgStore(Store) {
    has conninfo: ConnInfo,
        ensure_cb: (any | None) = None,
        promotions: dict[str, list[str]] = {},
        auto_schema: bool = False,
        pending_reset: bool = False,
        _conn: (any | None) postinit,
        _side_conn: (any | None) postinit,
        _lock: threading.RLock postinit,
        _server_version: (int | None) postinit,
        _in_txn: bool postinit,
        _isolation: (TxnIsolation | None) postinit,
        _known_types: set[str] postinit,
        _listeners: list[ChannelListener] postinit,
        _listen_thread: (any | None) postinit,
        _listen_stop: (any | None) postinit,
        _side_listened: bool postinit,
        _booted: bool postinit,
        _ready: bool postinit,
        _readying: (int | None) postinit;

    def postinit -> None;
    def is_available -> bool;
    def server_version -> int;
    def ensure_schema(promotions: dict[str, list[str]]) -> None;
    def ensure_schema_once(promotions: dict[str, list[str]]) -> None;
    def reset_data -> None;
    def takeover -> int;
    def begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) -> None;
    def commit -> None;
    def rollback -> None;
    def in_txn -> bool;
    def txn_isolation -> (TxnIsolation | None);
    def load_full(ids: list[UUID]) -> dict[UUID, AnchorRow];
    def upsert(rows_in: list[AnchorRow]) -> None;
    def delete(ids: list[UUID]) -> None;
    def existing(ids: list[UUID]) -> set[UUID];
    def root_ids -> list[UUID];
    def subtype_names(type_name: str) -> list[str];
    def rows(sql: str, params: dict) -> list[tuple];
    def kv_get(key: str) -> (str | None);
    def kv_put(key: str, value: str) -> None;
    def kv_put_ttl(key: str, value: str, ttl_seconds: int) -> None;
    def kv_delete(key: str) -> None;
    def kv_acquire_lease(key: str, ttl_seconds: int, owner: str) -> bool;
    def kv_release_lease(key: str, owner: str) -> bool;
    def quarantine(missing_id: UUID, referrer_id: (UUID | None), kind: str) -> None;
    def notify(channel: str, payload: str) -> None;
    def listen(channel: str, callback: any) -> None;
    def unlisten(channel: str) -> None;
    def close -> None;
    def _ensure_ready -> None;
    def _connect -> any;
    def _main -> any;
    def _side -> any;
    def _run(sql: str, params: dict) -> list;
    def _promotion_columns -> list[tuple[str, str, str]];
    def _promoted_column_type(col: str) -> (str | None);
    def _apply_promotions -> None;
    def _property_graph_ddl -> None;
    def _listen_loop -> None;
    def _dispatch_notification(channel: str, payload: str) -> None;
    def _stop_listen_thread -> any;
    def _join_listen_thread(parked: any) -> None;
    def _schema_fingerprint -> str;
    def _schema_stamp -> (str | None);
    def _acquire_schema_lock(fingerprint: str) -> bool;
    def _release_schema_lock -> None;
    def _apply_schema_ddl -> None;
    def _apply_schema_ddl_resilient -> None;
    def _load_known_types -> None;
    def _peer_sessions -> list[dict];
    def _reap_dead_sessions -> int;
    def _live_blockers -> list[dict];
}
