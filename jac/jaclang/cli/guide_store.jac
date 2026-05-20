"""Shared guide store -- the single source of truth for Jac reference guides.

A "guide" is a curated reference document (Markdown body + YAML frontmatter)
for writing correct, idiomatic Jac. The guides are hand-edited and live in
`jaclang/cli/skills/<name>.md`, so they ship inside the jaclang wheel and need
no build step.

Every consumer reads guides through this module -- the `jac guide` CLI command
(including `jac guide --export`, which writes them out as Claude Code Agent
Skills), the compiler's diagnostic hints, and the jac-mcp server -- so there is
exactly one copy of the content and one frontmatter parser.
"""

import from pathlib { Path }

"""A single reference guide: parsed frontmatter plus its markdown body."""
obj Guide {
    has name: str,  # Stable identifier, e.g. "jac-types"
        description: str,  # One-line summary from frontmatter
        body: str,  # Markdown body with frontmatter stripped
        path: str;  # Absolute path to the backing .md file
}

"""Absolute path to the bundled guides directory inside the jaclang package."""
def guides_dir -> Path;

"""Parse a guide markdown file (frontmatter + body) into a Guide.

Returns None when the file is missing or unreadable.
"""
def parse_guide(path: Path) -> Guide | None;

"""Return every bundled guide, ordered by name. Empty when none are bundled."""
def list_guides -> list[Guide];

"""Return a single guide by name, or None when it is not bundled."""
def get_guide(name: str) -> Guide | None;

"""Return guides whose name, description, or body contains `query` (case-insensitive)."""
def search_guides(query: str) -> list[Guide];

"""Map a compiler diagnostic to the guide that explains how to fix it.

`code` is a diagnostic code like "W0064"; `category` is the lowercase
diagnostic Category value (e.g. "type"). Returns a guide name only when that
guide is actually bundled, so callers never emit a dangling hint.
"""
def guide_for_diagnostic(code: str, category: str = "") -> str | None;
