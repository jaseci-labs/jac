import hashlib;
import json;
import os;
import time;
import urllib.error;
import urllib.request;
import from pathlib { Path }
import from urllib.parse { urljoin, urlsplit }

glob DEFAULT_REGISTRY_NAME: str = "jaseci",
     DEFAULT_REGISTRY_URL: str = "https://raw.githubusercontent.com/jaseci-labs/jac-index/main/",
     REGISTRY_ENV: str = "JAC_REGISTRY",
     PROTOCOL_VERSION: int = 1,
     SETTINGS_NAME: str = "config.json",
     INDEX_DIR: str = "index",
     API_DIR: str = "api",
     GITHUB_API: str = "https://api.github.com",
     USER_AGENT: str = "jac-packages";

obj RegistryError(Exception) {}

obj IndexEntry {
    has name: str,
        version: str,
        sha256: str,
        role: str = "lib",
        description: str = "",
        deps: dict[str, str] = {},
        pypi: dict[str, str] = {},
        npm: dict[str, str] = {},
        jac_version: str = "",
        api_digest: str = "",
        exports: list[str] = [],
        pinned: list[str] = [],
        yanked: bool = False,
        published: str = "",
        source: str = "",
        upload: str = "";

    static def from_json(row: dict[str, any]) -> IndexEntry;
    def to_json -> dict[str, any];
    def to_line -> str;
}

def _str_map(raw: any) -> dict[str, str];

def parse_index_lines(text: str) -> list[IndexEntry];

def index_rel_path(name: str) -> str;

def api_rel_path(name: str, version: str) -> str;

def name_of_index_path(rel: str) -> str | None;

def _github_tree(repo: str, branch: str) -> list[str];

def _is_local(url: str) -> bool;

def _local_path(url: str) -> Path;

obj Registry {
    has name: str,
        url: str,
        _settings: dict[str, any] | None = None,
        _entries: dict[str, list[IndexEntry]] = {};

    def base -> str;
    def key -> str;
    def _cache_file(rel: str) -> Path;
    def _read(rel: str) -> str | None;
    def settings -> dict[str, any];
    def entries(name: str) -> list[IndexEntry];
    def list_names -> list[str];
    def api(name: str, version: str) -> dict[str, any] | None;
    def find(name: str, version: str) -> IndexEntry | None;
    def blob_url(sha256: str) -> str;
    def fetch_blob(item: IndexEntry) -> bytes;
}

def fetch_verified(url: str, sha256: str, label: str) -> bytes;

def registry_urls(configured: dict[str, str] | None = None) -> dict[str, str];

glob _open_registries: dict[str, Registry] = {};

def registry_named(name: str, configured: dict[str, str] | None = None) -> Registry;

def forget_registries;
