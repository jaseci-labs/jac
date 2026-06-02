"""jac-desktop CLI entry — registers `jac desktop plugin …` commands."""

import from jaclang.cli.registry {
    get_registry,
    Arg,
    ArgKind,
    HookContext,
    CommandPriority
}
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import from jaclang.jac0core.runtime { hookimpl }
import from pathlib { Path }
import from typing { Any }

import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
import from jac_desktop.enums {
    PluginAction,
    official_tauri_plugin_ids,
    parse_tauri_plugin_id,
    parse_desktop_subcommand,
    parse_plugin_action,
    suggest_tauri_plugin_id,
    plugin_id_to_npm_package,
    tauri_plugin_permission,
    permissions_for_plugin_ids
}
import from jac_desktop.helpers.desktop_helpers { DESKTOP_CLI_COMMAND }
import from jac_desktop.targets.pytauri_desktop_target {
    _generate_pytauri_capabilities,
    sync_tauri_plugin_npm_dependencies
}

def _resolve_pytauri_project(ctx: HookContext) -> Path | None {
    cfg = get_config();
    if cfg is None {
        console.error(
            "No jac.toml found.",
            hint="Run 'jac create' (or cd into a Jac project) first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }
    project_dir = Path(str(cfg.project_root)) if cfg.project_root else Path.cwd();
    pytauri_dir = project_dir / "src-pytauri";
    if not pytauri_dir.exists() {
        console.error(
            f"Not a pytauri desktop project: {pytauri_dir} does not exist.",
            hint="Run 'jac setup desktop' first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }
    return project_dir;
}

def _read_tauri_plugins(project_dir: Path) -> list[str] {
    desktop_cfg = get_desktop_config(project_dir);
    try {
        return desktop_cfg.get_tauri_plugins_config();
    } except Exception as e {
        console.warning(
            f"Failed to read [plugins.desktop].tauri_plugins ({e}); treating as empty"
        );
        return [];
    }
}

def _write_tauri_plugins(plugin_ids: list[str]) {
    import from jaclang.jac0core.helpers { read_toml_with_encoding }
    cfg = get_config();
    if cfg is None or cfg.toml_path is None {
        raise RuntimeError("No jac.toml found");
    }
    toml_path = cfg.toml_path;
    if toml_path.exists() {
        doc = read_toml_with_encoding(str(toml_path));
    } else {
        doc = {};
    }
    if "plugins" not in doc {
        doc["plugins"] = {};
    }
    if "desktop" not in doc["plugins"] {
        doc["plugins"]["desktop"] = {};
    }
    doc["plugins"]["desktop"]["tauri_plugins"] = list(plugin_ids);
    cfg.persist_doc(doc);
    reset_desktop_config();
}

def _regen_all(project_dir: Path) {
    pytauri_dir = project_dir / "src-pytauri";
    plugin_ids = _read_tauri_plugins(project_dir);
    extra_perms = permissions_for_plugin_ids(plugin_ids);
    _generate_pytauri_capabilities(pytauri_dir, extra_permissions=extra_perms);
    sync_tauri_plugin_npm_dependencies(project_dir);
}

def _handle_plugin_list(ctx: HookContext) -> None {
    project_dir = _resolve_pytauri_project(ctx);
    if project_dir is None {
        return;
    }
    current = set(_read_tauri_plugins(project_dir));
    official = official_tauri_plugin_ids();
    official_values = {pid.value for pid in official};
    console.print("Tauri plugins (jac-desktop catalog):", style="bold");
    console.print("  ✔ = installed in [plugins.desktop].tauri_plugins", style="muted");
    console.print("");
    for pid in official {
        mark = "✔" if pid.value in current else " ";
        npm_pkg = plugin_id_to_npm_package(pid);
        perm = tauri_plugin_permission(pid);
        style = "success" if pid.value in current else "muted";
        console.print(
            f"  {mark} {pid.value:<22} npm: {npm_pkg:<32} perm: {perm}", style=style
        );
    }
    unofficial = sorted(current - official_values);
    if unofficial {
        console.print("");
        console.print("User-added (unknown to jac-desktop catalog):", style="warning");
        for pid in unofficial {
            console.print(f"  ? {pid}", style="warning");
        }
    }
    ctx.set_data("cancel_execution", True);
    ctx.set_data("cancel_return_code", 0);
}

def _cancel_plugin_cmd(ctx: HookContext, code: int) {
    ctx.set_data("cancel_execution", True);
    ctx.set_data("cancel_return_code", code);
}

def _validate_plugin_ids(ctx: HookContext, plugin_ids: Any) -> bool {
    unknown = [
        pid
        for pid in plugin_ids
        if parse_tauri_plugin_id(str(pid)) is None
    ];
    if not unknown {
        return True;
    }
    for pid in unknown {
        sug = suggest_tauri_plugin_id(str(pid));
        if sug {
            console.error(
                f"Unknown plugin id: '{pid}'", hint=f"Did you mean '{sug.value}'?"
            );
        } else {
            console.error(f"Unknown plugin id: '{pid}'");
        }
    }
    console.print(
        "Run 'jac desktop plugin list' to see the official catalog.", style="muted"
    );
    _cancel_plugin_cmd(ctx, 1);
    return False;
}

def _apply_plugin_diff(
    ctx: HookContext, project_dir: Path, action: PluginAction
) -> None {
    plugin_ids = ctx.get_arg("names", []);
    if not plugin_ids {
        plugin_ids = ctx.get_arg("plugin_ids", []);
    }
    if not plugin_ids {
        if action == PluginAction.ADD {
            console.error(
                "No plugin ids specified.",
                hint="Usage: jac desktop plugin add dialog fs notification"
            );
        } else {
            console.error(
                "No plugin ids specified.",
                hint="Usage: jac desktop plugin remove dialog fs"
            );
        }
        _cancel_plugin_cmd(ctx, 1);
        return;
    }
    if action == PluginAction.ADD and not _validate_plugin_ids(ctx, plugin_ids) {
        return;
    }
    current = _read_tauri_plugins(project_dir);
    changed = [];
    if action == PluginAction.ADD {
        for pid in plugin_ids {
            if pid not in current {
                current.append(pid);
                changed.append(pid);
            }
        }
        if not changed {
            console.print(
                "Nothing to add — all requested plugins are already installed.",
                style="muted"
            );
            _cancel_plugin_cmd(ctx, 0);
            return;
        }
        _write_tauri_plugins(current);
        changed_str = ", ".join([str(c) for c in changed]);
        console.print(
            f"  ✔ Added to [plugins.desktop].tauri_plugins: {changed_str}",
            style="success"
        );
    } elif action == PluginAction.REMOVE {
        for pid in plugin_ids {
            if pid in current {
                current.remove(pid);
                changed.append(pid);
            }
        }
        if not changed {
            console.print(
                "Nothing to remove — none of those plugins are installed.",
                style="muted"
            );
            _cancel_plugin_cmd(ctx, 0);
            return;
        }
        _write_tauri_plugins(current);
        changed_str = ", ".join([str(c) for c in changed]);
        console.print(
            f"  ✔ Removed from [plugins.desktop].tauri_plugins: {changed_str}",
            style="success"
        );
    }
    _regen_all(project_dir);
    console.success("Desktop plugins updated.");
    _cancel_plugin_cmd(ctx, 0);
}

def _handle_plugin_add(ctx: HookContext) -> None {
    project_dir = _resolve_pytauri_project(ctx);
    if project_dir is None {
        return;
    }
    _apply_plugin_diff(ctx, project_dir, PluginAction.ADD);
}

def _handle_plugin_remove(ctx: HookContext) -> None {
    project_dir = _resolve_pytauri_project(ctx);
    if project_dir is None {
        return;
    }
    _apply_plugin_diff(ctx, project_dir, PluginAction.REMOVE);
}

def _handle_plugin_sync(ctx: HookContext) -> None {
    project_dir = _resolve_pytauri_project(ctx);
    if project_dir is None {
        return;
    }
    console.print("Regenerating capabilities and npm deps...", style="muted");
    _regen_all(project_dir);
    console.success("Desktop plugins synced.");
    ctx.set_data("cancel_execution", True);
    ctx.set_data("cancel_return_code", 0);
}

def _print_desktop_help -> None {
    import from jaclang.cli.help { get_help_formatter }
    registry = get_registry();
    spec = registry.get(DESKTOP_CLI_COMMAND);
    if spec is None {
        console.print("Usage: jac desktop plugin list|add|remove|sync", style="muted");
        return;
    }
    formatter = get_help_formatter();
    console.print(formatter.format_command_help(spec));
}

glob _PLUGIN_ACTION_HANDLERS: dict[PluginAction, any] = {
         PluginAction.LIST: _handle_plugin_list,
         PluginAction.ADD: _handle_plugin_add,
         PluginAction.REMOVE: _handle_plugin_remove,
         PluginAction.SYNC: _handle_plugin_sync
     };

def _handle_desktop_cmd(ctx: HookContext) -> None {
    sub_raw = ctx.get_arg("subcommand") or "";
    action_raw = ctx.get_arg("action") or "";
    if not sub_raw {
        _print_desktop_help();
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
        return;
    }
    sub = parse_desktop_subcommand(sub_raw);
    if sub is None {
        console.error(
            f"Unknown 'jac desktop' subcommand: '{sub_raw}'",
            hint="Try: jac desktop plugin list|add|remove|sync"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    if not action_raw {
        _print_desktop_help();
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
        return;
    }
    action = parse_plugin_action(action_raw);
    if action is None {
        console.error(
            f"Unknown 'jac desktop plugin' action: '{action_raw}'",
            hint="Try: jac desktop plugin list|add|remove|sync"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    handler = _PLUGIN_ACTION_HANDLERS.get(action);
    if handler {
        handler(ctx);
    }
}

def _desktop_cmd_noop(
    subcommand: str = "", action: str = "", names: list[str] | None = None
) -> int {
    # Handler stub — all logic runs in the pre_hook (same pattern as jac-client build/setup).
    return 0;
}

"""CLI hooks for jac-desktop."""
class JacCmd {
    @hookimpl
    static def create_cmd {
        registry = get_registry();
        registry.command(
            name=DESKTOP_CLI_COMMAND,
            help="Manage native desktop (PyTauri) functionality for the current project.",
            args=[
                Arg.create(
                    "subcommand",
                    kind=ArgKind.POSITIONAL,
                    help="Subcommand group (currently only: plugin)"
                ),
                Arg.create(
                    "action",
                    kind=ArgKind.POSITIONAL,
                    help="Action: list | add | remove | sync"
                ),
                Arg.create(
                    "names",
                    kind=ArgKind.MULTI,
                    default=[],
                    help="Plugin ids for add/remove (e.g. dialog fs notification)"
                )
            ],
            examples=[
                (
                    "jac desktop plugin list",
                    "Show installed and available tauri plugins"
                ),
                ("jac desktop plugin add dialog fs", "Install dialog and fs plugins"),
                ("jac desktop plugin remove dialog", "Uninstall the dialog plugin"),
                ("jac desktop plugin sync", "Regenerate after manual jac.toml edits")
            ],
            group="project",
            priority=CommandPriority.PLUGIN,
            source="jac-desktop"
        )(
            _desktop_cmd_noop
        );
        registry.extend_command(
            command_name=DESKTOP_CLI_COMMAND,
            pre_hook=_handle_desktop_cmd,
            source="jac-desktop"
        );
    }
}
