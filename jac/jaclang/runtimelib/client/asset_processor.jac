import contextlib;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.client.assets { ASSET_COPY_EXTENSIONS }

class AssetProcessor {
    with entry {
        ASSET_EXTENSIONS = ASSET_COPY_EXTENSIONS;
    }

    def copy_assets(
        self: AssetProcessor,
        src_dir: Path,
        dest_dir: Path,
        preserve_structure: bool = True
    ) -> None;

    def copy_custom_asset_types(
        self: AssetProcessor,
        src_dir: Path,
        dest_dir: Path,
        preserve_structure: bool = True
    ) -> None;
}
