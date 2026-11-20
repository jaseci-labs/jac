import json;
import os;
import shutil;
import subprocess;
import tempfile;
import tomllib;
import from pathlib { Path }
import from urllib.parse { urlsplit }

glob ORGS_DIR: str = "orgs",
     INDEX_DIR: str = "index",
     RESERVED_FILE: str = "reserved.txt",
     UPLOAD_HOSTS: tuple[str, ...] = ("github.com", "objects.githubusercontent.com");

obj VerifyReport {
    has problems: list[str] = [],
        mirror: list[dict[str, str]] = [],
        checked: list[str] = [],
        api_files: set[str] = set(),
        any_upload: bool = False;
}

def _git(base_root: Path, args: list[str]) -> str;

def _at_base(base_root: Path, base: str, rel: str) -> str | None;

def _owners(text: str | None) -> list[str];

def _reserved(base_root: Path) -> set[str];

def _changed_files(base_root: Path, base: str) -> list[str];

def _check_org(
    base_root: Path, base: str, rel: str, author: str, outcome: VerifyReport
);

def _verify_entry(
    base_root: Path,
    registry: Registry,
    item: IndexEntry,
    history: list[IndexEntry],
    outcome: VerifyReport
);

def _check_api_file(
    base_root: Path, stage: Path, item: IndexEntry, outcome: VerifyReport
);

def _verify_library(
    tree: Path,
    registry: Registry,
    item: IndexEntry,
    version: Version,
    history: list[IndexEntry],
    outcome: VerifyReport
);

def _check_index_file(
    base_root: Path,
    base: str,
    rel: str,
    author: str,
    registry: Registry,
    outcome: VerifyReport
);

def verify_index(
    base_root: Path, base: str, author: str, any_upload: bool = False
) -> VerifyReport;

def run_verify(index_dir: str, base: str, author: str, mirror_out: str = "") -> int;
