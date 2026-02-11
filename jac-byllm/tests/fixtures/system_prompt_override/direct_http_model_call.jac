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
        "http_client": True,
        "ca_bundle": True,

        # for test cases
        "show_params": True,
        "verbose": True,
    }
);

def say_hello(name: str) -> str by llm();

with entry {
    result = say_hello("Alice");
    print(f"Result: {result}");
}
