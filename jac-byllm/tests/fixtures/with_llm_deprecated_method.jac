import from byllm.lib { MockLLM }

glob llm = MockLLM(model_name="mockllm", config={"outputs": ["test output"]});

def simple_tool() -> str {
    print("tool output");
}

def simple_task(query: str) -> str by llm(method="ReAct", tools=[simple_tool]);

with entry {
    print(simple_task("hello"));
}
