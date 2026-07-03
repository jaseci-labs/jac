import os;

import from .libc_tty { tty_update_size, tty_rows, tty_cols }
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
import from .runtime { TuiRuntime }

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

def tui_render_once(rt: TuiRuntime) -> bool {
    state = rt.state;
    if not state.dirty {
        return False;
    }
    if state.overlay_full_redraw {
        rt.diff.invalidate();
        state.overlay_full_redraw = False;
    }
    lines = screen_render(state, state.term_cols, state.term_rows);
    rt.diff.paint(lines, state.term_cols, state.render_fd, rt.paint_buf);
    state.dirty = False;
    return True;
}
