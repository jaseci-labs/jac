"""jac-shadcn plugin — hooks for CLI extensions and template registration.

Registers:
- `--shadcn` flag on `jac add` and `jac remove`
- `jac-shadcn` project template for `jac create --use jac-shadcn`
"""

import json;
import from pathlib { Path }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.jac0core.runtime { hookimpl }

class JacShadcnPlugin {
    @hookimpl
    static def create_cmd -> None;

    @hookimpl
    static def register_project_template -> dict | None;
}

"""Pre-hook handler for `jac add --shadcn`."""
def _handle_shadcn_add(ctx: HookContext) -> None;

"""Pre-hook handler for `jac remove --shadcn`."""
def _handle_shadcn_remove(ctx: HookContext) -> None;

"""Fallback template with Tailwind v4 + shadcn theming scaffold."""
def _get_default_template -> dict;
