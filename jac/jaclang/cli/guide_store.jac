import from pathlib { Path }

obj Guide {
    has name: str,
        description: str,
        body: str,
        path: str;
}

obj GuideSection {
    has title: str,
        slug: str,
        level: int,
        line_no: int,
        body: str;
}

def guide_sections(g: Guide) -> list[GuideSection];

obj GrepHit {
    has guide: str,
        line_no: int,
        text: str;
}

obj NavPage {
    has page: str,
        title: str,
        order: int,
        section: list[str];
}

def guides_dir -> Path;

def docs_dir -> Path;

def parse_guide(path: Path) -> Guide | None;

def list_guides -> list[Guide];

def list_docs -> list[Guide];

def doc_corpora -> list[tuple[str, list[Guide]]];

def corpus_blurb(ns: str) -> str;

def nav_manifest -> dict;

def nav_pages -> list[NavPage];

def get_guide(name: str) -> Guide | None;

def grep_guides(
    query: str, max_per_guide: int = 8, max_total: int = 200
) -> list[GrepHit];

def guide_group(name: str) -> str;

def grouped_guides -> list[tuple[str, list[Guide]]];

def search_guides(query: str) -> list[Guide];

def guide_for_diagnostic(code: str, category: str = "") -> str | None;
