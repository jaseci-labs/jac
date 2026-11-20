glob EXCLUDE_DIRS: set[str] = {".git", ".jac", "node_modules", "__pycache__", "assets"},
     ALLOW_EXT: set[str] = {".jac", ".toml", ".css", ".md"};

def _project_root -> str;

def _language_of(name: str) -> str;

def _tree_order(f: SourceFile) -> tuple[int, str, int, str];

def _walk_sources -> list[SourceFile];

def:pub source_tree -> list[SourceFile];

def:pub source_file(path: str) -> SourceView | None;

def:pub source_span(
    path: str, needle: str, hl_lines: int = 1, before: int = 3, after: int = 12
) -> SourceSpan | None;
