"""Bytecode caching for Jac modules.

This module provides disk-based caching for compiled Jac bytecode,
similar to Python's __pycache__ mechanism. Cache files are stored
in a single .jaccache/ directory in the current working directory.
"""

from __future__ import annotations

import hashlib
import marshal
import os
import sys
import types
from dataclasses import dataclass
from pathlib import Path
from typing import Final


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
    """Disk-based bytecode cache using a single .jaccache/ directory.

    Cache files are stored in .jaccache/ in the current working directory,
    with filenames that include a path hash, Python version, and
    compilation mode to avoid conflicts.

    Example:
        source:  /project/src/main.jac
        cache:   .jaccache/main.a1b2c3d4.cpython-312.jbc
                 .jaccache/main.a1b2c3d4.cpython-312.minimal.jbc
    """

    CACHE_DIR: Final[str] = ".jaccache"
    EXTENSION: Final[str] = ".jbc"
    MINIMAL_SUFFIX: Final[str] = ".minimal"

    def _get_cache_path(self, key: CacheKey) -> Path:
        """Generate the cache file path for a given key.

        Uses a hash of the full source path to ensure uniqueness when
        files with the same name exist in different directories.
        """
        source = Path(key.source_path).resolve()
        cache_dir = Path.cwd() / self.CACHE_DIR

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
        """Check if cached bytecode is still valid (exists and newer than source)."""
        if not cache_path.exists():
            return False

        try:
            source_mtime = os.path.getmtime(key.source_path)
            cache_mtime = os.path.getmtime(cache_path)
            return cache_mtime > source_mtime
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
