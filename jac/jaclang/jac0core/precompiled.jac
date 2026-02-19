"""Precompiled bytecode loader for Jac packages.

This module provides fast loading of precompiled .jbc files shipped
with Jac packages (jaclang, jac-scale, jac-client, etc.). These files
eliminate the cold-start compilation penalty by providing pre-built
Python bytecode for each supported Python version.

Each package can ship a ``_precompiled/`` directory containing:
- ``manifest.json`` with source hashes for validation
- ``cpython-{major}{minor}/`` subdirectories with ``.jbc`` files

The loader is package-agnostic: it walks up from the ``.jac`` file to
find the nearest ``_precompiled/manifest.json``, so any Jac package
can opt in by simply including the directory.
"""
import hashlib;
import json;
import marshal;
import os;
import sys;
import types;
import from pathlib { Path }

# Sentinel string embedded in co_filename at build time.
# Replaced with the actual package root at load time.
glob SENTINEL = "__PKG_ROOT__",
     _package_root_cache: dict[str, str | None] = {},
     _manifest_cache: dict[str, dict | None] = {},
     _MISS: dict = {};

"""Find the package root for a .jac file.

Walks up from the file's directory looking for
_precompiled/manifest.json. Results are cached so repeated
lookups in the same package are O(1).
"""
def _find_package_root(file_path: str) -> str | None {
    d = os.path.dirname(os.path.abspath(file_path));
    visited: list[str] = [];

    while True {
        if d in _package_root_cache {
            result = _package_root_cache[d];
            for v in visited {
                _package_root_cache[v] = result;
            }
            return result;
        }

        visited.append(d);
        manifest = os.path.join(d, "_precompiled", "manifest.json");
        if os.path.isfile(manifest) {
            for v in visited {
                _package_root_cache[v] = d;
            }
            return d;
        }

        parent = os.path.dirname(d);
        if parent == d {
            for v in visited {
                _package_root_cache[v] = None;
            }
            return None;
        }
        d = parent;
    }
}

"""Load and cache the manifest for a package root."""
def _get_manifest(package_root: str) -> dict | None {
    if package_root in _manifest_cache {
        cached = _manifest_cache[package_root];
        return None if cached is _MISS else cached;
    }

    manifest_path = os.path.join(package_root, "_precompiled", "manifest.json");
    try {
        with open(manifest_path, encoding="utf-8") as f {
            data = json.load(f);
        }
        _manifest_cache[package_root] = data;
        return data;
    } except (OSError, json.JSONDecodeError, ValueError) {
        _manifest_cache[package_root] = _MISS;
        return None;
    }
}

"""Check that source + impl files match the hashes in the manifest."""
def _validate_source_hash(manifest: dict, rel_path: str, package_root: str) -> bool {
    entries = manifest.get("entries");
    if not isinstance(entries, dict) {
        return False;
    }

    entry = entries.get(rel_path);
    if not isinstance(entry, dict) {
        return False;
    }

    expected_hash = entry.get("source_hash");
    if not expected_hash {
        return False;
    }

    # Check main source file
    abs_path = os.path.join(package_root, rel_path);
    try {
        with open(abs_path, "rb") as f {
            actual_hash = hashlib.sha256(f.read()).hexdigest();
        }
    } except OSError {
        return False;
    }

    if actual_hash != expected_hash {
        return False;
    }

    # Check impl file hashes
    impl_hashes = entry.get("impl_hashes");
    if isinstance(impl_hashes, dict) {
        for (impl_rel, impl_expected) in impl_hashes.items() {
            impl_abs = os.path.join(package_root, impl_rel);
            try {
                with open(impl_abs, "rb") as f {
                    if hashlib.sha256(f.read()).hexdigest() != impl_expected {
                        return False;
                    }
                }
            } except OSError {
                return False;
            }
        }
    }

    return True;
}

"""Recursively replace sentinel with real_root in co_filename.

Python code objects embed absolute paths in co_filename for
tracebacks. At build time we compile with a sentinel path; at load
time we swap it for the actual install location.

code.replace() (available since Python 3.8) creates a shallow
copy with the specified fields changed.
"""
def _patch_code_filenames(
    code: types.CodeType, sentinel: str, real_root: str
) -> types.CodeType {
    new_filename = code.co_filename.replace(sentinel, real_root);

    new_consts = tuple(
        _patch_code_filenames(c, sentinel, real_root)
        if isinstance(c, types.CodeType)
        else c for c in code.co_consts
    );

    return code.replace(co_filename=new_filename, co_consts=new_consts);
}

"""Load precompiled bytecode for a .jac file, if available.

Returns None when precompiled bytecode is not available or
invalid — the caller should fall through to full compilation.

Works for any Jac package (jaclang, jac-scale, jac-client, etc.)
as long as the package ships a _precompiled/ directory.
"""
def get_precompiled_bytecode(file_path: str) -> types.CodeType | None {
    package_root = _find_package_root(file_path);
    if package_root is None {
        return None;
    }

    manifest = _get_manifest(package_root);
    if manifest is None {
        return None;
    }

    # Compute the relative path of the source within the package
    norm_file = os.path.normpath(os.path.abspath(file_path));
    norm_root = os.path.normpath(package_root);
    if not norm_file.startswith(norm_root + os.sep) {
        return None;
    }
    rel_path = norm_file[len(norm_root) + 1:];
    # Normalise to forward slashes for manifest lookup
    rel_path_key = rel_path.replace(os.sep, "/");

    # Validate that sources haven't changed (important for editable installs)
    if not _validate_source_hash(manifest, rel_path_key, package_root) {
        return None;
    }

    # Build path to the .jbc file for the current Python version
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    jbc_rel = os.path.splitext(rel_path)[0] + ".jbc";
    jbc_path = os.path.join(package_root, "_precompiled", pyver, jbc_rel);

    try {
        with open(jbc_path, "rb") as f {
            code = marshal.loads(f.read());
        }
    } except (OSError, ValueError, EOFError) {
        return None;
    }

    # Patch co_filename from build-time sentinel to actual install path
    sentinel = manifest.get("filename_sentinel", SENTINEL);
    return _patch_code_filenames(code, sentinel, package_root);
}
