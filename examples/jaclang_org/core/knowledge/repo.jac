import os;
import re;
import json;
import shutil;
import subprocess;
import threading;
import from pathlib { Path }
import from datetime { datetime, UTC }

glob REPO_URL_ENV: str = "JACORG_REPO_URL",
     DEFAULT_REPO_URL: str = "https://github.com/jaseci-labs/jac.git",
     DIR_ENV: str = "JACORG_KNOWLEDGE_DIR",
     SPARSE_PATHS: list[str] = ["jac/jaclang/cli/docs", "jac/jaclang/cli/skills", "jac/examples"],
     DOCS_PATH: str = "jac/jaclang/cli/docs",
     SKILLS_PATH: str = "jac/jaclang/cli/skills",
     FETCH_EVERY_S: float = 3600.0,
     GIT_TIMEOUT_S: int = 900,
     _PROCESS_LOCK: threading.Lock = threading.Lock();

obj RepoStatus {
    has phase: str = "idle",
        detail: str = "",
        serving_version: str = "",
        checked_out: str = "",
        fetched_at: str = "",
        updated_at: str = "";
}

def knowledge_dir -> Path;

def repo_dir -> Path;

def repo_url -> str;

"""Where the docs of release `tag` can be read on the web."""
def docs_source_url(tag: str) -> str;

def git(args: list[str], cwd: Path | None = None, extra_env: dict[str, str] | None = None) -> str;

def git_available -> bool;

def version_of(tag: str) -> tuple[int, int, int] | None;

def release_tags -> list[str];

def checkout_target(serving: str, tags: list[str]) -> str;

def read_status -> RepoStatus;

def write_status(status: RepoStatus);

def ensure_repo(serving: str) -> RepoStatus;

def checkout_root -> Path | None;
