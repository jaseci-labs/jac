"""Source file collector for jac bundle — walks [package.include] dirs and gathers wheel bundle files."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

# Default glob patterns when [package.include.data] is absent.
glob DEFAULT_INCLUDE_PATTERNS: list[str] = [
         "**/*.jac",
         "**/*.py",
         "**/*.pyi",  # type stubs
         "**/*.lark",  # Lark grammar files, may be vendored
         "**/py.typed",  # PEP 561 type marker
         "**/*.jir",  # pre-compiled JIR bytecode
         "_precompiled/manifest.json",  # JIR manifest

     ],
     # Directories excluded from the wheel — matched against any path component.
     EXCLUDED_DIRS: list[str] = [
         # build artefacts
         ".jac",
         "__pycache__",
         "dist",
         "build",
         # virtual environments
         "venv",
         ".venv",
         "env",
         # SCM and tooling
         ".git",
         ".hg",
         "node_modules",

     ],
     # File suffixes excluded from the wheel.
     EXCLUDED_SUFFIXES: list[str] = [".pyc"];

"""A file entry for the wheel archive."""
obj SourceFile {
    has wheel_path: str = "",
        source_path: Path | None = None,
        content: bytes | None = None;
}

"""Return bytes for a SourceFile, loading from disk on first access."""
def read_source_file(sf: SourceFile) -> bytes;

"""Collect source files for a package based on [package.include] config."""
def collect_source_files(
    config: JacConfig, project_root: Path | None = None,
) -> list[SourceFile];
