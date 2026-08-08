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
import from typing { Any }

import from jaclang.runtimelib.store { ConnInfo }

glob logger = logging.getLogger(__name__),
     PG_MAJOR = 19,
     SOCK_PORT = 5432,
     ZONKY_BASE = (
         'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
         'embedded-postgres-binaries-'
     ),
     __all__ = ['PgRuntime', 'PG_MAJOR', 'pinned_major', 'dist_cache_dir'];


def pinned_major -> int;
def dist_cache_dir -> str;


obj PgRuntime {
    has data_dir: str,
        port: int = 0,
        tcp: bool = False,
        superuser: str = 'jac',
        database: str = 'jac',
        _bin_dir: (str | None) postinit,
        _proc: (Any | None) postinit,
        _lock: threading.RLock postinit;

    def postinit -> None;
    def ensure -> ConnInfo;
    def serve -> int;
    def stop -> None;
    def is_running -> bool;
    def conninfo -> ConnInfo;
    def _sock_dir -> str;
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
    def _start(bin_dir: str) -> None;
    def _wait_ready(timeout: float = 60.0) -> None;
    def _ensure_database -> None;
}
