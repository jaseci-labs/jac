"""Builds the Jac client runtime as a publishable npm package (@jaseci/runtime).

A standalone npm package compiled from `.cl.jac` references runtime globals such
as `__jacJsx`; those resolve to this package, which compiles the bare-serve Jac
client runtime (`runtimelib/client_runtime.cl.jac`) to a single ESM module and
re-exports its public API. It is React-independent.
"""

import from pathlib { Path }

glob RUNTIME_PKG_NAME: str = "@jaseci/runtime";

"""The runtime's public API symbol names (its top-level def/glob surface).

   This same set drives runtime-import detection in npm_sources, so a module that
   uses any of these names gets an import wired to the runtime package."""
def runtime_api_names -> set[str];

"""Compile the Jac client runtime to a single ESM JavaScript string (cached)."""
def compile_runtime_js -> str;

"""Public API names actually declared at top level in `js`, sorted — the symbols
   appended to the runtime module's `export {...}` clause."""
def runtime_export_names(js: str) -> list[str];

"""Build the runtime npm tarball bytes for `version` (e.g. the jaclang version)."""
def build_runtime_tarball(version: str, pkg_name: str = RUNTIME_PKG_NAME) -> bytes;

"""Build the runtime tarball and write it to output_dir; returns the Path."""
def build_runtime_to(
    output_dir: Path, version: str, pkg_name: str = RUNTIME_PKG_NAME
) -> Path;
