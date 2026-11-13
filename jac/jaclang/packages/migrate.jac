import copy;
import tomllib;
import from pathlib { Path }

glob DEP_TABLES: tuple[str, ...] = ("dependencies", "dev-dependencies");

obj ManifestMigration {
    has path: Path,
        moved: list[str] = [],
        text: str = "",
        lossless: bool = True;
}

def _migrate_scope(scope: dict[str, any], prefix: str, moved: list[str]);

def migrate_manifest(path: Path) -> ManifestMigration;

def find_manifests(paths: list[str]) -> list[Path];
