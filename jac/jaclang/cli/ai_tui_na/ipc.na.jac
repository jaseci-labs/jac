import from .state { TuiState, EventKind, TuiStatus }
import from .ipc_schema {
    FIELD_TYPE,
    FIELD_STATUS,
    FIELD_ACTIVE,
    FIELD_MODEL,
    FIELD_NEEDS_KEY,
    FIELD_KEY_ENV,
    FIELD_LEN,
    FIELD_EV,
    FIELD_EVA,
    FTYPE_FULL,
    FTYPE_HB,
    FRAME_SEP
}

def parse_event_kind(s: str) -> EventKind {
    if s == "user" {
        return EventKind.USER;
    }
    if s == "answer" {
        return EventKind.ANSWER;
    }
    if s == "reasoning" {
        return EventKind.REASONING;
    }
    if s == "system" {
        return EventKind.SYSTEM;
    }
    if s == "logo" {
        return EventKind.LOGO;
    }
    if s == "error" {
        return EventKind.ERROR;
    }
    if s == "phase" {
        return EventKind.PHASE;
    }
    if s == "call" {
        return EventKind.CALL;
    }
    if s == "tool" {
        return EventKind.CALL;
    }
    if s == "tool_result" {
        return EventKind.TOOL_RESULT;
    }
    if s == "img" {
        return EventKind.IMG;
    }
    return EventKind.UNKNOWN;
}

def parse_tui_status(s: str) -> TuiStatus {
    if s == "idle" {
        return TuiStatus.IDLE;
    }
    if s == "running" {
        return TuiStatus.RUNNING;
    }
    return TuiStatus.UNKNOWN;
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
            if nc == "c" {
                result = result + ":";
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
    node_name = _unescape(rest2[:i3]);
    text_esc = rest2[i3 + 1:];
    text = _unescape(text_esc);

    ev_id: int = 0;
    try {
        ev_id = int(id_str);
    } except Exception { }

    state.upsert_event(ev_id, parse_event_kind(kind), text, node_name);
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
    if key == FIELD_EV {
        _parse_ev_val(state, val);
        return;
    }
    if key == FIELD_EVA {
        _parse_eva_val(state, val);
        return;
    }

    if key == FIELD_STATUS {
        state.status = parse_tui_status(val);
    } elif key == FIELD_ACTIVE {
        state.active = val;
    } elif key == FIELD_MODEL {
        state.model_name = val;
    } elif key == FIELD_NEEDS_KEY {
        state.needs_key = val == "1";
    } elif key == FIELD_KEY_ENV {
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
        if line == FRAME_SEP {
            continue;
        }
        colon_at = line.find(":");
        if colon_at >= 0 and line[:colon_at] == FIELD_LEN {
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
        if colon_at >= 0 and line[:colon_at] == FIELD_TYPE {
            frame_type = line[colon_at + 1:];
            break;
        }
    }

    if frame_type == FTYPE_HB {
        return True;
    }

    if frame_type == FTYPE_FULL {
        state.reset_events();
    }

    for line in lines {
        colon_at = line.find(":");
        if colon_at < 0 {
            continue;
        }
        key = line[:colon_at];
        if key == FIELD_TYPE {
            continue;
        }
        val = line[colon_at + 1:];
        ipc_apply_line(state, key, val);
    }

    return True;
}
