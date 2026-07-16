import from jaclang.cli.ai_tui.bridge_schema { LIFE_IDLE }


obj CommandError {
    has code: str = "",
        message: str = "",
        retryable: bool = False;
}


obj CommandReceipt {
    has accepted: bool = False,
        disposition: str = "rejected",
        command_id: str = "",
        prompt_id: str = "",
        error: CommandError = CommandError();
}


obj SessionCommand {
    has kind: str = "",
        command_id: str = "",
        payload: dict[str, any] = {};
}


obj DisposeResult {
    has ok: bool = True,
        timed_out: bool = False,
        reason: str = "",
        joined_workers: int = 0;
}


obj Subscription {
    has id: str = "",
        active: bool = True;
}


obj SessionTarget {
    has cwd: str = "",
        session_id: str = "",
        mode: str = "new";
}


obj ReplacementResult {
    has ok: bool = False,
        epoch: int = 0,
        session_id: str = "",
        error: str = "";
}


obj SessionEntry {
    has id: str = "",
        kind: str = "",
        text: str = "",
        parent_id: str = "",
        payload: dict[str, any] = {};
}


obj SessionMutation {
    has kind: str = "",
        text: str = "",
        parent_id: str = "",
        payload: dict[str, any] = {};
}


obj SessionQuery {
    has leaf_only: bool = True,
        limit: int = 0;
}


obj SessionView {
    has leaf_id: str = "",
        entries: list[SessionEntry] = [];
}


obj SessionContext {
    has cwd: str = "",
        leaf_id: str = "",
        messages: list[dict[str, any]] = [];
}


obj SessionSnapshot {
    has session_id: str = "",
        cwd: str = "",
        lifecycle: str = LIFE_IDLE,
        model_name: str = "",
        settled: bool = True;
}


obj RuntimeSnapshot {
    has epoch: int = 0,
        cwd: str = "",
        session_id: str = "",
        lifecycle: str = LIFE_IDLE,
        model_name: str = "";
}


obj StartResult {
    has ok: bool = False,
        session_id: str = "",
        epoch: int = 0,
        error: str = "";
}


obj MessagePart {
    has id: str = "",
        part_type: str = "text",
        text: str = "",
        tool_name: str = "",
        tool_args: str = "",
        image_ref: str = "";
}


obj Message {
    has id: str = "",
        role: str = "assistant",
        created_at: str = "",
        parts: list[MessagePart] = [];
}


obj UiMutation {
    has kind: str = "",
        seq: int = 0,
        epoch: int = 0,
        message_id: str = "",
        part_id: str = "",
        op: str = "",
        text: str = "",
        lifecycle: str = "",
        will_retry: bool = False,
        diagnostic: str = "",
        payload: dict[str, any] = {};
}


obj SessionEventBatch {
    has epoch: int = 0,
        first_seq: int = 0,
        last_seq: int = 0,
        mutations: list[UiMutation] = [];
}


obj UiSnapshot {
    has epoch: int = 0,
        base_seq: int = 0,
        lifecycle: str = LIFE_IDLE,
        model_name: str = "",
        active: str = "",
        messages: list[Message] = [];
}


obj ProjectedState {
    has epoch: int = 0,
        next_seq: int = 1,
        lifecycle: str = LIFE_IDLE,
        model_name: str = "",
        active: str = "",
        messages: list[Message] = [],
        settled_emitted: bool = False;

    def snapshot -> UiSnapshot {
        return UiSnapshot(
            epoch=self.epoch,
            base_seq=self.next_seq - 1,
            lifecycle=self.lifecycle,
            model_name=self.model_name,
            active=self.active,
            messages=self._copy_messages()
        );
    }

    def _copy_messages -> list[Message] {
        out: list[Message] = [];
        for m in self.messages {
            parts: list[MessagePart] = [];
            for p in m.parts {
                parts.append(
                    MessagePart(
                        id=p.id,
                        part_type=p.part_type,
                        text=p.text,
                        tool_name=p.tool_name,
                        tool_args=p.tool_args,
                        image_ref=p.image_ref
                    )
                );
            }
            out.append(
                Message(id=m.id, role=m.role, created_at=m.created_at, parts=parts)
            );
        }
        return out;
    }
}


def mutation_dict(m: UiMutation) -> dict[str, any] {
    return {
        "kind": m.kind,
        "seq": m.seq,
        "epoch": m.epoch,
        "message_id": m.message_id,
        "part_id": m.part_id,
        "op": m.op,
        "text": m.text,
        "lifecycle": m.lifecycle,
        "will_retry": m.will_retry,
        "diagnostic": m.diagnostic,
        "payload": m.payload
    };
}


def mutation_from_dict(d: dict[str, any]) -> UiMutation {
    raw_payload = d.get("payload", {});
    payload: dict[str, any] = raw_payload if isinstance(raw_payload, dict) else {};
    return UiMutation(
        kind=str(d.get("kind", "")),
        seq=int(d.get("seq", 0)),
        epoch=int(d.get("epoch", 0)),
        message_id=str(d.get("message_id", "")),
        part_id=str(d.get("part_id", "")),
        op=str(d.get("op", "")),
        text=str(d.get("text", "")),
        lifecycle=str(d.get("lifecycle", "")),
        will_retry=bool(d.get("will_retry", False)),
        diagnostic=str(d.get("diagnostic", "")),
        payload=payload
    );
}
