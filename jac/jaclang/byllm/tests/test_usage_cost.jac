"""Cost on the usage payload (#7896).

Uses litellm's real `completion_cost` rather than a stub: `_attach_call_cost`
swallows every exception, so a mocked suite stays green while the feature
reports nothing. The pricing table is local, so this needs no network or key.
"""

import asyncio;
import types;
import from unittest { mock }
import jaclang.byllm.llm as _byllm_llm_mod;
import litellm;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Message, MessageRole }

glob MODEL = "gpt-4o-mini",
     UNPRICEABLE = "openai/ft:definitely-not-a-real-model:acme::zzz",
     TOKENS = {"prompt_tokens": 100, "completion_tokens": 20, "total_tokens": 120},
     PATHS = [
         "dispatch_no_streaming",
         "adispatch_no_streaming",
         "dispatch_streaming_with_tools",
         "dispatch_streaming",
         "adispatch_streaming"
     ];


def _response(model: str = MODEL, usage: (dict | None) = None) -> dict {
    return {
        "model": model,
        "choices": [
            {
                "message": {"role": "assistant", "content": "hi", "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": dict(TOKENS) if usage is None else usage
    };
}


def _cost_of(usage: any) -> any {
    return usage.get("cost") if isinstance(usage, dict) else usage?.cost;
}


async def _aiter(items: list) {
    for item in items {
        yield item;
    }
}


async def _drain(agen: any) {
    async for _item in agen { }
}


def _usage_from(path: str, response: (dict | None) = None) -> any {
    resp = response if response is not None else _response();
    llm = Model(model_name=resp["model"]);
    mt = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="u")
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );
    chunks = [
        types.SimpleNamespace(
            usage=None,
            choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content="hi"))]
        ),
        types.SimpleNamespace(usage=litellm.Usage(**TOKENS), choices=[])
    ];
    _call = lambda (params: dict) { return resp; };
    _stream = lambda (params: dict) { return chunks; };
    _rebuild = lambda (seen: list) { return resp; };

    async def _acall(params: dict) -> dict {
        return resp;
    }
    async def _astream(params: dict) -> any {
        return _aiter(chunks);
    }

    if path == "dispatch_no_streaming" {
        with mock.patch.object(llm, "model_call_no_stream", _call) {
            return llm.dispatch_no_streaming(mt).usage;
        }
    }
    if path == "adispatch_no_streaming" {
        with mock.patch.object(llm, "model_call_no_stream_async", _acall) {
            coro: any = llm.adispatch_no_streaming(mt);
            result: any = asyncio.run(coro);
            return result.usage;
        }
    }
    if path == "dispatch_streaming_with_tools" {
        out: list = [];
        with mock.patch.object(llm, "model_call_with_stream", _stream), mock.patch.object(
            _byllm_llm_mod.litellm, "stream_chunk_builder", _rebuild
        ) {
            list(llm.dispatch_streaming_with_tools(mt, out));
        }
        return out[0].usage;
    }
    if path == "dispatch_streaming" {
        with mock.patch.object(llm, "model_call_with_stream", _stream) {
            list(llm.dispatch_streaming(mt));
        }
        return llm._usage_history[-1];
    }
    with mock.patch.object(llm, "model_call_with_stream_async", _astream) {
        agen: any = llm.adispatch_streaming(mt);
        asyncio.run(_drain(agen));
    }
    return llm._usage_history[-1];
}


test "every dispatch path reports the cost litellm computes for the call" {
    expected = litellm.completion_cost(completion_response=_response(), model=MODEL);
    assert expected > 0.0 , f"litellm priced {MODEL} at {expected}; fixture is blind";

    for path in PATHS {
        usage = _usage_from(path);
        cost = _cost_of(usage);
        assert cost is not None , f"{path} left no cost on the usage payload";
        assert abs(cost - expected) < 1e-12 , (
            f"{path} reported {cost}, litellm computes {expected}"
        );
        if not isinstance(usage, dict) {
            dumped: dict = usage.model_dump();
            assert "cost" in dumped , (
                f"{path} set cost but model_dump() dropped it, so would the aggregate"
            );
        }
    }
}


test "cost is omitted rather than guessed when it cannot be computed" {
    for (label, resp) in [
        ("unpriceable model", _response(UNPRICEABLE)),
        ("response with no usage data", _response(MODEL, {}))
    ] {
        usage = _usage_from("dispatch_no_streaming", resp);
        assert _cost_of(usage) is None , (
            f"{label} reported cost={_cost_of(usage)}; unknown must stay distinct "
            "from free"
        );
        if resp["usage"] {
            assert usage["prompt_tokens"] == TOKENS["prompt_tokens"] , (
                f"{label} must leave the token counts intact"
            );
        }
    }
}
