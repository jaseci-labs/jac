"""Test logging=True streaming with no tools (simple path)."""
import from byllm.lib { MockLLM }
import from byllm.types { StreamEvent }

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 "Jac is a programming language designed for the AI era.",

             ]
         },
     );

"""Explain what Jac is in one sentence."""
def explain_jac(topic: str) -> str by llm(stream=True, logging=True);

glob result = explain_jac("Jac language");

with entry {
    events = [];
    for event in result {
        assert isinstance(event, StreamEvent) , f"Expected StreamEvent, got {type(event)}";
        events.append(event);
    }

    # All events should be chunk type (no tools = no reasoning steps)
    chunk_events = [e for e in events if e.event_type == "chunk"];
    other_events = [e for e in events if e.event_type != "chunk"];

    assert len(chunk_events) > 0 , "Should have at least one chunk event";
    assert len(other_events) == 0 , f"No-tools path should only yield chunk events, got: {[e.event_type for e in other_events]}";

    # Reassemble the full content
    full_content = "";
    for e in chunk_events {
        full_content += e.data.get("content", "");
    }
    assert "Jac" in full_content , f"Content should mention Jac, got: {full_content}";
    assert "programming language" in full_content , f"Content should mention programming language, got: {full_content}";

    print("NO_TOOLS_PASS");
}
