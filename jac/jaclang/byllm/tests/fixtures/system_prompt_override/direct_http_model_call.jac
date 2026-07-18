import from jaclang.byllm.lib { MockLLM }

glob llm: MockLLM = MockLLM(
    model_name = "gemma3:4b",
    config = {
        "outputs": [
            "Hello, Alice! It's great to meet you.",
            "Hi Alice, welcome!"
        ],

        # Use these config options to call your own LLM endpoint
        "api_base": "https://your_api_base_here/v1/chat/completions",
        "api_key": "your_api_key_here",
        "http_client": True,
        "ca_bundle": True,

        # for test cases
        "show_params": True,
        "verbose": True,
    }
);

def say_hello(name: str) -> str by llm();

# Per-call `system_prompt` extends the jac.toml base SYSTEM (does not replace).
def say_hello_brief(name: str) -> str by llm(
    system_prompt="Respond in three words maximum."
);

with entry {
    result = say_hello("Alice");
    print(f"Result: {result}");
    brief = say_hello_brief("Alice");
    print(f"Brief: {brief}");
}
