import hashlib;
import json;
import logging;
import os;
import sqlite3;
import threading;
import time;
import uuid;
import from collections { OrderedDict }
import from jaclang.data.store {
    PgStore,
    Store,
    TxnIsolation,
    register_schema_extension
}
import from jaclang.server.bridge { BridgeRejected }

obj DeliveryReceipt {
    static def _from_wire(payload: dict) -> DeliveryReceipt {
        return DeliveryReceipt();
    }
}

glob logger = logging.getLogger(__name__),
     STATUS_PENDING = "pending",
     STATUS_DELIVERING = "delivering",
     STATUS_DELIVERED = "delivered",
     STATUS_DEAD = "dead",
     DEFAULT_MAX_ATTEMPTS = 8,
     BACKOFF_BASE_S = 1.0,
     BACKOFF_CAP_S = 300.0,
     DELIVER_BATCH = 100,
     LEASE_S = 60.0,
     SEEN_LRU_SIZE = 4096,
     DEFAULT_SEEN_TTL_S = 86400,
     DELIVERED_TTL_S = 86400,
     OUTBOX_DB_REL = os.path.join(".jac", "data", "outbox.sqlite"),
     __all__ = [
         'OutboxEntry',
         'OutboxStore',
         'SqlOutboxStore',
         'PgOutboxStore',
         'SqliteOutboxStore',
         'enqueue',
         'deliver_pending',
         'prune',
         'purge_dead',
         'dead_letters',
         'start_worker',
         'start_worker_if_bridging',
         'stop_worker',
         'worker_running',
         'seen_idempotency_key',
         'remember_idempotency_key',
         'cached_result',
         'scoped_idempotency_key',
         'replay_cached',
         'remember_response',
         'default_idempotency_key',
         'canonical_kwargs',
         'backoff_seconds',
         'outbox_db_path',
         'use_store',
         'STATUS_PENDING',
         'STATUS_DELIVERING',
         'STATUS_DELIVERED',
         'STATUS_DEAD',
         'DEFAULT_MAX_ATTEMPTS',
         'LEASE_S',
         'DELIVERED_TTL_S'
     ];

glob _SCHEMA_SQL = [
         """
    CREATE TABLE IF NOT EXISTS jac_outbox (
        id              TEXT PRIMARY KEY,
        app             TEXT NOT NULL,
        walker          TEXT NOT NULL,
        kwargs          TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        attempts        INTEGER NOT NULL DEFAULT 0,
        created_at      DOUBLE PRECISION NOT NULL,
        status          TEXT NOT NULL,
        last_error      TEXT NOT NULL DEFAULT '',
        next_attempt_at DOUBLE PRECISION NOT NULL DEFAULT 0
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_jac_outbox_due
        ON jac_outbox (status, next_attempt_at)
    """,
         """
    CREATE TABLE IF NOT EXISTS jac_outbox_seen (
        idempotency_key TEXT PRIMARY KEY,
        result          TEXT NOT NULL DEFAULT '',
        expires_at      DOUBLE PRECISION NOT NULL
    )
    """
     ];

with entry {
    register_schema_extension("outbox", _SCHEMA_SQL);
}

obj OutboxEntry {
    has id: str,
        app: str,
        `walker: str,
        kwargs: dict,
        idempotency_key: str,
        attempts: int = 0,
        created_at: float = 0.0,
        status: str = STATUS_PENDING,
        last_error: str = "",
        next_attempt_at: float = 0.0;
}


obj OutboxStore {
    def put(item: OutboxEntry) -> None abst;
    def get_by_key(key: str) -> (OutboxEntry | None) abst;
    def list_pending(now: float, limit: int = DELIVER_BATCH) -> list[OutboxEntry] abst;
    def claim(id: str, now: float, lease_s: float = LEASE_S) -> bool abst;
    def update(item: OutboxEntry) -> None abst;
    def list_status(status: str) -> list[OutboxEntry] abst;
    def prune_status(status: str, created_before: float) -> int abst;
    def prune_seen(now: float) -> int abst;
    def recall_key(key: str, now: float) -> (str | None) abst;
    def remember_key(key: str, ttl_s: int, result: str, now: float) -> None abst;
    def close -> None abst;
}


obj SqlOutboxStore(OutboxStore) {
    def _exec(sql: str, params: dict) -> list[tuple] abst;
    def _exec_count(sql: str, params: dict) -> int abst;
    def ensure_tables -> None abst;
    def put(item: OutboxEntry) -> None;
    def get_by_key(key: str) -> (OutboxEntry | None);
    def list_pending(now: float, limit: int = DELIVER_BATCH) -> list[OutboxEntry];
    def claim(id: str, now: float, lease_s: float = LEASE_S) -> bool;
    def update(item: OutboxEntry) -> None;
    def list_status(status: str) -> list[OutboxEntry];
    def prune_status(status: str, created_before: float) -> int;
    def prune_seen(now: float) -> int;
    def recall_key(key: str, now: float) -> (str | None);
    def remember_key(key: str, ttl_s: int, result: str, now: float) -> None;
}


obj PgOutboxStore(SqlOutboxStore) {
    has store: PgStore;

    def _exec(sql: str, params: dict) -> list[tuple];
    def _exec_count(sql: str, params: dict) -> int;
    def ensure_tables -> None;
    def close -> None;
}


obj SqliteOutboxStore(SqlOutboxStore) {
    has path: str,
        _conn: (sqlite3.Connection | None) = None,
        _lock: threading.RLock = threading.RLock();

    def postinit -> None;
    def _exec(sql: str, params: dict) -> list[tuple];
    def _exec_count(sql: str, params: dict) -> int;
    def ensure_tables -> None;
    def close -> None;
}


obj OutboxState {
    has explicit: (OutboxStore | None) = None,
        worker_store: (OutboxStore | None) = None,
        sqlite_store: (SqliteOutboxStore | None) = None,
        schema_ready: set[str] = set(),
        worker: (threading.Thread | None) = None,
        stop_event: (threading.Event | None) = None,
        lock: threading.RLock = threading.RLock(),
        seen_lru: OrderedDict = OrderedDict();
}


glob _state: OutboxState = OutboxState();


def canonical_kwargs(kwargs: dict) -> str;
def default_idempotency_key(app: str, `walker: str, kwargs: dict) -> str;
def backoff_seconds(attempts: int) -> float;
def outbox_db_path -> str;
def use_store(store: (OutboxStore | None)) -> None;

def enqueue(app: str, `walker: str, kwargs: dict, idempotency_key: str = "") -> str;
def deliver_pending(max_attempts: int = DEFAULT_MAX_ATTEMPTS) -> int;
def prune(delivered_ttl_s: float = DELIVERED_TTL_S) -> int;
def purge_dead(older_than_s: float = 0.0) -> int;
def dead_letters -> list[OutboxEntry];

def start_worker(interval_s: float = 1.0) -> None;
def start_worker_if_bridging(interval_s: float = 1.0) -> bool;
def stop_worker(timeout_s: float = 5.0) -> None;
def worker_running -> bool;

def seen_idempotency_key(key: str) -> bool;
def cached_result(key: str) -> (str | None);
def remember_idempotency_key(
    key: str, ttl_s: int = DEFAULT_SEEN_TTL_S, result: str = ""
) -> None;

def scoped_idempotency_key(raw: str, username: str, app: str, target: str) -> str;
def replay_cached(key: str) -> any;
def remember_response(key: str, response: any) -> any;

def _row_to_entry(row: tuple) -> OutboxEntry;
def _current_memory -> any;
def _primary_pg_store -> (PgStore | None);
def _writable_txn(mem: any, store: Store) -> None;
def _derive_worker_store(primary: PgStore) -> PgOutboxStore;
def _ensure_pg_schema(primary: PgStore) -> None;
def _sqlite_store -> SqliteOutboxStore;
def _store_for_request(writable: bool = True) -> OutboxStore;
def _store_for_worker -> OutboxStore;
def _store_for_seen -> OutboxStore;
def _lru_get(key: str, now: float) -> (str | None);
def _lru_put(key: str, expires_at: float, result: str) -> None;
def _run_coro(coro: any) -> any;
async def _deliver_one(item: OutboxEntry) -> any;
def _worker_loop(interval_s: float, stop: threading.Event) -> None;
