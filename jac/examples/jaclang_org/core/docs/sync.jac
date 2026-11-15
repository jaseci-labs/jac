import logging;
import os;
import re;
import time;
import from jaclang.cli.guide_store { docs_dir }
import from jaclang.cli.manifest_route { resolve_cli_version }
import from jaclang.server.bridge { BridgeError }

glob SYNC_TICK_S: float = 30.0,
     RECHECK_S: float = 600.0,
     SYNC_STATE: dict[str, float] = {},
     log: logging.Logger = logging.getLogger("docs.sync");

def corpus_bundle -> DocBundle;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def build_version(bundle: DocBundle) -> DocVersion;

def corpus_stale(bundle: DocBundle) -> bool;

def ingest(bundle: DocBundle);

def retire_versions(keep: list[str]);

async def sync_release_lines(serving_label: str) -> bool;

@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_TICK_S)
async def:protect docs_sync_tick;
