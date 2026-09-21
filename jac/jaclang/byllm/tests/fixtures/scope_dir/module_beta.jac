"""module_beta's `process_data`, which shares its name with module_alpha's."""

import from jaclang.byllm.lib { MockLLM }

obj BetaResult {
    has value: str;
}

glob llm = MockLLM(
         model_name="mockllm",
         config={"outputs": [BetaResult(value="beta_result")], "verbose": False}
     );

def process_data -> BetaResult by llm();
