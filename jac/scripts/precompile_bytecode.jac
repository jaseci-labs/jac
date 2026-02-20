"""Precompile bytecode for a Jac package.

Generates _precompiled/ directory with .jbc files for the current
Python version.  Run once per Python version during CI/release.

Usage:
    jac run scripts/precompile_bytecode.jac<package-source-dir>

Examples:
    jac run scripts/precompile_bytecode.jac./jac
    jac run scripts/precompile_bytecode.jac./jac-scale
    jac run scripts/precompile_bytecode.jac./jac-client
    jac run scripts/precompile_bytecode.jac./jac-byllm
    jac run scripts/precompile_bytecode.jac./jac-super
"""

import hashlib;
import json;
import marshal;
import os;
import sys;
import types;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.precompiled { SENTINEL, _patch_code_filenames }

"""Discover the Python package directory inside a source tree.

Looks for directories containing __init__.py or __init__.jac
at the top level of the given source directory.
"""
def find_package_dir(source_dir: str) -> str | None {
    src = Path(source_dir).resolve();
    if not src.is_dir() {
        console.error(f"Error: {source_dir} is not a directory");
        return None;
    }
    excluded: list = [
        "tests",
        "test",
        "scripts",
        "docs",
        ".git",
        ".github",
        "node_modules"
    ];
    # First pass: look for directories with __init__.py or __init__.jac
    for child in sorted(src.iterdir()) {
        if child.is_dir() and child.name not in excluded {
            init_py = child / "__init__.py";
            init_jac = child / "__init__.jac";
            if init_py.is_file() or init_jac.is_file() {
                return str(child);
            }
        }
    }
    # Second pass: namespace packages — directory with .jac files in subdirs
    # Use the source dir name convention: jac-client -> jac_client
    expected_name = src.name.replace("-", "_");
    candidate = src / expected_name;
    if candidate.is_dir() and any(candidate.rglob("*.jac")) {
        return str(candidate);
    }
    # Last resort: any child dir containing .jac files
    for child in sorted(src.iterdir()) {
        if child.is_dir()
        and child.name not in excluded
        and not child.name.startswith(".") {
            if any(child.rglob("*.jac")) {
                return str(child);
            }
        }
    }
    return None;
}

"""Discover all .jac files in a package directory (excluding tests)."""
def find_jac_files(package_dir: str) -> list[str] {
    result: list[str] = [];
    pkg = Path(package_dir);
    for jac_file in sorted(pkg.rglob("*.jac")) {
        rel = str(jac_file.relative_to(pkg));
        # Skip test files, impl files, and hidden files
        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or rel.startswith(".")
            or ".impl." in jac_file.name
        ) {
            continue;
        }
        result.append(str(jac_file));
    }
    return result;
}

"""Compute SHA-256 hash of a file's contents."""
def file_hash(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        h.update(f.read());
    }
    return h.hexdigest();
}

"""Build the manifest entries for all .jac files in a package."""
def build_manifest(package_dir: str, jac_files: list[str]) -> dict {
    entries: dict[str, dict] = {};
    pkg = Path(package_dir);

    for jac_path in jac_files {
        rel = str(Path(jac_path).relative_to(pkg));
        rel_key = rel.replace(os.sep, "/");

        entry: dict[str, object] = {"source_hash": file_hash(jac_path)};

        # Discover and hash impl files
        impl_files = discover_annex_files(jac_path);
        if impl_files {
            impl_hashes: dict[str, str] = {};
            for impl_path in impl_files {
                impl_rel = str(Path(impl_path).relative_to(pkg));
                impl_rel_key = impl_rel.replace(os.sep, "/");
                impl_hashes[impl_rel_key] = file_hash(impl_path);
            }
            entry["impl_hashes"] = impl_hashes;
        }

        entries[rel_key] = entry;
    }

    return {"version": 1, "filename_sentinel": SENTINEL, "entries": entries};
}

"""Compile a single .jac file and extract its bytecode.

Triggers the full Jac compilation pipeline (or uses cached bytecode).
Returns the marshal'd bytecode bytes, or None on failure.
"""
def compile_and_extract(jac_path: str) -> bytes | None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    compiler = Jac.get_compiler();
    program = Jac.get_program();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    if code is None {
        return None;
    }
    return marshal.dumps(code);
}

"""Patch bytecode filenames: replace actual package root with sentinel."""
def patch_to_sentinel(bytecode: bytes, package_root: str) -> bytes {
    code = marshal.loads(bytecode);
    patched = _patch_code_filenames(code, package_root, SENTINEL);
    return marshal.dumps(patched);
}

"""Run the precompilation pipeline."""
def main {
    args = sys.argv[1:];
    if not args {
        console.print(
            "Usage: jac run scripts/precompile_bytecode.jac<package-source-dir>"
        );
        console.print("\nExamples:");
        console.print("  jac run scripts/precompile_bytecode.jac./jac");
        console.print("  jac run scripts/precompile_bytecode.jac./jac-scale");
        sys.exit(1);
    }

    source_dir = args[0];
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.exit(1);
    }

    pkg_name = Path(package_dir).name;
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");

    # Discover .jac files
    jac_files = find_jac_files(package_dir);
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files {
        console.print("  No .jac files to precompile.");
        sys.exit(0);
    }

    # Set up output directory
    precompiled_dir = Path(package_dir) / "_precompiled";
    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);

    # Compile each file and store bytecode
    compiled = 0;
    failed = 0;
    pkg_path = Path(package_dir);

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jbc_rel = rel.with_suffix(".jbc");
        jbc_path = out_dir / jbc_rel;

        try {
            bytecode = compile_and_extract(jac_path);
            if bytecode is None {
                console.print(f"  SKIP (no bytecode): {rel}");
                failed += 1;
                continue;
            }

            # Patch filenames to use sentinel
            patched = patch_to_sentinel(bytecode, package_dir);

            # Write .jbc file
            jbc_path.parent.mkdir(parents=True, exist_ok=True);
            jbc_path.write_bytes(patched);
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            failed += 1;
        }
    }

    # Generate manifest
    manifest = build_manifest(package_dir, jac_files);
    manifest_path = precompiled_dir / "manifest.json";
    with open(manifest_path, "w", encoding="utf-8") as f {
        json.dump(manifest, f, indent=2, sort_keys=True);
    }

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules ({failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Manifest: {manifest_path}");
    console.print(f"  Python version: {pyver}");
}

with entry {
    main();
}
