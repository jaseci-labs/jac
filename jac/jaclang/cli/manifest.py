"""Canonical lightweight command manifest (stdlib only)."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from enum import IntEnum
from typing import Any

from jaclang.cli._manifest_data import COMMANDS

VERB_BUDGET = 28

TOMBSTONED_VERBS: dict[str, str] = {
    "add": "jac install <pkg>",
    "format": "jac fmt",
    "lint": "jac check --lint",
    "deps": "jac install --plan",
    "script": "jac x <name>",
    "jacpack": "jac create --pack <dir>",
    "enter": "jac run --entry <name> <file>",
    "debug": "jac run --debug <file>",
    "bundle": "jac build [--as jab|sealed|binary|wheel|npm]",
    "eject": "jac build --as source",
    "js": "jac tool jac2js <file>",
    "jac2py": "jac tool jac2py <file>",
    "py2jac": "jac tool py2jac <file>",
    "jac2js": "jac tool jac2js <file>",
    "grammar": "jac tool grammar",
    "destroy": "jac scale destroy <file.jac>",
    "status": "jac scale status <file.jac>",
}

GROUP_DISPLAY: dict[str, str] = {
    "execution": "Program Execution",
    "analysis": "Code Analysis",
    "transform": "Code Transformation",
    "project": "Project Management",
    "tools": "Development Tools",
    "config": "Configuration",
    "build": "Build",
    "db": "Database",
    "microservices": "Microservices",
    "general": "General",
}

GROUP_ORDER: list[str] = [
    "execution",
    "analysis",
    "transform",
    "project",
    "tools",
    "config",
    "build",
    "db",
    "microservices",
    "general",
]

TIER_SECTIONS: dict[str, str] = {
    "core": "Common commands",
    "learn": "Learn & build with AI",
}

TIER_ORDER: list[str] = ["core", "learn"]


class ArgKind(IntEnum):
    POSITIONAL = 1
    OPTION = 2
    FLAG = 3
    MULTI = 4
    REMAINDER = 5
    APPEND = 6


@dataclass(frozen=True)
class ArgMeta:
    name: str
    kind: ArgKind
    typ: str = "str"
    default: Any = None
    help: str = ""
    short: str | None = None
    choices: tuple[Any, ...] | None = None
    required: bool = False
    dest: str | None = None
    metavar: str | None = None


@dataclass(frozen=True)
class CommandMeta:
    name: str
    help: str
    description: str
    group: str
    tier: str
    hidden: bool
    examples: tuple[tuple[str, str], ...]
    args: tuple[ArgMeta, ...]
    handler_module: str
    handler_name: str


def _parse_arg(raw: dict[str, Any]) -> ArgMeta:
    kind_raw = raw["kind"]
    if isinstance(kind_raw, str) and kind_raw.startswith("ArgKind."):
        kind_raw = kind_raw.split(".", 1)[1]
    return ArgMeta(
        name=raw["name"],
        kind=ArgKind[kind_raw],
        typ=raw.get("typ", "str"),
        default=raw.get("default"),
        help=raw.get("help", ""),
        short=raw.get("short"),
        choices=tuple(raw["choices"]) if raw.get("choices") else None,
        required=bool(raw.get("required", False)),
        dest=raw.get("dest"),
        metavar=raw.get("metavar"),
    )


def _parse_command(raw: dict[str, Any]) -> CommandMeta:
    examples = tuple((e[0], e[1]) for e in raw.get("examples", []))
    args = tuple(_parse_arg(a) for a in raw.get("args", []))
    return CommandMeta(
        name=raw["name"],
        help=raw["help"],
        description=raw.get("description", ""),
        group=raw.get("group", "general"),
        tier=raw.get("tier", ""),
        hidden=bool(raw.get("hidden", False)),
        examples=examples,
        args=args,
        handler_module=raw["handler_module"],
        handler_name=raw["handler_name"],
    )


_COMMANDS: dict[str, CommandMeta] = {
    raw["name"]: _parse_command(raw) for raw in COMMANDS
}


def validate_manifest() -> list[str]:
    """Return validation errors; empty list means valid."""
    errors: list[str] = []
    names = list(_COMMANDS.keys())
    if len(names) != len(set(names)):
        errors.append("duplicate command names in manifest")

    visible = [n for n, m in _COMMANDS.items() if not m.hidden]
    if len(visible) > VERB_BUDGET:
        errors.append(
            f"{len(visible)} visible verbs exceed budget of {VERB_BUDGET}: {sorted(visible)}"
        )

    revived = sorted(v for v in TOMBSTONED_VERBS if v in _COMMANDS)
    if revived:
        errors.append(f"tombstoned verb(s) present in manifest: {revived}")

    for name, meta in _COMMANDS.items():
        if not meta.handler_module or not meta.handler_name:
            errors.append(f"{name}: missing handler reference")
        if meta.tier and meta.tier not in TIER_SECTIONS:
            errors.append(f"{name}: unknown tier {meta.tier!r}")

    return errors


def get_command_meta(name: str) -> CommandMeta | None:
    return _COMMANDS.get(name)


def iter_command_meta(*, include_hidden: bool = False) -> Iterator[CommandMeta]:
    for meta in _COMMANDS.values():
        if not include_hidden and meta.hidden:
            continue
        yield meta


def known_command_names(*, include_hidden: bool = False) -> frozenset[str]:
    return frozenset(m.name for m in iter_command_meta(include_hidden=include_hidden))


def get_groups() -> list[str]:
    groups = {m.group for m in iter_command_meta(include_hidden=True)}
    return sorted(groups)
