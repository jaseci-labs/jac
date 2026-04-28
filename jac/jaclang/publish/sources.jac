"""Source file collector for jac publish — walks [package.include] dirs and gathers wheel bundle files."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

# Default glob patterns for Jac packages when [package.include.data] is absent.
# Using '**/' prefix so pathlib.glob() recurses into every subdirectory.
glob DEFAULT_INCLUDE_PATTERNS: list[str] = [
         "**/*.jac",  # all Jac source files (recursive)
         "**/*.py",  # Python shims (__init__.py, etc.)
         "**/*.pyi",  # type stubs
         "**/*.lark",  # Lark grammar files (some are vendored inside packages)
         "**/py.typed",  # PEP 561 type marker
         "**/*.jir",  # pre-compiled JIR bytecode from _precompiled/
         "_precompiled/manifest.json",  # JIR manifest

     ],
     # Directories whose contents must never appear in a published wheel,
     # matched as path *components* (any segment in the path).
     # Mirrors which directories pip skips when discovering packages:
     # pip only ships Python packages (dirs with __init__.py); dev-only
     # directories like examples/, tests/, docs/ are not packages and
     # are not shipped.
     EXCLUDED_DIRS: list[str] = [
         # Jac / Python build artefacts
         ".jac",
         "__pycache__",
         "dist",
         "build",
         # Virtual environments (may appear inside example projects)
         "venv",
         ".venv",
         "env",
         # SCM and tooling
         ".git",
         ".hg",
         "node_modules",

     ],
     # File suffixes that must never appear in a published wheel.
     EXCLUDED_SUFFIXES: list[str] = [".pyc", ".egg-info", ];

"""A single file to be included in the wheel archive (wheel-relative path, disk path, and content bytes)."""
obj SourceFile {
    has wheel_path: str = "",
        source_path: Path | None = None,
        content: bytes = b"";
}

"""Return bytes for a SourceFile, reading from source_path if content is not yet loaded."""
def read_source_file(sf: SourceFile) -> bytes;

"""Collect all source files for a package from disk based on [package.include] config; raises ValueError when config.package is None."""
def collect_source_files(
    config: JacConfig, project_root: Path | None = None,
) -> list[SourceFile];
