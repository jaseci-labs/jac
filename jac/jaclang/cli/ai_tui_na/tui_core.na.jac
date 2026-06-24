"""Shared TUI lifecycle helpers: setup / loop-once / teardown.

Factored out of tui.na.jac so the subprocess entry (tui.na.jac) and the
in-process host (host.na.jac, Phase 1) drive the same renderer through one set
of helpers -- no duplication. These touch libc / g_tty and must NEVER run during
glob init: call them from `with entry` or a :pub export only.
"""

import os;

import from .libc_tty {
    tty_open,
    tty_close,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_write,
    tty_init_stdio_remap,
    tty_restore_stdio,
    tty_ipc_fd
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
import from .ipc { ipc_read_frame_v2 }
import from .screen { screen_render }
import from .diff { DiffEngine }
import from .input { handle_key }

def _sync_size(state: TuiState) {
    tty_update_size();
    new_rows: int = tty_rows();
    new_cols: int = tty_cols();
    # A column change alters line wrapping, so the display-row cache must be
    # rebuilt (mark_layout_dirty). A rows-only change leaves wrapping intact but
    # resizes the viewport that screen_render paints, so it still needs a repaint
    # (dirty) -- without this a purely vertical resize would never redraw.
    if new_cols != state.term_cols {
        state.mark_layout_dirty();
    } elif new_rows != state.term_rows {
        state.dirty = True;
    }
    state.term_rows = new_rows;
    state.term_cols = new_cols;
}

# Populate TuiState from the env-derived strings (cwd, project file list, model
# presets). Pure data -- no libc, no tty -- so it is shared verbatim by the
# subprocess tui_setup and the in-process host's tui_init.
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

# Enter the alt screen on `fd`, hide the cursor, enable mouse, sync the size and
# mark dirty. Shared by both paths; the subprocess passes fd 1, the in-process
# host passes the tty fd it owns (see plan §2).
def tui_enter_screen(state: TuiState, fd: int) {
    term_enter_alt_screen(fd);
    term_hide_cursor(fd);
    term_enable_mouse(fd);

    _sync_size(state);
    state.dirty = True;
}

# Leave the alt screen on `fd`, restore the cursor and disable mouse. Does NOT
# touch termios/stdio/tty fd -- the caller owns that (subprocess restores stdio;
# host closes its tty). Safe to call once.
def tui_leave_screen(state: TuiState, fd: int) {
    term_disable_mouse(fd);
    term_show_cursor(fd);
    term_leave_alt_screen(fd);
}

# Render-if-dirty into `fd` (fd < 0 paints into diff's in-memory buffer; see
# diff.na.jac). Returns True if it painted, False if nothing was dirty. Shared by
# the subprocess loop and the host's tui_render export.
def tui_render_once(state: TuiState, diff_engine: DiffEngine, fd: int) -> bool {
    # `dirty` is the single repaint gate. Every state change that affects the
    # screen sets it at its source: scroll/input/overlay handlers directly, the
    # transcript mutators and resize via mark_layout_dirty, and status fields in
    # ipc_apply_line. `layout_dirty` is purely the build_rows cache key, not a
    # paint trigger, so it does not belong in this condition.
    if not state.dirty {
        return False;
    }
    if state.overlay_full_redraw {
        diff_engine.invalidate();
        state.overlay_full_redraw = False;
    }
    lines = screen_render(state, state.term_cols, state.term_rows);
    diff_engine.paint(lines, state.term_cols, fd);
    state.dirty = False;
    return True;
}

# Open the tty, remap stdio for IPC, populate state from the env-derived strings,
# and enter the alt screen. Returns 0 on success, -1 on a tty/remap failure (the
# caller decides whether to exit). This is the SUBPROCESS path; the in-process
# host (host.na.jac) reuses tui_populate_state / tui_enter_screen directly but
# skips the stdio remap (no IPC pipe) and uses its own tty fd.
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

    if tty_init_stdio_remap() < 0 {
        tty_write(2, "[tui] stdio remap failed\r\n");
        tty_close();
        return -1;
    }

    state.ipc_fd = tty_ipc_fd();

    tui_populate_state(state, project, files_env, presets_env);
    tui_enter_screen(state, 1);

    return 0;
}

# One iteration of the subprocess render loop: poll, drain a keystroke, drain
# ALL pending IPC frames, repaint once. Returns True to keep looping, False
# once quit is requested (key/QUIT) or the IPC stream closes. Keyboard is
# handled before IPC frames so a steady ui_stream() delta feed cannot starve
# editing. Draining ALL available frames before a single render call is the
# key to keeping up with fast LLM token streams: with per-event render caching
# each frame is cheap to process, and rendering once after all pending frames
# are drained avoids redundant repaints.
def tui_loop_once(state: TuiState, diff_engine: DiffEngine) -> bool {
    tty_poll(50);

    if tty_key_ready() > 0 {
        k = tty_read_key();
        if len(k) > 0 {
            should_quit = handle_key(k, state, state.ipc_fd);
            if should_quit {
                state.quit_flag = True;
            }
        }
    }

    # Drain ALL available IPC frames before rendering, up to 64 per tick.
    # At 100 tok/s the producer sends ~5 EVA frames per 50 ms poll; processing
    # them all and painting once avoids queue buildup and redundant repaints.
    # The 64-frame cap prevents stalling on a partial frame whose trailing `---`
    # hasn't arrived yet (tty_stdin_ready sees bytes but ipc_read_frame_v2 would
    # block on tty_read_line waiting for the newline).
    frames_drained: int = 0;
    while tty_stdin_ready() > 0 and frames_drained < 64 {
        ok = ipc_read_frame_v2(state);
        if not ok {
            state.quit_flag = True;
            return False;
        }
        _sync_size(state);
        frames_drained = frames_drained + 1;
    }

    tui_render_once(state, diff_engine, 1);

    return not state.quit_flag;
}

# Leave the alt screen, restore termios + stdio, close the tty. Safe to call once.
def tui_teardown(state: TuiState) {
    tui_leave_screen(state, 1);
    tty_restore_stdio();
    tty_close();
}
