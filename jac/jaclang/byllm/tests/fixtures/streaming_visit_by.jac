"""Streaming `visit [-->] by model`.

The routing decision streams token-by-token to a `stream_handler` (exactly how
the jac ai --ui firehose consumes it) while the structured edge selection still
drives the walker to the chosen successor. The routing call returns a
`list[RouteChoice]` of candidate handles wrapped under `schema_object_wrapper`;
the descriptive handle "GreenNode" here selects that successor.
"""
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { StreamEvent }

glob llm: MockLLM = MockLLM(
         model_name="mockllm",
         config={"outputs": ['{"schema_object_wrapper": ["GreenNode"]}']}
     );

glob streamed_chunks: list = [];

"""Collect the routing call's streamed tokens, the way the UI firehose does."""
def route_sink(ev: StreamEvent) -> None {
    if ev.event_type == "chunk" {
        streamed_chunks.append(str(ev.data.get("content", "")));
    }
}

node Hub {}

walker router {
    can route with Hub entry {
        visit [-->] by llm(stream=True, stream_handler=route_sink);
    }
}

node RedNode {
    can mark with router entry {
        print("VISITED: red");
    }
}

node GreenNode {
    can mark with router entry {
        print("VISITED: green");
    }
}

with entry {
    # Walk from a fresh hub (not root) so the candidate edges are exactly these
    # two, independent of any other graph state in the process.
    hub = Hub();
    hub ++> RedNode();
    hub ++> GreenNode();
    router() spawn hub;

    # 1) The routing decision reached the handler token-by-token.
    full = "".join(streamed_chunks);
    assert len(streamed_chunks) > 0 , "stream_handler received no chunk events";
    assert "schema_object_wrapper" in full , f"unexpected streamed tokens: {full!r}";
    print("STREAMING_VISIT_BY_PASS");
}
