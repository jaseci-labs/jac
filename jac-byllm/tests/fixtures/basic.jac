"""Fixture with module name ending in 'c' to test scope name resolution."""

import from byllm.lib { MockLLM }

obj BasicInfo {
    has name: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [BasicInfo(name="test_basic")], "verbose": False}
);

def get_basic -> BasicInfo by llm();
