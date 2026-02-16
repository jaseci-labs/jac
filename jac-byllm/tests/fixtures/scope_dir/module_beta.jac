"""Fixture module_beta with process_data function for scope resolution test."""

import from byllm.lib { MockLLM }

obj BetaResult {
    has value: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [BetaResult(value="beta_result")], "verbose": False}
);

def process_data -> BetaResult by llm();
