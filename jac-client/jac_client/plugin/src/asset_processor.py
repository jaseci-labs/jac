"""Asset file processing and copying utilities."""

from __future__ import annotations

import contextlib
import shutil
from pathlib import Path


class AssetProcessor:
    """Handles copying of asset files (CSS, images, fonts, etc.) between directories."""

    # Asset file extensions to copy
    ASSET_EXTENSIONS = {
        ".css",
        ".scss",
        ".sass",
        ".less",
        ".svg",
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".webp",
        ".ico",
        ".woff",
        ".woff2",
        ".ttf",
        ".eot",
        ".otf",
        ".mp4",
        ".webm",
        ".mp3",
        ".wav",
    }

    def copy_assets(
        self, src_dir: Path, dest_dir: Path, preserve_structure: bool = True
    ) -> None:
        """Copy CSS and other asset files from source to destination recursively.

        Babel only transpiles JavaScript files, so CSS and other assets need to be
        manually copied to the build directory for Vite to resolve them.
        This method recursively copies assets from subdirectories while preserving
        the directory structure.

        Args:
            src_dir: Source directory to copy from
            dest_dir: Destination directory to copy to
            preserve_structure: Whether to preserve relative path structure
        """
        if not src_dir.exists():
            return

        # Ensure destination directory exists
        dest_dir.mkdir(parents=True, exist_ok=True)

        def copy_recursive(
            source: Path, destination: Path, base: Path | None = None
        ) -> None:
            """Recursively copy asset files from source to destination.

            Args:
                source: Source directory to copy from
                destination: Destination directory to copy to
                base: Base directory for calculating relative paths (defaults to source)
            """
            if not source.exists():
                return

            if base is None:
                base = source

            for item in source.iterdir():
                if item.is_file() and item.suffix.lower() in self.ASSET_EXTENSIONS:
                    if preserve_structure:
                        # Preserve relative path structure from base
                        relative_path = item.relative_to(base)
                        dest_file = destination / relative_path
                    else:
                        # Just copy to destination root
                        dest_file = destination / item.name

                    dest_file.parent.mkdir(parents=True, exist_ok=True)
                    with contextlib.suppress(OSError, shutil.Error):
                        shutil.copy2(item, dest_file)
                elif item.is_dir():
                    # Recursively process subdirectories
                    copy_recursive(item, destination, base)

        # Copy files from src_dir root and recursively from subdirectories
        copy_recursive(src_dir, dest_dir)

    def copy_typescript_files(
        self, src_dir: Path, dest_dir: Path, preserve_structure: bool = True
    ) -> None:
        """Copy TypeScript files (.ts, .tsx) from source to destination recursively.

        TypeScript files need to be copied to the build directory so Vite can resolve
        them during bundling. Babel only processes JavaScript files.

        Args:
            src_dir: Source directory to copy from
            dest_dir: Destination directory to copy to
            preserve_structure: Whether to preserve relative path structure
        """
        if not src_dir.exists():
            return

        # Ensure destination directory exists
        dest_dir.mkdir(parents=True, exist_ok=True)

        ts_extensions = {".ts", ".tsx"}

        def copy_recursive(
            source: Path, destination: Path, base: Path | None = None
        ) -> None:
            """Recursively copy TypeScript files from source to destination.

            Args:
                source: Source directory to copy from
                destination: Destination directory to copy to
                base: Base directory for calculating relative paths (defaults to source)
            """
            if not source.exists():
                return

            if base is None:
                base = source

            for item in source.iterdir():
                if item.is_file() and item.suffix.lower() in ts_extensions:
                    if preserve_structure:
                        # Preserve relative path structure from base
                        relative_path = item.relative_to(base)
                        dest_file = destination / relative_path
                    else:
                        # Just copy to destination root
                        dest_file = destination / item.name

                    dest_file.parent.mkdir(parents=True, exist_ok=True)
                    with contextlib.suppress(OSError, shutil.Error):
                        shutil.copy2(item, dest_file)
                elif item.is_dir():
                    # Recursively process subdirectories
                    copy_recursive(item, destination, base)

        # Copy files from src_dir root and recursively from subdirectories
        copy_recursive(src_dir, dest_dir)
