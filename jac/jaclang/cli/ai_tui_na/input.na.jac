"""Keyboard dispatch for the TUI: routes parsed keys to the overlay,
autocomplete popup, Ctrl-chord, cursor-movement, and text-editing handlers.
Every handler returns True only when the app should quit."""
import from .state { TuiState, EventKind, TuiStatus, AcKind }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT }
import from .runtime { TuiRuntime }
import from .keys { Key, KeyKind }
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_is_active,
    overlay_handle_key,
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file
}
import from .commands { slash_submit, CmdResult }

glob _EDITOR_CHROME_COLS: int = 6,  # frame/prompt columns around the editor text
    _EDITOR_CHROME_ROWS: int = 6,  # header/status rows around the editor box
    _INPUT_EDITOR_MAX_ROWS: int = 10,  # editor viewport height cap
    _PAGE_CHROME_ROWS: int = 4,  # rows excluded from a PageUp/PageDown jump
    _MOUSE_SCROLL_LINES: int = 3,  # feed lines per mouse wheel tick
    _MAX_INPUT_LEN: int = 4096;  # editor content byte cap

# --- editor geometry ---

"""Usable editor text width for the current terminal size (>= 1)."""
def _editor_width(state: TuiState) -> int {
    return max(1, state.term_cols - _EDITOR_CHROME_COLS);
}

"""Editor viewport row budget for the current terminal size, clamped to
[1, _INPUT_EDITOR_MAX_ROWS]."""
def _editor_max_rows(state: TuiState) -> int {
    return max(1, min(_INPUT_EDITOR_MAX_ROWS, state.term_rows - _EDITOR_CHROME_ROWS));
}

"""Post-edit epilogue: re-clamp the editor viewport to the cursor and mark
the frame dirty."""
def _sync_editor_view(state: TuiState) {
    state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
    state.dirty = True;
}

# --- submit ---

"""True when the character left of the cursor is a backslash, i.e. the user
asked for a line continuation instead of a submit."""
def _pending_continuation(state: TuiState) -> bool {
    ed = state.editor;
    if not ed.lines {
        return False;
    }
    if ed.cursor_col <= 0 {
        return False;
    }
    cur_line = ed.lines[ed.cursor_line];
    return cur_line[ed.cursor_col - 1] == "\\";
}

"""Submit the editor buffer: backslash continuation turns Enter into a
newline; slash commands dispatch locally; anything else is echoed to the
feed and sent over IPC (unless a run is already in flight)."""
def _handle_submit(rt: TuiRuntime) -> bool {
    state = rt.state;
    ed = state.editor;

    if _pending_continuation(state) {
        ed.backspace();
        ed.newline();
        state.dirty = True;
        return False;
    }

    text = ed.submit();
    state.dirty = True;
    if not text {
        return False;
    }

    result = slash_submit(text, rt);
    if result == CmdResult.QUIT {
        return True;
    }
    if result == CmdResult.OPEN_MODEL {
        overlay_open_model(state);
        return False;
    }
    if result == CmdResult.OPEN_FILE {
        overlay_open_file(state);
        return False;
    }
    if result == CmdResult.HANDLED {
        return False;
    }

    if state.status == TuiStatus.RUNNING {
        return False;
    }

    state.upsert_event(-1, EventKind.USER, text, "");
    state.scroll_to_bottom();

    # Concat, not an f-string: text may be up to _MAX_INPUT_LEN bytes and
    # f-strings truncate at 1024.
    rt.cmd_queue.send(state.ipc_fd, CMD_SEND + ":" + text);
    return False;
}

# --- per-mode handlers ---

"""Handle keys while the autocomplete popup is open."""
def _handle_ac_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;

    if k.kind == KeyKind.TAB {
        ac_apply(state);
        _sync_editor_view(state);
        return False;
    }
    if k.kind == KeyKind.ESCAPE {
        state.ac.dismiss();
        state.dirty = True;
        return False;
    }
    if k.kind == KeyKind.UP {
        state.ac.nav_up();
        state.dirty = True;
        return False;
    }
    if k.kind == KeyKind.DOWN {
        state.ac.nav_down();
        state.dirty = True;
        return False;
    }
    if k.kind == KeyKind.ENTER {
        ac_kind = state.ac.kind;
        ac_apply(state);
        state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
        if ac_kind == AcKind.SLASH {
            return _handle_submit(rt);
        }
        return False;
    }

    state.ac.dismiss();
    return _handle_edit_key(k, rt);
}

"""Handle Ctrl+<char> chords: app control, overlay open, and line editing."""
def _handle_ctrl_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    ed = state.editor;

    ch = chr(k.code);
    if ch == "c" or ch == "q" {
        rt.cmd_queue.send(state.ipc_fd, CMD_QUIT);
        return True;
    }
    if ch == "g" {
        rt.cmd_queue.send(state.ipc_fd, CMD_STOP);
        state.dirty = True;
        return False;
    }
    if ch == "r" {
        rt.cmd_queue.send(state.ipc_fd, CMD_RESET);
        state.reset_events();
        state.dirty = True;
        return False;
    }
    if ch == "o" {
        overlay_open_palette(state, "");
        return False;
    }
    if ch == "a" {
        ed.move_line_start();
        _sync_editor_view(state);
        return False;
    }
    if ch == "e" {
        ed.move_line_end();
        _sync_editor_view(state);
        return False;
    }
    if ch == "k" {
        ed.delete_to_line_end();
        _sync_editor_view(state);
        return False;
    }
    if ch == "u" {
        ed.delete_to_line_start();
        _sync_editor_view(state);
        return False;
    }
    if ch == "w" {
        ed.delete_word_back();
        _sync_editor_view(state);
        return False;
    }
    return False;
}

"""Handle cursor-movement and page-scroll keys. Returns True when the key
was a movement key (handled); False tells the caller to try the edit
handler. Movement never quits the app."""
def _handle_movement_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    ed = state.editor;
    ew = _editor_width(state);

    if k.kind == KeyKind.UP {
        if ed.is_on_first_vline(ew) {
            navigated = ed.nav_history(-1);
            if not navigated {
                ed.move_line_start();
            }
        } else {
            ed.move_up(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.DOWN {
        if ed.is_on_last_vline(ew) {
            navigated = ed.nav_history(1);
            if not navigated {
                ed.move_line_end();
            }
        } else {
            ed.move_down(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.LEFT {
        ed.move_left();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.RIGHT {
        ed.move_right();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.HOME {
        ed.move_line_start();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.END {
        ed.move_line_end();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.WORD_LEFT {
        ed.word_left();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.WORD_RIGHT {
        ed.word_right();
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.PAGE_UP {
        state.scroll_up(state.term_rows - _PAGE_CHROME_ROWS);
        return True;
    }
    if k.kind == KeyKind.PAGE_DOWN {
        state.scroll_down(state.term_rows - _PAGE_CHROME_ROWS);
        return True;
    }
    return False;
}

"""Handle text-editing keys and mouse scroll."""
def _handle_edit_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    ed = state.editor;

    if k.kind == KeyKind.TAB {
        ed_text = ed.get_text();
        if ed_text.startswith("/") {
            overlay_open_palette(state, ed_text[1:]);
        }
        return False;
    }
    if k.kind == KeyKind.SHIFT_ENTER {
        ed.newline();
        _sync_editor_view(state);
        return False;
    }
    if k.kind == KeyKind.ENTER {
        return _handle_submit(rt);
    }
    if k.kind == KeyKind.BACKSPACE {
        ed.backspace();
        _sync_editor_view(state);
        ac_update(state);
        return False;
    }
    if k.kind == KeyKind.MOUSE_SCROLL_UP {
        state.scroll_up(_MOUSE_SCROLL_LINES);
        return False;
    }
    if k.kind == KeyKind.MOUSE_SCROLL_DOWN {
        state.scroll_down(_MOUSE_SCROLL_LINES);
        return False;
    }
    if k.kind == KeyKind.DELETE {
        ed.forward_delete();
        _sync_editor_view(state);
        return False;
    }
    if k.kind == KeyKind.CHAR {
        if ed.text_len() >= _MAX_INPUT_LEN {
            return False;
        }
        ed.insert(chr(k.code));
        _sync_editor_view(state);
        ac_update(state);
        return False;
    }
    return False;
}

# --- entry point ---

"""Top-level key dispatch: overlay first, then autocomplete popup, Ctrl
chords, movement, and finally text editing. Returns True on quit."""
def handle_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    if k.kind == KeyKind.UNKNOWN {
        return False;
    }
    if overlay_is_active(state) {
        return overlay_handle_key(k, rt);
    }
    if state.ac.active {
        return _handle_ac_key(k, rt);
    }
    if k.kind == KeyKind.CTRL {
        return _handle_ctrl_key(k, rt);
    }
    if _handle_movement_key(k, rt) {
        return False;
    }
    return _handle_edit_key(k, rt);
}
