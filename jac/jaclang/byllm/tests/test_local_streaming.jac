"""Local streams retain text and metadata from llama.cpp dictionary replies."""

import asyncio;
import unittest.mock;
import from jaclang.byllm.llm { BaseLLM, LocalLLM, Model }
import from jaclang.byllm.mtir { MTRuntime }
import from support { mk_run }


# Replace only the engine boundary: request shaping, the local adapter, model
# delegation and both streaming dispatchers still run.
obj _LlamaStream {
    has with_usage: bool;

    def create_chat_completion(**params: any) -> any {
        assert params["messages"];
        if not params.get("stream") {
            return {
                "model": "local-engine",
                "choices": [
                    {
                        "message": {"role": "assistant", "content": "hello world"},
                        "finish_reason": "stop"
                    }
                ]
            };
        }
        chunks: list[dict[str, any]] = [];
        for delta in [
            {"role": "assistant"},
            {"content": "hello "},
            {"content": "world"}
        ] {
            chunks.append(
                {
                    "model": "local-engine",
                    "choices": [{"index": 0, "delta": delta, "finish_reason": None}]
                }
            );
        }
        chunks.append(
            {
                "model": "local-engine",
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]
            }
        );
        if self.with_usage {
            chunks.append(
                {
                    "choices": [],
                    "usage": {
                        "prompt_tokens": 3,
                        "completion_tokens": 2,
                        "total_tokens": 5
                    }
                }
            );
        }
        return iter(chunks);
    }
}


async def _async_text(model: BaseLLM, mt: MTRuntime) -> str {
    stream = await model.ainvoke(mt);
    chunks: list[str] = [];
    async for chunk in stream {
        chunks.append(chunk);
    }
    return "".join(chunks);
}


test "local dictionary streams preserve text and terminal metadata" {
    for delegated in [False, True] {
        for asynchronous in [False, True] {
            for with_usage in [False, True] {
                label = f"delegated={delegated}, async={asynchronous}, usage={with_usage}";
                model = Model(model_name="local:gemma-4-e4b")
                    if delegated
                    else LocalLLM(model_name="local:gemma-4-e4b");
                engine_owner = model._local_delegate
                    if isinstance(model, Model)
                    else model;
                mt = mk_run(stream=True);
                with unittest.mock.patch.object(
                    engine_owner, "_llama", _LlamaStream(with_usage)
                ) {
                    assert model.invoke(mk_run()) == "hello world" , label;
                    text = asyncio.run(_async_text(model, mt))
                        if asynchronous
                        else "".join(model.invoke(mt));
                }
                assert text == "hello world" , f"{label}: got {text!r}";
                assert len(mt._usage_history) == 1 , f"{label}: {mt._usage_history}";
                usage = mt._usage_history[0];
                assert usage["model"] == "local-engine" , f"{label}: {usage}";
                assert usage["finish_reason"] == "stop" , f"{label}: {usage}";
                if with_usage {
                    assert usage["prompt_tokens"] == 3 , f"{label}: {usage}";
                    assert usage["completion_tokens"] == 2 , f"{label}: {usage}";
                    assert usage["total_tokens"] == 5 , f"{label}: {usage}";
                } else {
                    assert "total_tokens" not in usage , f"{label}: {usage}";
                }
            }
        }
    }
}
