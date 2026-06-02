"""Desktop plugin enums and parse helpers."""

"""Official Tauri / pytauri_plugins submodule ids (snake_case)."""
enum TauriPluginId {
    DIALOG = "dialog",
    FS = "fs",
    NOTIFICATION = "notification",
    OPENER = "opener",
    SHELL = "shell",
    CLIPBOARD_MANAGER = "clipboard_manager",
    GLOBAL_SHORTCUT = "global_shortcut",
    HTTP = "http",
    OS = "os",
    PROCESS = "process",
    AUTOSTART = "autostart",
    DEEP_LINK = "deep_link",
    SINGLE_INSTANCE = "single_instance",
    UPDATER = "updater",
    UPLOAD = "upload",
    WEBSOCKET = "websocket",
    WINDOW_STATE = "window_state",
    POSITIONER = "positioner",
    PERSISTED_SCOPE = "persisted_scope"
}

"""Top-level `jac desktop` subcommand groups."""
enum DesktopSubcommand {
    PLUGIN = "plugin"
}

"""`jac desktop plugin` actions."""
enum PluginAction {
    LIST = "list",
    ADD = "add",
    REMOVE = "remove",
    SYNC = "sync"
}

glob _OFFICIAL_TAURI_PLUGIN_ORDER: list[TauriPluginId] = [
         TauriPluginId.DIALOG,
         TauriPluginId.FS,
         TauriPluginId.NOTIFICATION,
         TauriPluginId.OPENER,
         TauriPluginId.SHELL,
         TauriPluginId.CLIPBOARD_MANAGER,
         TauriPluginId.GLOBAL_SHORTCUT,
         TauriPluginId.HTTP,
         TauriPluginId.OS,
         TauriPluginId.PROCESS,
         TauriPluginId.AUTOSTART,
         TauriPluginId.DEEP_LINK,
         TauriPluginId.SINGLE_INSTANCE,
         TauriPluginId.UPDATER,
         TauriPluginId.UPLOAD,
         TauriPluginId.WEBSOCKET,
         TauriPluginId.WINDOW_STATE,
         TauriPluginId.POSITIONER,
         TauriPluginId.PERSISTED_SCOPE
     ];

def _tauri_plugin_by_value -> dict[str, TauriPluginId] {
    out: dict[str, TauriPluginId] = {};
    for pid in _OFFICIAL_TAURI_PLUGIN_ORDER {
        out[pid.value] = pid;
    }
    return out;
}

glob _TAURI_PLUGIN_BY_VALUE: dict[str, TauriPluginId] = _tauri_plugin_by_value();

def official_tauri_plugin_ids -> list[TauriPluginId] {
    return list(_OFFICIAL_TAURI_PLUGIN_ORDER);
}

def parse_tauri_plugin_id(raw: str) -> TauriPluginId | None {
    key = str(raw).strip().lower();
    if not key {
        return None;
    }
    return _TAURI_PLUGIN_BY_VALUE.get(key);
}

def parse_desktop_subcommand(raw: str) -> DesktopSubcommand | None {
    key = str(raw).strip().lower();
    if key == DesktopSubcommand.PLUGIN.value {
        return DesktopSubcommand.PLUGIN;
    }
    return None;
}

def parse_plugin_action(raw: str) -> PluginAction | None {
    key = str(raw).strip().lower();
    if key == PluginAction.LIST.value {
        return PluginAction.LIST;
    }
    if key == PluginAction.ADD.value {
        return PluginAction.ADD;
    }
    if key == PluginAction.REMOVE.value {
        return PluginAction.REMOVE;
    }
    if key == PluginAction.SYNC.value {
        return PluginAction.SYNC;
    }
    return None;
}

def suggest_tauri_plugin_id(unknown: str) -> TauriPluginId | None {
    import difflib;
    values = [pid.value for pid in _OFFICIAL_TAURI_PLUGIN_ORDER];
    matches = difflib.get_close_matches(unknown.lower(), values, n=1, cutoff=0.6);
    if not matches {
        return None;
    }
    return _TAURI_PLUGIN_BY_VALUE.get(matches[0]);
}

def plugin_id_to_npm_package(plugin_id: TauriPluginId) -> str {
    kebab = plugin_id.value.replace("_", "-");
    return f"@tauri-apps/plugin-{kebab}";
}

def tauri_plugin_permission(plugin_id: TauriPluginId) -> str {
    perm_prefix = plugin_id.value.replace("_", "-");
    return f"{perm_prefix}:default";
}

def permissions_for_plugin_ids(plugin_ids: list[str]) -> list[str] {
    perms: list[str] = [];
    for raw in plugin_ids {
        typed = parse_tauri_plugin_id(raw);
        if typed is None {
            continue;
        }
        perm = tauri_plugin_permission(typed);
        if perm not in perms {
            perms.append(perm);
        }
    }
    return perms;
}
