"""Importable .jac → .jir precompiler used during jac publish."""

import from pathlib { Path }

# Sentinel embedded in co_filename so installed wheels are path-portable.
# NOTE: scripts/precompile_bytecode.jac defines its own copy of SENTINEL and
# the excluded-directory list. If you change either constant here, update that
# script too to prevent the two implementations from drifting.
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
