import base64;
import csv;
import hashlib;
import io;
import json;
import os;
import zipfile;
import from typing { BinaryIO }

glob BUILD_DATA_FILE: str = "_jac_build.json";

def record_hash(data: bytes) -> str;

def record_text(rows: list[tuple[str, str, int]], record_path: str) -> str;

def write_wheel(
    out: BinaryIO,
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
);

def wheel_bytes(
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
) -> bytes;

def _read_file(path: str) -> bytes;

def get_requires_for_build_wheel(
    config_settings: dict[str, str] | None = None  # jac:ignore[W2003]
) -> list[str];

def build_wheel(
    wheel_directory: str,
    config_settings: dict[str, str] | None = None,  # jac:ignore[W2003]
    metadata_directory: str | None = None  # jac:ignore[W2003]
) -> str;
