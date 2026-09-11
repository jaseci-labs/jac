"""Fixture for jac#8932: async by llm(stream=True) over a stubbed provider.

acall_llm is deliberately not mocked, so the whole chain runs.
"""

import litellm;
import from jaclang.byllm.llm { BaseLLM }


def _chunk(text: str) -> object {
    return litellm.ModelResponseStream(
        **{
            "id": "c",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "stub",
            "choices": [{"index": 0, "delta": {"content": text}, "finish_reason": None}]
        }
    );
}


obj StubStreamLLM(BaseLLM) {
    """Implements only the sync provider call, so it inherits the base async one."""
    override def model_call_with_stream(params: dict) -> object {
        for word in ["streamed ", "reply"] {
            yield _chunk(word);
        }
    }
}


glob llm = StubStreamLLM(model_name="stub-stream");


async def ask(topic: str) -> str by llm(stream=True);
