"""Test logging=True streaming with ReAct tool calls."""
import from byllm.lib {  MockLLM, MockToolCall }
import from byllm.types { StreamEvent }

# Mock tool functions
def get_weather(city: str) -> str {
    return f"The weather in {city} is sunny, 25°C.";
}

def finish_tool(final_output: str) -> str {
    return final_output;
}

# Create a mock LLM that simulates ReAct: thought -> tool call -> finish
glob llm =  MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 # Iteration 1: LLM calls get_weather tool
                 MockToolCall(tool=get_weather, args={"city": "London"}),
                 # Iteration 2: LLM calls finish_tool
                 MockToolCall(
                     tool=finish_tool,
                     args={"final_output": "The weather in London is sunny, 25°C."}
                 ),
                 # Final streaming answer after finish_tool
                 "Based on the information gathered, the weather in London is currently sunny with a temperature of 25°C.",

             ]
         },
     );

"""Get the current weather for a city."""
def check_weather(question: str) -> str by llm(
    tools=[get_weather], stream=True, logging=True
);

glob result = check_weather("What is the weather in London?");

with entry {
    events = [];
    for event in result {
        assert isinstance(event, StreamEvent) , f"Expected StreamEvent, got {type(event)}";
        events.append(event);
    }

    # Collect events by type
    event_types = [e.event_type for e in events];

    # Should have tool_call events
    tool_call_events = [e for e in events if e.event_type == "tool_call"];
    assert len(tool_call_events) >= 1 , f"Should have at least 1 tool_call event, got: {event_types}";
    assert tool_call_events[0].data["tool"] == "get_weather" , "First tool call should be get_weather";

    # Should have tool_result events
    tool_result_events = [e for e in events if e.event_type == "tool_result"];
    assert len(tool_result_events) >= 1 , f"Should have at least 1 tool_result event, got: {event_types}";
    assert "sunny" in tool_result_events[0].data["result"] , "Tool result should contain weather info";

    # Should have steps_done event
    steps_done_events = [e for e in events if e.event_type == "steps_done"];
    assert len(steps_done_events) >= 1 , f"Should have steps_done event, got: {event_types}";

    # Should have chunk events (final answer)
    chunk_events = [e for e in events if e.event_type == "chunk"];
    assert len(chunk_events) > 0 , f"Should have chunk events for final answer, got: {event_types}";

    # Reassemble the final streamed content
    full_content = "";
    for e in chunk_events {
        full_content += e.data.get("content", "");
    }
    assert "London" in full_content , f"Final answer should mention London, got: {full_content}";

    # Verify event ordering: tool events come before chunks
    first_chunk_idx = event_types.index("chunk");
    last_tool_idx = len(event_types) - 1 - event_types[::-1].index("tool_result");
    assert last_tool_idx < first_chunk_idx , "Tool events should come before chunk events";

    # Should have a usage event at the very end with aggregated token counts
    usage_events = [e for e in events if e.event_type == "usage"];
    assert len(usage_events) == 1 , f"Should have exactly 1 usage event, got: {len(usage_events)}";
    assert "total" in usage_events[0].data , "Usage event should have 'total' field";
    assert "per_call" in usage_events[0].data , "Usage event should have 'per_call' field";
    assert usage_events[0] == events[-1] , "Usage event should be the last event";

    print("REACT_LOGGING_PASS");
}
