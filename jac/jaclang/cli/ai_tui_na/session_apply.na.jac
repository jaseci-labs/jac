"""Apply typed session mutations / snapshots onto TuiState (Phase 4)."""

import from .state { TuiState, EventKind }
import from .ipc { parse_tui_status }
import from .bridge_schema {
    as_str,
    as_int,
    MUT_SNAPSHOT_REQUIRED,
    MUT_MESSAGE_START,
    MUT_MESSAGE_UPDATE,
    MUT_MESSAGE_END,
    MUT_STATUS,
    MUT_DIAGNOSTIC,
    MUT_AGENT_SETTLED,
    MUT_AGENT_END,
    MUT_AGENT_START
}


def _msg_id(raw: any) -> int {
    return as_int(raw, 1);
}


def _text_of(m: dict[str, any]) -> str {
    t: str = as_str(m.get("text", ""));
    if t {
        return t;
    }
    return as_str(m.get("diagnostic", ""));
}


def apply_mutation(state: TuiState, m: dict[str, any]) {
    kind: str = as_str(m.get("kind", ""));
    if kind == MUT_STATUS {
        life: str = as_str(m.get("lifecycle", ""));
        if life {
            state.status = parse_tui_status(life);
            state.mark_layout_dirty();
        }
        return;
    }
    if kind == MUT_AGENT_START {
        state.status = parse_tui_status("running");
        state.mark_layout_dirty();
        return;
    }
    if kind == MUT_AGENT_END or kind == MUT_AGENT_SETTLED {
        life2: str = as_str(m.get("lifecycle", "idle"));
        if not life2 {
            life2 = "idle";
        }
        state.status = parse_tui_status(life2);
        state.mark_layout_dirty();
        return;
    }
    if kind == MUT_MESSAGE_START {
        op: str = as_str(m.get("op", ""));
        text = _text_of(m);
        ek = EventKind.ANSWER;
        if op == "user" {
            ek = EventKind.USER;
        }
        state.upsert_event(_msg_id(m.get("message_id", "1")), ek, text, "session");
        return;
    }
    if kind == MUT_MESSAGE_UPDATE {
        mid = _msg_id(m.get("message_id", "1"));
        text = _text_of(m);
        op2: str = as_str(m.get("op", ""));
        if op2 == "text_append" or op2 == "thinking_append" {
            state.append_to_event(mid, text);
        } else {
            state.upsert_event(mid, EventKind.ANSWER, text, "session");
        }
        return;
    }
    if kind == MUT_MESSAGE_END {
        return;
    }
    if kind == MUT_DIAGNOSTIC {
        detail = _text_of(m);
        if not detail {
            detail = "diagnostic";
        }
        state.upsert_event(-103, EventKind.ERROR, detail, "host");
        return;
    }
    if kind == MUT_SNAPSHOT_REQUIRED {
        state.mark_layout_dirty();
        return;
    }
}


def apply_batch(state: TuiState, batch: dict[str, any]) -> bool {
    muts = batch.get("mutations", []);
    if not isinstance(muts, list) {
        return False;
    }
    need_snap = False;
    for item in muts {
        if not isinstance(item, dict) {
            continue;
        }
        m: dict[str, any] = item;
        if as_str(m.get("kind", "")) == MUT_SNAPSHOT_REQUIRED {
            need_snap = True;
        }
        apply_mutation(state, m);
    }
    return need_snap;
}


def apply_snapshot(state: TuiState, snap: dict[str, any]) {
    state.reset_events();
    life: str = as_str(snap.get("lifecycle", "idle"));
    state.status = parse_tui_status(life);
    model: str = as_str(snap.get("model_name", ""));
    if model {
        state.model_name = model;
    }
    active: str = as_str(snap.get("active", ""));
    if active {
        state.active = active;
    }
    msgs = snap.get("messages", []);
    if not isinstance(msgs, list) {
        state.mark_layout_dirty();
        return;
    }
    for msg_any in msgs {
        if not isinstance(msg_any, dict) {
            continue;
        }
        msg: dict[str, any] = msg_any;
        mid = _msg_id(msg.get("id", "1"));
        role: str = as_str(msg.get("role", "assistant"));
        ek = EventKind.USER if role == "user" else EventKind.ANSWER;
        parts = msg.get("parts", []);
        text_parts: list[str] = [];
        if isinstance(parts, list) {
            for p_any in parts {
                if isinstance(p_any, dict) {
                    p: dict[str, any] = p_any;
                    t: str = as_str(p.get("text", ""));
                    if t {
                        text_parts.append(t);
                    }
                }
            }
        }
        state.upsert_event(mid, ek, "".join(text_parts), "session");
    }
    state.mark_layout_dirty();
}
