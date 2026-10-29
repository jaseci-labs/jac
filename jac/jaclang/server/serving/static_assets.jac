import logging;
import from pathlib { Path }

glob _logger = logging.getLogger(__name__);


obj AssetRoot {
    has url_prefix: str,
        resolved_dir: Path,
        is_mount: bool = False;
}


def _resolve_root(local_dir: Path) -> Path;


def _assets_dir(project_root: Path) -> Path;


def _public_dirs(project_root: Path) -> list[Path];


def asset_root_table(
    project_root: Path, client_dist: Path, mounts: (list[dict[str, str]] | None) = None
) -> list[AssetRoot];


def _remainder(url_path: str, prefix: str) -> (str | None);


def resolve_asset(table: list[AssetRoot], url_path: str) -> (Path | None);


def mount_claims(table: list[AssetRoot], url_path: str) -> bool;


def asset_cache_policy(target: Path) -> str;
