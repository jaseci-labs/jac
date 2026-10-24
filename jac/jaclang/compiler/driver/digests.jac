import hashlib;
import json;
import os;
import time;
import from pathlib { Path }

glob RACY_WINDOW_NS: int = 2000000000,
     LEDGER_SUBDIR: str = "digests",
     LEDGER_SHARD_CAP: int = 4096,
     _MEMO: dict[str, tuple[tuple[int, int, int, int], str]] = {},
     _SHARDS: dict[str, dict[str, list]] = {},
     _DIRTY: set[str] = set(),
     _FLUSH_ARMED: list[bool] = [];

def file_identity(path: str) -> (tuple[int, int, int, int] | None);

def file_sha256(path: str) -> str;

def flush_digests;

def forget_digests;

def _ledger_dir -> Path;

def _shard_name(real: str) -> str;

def _shard(name: str) -> dict[str, list];

def _hash_file(path: str) -> str;

def _stable(ident: tuple[int, int, int, int]) -> bool;
