import from jaclang.runtimelib.store {
    AnchorRow,
    ConnInfo,
    SCHEMA_VERSION,
    Store,
    TxnIsolation
}


obj BunStore(Store) {
    has conninfo: ConnInfo,
        _ready: bool postinit,
        _sql: (any | None) postinit;

    def postinit -> None;
    def is_available -> bool;
    def server_version -> int;
    def ensure_schema(promotions: dict[str, list[str]]) -> None;
    def reset_data -> None;
    def begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) -> None;
    def commit -> None;
    def rollback -> None;
    def in_txn -> bool;
    def txn_isolation -> (TxnIsolation | None);
    def load_full(ids: list) -> dict;
    def upsert(rows_in: list[AnchorRow]) -> None;
    def delete(ids: list) -> None;
    def existing(ids: list) -> set;
    def root_ids -> list;
    def subtype_names(type_name: str) -> list[str];
    def rows(sql: str, params: dict) -> list[tuple];
    def kv_get(key: str) -> (str | None);
    def kv_put(key: str, value: str) -> None;
    def kv_put_ttl(key: str, value: str, ttl_seconds: int) -> None;
    def kv_delete(key: str) -> None;
    def quarantine(missing_id: any, referrer_id: (any | None), kind: str) -> None;
    def notify(channel: str, payload: str) -> None;
    def close -> None;
}
