"""Tool use and the ReAct loop: finish_tool, and recovering when a model skips it."""

import from jaclang.byllm.types { IterationAction, IterationContext }
import from support_tests { FakeLLM, call, finish, prompt_text, say, tool_names }


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
    llm = FakeLLM(replies=[say(line), finish({"person": "Merchant", "message": line})]);

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
    for (label, final) in [
        ("plain text", say("FINAL_REPORT")),
        ("finish_tool call", finish("FINAL_REPORT"))
    ] {
        calls = {"wind": 0, "unit": 0};

        def get_live_wind_speed(city: str) -> str {
            calls["wind"] += 1;
            return f"The current wind speed in {city} is about 18-22 km/h.";
        }
        def get_speed_unit -> str {
            calls["unit"] += 1;
            return "km/h";
        }

        llm = FakeLLM(
            replies=[
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
}


test "an on_iteration hook can stop the loop, with or without a summary" {
    # ABORT stops dead; ABORT_WITH_SUMMARY stops and spends one more model call
    # asking for a summary. Both must leave the tools already run untouched.
    for (label, action, extra_replies, expected) in [
        ("ABORT", IterationAction.ABORT, [], None),
        (
            "ABORT_WITH_SUMMARY",
            IterationAction.ABORT_WITH_SUMMARY,
            [say("SUMMARY_OUTPUT")],
            "SUMMARY_OUTPUT"
        )
    ] {
        seen: list = [];

        def get_data(key: str) -> str {
            seen.append(key);
            return f"value_for_{key}";
        }

        fired: list = [];

        def hook(ctx: IterationContext) -> IterationAction {
            if ctx.iteration > 2 {
                fired.append(ctx.iteration);
                return action;
            }
            return IterationAction.CONTINUE;
        }
        llm = FakeLLM(
            replies=[call("get_data", {"key": "a"}), call("get_data", {"key": "b"})]
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
}


glob _calc_llm = FakeLLM();

obj Calculator {
    has calls: list = [];

    def add(num1: int, num2: int) -> int {
        self.calls.append((num1, num2));
        return num1 + num2;
    }

    # The model is named here rather than inline because the tool is a bound
    # method: `self.add` only exists once there is a receiver.
    def eval_expr(expression: str) -> str by _calc_llm(tools=[self.add]);
}


test "a bound method can be a tool, and runs against its own receiver" {
    _calc_llm.replies.extend([call("add", {"num1": 12, "num2": 34}), say("46")]);
    _calc_llm.postinit();
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
