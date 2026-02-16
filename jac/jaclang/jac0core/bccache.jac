"""Bytecode caching for Jac modules.

This module provides disk-based caching for compiled Jac bytecode,
similar to Python's __pycache__ mechanism. Cache files are stored
in a global user cache directory following platform conventions:
- Linux:   ~/.cache/jac/bytecode/
- macOS:   ~/Library/Caches/jac/bytecode/
- Windows: %LOCALAPPDATA%/jac/cache/bytecode/
"""
import hashlib;
import marshal;
import os;
import pickle;
import sys;
import types;
import from pathlib { Path }
import from dataclasses { dataclass }
import from typing { TYPE_CHECKING, Any, Final }

with entry {
    if TYPE_CHECKING {
        import from jaclang.project.config { JacConfig }
    }
}

"""Get the platform-appropriate global cache directory for Jac bytecode.

    Returns:
        Path to the global cache directory:
        - Linux:   ~/.cache/jac/bytecode/ (respects XDG_CACHE_HOME)
        - macOS:   ~/Library/Caches/jac/bytecode/
        - Windows: %LOCALAPPDATA%/jac/cache/bytecode/
    """
def get_global_cache_dir -> Path {
    if (sys.platform == 'win32') {
        base = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local'));
        return (base / 'jac' / 'cache' / 'bytecode');
    } elif (sys.platform == 'darwin') {
        return Path.home() / 'Library' / 'Caches' / 'jac' / 'bytecode';
    } else {
        xdg_cache = os.environ.get('XDG_CACHE_HOME');
        base = Path(xdg_cache) if xdg_cache else (Path.home() / '.cache');
        return base / 'jac' / 'bytecode';
    }
}

"""Discover annex files (.impl.jac, .test.jac) for a source .jac or .cl.jac file.

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/, test/).
    """
def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str] {
    src = Path(source_path).resolve();
    if (not src.name.endswith('.jac') or src.name.endswith(suffix)) {
        return [];
    }
    base = src.stem;
    if base.endswith('.cl') {
        base = base[:-3];
    }
    mod_folder = src.parent / (base + suffix[:-4]);
    shared_folder = suffix[1:-4];
    dirs = [src.parent, mod_folder, (src.parent / shared_folder)];
    return [
        str(f)
        for d in dirs
        if d.is_dir()
        for f in d.iterdir()
        if (
            f.is_file()
            and f.name.endswith(suffix)
            and ((d == mod_folder) or f.name.startswith(f"{base}."))
        )
    ];
}

"""Discover the base .jac or .cl.jac file for an annex file (.impl.jac, .test.jac).

    Searches: same directory, module-specific folder (foo.impl/), shared folder (impl/).
    For multi-part names like "foo.bar.impl.jac", only the first component is used.
    """
def discover_base_file(annex_path: str) -> (str | None) {
    src = Path(annex_path).resolve();
    annex_types = {'.impl.jac': '.impl', '.test.jac': '.test'};
    for (suffix, folder_suffix) in annex_types.items() {
        if src.name.endswith(suffix) {
            base_name = src.name[:-len(suffix)].split('.')[0];
            parent = src.parent.name;
            candidates = [(src.parent, base_name)];
            if parent.endswith(folder_suffix) {
                candidates.append((src.parent.parent, parent[:-len(folder_suffix)]));
            }
            if (parent in {'impl','test'}) {
                candidates.append((src.parent.parent, base_name));
            }
            for (directory, name) in candidates {
                for ext in ('.jac', '.cl.jac') {
                    path = directory / f"{name}{ext}";
                    if (path.is_file() and (path != src)) {
                        return str(path);
                    }
                }
            }
            break;
        }
    }
    return None;
}

"""Immutable key identifying a cached bytecode entry.

    Attributes:
        source_path: Absolute path to the source .jac file.
        python_version: Python version tuple (major, minor).
    """
@dataclass(frozen=True, slots=True)
obj CacheKey {
    has source_path: str,
        python_version: tuple[(int, int)];

    @classmethod
    def for_source(cls: Any, source_path: str) -> CacheKey;
}

"""Abstract interface for bytecode caching."""
class BytecodeCache {
    """Retrieve cached bytecode if valid."""
    def get(self: BytecodeCache, _key: CacheKey) -> (types.CodeType | None) {
        raise NotImplementedError ;
    }

    """Store bytecode in the cache."""
    def put(self: BytecodeCache, _key: CacheKey, _bytecode: bytes) -> None {
        raise NotImplementedError ;
    }
}

"""Disk-based bytecode cache using a global user cache directory.

    Cache files are stored in a platform-appropriate global location:
    - Linux:   ~/.cache/jac/bytecode/
    - macOS:   ~/Library/Caches/jac/bytecode/
    - Windows: %LOCALAPPDATA%/jac/cache/bytecode/

    Filenames include a path hash and Python version
    to ensure uniqueness across different projects and avoid conflicts.

    Example:
        source:  /project/src/main.jac
        cache:   ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.jbc
                 ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.mtir.pkl
                 ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.llvmir  (native modules)
                 ~/.cache/jac/bytecode/main.a1b2c3d4.cpython-312.interop.pkl  (native interop)
    """
class DiskBytecodeCache(BytecodeCache) {
    with entry {
        EXTENSION: Final[str] = '.jbc';
        MTIR_EXTENSION: Final[str] = '.mtir.pkl';
        LLVMIR_EXTENSION: Final[str] = '.llvmir';
        INTEROP_EXTENSION: Final[str] = '.interop.pkl';
    }

    """Initialize the cache with optional config."""
    def init(self: DiskBytecodeCache, config: (JacConfig | None) = None) -> None {
        self._config = config;
        self._cache_dir: (Path | None) = None;
    }

    """Get the global cache directory."""
    def _get_cache_dir(self: DiskBytecodeCache) -> Path {
        if (self._cache_dir is not None) {
            return self._cache_dir;
        }
        self._cache_dir = get_global_cache_dir();
        return self._cache_dir;
    }

    """Generate the cache file path for a given key.

        Uses a hash of the full source path to ensure uniqueness when
        files with the same name exist in different directories.
        """
    def _get_cache_path(self: DiskBytecodeCache, key: CacheKey) -> Path {
        source = Path(key.source_path).resolve();
        cache_dir = self._get_cache_dir();
        path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
        (major, minor) = key.python_version;
        py_version = f"cpython-{major}{minor}";
        cache_name = f"{source.stem}.{path_hash}.{py_version}{self.EXTENSION}";
        return (cache_dir / cache_name);
    }

    """Check if cached bytecode is still valid.

        The cache is valid if:
        - The cache file exists
        - The cache is newer than the source file
        - The cache is newer than all impl files associated with the source
        """
    def _is_valid(self: DiskBytecodeCache, key: CacheKey, cache_path: Path) -> bool {
        if not cache_path.exists() {
            return False;
        }
        try {
            cache_mtime = os.path.getmtime(cache_path);
            source_mtime = os.path.getmtime(key.source_path);
            if (cache_mtime <= source_mtime) {
                return False;
            }
            for impl_path in discover_annex_files(key.source_path) {
                try {
                    impl_mtime = os.path.getmtime(impl_path);
                    if (cache_mtime <= impl_mtime) {
                        return False;
                    }
                } except OSError {
                    return False;
                }
            }
            return True;
        } except OSError {
            return False;
        }
    }

    """Retrieve cached bytecode if valid."""
    def get(self: DiskBytecodeCache, key: CacheKey) -> (types.CodeType | None) {
        cache_path = self._get_cache_path(key);
        if not self._is_valid(key, cache_path) {
            return None;
        }
        try {
            bytecode = cache_path.read_bytes();
            return marshal.loads(bytecode);
        } except (OSError, ValueError, EOFError) {
            return None;
        }
    }

    """Store bytecode in the cache."""
    def put(self: DiskBytecodeCache, key: CacheKey, bytecode: bytes) -> None {
        cache_path = self._get_cache_path(key);
        try {
            cache_path.parent.mkdir(parents=True, exist_ok=True);
            cache_path.write_bytes(bytecode);
        } except OSError {
            ;
        }
    }

    """Generate the MTIR cache file path for a given key.

        MTIR cache is stored alongside bytecode cache with .mtir.pkl extension.
        """
    def _get_mtir_cache_path(self: DiskBytecodeCache, key: CacheKey) -> Path {
        source = Path(key.source_path).resolve();
        cache_dir = self._get_cache_dir();
        path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
        (major, minor) = key.python_version;
        py_version = f"cpython-{major}{minor}";
        cache_name = f"{source.stem}.{path_hash}.{py_version}{self.MTIR_EXTENSION}";
        return (cache_dir / cache_name);
    }

    """Retrieve cached MTIR map if valid.

        Returns the mtir_map dictionary that maps scope strings to MTIR objects.
        """
    def get_mtir(self: DiskBytecodeCache, key: CacheKey) -> (dict[(str, Any)] | None) {
        mtir_cache_path = self._get_mtir_cache_path(key);
        if not self._is_valid(key, mtir_cache_path) {
            return None;
        }
        try {
            with open(mtir_cache_path, 'rb') as f {
                return pickle.load(f);
            }
        } except (OSError, pickle.PickleError, EOFError) {
            return None;
        }
    }

    """Store MTIR map in the cache.

        Args:
            key: Cache key identifying the source file
            mtir_map: Dictionary mapping scope strings to MTIR objects
        """
    def put_mtir(
        self: DiskBytecodeCache, key: CacheKey, mtir_map: dict[(str, Any)]
    ) -> None {
        mtir_cache_path = self._get_mtir_cache_path(key);
        try {
            mtir_cache_path.parent.mkdir(parents=True, exist_ok=True);
            with open(mtir_cache_path, 'wb') as f {
                pickle.dump(mtir_map, f, protocol=pickle.HIGHEST_PROTOCOL);
            }
        } except (OSError, pickle.PickleError) {
            ;
        }
    }

    """Generate the LLVM IR cache file path for a given key."""
    def _get_llvmir_cache_path(self: DiskBytecodeCache, key: CacheKey) -> Path {
        source = Path(key.source_path).resolve();
        cache_dir = self._get_cache_dir();
        path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
        (major, minor) = key.python_version;
        py_version = f"cpython-{major}{minor}";
        cache_name = f"{source.stem}.{path_hash}.{py_version}{self.LLVMIR_EXTENSION}";
        return (cache_dir / cache_name);
    }

    """Generate the interop manifest cache file path for a given key."""
    def _get_interop_cache_path(self: DiskBytecodeCache, key: CacheKey) -> Path {
        source = Path(key.source_path).resolve();
        cache_dir = self._get_cache_dir();
        path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
        (major, minor) = key.python_version;
        py_version = f"cpython-{major}{minor}";
        cache_name = f"{source.stem}.{path_hash}.{py_version}{self.INTEROP_EXTENSION}";
        return (cache_dir / cache_name);
    }

    """Retrieve cached LLVM IR string if valid.

        Returns:
            The LLVM IR string, or None if not cached/invalid.
        """
    def get_llvmir(self: DiskBytecodeCache, key: CacheKey) -> (str | None) {
        llvmir_cache_path = self._get_llvmir_cache_path(key);
        if not self._is_valid(key, llvmir_cache_path) {
            return None;
        }
        try {
            return llvmir_cache_path.read_text(encoding='utf-8');
        } except OSError {
            return None;
        }
    }

    """Store LLVM IR string in the cache.

        Args:
            key: Cache key identifying the source file
            llvm_ir: The LLVM IR string to cache
        """
    def put_llvmir(self: DiskBytecodeCache, key: CacheKey, llvm_ir: str) -> None {
        llvmir_cache_path = self._get_llvmir_cache_path(key);
        try {
            llvmir_cache_path.parent.mkdir(parents=True, exist_ok=True);
            llvmir_cache_path.write_text(llvm_ir, encoding='utf-8');
        } except OSError {
            ;
        }
    }

    """Retrieve cached interop manifest data if valid.

        Returns:
            Dictionary with interop binding data, or None if not cached/invalid.
        """
    def get_interop(
        self: DiskBytecodeCache, key: CacheKey
    ) -> (dict[(str, Any)] | None) {
        interop_cache_path = self._get_interop_cache_path(key);
        if not self._is_valid(key, interop_cache_path) {
            return None;
        }
        try {
            with open(interop_cache_path, 'rb') as f {
                return pickle.load(f);
            }
        } except (OSError, pickle.PickleError, EOFError) {
            return None;
        }
    }

    """Store interop manifest data in the cache.

        Args:
            key: Cache key identifying the source file
            interop_data: Dictionary with serializable interop binding data
        """
    def put_interop(
        self: DiskBytecodeCache, key: CacheKey, interop_data: dict[(str, Any)]
    ) -> None {
        interop_cache_path = self._get_interop_cache_path(key);
        try {
            interop_cache_path.parent.mkdir(parents=True, exist_ok=True);
            with open(interop_cache_path, 'wb') as f {
                pickle.dump(interop_data, f, protocol=pickle.HIGHEST_PROTOCOL);
            }
        } except (OSError, pickle.PickleError) {
            ;
        }
    }
}

glob _default_cache: (BytecodeCache | None) = None;
"""Get the default bytecode cache instance."""
def get_bytecode_cache -> BytecodeCache {
    global _default_cache;
    if (_default_cache is None) {
        _default_cache = DiskBytecodeCache();
    }
    return _default_cache;
}
