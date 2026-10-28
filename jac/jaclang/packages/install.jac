import from pathlib { Path }

obj InstallError(Exception) {}

obj SyncResult {
    has lock: Lockfile,
        targets: dict[str, Path] = {},
        resolved: bool = False;
}

def lock_path(config: JacConfig) -> Path;

def load_lock(config: JacConfig) -> Lockfile | None;

def has_packages(config: JacConfig) -> bool;

def lock_is_current(config: JacConfig, lock: Lockfile | None) -> bool;

def project_dir(config: JacConfig) -> Path;

def fetch_locked(config: JacConfig, pkg: LockedPackage) -> Path;

def _registry_for_source(config: JacConfig, base: str) -> any;

def mount_targets(
    config: JacConfig, lock: Lockfile, include_dev: bool = True
) -> dict[str, Path];

def sync(
    config: JacConfig,
    update: list[str] | None = None,
    frozen: bool = False,
    include_dev: bool = True
) -> SyncResult;

def write_lock(config: JacConfig, lock: Lockfile);

def package_pip_requirements(
    lock: Lockfile | None, include_dev: bool
) -> list[tuple[str, str, str]];

def package_npm_requirements(
    lock: Lockfile | None, include_dev: bool
) -> list[tuple[str, str, str]];

def describe_sync(result: SyncResult);
