"""Keypress dispatcher: routes raw key strings to editor operations or IPC commands.

Key strings from libc_tty tty_read_key:
  Regular char     -> itself e.g. "a", " "
  Enter            -> "\r"   (CR, code 13)
  LF               -> "\n"   (code 10)
  Backspace        -> "\177" (DEL, code 127) or "\010" (BS, code 8)
  Delete           -> "\033[3~"
  Ctrl+C           -> "\003"
  Ctrl+Q           -> "\021"
  Ctrl+G (stop)    -> "\007"
  Ctrl+R (reset)   -> "\022"
  Ctrl+O (palette) -> "\017"
  Tab (slash menu) -> "\t"   when editor text starts with /
  Ctrl+A (home)    -> "\001"
  Ctrl+E (end)     -> "\005"
  Ctrl+K           -> "\013"
  Ctrl+U           -> "\025"
  Ctrl+W           -> "\027"
  ESC              -> "\033"
  Alt+Enter        -> "\033\r"
  Shift+Enter (CSI)-> "\033[13;2~"
  Up arrow         -> "\033[A" or "\033OA"
  Down arrow       -> "\033[B" or "\033OB"
  Left arrow       -> "\033[D" or "\033OD"
  Right arrow      -> "\033[C" or "\033OC"
  Home             -> "\033[H" or "\033OH"
  End              -> "\033[F" or "\033OF"
  Ctrl+Left        -> "\033[1;5D" or "\033[5D"
  Ctrl+Right       -> "\033[1;5C" or "\033[5C"
  Alt+Left         -> "\033b"  or "\033[1;3D"
  Alt+Right        -> "\033f"  or "\033[1;3C"
  Page Up          -> "\033[5~"
  Page Down        -> "\033[6~"
"""

import from .state { TuiState }
import from .ipc { ipc_send_cmd }
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_is_active,
    overlay_handle_key,
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file
}
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

def _parse_uint(s: str) -> int {
    # Parse a run of ASCII digits to an int (non-digits ignored). Used for the
    # decimal button field of an SGR mouse sequence; no NUL hazard since the
    # bytes are printable ASCII (see na-chr-concat-drops-nul).
    n: int = 0;
    i: int = 0;
    m = len(s);
    while i < m {
        c = ord(s[i]);
        if c >= 48 and c <= 57 {
            n = n * 10 + (c - 48);
        }
        i = i + 1;
    }
    return n;
}

def _editor_width(state: TuiState) -> int {
    # Content width available for the editor (same as text_width in screen.na.jac).
    # cols - 4 (box borders+space) - 2 (prompt prefix "› " or "  ")
    w = state.term_cols - 6;
    if w < 1 {
        return 1;
    }
    return w;
}

def _editor_max_rows(state: TuiState) -> int {
    # Maximum visible editor content rows (30% of terminal, min 1, max 10).
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

    # Check backslash+Enter: if char before cursor is \, replace with newline.
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

    if text == "/model" or text == "/models" {
        overlay_open_model(state);
        return False;
    }
    if text == "/file" or text == "/files" {
        overlay_open_file(state);
        return False;
    }
    if text == "/quit" or text == "/exit" or text == "/q" {
        ipc_send_cmd(ipc_fd, "QUIT");
        return True;
    }
    if text == "/stop" {
        ipc_send_cmd(ipc_fd, "STOP");
        return False;
    }
    if text == "/reset" or text == "/clear" {
        ipc_send_cmd(ipc_fd, "RESET");
        state.reset_events();
        return False;
    }
    if text.startswith("/settings ") {
        args = text[10:].strip();
        ipc_send_cmd(ipc_fd, f"APPLY:{args}");
        return False;
    }

    if state.status == "running" {
        return False;
    }

    # Add user message to transcript immediately for instant feedback
    # Use negative ID to avoid conflicts with backend-assigned IDs
    state.upsert_event(-1, "user", text, "");
    state.scroll_to_bottom();

    ipc_send_cmd(ipc_fd, f"SEND:{text}");
    return False;
}

def handle_key(key: str, state: TuiState, ipc_fd: int) -> bool {
    if len(key) == 0 {
        return False;
    }

    if overlay_is_active(state) {
        return overlay_handle_key(key, state, ipc_fd);
    }

    ed = state.editor;
    ew = _editor_width(state);
    emr = _editor_max_rows(state);

    first = key[0];
    code = ord(first);

    # ── Autocomplete intercepts (phase 7) ─────────────────────────────────────
    # These run before other key handlers so AC navigation takes priority.
    if state.ac.active {
        # Tab: apply the selected completion.
        if code == 9 {
            ac_apply(state);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }
        # Plain ESC (\033, len 1): dismiss without modifying editor.
        if code == 27 and len(key) == 1 {
            state.ac.dismiss();
            state.dirty = True;
            return False;
        }
        # Up arrow: move AC selection up instead of cursor/history.
        if key == "\033[A" or key == "\033OA" {
            state.ac.nav_up();
            state.dirty = True;
            return False;
        }
        # Down arrow: move AC selection down.
        if key == "\033[B" or key == "\033OB" {
            state.ac.nav_down();
            state.dirty = True;
            return False;
        }
        # Enter (single CR or LF): apply completion, then submit if slash command.
        if (code == 13 or code == 10) and len(key) == 1 {
            ac_kind = state.ac.kind;
            ac_apply(state);
            editor_update_scroll(ed, ew, emr);
            if ac_kind == "slash" {
                return _handle_submit(state, ipc_fd);
            }
            return False;
        }
        # Any other key: dismiss AC and fall through to normal handling.
        state.ac.dismiss();
        state.dirty = True;
    }

    # Ctrl+C (\003) or Ctrl+Q (\021)
    if code == 3 or code == 17 {
        ipc_send_cmd(ipc_fd, "QUIT");
        return True;
    }

    # Ctrl+G (\007) — stop current turn
    if code == 7 {
        ipc_send_cmd(ipc_fd, "STOP");
        state.dirty = True;
        return False;
    }

    # Ctrl+R (\022) — reset session
    if code == 18 {
        ipc_send_cmd(ipc_fd, "RESET");
        state.reset_events();
        state.dirty = True;
        return False;
    }

    # Ctrl+O (\017) — command palette
    if code == 15 {
        overlay_open_palette(state, "");
        return False;
    }

    # Tab — slash-command palette when editor starts with /
    if code == 9 {
        ed_text = ed.get_text();
        if ed_text.startswith("/") {
            overlay_open_palette(state, ed_text[1:]);
            return False;
        }
    }

    # Ctrl+A (\001) — move to line start
    if code == 1 {
        editor_move_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Ctrl+E (\005) — move to line end
    if code == 5 {
        editor_move_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Ctrl+K (\013) — delete to line end
    if code == 11 {
        editor_delete_to_line_end(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Ctrl+U (\025) — delete to line start
    if code == 21 {
        editor_delete_to_line_start(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Ctrl+W (\027) — delete word back
    if code == 23 {
        editor_delete_word_back(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Alt+Enter (\033\r) or Shift+Enter (\033[13;2~) — insert newline
    if key == "\033\r" or key == "\033[13;2~" {
        editor_newline(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Enter (\r = 13 or \n = 10)
    if code == 13 or code == 10 {
        if len(key) == 1 {
            return _handle_submit(state, ipc_fd);
        }
        # Multi-byte sequence starting with LF: treat as newline
        editor_newline(ed);
        editor_update_scroll(ed, ew, emr);
        state.dirty = True;
        return False;
    }

    # Backspace / DEL (\177 or \010)
    if code == 127 or code == 8 {
        editor_backspace(ed);
        editor_update_scroll(ed, ew, emr);
        ac_update(state);
        state.dirty = True;
        return False;
    }

    # ESC sequences
    if code == 27 and len(key) > 1 {
        # SGR mouse event: \033[<button;x;yM (press) / m (release). Wheel-up is
        # button 64, wheel-down 65 — scroll the transcript ~3 rows/notch. Other
        # buttons (press/drag/click) are reserved for a later selection effort.
        klen = len(key);
        last = key[klen - 1];
        if key.startswith("\033[<") and (last == "M" or last == "m") {
            parts = key[3:klen - 1].split(";");
            if len(parts) > 0 {
                btn = _parse_uint(parts[0]);
                if btn == 64 {
                    state.scroll_up(3);
                } elif btn == 65 {
                    state.scroll_down(3);
                }
            }
            return False;
        }

        # Delete key
        if key == "\033[3~" {
            editor_forward_delete(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Up arrow — move cursor up or navigate history older
        if key == "\033[A" or key == "\033OA" {
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

        # Down arrow — move cursor down or navigate history newer
        if key == "\033[B" or key == "\033OB" {
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

        # Left arrow
        if key == "\033[D" or key == "\033OD" {
            editor_move_left(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Right arrow
        if key == "\033[C" or key == "\033OC" {
            editor_move_right(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Home
        if key == "\033[H" or key == "\033OH" {
            editor_move_line_start(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # End
        if key == "\033[F" or key == "\033OF" {
            editor_move_line_end(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Ctrl+Left or Alt+Left — word left
        if key == "\033[1;5D"
        or key == "\033[5D"
        or key == "\033b"
        or key == "\033[1;3D" {
            editor_word_left(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Ctrl+Right or Alt+Right — word right
        if key == "\033[1;5C"
        or key == "\033[5C"
        or key == "\033f"
        or key == "\033[1;3C" {
            editor_word_right(ed);
            editor_update_scroll(ed, ew, emr);
            state.dirty = True;
            return False;
        }

        # Page Up — scroll transcript
        if key == "\033[5~" or key == "\033[1;5A" {
            state.scroll_up(state.term_rows - 4);
            return False;
        }

        # Page Down — scroll transcript
        if key == "\033[6~" or key == "\033[1;5B" {
            state.scroll_down(state.term_rows - 4);
            return False;
        }

        return False;
    }

    # Printable ASCII (32-126)
    if code >= 32 and code <= 126 {
        if len(ed.get_text()) < 4096 {
            editor_insert(ed, first);
            editor_update_scroll(ed, ew, emr);
            ac_update(state);
            state.dirty = True;
        }
        return False;
    }

    return False;
}
