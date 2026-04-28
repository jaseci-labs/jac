"""Importable .jac → .jir precompiler; mirrors scripts/precompile_bytecode.jac without subprocess round-trips."""

import from pathlib { Path }

# Sentinel embedded in co_filename so installed wheels are path-portable.
glob SENTINEL: str = "__PKG_ROOT__",
     # Directory names to exclude when walking a package — mirrors the
     # `excluded` list in scripts/precompile_bytecode.jac:find_package_dir.
     SKIP_FRAGMENTS: list[str] = [
         "tests",
         "test",
         "scripts",
         "docs",
         ".git",
         ".github",
         "node_modules",

     ];

"""Compile all head .jac files in pkg_dir to .jir, write manifest.json, return compiled count."""
def precompile_package(pkg_dir: Path) -> int;
