"""`jac shadcn` — top-level command group for the jac-shadcn plugin.

Subcommands:
- `jac shadcn init [--style ... --theme ... ...]`  Bootstrap shadcn into the
  current project. Flag values override `[jac-shadcn]` in jac.toml, which
  overrides hardcoded defaults. No URL needed -- the plugin composes the
  registry call internally using `[jac-shadcn].registry`.
- `jac shadcn add <names...>`     Install components. Supports `name@version`.
- `jac shadcn remove <names...>`  Uninstall components. Auto-prunes orphan
                                  npm deps unless `--keep-deps` is set.
- `jac shadcn list`               List registry components, marking installed
                                  ones. Use `--installed-only` to skip the
                                  network call.
- `jac shadcn upgrade [names...]` Re-fetch installed components. Any of
                                  --style/--theme/--font/--base-color/
                                  --radius/--menu-accent updates jac.toml
                                  and re-fetches.
- `jac shadcn prune`              Drop orphan npm deps from jac.toml without
                                  uninstalling anything.

Modeled after `jac db` (jaclang.cli.commands.db) -- one top-level command with
a positional `action` arg that the handler dispatches on. Plugins call
`@registry.command(...)` directly; this module's top-level decorator runs at
import time, and `JacShadcnPlugin.create_cmd` imports this module so the
command is registered during CLI bootstrap.
"""

import from jaclang.cli.command { Arg, ArgKind, CommandPriority }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();


@registry.command(
    name="shadcn",
    help="Manage shadcn UI components (init, add, remove, list, upgrade, prune)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="list",
            help="Subcommand: init, add, remove, list, upgrade, prune"
        ),
        Arg.create(
            "packages",
            kind=ArgKind.MULTI,
            default=[],
            help=(
                "Positional payload: component names for `add`/`remove`/`upgrade`. "
                "Component names may be pinned with `name@version` for `add`."
            )
        ),
        # Theme flags -- used by `init` and `upgrade`.
        Arg.create(
            "style",
            typ=str,
            default="",
            help="Visual style (nova/vega/maia/lyra/mira). Default: nova."
        ),
        Arg.create(
            "base-color",
            typ=str,
            default="",
            help="Base neutral color (neutral/stone/zinc/gray). Default: neutral."
        ),
        Arg.create(
            "theme",
            typ=str,
            default="",
            help="Accent theme color (rose/blue/emerald/...). Default: neutral."
        ),
        Arg.create(
            "font",
            typ=str,
            default="",
            help="Font family (inter/figtree/geist/...). Default: figtree."
        ),
        Arg.create(
            "radius",
            typ=str,
            default="",
            help="Border radius (default/none/small/medium/large). Default: default."
        ),
        Arg.create(
            "menu-accent",
            typ=str,
            default="",
            help="Menu accent (subtle/bold). Default: subtle."
        ),
        # Behavior flags.
        Arg.create(
            "keep-deps",
            typ=bool,
            default=False,
            help="`remove`: keep npm deps even if no installed component still needs them"
        ),
        Arg.create(
            "installed-only",
            typ=bool,
            default=False,
            help="`list`: skip the registry call, show only what's in jac-shadcn.lock"
        ),
        Arg.create(
            "all",
            typ=bool,
            default=False,
            help="`init`: install every component the registry ships (instead of just the 10-essentials starter set)",
            short=""
        ),
        Arg.create(
            "bare",
            typ=bool,
            default=False,
            help="`init`: skip component install entirely (theme + global.css only)",
            short=""
        ),

    ],
    examples=[
        (
            "jac shadcn init",
            "Bootstrap with defaults (nova/neutral) + install 10 essentials"
        ),
        (
            "jac shadcn init --style nova --theme rose --font figtree",
            "Bootstrap with custom theme + 10 essentials"
        ),
        (
            "jac shadcn init --all",
            "Install every component the registry ships (~53), not just essentials"
        ),
        (
            "jac shadcn init --bare",
            "Set up theme/global.css only; install no components"
        ),
        ("jac shadcn add button card dialog", "Install three components"),
        ("jac shadcn add button@1.0.0", "Pin a component version"),
        ("jac shadcn remove button", "Remove a component; auto-prune orphan deps"),
        (
            "jac shadcn remove button --keep-deps",
            "Remove without touching jac.toml deps"
        ),
        ("jac shadcn list", "List registry components, * marks installed"),
        ("jac shadcn list --installed-only", "List only installed (no network)"),
        ("jac shadcn upgrade", "Re-fetch every installed component"),
        (
            "jac shadcn upgrade --style vega --theme blue",
            "Switch style + theme, persist to jac.toml, re-fetch everything"
        ),
        ("jac shadcn upgrade button card", "Re-fetch just these two"),
        ("jac shadcn prune", "Drop orphan npm deps from jac.toml"),

    ],
    group="shadcn",
    priority=CommandPriority.PLUGIN,
    source="jac-shadcn"
)
def shadcn(
    action: str = "list",
    packages: list = [],
    style: str = "",
    base_color: str = "",
    theme: str = "",
    font: str = "",
    radius: str = "",
    menu_accent: str = "",
    keep_deps: bool = False,
    installed_only: bool = False,
    all: bool = False,
    bare: bool = False
) -> int;
