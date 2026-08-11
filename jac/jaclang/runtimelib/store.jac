import json;
import logging;
import os;
import threading;
import from typing { Any }
import from uuid { UUID }

import from jaclang.runtimelib.pgwire { PgWireError }

glob logger = logging.getLogger(__name__),
     SCHEMA_VERSION = 1,
     SCHEMA_STAMP_KEY = 'schema_fingerprint',
     __all__ = [
         'AnchorRow',
         'Store',
         'PgStore',
         'ConnInfo',
         'SCHEMA_VERSION',
         'SCHEMA_STAMP_KEY',
         'SessionConflictError'
     ];


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
        props: dict = {},
        src: (UUID | None) = None,
        dst: (UUID | None) = None,
        undirected: bool = False,
        ancestry: list[str] = [],
        version: int = 0,
        adjacency: (list[UUID] | None) = None;
}


obj Store {
    def is_available -> bool abst;
    def server_version -> int abst;
    def ensure_schema(promotions: dict[str, list[str]]) -> None abst;
    def begin(serializable: bool = True, read_only: bool = False) -> None abst;
    def commit -> None abst;
    def rollback -> None abst;
    def in_txn -> bool abst;
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
    def quarantine(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None abst;

    def notify(channel: str, payload: str) -> None abst;
    def close -> None abst;
}


obj PgStore(Store) {
    has conninfo: ConnInfo,
        ensure_cb: (Any | None) = None,
        promotions: dict[str, list[str]] = {},
        _conn: (Any | None) postinit,
        _side_conn: (Any | None) postinit,
        _lock: threading.RLock postinit,
        _server_version: (int | None) postinit,
        _in_txn: bool postinit,
        _known_types: set[str] postinit,
        _listeners: list[tuple[str, Any]] postinit,
        _listen_thread: (Any | None) postinit,
        _listen_stop: (Any | None) postinit;

    def postinit -> None;
    def is_available -> bool;
    def server_version -> int;
    def ensure_schema(promotions: dict[str, list[str]]) -> None;
    def takeover -> int;
    def begin(serializable: bool = True, read_only: bool = False) -> None;
    def commit -> None;
    def rollback -> None;
    def in_txn -> bool;
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
    def quarantine(missing_id: UUID, referrer_id: (UUID | None), kind: str) -> None;
    def notify(channel: str, payload: str) -> None;
    def listen(channel: str, callback: Any) -> None;
    def close -> None;
    def _connect -> Any;
    def _main -> Any;
    def _side -> Any;
    def _run(sql: str, params: dict) -> list;
    def _promotion_columns -> list[tuple[str, str, str]];
    def _apply_promotions -> None;
    def _property_graph_ddl -> None;
    def _listen_loop -> None;
    def _schema_fingerprint -> str;
    def _schema_stamp -> (str | None);
    def _apply_schema_ddl -> None;
    def _load_known_types -> None;
    def _peer_sessions -> list[dict];
    def _reap_dead_sessions -> int;
    def _live_blockers -> list[dict];
}
