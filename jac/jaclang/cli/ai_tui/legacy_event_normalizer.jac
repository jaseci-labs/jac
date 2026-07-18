import from jaclang.cli.ai_tui.session_models { UiMutation }
import from jaclang.cli.ai_tui.bridge_schema {
    LIFE_IDLE,
    LIFE_RUNNING,
    LIFE_STOPPING,
    MUT_DIAGNOSTIC,
    MUT_MESSAGE_END,
    MUT_MESSAGE_START,
    MUT_MESSAGE_UPDATE,
    MUT_STATUS,
    MUT_TOOL_END,
    MUT_TOOL_START,
    MUT_TOOL_UPDATE
}


def normalize_status(raw: str) -> str {
    s = raw.strip().lower();
    if s == "idle" {
        return LIFE_IDLE;
    }
    if s == "running" {
        return LIFE_RUNNING;
    }
    if s == "stopping" {
        return LIFE_STOPPING;
    }
    if s in (
        LIFE_IDLE,
        LIFE_RUNNING,
        LIFE_STOPPING,
        "starting",
        "quiescing",
        "disposed",
        "failed"
    ) {
        return s;
    }
    raise ValueError(f"unknown lifecycle status: {raw!r}");
}


def normalize_event_kind(kind: str) -> str {
    k = kind.strip().lower();
    mapping: dict[str, str] = {
        "user": MUT_MESSAGE_START,
        "answer": MUT_MESSAGE_UPDATE,
        "reasoning": MUT_MESSAGE_UPDATE,
        "system": MUT_DIAGNOSTIC,
        "logo": MUT_DIAGNOSTIC,
        "error": MUT_DIAGNOSTIC,
        "phase": MUT_STATUS,
        "call": MUT_TOOL_START,
        "tool": MUT_TOOL_START,
        "tool_result": MUT_TOOL_END,
        "img": MUT_MESSAGE_UPDATE
    };
    if k not in mapping {
        raise ValueError(f"unknown legacy event kind: {kind!r}");
    }
    return mapping[k];
}


def legacy_frame_to_mutations(
    frame: dict[str, any], epoch: int = 0, seq_start: int = 1
) -> list[UiMutation] {
    out: list[UiMutation] = [];
    seq = seq_start;

    if "status" in frame {
        life = normalize_status(str(frame.get("status", "")));
        out.append(UiMutation(kind=MUT_STATUS, seq=seq, epoch=epoch, lifecycle=life));
        seq += 1;
    }

    events = frame.get("events");
    if isinstance(events, list) {
        for ev in events {
            if isinstance(ev, dict) {
                pair = _legacy_ev(ev, epoch, seq, True);
                out.append(pair[0]);
                seq = pair[1];
            }
        }
    }

    ev = frame.get("ev");
    if isinstance(ev, dict) {
        pair = _legacy_ev(ev, epoch, seq, True);
        out.append(pair[0]);
        seq = pair[1];
    }

    eva = frame.get("eva");
    if isinstance(eva, dict) {
        pair = _legacy_ev(eva, epoch, seq, False);
        out.append(pair[0]);
        seq = pair[1];
    }

    return out;
}


def _legacy_ev(
    ev: dict[str, any], epoch: int, seq: int, full: bool
) -> tuple[UiMutation, int] {
    kind_raw = str(ev.get("kind", ""));
    mut_kind = normalize_event_kind(kind_raw);
    text = str(ev.get("text", ""));
    ev_id = str(ev.get("id", ""));
    op = "replace_partial" if full else "text_append";
    if kind_raw in ("answer", "reasoning") and not full {
        op = "thinking_append" if kind_raw == "reasoning" else "text_append";
    }
    if mut_kind == MUT_MESSAGE_START and kind_raw == "user" {
        m = UiMutation(
            kind=MUT_MESSAGE_START,
            seq=seq,
            epoch=epoch,
            message_id=ev_id,
            part_id=ev_id + ":text",
            op="replace_partial",
            text=text,
            payload={"role": "user", "node": str(ev.get("node", ""))}
        );
        return (m, seq + 1);
    }
    if mut_kind == MUT_TOOL_START {
        m = UiMutation(
            kind=MUT_TOOL_START,
            seq=seq,
            epoch=epoch,
            message_id=ev_id,
            text=text,
            payload={"node": str(ev.get("node", "")), "legacy_kind": kind_raw}
        );
        return (m, seq + 1);
    }
    if mut_kind == MUT_TOOL_END {
        m = UiMutation(
            kind=MUT_TOOL_END,
            seq=seq,
            epoch=epoch,
            message_id=ev_id,
            text=text,
            payload={"node": str(ev.get("node", ""))}
        );
        return (m, seq + 1);
    }
    m = UiMutation(
        kind=mut_kind,
        seq=seq,
        epoch=epoch,
        message_id=ev_id,
        part_id=ev_id + ":text",
        op=op,
        text=text,
        diagnostic=text if mut_kind == MUT_DIAGNOSTIC else "",
        payload={"legacy_kind": kind_raw, "node": str(ev.get("node", ""))}
    );
    return (m, seq + 1);
}
