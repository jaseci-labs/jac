import hashlib;
import logging;
import os;
import platform;
import shutil;
import signal;
import subprocess;
import tarfile;
import threading;
import time;
import urllib.request;
import zipfile;
import from pathlib { Path }
import from jaclang.runtimelib.dbcatalog { DbKind }
import from jaclang.runtimelib.store { ConnInfo }

glob logger = logging.getLogger(__name__),
     PG_MAJOR = 19,
     SOCK_PORT = 5432,
     PG_MAX_CONNECTIONS = 256,
     PG_RUN_USERS = ['jac', 'postgres', 'nobody'],
     PG_MAX_PRED_LOCKS_PER_TXN = 1024,
     PG_IDLE_IN_TXN_TIMEOUT_MS = 300000,
     ZONKY_BASE = (
         'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
         'embedded-postgres-binaries-'
     ),
     __all__ = [
         'PgRuntime',
         'PgPrivMode',
         'PgPrivPlan',
         'PgRunAs',
         'PG_MAJOR',
         'PG_MAX_CONNECTIONS',
         'PG_RUN_USERS',
         'PG_MAX_PRED_LOCKS_PER_TXN',
         'PG_IDLE_IN_TXN_TIMEOUT_MS',
         'pg_tuning_settings',
         'pinned_major',
         'dist_cache_dir',
         'pg_priv_plan',
         'pg_run_candidates'
     ];


enum PgPrivMode { AS_IS = 'as_is', DROP = 'drop', BLOCKED = 'blocked' }


obj PgRunAs {
    has name: str,
        uid: int,
        gid: int;
}


obj PgPrivPlan {
    has mode: PgPrivMode,
        run_as: (PgRunAs | None) = None,
        reason: str = '';
}


def pinned_major -> int;
def dist_cache_dir -> str;
def pg_run_candidates -> list[PgRunAs];
def pg_priv_plan(euid: int, candidates: list[PgRunAs]) -> PgPrivPlan;
def pg_tuning_settings -> dict[str, str];


obj PgRuntime {
    has data_dir: str,
        port: int = 0,
        tcp: bool = False,
        superuser: str = 'jac',
        database: str = 'jac',
        owner_path: str = '',
        kind: DbKind = DbKind.PROJECT,
        retention_days: int = 0,
        _bin_dir: (str | None) postinit,
        _proc: (any | None) postinit,
        _lock: threading.RLock postinit,
        _priv: (PgPrivPlan | None) postinit;

    def postinit -> None;
    def ensure -> ConnInfo;
    def serve -> int;
    def stop -> None;
    def is_running -> bool;
    def conninfo -> ConnInfo;
    def drop_database(database: str, force: bool = False) -> bool;
    def databases -> list;
    def fetch_dist -> str;
    def _sock_dir -> str;
    def _priv_plan -> PgPrivPlan;
    def _run_as -> (PgRunAs | None);
    def _as_user -> dict;
    def _grant_dir(path: str) -> None;
    def _resolve_binaries -> str;
    def _resolve_from_env -> (str | None);
    def _resolve_from_path -> (str | None);
    def _resolve_from_zonky -> (str | None);
    def _download_zonky(major: int) -> (str | None);
    def _fetch_dist(
        slug: str, version: str, dist_dir: str, bin_dir: str
    ) -> (str | None);

    def _zonky_versions -> list[str];
    def _initdb_if_needed(bin_dir: str) -> None;
    def _server_opts -> str;
    def _start(bin_dir: str) -> None;
    def _wait_ready(timeout: float = 60.0) -> None;
    def _ensure_database -> None;
    def _reap_scratch(conn: any) -> int;
    def _sweep_on_start -> None;
}
