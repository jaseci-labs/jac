import json;
import logging;
import threading;
import from typing { Any }
import from uuid { UUID }

import from jaclang.runtimelib.pgwire { PgWireError }

glob logger = logging.getLogger(__name__),
     SCHEMA_VERSION = 1,
     __all__ = ['AnchorRow', 'Store', 'PgStore', 'ConnInfo', 'SCHEMA_VERSION'];


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
        version: int = 0;
}


obj Store {
    def is_available -> bool abst;
    def server_version -> int abst;
    def ensure_schema(promotions: dict[str, list[str]]) -> None abst;
    def begin(serializable: bool = True) -> None abst;
    def commit -> None abst;
    def rollback -> None abst;
    def in_txn -> bool abst;
    def load(ids: list[UUID]) -> dict[UUID, AnchorRow] abst;
    def adjacency(ids: list[UUID]) -> dict[UUID, list[UUID]] abst;
    def load_versions(ids: list[UUID]) -> dict[UUID, int] abst;
    def upsert(rows_in: list[AnchorRow]) -> None abst;
    def delete(ids: list[UUID]) -> None abst;
    def existing(ids: list[UUID]) -> set[UUID] abst;
    def root_ids -> list[UUID] abst;
    def subtype_names(type_name: str) -> list[str] abst;
    def rows(sql: str, params: dict) -> list[tuple] abst;
    def kv_get(key: str) -> (str | None) abst;
    def kv_put(key: str, value: str) -> None abst;
    def kv_delete(key: str) -> None abst;
    def quarantine(
        missing_id: UUID, referrer_id: (UUID | None), kind: str
    ) -> None abst;

    def notify(channel: str, payload: str) -> None abst;
    def close -> None abst;
}


obj PgStore(Store) {
    has conninfo: ConnInfo,
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
    def begin(serializable: bool = True) -> None;
    def commit -> None;
    def rollback -> None;
    def in_txn -> bool;
    def load(ids: list[UUID]) -> dict[UUID, AnchorRow];
    def adjacency(ids: list[UUID]) -> dict[UUID, list[UUID]];
    def load_versions(ids: list[UUID]) -> dict[UUID, int];
    def upsert(rows_in: list[AnchorRow]) -> None;
    def delete(ids: list[UUID]) -> None;
    def existing(ids: list[UUID]) -> set[UUID];
    def root_ids -> list[UUID];
    def subtype_names(type_name: str) -> list[str];
    def rows(sql: str, params: dict) -> list[tuple];
    def kv_get(key: str) -> (str | None);
    def kv_put(key: str, value: str) -> None;
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
}
