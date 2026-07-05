import from .state { TuiState, AcItem, TuiStatus }
import from .select_list { SelectItem }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT, CMD_APPLY }
import from .runtime { TuiRuntime }

enum CmdKind {
    NONE = 0,
    OVERLAY = 1,
    SCROLL_BOTTOM = 2,
    SCROLL_TOP = 3,
    IPC_RESET = 4,
    IPC = 5,
}

enum CmdResult { NONE = 0, HANDLED = 1, QUIT = 2, OPEN_MODEL = 3, OPEN_FILE = 4, }

obj CmdDef {
    has value: str = "",
        slash_labels: list[str] = [],
        description: str = "",
        kind: CmdKind = CmdKind.NONE,
        ipc_name: str = "",
        slash_ac: bool = False,
        palette: bool = False,
        running_only: bool = False,
        palette_label: str = "";

    def execute(rt: TuiRuntime) -> CmdResult {
        state = rt.state;

        if self.kind == CmdKind.OVERLAY {
            if self.value == "open_model" {
                return CmdResult.OPEN_MODEL;
            }
            if self.value == "open_file" {
                return CmdResult.OPEN_FILE;
            }
            return CmdResult.NONE;
        }

        if self.kind == CmdKind.SCROLL_BOTTOM {
            state.scroll_to_bottom();
            return CmdResult.HANDLED;
        }

        if self.kind == CmdKind.SCROLL_TOP {
            state.viewport_top = 0;
            state.follow_tail = False;
            state.dirty = True;
            return CmdResult.HANDLED;
        }

        if self.kind == CmdKind.IPC_RESET {
            rt.cmd_queue.send(state.ipc_fd, self.ipc_name);
            state.reset_events();
            state.dirty = True;
            return CmdResult.HANDLED;
        }

        if self.kind == CmdKind.IPC {
            rt.cmd_queue.send(state.ipc_fd, self.ipc_name);
            if self.ipc_name == CMD_QUIT {
                return CmdResult.QUIT;
            }
            state.dirty = True;
            return CmdResult.HANDLED;
        }

        return CmdResult.NONE;
    }
}

glob _CMD_DEFS_CACHE: list[CmdDef] = [];

def _push_cmd(
    defs: list[CmdDef],
    value: str,
    slash_a: str,
    slash_b: str,
    description: str,
    kind: CmdKind,
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
        CmdKind.OVERLAY,
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
        CmdKind.OVERLAY,
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
        CmdKind.SCROLL_BOTTOM,
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
        CmdKind.SCROLL_TOP,
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
        CmdKind.IPC,
        CMD_STOP,
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
        CmdKind.IPC_RESET,
        CMD_RESET,
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
        CmdKind.IPC_RESET,
        CMD_RESET,
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
        CmdKind.IPC,
        CMD_QUIT,
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
            kind=CmdKind.IPC,
            ipc_name=CMD_QUIT,
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

def command_dispatch(cmd: str, rt: TuiRuntime) -> CmdResult {
    d = _find_def(cmd);
    if d is None {
        return CmdResult.NONE;
    }
    return d.execute(rt);
}

def slash_submit(text: str, rt: TuiRuntime) -> CmdResult {
    state = rt.state;
    if text.startswith("/settings ") {
        args = text[10:].strip();
        rt.cmd_queue.send(state.ipc_fd, CMD_APPLY + ":" + args);
        return CmdResult.HANDLED;
    }
    value = resolve_slash_line(text);
    if len(value) == 0 {
        return CmdResult.NONE;
    }
    return command_dispatch(value, rt);
}

def run_command(cmd: str, rt: TuiRuntime) -> bool {
    return command_dispatch(cmd, rt) == CmdResult.QUIT;
}

def palette_commands(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        d = defs[i];
        if d.palette {
            if d.running_only and state.status != TuiStatus.RUNNING {
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
    items: list[AcItem] = [];
    defs = _cmd_defs();
    i: int = 0;
    while i < len(defs) {
        d = defs[i];
        if d.slash_ac {
            label = d.slash_labels[0];
            if d.kind == CmdKind.OVERLAY and len(d.palette_label) > 0 {
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

def apply_model(model: str, rt: TuiRuntime) {
    state = rt.state;
    rt.cmd_queue.send(state.ipc_fd, CMD_APPLY + ":model=" + model);
    state.dirty = True;
}
