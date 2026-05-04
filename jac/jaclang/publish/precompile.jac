"""Importable .jac → .jir precompiler used during jac publish."""

import from pathlib { Path }

# Sentinel embedded in co_filename so installed wheels are path-portable.
# NOTE: scripts/precompile_bytecode.jac duplicates SENTINEL and the excluded-directory
# list — scripts/ is not an installed package so importing from here fails at runtime.
# If you change either constant, update that script too.
glob SENTINEL: str = "__PKG_ROOT__",
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
