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

def get_wind_speed_report(city: str) -> str by llm(
    method="ReAct",
    tools=[get_live_wind_speed, get_speed_unit],
    max_react_iterations=2
);

glob llm: MockLLM = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                MockToolCall(tool=get_live_wind_speed, args={"city": "Puttalam"}),
                MockToolCall(tool=get_speed_unit, args={}),
                "FINAL_REPORT"
        ],
        "show_params": True,
        "verbose": True
    });

with entry {
    result = get_wind_speed_report("Puttalam");
    print("RESULT: " + result);
    print("WIND_TOOL_CALLS: " + str(tool_calls["wind"]));
    print("UNIT_TOOL_CALLS: " + str(tool_calls["unit"]));
}
