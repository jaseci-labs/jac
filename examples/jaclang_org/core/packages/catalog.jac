import datetime;
import logging;
import threading;

glob CATALOG_TTL_S: float = 600.0,
     README_TTL_S: float = 3600.0,
     USER_AGENT: str = "jaclang-org-packages",
     _CACHE: dict[str, any] = {},
     _LOCK: threading.Lock = threading.Lock(),
     log: logging.Logger = logging.getLogger("packages.catalog");

def open_registry -> Registry;

def install_command(name: str, role: str) -> str;

def latest_entry(entries: list[IndexEntry]) -> IndexEntry | None;

def version_of(e: IndexEntry) -> PackageVersion;

def summary_of(
    name: str, entries: list[IndexEntry], surface: dict[str, any] | None
) -> PackageSummary | None;

def params_of(desc: dict[str, any]) -> list[ApiParam];

def api_modules(surface: dict[str, any] | None) -> list[ApiModule];

def safe_readme(text: str, owner: str, repo: str, branch: str) -> list[str];

def repo_readme(source: str) -> RepoReadme;

def build_catalog -> PackageCatalog;

def cached(key: str, ttl: float, make: any) -> any;

def:pub package_catalog -> PackageCatalog;

def:pub package_detail(name: str, version: str = "") -> PackageDetail;
