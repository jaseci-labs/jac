import hashlib;
import logging;
import os;
import re;
import from pathlib { Path }
import from jaclang.cli.guide_store { NavPage, docs_dir, nav_pages, parse_guide }
import from jaclang.cli.manifest_route { resolve_cli_version }
import from core.timefmt { now_iso }
import from .graph {
    DocsHub,
    DocVersion,
    HasHub,
    HasVersion,
    NextPage,
    _pretty,
    _sweep_stale,
    _version,
    place_page,
    rewrite_href,
    toc_of
}

obj DocBundle {
    has pages: dict[str, str] = {},
        nav: dict[str, NavPage] = {},
        jac_version: str = "",
        fingerprint: str = "";
}

glob SYNC_TICK_S: float = 30.0,
     SYNC_STATE: dict[str, bool] = {},
     log: logging.Logger = logging.getLogger("docs.sync");

def label_of(version: str) -> str;

def corpus_bundle -> DocBundle;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def build_version(bundle: DocBundle) -> DocVersion;

def corpus_stale(bundle: DocBundle) -> bool;

def ingest(bundle: DocBundle);

@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_TICK_S)
def docs_sync_tick;
