import from jaclang.cli.ai_tui.session_models {
    Message,
    MessagePart,
    ProjectedState,
    UiMutation,
    UiSnapshot
}
import from jaclang.cli.ai_tui.bridge_schema {
    LIFE_IDLE,
    LIFE_RUNNING,
    LIFE_STOPPING,
    MUT_AGENT_END,
    MUT_AGENT_SETTLED,
    MUT_AGENT_START,
    MUT_DIAGNOSTIC,
    MUT_MESSAGE_END,
    MUT_MESSAGE_START,
    MUT_MESSAGE_UPDATE,
    MUT_RUNTIME_REPLACED,
    MUT_STATUS,
    MUT_TOOL_END,
    MUT_TOOL_START,
    MUT_TOOL_UPDATE
}


obj UiEventProjector {
    has state: ProjectedState = ProjectedState();

    def snapshot -> UiSnapshot {
        return self.state.snapshot();
    }

    def apply(event: UiMutation) -> list[UiMutation] {
        st = self.state;
        if event.epoch != 0
        and event.epoch != st.epoch
        and event.kind != MUT_RUNTIME_REPLACED {
            raise ValueError(f"epoch mismatch: event={event.epoch} state={st.epoch}");
        }

        if event.kind == MUT_RUNTIME_REPLACED {
            st.epoch = event.epoch if event.epoch != 0 else st.epoch + 1;
            st.next_seq = 1;
            st.messages = [];
            st.lifecycle = LIFE_IDLE;
            st.active = "";
            st.settled_emitted = False;
            if event.lifecycle {
                st.lifecycle = event.lifecycle;
            }
            out = UiMutation(
                kind=MUT_RUNTIME_REPLACED, seq=0, epoch=st.epoch, lifecycle=st.lifecycle
            );
            return [out];
        }

        if event.seq != 0 and event.seq != st.next_seq {
            raise ValueError(f"sequence gap: expected {st.next_seq}, got {event.seq}");
        }

        assigned = event.seq if event.seq != 0 else st.next_seq;
        st.next_seq = assigned + 1;
        emitted = UiMutation(
            kind=event.kind,
            seq=assigned,
            epoch=st.epoch,
            message_id=event.message_id,
            part_id=event.part_id,
            op=event.op,
            text=event.text,
            lifecycle=event.lifecycle,
            will_retry=event.will_retry,
            diagnostic=event.diagnostic,
            payload=event.payload
        );

        if event.kind == MUT_STATUS or event.kind == MUT_AGENT_START {
            if event.lifecycle {
                st.lifecycle = event.lifecycle;
            } elif event.kind == MUT_AGENT_START {
                st.lifecycle = LIFE_RUNNING;
                st.settled_emitted = False;
            }
        } elif event.kind == MUT_AGENT_END {
            if not event.will_retry {
                st.lifecycle = LIFE_STOPPING
                    if st.lifecycle == LIFE_RUNNING
                    else st.lifecycle;
            }
        } elif event.kind == MUT_AGENT_SETTLED {
            if st.settled_emitted {
                raise ValueError("agent_settled emitted more than once");
            }
            st.settled_emitted = True;
            st.lifecycle = LIFE_IDLE;
            st.active = "";
        } elif event.kind == MUT_MESSAGE_START {
            self._message_start(emitted);
        } elif event.kind == MUT_MESSAGE_UPDATE {
            self._message_update(emitted);
        } elif event.kind == MUT_MESSAGE_END {
            self._message_end(emitted);
        } elif event.kind in (MUT_TOOL_START, MUT_TOOL_UPDATE, MUT_TOOL_END) {
            self._tool_mut(emitted);
        } elif event.kind == MUT_DIAGNOSTIC { } else {
            raise ValueError(f"unknown mutation kind: {event.kind!r}");
        }
        return [emitted];
    }

    def _find_message(message_id: str) -> Message | None {
        for m in self.state.messages {
            if m.id == message_id {
                return m;
            }
        }
        return None;
    }

    def _message_start(ev: UiMutation) {
        role = str(ev.payload.get("role", "assistant"));
        part = MessagePart(
            id=ev.part_id or ev.message_id + ":text", part_type="text", text=ev.text
        );
        existing = self._find_message(ev.message_id);
        if existing is not None {
            existing.parts = [part];
            existing.role = role;
            return;
        }
        self.state.messages.append(Message(id=ev.message_id, role=role, parts=[part]));
    }

    def _message_update(ev: UiMutation) {
        msg = self._find_message(ev.message_id);
        if msg is None {
            part = MessagePart(
                id=ev.part_id or ev.message_id + ":text",
                part_type="thinking" if ev.op == "thinking_append" else "text",
                text=ev.text
            );
            role = "assistant";
            self.state.messages.append(
                Message(id=ev.message_id, role=role, parts=[part])
            );
            return;
        }
        target: MessagePart | None = None;
        for p in msg.parts {
            if p.id == ev.part_id
            or (not ev.part_id and p.part_type in ("text", "thinking")) {
                target = p;
                break;
            }
        }
        if target is None {
            msg.parts.append(
                MessagePart(
                    id=ev.part_id or ev.message_id + ":text",
                    part_type="thinking" if ev.op == "thinking_append" else "text",
                    text=ev.text
                )
            );
            return;
        }
        if ev.op in ("text_append", "thinking_append") {
            target.text += ev.text;
        } else {
            target.text = ev.text;
        }
    }

    def _message_end(ev: UiMutation) {
        msg = self._find_message(ev.message_id);
        if msg is None {
            self._message_start(ev);
        }
    }

    def _tool_mut(ev: UiMutation) {
        msg = self._find_message(ev.message_id);
        part_type = "tool_call" if ev.kind != MUT_TOOL_END else "tool_result";
        part = MessagePart(
            id=ev.part_id or ev.message_id + ":" + part_type,
            part_type=part_type,
            text=ev.text,
            tool_name=str(ev.payload.get("node", ""))
        );
        if msg is None {
            self.state.messages.append(
                Message(id=ev.message_id, role="tool", parts=[part])
            );
            return;
        }
        for (i, p) in enumerate(msg.parts) {
            if p.id == part.id {
                msg.parts[i] = part;
                return;
            }
        }
        msg.parts.append(part);
    }
}
