"""A `-> str` agent whose model skips finish_tool and answers in plain text
must deliver that terminal text on the `chunk` channel, not leave it as
`thought`-only."""
import from jaclang.byllm.lib { MockLLM }

# A tool is offered (so we enter the ReAct loop), but the model never calls it -
# it answers directly in plain text, skipping finish_tool.
def get_weather(city: str) -> str {
    return f"The weather in {city} is sunny, 25°C.";
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": ["It's sunny in London, about 25°C."]},
);

def answer(question: str) -> str by llm(
    tools=[get_weather], stream=True, logging=True
);

with entry {
    chunk_text = "";
    for event in answer("What is the weather in London?") {
        if event.event_type == "chunk" {
            chunk_text += event.data.get("content", "");
        }
    }
    # The final answer now reaches the `chunk` channel (was empty before the fix).
    assert "sunny in London" in chunk_text , f"answer should be on chunk, got: {chunk_text!r}";
    print("STR_SKIP_FINISH_CHUNK_PASS");
}
