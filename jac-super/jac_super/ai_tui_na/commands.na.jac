"""Command palette entries, model/file picker item lists, and execution."""

import from .state { TuiState }
import from .select_list { SelectItem }
import from .ipc { ipc_send_cmd }

def palette_commands(state: TuiState) -> list[SelectItem] {
    items: list[SelectItem] = [];

    items.append(
        SelectItem(
            value="open_model", label="/model", description="Switch the active model"
        )
    );
    items.append(
        SelectItem(
            value="open_file",
            label="/files",
            description="Insert a project file reference"
        )
    );
    items.append(
        SelectItem(
            value="scroll_bottom",
            label="Scroll to bottom",
            description="Follow latest transcript rows"
        )
    );
    items.append(
        SelectItem(
            value="scroll_top",
            label="Scroll to top",
            description="Jump to oldest visible rows"
        )
    );

    if state.status == "running" {
        items.append(
            SelectItem(
                value="/stop", label="/stop", description="Stop the current turn"
            )
        );
    }

    items.append(
        SelectItem(
            value="/clear",
            label="/clear",
            description="Clear transcript and reset session"
        )
    );
    items.append(
        SelectItem(
            value="/reset",
            label="/reset",
            description="Clear transcript and reset session"
        )
    );
    items.append(
        SelectItem(value="/quit", label="/quit", description="Exit jac ai TUI")
    );

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

def run_command(cmd: str, state: TuiState, ipc_fd: int) -> bool {
    if cmd == "scroll_bottom" {
        state.scroll_to_bottom();
        return False;
    }
    if cmd == "scroll_top" {
        state.viewport_top = 0;
        state.follow_tail = False;
        state.dirty = True;
        return False;
    }
    if cmd == "/stop" {
        ipc_send_cmd(ipc_fd, "STOP");
        state.dirty = True;
        return False;
    }
    if cmd == "/reset" or cmd == "/clear" {
        ipc_send_cmd(ipc_fd, "RESET");
        state.reset_events();
        state.dirty = True;
        return False;
    }
    if cmd == "/quit" or cmd == "/exit" or cmd == "/q" {
        ipc_send_cmd(ipc_fd, "QUIT");
        return True;
    }
    return False;
}

def apply_model(model: str, state: TuiState, ipc_fd: int) {
    # APPLY:model=<name> tells the control plane to rebuild the model live
    # (PROTOCOL.md).
    ipc_send_cmd(ipc_fd, f"APPLY:model={model}");
    state.dirty = True;
}
