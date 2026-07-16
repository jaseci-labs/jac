#!/usr/bin/env python3
"""Generate jac/jaclang/cli/_manifest_data.py from the live command registry.

Run from the jac source tree after registry changes to refresh the canonical
manifest. Requires a working jaclang import (dev or release).
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "jac"
OUT = ROOT / "jaclang" / "cli" / "_manifest_data.py"


def _kind_name(kind: object) -> str:
    if hasattr(kind, "name"):
        return kind.name
    text = str(kind)
    if text.startswith("ArgKind."):
        return text.split(".", 1)[1]
    return text


def _collect() -> list[dict]:
    sys.path.insert(0, str(ROOT))
    import jaclang.cli.commands  # noqa: F401
    from jaclang.cli.registry import get_registry, register_feature_commands

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


def _emit(data: list[dict]) -> str:
    import pprint

    body = pprint.pformat(data, width=120, sort_dicts=False)
    return (
        '"""Auto-generated command manifest. Do not edit by hand.\n\n'
        "Regenerate with: python scripts/generate_command_manifest.py\n"
        '"""\n\n'
        "from __future__ import annotations\n\n"
        f"COMMANDS: list[dict] = {body}\n"
    )


def main() -> int:
    data = _collect()
    OUT.write_text(_emit(data), encoding="utf-8")
    print(f"Wrote {len(data)} commands to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
