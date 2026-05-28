"""Structured streaming is gated on a stream_handler.

Streaming a non-`str` return without a handler to consume the events has no
well-defined result, so it is rejected up front. With a handler the same call
is allowed (see streaming_visit_by).
"""
import from byllm.lib { MockLLM }
import from byllm.exceptions { ConfigurationError }

glob llm: MockLLM = MockLLM(
         model_name="mockllm",
         config={"outputs": ['{"schema_object_wrapper": [1]}']}
     );

def pick(options: str) -> list[int] by llm(stream=True);

with entry {
    raised = False;
    try {
        pick("0=a, 1=b");
    } except ConfigurationError {
        raised = True;
    }
    assert raised , "structured streaming without a stream_handler must raise ConfigurationError";
    print("STREAMING_GUARD_PASS");
}
