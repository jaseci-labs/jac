"""Test ModelPool cost-based-routing with LiteLLM Router.

LiteLLM Router's cost-based-routing uses the async acompletion() path
internally. ModelPool bridges this by running acompletion() in a
ThreadPoolExecutor so it is safe even inside frameworks with an existing
event loop. Verifies the full async dispatch pipeline works end-to-end.
"""
import from byllm.lib { MockLLM, ModelPool }
import asyncio;

glob model1 = MockLLM(model_name="gpt-4o", config={"outputs": []});
glob model2 = MockLLM(model_name="gpt-4o-mini", config={"outputs": []});
glob pool = ModelPool(models=[model1, model2], strategy="cost-based-routing");

def get_answer(question: str) -> str by pool();

async def mock_acompletion(**_kwargs: object) -> dict {
    return {
        "model": "gpt-4o-mini",
        "choices": [
            {
                "message": {
                    "content": "cost_based_success",
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
    pool._router.acompletion = mock_acompletion;  # type: ignore
    result = get_answer("test");
    print(result);
}
