"""jac-shadcn plugin — hooks for CLI extensions.

Registers:
- `--shadcn` flag on `jac add` and `jac remove`
- `jac-shadcn` project template via `register_project_template` hook
"""

import from jaclang.cli.command { Arg, HookContext }
import from jaclang.jac0core.runtime { hookimpl }
import from typing { Any }

class JacShadcnPlugin {
    @hookimpl
    static def create_cmd -> None;

    @hookimpl
    static def register_project_template -> dict[str, Any] | None;
}

"""Pre-hook handler for `jac add --shadcn`."""
def _handle_shadcn_add(ctx: HookContext) -> None;

"""Pre-hook handler for `jac remove --shadcn`."""
def _handle_shadcn_remove(ctx: HookContext) -> None;
