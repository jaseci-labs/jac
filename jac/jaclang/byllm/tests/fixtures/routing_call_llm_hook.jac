"""Regression: visit-routing LLM calls go through the central `call_llm` entry.

`route_visit` must dispatch via `Jac.call_llm` (not `model.invoke` directly) so
that the single runtime LLM entry point stays authoritative for routing exactly
as it is for regular `by llm` calls. This fixture temporarily wraps
`Jac.call_llm` to count invocations, runs a routing visit, and reports how many
times it fired.
"""

import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }

glob hook_calls: list = [];

obj PickFirstMock(MockLLM) {
    """Selects the first candidate handle."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        return CompletionResult(output=[0], tool_calls=[], usage={});
    }
}

glob llm: PickFirstMock = PickFirstMock(
         model_name="mockllm", config={"outputs": []}
     );

node Desk {}

node Agent {
    has tag: str = "x";

    can serve with router entry {
        print("VISITED:" + self.tag);
    }
}

walker router {
    can route with Desk entry {
        visit [-->] by llm(select=1, intent="route");
    }
}

with entry {
    _orig_call_llm = Jac.call_llm;

    def _counting_call_llm(model: object, mt_run: MTRuntime) -> object {
        hook_calls.append(1);
        return _orig_call_llm(model, mt_run);
    }
    Jac.call_llm = _counting_call_llm;
    try {
        desk = root ++> Desk();
        desk ++> Agent(tag="a");
        router() spawn desk;
    } finally {
        Jac.call_llm = _orig_call_llm;
    }
    print("HOOK_CALLS:" + str(len(hook_calls)));
}
