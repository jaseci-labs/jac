"""Test ModelPool load-balancing with LiteLLM Router (simple-shuffle strategy).

All models in a load-balancing pool share the "pool-model" alias so the
router treats them as equivalent deployments. Verifies the alias config
and that multiple calls are served correctly.
"""
import from byllm.lib { MockLLM, ModelPool }

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []});
glob model2 = MockLLM(model_name="gpt-4o-mini", config={"outputs": []});
glob model3 = MockLLM(model_name="gemini/gemini-2.0-flash", config={"outputs": []});
glob pool = ModelPool(models=[model1, model2, model3], strategy="simple-shuffle");

def get_answer(question: str) -> str by pool();

def mock_completion(**_kwargs: object) -> dict {
    return {
        "model": "mock-pool-model",
        "choices": [
            {
                "message": {
                    "content": "load_balance_response",
                    "role": "assistant",
                    "tool_calls": None,
                },
                "finish_reason": "stop",
                "index": 0,
            }
        ],
    };
}

with entry {
    # Print router init info so the test can verify the load-balance configuration
    print(f"pool_alias:{pool.model_name}");

    pool._router.completion = mock_completion;  # type: ignore

    result1 = get_answer("question 1");
    result2 = get_answer("question 2");
    result3 = get_answer("question 3");

    print(result1);
    print(result2);
    print(result3);
}
