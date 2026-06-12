"""NpmBuilder — packs compiled client modules into an npm `.tgz` tarball."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }


"""Builds an npm-publishable `.tgz` from a JacConfig and the project's client modules.

The tarball mirrors `npm pack` output: a gzipped tar whose every entry is prefixed
with `package/`, containing the generated `package.json`, the compiled `.js`
modules (with JSDoc), and the README when present."""
obj NpmBuilder {
    has config: JacConfig,
        project_root: Path | None = None;

    def postinit -> None;
    """Build the tarball in memory and return its raw bytes; raises ValueError when
       the project name is missing and NpmBoundaryError on a server-boundary crossing."""
    def build -> bytes;

    """Build the tarball and write it to output_dir/<name>-<version>.tgz; returns the Path."""
    def build_to(output_dir: Path) -> Path;
}
