import hashlib;
import os;
import re;
import from pathlib { Path }
import from jaclang.cli.guide_store { nav_pages, parse_guide }

glob BUILD_FORMAT: str = "2";

obj NavEntry {
    has page: str = "",
        title: str = "",
        order: int = 0;
}

obj DocBundle {
    has pages: dict[str, str] = {},
        nav: dict[str, NavEntry] = {},
        jac_version: str = "",
        fingerprint: str = "";
}

def label_of(version: str) -> str;

def bundle_from(ddir: Path, jac_version: str) -> DocBundle;
