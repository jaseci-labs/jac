"""module_alpha's `process_data`, which shares its name with module_beta's."""

import from jaclang.byllm.lib { MockLLM }

obj AlphaResult {
    has value: str;
}

glob llm = MockLLM(
         model_name="mockllm",
         config={"outputs": [AlphaResult(value="alpha_result")], "verbose": False}
     );

def process_data -> AlphaResult by llm();
