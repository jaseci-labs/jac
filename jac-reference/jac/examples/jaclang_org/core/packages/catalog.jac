import logging;
import threading;
import from jaclang.packages.index { IndexEntry, Registry }

obj ApiParam {
    has name: str = "",
        kind: str = "normal",
        type: str = "any",
        optional: bool = False,
        value: str = "";
}

obj ApiMember {
    has name: str = "",
        kind: str = "",
        type: str = "",
        doc: str = "",
        value: str = "",
        params: list[ApiParam] = [],
        returns: str = "";
}

obj ApiSymbol {
    has name: str = "",
        kind: str = "",
        doc: str = "",
        type: str = "",
        returns: str = "",
        params: list[ApiParam] = [],
        bases: list[str] = [],
        members: list[ApiMember] = [];
}

obj ApiModule {
    has name: str = "",
        doc: str = "",
        symbols: list[ApiSymbol] = [];
}

obj PackageVersion {
    has version: str = "",
        published: str = "",
        yanked: bool = False,
        jac_version: str = "",
        deps: list[str] = [],
        pypi: list[str] = [],
        npm: list[str] = [];
}

obj PackageSummary {
    has name: str = "",
        org: str = "",
        short: str = "",
        role: str = "lib",
        description: str = "",
        latest: str = "",
        published: str = "",
        source: str = "",
        install: str = "",
        versions: int = 0,
        exports: list[str] = [],
        symbols: list[str] = [];
}

obj PackageCatalog {
    has ready: bool = False,
        error: str = "",
        fetched_at: str = "",
        packages: list[PackageSummary] = [];
}

obj PackageDetail {
    has found: bool = False,
        error: str = "",
        summary: PackageSummary | None = None,
        version: str = "",
        versions: list[PackageVersion] = [],
        modules: list[ApiModule] = [],
        readme_lines: list[str] = [],
        stars: int = 0,
        topics: list[str] = [];
}

obj RepoReadme {
    has lines: list[str] = [],
        stars: int = 0,
        topics: list[str] = [];
}

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
