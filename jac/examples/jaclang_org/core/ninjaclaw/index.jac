import math;
import os;
import re;
import from pathlib { Path }

obj IndexDoc {
    has kind: str = "docs",
        key: str = "",
        title: str = "",
        href: str = "",
        text: str = "",
        terms: dict[str, int] = {},
        length: int = 0;
}

obj IndexHit {
    has doc: IndexDoc,
        score: float = 0.0;
}

glob STOP_WORDS: set[str] = {
         "a",
         "an",
         "and",
         "are",
         "as",
         "at",
         "be",
         "by",
         "can",
         "do",
         "does",
         "for",
         "from",
         "how",
         "i",
         "if",
         "in",
         "into",
         "is",
         "it",
         "its",
         "me",
         "my",
         "of",
         "on",
         "or",
         "so",
         "that",
         "the",
         "this",
         "to",
         "use",
         "using",
         "what",
         "when",
         "where",
         "which",
         "why",
         "with",
         "you",
         "your",
         "jac",
         "ninjaclaw"
     },
     TITLE_WEIGHT: int = 4,
     BM25_K1: float = 1.4,
     BM25_B: float = 0.75;

def tokens_of(text: str) -> list[str];

def index_doc(kind: str, key: str, title: str, href: str, text: str) -> IndexDoc;

def docs_route(rel: str) -> str;

def heading_anchor(heading: str) -> tuple[str, str];

def page_sections(text: str) -> list[tuple[str, str, str]];

def docs_from_tree(ddir: Path) -> list[IndexDoc];

def search(docs: list[IndexDoc], query: str, limit: int = 8) -> list[IndexHit];

def excerpt(doc: IndexDoc, query: str, size: int = 700) -> str;
