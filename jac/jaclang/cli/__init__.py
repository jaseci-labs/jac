"""CLI for jaclang."""

# Import the cli module (which is a .jac file) to expose it via the package.
# The meta_importer handles compiling .jac files when they're imported.
from jaclang.cli import cli  # type: ignore[attr-defined]  # noqa: F401
