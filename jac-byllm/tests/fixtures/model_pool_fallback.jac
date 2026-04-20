"""Test ModelPool fallback strategy with LiteLLM Router.

Verifies the full dispatch pipeline works end-to-end by replacing the
router's completion method with a plain function that returns a canned
response — no real API call is made.
"""
import from byllm.lib { MockLLM, ModelPool }

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []});
glob model2 = MockLLM(model_name="gpt-4", config={"outputs": []});
glob pool = ModelPool(models=[model1, model2], strategy="fallback");

def get_answer(question: str) -> str by pool();

def mock_completion(**_kwargs: object) -> dict {
    return {
        "model": "mock-pool-model",
        "choices": [
            {
                "message": {
                    "content": "fallback_success",
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
    pool._router.completion = mock_completion;  # type: ignore
    result = get_answer("test question");
    print(result);
}
