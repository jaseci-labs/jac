"""Wire-protocol frame parser for the JS sidecar.

Ported from `ai_tui_na/ipc.na.jac` with identical semantics, minus the raw line
I/O (which lives in main.cl.jac): `apply_frame` takes the already-collected,
stripped, non-empty frame lines and mutates a TuiState. Organized as a `Protocol`
object so cross-module method calls compile to direct JS (no `@jac/runtime` RPC).

Frame grammar (see ai_tui/PROTOCOL.md): KEY:VALUE lines, a leading
TYPE:full|delta|hb, EV:<id>:<kind>:<node>:<text_escaped>, terminated by `---`.
"""

import from .state { TuiState }

obj:pub Protocol {
    # Reverse the control-plane text escaping: "\\n" -> newline, "\\\\" -> "\\".
    def unescape(s: str) -> str {
        result: str = "";
        i: int = 0;
        slen = len(s);
        while i < slen {
            c = s[i];
            if c == "\\" and i + 1 < slen {
                nc = s[i + 1];
                if nc == "n" {
                    result = result + "\n";
                    i = i + 2;
                    continue;
                }
                if nc == "\\" {
                    result = result + "\\";
                    i = i + 2;
                    continue;
                }
            }
            result = result + c;
            i = i + 1;
        }
        return result;
    }

    # Parse an EV value `id:kind:node:text_escaped` (split on the first three
    # colons only; text may contain colons) and upsert it by id.
    def parse_ev(state: TuiState, val: str) -> None {
        i1 = val.find(":");
        if i1 < 0 {
            return;
        }
        id_str = val[:i1];
        rest1 = val[i1 + 1:];

        i2 = rest1.find(":");
        if i2 < 0 {
            return;
        }
        kind = rest1[:i2];
        rest2 = rest1[i2 + 1:];

        i3 = rest2.find(":");
        if i3 < 0 {
            return;
        }
        node_name = rest2[:i3];
        text_esc = rest2[i3 + 1:];
        text = self.unescape(text_esc);

        # int() of non-numeric is NaN in JS (no throw, unlike NA); guard to 0 to
        # match the NA default. ("" -> 0 already, matching Python int("") raising
        # is irrelevant since the bus only emits integer ids.)
        ev_id: int = int(id_str);
        if ev_id != ev_id {
            ev_id = 0;
        }

        state.upsert_event(ev_id, kind, text, node_name);
    }

    def apply_line(state: TuiState, key: str, val: str) {
        if key == "STATUS" {
            state.status = val;
        }
        if key == "ACTIVE" {
            state.active = val;
        }
        if key == "MODEL" {
            state.model_name = val;
        }
        if key == "NEEDS_KEY" {
            state.needs_key = val == "1";
        }
        if key == "KEY_ENV" {
            state.key_env = val;
        }
        if key == "EV" {
            self.parse_ev(state, val);
        }
    }

    # Apply one frame's worth of pre-stripped, non-empty lines (the `---`
    # terminator already consumed by the caller). A `full` frame resets the
    # transcript first; `hb` is a no-op; `delta`/unknown just apply each line.
    def apply_frame(state: TuiState, lines: list[str]) -> None {
        if len(lines) == 0 {
            return;
        }

        frame_type: str = "";
        for line in lines {
            if line.startswith("TYPE:") {
                frame_type = line[5:];
                break;
            }
        }

        if frame_type == "hb" {
            return;
        }

        if frame_type == "full" {
            state.reset_events();
        }

        for line in lines {
            if line.startswith("TYPE:") {
                continue;
            }
            idx = line.find(":");
            if idx < 0 {
                continue;
            }
            key = line[:idx];
            val = line[idx + 1:];
            self.apply_line(state, key, val);
        }
    }
}
