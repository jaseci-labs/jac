#!/usr/bin/env python3
"""Merge per-target manifest fragments into a single registry index.json (M5.4).

Each runner in the artifact matrix emits manifest-<triple>.json — a flat list of
{crate, version, triple, filename, sha256, relpath} records. This folds every
fragment found under the input dir(s) into the nested schema the resolver reads:

  {
    "schema": 1,
    "crates": {
      "<crate>": {
        "<version>": {
          "<triple>": {"url": "<relpath>", "sha256": "<hex>"}
        }
      }
    }
  }

The `url` is left relative to the index location, so the whole tree (index.json +
the crate/version/triple/*.so layout) can be served from any static host and the
resolver's urljoin resolves each artifact against wherever it fetched the index.

Usage:
  merge_registry_index.py --out index.json <dir-with-manifests> [<more-dirs>...]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCHEMA = 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("inputs", nargs="+", type=Path, help="dirs holding manifest-*.json")
    args = ap.parse_args()

    fragments = []
    for root in args.inputs:
        if root.is_file():
            fragments.append(root)
        else:
            fragments.extend(sorted(root.rglob("manifest-*.json")))
    if not fragments:
        print("error: no manifest-*.json fragments found", file=sys.stderr)
        return 2

    crates: dict = {}
    total = 0
    for frag in fragments:
        for rec in json.loads(frag.read_text(encoding="utf-8")):
            crate = crates.setdefault(rec["crate"], {})
            version = crate.setdefault(rec["version"], {})
            triple = rec["triple"]
            entry = {"url": rec["relpath"], "sha256": rec["sha256"]}
            if triple in version and version[triple] != entry:
                print(
                    f"warning: conflicting artifact for {rec['crate']} "
                    f"{rec['version']} {triple}; keeping first",
                    file=sys.stderr,
                )
                continue
            version[triple] = entry
            total += 1

    index = {"schema": SCHEMA, "crates": crates}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(index, indent=2, sort_keys=True), encoding="utf-8")
    print(f"merged {total} artifact(s) from {len(fragments)} fragment(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
