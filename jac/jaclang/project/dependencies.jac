glob PACKAGE_DEP_KEYS: tuple[str, ...] = (
         "version",
         "path",
         "git",
         "rev",
         "registry"
     ),
     PYPI_TABLE: str = "pypi",
     MIGRATE_HINT: str = "run 'jac fix dependencies' to move them";

obj ManifestError(ValueError) {}

obj PackageDep {
    has name: str,
        version: str = "*",
        path: str = "",
        git: str = "",
        rev: str = "",
        registry: str = "",
        dev: bool = False;

    def kind -> str;
    def to_toml -> str | dict[str, str];
    static def parse(name: str, value: any, dev: bool, section: str) -> PackageDep;
}

obj DependencyTables {
    has packages: dict[str, PackageDep] = {},
        pypi: dict[str, str] = {},
        pypi_git: dict[str, dict[str, str]] = {},
        ecosystems: dict[str, dict[str, any]] = {};
}

def _looks_like_package_dep(value: dict[str, any]) -> bool;

def split_dependency_table(
    table: dict[str, any], dev: bool, section: str
) -> DependencyTables;

def migrate_dependency_table(table: dict[str, any]) -> dict[str, any];
