"""Client-module collector for `jac bundle --target npm`.

Walks the project's [project.include] package directories for client-context Jac
modules (`.cl.jac` and plain `.jac`), compiles each to JavaScript, injects JSDoc,
and records the npm-relative `.js` path. Modules that cross a server (`sv`)
boundary are not standalone-publishable and raise NpmBoundaryError.
"""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

# Source suffixes that are NOT client modules and must be skipped.
glob NON_CLIENT_SUFFIXES: list[str] = [".sv.jac", ".na.jac"];

"""Raised when a module destined for an npm package crosses a server boundary."""
class NpmBoundaryError(RuntimeError) {}

"""A compiled client module bound for the npm tarball.

   `external_imports` lists the npm packages this module pulls in (the Jac client
   runtime package and/or react/react-dom), aggregated by the builder into the
   package.json dependencies and peerDependencies."""
obj NpmSourceFile {
    has npm_path: str = "",
        source_path: Path | None = None,
        js: str = "",
        dts: str = "",
        external_imports: list[str] = [];
}

"""Map a source path (relative, forward-slashed) to its npm `.js` output path."""
def npm_js_path(rel_path: str) -> str;

"""The runtime npm package name: the [npm] `runtime` override or @jaseci/runtime."""
def runtime_pkg_name(config: JacConfig) -> str;

"""Compile and collect every client module under the project's packages.

   Raises NpmBoundaryError if any module crosses a server boundary, and
   ValueError when project_root or the project name is missing."""
def collect_npm_sources(
    config: JacConfig, project_root: Path | None = None,
) -> list[NpmSourceFile];

"""Pick the entry `.js` path for `main`/`exports` from collected files:
   the [npm] `entry` override, else a top-level `index.js`, else the sole file."""
def resolve_npm_entry(config: JacConfig, files: list[NpmSourceFile],) -> str | None;
