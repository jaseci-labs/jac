"""`visit ... by llm()`: what the routing prompt offers, and what gets visited.

The model reads the prompt and chooses from it rather than being handed a
scripted answer. Handles are generated from the candidate set, so read them back
with routing_candidates() instead of writing them out.
"""

import os;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.runtime.runtime { JacRuntime }
import from fixtures.routing_graph {
    Agent,
    Hub,
    Route,
    collector,
    leaky,
    picker,
    router,
    stream_router
}
import fixtures.routing_graph as rg;
import from fixtures.agent_graph { MathAgent, PoemAgent, Team, supervisor }
import fixtures.agent_graph as ag;
import from support_tests { RoutingLLM, prompt_text, routing_candidates, say }


"""A hub with one agent per (tag, edge priority) pair."""
def build_hub(pairs: list) -> Hub {
    hub = root ++> Hub();
    for (tag, priority) in pairs {
        hub +>:Route(priority=priority):+> Agent(tag=tag);
    }
    return hub;
}


test "the prompt renders each candidate's edge, so routing can choose by it" {
    llm = RoutingLLM(
        pick=lambda (c: list, p: str) { [
            x[0]
            for x in c
            if "priority='high'" in x[1]
        ]; }
    );
    rg.llm = llm;
    hub = build_hub([("alpha", "low"), ("beta", "high")]);

    w = router() spawn hub;

    assert w.visited == ["beta"] , f"the high-priority edge should win, got {w.visited}";
    cands = routing_candidates(llm.seen[0]);
    assert len(cands) == 2 , f"both successors should be offered, got {cands}";
    assert any("priority='high'" in line for (_h, line) in cands) , (
        f"the edge attribute must be rendered, got {cands}"
    );

    # `Agent` carries one ability per walker type. Only the one this walker
    # triggers may be listed: the line tells the model what visiting will do.
    offered = " ".join([line for (_h, line) in cands]);
    assert "runs: log" in offered , f"the firing ability must be named, got {offered!r}";
    for quiet in ["log_picked", "log_collected", "log_streamed"] {
        assert quiet not in offered , (
            f"{quiet} does not fire for `router` and must not be offered: {offered!r}"
        );
    }
}


test "an arbitrary node list is offered without a fabricated edge" {
    # `visit` accepts any node list, not just [-->] successors. Standalone nodes
    # have no edge to `here`, so the prompt must not invent one.
    # The model picks both, so `select=1` has to do the truncating: a picker
    # that returned one anyway would leave that path unexercised.
    llm = RoutingLLM(pick=lambda (c: list, p: str) { [x[0] for x in c]; });
    rg.llm = llm;
    hub = root ++> Hub();
    loose = [Agent(tag="alpha"), Agent(tag="beta")];

    w = picker(options=loose) spawn hub;

    assert len(w.visited) == 1 , (
        f"select=1 must keep one of the two the model returned, got {w.visited}"
    );
    lines = " ".join([line for (_h, line) in routing_candidates(llm.seen[0])]);
    for invented in ["(direct)", "here --", "here <-"] {
        assert invented not in lines , (
            f"a node-only candidate must not be framed as an edge: {lines!r}"
        );
    }
}


test "candidates with identical field values stay distinct targets" {
    # Two candidates carrying the same field values must both be visited.
    # Their handles are what has to stay distinct: the router names candidates
    # by node type, so same-typed siblings collide unless it disambiguates.
    llm = RoutingLLM(pick=lambda (c: list, p: str) { [x[0] for x in c]; });
    rg.llm = llm;
    hub = build_hub([("same", "low"), ("same", "low")]);

    w = collector() spawn hub;

    assert len(w.visited) == 2 , (
        f"two equal-valued nodes are two targets, got {w.visited}"
    );
}


test "routing-only call params are stripped before the request goes out" {
    # select, intent and incl_info are consumed by the router; a real backend
    # rejects them as unknown kwargs. temperature is a real knob and must
    # survive.
    #
    # Asserted on the MTRuntime the routing call built, not on the outgoing
    # params: make_model_params assembles the request from a fixed set of keys,
    # so an unstripped routing key could never appear there and asserting its
    # absence would pass no matter what.
    llm = RoutingLLM();
    rg.llm = llm;
    hub = build_hub([("alpha", "low")]);

    seen_params: list = [];
    original = JacRuntime.call_llm;

    def capture(model: any, mt_run: any) -> any {
        seen_params.append(dict(mt_run.call_params or {}));
        return original(model, mt_run);
    }
    JacRuntime.call_llm = capture;
    try {
        leaky() spawn hub;
    } finally {
        JacRuntime.call_llm = original;
    }
    assert seen_params , "the routing call never reached call_llm";
    routed = seen_params[0];
    for leaked in ["select", "intent", "incl_info"] {
        assert leaked not in routed , (
            f"{leaked} is routing control and must not survive into the call: {sorted(
                routed
            )}"
        );
    }
    assert routed.get("temperature") == 0.5 , (
        f"a real API knob must still pass through, got {routed.get('temperature')!r}"
    );
}


test "a routing call dispatches through the central call_llm entry" {
    # route_visit must go through Jac.call_llm, not model.invoke, so the one
    # runtime entry point stays authoritative for routing as it is for `by llm`.
    llm = RoutingLLM();
    rg.llm = llm;
    hub = build_hub([("a", "low")]);

    calls: list = [];
    original = JacRuntime.call_llm;

    def counting(model: any, mt_run: any) -> any {
        calls.append(1);
        return original(model, mt_run);
    }
    JacRuntime.call_llm = counting;
    try {
        w = router() spawn hub;
    } finally {
        JacRuntime.call_llm = original;
    }
    assert len(calls) == 1 , f"expected exactly one call_llm dispatch, got {len(
        calls
    )}";
    assert w.visited == ["a"] , f"got {w.visited}";
}


test "a supervisor routes to the agent whose speciality matches the request" {
    # One run makes two model calls of different kinds through the same model:
    # the routing choice, then the chosen agent's own `by llm()`. RoutingLLM
    # answers the first from the prompt and falls through to the script for the
    # second.
    poem = "In circuits bright, with purpose clear, agentic minds we hold dear.";

    """Route on the request, not the whole prompt.

    Handles come from node type names, so `"poem" in prompt` is true for the
    math request too: PoemAgent is on the candidate list.
    """
    def by_topic(candidates: list, prompt: str) -> list {
        import re;
        m = re.search(r"user_input='([^']*)'", prompt);
        asked = m.group(1).lower() if m else "";
        wants_poem = "poem" in asked;
        return [
            x[0]
            for x in candidates
            if ("Poem" in x[0]) == wants_poem
        ][:1];
    }
    llm = RoutingLLM(outputs=[say(poem), say("35")], pick=by_topic);
    ag.llm = llm;
    team = root ++> Team();
    team ++> PoemAgent();
    team ++> MathAgent();

    w1 = supervisor(
        user_input="Write four lines of a poem about Agentic AI"
    ) spawn team;
    assert w1.answers == [("poem", poem)] , f"got {w1.answers}";

    w2 = supervisor(user_input="What is (15 + 5) * 2 - (10 / 2)?") spawn team;
    assert w2.answers == [("math", "35")] , f"got {w2.answers}";

    # Asserted on the rendered incl_info entry, not on the bare text: the
    # walker's own repr already carries `user_input=` into every routing
    # prompt, so a substring match would pass with incl_info dropped entirely.
    assert (
        "User input = Write four lines of a poem about Agentic AI"
        in prompt_text(llm, 0)
    ) , f"incl_info must reach the routing prompt, got {prompt_text(llm, 0)[:400]!r}";
}


test "a streaming routing decision reaches the handler and still selects an edge" {
    # The decision streams token by token to a stream_handler, which is how a
    # live token feed consumes it, while the structured choice still drives the
    # walker to the chosen successor.
    llm = RoutingLLM(
        pick=lambda (c: list, p: str) { [
            x[0]
            for x in c
            if "green" in x[1]
        ]; }
    );
    rg.llm = llm;
    rg.streamed.clear();
    hub = build_hub([("red", "low"), ("green", "low")]);

    w = stream_router() spawn hub;

    assert w.visited == ["green"] , f"the structured choice must still route, got {w.visited}";
    assert rg.streamed , "the stream_handler received no chunk events";
    assert "green" in "".join(rg.streamed) , (
        f"the decision must reach the handler token by token, got {rg.streamed}"
    );
}
