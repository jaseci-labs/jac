#!/usr/bin/env python3
"""Generate jac/jaclang/cli/_manifest_data.json from the live command registry.

Run from the jac source tree after registry changes to refresh the canonical
manifest. Requires a working jaclang import (dev or release).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "jac"
OUT = ROOT / "jaclang" / "cli" / "_manifest_data.json"
LEGACY_OUT = ROOT / "jaclang" / "cli" / "_manifest_data.py"


def _kind_name(kind: object) -> str:
    if hasattr(kind, "name"):
        return kind.name
    text = str(kind)
    if text.startswith("ArgKind."):
        return text.split(".", 1)[1]
    return text


def _collect() -> list[dict]:
    sys.path.insert(0, str(ROOT))
    from jaclang.cli.registry import (
        get_registry,
        register_core_commands,
        register_feature_commands,
    )

    # Build-time full registration: import every core command module from the
    # authoritative _CORE_REGISTRATION_MODULES list, then the optional feature
    # families. Production dispatch must NOT rely on package __init__ side
    # effects -- jaclang/cli/commands/__init__.jac is intentionally empty.
    register_core_commands()
    register_feature_commands()
    reg = get_registry()
    out: list[dict] = []
    for name, spec in sorted(reg.commands.items()):
        args = []
        for a in spec.args:
            args.append(
                {
                    "name": a.name,
                    "kind": _kind_name(a.kind),
                    "typ": getattr(a.typ, "__name__", str(a.typ)),
                    "default": a.default,
                    "help": a.help,
                    "short": a.short,
                    "choices": list(a.choices) if a.choices else None,
                    "required": a.required,
                    "dest": a.dest,
                    "metavar": a.metavar,
                }
            )
        handler = spec.handler
        out.append(
            {
                "name": name,
                "help": spec.help,
                "description": spec.description,
                "group": spec.group,
                "tier": spec.tier,
                "hidden": spec.hidden,
                "examples": list(spec.examples),
                "args": args,
                "handler_module": handler.__module__ if handler else None,
                "handler_name": handler.__name__ if handler else None,
            }
        )
    return out


def _serialize(data: list[dict]) -> str:
    return json.dumps({"commands": data}, indent=2, ensure_ascii=False) + "\n"


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help=(
            "Verify the on-disk manifest matches a fresh regeneration; "
            "exit nonzero on diff without writing."
        ),
    )
    args = parser.parse_args()

    data = _collect()

    if args.check:
        return _check(data)

    OUT.write_text(_serialize(data), encoding="utf-8")
    print(f"Wrote {len(data)} commands to {OUT}")
    if LEGACY_OUT.exists():
        LEGACY_OUT.unlink()
        print(f"Removed legacy {LEGACY_OUT}")
    return 0


def _check(data: list[dict]) -> int:
    """Fail if the committed manifest differs from a fresh regeneration."""
    import difflib

    if not OUT.exists():
        print(
            f"ERROR: {OUT} does not exist; "
            "run `python scripts/generate_command_manifest.py` to create it.",
            file=sys.stderr,
        )
        return 1

    regenerated = _serialize(data)
    committed = OUT.read_text(encoding="utf-8")
    if regenerated == committed:
        print(f"OK: {len(data)} commands; {OUT.name} is up to date.")
        return 0

    print(
        f"ERROR: {OUT} is out of date with the live command registry.\n"
        "Run `python scripts/generate_command_manifest.py` and commit the result.",
        file=sys.stderr,
    )
    diff = difflib.unified_diff(
        committed.splitlines(keepends=True),
        regenerated.splitlines(keepends=True),
        fromfile=f"{OUT.name} (committed)",
        tofile=f"{OUT.name} (regenerated)",
    )
    sys.stderr.writelines(diff)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
