"""Lazy command handler loading."""

from __future__ import annotations

import importlib
from collections.abc import Callable
from typing import Any

from jaclang.cli.manifest import CommandMeta, get_command_meta

# Feature packages register commands at import time; load only when selected.
_FEATURE_BOOTSTRAPS: dict[str, tuple[str, ...]] = {
    "setup": ("jaclang.runtimelib.client.cli",),
    "retheme": ("jaclang.cli.shadcn.cli",),
    "scale": ("jaclang.scale.plugin",),
    "model": ("jaclang.byllm.cli",),
}

# Commands whose handlers live in modules not imported by cli/commands/__init__.jac
_EXTRA_MODULES: dict[str, str] = {
    "setup": "jaclang.runtimelib.client.cli",
    "retheme": "jaclang.cli.shadcn.cli",
    "scale": "jaclang.scale.plugin",
    "model": "jaclang.byllm.cli",
    "mcp": "jaclang.cli.commands.mcp",
    "ninja": "jaclang.cli.commands.tools",
    "precommit": "jaclang.cli.commands.tools",
    "completions": "jaclang.cli.commands.tools",
    "tool": "jaclang.cli.commands.tools",
    "dot": "jaclang.cli.commands.tools",
    "gen_parser": "jaclang.cli.commands.tools",
    "gen-jir-registry": "jaclang.cli.commands.tools",
    "gen-uni-dispatch": "jaclang.cli.commands.tools",
    "lsp": "jaclang.cli.commands.tools",
    "browse": "jaclang.cli.commands.browse",
    "code": "jaclang.cli.commands.code",
    "build": "jaclang.cli.commands.build",
    "ai": "jaclang.cli.commands.ai",
    "db": "jaclang.cli.commands.db",
    "guide": "jaclang.cli.commands.guide",
}

_loaded_features: set[str] = set()


def _load_feature_modules(command: str) -> None:
    if command in _loaded_features:
        return
    for mod in _FEATURE_BOOTSTRAPS.get(command, ()):
        importlib.import_module(mod)
    _loaded_features.add(command)


def _ensure_command_module(meta: CommandMeta) -> None:
    mod = _EXTRA_MODULES.get(meta.name, meta.handler_module)
    importlib.import_module(mod)


def load_handler(name: str) -> Callable[..., Any]:
    """Import and return the handler for ``name``."""
    meta = get_command_meta(name)
    if meta is None:
        raise KeyError(name)

    _load_feature_modules(name)
    _ensure_command_module(meta)

    mod = importlib.import_module(meta.handler_module)
    handler = getattr(mod, meta.handler_name, None)
    if handler is None:
        raise AttributeError(
            f"{meta.handler_module}.{meta.handler_name} missing for command {name!r}"
        )
    return handler
