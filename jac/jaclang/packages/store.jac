import hashlib;
import json;
import os;
import shutil;
import from pathlib { Path }

glob MARKER_NAME: str = ".jac-package.json";

obj StoreError(Exception) {}

def store_path(name: str, version: str, sha256: str) -> Path;

def is_materialized(path: Path, sha256: str) -> bool;

def materialize(
    name: str, version: str, sha256: str, data: bytes, source: str
) -> Path;

def cached(name: str, version: str, sha256: str) -> Path | None;
