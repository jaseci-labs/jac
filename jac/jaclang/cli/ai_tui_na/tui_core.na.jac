import os;

import from .libc_tty { tty_update_size, tty_rows, tty_cols }
import from .state { TuiState }
import from .overlay { overlay_build_modal, overlay_composite, overlay_is_active }
import from .runtime { TuiRuntime }
import from .process_terminal { ProcessTerminal }
import from .frame_renderer { FrameRenderer }

def tui_sync_size(state: TuiState) {
    tty_update_size();
    new_rows: int = tty_rows();
    new_cols: int = tty_cols();

    if new_cols != state.term_cols {
        state.mark_layout_dirty();
    } elif new_rows != state.term_rows {
        state.mark_layout_dirty();
    }
    state.term_rows = new_rows;
    state.term_cols = new_cols;
}

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

def tui_populate_state(
    state: TuiState, project: str, files_env: str, presets_env: str
) {
    cwd_now = os.getcwd();
    state.cwd = project if project else cwd_now;
    state.files.extend(_nonempty_lines(files_env));
    state.model_presets.extend(_nonempty_lines(presets_env));
}

def tui_enter_screen(state: TuiState) {
    term = ProcessTerminal();
    term.bind_fd(state.render_fd);
    term.enter_screen();
    tui_sync_size(state);
    state.mark_layout_dirty();
}

def tui_leave_screen(state: TuiState) {
    term = ProcessTerminal();
    term.bind_fd(state.render_fd);
    term.mark_entered();
    term.leave_screen();
}

def tui_render_once(rt: TuiRuntime) -> bool {
    state = rt.state;
    if not state.dirty {
        return False;
    }
    fr = FrameRenderer();
    fr.bind_diff(rt.diff);
    fr.bind_paint_buf(rt.paint_buf);
    if state.overlay_full_redraw {
        fr.invalidate();
        state.overlay_full_redraw = False;
    }
    lines = rt.screen.render(state, state.term_cols, state.term_rows);
    if overlay_is_active(state) {
        modal = overlay_build_modal(state, state.term_cols, state.term_rows);
        lines = overlay_composite(lines, modal, state.term_cols, state.term_rows);
    }
    fr.paint(lines, state.term_cols, state.render_fd);
    state.dirty = False;
    return True;
}
