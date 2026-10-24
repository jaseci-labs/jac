import from pathlib { Path }

glob PYPI_HINT: str = "Jac packages are scoped as org/name; install a Python package with 'jac install --pypi <name>'";

obj PackageSpec {
    has name: str,
        version: str = "";

    static def parse(text: str) -> PackageSpec;
}

def split_package_specs(texts: list[str]) -> tuple[list[PackageSpec], list[str]];

def _install_python(
    config: JacConfig,
    lock: Lockfile,
    specs: list[str],
    ctx: InstallContext,
    refresh: bool
) -> bool;

def install_project(
    config: JacConfig,
    include_dev: bool = False,
    extras: list[str] | None = None,
    scale: bool = False,
    frozen: bool = False,
    skip_npm: bool = False,
    update: list[str] | None = None,
    ctx: InstallContext | None = None
) -> int;

def _org_collisions(config: JacConfig, lock: Lockfile) -> list[str];

def _bun_lock_digest(config: JacConfig) -> str;

def _dep_from_source(git: str, path: str, rev: str, base: Path) -> PackageDep;

def add_packages(
    config: JacConfig,
    texts: list[str],
    dev: bool = False,
    git: str = "",
    path: str = "",
    rev: str = "",
    ctx: InstallContext | None = None
) -> int;

def remove_packages(config: JacConfig, texts: list[str], dev: bool = False) -> int;
