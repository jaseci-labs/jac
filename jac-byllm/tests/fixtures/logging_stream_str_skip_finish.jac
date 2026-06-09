"""Test logging=True streaming for a `-> str` agent when the model skips
finish_tool and answers with plain text (the gpt-4o failure mode).

"""
import from byllm.lib { MockLLM }
import from byllm.types { StreamEvent }

# A tool is offered (so finish_tool is auto-injected and we enter the ReAct
# loop), but the model never calls it.
def get_weather(city: str) -> str {
    return f"The weather in {city} is sunny, 25°C.";
}

# The model answers directly in plain text - no tool call, no finish_tool.
glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            "It's sunny in London right now, about 25°C. Enjoy!"
        ]
    },
);

"""Answer the user's question."""
def answer(question: str) -> str by llm(
    tools=[get_weather], stream=True, logging=True
);

glob result = answer("What is the weather in London?");

with entry {
    events = [];
    for event in result {
        assert isinstance(event, StreamEvent) , f"Expected StreamEvent, got {type(event)}";
        events.append(event);
    }
    event_types = [e.event_type for e in events];

    # The model called no tool, so there must be no tool_call events.
    tool_call_events = [e for e in events if e.event_type == "tool_call"];
    assert len(tool_call_events) == 0 , f"No tool should be called, got: {event_types}";

    # The terminal plain-text answer must be delivered on the `chunk` channel
    # (the core of Option A). Before the fix this list was empty.
    chunk_events = [e for e in events if e.event_type == "chunk"];
    assert len(chunk_events) > 0 , f"Final answer should be delivered as chunk, got: {event_types}";

    full_content = "";
    for e in chunk_events {
        full_content += e.data.get("content", "");
    }
    assert "sunny in London" in full_content , f"chunk should carry the answer, got: {full_content!r}";

    # steps_done is still emitted, and it precedes the chunk(s).
    steps_done_events = [e for e in events if e.event_type == "steps_done"];
    assert len(steps_done_events) >= 1 , f"Should have steps_done event, got: {event_types}";
    first_chunk_idx = event_types.index("chunk");
    first_steps_done_idx = event_types.index("steps_done");
    assert first_steps_done_idx < first_chunk_idx , f"steps_done should precede chunk, got: {event_types}";

    # usage is still the final event with aggregated counts.
    usage_events = [e for e in events if e.event_type == "usage"];
    assert len(usage_events) == 1 , f"Should have exactly 1 usage event, got: {len(usage_events)}";
    assert usage_events[0] == events[-1] , "Usage event should be the last event";

    print("STR_SKIP_FINISH_CHUNK_PASS");
}
