import from stdjac.server { schedule }
import logging;
import os;
import re;
import time;

comptime SYNC_TICK_S: float = 30.0;

glob RECHECK_S: float = 600.0,
     SYNC_STATE: dict[str, float] = {},
     # The section of the pages nav.json does not name, last in the tree.
     UNNAMED_SECTION: str = "Other pages",
     log: logging.Logger = logging.getLogger("docs.sync");

"""jac's docs tree, read whole."""
def corpus_bundle -> DocBundle;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def build_version(bundle: DocBundle) -> DocVersion;

def corpus_stale(bundle: DocBundle) -> bool;

def ingest(bundle: DocBundle);

"""Tear down every version but those labelled in `keep`: the graph holds the
versions its source offers, and no other."""
def retire_versions(keep: list[str]);

@schedule(interval=SYNC_TICK_S)
def:protect docs_sync_tick;
