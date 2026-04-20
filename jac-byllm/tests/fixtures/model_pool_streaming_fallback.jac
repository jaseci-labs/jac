"""Test ModelPool streaming fallback path.

Scenario A – pre-stream failure:
  Verifies that when the primary model fails before yielding any chunks,
  the fallback model takes over and streams its response cleanly.

Scenario B – mid-stream failure (yielded guard):
  Verifies that when the primary model yields at least one chunk and then
  raises, the exception propagates to the caller instead of silently falling
  back to the next model. This exercises the `yielded` flag in _fallback_gen
  that prevents corrupted output (partial A concatenated with full B).

This is a regression test for the stream_with_fallbacks infinite loop fix:
our _fallback_gen calls Router._completion() per model with fallbacks=[]
to prevent LiteLLM Router from recursing back into the primary model when
a streaming call fails mid-flight.
"""
import from byllm.lib { MockLLM, ModelPool }
import from litellm.exceptions { RateLimitError }
import types;

# ---------------------------------------------------------------------------
# Shared helper
# ---------------------------------------------------------------------------
def make_chunk(text: str) -> object {
    delta = types.SimpleNamespace(content=text);
    choice = types.SimpleNamespace(delta=delta);
    return types.SimpleNamespace(choices=[choice]);
}

# ---------------------------------------------------------------------------
# Scenario A: pre-stream failure → fallback takes over
# ---------------------------------------------------------------------------
glob model1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []});
glob model2 = MockLLM(model_name="gpt-4", config={"outputs": []});
glob pool = ModelPool(models=[model1, model2], strategy="fallback");

"""Stream a short answer to the given question."""
def stream_answer(question: str) -> str by pool(stream=True);

glob _models_tried: list = [];

def mock_completion(model: str, messages: list, stream: bool,
                    fallbacks: list, **_kwargs: object) -> object {
    _models_tried.append(model);
    if model == "pool-primary" {
        raise RateLimitError(
            message="Primary quota exceeded",
            model="gpt-3.5-turbo",
            llm_provider="openai",
        );
    }
    def _gen() -> object {
        yield make_chunk("stream_fallback_");
        yield make_chunk("success");
    }
    return _gen();
}

# ---------------------------------------------------------------------------
# Scenario B: mid-stream failure → exception must propagate, no fallback
# ---------------------------------------------------------------------------
glob model_b1 = MockLLM(model_name="gpt-3.5-turbo", config={"outputs": []});
glob model_b2 = MockLLM(model_name="gpt-4", config={"outputs": []});
glob pool_mid = ModelPool(models=[model_b1, model_b2], strategy="fallback");

"""Stream a short answer (mid-stream scenario)."""
def stream_answer_mid(question: str) -> str by pool_mid(stream=True);

glob _tried_mid: list = [];

def mock_midstream_completion(model: str, messages: list, stream: bool,
                              fallbacks: list, **_kwargs: object) -> object {
    _tried_mid.append(model);
    if model == "pool-primary" {
        def _failing_gen() -> object {
            yield make_chunk("partial_chunk");
            raise RateLimitError(
                message="Primary failed mid-stream",
                model="gpt-3.5-turbo",
                llm_provider="openai",
            );
        }
        return _failing_gen();
    }
    # Fallback should never be reached — if it is, the test will catch it.
    def _fallback_gen() -> object {
        yield make_chunk("should_not_appear");
    }
    return _fallback_gen();
}

with entry {
    # --- Scenario A ---
    pool._router._completion = mock_completion;  # type: ignore

    result_stream = stream_answer("test question");
    output = "".join(list(result_stream));

    print(f"output:{output}");
    print(f"primary_tried:{'pool-primary' in _models_tried}");
    print(f"fallback_tried:{'pool-fallback-1' in _models_tried}");
    print(f"order_correct:{_models_tried.index('pool-primary') < _models_tried.index('pool-fallback-1')}");

    # --- Scenario B ---
    pool_mid._router._completion = mock_midstream_completion;  # type: ignore

    mid_raised: bool = False;
    mid_chunks: list = [];
    try {
        for chunk in stream_answer_mid("test question") {
            mid_chunks.append(chunk);
        }
    } except RateLimitError {
        mid_raised = True;
    }

    mid_output = "".join(mid_chunks);
    print(f"mid_raised:{mid_raised}");
    print(f"mid_partial_received:{'partial_chunk' in mid_output}");
    print(f"mid_fallback_not_tried:{'pool-fallback-1' not in _tried_mid}");
    print(f"mid_should_not_appear:{'should_not_appear' not in mid_output}");
}
