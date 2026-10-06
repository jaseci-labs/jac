"""The System One backend: closed-set `by` call sites answered by a decision model.

What goes on the wire for each return shape and what comes back; when a call is
refused or escalated to the fallback chat model; how `visit ... by` honours `select`.
"""

import asyncio;
import os;
import from jaclang.byllm.lib { Decision, MockLLM, MockSystemOne, Model }
import from jaclang.byllm.llm { SystemOneModel }
import from jaclang.byllm.mtir { MTIR, MTRuntime }
import from jaclang.byllm.exceptions {
    AuthenticationError,
    ByLLMError,
    ConfigurationError,
    RateLimitError
}
import from jaclang.byllm.systemone {
    ROUTE_SELECT_ATTR,
    assemble,
    lower,
    resolve_model_name
}
import from jaclang.runtime.semantic {
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    ParamInfo,
    TypeForm
}
import from fixtures.routing_graph { Agent, Hub, Route, collector, duo, router }
import fixtures.routing_graph as rg;
import from support { choose, mk_run, nouls, prompt_text, questions_of, say, yes }


enum Priority { LOW, HIGH }


enum Team { BILLING, SECURITY, PLATFORM }


enum Sev { LOW = 1, HIGH = 2, SEVERE = 2 }


obj Triage {
    has urgency: Priority,
        needs_human: bool;
}


glob _ticket_so1 = MockSystemOne();


obj Ticket {
    has text: str,
        tier: Priority = Priority.HIGH;

    def rank -> Priority by _ticket_so1();
}


def _fn(ticket: str) -> object {
    return None;
}


def _tool(query: str) -> str {
    return query;
}


"""An MTRuntime as a call site builds it, carrying the compiler's IR when given."""
def _site(
    resp_type: any, args: dict[any, any] = {}, info: (FunctionInfo | None) = None
) -> MTRuntime {
    run = mk_run();
    run.resp_type = resp_type;
    if info is not None {
        run.mtir = MTIR(caller=_fn, args=args, call_params={}, ir_info=info);
    }
    return run;
}


"""A hub with one agent per tag."""
def _hub(tags: list[str]) -> Hub {
    hub = root ++> Hub();
    for tag in tags {
        hub +>:Route():+> Agent(tag=tag);
    }
    return hub;
}


def _priority_ir -> EnumInfo {
    return EnumInfo(
        name="Priority",
        semstr=None,
        members=[
            FieldInfo(name="LOW", semstr="can wait", type_info=None),
            FieldInfo(name="HIGH", semstr="urgent now", type_info=None)
        ]
    );
}


test "an enum call site is asked one choice over its members and returns the member" {
    so1 = MockSystemOne(answers=[choose("HIGH", 0.93)]);

    def rank(ticket: str) -> Priority by so1();

    assert rank("the checkout page is down") is Priority.HIGH;
    q = questions_of(so1)["value"];
    assert q["type"] == "choice" , f"an enum is a choice, got {q}";
    assert set(q["criteria"].keys()) == {"LOW", "HIGH"} , q["criteria"];
    assert so1.seen[0]["state"] == {"ticket": "the checkout page is down"} , (
        f"the arguments are the state, got {so1.seen[0]['state']}"
    );
    assert so1.exhausted();
}


test "a bool call site is asked one noul" {
    so1 = MockSystemOne(answers=[yes(0.9), yes(0.2)]);

    def is_spam(subject: str) -> bool by so1();

    assert is_spam("YOU HAVE WON") is True;
    assert is_spam("minutes from Tuesday") is False;
    assert questions_of(so1)["value"]["type"] == "noul";
}


test "Decision[T] returns the value with the endpoint's confidence and distribution" {
    so1 = MockSystemOne(answers=[choose("HIGH", 0.93)]);

    def rank(ticket: str) -> Decision[Priority] by so1();

    d = rank("the checkout page is down");
    assert isinstance(d, Decision) and d.value is Priority.HIGH , f"got {d!r}";
    assert d.confidence == 0.93;
    assert "HIGH" in d.probabilities["value"];
}


test "list[E] is asked one noul per member and returns those above the gate, most probable first" {
    so1 = MockSystemOne(
        answers=[
            nouls({"BILLING": 0.6, "SECURITY": 0.9, "PLATFORM": 0.2}),
            nouls({"BILLING": 0.1, "SECURITY": 0.2, "PLATFORM": 0.05})
        ]
    );

    def teams(ticket: str) -> list[Team] by so1();

    assert teams("charged twice, and a CVE") == [Team.SECURITY, Team.BILLING];
    assert set(questions_of(so1).keys()) == {"BILLING", "SECURITY", "PLATFORM"};
    assert teams("hello") == [] , "nothing above the gate is an empty list";
}


test "an enum alias is asked once and returned once" {
    so1 = MockSystemOne(answers=[nouls({"LOW": 0.9, "HIGH": 0.8})]);

    def severities(ticket: str) -> list[Sev] by so1();

    assert severities("x") == [Sev.LOW, Sev.HIGH];
    assert set(questions_of(so1).keys()) == {"LOW", "HIGH"} , (
        "SEVERE aliases HIGH and must not be a separate question"
    );
}


test "a closed-set obj is asked one question per field in a single request" {
    so1 = MockSystemOne(
        answers=[
            {"urgency": choose("HIGH", 0.9)["value"], "needs_human": yes(0.8)["value"]}
        ]
    );

    def triage(ticket: str) -> Triage by so1();

    t = triage("the site is down");
    assert isinstance(t, Triage) , f"expected a Triage, got {t!r}";
    assert t.urgency is Priority.HIGH and t.needs_human is True;
    qs = questions_of(so1);
    assert qs["urgency"]["type"] == "choice" and qs["needs_human"]["type"] == "noul";
    assert len(so1.seen) == 1 , "both fields travel in one request";
}


test "a call the protocol cannot answer goes to the fallback chat model untouched" {
    fb = MockLLM(outputs=[say("a summary"), Team.BILLING]);
    so1 = MockSystemOne(fallback=fb, config={"max_choice_options": 2});

    def summarize(text: str) -> str by so1();
    def route(subject: str) -> Team by so1();

    assert summarize("a long document") == "a summary";
    assert "a long document" in prompt_text(fb) , (
        "the fallback is handed the prompt byLLM already built"
    );
    assert route("invoice") is Team.BILLING , (
        "three labels exceed this provider's cap of two, so the fallback answers"
    );
    assert so1.seen == [] , "nothing is sent to the endpoint for a refused call";
}


test "with no fallback an unanswerable call is a configuration error" {
    so1 = MockSystemOne();

    def summarize(text: str) -> str by so1();

    raised = False;
    try {
        summarize("a long document");
    } except ConfigurationError as e {
        raised = True;
        assert "fallback" in str(e) , f"the error must say what to configure, got {e}";
    }
    assert raised;
}


test "an answer below min_confidence is escalated to the fallback; above it stands" {
    fb = MockLLM(outputs=[Priority.LOW]);
    so1 = MockSystemOne(
        answers=[choose("HIGH", 0.4), choose("HIGH", 0.95)],
        fallback=fb,
        min_confidence=0.7
    );

    def rank(ticket: str) -> Priority by so1();

    assert rank("hmm") is Priority.LOW , "below the threshold the fallback answers";
    assert rank("the site is down") is Priority.HIGH , "above it the endpoint stands";
    assert fb.exhausted() and so1.exhausted();
}


test "the lowering refuses tools and streaming: the protocol answers, it does not act" {
    assert lower(mk_run(resp_type=Priority, tools=[_tool])) is None;
    assert lower(mk_run(resp_type=Priority, stream=True)) is None;
}


test "endpoint statuses map onto byLLM's exceptions, retrying 429" {
    for (script, err) in [
        ([(401, {"error": "bad key"})], AuthenticationError),
        ([(422, {"detail": "criteria missing"})], ConfigurationError),
        ([(500, {"raw": "boom"})], ByLLMError),
        ([(429, {}), (429, {}), (429, {})], RateLimitError)
    ] {
        so1 = MockSystemOne(answers=script);
        caught: (Exception | None) = None;
        try {
            so1.invoke(mk_run(resp_type=Priority));
        } except ByLLMError as e {
            caught = e;
        }
        assert isinstance(caught, err) , f"expected {err.__name__}, got {caught!r}";
        assert so1.exhausted() , "every scripted status must have been requested";
    }

    flaky = MockSystemOne(answers=[(429, {}), choose("LOW", 0.9)]);
    assert flaky.invoke(mk_run(resp_type=Priority)) is Priority.LOW , (
        "a 429 followed by a 200 succeeds"
    );
    assert len(flaky.seen) == 2;
}


test "a systemone: model name selects the backend, its endpoint and its caps" {
    assert resolve_model_name("systemone:jev-preview") == ("typesafe", "jev-preview");
    assert resolve_model_name("systemone:laya") == ("laya", "");

    laya = Model(model_name="systemone:laya")._so1_delegate;
    assert isinstance(laya, SystemOneModel) , "the prefix must select the delegate";
    caps = laya._caps;
    assert caps is not None and caps.max_choice_options == 24 , (
        "laya's option cap comes from its provider entry"
    );
    assert laya._endpoint() == "http://localhost:8000/v1/systemone" , laya._endpoint();

    proxy = MockSystemOne(model_name="systemone:litellm/jev-latest", api_key="virtual");
    assert proxy._endpoint() == "http://localhost:4000/typesafe/v1/systemone";
    assert proxy._headers()["Authorization"] == "Bearer virtual";
}


test "the async path answers the same way" {
    so1 = MockSystemOne(answers=[choose("HIGH", 0.96)]);
    assert asyncio.run(so1.ainvoke(mk_run(resp_type=Priority))) is Priority.HIGH;
}


test "visit by select=1 asks one choice over the live frontier and visits the pick" {
    rg.llm = MockSystemOne(answers=[choose("Agent_beta", 0.9)]);

    w = router() spawn _hub(["alpha", "beta"]);

    assert w.visited == ["beta"] , f"got {w.visited}";
    q = questions_of(rg.llm)["value"];
    assert q["type"] == "choice";
    assert set(q["criteria"].keys()) == {"Agent_alpha", "Agent_beta"} , q["criteria"];
}


test "a single-candidate frontier with select=1 is asked one noul, not refused" {
    rg.llm = MockSystemOne(answers=[nouls({"Agent": 0.9})]);

    w = router() spawn _hub(["solo"]);

    assert w.visited == ["solo"] , f"got {w.visited}";
    assert questions_of(rg.llm)["Agent"]["type"] == "noul";
}


test "visit by select=all visits every candidate above the gate, ties in declaration order" {
    rg.llm = MockSystemOne(
        answers=[
            nouls(
                {
                    "Agent_alpha": 0.7,
                    "Agent_beta": 0.9,
                    "Agent_gamma": 0.7,
                    "Agent_delta": 0.1
                }
            )
        ]
    );

    w = collector() spawn _hub(["alpha", "beta", "gamma", "delta"]);

    assert w.visited == ["beta", "alpha", "gamma"] , f"got {w.visited}";
}


test "visit by select=2 fills to two by rank, and takes what exists on a smaller frontier" {
    rg.llm = MockSystemOne(
        answers=[nouls({"Agent_alpha": 0.9, "Agent_beta": 0.3, "Agent_gamma": 0.1})]
    );
    w = duo() spawn _hub(["alpha", "beta", "gamma"]);
    assert w.visited == ["alpha", "beta"] , (
        f"exact N must not come back short when candidates exist, got {w.visited}"
    );

    rg.llm = MockSystemOne(answers=[nouls({"Agent": 0.8})]);
    w2 = duo() spawn _hub(["solo"]);
    assert w2.visited == ["solo"] , f"a frontier smaller than N yields it, got {w2.visited}";
}


test "a (lo, hi) select fills to lo and cuts to hi, at the weakest pick's confidence" {
    run = _site(list[Team]);
    setattr(run, ROUTE_SELECT_ATTR, (1, 2));
    spec = lower(run);
    assert spec is not None;

    (cut, conf) = assemble(
        spec, nouls({"BILLING": 0.7, "SECURITY": 0.9, "PLATFORM": 0.8})
    );
    assert cut == [Team.SECURITY, Team.PLATFORM] and abs(conf - 0.6) < 1e-9 , (
        cut,
        conf
    );

    (filled, conf2) = assemble(
        spec, nouls({"BILLING": 0.2, "SECURITY": 0.1, "PLATFORM": 0.3})
    );
    assert filled == [Team.PLATFORM] and conf2 == 0.0 , (
        f"a filled pick below the gate is zero confidence, got {filled}, {conf2}"
    );
}


test "the compiler's IR words the question: semstrs become instructions and criteria" {
    info = FunctionInfo(
        name="rank",
        semstr="Rank how urgent the ticket is",
        params=[ParamInfo(name="ticket", semstr=None, type_info="str")],
        return_type=_priority_ir()
    );
    spec = lower(_site(Priority, {0: "the site is down"}, info));
    assert spec is not None;

    q = spec.questions["value"];
    assert q.instructions == "Rank how urgent the ticket is" , q.instructions;
    assert q.criteria == {"LOW": "can wait", "HIGH": "urgent now"} , q.criteria;
    assert spec.state == {"ticket": "the site is down"} , (
        f"a positional argument is named from ParamInfo, got {spec.state}"
    );
}


test "field semstrs word each question of an obj, and TypeForm is unwrapped" {
    record = FunctionInfo(
        name="triage",
        semstr="Triage the ticket",
        params=[],
        return_type=ClassInfo(
            name="Triage",
            semstr=None,
            fields=[
                FieldInfo(
                    name="urgency", semstr="How urgent it is", type_info=_priority_ir()
                ),
                FieldInfo(
                    name="needs_human",
                    semstr="Whether a person must look",
                    type_info="bool"
                )
            ],
            base_classes=[],
            methods=[]
        )
    );
    spec = lower(_site(Triage, {}, record));
    assert spec is not None;
    assert spec.questions["urgency"].instructions == "How urgent it is";
    assert spec.questions["urgency"].criteria["HIGH"] == "urgent now";
    assert spec.questions["needs_human"].instructions == "Whether a person must look";

    many = FunctionInfo(
        name="all",
        semstr="Which apply",
        params=[],
        return_type=TypeForm(head="list", args=[_priority_ir()])
    );
    listed = lower(_site(list[Priority], {}, many));
    assert listed is not None;
    assert listed.questions["HIGH"].criteria["true"] == "HIGH: urgent now";

    wrapped = FunctionInfo(
        name="rank",
        semstr="Rank",
        params=[],
        return_type=TypeForm(head="Decision", args=[_priority_ir()])
    );
    enveloped = lower(_site(Decision.__class_getitem__(Priority), {}, wrapped));
    assert enveloped is not None and enveloped.wrap_decision;
    assert enveloped.questions["value"].criteria["LOW"] == "can wait";
}


test "Decision[T] survives the fallback: escalation, refusal and an outage all return the envelope" {
    fb = MockLLM(outputs=[Priority.LOW, Priority.LOW]);
    so1 = MockSystemOne(
        answers=[choose("HIGH", 0.3), (503, {"raw": "down"}), (503, {}), (503, {})],
        fallback=fb,
        min_confidence=0.7
    );

    def rank(ticket: str) -> Decision[Priority] by so1();

    escalated = rank("hmm");
    assert isinstance(escalated, Decision) and escalated.value is Priority.LOW , (
        f"the fallback's answer comes back in the envelope, got {escalated!r}"
    );
    assert escalated.answered_by == "fallback" and escalated.confidence == 0.3 , (
        "it says who answered and keeps the confidence that triggered escalation"
    );

    outage = rank("the site is down");
    assert isinstance(outage, Decision) and outage.value is Priority.LOW , (
        f"an unreachable endpoint routes to the fallback, got {outage!r}"
    );
    assert outage.answered_by == "fallback" and outage.confidence == 0.0;
}


test "a rejected key is raised, not routed to the fallback" {
    so1 = MockSystemOne(answers=[(401, {"error": "bad key"})], fallback=MockLLM());

    raised = False;
    try {
        so1.invoke(mk_run(resp_type=Priority));
    } except AuthenticationError {
        raised = True;
    }
    assert raised , "a bad key is a configuration bug; silent rerouting would hide it";
}


test "the state carries incl_info and the receiver, as the chat prompt does" {
    so1 = MockSystemOne(answers=[choose("HIGH", 0.9)]);

    def rank(ticket: str) -> Priority by so1(incl_info={"customer_tier": "platinum"});

    rank("x");
    assert so1.seen[0]["state"] == {"ticket": "x", "customer_tier": "platinum"} , (
        so1.seen[0]["state"]
    );

    _ticket_so1.answers = [choose("LOW", 0.9)];
    Ticket(text="refund please").rank();
    assert _ticket_so1.seen[-1]["state"]["self"]
        == {"text": "refund please", "tier": "HIGH"} , f"a method's receiver is part of the state, got {_ticket_so1.seen[
        -1
    ]['state']}";
    assert questions_of(_ticket_so1, len(_ticket_so1.seen) - 1)["value"]["instructions"]
        == "rank" , (
        "with no IR the function's name, not the system persona, is the instruction"
    );
}


test "a call carrying conversation history or its own system prompt goes to the fallback" {
    history: list[dict[str, any]] = [];
    fb = MockLLM(outputs=[Priority.LOW, Priority.HIGH]);
    so1 = MockSystemOne(fallback=fb);

    def chat_rank(ticket: str) -> Priority by so1(conversation=history);
    def styled_rank(ticket: str) -> Priority by so1(system_prompt="Be strict.");

    assert chat_rank("x") is Priority.LOW;
    assert styled_rank("y") is Priority.HIGH;
    assert so1.seen == [] , "neither can be expressed as a System One state";
    assert history , "the fallback records the turn in the caller's history";
}


test "a systemone: model never inherits the chat provider's key" {
    before = os.environ.get("TYPESAFE_API_KEY");
    os.environ["TYPESAFE_API_KEY"] = "ts-from-env";
    try {
        configured = Model(
            model_name="systemone:typesafe/jev-latest", config={"api_key": "sk-openai"}
        )._so1_delegate;
        assert configured is not None and configured.api_key == "ts-from-env" , (
            "a model-config api_key belongs to the chat provider and must not be sent"
        );
        explicit = Model(
            model_name="systemone:typesafe/jev-latest", api_key="ts-explicit"
        )._so1_delegate;
        assert explicit is not None and explicit.api_key == "ts-explicit";
    } finally {
        if before is None {
            del os.environ["TYPESAFE_API_KEY"];
        } else {
            os.environ["TYPESAFE_API_KEY"] = before;
        }
    }
}
