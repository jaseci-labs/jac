"""Regression: visit-routing LLM calls go through the `call_llm` plugin hook.

`route_visit` must dispatch via `Jac.call_llm` (not `model.invoke` directly) so
any registered `call_llm`/`acall_llm` middleware (retry, cost tracking,
observability, rate limiting) fires for routing exactly as it does for regular
`by llm` calls. This fixture registers an observing `call_llm` hook, runs a
routing visit, and reports how many times the hook fired.
"""

import from jaclang.jac0core.runtime { hookimpl, plugin_manager }
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }

glob hook_calls: list = [];

class ObsPlugin {
    """Observability middleware: counts every routed LLM call, then delegates."""
    @hookimpl
    static def call_llm(model: object, mt_run: MTRuntime) -> object {
        hook_calls.append(1);
        return model.invoke(mt_run=mt_run);
    }
}

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
    plugin_manager.register(ObsPlugin);
    try {
        desk = root ++> Desk();
        desk ++> Agent(tag="a");
        router() spawn desk;
    } finally {
        plugin_manager.unregister(ObsPlugin);
    }
    print("HOOK_CALLS:" + str(len(hook_calls)));
}
