"""Asset file processing and copying utilities."""
import contextlib;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { get_config }

"""Handles copying of asset files (CSS, images, fonts, etc.) between directories."""
class AssetProcessor {
    with entry {
        ASSET_EXTENSIONS = {'.css','.scss','.sass','.less','.svg','.png','.jpg','.jpeg','.gif','.webp','.ico','.woff','.woff2','.ttf','.eot','.otf','.mp4','.webm','.mp3','.wav'};
    }

    def copy_assets(
        self: AssetProcessor,
        src_dir: Path,
        dest_dir: Path,
        preserve_structure: bool = True
    ) -> None;

    def copy_typescript_files(
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
