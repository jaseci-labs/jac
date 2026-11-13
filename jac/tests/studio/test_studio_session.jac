"""Studio sessions: saved on a root graph, resumed, forked, and replayed to an agent."""
import from tempfile { TemporaryDirectory }
import from jaclang.studio.agent_session { AgentEvent }
import from jaclang.studio.session {
    fork_session,
    load_session,
    new_session,
    transcript_of
}

test "a session resumes and forks with the conversation an agent needs" {
    with TemporaryDirectory() as tmp {
        rec = new_session(tmp, agent="jac", title="shapes");
        rec.add("user", "add a perimeter method to Circle");
        # An answer the model takes back is not saved.
        for ev in [
            AgentEvent(kind="message_chunk", data={"text": "Added Circle.ar"}),
            AgentEvent(kind="message_reset"),
            AgentEvent(kind="message_chunk", data={"text": "Added Circle.perimeter."})
        ] {
            rec.record(ev);
        }
        rec.tray = ["geo.shape.Circle"];
        rec.agent_session_id = "agent-1";
        rec.save();
        back = load_session(tmp, rec.id);
        assert back is not None;
        assert [e["role"] for e in back.entries] == ["user", "agent"];
        assert back.tray == ["geo.shape.Circle"];
        assert back.agent_session_id == "agent-1";
        child = fork_session(tmp, rec.id);
        assert child is not None and child.parent == rec.id and child.id != rec.id;
        assert child.agent_session_id == "" , "a fork starts a fresh agent conversation";
        told = transcript_of(child.entries);
        assert "User: add a perimeter method to Circle" in told;
        assert "Assistant: Added Circle.perimeter." in told
            and "Circle.ar" not in told , told;
    }
}
