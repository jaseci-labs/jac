import from .state { TuiState, EventKind, TuiStatus, AcKind }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT }
import from .runtime { TuiRuntime }
import from .keys { Key, KeyKind, parse_key }
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_is_active,
    overlay_handle_key,
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file
}
import from .commands { slash_submit, CmdResult }
import from .editor {
    editor_insert,
    editor_backspace,
    editor_forward_delete,
    editor_newline,
    editor_move_left,
    editor_move_right,
    editor_move_up,
    editor_move_down,
    editor_move_line_start,
    editor_move_line_end,
    editor_delete_to_line_end,
    editor_delete_to_line_start,
    editor_delete_word_back,
    editor_word_left,
    editor_word_right,
    editor_is_on_first_vline,
    editor_is_on_last_vline,
    editor_nav_history,
    editor_update_scroll,
    editor_submit
}

def _editor_width(state: TuiState) -> int {
    w = state.term_cols - 6;
    if w < 1 {
        return 1;
    }
    return w;
}

def _editor_max_rows(state: TuiState) -> int {
    m = state.term_rows - 6;
    if m < 1 {
        return 1;
    }
    if m > 10 {
        return 10;
    }
    return m;
}

def _handle_submit(rt: TuiRuntime) -> bool {
    state = rt.state;
    ed = state.editor;

    if len(ed.lines) > 0 {
        cur_line = ed.lines[ed.cursor_line];
        if ed.cursor_col > 0 and cur_line[ed.cursor_col - 1] == "\\" {
            editor_backspace(ed);
            editor_newline(ed);
            state.dirty = True;
            return False;
        }
    }

    text = editor_submit(ed);
    state.dirty = True;

    if len(text) == 0 {
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

    rt.cmd_queue.send(state.ipc_fd, CMD_SEND + ":" + text);
    return False;
}

def _handle_ac_key(k: Key, rt: TuiRuntime) -> bool {
    """Handle keys when autocomplete is active.""";
    state = rt.state;
    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

    if k.kind == KeyKind.TAB {
        ac_apply(state);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
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
        editor_update_scroll(ed, ew, emr);
        if ac_kind == AcKind.SLASH {
            return _handle_submit(rt);
        }
        return False;
    }

    state.ac.dismiss();
    state.dirty = True;
    return False;
}

def _handle_ctrl_key(k: Key, rt: TuiRuntime) -> bool {
    """Handle Ctrl+<char> key combinations.""";
    state = rt.state;
    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

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
        editor_move_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }
    if ch == "e" {
        editor_move_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }
    if ch == "k" {
        editor_delete_to_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }
    if ch == "u" {
        editor_delete_to_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }
    if ch == "w" {
        editor_delete_word_back(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }
    return False;
}

def _handle_movement_key(k: Key, rt: TuiRuntime) -> bool {
    """Handle cursor movement keys (up/down/left/right/home/end/word/page).""";
    state = rt.state;
    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

    if k.kind == KeyKind.UP {
        if editor_is_on_first_vline(ed, ew) {
            navigated = editor_nav_history(ed, -1);
            if not navigated {
                editor_move_line_start(ed);
            }
        } else {
            editor_move_up(ed, ew);
        }
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.DOWN {
        if editor_is_on_last_vline(ed, ew) {
            navigated = editor_nav_history(ed, 1);
            if not navigated {
                editor_move_line_end(ed);
            }
        } else {
            editor_move_down(ed, ew);
        }
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.LEFT {
        editor_move_left(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.RIGHT {
        editor_move_right(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.HOME {
        editor_move_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.END {
        editor_move_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.WORD_LEFT {
        editor_word_left(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.WORD_RIGHT {
        editor_word_right(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.PAGE_UP {
        state.scroll_up(state.term_rows - 4);
        return False;
    }

    if k.kind == KeyKind.PAGE_DOWN {
        state.scroll_down(state.term_rows - 4);
        return False;
    }

    return False;
}

def _handle_edit_key(k: Key, rt: TuiRuntime) -> bool {
    """Handle text editing keys (enter, backspace, delete, char, etc.).""";
    state = rt.state;
    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

    if k.kind == KeyKind.TAB {
        ed_text = ed.get_text();
        if ed_text.startswith("/") {
            overlay_open_palette(state, ed_text[1:]);
            return False;
        }
        return False;
    }

    if k.kind == KeyKind.SHIFT_ENTER {
        editor_newline(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.ENTER {
        return _handle_submit(rt);
    }

    if k.kind == KeyKind.BACKSPACE {
        editor_backspace(ed);
        editor_update_scroll(ed, ew, emr);
        ac_update(state);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.MOUSE_SCROLL_UP {
        state.scroll_up(3);
        return False;
    }

    if k.kind == KeyKind.MOUSE_SCROLL_DOWN {
        state.scroll_down(3);
        return False;
    }

    if k.kind == KeyKind.DELETE {
        editor_forward_delete(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KeyKind.CHAR {
        if ed.text_len() < 4096 {
            editor_insert(ed, chr(k.code));
            editor_update_scroll(ed, ew, emr);
            ac_update(state);
            state.dirty = True;
        }
        return False;
    }

    return False;
}

def handle_key(k: Key, rt: TuiRuntime) -> bool {
    """Main key dispatch — delegates to per-kind handlers.""";
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

    result = _handle_movement_key(k, rt);
    if (
        k.kind == KeyKind.UP
        or k.kind == KeyKind.DOWN
        or k.kind == KeyKind.LEFT
        or k.kind == KeyKind.RIGHT
        or k.kind == KeyKind.HOME
        or k.kind == KeyKind.END
        or k.kind == KeyKind.WORD_LEFT
        or k.kind == KeyKind.WORD_RIGHT
        or k.kind == KeyKind.PAGE_UP
        or k.kind == KeyKind.PAGE_DOWN
    ) {
        return result;
    }

    return _handle_edit_key(k, rt);
}
