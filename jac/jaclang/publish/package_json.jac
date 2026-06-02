"""package.json generator for `jac bundle --target npm` — in-memory, nothing written to disk."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

"""Read the optional [npm] table from a JacConfig's raw TOML data."""
def npm_settings(config: JacConfig) -> dict[str, any];

"""The npm package name: the [npm] name override (may be scoped, e.g. @scope/pkg)
   or the PEP 503-normalized [project] name. Raises ValueError when no name exists."""
def npm_package_name(config: JacConfig) -> str;

"""The npm `.tgz` filename, flattening any scope exactly like `npm pack`
   (e.g. @jaseci/mylib@2.1.0 -> jaseci-mylib-2.1.0.tgz)."""
def npm_tarball_filename(config: JacConfig) -> str;

"""Collect npm runtime dependencies from [dependencies.npm] (excluding the
   nested `dev` table) merged with any [npm] dependencies override."""
def npm_dependencies(config: JacConfig) -> dict[str, str];

"""Collect peerDependencies from the [npm] peer-dependencies override."""
def npm_peer_dependencies(config: JacConfig) -> dict[str, str];

"""Generate the package.json string from a JacConfig.

   `main` is the entry module's compiled `.js` path (relative to the package
   root); when provided it drives the `main`, `module`, and `exports` fields.
   `types` is the entry `.d.ts` path (Phase 3); when provided it drives the
   `types` field and the `exports` `types` condition.
   `extra_dependencies`/`extra_peer_dependencies` are auto-detected entries
   (e.g. the Jac runtime package, react) merged under the explicit jac.toml
   declarations, which always win on a name collision.
   Raises ValueError when the project name is missing."""
def generate_package_json(
    config: JacConfig,
    project_root: Path | None = None,
    main: str | None = None,
    types: str | None = None,
    extra_dependencies: dict[str, str] | None = None,
    extra_peer_dependencies: dict[str, str] | None = None,
) -> str;
