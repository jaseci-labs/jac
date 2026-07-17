"""Enforce that the committed command manifest is in sync with the registry.

The manifest (jac/jaclang/cli/_manifest_data.json) is generated from the live
command registry by scripts/generate_command_manifest.py. Several fast CLI
paths (help, MCP discovery, lazy dispatch) read it instead of importing every
command, so it must not silently drift from the decorator registrations.

This test regenerates the manifest in-process and fails on any byte-level diff
against the committed artifact. It is the CI guard for the generator --check
mode: change a command decorator -> re-run the generator -> commit the JSON,
or this test (and therefore the CI test jobs) will fail.
"""

from __future__ import annotations

import runpy
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GEN = REPO / "scripts" / "generate_command_manifest.py"
OUT = REPO / "jac" / "jaclang" / "cli" / "_manifest_data.json"


def test_committed_manifest_matches_generator() -> None:
    ns = runpy.run_path(str(GEN), run_name="__not_main__")
    regenerated = ns["_serialize"](ns["_collect"]())
    committed = OUT.read_text(encoding="utf-8")
    assert regenerated == committed, (
        f"{OUT.name} is out of date with the live command registry.\n"
        "Run `python scripts/generate_command_manifest.py` and commit the result."
    )
