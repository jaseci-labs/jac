"""Keypress dispatcher for the JS sidecar.

Ported from `ai_tui_na/input.na.jac`. Unlike the NA version (which writes commands
to an fd inline), this is I/O-free: `handle_key` returns a `KeyResult` carrying
the commands to emit and whether to quit, so it is directly unit-testable and
main.cl.jac owns the actual stdout writes. main also translates OpenTUI key
events into the raw key strings this expects (a single char, "\r", "\x7f",
control codes, or an ESC sequence like "\x1b[A").
"""

import from .state { TuiState }

obj:pub KeyResult {
    has commands: list[str] = [],
        quit: bool = False;
}

obj:pub Input {
    def _handle_enter(state: TuiState) -> KeyResult {
        res = KeyResult();
        prompt = state.input_buf.strip();
        state.input_buf = "";
        state.dirty = True;

        if len(prompt) == 0 {
            return res;
        }

        if prompt == "/quit" or prompt == "/exit" or prompt == "/q" {
            res.commands.append("QUIT");
            res.quit = True;
            return res;
        }
        if prompt == "/stop" {
            res.commands.append("STOP");
            return res;
        }
        if prompt == "/reset" {
            res.commands.append("RESET");
            state.reset_events();
            return res;
        }
        if prompt.startswith("/settings ") {
            args = prompt[10:].strip();
            res.commands.append(f"APPLY:{args}");
            return res;
        }

        if state.status == "running" {
            return res;
        }

        res.commands.append(f"SEND:{prompt}");
        state.scroll_to_bottom();
        return res;
    }

    def handle_key(state: TuiState, key: str) -> KeyResult {
        res = KeyResult();
        if len(key) == 0 {
            return res;
        }

        first = key[0];
        code = ord(first);

        # Ctrl+C (\003) or Ctrl+Q (\021)
        if code == 3 or code == 17 {
            res.commands.append("QUIT");
            res.quit = True;
            return res;
        }

        # Ctrl+G (\007) — stop current turn
        if code == 7 {
            res.commands.append("STOP");
            state.dirty = True;
            return res;
        }

        # Ctrl+R (\022) — reset session
        if code == 18 {
            res.commands.append("RESET");
            state.reset_events();
            state.dirty = True;
            return res;
        }

        # Enter (\r or \n)
        if code == 13 or code == 10 {
            return self._handle_enter(state);
        }

        # Backspace / DEL (\177 or \010)
        if code == 127 or code == 8 {
            blen = len(state.input_buf);
            if blen > 0 {
                state.input_buf = state.input_buf[:blen - 1];
                state.dirty = True;
            }
            return res;
        }

        # ESC sequences
        if code == 27 and len(key) > 1 {
            if key == "\x1b[A" or key == "\x1bOA" {
                state.scroll_up(3);
            } elif key == "\x1b[B" or key == "\x1bOB" {
                state.scroll_down(3);
            } elif key == "\x1b[5~" or key == "\x1b[1;5A" {
                state.scroll_up(state.term_rows - 4);
            } elif key == "\x1b[6~" or key == "\x1b[1;5B" {
                state.scroll_down(state.term_rows - 4);
            }
            state.dirty = True;
            return res;
        }

        # Printable ASCII
        if code >= 32 and code <= 126 {
            if len(state.input_buf) < 1024 {
                state.input_buf = state.input_buf + first;
                state.dirty = True;
            }
            return res;
        }

        return res;
    }
}
