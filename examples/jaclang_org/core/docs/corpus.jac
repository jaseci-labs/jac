"""A docs tree read whole: each page as the reader shows it, and what nav.json
says of each page: its title, its place in the order and its sections."""

import hashlib;
import os;
import re;
import from pathlib { Path }

glob BUILD_FORMAT: str = "4";

obj NavEntry {
    has page: str = "",
        title: str = "",
        order: int = 0,
        section: list[str] = [];
}

obj DocBundle {
    has pages: dict[str, str] = {},
        descriptions: dict[str, str] = {},
        nav: dict[str, NavEntry] = {},
        version: str = "",
        fingerprint: str = "";
}

def label_of(version: str) -> str;

"""A page's Markdown without the lines of its HTML comments, which are notes to
the docs' own checks (`<!-- example: not checked: ... -->`), not to a reader. A
comment inside a code fence is the code's, and stays."""
def reader_text(body: str) -> str;

"""The tree at `ddir`, labelled with the version of jac it documents."""
def bundle_from(ddir: Path) -> DocBundle;
