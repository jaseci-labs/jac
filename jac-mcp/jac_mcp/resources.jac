"""Resource providers for jac-mcp.

This module provides read-only reference material that AI models can load
for context: grammar specs, documentation, examples, and curated guides.
"""

import from typing { Any }

"""Find the repo root by walking up from jaclang package location."""
def find_repo_root -> str | None;

"""Resource provider that indexes and serves Jac reference content."""
obj ResourceProvider {
    has _resources: dict = {},
        _repo_root: str | None = None,
        _package_dir: str = "";

    """Scan paths and build URI to filepath mapping."""
    def index_resources -> None;

    """Index bundled content (pitfalls, patterns)."""
    def _index_bundled -> None;

    """Index bundled docs copied at release time."""
    def _index_bundled_docs -> None;

    """Return list of available resources."""
    def list_resources -> list[dict[str, str]];

    """Read resource content by URI."""
    def read_resource(uri: str) -> str;
}
