"""Screen lifecycle and per-frame render for the embed TUI.

Bridges the runtime aggregate to the terminal: seeds TuiState from the
host environment, enters/leaves the alt screen, tracks terminal size,
and paints one diffed frame per dirty tick.
"""

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
# Suspected load-bearing: DiffEngine is never named below, but the import
# keeps diff.na.jac in the native link closure -- do not remove without a
# full rebuild + runtime check.
import from .diff { DiffEngine }
import from .runtime { TuiRuntime }

"""Refresh cached terminal size; flag layout-dirty (cols) or dirty (rows)."""
def tui_sync_size(state: TuiState) {
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

"""Split on newlines, strip each line, and drop the empty ones."""
def _nonempty_lines(raw: str) -> list[str] {
    lines: list[str] = [];
    for raw_line in raw.split("\n") {
        line = raw_line.strip();
        if line {
            lines.append(line);
        }
    }
    return lines;
}

"""Seed TuiState from the host env: cwd override, file list, model presets."""
def tui_populate_state(
    state: TuiState, project: str, files_env: str, presets_env: str
) {
    # Evaluate os.getcwd() unconditionally (as the original did): it must still
    # surface a failure — e.g. the process cwd was unlinked (ENOENT) — even when
    # a project override wins. A ternary calling it in the else arm would skip it.
    cwd_now = os.getcwd();
    state.cwd = project if project else cwd_now;
    state.files.extend(_nonempty_lines(files_env));
    state.model_presets.extend(_nonempty_lines(presets_env));
}

"""Enter alt screen with hidden cursor + SGR mouse; undo via tui_leave_screen."""
def tui_enter_screen(state: TuiState) {
    term_enter_alt_screen(state.render_fd);
    term_hide_cursor(state.render_fd);
    term_enable_mouse(state.render_fd);

    tui_sync_size(state);
    state.dirty = True;
}

"""Restore the terminal: mouse off, cursor shown, primary screen."""
def tui_leave_screen(state: TuiState) {
    term_disable_mouse(state.render_fd);
    term_show_cursor(state.render_fd);
    term_leave_alt_screen(state.render_fd);
}

"""Paint one diffed frame if dirty; return whether anything was drawn."""
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
