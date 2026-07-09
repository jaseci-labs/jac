"""IPC frame parsing: host state frames -> TuiState mutations.

The host streams newline-delimited frames of `KEY:value` lines separated
by FRAME_SEP, with keys drawn from ipc_schema. Event lines pack extra
colon-separated sub-fields; their text is escaped by the sv serializer
(tui_shared _esc_text/_esc_field: backslash, newline, and — for fields
only — colon), and _unescape here is the exact inverse. Event text keeps
raw colons on the wire, so parsers must split a fixed number of times
and treat the remainder as opaque payload.
"""
import from .state { TuiState, EventKind, TuiStatus }
import from .util { parse_int_or, split_kv }
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

glob _UNESCAPE_MAP: dict[str, str] = {"n": "\n", "\\": "\\", "c": ":"};

# FROZEN: CI regex-greps `def parse_event_kind` and its `s == "..."`
# literal-comparison if-chain body shape — do not rewrite this def as a
# match statement or dict lookup, and do not reorder its branches.
"""Map a wire event-kind token to its EventKind ("tool" aliases CALL)."""
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

"""Map a wire status token to its TuiStatus member."""
def parse_tui_status(s: str) -> TuiStatus {
    if s == "idle" {
        return TuiStatus.IDLE;
    }
    if s == "running" {
        return TuiStatus.RUNNING;
    }
    return TuiStatus.UNKNOWN;
}

"""Decode wire escaping — the exact inverse of sv _esc_text/_esc_field.

Recognized pairs are backslash-n (newline), doubled backslash, and
backslash-c (colon); any other backslash, including one ending the
string, passes through unchanged.
"""
def _unescape(s: str) -> str {
    parts: list[str] = [];
    slen = len(s);
    i: int = 0;
    while i < slen {
        c = s[i];
        if c == "\\" and i + 1 < slen {
            decoded = _UNESCAPE_MAP.get(s[i + 1], "");
            if decoded {
                parts.append(decoded);
                i += 2;
                continue;
            }
        }
        parts.append(c);
        i += 1;
    }
    return "".join(parts);
}

"""Apply an EV value `id:kind:node:text` — upsert the event.

node and text are wire-escaped; text may contain raw colons, so only
the first three separators split fields. Malformed values are ignored.
"""
def _parse_ev_val(state: TuiState, val: str) {
    if ":" not in val {
        return;
    }
    (id_str, rest) = split_kv(val, ":");
    if ":" not in rest {
        return;
    }
    (kind, rest2) = split_kv(rest, ":");
    if ":" not in rest2 {
        return;
    }
    (node_esc, text_esc) = split_kv(rest2, ":");
    state.upsert_event(
        parse_int_or(id_str, 0),
        parse_event_kind(kind),
        _unescape(text_esc),
        _unescape(node_esc)
    );
}

"""Apply an EVA value `id:delta` — append the wire-escaped delta."""
def _parse_eva_val(state: TuiState, val: str) {
    if ":" not in val {
        return;
    }
    (id_str, delta_esc) = split_kv(val, ":");
    state.append_to_event(parse_int_or(id_str, 0), _unescape(delta_esc));
}

"""Apply one `key:val` frame line; scalar field updates mark state dirty."""
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

"""Parse one frame blob into state changes; always True (reader contract).

Each line is split once into (key, val); separators, length prefixes,
and non-KV noise are dropped. A heartbeat frame is a no-op; a full
frame resets events before the lines are applied in wire order.
"""
def ipc_parse_frame(state: TuiState, blob: str) -> bool {
    pairs: list[tuple[str, str]] = [];
    for raw in blob.split("\n") {
        line = raw.strip();
        if not line or line == FRAME_SEP or ":" not in line {
            continue;
        }
        (key, val) = split_kv(line, ":");
        if key != FIELD_LEN {
            pairs.append((key, val));
        }
    }
    if not pairs {
        return True;
    }

    frame_type: str = "";
    for pair in pairs {
        if pair[0] == FIELD_TYPE {
            frame_type = pair[1];
            break;
        }
    }
    if frame_type == FTYPE_HB {
        return True;
    }
    if frame_type == FTYPE_FULL {
        state.reset_events();
    }

    for pair in pairs {
        if pair[0] != FIELD_TYPE {
            ipc_apply_line(state, pair[0], pair[1]);
        }
    }
    return True;
}
