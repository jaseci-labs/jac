import from pathlib { Path }

obj Guide {
    has name: str,
        description: str,
        body: str,
        path: str;
}

def guides_dir -> Path;

def parse_guide(path: Path) -> Guide | None;

def list_guides -> list[Guide];

def get_guide(name: str) -> Guide | None;

def guide_group(name: str) -> str;

def grouped_guides -> list[tuple[str, list[Guide]]];

def search_guides(query: str) -> list[Guide];

def guide_for_diagnostic(code: str, category: str = "") -> str | None;
