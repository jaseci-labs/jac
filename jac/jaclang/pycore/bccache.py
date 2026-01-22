"""Bytecode caching for Jac modules.

This module provides disk-based caching for compiled Jac bytecode,
similar to Python's __pycache__ mechanism. Cache files are stored
in a global user cache directory following platform conventions:
- Linux:   ~/.cache/jac/bytecode/
- macOS:   ~/Library/Caches/jac/bytecode/
- Windows: %LOCALAPPDATA%/jac/cache/bytecode/
"""

from __future__ import annotations

import hashlib
import marshal
import os
import sys
import types
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, Final

if TYPE_CHECKING:
    from jaclang.project.config import JacConfig


def get_global_cache_dir() -> Path:
    """Get the platform-appropriate global cache directory for Jac bytecode.

    Returns:
        Path to the global cache directory:
        - Linux:   ~/.cache/jac/bytecode/ (respects XDG_CACHE_HOME)
        - macOS:   ~/Library/Caches/jac/bytecode/
        - Windows: %LOCALAPPDATA%/jac/cache/bytecode/
    """
    if sys.platform == "win32":
        # Windows: Use LOCALAPPDATA
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache" / "bytecode"
    elif sys.platform == "darwin":
        # macOS: Use ~/Library/Caches
        return Path.home() / "Library" / "Caches" / "jac" / "bytecode"
    else:
        # Linux/Unix: Follow XDG Base Directory Specification
        xdg_cache = os.environ.get("XDG_CACHE_HOME")
        base = Path(xdg_cache) if xdg_cache else Path.home() / ".cache"
        return base / "jac" / "bytecode"


def discover_annex_files(source_path: str, suffix: str = ".impl.jac") -> list[str]:
    """Discover annex files (.impl.jac, .test.jac) for a source .jac or .cl.jac file.

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/, test/).
    """
    src = Path(source_path).resolve()
    # Skip non-.jac files and files that are the same annex type as requested
    if not src.name.endswith(".jac") or src.name.endswith(suffix):
        return []

    # Handle .cl.jac files: extract base name (e.g., foo.cl.jac -> foo)
    base = src.stem
    if base.endswith(".cl"):
        base = base[:-3]
    mod_folder = src.parent / (base + suffix[:-4])  # foo.impl/, foo.test/
    shared_folder = suffix[1:-4]  # Extract "impl" or "test"
    dirs = [src.parent, mod_folder, src.parent / shared_folder]
    return [
        str(f)
        for d in dirs
        if d.is_dir()
        for f in d.iterdir()
        if f.is_file()
        and f.name.endswith(suffix)
        and (d == mod_folder or f.name.startswith(f"{base}."))
    ]


def discover_base_file(annex_path: str) -> str | None:
    """Discover the base .jac or .cl.jac file for an annex file (.impl.jac, .test.jac).

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/).
    For multi-part names like "foo.bar.impl.jac", only the first component is used.
    """
    src = Path(annex_path).resolve()
    annex_types = {".impl.jac": ".impl", ".test.jac": ".test"}

    # Find matching annex type and extract base name
    for suffix, folder_suffix in annex_types.items():
        if src.name.endswith(suffix):
            base_name = src.name[: -len(suffix)].split(".")[0]
            parent = src.parent.name
            # Build search candidates: (directory, base_name_to_search)
            candidates = [(src.parent, base_name)]
            if parent.endswith(folder_suffix):  # Module-specific folder
                candidates.append((src.parent.parent, parent[: -len(folder_suffix)]))
            if parent in {"impl", "test"}:  # Shared folder
                candidates.append((src.parent.parent, base_name))
            # Search for base file (both .jac and .cl.jac can have annexes)
            for directory, name in candidates:
                for ext in (".jac", ".cl.jac"):
                    path = directory / f"{name}{ext}"
                    if path.is_file() and path != src:
                        return str(path)
            break
    return None


@dataclass(frozen=True, slots=True)
class CacheKey:
    """Immutable key identifying a cached bytecode entry.

    Attributes:
        source_path: Absolute path to the source .jac file.
        minimal: Whether minimal compilation mode was used.
        python_version: Python version tuple (major, minor).
    """

    source_path: str
    minimal: bool
    python_version: tuple[int, int]

    @classmethod
    def for_source(cls, source_path: str, minimal: bool = False) -> CacheKey:
        """Create a cache key for the current Python version."""
        return cls(
            source_path=source_path,
            minimal=minimal,
            python_version=(sys.version_info.major, sys.version_info.minor),
        )


class BytecodeCache:
    """Abstract interface for bytecode caching."""

    def get(self, _key: CacheKey) -> types.CodeType | None:
        """Retrieve cached bytecode if valid."""
        raise NotImplementedError

    def put(self, _key: CacheKey, _bytecode: bytes) -> None:
        """Store bytecode in the cache."""
        raise NotImplementedError


class DiskBytecodeCache(BytecodeCache):
    """Disk-based bytecode cache using a global user cache directory.

    Cache files are stored in a platform-appropriate global location:
    - Linux:   ~/.cache/jac/bytecode/
    - macOS:   ~/Library/Caches/jac/bytecode/
    - Windows: %LOCALAPPDATA%/jac/cache/bytecode/

    Filenames include a path hash, Python version, and compilation mode
    to ensure uniqueness across different projects and avoid conflicts.

    Example:
        source:  /project/src/main.jac
        cache:   ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.jbc
                 ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.minimal.jbc
    """

    EXTENSION: Final[str] = ".jbc"
    MINIMAL_SUFFIX: Final[str] = ".minimal"

    def __init__(self, config: JacConfig | None = None) -> None:
        """Initialize the cache with optional config."""
        self._config = config
        self._cache_dir: Path | None = None

    def _get_cache_dir(self) -> Path:
        """Get the global cache directory."""
        if self._cache_dir is not None:
            return self._cache_dir

        self._cache_dir = get_global_cache_dir()
        return self._cache_dir

    def _get_cache_path(self, key: CacheKey) -> Path:
        """Generate the cache file path for a given key.

        Uses a hash of the full source path to ensure uniqueness when
        files with the same name exist in different directories.
        """
        source = Path(key.source_path).resolve()
        cache_dir = self._get_cache_dir()

        # Create a short hash of the full path for uniqueness
        path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8]

        major, minor = key.python_version
        py_version = f"cpython-{major}{minor}"
        suffix = (
            f"{self.MINIMAL_SUFFIX}{self.EXTENSION}" if key.minimal else self.EXTENSION
        )
        cache_name = f"{source.stem}.{path_hash}.{py_version}{suffix}"

        return cache_dir / cache_name

    def _is_valid(self, key: CacheKey, cache_path: Path) -> bool:
        """Check if cached bytecode is still valid.

        The cache is valid if:
        - The cache file exists
        - The cache is newer than the source file
        - The cache is newer than all impl files associated with the source
        """
        if not cache_path.exists():
            return False

        try:
            cache_mtime = os.path.getmtime(cache_path)

            # Check source file modification time
            source_mtime = os.path.getmtime(key.source_path)
            if cache_mtime <= source_mtime:
                return False

            # Check all impl files - cache must be newer than all of them
            for impl_path in discover_annex_files(key.source_path):
                try:
                    impl_mtime = os.path.getmtime(impl_path)
                    if cache_mtime <= impl_mtime:
                        return False
                except OSError:
                    # If we can't stat an impl file, invalidate cache to be safe
                    return False

            return True
        except OSError:
            return False

    def get(self, key: CacheKey) -> types.CodeType | None:
        """Retrieve cached bytecode if valid."""
        cache_path = self._get_cache_path(key)

        if not self._is_valid(key, cache_path):
            return None

        try:
            bytecode = cache_path.read_bytes()
            return marshal.loads(bytecode)
        except (OSError, ValueError, EOFError):
            return None

    def put(self, key: CacheKey, bytecode: bytes) -> None:
        """Store bytecode in the cache."""
        cache_path = self._get_cache_path(key)

        try:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_bytes(bytecode)
        except OSError:
            pass  # Silently ignore write failures


# Default cache instance (singleton)
_default_cache: BytecodeCache | None = None


def get_bytecode_cache() -> BytecodeCache:
    """Get the default bytecode cache instance."""
    global _default_cache
    if _default_cache is None:
        _default_cache = DiskBytecodeCache()
    return _default_cache
