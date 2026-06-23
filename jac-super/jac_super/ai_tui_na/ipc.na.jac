"""IPC frame parser: converts text lines from the Python bridge to TuiState."""

import from .state { TuiState }

import from .libc_tty { tty_read_line, tty_write }

def _unescape(s: str) -> str {
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

def _parse_ev_val(state: TuiState, val: str) -> None {
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
    text = _unescape(text_esc);

    ev_id: int = 0;
    try {
        ev_id = int(id_str);
    } except Exception { }

    state.upsert_event(ev_id, kind, text, node_name);
}

def _parse_eva_val(state: TuiState, val: str) -> None {
    # EVA:<id>:<escaped_delta> — append delta to existing streaming event text.
    i1 = val.find(":");
    if i1 < 0 {
        return;
    }
    id_str = val[:i1];
    delta_esc = val[i1 + 1:];
    delta = _unescape(delta_esc);

    ev_id: int = 0;
    try {
        ev_id = int(id_str);
    } except Exception { }

    state.append_to_event(ev_id, delta);
}

def ipc_apply_line(state: TuiState, key: str, val: str) {
    # EV/EVA mutate the transcript through TuiState, which marks itself dirty
    # (mark_layout_dirty), so they own their own repaint.
    if key == "EV" {
        _parse_ev_val(state, val);
        return;
    }
    if key == "EVA" {
        _parse_eva_val(state, val);
        return;
    }

    # The rest are scalar status fields painted in the header/footer; a change to
    # any of them must repaint. Marking dirty once here -- where the field is
    # actually written -- follows the same "owner sets the flag" rule as the
    # input/scroll handlers and the transcript mutators, so the render gate can
    # stay a plain `dirty` check (no special-casing in ipc_parse_frame).
    if key == "STATUS" {
        state.status = val;
    } elif key == "ACTIVE" {
        state.active = val;
    } elif key == "MODEL" {
        state.model_name = val;
    } elif key == "NEEDS_KEY" {
        state.needs_key = val == "1";
    } elif key == "KEY_ENV" {
        state.key_env = val;
    } else {
        return;
    }
    state.dirty = True;
}

# Parse one already-assembled frame `blob` (KEY:VALUE lines joined by "\n", the
# trailing "---" optional) into `state`. Transport-agnostic: the subprocess path
# (ipc_read_frame_v2) builds the blob from the pipe; the in-process host passes
# the exact same text from tui_apply_frame. Always returns True (an empty/hb
# frame is a no-op); EOF detection stays in the pipe reader. Reuses _unescape /
# _parse_ev_val / ipc_apply_line unchanged.
def ipc_parse_frame(state: TuiState, blob: str) -> bool {
    lines: list[str] = [];
    for raw in blob.split("\n") {
        line = raw.strip();
        if line == "---" {
            continue;
        }
        if len(line) > 0 {
            lines.append(line);
        }
    }

    if len(lines) == 0 {
        return True;
    }

    frame_type: str = "";
    for line in lines {
        if line.startswith("TYPE:") {
            frame_type = line[5:];
            break;
        }
    }

    if frame_type == "hb" {
        return True;
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
        ipc_apply_line(state, key, val);
    }

    # No blanket dirty set here: each ipc_apply_line either writes a status field
    # (and marks dirty) or delegates to a TuiState mutator (which marks dirty via
    # mark_layout_dirty). A frame that changes nothing on screen leaves the gate
    # alone instead of forcing a needless repaint.
    return True;
}

def ipc_read_frame_v2(state: TuiState) -> bool {
    blob: str = "";

    while True {
        raw = tty_read_line();
        if len(raw) == 0 {
            return False;
        }
        line = raw.strip();
        if line == "---" {
            break;
        }
        if len(line) > 0 {
            if len(blob) > 0 {
                blob = blob + "\n";
            }
            blob = blob + line;
        }
    }

    return ipc_parse_frame(state, blob);
}

# In-process command sink. Native enqueues command strings here when there is no
# IPC pipe fd; the sv host drains them via tui_next_command() (Phase 1). Must be
# an `obj` glob with list/cursor FIELDS -- bare scalar globs don't persist writes
# across :pub calls in NA codegen (jaseci-labs/jaseci#6816).
obj CmdQueue {
    has items: list[str] = [],
        cursor: int = 0;

    def push(cmd: str) {
        self.items.append(cmd);
    }

    # FIFO drain: next queued command, "" when empty. Compacts on drain so the
    # backing list does not grow unbounded across the session.
    def pop_next -> str {
        if self.cursor >= len(self.items) {
            self.items = [];
            self.cursor = 0;
            return "";
        }
        cmd = self.items[self.cursor];
        self.cursor = self.cursor + 1;
        return cmd;
    }
}

# Pure object construction is safe in glob init (no libc).
glob cmd_queue: CmdQueue = CmdQueue();

# fd >= 0: write the command to the pipe (subprocess transport). fd < 0: enqueue
# into cmd_queue for the in-process host to pull (same command grammar).
def ipc_send_cmd(fd: int, cmd: str) {
    if fd < 0 {
        cmd_queue.push(cmd);
        return;
    }
    tty_write(fd, cmd + "\n");
}

# Pull the next queued in-process command (FIFO), "" when drained. The sv host
# calls this in a loop after tui_handle_key (plan §5/§8) and feeds each line to
# _dispatch_cmd -- the exact SEND:/STOP/RESET/QUIT/APPLY: grammar as the pipe.
def ipc_next_command -> str {
    return cmd_queue.pop_next();
}
