import from byllm.lib { MockLLM }

glob llm: MockLLM = MockLLM(
    model_name = "gemma3:4b",
    config = {
        "outputs": [
            "Hello, Alice! It's great to meet you."
        ],

        # Use these config options to call your own LLM endpoint
        "api_base": "https://your_api_base_here/v1/chat/completions",
        "api_key": "your_api_key_here",
        "use_http_client": True,
        "ca_bundle": True,

        # for test cases
        "show_params": True,
        "verbose": True,
    }
);

# Now byLLM gives the ability to override byLLM system prompts.
# But not recommended. This is only for special use cases.
def say_hello(name: str) -> str by llm(
    stream = False,
    _allow_system_override = True,
    _system_prompt_override = "You are a friendly assistant. Greet the person warmly and briefly.",
);

with entry {
    result = say_hello("Alice");
    print(f"Result: {result}");
}
