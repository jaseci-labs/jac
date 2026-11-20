"""The docs the site serves: jac's documentation tree, the Markdown under the
repository's docs/, with `nav.json` saying their order and their sections."""

import json;
import os;
import tomllib;
import from pathlib { Path }

glob DOCS_ENV: str = "JAC_WEB_DOCS";

obj Guide {
    has name: str,
        description: str,
        body: str,
        path: str;
}

"""A page nav.json names: its title, its place in nav.json's order of pages,
and the titles of the sections it is in, outermost first."""
obj NavPage {
    has page: str,
        title: str,
        order: int,
        section: list[str];
}

"""The docs tree: the directory `JAC_WEB_DOCS` names when it is set, else the
repository's docs/ in the checkout this file is in."""
def docs_dir -> Path;

"""The version of jac a docs tree documents. A release's docs/ has the
release's VERSION file beside it, whose first line is the version; a
checkout's has its `jac.toml`, whose `[project] version` it is. "" when the
tree has neither."""
def docs_version(docs_root: Path | None = None) -> str;

def parse_guide(path: Path) -> Guide | None;

def nav_manifest(docs_root: Path | None = None) -> dict[str, any];

def nav_pages(docs_root: Path | None = None) -> list[NavPage];

def _nav_walk(items: list[any], trail: list[str], pages: list[NavPage]);
