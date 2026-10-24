import os;
import from pathlib { Path }

obj ResolveError(Exception) {}

obj LocalPackage {
    has name: str,
        version: Version,
        config: JacConfig,
        tree: Path,
        source: str,
        sha256: str = "";
}

def running_jac_version -> Version;

def pip_requirement(name: str, spec: str) -> str;

def manifest_pypi(config: JacConfig) -> dict[str, str];

def manifest_npm(config: JacConfig) -> dict[str, str];

def manifest_inputs(config: JacConfig) -> str;

obj GraphSource(PackageSource) {
    has root_dir: Path,
        registries: dict[str, str],
        locked: dict[str, str] = {},
        unlock: set[str] = set(),
        unlock_all: bool = False,
        jac_version: Version = Version.parse("0.0.0"),
        locals: dict[str, LocalPackage] = {},
        local_requesters: dict[str, Path] = {},
        origin_registry: dict[str, str] = {},
        prerelease: set[str] = set();

    def registry_for(name: str) -> Registry;
    def note_requirement(name: str, req: Requirement);
    def add_local(dep: PackageDep, base: Path) -> LocalPackage;
    override def versions(name: str) -> list[Version];
    def _entry(name: str, version: Version) -> IndexEntry;
    override def dependencies(name: str, version: Version) -> dict[str, Requirement];
    override def unavailable_reason(name: str, version: Version) -> str;
    override def preferred(name: str) -> Version | None;
    override def allows_prerelease(name: str) -> bool;
    def locked_entry(name: str, version: Version) -> LockedPackage;
}

def _mark_dev(
    packages: list[LockedPackage], runtime_roots: list[str]
) -> list[LockedPackage];

def resolve_graph(
    config: JacConfig, previous: Lockfile | None = None, update: list[str] | None = None
) -> Lockfile;
