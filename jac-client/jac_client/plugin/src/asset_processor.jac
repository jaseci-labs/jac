"""Asset file processing and copying utilities."""
import contextlib;
import shutil;
import from pathlib { Path }

"""Handles copying of asset files (CSS, images, fonts, etc.) between directories."""
class AssetProcessor {
    with entry {
        ASSET_EXTENSIONS = {'.css','.scss','.sass','.less','.svg','.png','.jpg','.jpeg','.gif','.webp','.ico','.woff','.woff2','.ttf','.eot','.otf','.mp4','.webm','.mp3','.wav'};
    }

    """Copy CSS and other asset files from source to destination recursively."""
    def copy_assets(
        self: AssetProcessor,
        src_dir: Path,
        dest_dir: Path,
        preserve_structure: bool = True
    ) -> None {
        if not src_dir.exists() {
            return;
        }
        dest_dir.mkdir(parents=True, exist_ok=True);

        def copy_recursive(
            source: Path, destination: Path, base: (Path | None) = None
        ) -> None {
            if not source.exists() {
                return;
            }
            if (base is None) {
                base = source;
            }
            for item in source.iterdir() {
                if (item.is_file() and (item.suffix.lower() in self.ASSET_EXTENSIONS)) {
                    if preserve_structure {
                        relative_path = item.relative_to(base);
                        dest_file = destination / relative_path;
                    } else {
                        dest_file = destination / item.name;
                    }
                    dest_file.parent.mkdir(parents=True, exist_ok=True);
                    with contextlib.suppress(OSError, shutil.Error) {
                        shutil.copy2(item, dest_file);
                    }
                } elif item.is_dir() {
                    copy_recursive(item, destination, base);
                }
            }
        }
        copy_recursive(src_dir, dest_dir);
    }

    """Copy TypeScript files (.ts, .tsx) from source to destination recursively."""
    def copy_typescript_files(
        self: AssetProcessor,
        src_dir: Path,
        dest_dir: Path,
        preserve_structure: bool = True
    ) -> None {
        if not src_dir.exists() {
            return;
        }
        dest_dir.mkdir(parents=True, exist_ok=True);
        ts_extensions = {'.ts','.tsx'};

        def copy_recursive(
            source: Path, destination: Path, base: (Path | None) = None
        ) -> None {
            if not source.exists() {
                return;
            }
            if (base is None) {
                base = source;
            }
            for item in source.iterdir() {
                if (item.is_file() and (item.suffix.lower() in ts_extensions)) {
                    if preserve_structure {
                        relative_path = item.relative_to(base);
                        dest_file = destination / relative_path;
                    } else {
                        dest_file = destination / item.name;
                    }
                    dest_file.parent.mkdir(parents=True, exist_ok=True);
                    with contextlib.suppress(OSError, shutil.Error) {
                        shutil.copy2(item, dest_file);
                    }
                } elif item.is_dir() {
                    copy_recursive(item, destination, base);
                }
            }
        }
        copy_recursive(src_dir, dest_dir);
    }
}
