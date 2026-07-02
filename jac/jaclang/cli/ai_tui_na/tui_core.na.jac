import os;

import from .libc_tty {
    tty_open,
    tty_close,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_write,
    tty_setup_stdio_contract,
    tty_restore_stdio
}
import from .terminal {
    term_enter_alt_screen,
    term_leave_alt_screen,
    term_hide_cursor,
    term_show_cursor,
    term_enable_mouse,
    term_disable_mouse
}
import from .state { TuiState }
import from .screen { screen_render }
import from .diff { DiffEngine }

def _sync_size(state: TuiState) {
    tty_update_size();
    new_rows: int = tty_rows();
    new_cols: int = tty_cols();

    if new_cols != state.term_cols {
        state.mark_layout_dirty();
    } elif new_rows != state.term_rows {
        state.dirty = True;
    }
    state.term_rows = new_rows;
    state.term_cols = new_cols;
}

def tui_populate_state(
    state: TuiState, project: str, files_env: str, presets_env: str
) {
    state.cwd = os.getcwd();
    if len(project) > 0 {
        state.cwd = project;
    }

    for raw_path in files_env.split("\n") {
        p = raw_path.strip();
        if len(p) > 0 {
            state.files.append(p);
        }
    }

    for raw_name in presets_env.split("\n") {
        name = raw_name.strip();
        if len(name) > 0 {
            state.model_presets.append(name);
        }
    }
}

def tui_enter_screen(state: TuiState) {
    term_enter_alt_screen(state.render_fd);
    term_hide_cursor(state.render_fd);
    term_enable_mouse(state.render_fd);

    _sync_size(state);
    state.dirty = True;
}

def tui_leave_screen(state: TuiState) {
    term_disable_mouse(state.render_fd);
    term_show_cursor(state.render_fd);
    term_leave_alt_screen(state.render_fd);
}

def tui_render_once(state: TuiState, diff_engine: DiffEngine) -> bool {
    if not state.dirty {
        return False;
    }
    if state.overlay_full_redraw {
        diff_engine.invalidate();
        state.overlay_full_redraw = False;
    }
    lines = screen_render(state, state.term_cols, state.term_rows);
    diff_engine.paint(lines, state.term_cols, state.render_fd);
    state.dirty = False;
    return True;
}

def tui_setup(state: TuiState, project: str, files_env: str, presets_env: str) -> int {
    tty_write(2, "[tui] starting\r\n");

    raw_fd: int = tty_open();
    if raw_fd < 0 {
        tty_write(
            2, "[tui] tty open failed (set JAC_AI_TUI_TTY or run from a terminal)\r\n"
        );
        return -1;
    }
    tty_write(2, "[tui] tty_open ok\r\n");

    contract = tty_setup_stdio_contract();
    if contract.ok == 0 {
        tty_write(2, "[tui] stdio remap failed\r\n");
        tty_close();
        return -1;
    }

    state.render_fd = contract.render_fd;
    state.ipc_fd = contract.ipc_fd;

    tui_populate_state(state, project, files_env, presets_env);
    tui_enter_screen(state);

    return 0;
}

def tui_teardown(state: TuiState) {
    tui_leave_screen(state);
    tty_restore_stdio();
    tty_close();
}
