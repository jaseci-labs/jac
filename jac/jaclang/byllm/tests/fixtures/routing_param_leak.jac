"""Regression fixture: routing-only `call_params` must not leak to the model.

`select`, `intent`, and `incl_info` are routing-control keys consumed by
`route_visit`; they must be stripped before the request reaches the LLM (a real
backend would reject them as unknown kwargs, e.g. "unexpected keyword argument
'select'"). A legitimate API knob like `temperature` must still pass through.

`MockLLM` ignores `call_params`, which is exactly why the bug went unnoticed --
so this mock instead *captures* `mt_run.call_params` into a global, and the
entry block surfaces what actually reached the runtime for the test to assert on.
"""

import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }

glob captured_params: dict = {};

obj ParamCaptureMock(MockLLM) {
    """Records the `call_params` that reach the runtime for the routing call."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        captured_params.clear();
        captured_params.update(mt_run.call_params or {});
        return CompletionResult(output=[0], tool_calls=[], usage={});
    }
}

glob llm: ParamCaptureMock = ParamCaptureMock(
         model_name="mockllm", config={"outputs": []}
     );

node Desk {}

node Agent {
    has tag: str = "x";
}

walker dispatcher {
    can route with Desk entry {
        visit [-->] by llm(
            select=1, intent="go", incl_info={"k": "v"}, temperature=0.5
        );
    }
}

with entry {
    desk = root ++> Desk();
    desk ++> Agent(tag="alpha");
    dispatcher() spawn desk;
    for key in ["select", "intent", "incl_info"] {
        if key in captured_params {
            print("LEAKED:" + key);
        }
    }
    print("HAS_TEMPERATURE:" + str("temperature" in captured_params));
}
