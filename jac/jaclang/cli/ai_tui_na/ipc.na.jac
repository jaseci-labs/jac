import from .state { TuiState }
import from .ipc_schema {
    IPC_TYPE,
    IPC_STATUS,
    IPC_ACTIVE,
    IPC_MODEL,
    IPC_NEEDS_KEY,
    IPC_KEY_ENV,
    IPC_EV,
    IPC_EVA,
    IPC_LEN,
    IPC_FTYPE_FULL,
    IPC_FTYPE_HB,
    IPC_SEP
}
import from .transport { CmdQueue }
import from .libc_tty { tty_read_line }

glob _cmd_queue: CmdQueue = CmdQueue();

def ipc_send_cmd(fd: int, cmd: str) {
    _cmd_queue.send(fd, cmd);
}

def ipc_next_command -> str {
    return _cmd_queue.drain();
}

def ipc_clear_cmd_queue {
    _cmd_queue.clear();
}

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
    if key == IPC_EV {
        _parse_ev_val(state, val);
        return;
    }
    if key == IPC_EVA {
        _parse_eva_val(state, val);
        return;
    }

    if key == IPC_STATUS {
        state.status = val;
    } elif key == IPC_ACTIVE {
        state.active = val;
    } elif key == IPC_MODEL {
        state.model_name = val;
    } elif key == IPC_NEEDS_KEY {
        state.needs_key = val == "1";
    } elif key == IPC_KEY_ENV {
        state.key_env = val;
    } else {
        return;
    }
    state.dirty = True;
}

def ipc_parse_frame(state: TuiState, blob: str) -> bool {
    lines: list[str] = [];
    for raw in blob.split("\n") {
        line = raw.strip();
        if line == IPC_SEP {
            continue;
        }
        colon_at = line.find(":");
        if colon_at >= 0 and line[:colon_at] == IPC_LEN {
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
        colon_at = line.find(":");
        if colon_at >= 0 and line[:colon_at] == IPC_TYPE {
            frame_type = line[colon_at + 1:];
            break;
        }
    }

    if frame_type == IPC_FTYPE_HB {
        return True;
    }

    if frame_type == IPC_FTYPE_FULL {
        state.reset_events();
    }

    for line in lines {
        colon_at = line.find(":");
        if colon_at < 0 {
            continue;
        }
        key = line[:colon_at];
        if key == IPC_TYPE {
            continue;
        }
        val = line[colon_at + 1:];
        ipc_apply_line(state, key, val);
    }

    return True;
}

def ipc_read_frame_v2(state: TuiState) -> bool {
    raw = tty_read_line();
    if len(raw) == 0 {
        return False;
    }
    first = raw.strip();

    expected_lines: int = -1;
    colon_at = first.find(":");
    if colon_at >= 0 and first[:colon_at] == IPC_LEN {
        try {
            expected_lines = int(first[colon_at + 1:]);
        } except Exception { }
    }

    blob: str = "";

    if expected_lines >= 0 {
        n: int = 0;
        while n < expected_lines {
            raw2 = tty_read_line();
            if len(raw2) == 0 {
                return False;
            }
            line = raw2.strip();
            if len(blob) > 0 {
                blob = blob + "\n";
            }
            blob = blob + line;
            n = n + 1;
        }
        tty_read_line();
    } else {
        if first != IPC_SEP and len(first) > 0 {
            blob = first;
        }
        while True {
            raw2 = tty_read_line();
            if len(raw2) == 0 {
                return False;
            }
            line = raw2.strip();
            if line == IPC_SEP {
                break;
            }
            if len(line) > 0 {
                if len(blob) > 0 {
                    blob = blob + "\n";
                }
                blob = blob + line;
            }
        }
    }

    return ipc_parse_frame(state, blob);
}
