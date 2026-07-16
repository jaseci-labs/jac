"""MCP command discovery backed by the lightweight manifest."""

from __future__ import annotations

from typing import Any

from jaclang.cli.manifest import get_command_meta, get_groups, iter_command_meta


def list_commands() -> dict[str, Any]:
    commands = [
        {"name": meta.name, "help": meta.help, "group": meta.group}
        for meta in iter_command_meta()
    ]
    commands.sort(key=lambda c: (c["group"], c["name"]))
    return {"commands": commands, "groups": get_groups(), "total": len(commands)}


def get_command(name: str) -> dict[str, Any]:
    meta = get_command_meta(name)
    if meta is None:
        return {"error": f"Command not found: {name}"}

    args: list[dict[str, Any]] = []
    seen: set[str] = set()
    for arg in meta.args:
        if arg.name in seen:
            continue
        seen.add(arg.name)
        info: dict[str, Any] = {
            "name": arg.name,
            "kind": arg.kind.name,
            "type": arg.typ,
            "required": arg.required,
            "default": arg.default,
            "help": arg.help,
        }
        if arg.short is not None:
            info["short"] = arg.short
        if arg.choices is not None:
            info["choices"] = list(arg.choices)
        args.append(info)

    return {
        "name": meta.name,
        "help": meta.help,
        "description": meta.description,
        "group": meta.group,
        "tier": meta.tier,
        "args": args,
        "examples": [{"command": c, "description": d} for c, d in meta.examples],
    }
