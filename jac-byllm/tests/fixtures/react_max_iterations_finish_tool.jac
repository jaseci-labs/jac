"""Test that when max_react_iterations is exceeded, a finish_tool call
from the LLM (e.g. Anthropic) is correctly handled to extract the final output.
This covers the new code path added in the bug fix for the tool calling error."""
import from byllm.lib { MockLLM, MockToolCall }

glob tool_calls = {"wind": 0, "unit": 0};

def get_live_wind_speed(city: str) -> str {
    tool_calls["wind"] += 1;
    print(f"get_live_wind_speed called for {city}");
    return f"The current wind speed in {city} is about 18-22 km/h.";
}

def get_speed_unit() -> str {
    tool_calls["unit"] += 1;
    print("get_speed_unit called");
    return "km/h";
}

# Simulates what Anthropic does: instead of returning a plain text final answer,
# it returns the answer via a finish_tool call after max iterations are exceeded.
def finish_tool(final_output: str) -> str {
    return final_output;
}

def get_wind_speed_report(city: str) -> str by llm(
    tools=[get_live_wind_speed, get_speed_unit],
    max_react_iterations=2
);

glob llm: MockLLM = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            MockToolCall(tool=get_live_wind_speed, args={"city": "Puttalam"}),
            MockToolCall(tool=get_speed_unit, args={}),
            MockToolCall(tool=finish_tool, args={"final_output": "FINAL_REPORT"}),
        ]
    }
);

with entry {
    result = get_wind_speed_report("Puttalam");
    print("RESULT: " + result);
    print("WIND_TOOL_CALLS: " + str(tool_calls["wind"]));
    print("UNIT_TOOL_CALLS: " + str(tool_calls["unit"]));
}
