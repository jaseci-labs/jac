"""Keypress dispatcher: maps raw key strings from tui_read_key to state mutations.

Returns True when the TUI should quit.

Key strings from tui_helpers.c tui_read_key:
  Regular char   -> itself e.g. "a", " "
  Enter          -> "\r"
  Backspace      -> "\177"  (DEL)
  Ctrl+C         -> "\003"
  Ctrl+Q         -> "\021"
  Ctrl+G (stop)  -> "\007"
  Ctrl+R (reset) -> "\022"
  ESC            -> "\033"
  Up arrow       -> "\033[A"
  Down arrow     -> "\033[B"
  Page Up        -> "\033[5~"
  Page Down      -> "\033[6~"
"""

import from .state { TuiState }
import from .ipc { ipc_send_cmd }

def _handle_enter(state: TuiState, ipc_fd: int) -> bool {
    prompt = state.input_buf.strip();
    state.input_buf = "";
    state.dirty = True;

    if len(prompt) == 0 {
        return False;
    }

    if prompt == "/quit" or prompt == "/exit" or prompt == "/q" {
        ipc_send_cmd(ipc_fd, "QUIT");
        return True;
    }
    if prompt == "/stop" {
        ipc_send_cmd(ipc_fd, "STOP");
        return False;
    }
    if prompt == "/reset" {
        ipc_send_cmd(ipc_fd, "RESET");
        state.reset_events();
        return False;
    }
    if prompt.startswith("/settings ") {
        args = prompt[10:].strip();
        ipc_send_cmd(ipc_fd, f"APPLY:{args}");
        return False;
    }

    if state.status == "running" {
        return False;
    }

    ipc_send_cmd(ipc_fd, f"SEND:{prompt}");
    state.scroll_to_bottom();
    return False;
}

def handle_key(key: str, state: TuiState, ipc_fd: int) -> bool {
    if len(key) == 0 {
        return False;
    }

    first = key[0];
    code = ord(first);

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

    # Enter (\r or \n)
    if code == 13 or code == 10 {
        return _handle_enter(state, ipc_fd);
    }

    # Backspace / DEL (\177 or \010)
    if code == 127 or code == 8 {
        blen = len(state.input_buf);
        if blen > 0 {
            state.input_buf = state.input_buf[:blen - 1];
            state.dirty = True;
        }
        return False;
    }

    # ESC sequences
    if code == 27 and len(key) > 1 {
        if key == "\033[A" or key == "\033OA" {
            state.scroll_up(3);
        } elif key == "\033[B" or key == "\033OB" {
            state.scroll_down(3);
        } elif key == "\033[5~" or key == "\033[1;5A" {
            state.scroll_up(state.term_rows - 4);
        } elif key == "\033[6~" or key == "\033[1;5B" {
            state.scroll_down(state.term_rows - 4);
        }
        state.dirty = True;
        return False;
    }

    # Printable ASCII
    if code >= 32 and code <= 126 {
        if len(state.input_buf) < 1024 {
            state.input_buf = state.input_buf + first;
            state.dirty = True;
        }
        return False;
    }

    return False;
}
