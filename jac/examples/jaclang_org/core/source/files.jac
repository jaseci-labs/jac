glob EXCLUDE_DIRS: set = {".git", ".jac", "node_modules", "__pycache__", "assets"},
     ALLOW_EXT: set = {".jac", ".toml", ".css", ".md"},
     EXAMPLES_DIR: str = "core/site/examples";

obj SourceFile {
    has path: str,
        dir: str,
        name: str,
        language: str,
        lines: int;
}

obj SourceView {
    has path: str,
        language: str,
        size_bytes: int,
        lines: int,
        raw_lines: list[str];
}

obj SourceSpan {
    has path: str,
        language: str,
        total_lines: int,
        start: int,
        hl_from: int,
        hl_to: int,
        found: bool,
        raw_lines: list[str];
}

def _project_root -> str;

def _language_of(name: str) -> str;

def _tree_order(f: SourceFile) -> tuple;

def _walk_sources -> list[SourceFile];

def:pub source_tree -> list[SourceFile];

def:pub source_file(path: str) -> SourceView | None;

def:pub source_span(
    path: str, needle: str, hl_lines: int = 1, before: int = 3, after: int = 12
) -> SourceSpan | None;

def:pub example_sources -> list[SourceView];
