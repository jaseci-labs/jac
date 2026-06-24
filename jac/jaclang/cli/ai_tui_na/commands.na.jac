"""Command registry: slash input, palette, and autocomplete share one source of truth.

Add new slash/palette commands in `_cmd_defs()` only. `slash_submit` handles typed
editor lines; `palette_commands` + `command_dispatch` handle the palette; slash AC
pulls labels/descriptions from the same registry via `slash_ac_catalog`.
"""

import from .state { TuiState, AcItem }
import from .select_list { SelectItem }
import from .ipc { ipc_send_cmd }

obj CmdDef {
    has value: str = "",
        slash_labels: list[str] = [],
        description: str = "",
        kind: str = "",
        ipc_name: str = "",
        slash_ac: bool = False,
        palette: bool = False,
        running_only: bool = False,
        palette_label: str = "";
}

glob _CMD_DEFS_CACHE: list[CmdDef] = [];

def _push_cmd(
    defs: list[CmdDef],
    value: str,
    slash_a: str,
    slash_b: str,
    description: str,
    kind: str,
    ipc_name: str,
    slash_ac: bool,
    palette: bool,
    running_only: bool,
    palette_label: str
) {
    labels: list[str] = [];
    if len(slash_a) > 0 {
        labels.append(slash_a);
    }
    if len(slash_b) > 0 and slash_b != slash_a {
        labels.append(slash_b);
    }
    defs.append(
        CmdDef(
            value=value,
            slash_labels=labels,
            description=description,
            kind=kind,
            ipc_name=ipc_name,
            slash_ac=slash_ac,
            palette=palette,
            running_only=running_only,
            palette_label=palette_label
        )
    );
}

def _cmd_defs -> list[CmdDef] {
    if len(_CMD_DEFS_CACHE) > 0 {
        return _CMD_DEFS_CACHE;
    }
    defs: list[CmdDef] = [];
    _push_cmd(
        defs,
        "open_model",
        "/model",
        "/models",
        "Switch the active model",
        "overlay",
        "",
        True,
        True,
        False,
        "/model"
    );
    _push_cmd(
        defs,
        "open_file",
        "/file",
        "/files",
        "Insert a project file reference",
        "overlay",
        "",
        True,
        True,
        False,
        "/files"
    );
    _push_cmd(
        defs,
        "scroll_bottom",
        "",
        "",
        "Follow latest transcript rows",
        "scroll_bottom",
        "",
        False,
        True,
        False,
        "Scroll to bottom"
    );
    _push_cmd(
        defs,
        "scroll_top",
        "",
        "",
        "Jump to oldest visible rows",
        "scroll_top",
        "",
        False,
        True,
        False,
        "Scroll to top"
    );
    _push_cmd(
        defs,
        "/stop",
        "/stop",
        "",
        "Stop the current turn",
        "ipc",
        "STOP",
        True,
        True,
        True,
        "/stop"
    );
    _push_cmd(
        defs,
        "/clear",
        "/clear",
        "",
        "Clear transcript and reset session",
        "ipc_reset",
        "RESET",
        True,
        True,
        False,
        "/clear"
    );
    _push_cmd(
        defs,
        "/reset",
        "/reset",
        "",
        "Clear transcript and reset session",
        "ipc_reset",
        "RESET",
        True,
        True,
        False,
        "/reset"
    );
    _push_cmd(
        defs,
        "/quit",
        "/quit",
        "/exit",
        "Exit jac ai TUI",
        "ipc",
        "QUIT",
        True,
        True,
        False,
        "/quit"
    );
    labels_q: list[str] = ["/q"];
    defs.append(
        CmdDef(
            value="/quit",
            slash_labels=labels_q,
            description="Exit jac ai TUI",
            kind="ipc",
            ipc_name="QUIT",
            slash_ac=False,
            palette=False,
            running_only=False,
            palette_label="/quit"
        )
    );
    i: int = 0;
    while i < len(defs) {
        _CMD_DEFS_CACHE.append(defs[i]);
        i = i + 1;
    }
    return _CMD_DEFS_CACHE;
}

def _find_def(value: str) -> CmdDef | None {
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        if defs[i].value == value {
            return defs[i];
        }
        i = i + 1;
    }
    return None;
}

def resolve_slash_line(text: str) -> str {
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        d = defs[i];
        j: int = 0;
        while j < len(d.slash_labels) {
            if text == d.slash_labels[j] {
                return d.value;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    return "";
}

def command_dispatch(cmd: str, state: TuiState, ipc_fd: int) -> str {
    # Returns: "quit" | "handled" | "open_model" | "open_file" | "" (unknown).
    d = _find_def(cmd);
    if d is None {
        return "";
    }
    if d.kind == "overlay" {
        if d.value == "open_model" {
            return "open_model";
        }
        if d.value == "open_file" {
            return "open_file";
        }
        return "";
    }
    if d.kind == "scroll_bottom" {
        state.scroll_to_bottom();
        return "handled";
    }
    if d.kind == "scroll_top" {
        state.viewport_top = 0;
        state.follow_tail = False;
        state.dirty = True;
        return "handled";
    }
    if d.kind == "ipc_reset" {
        ipc_send_cmd(ipc_fd, d.ipc_name);
        state.reset_events();
        state.dirty = True;
        return "handled";
    }
    if d.kind == "ipc" {
        ipc_send_cmd(ipc_fd, d.ipc_name);
        if d.ipc_name == "QUIT" {
            return "quit";
        }
        state.dirty = True;
        return "handled";
    }
    return "";
}

def slash_submit(text: str, state: TuiState, ipc_fd: int) -> str {
    # Typed editor submit for slash lines. Returns the same codes as command_dispatch
    # plus "" when the line is not a recognized slash command.
    if text.startswith("/settings ") {
        args = text[10:].strip();
        ipc_send_cmd(ipc_fd, f"APPLY:{args}");
        return "handled";
    }
    value = resolve_slash_line(text);
    if len(value) == 0 {
        return "";
    }
    return command_dispatch(value, state, ipc_fd);
}

def run_command(cmd: str, state: TuiState, ipc_fd: int) -> bool {
    return command_dispatch(cmd, state, ipc_fd) == "quit";
}

def palette_commands(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        d = defs[i];
        if d.palette {
            if d.running_only and state.status != "running" {
                i = i + 1;
                continue;
            }
            items.append(
                SelectItem(
                    value=d.value, label=d.palette_label, description=d.description
                )
            );
        }
        i = i + 1;
    }
    return items;
}

def slash_ac_catalog(state: TuiState) -> list[AcItem] {
    # Slash AC lists every slash_ac command regardless of running state (palette
    # still hides /stop when idle). Overlay entries use palette_label (/files).
    items: list[AcItem] = [];
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        d = defs[i];
        if d.slash_ac {
            label = d.slash_labels[0];
            if d.kind == "overlay" and len(d.palette_label) > 0 {
                label = d.palette_label;
            }
            items.append(AcItem(value=label, label=label, description=d.description));
        }
        i = i + 1;
    }
    return items;
}

def model_items(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    i: int = 0;
    n = len(state.model_presets);
    while i < n {
        name = state.model_presets[i];
        desc: str = "";
        if name == state.model_name {
            desc = "current";
        }
        items.append(SelectItem(value=name, label=name, description=desc));
        i = i + 1;
    }
    return items;
}

def file_items(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    i: int = 0;
    n = len(state.files);
    while i < n {
        path = state.files[i];
        items.append(SelectItem(value=path, label=path, description=""));
        i = i + 1;
    }
    return items;
}

def apply_model(model: str, state: TuiState, ipc_fd: int) {
    # APPLY:model=<name> tells the control plane to rebuild the model live
    # (PROTOCOL.md).
    ipc_send_cmd(ipc_fd, f"APPLY:model={model}");
    state.dirty = True;
}
