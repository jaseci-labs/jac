"""Multistage visit routing: condense -> reason -> extract pipeline.

`by llm(multistage=True)` must dispatch through `route_visit_multistage`:
a long `intent` is condensed in one dedicated call, the routing decision is
made in a free-text reasoning call, and a well-formed trailing 'CHOICE:' line
short-circuits the structured extraction call entirely. The mock tags each
stage by its system prompt and counts how often each fires; a second hop with
the identical intent must hit the condensation cache instead of a new call.
"""

import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }

glob stage_calls: dict = {"condense": 0, "reason": 0, "extract": 0};

glob LONG_GOAL: str = (
    "Route the walker to the agent best suited for billing questions. " * 20
);

obj StageMock(MockLLM) {
    """Answers each pipeline stage, keyed off its system prompt."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        sys_txt = str(getattr(mt_run.messages[0], "content", ""));
        if "compress task context" in sys_txt {
            stage_calls["condense"] += 1;
            return CompletionResult(
                output="Send the walker to the billing agent.",
                tool_calls=[],
                usage={}
            );
        }
        if "Extract the routing decision" in sys_txt {
            stage_calls["extract"] += 1;
            return CompletionResult(output=[0], tool_calls=[], usage={});
        }
        stage_calls["reason"] += 1;
        user_txt = str(getattr(mt_run.messages[-1], "content", ""));
        pick = "none";
        if "Agent_beta)" in user_txt {
            pick = "Agent_beta";
        } elif "Agent)" in user_txt {
            pick = "Agent";
        }
        return CompletionResult(
            output=f"Beta handles billing questions.\nCHOICE: {pick}",
            tool_calls=[],
            usage={}
        );
    }
}

glob llm: StageMock = StageMock(model_name="mockllm", config={"outputs": []});

node Desk {}

node Agent {
    has tag: str = "x";

    can serve with router entry {
        print("VISITED:" + self.tag);
        visit [-->] by llm(select=1, multistage=True, intent=LONG_GOAL);
    }
}

walker router {
    can route with Desk entry {
        visit [-->] by llm(select=1, multistage=True, intent=LONG_GOAL);
    }
}

with entry {
    desk = root ++> Desk();
    desk ++> Agent(tag="alpha");
    beta = desk ++> Agent(tag="beta");
    beta ++> Agent(tag="gamma");
    router() spawn desk;
    print("CONDENSE:" + str(stage_calls["condense"]));
    print("REASON:" + str(stage_calls["reason"]));
    print("EXTRACT:" + str(stage_calls["extract"]));
}
