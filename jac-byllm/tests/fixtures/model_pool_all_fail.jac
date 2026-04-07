"""Test ModelPool exception propagation when all deployments fail.

Verifies that when the LiteLLM Router raises (all deployments exhausted)
the exception propagates to the caller rather than being swallowed.
"""
import from byllm.lib { MockLLM, ModelPool }
import from litellm.exceptions { RateLimitError }

glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []});
glob model2 = MockLLM(model_name="gpt-4", config={"outputs": []});
glob pool = ModelPool(models=[model1, model2], strategy="fallback");

def get_answer(question: str) -> str by pool();

def mock_completion(**_kwargs: object) -> object {
    raise RateLimitError(
        message="All deployments exhausted",
        model="gpt-3.5-turbo",
        llm_provider="openai",
    );
}

with entry {
    pool._router.completion = mock_completion;  # type: ignore

    try {
        result = get_answer("test");
        print(f"UNEXPECTED: {result}");
    } except Exception as e {
        print(f"EXPECTED_ERROR: {type(e).__name__}");
    }
}
