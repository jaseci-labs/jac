"""Tool use and the ReAct loop: finish_tool, and recovering when a model skips it."""

import from jaclang.byllm.types { IterationAction, IterationContext }
import from jaclang.byllm.lib { MockLLM, MockRawResponse }
import from support { call, fail, finish, mk_run, prompt_text, say, tool_names }

import litellm;


"""A chat message from one person."""
obj Chat {
    has person: str,
        message: str;
}


"""A side-effect tool. Its presence is what causes finish_tool to be auto-added."""
def get_mood(character: str) -> str {
    return "cheerful";
}


test "plain text instead of finish_tool is re-prompted, not accepted" {
    # The gpt-4o failure mode: the model answers conversationally rather than
    # calling finish_tool. invoke should notice, re-prompt with finish_tool
    # forced, and extract the typed result from the second turn.
    line = "Greetings traveller, I have wares to trade!";
    llm = MockLLM(outputs=[say(line), finish({"person": "Merchant", "message": line})]);

    """Generate the NPC's opening line given a player name."""
    def generate_npc_line(player_name: str, npc_name: str) -> Chat by llm(
        tools=[get_mood]
    );

    result = generate_npc_line("Elara", "Merchant");
    assert result.person == "Merchant" , f"got {result!r}";
    assert result.message == line , f"got {result!r}";

    assert len(llm.seen) == 2 , (
        f"expected the plain answer then a recovery turn, got {len(llm.seen)}"
    );
    assert llm.exhausted() , "both scripted turns should have been consumed";
}


test "the answer is extracted however the model delivers it past max iterations" {
    # When max_react_iterations is exceeded byLLM forces a final answer. Some
    # providers reply in plain text, Anthropic replies with a finish_tool call.
    # Both have to yield the same result, and neither may re-run the tools.
    def answers(label: str, final: MockRawResponse) {
        calls = {"wind": 0, "unit": 0};

        def get_live_wind_speed(city: str) -> str {
            calls["wind"] += 1;
            return f"The current wind speed in {city} is about 18-22 km/h.";
        }
        def get_speed_unit -> str {
            calls["unit"] += 1;
            return "km/h";
        }

        llm = MockLLM(
            outputs=[
                call("get_live_wind_speed", {"city": "Puttalam"}),
                call("get_speed_unit", {}),
                final
            ]
        );

        def wind_report(city: str) -> str by llm(
            tools=[get_live_wind_speed, get_speed_unit], max_react_iterations=2
        );

        assert wind_report("Puttalam") == "FINAL_REPORT" , f"{label}: wrong answer";
        assert calls == {"wind": 1, "unit": 1} , (
            f"{label}: each tool runs once, got {calls}"
        );
        assert "final answer" in prompt_text(llm, len(llm.seen) - 1).lower() , (
            f"{label}: the last turn must be the forced-answer prompt"
        );
    }
    for (label, final) in [
        ("plain text", say("FINAL_REPORT")),
        ("finish_tool call", finish("FINAL_REPORT"))
    ] {
        answers(label, final);
    }
}


test "a rejected forced tool choice retries the final answer with automatic selection" {
    unsupported = litellm.exceptions.BadRequestError(
        message='tool_choice: type "tool" and "any" are not supported for this model.',
        model="claude-opus-5-5",
        llm_provider="anthropic"
    );
    llm = MockLLM(outputs=[fail(unsupported), say("FINAL_REPORT")]);
    mt_run = mk_run(tools=[get_mood], call_params={"tool_choice": "required"});

    assert llm._force_final_answer(mt_run) == "FINAL_REPORT";
    assert len(llm.seen) == 2 and llm.exhausted() , (
        f"expected one forced call and one automatic retry, got {len(llm.seen)}"
    );
    assert llm.seen[0]["tool_choice"]
        == {"type": "function", "function": {"name": "finish_tool"}};
    assert llm.seen[1]["tool_choice"] == "auto";
    assert mt_run.call_params["tool_choice"] == "required" , (
        "the caller's tool choice must be restored after the retry"
    );
}


test "an unrelated bad request is not retried as a tool choice failure" {
    unrelated = litellm.exceptions.BadRequestError(
        message="the requested token limit is invalid",
        model="claude-opus-5-5",
        llm_provider="anthropic"
    );
    llm = MockLLM(outputs=[fail(unrelated), say("must not be consumed")]);
    raised: Exception | None = None;
    try {
        llm._force_final_answer(mk_run(tools=[get_mood]));
    } except Exception as e {
        raised = e;
    }

    assert raised is unrelated , f"the original provider error was lost: {raised!r}";
    assert len(llm.seen) == 1 , f"an unrelated bad request was retried: {llm.seen}";
}


test "an on_iteration hook can stop the loop, with or without a summary" {
    # ABORT stops dead; ABORT_WITH_SUMMARY stops and spends one more model call
    # asking for a summary. Both must leave the tools already run untouched.
    def stops(
        label: str,
        action: IterationAction,
        extra_replies: list[MockRawResponse],
        expected: str | None
    ) {
        seen: list[str] = [];

        def get_data(key: str) -> str {
            seen.append(key);
            return f"value_for_{key}";
        }

        fired: list[int] = [];

        def hook(ctx: IterationContext) -> IterationAction {
            if ctx.iteration > 2 {
                fired.append(ctx.iteration);
                return action;
            }
            return IterationAction.CONTINUE;
        }
        llm = MockLLM(
            outputs=[call("get_data", {"key": "a"}), call("get_data", {"key": "b"})]
                + extra_replies
        );

        def fetch(query: str) -> str by llm(tools=[get_data], on_iteration=hook);

        result = fetch("get everything");
        assert fired , f"{label}: the hook never fired";
        assert seen == ["a", "b"] , (
            f"{label}: the loop must stop after the tools already run, got {seen}"
        );
        if expected is not None {
            assert result == expected , f"{label}: got {result!r}";
        }
    }
    stops("ABORT", IterationAction.ABORT, [], None);
    stops(
        "ABORT_WITH_SUMMARY",
        IterationAction.ABORT_WITH_SUMMARY,
        [say("SUMMARY_OUTPUT")],
        "SUMMARY_OUTPUT"
    );
}


glob _calc_llm = MockLLM();

obj Calculator {
    has calls: list[tuple[int, int]] = [];

    def add(num1: int, num2: int) -> int {
        self.calls.append((num1, num2));
        return num1 + num2;
    }

    # The model is named here rather than inline because the tool is a bound
    # method: `self.add` only exists once there is a receiver.
    def eval_expr(expression: str) -> str by _calc_llm(tools=[self.add]);
}


test "a bound method can be a tool, and runs against its own receiver" {
    _calc_llm.outputs.extend([call("add", {"num1": 12, "num2": 34}), say("46")]);
    calc = Calculator();

    assert calc.eval_expr("What is 12 + 34?") == "46";
    assert calc.calls == [(12, 34)] , (
        f"the tool must run against the receiver it was bound to, got {calc.calls}"
    );
    assert "add" in tool_names(_calc_llm.seen[0]) , (
        f"the bound method must be offered as a tool, got {tool_names(
            _calc_llm.seen[0]
        )}"
    );
}
