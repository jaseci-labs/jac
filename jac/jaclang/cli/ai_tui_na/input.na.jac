import from .state { TuiState }
import from .ipc { ipc_send_cmd }
import from .ipc_schema { IPC_CMD_SEND, IPC_CMD_STOP, IPC_CMD_RESET, IPC_CMD_QUIT }
import from .keys {
    Key,
    parse_key,
    KK_UNKNOWN,
    KK_TAB,
    KK_ESCAPE,
    KK_UP,
    KK_DOWN,
    KK_ENTER,
    KK_CTRL,
    KK_SHIFT_ENTER,
    KK_BACKSPACE,
    KK_MOUSE_SCROLL_UP,
    KK_MOUSE_SCROLL_DOWN,
    KK_DELETE,
    KK_LEFT,
    KK_RIGHT,
    KK_HOME,
    KK_END,
    KK_WORD_LEFT,
    KK_WORD_RIGHT,
    KK_PAGE_UP,
    KK_PAGE_DOWN,
    KK_CHAR
}
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_is_active,
    overlay_handle_key,
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file
}
import from .commands { slash_submit }
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

def _handle_submit(state: TuiState, ipc_fd: int) -> bool {
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

    result = slash_submit(text, state, ipc_fd);
    if result == "quit" {
        return True;
    }
    if result == "open_model" {
        overlay_open_model(state);
        return False;
    }
    if result == "open_file" {
        overlay_open_file(state);
        return False;
    }
    if result == "handled" {
        return False;
    }

    if state.status == "running" {
        return False;
    }

    state.upsert_event(-1, "user", text, "");
    state.scroll_to_bottom();

    ipc_send_cmd(ipc_fd, IPC_CMD_SEND + ":" + text);
    return False;
}

def handle_key(k: Key, state: TuiState, ipc_fd: int) -> bool {
    if k.kind == KK_UNKNOWN {
        return False;
    }

    if overlay_is_active(state) {
        return overlay_handle_key(k, state, ipc_fd);
    }

    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

    if state.ac.active {
        if k.kind == KK_TAB {
            ac_apply(state);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        if k.kind == KK_ESCAPE {
            state.ac.dismiss();
            state.dirty = True;
            return False;
        }

        if k.kind == KK_UP {
            state.ac.nav_up();
            state.dirty = True;
            return False;
        }

        if k.kind == KK_DOWN {
            state.ac.nav_down();
            state.dirty = True;
            return False;
        }

        if k.kind == KK_ENTER {
            ac_kind = state.ac.kind;
            ac_apply(state);
            editor_update_scroll(ed, ew, emr);
            if ac_kind == "slash" {
                return _handle_submit(state, ipc_fd);
            }
            return False;
        }

        state.ac.dismiss();
        state.dirty = True;
    }

    if k.kind == KK_CTRL {
        ch = chr(k.code);
        if ch == "c" or ch == "q" {
            ipc_send_cmd(ipc_fd, IPC_CMD_QUIT);
            return True;
        }
        if ch == "g" {
            ipc_send_cmd(ipc_fd, IPC_CMD_STOP);
            state.dirty = True;
            return False;
        }
        if ch == "r" {
            ipc_send_cmd(ipc_fd, IPC_CMD_RESET);
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

    if k.kind == KK_TAB {
        ed_text = ed.get_text();
        if ed_text.startswith("/") {
            overlay_open_palette(state, ed_text[1:]);
            return False;
        }
    }

    if k.kind == KK_SHIFT_ENTER {
        editor_newline(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_ENTER {
        return _handle_submit(state, ipc_fd);
    }

    if k.kind == KK_BACKSPACE {
        editor_backspace(ed);
        editor_update_scroll(ed, ew, emr);
        ac_update(state);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_MOUSE_SCROLL_UP {
        state.scroll_up(3);
        return False;
    }

    if k.kind == KK_MOUSE_SCROLL_DOWN {
        state.scroll_down(3);
        return False;
    }

    if k.kind == KK_DELETE {
        editor_forward_delete(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_UP {
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

    if k.kind == KK_DOWN {
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

    if k.kind == KK_LEFT {
        editor_move_left(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_RIGHT {
        editor_move_right(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_HOME {
        editor_move_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_END {
        editor_move_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_WORD_LEFT {
        editor_word_left(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_WORD_RIGHT {
        editor_word_right(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    if k.kind == KK_PAGE_UP {
        state.scroll_up(state.term_rows - 4);
        return False;
    }

    if k.kind == KK_PAGE_DOWN {
        state.scroll_down(state.term_rows - 4);
        return False;
    }

    if k.kind == KK_CHAR {
        if len(ed.get_text()) < 4096 {
            editor_insert(ed, chr(k.code));
            editor_update_scroll(ed, ew, emr);
            ac_update(state);
            state.dirty = True;
        }
        return False;
    }

    return False;
}
