"""Fixture module_alpha with process_data function for scope resolution test."""

import from byllm.lib { MockLLM }

obj AlphaResult {
    has value: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [AlphaResult(value="alpha_result")], "verbose": False}
);

def process_data -> AlphaResult by llm();
