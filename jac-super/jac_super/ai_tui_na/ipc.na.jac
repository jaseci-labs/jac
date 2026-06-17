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

def ipc_apply_line(state: TuiState, key: str, val: str) {
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
        _parse_ev_val(state, val);
    }
}

def ipc_read_frame_v2(state: TuiState) -> bool {
    lines: list[str] = [];

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

    return True;
}

def ipc_send_cmd(fd: int, cmd: str) {
    tty_write(fd, cmd + "\n");
}
