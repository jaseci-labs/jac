import from byllm.lib { MockLLM, MockToolCall }

def get_live_wind_speed(city: str) -> str {
    return f"The current wind speed in {city} is about 18-22 km/h.";
}

sem get_live_wind_speed= """Get the current wind speed of a given city.""";

def get_wind_speed_report(city: str) -> str by MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            MockToolCall(tool=get_live_wind_speed, args={"city": "Puttalam"}),
            "The current wind speed in Puttalam is about 18-22 km/h."
        ],
        "show_params": True,
        "verbose": True
    },
)(
    tools=[get_live_wind_speed]
);

glob result = get_wind_speed_report("Puttalam");

with entry {
    print(result);
}
