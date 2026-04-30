"""Streaming + conversation regression: covers two bugs.

(1) write_back must run after the streaming generator exhausts so the final
    assistant message is in history.
(2) Conversation entries are always persisted as dicts, regardless of seed
    type (empty / dict / Message).
"""
import from byllm.lib { MockLLM, MockToolCall, Message, MessageRole }


def get_weather(city: str) -> str {
    return f"sunny in {city}";
}


def finish_tool(final_output: str) -> str {
    return final_output;
}


def outputs -> list {
    return [
        MockToolCall(tool=get_weather, args={"city": "Paris"}),
        MockToolCall(tool=finish_tool, args={"final_output": "Paris is sunny."}),
        "Paris is sunny right now."
    ];
}


def outputs_two_turns -> list {
    return [
        # Turn 1: tool call + finish + streamed answer
        MockToolCall(tool=get_weather, args={"city": "Paris"}),
        MockToolCall(tool=finish_tool, args={"final_output": "Paris is sunny."}),
        "Paris is sunny right now.",
        # Turn 2: model uses prior tool result; finish + streamed answer
        MockToolCall(tool=finish_tool, args={"final_output": "Yes, still sunny."}),
        "Yes, Paris is still sunny."
    ];
}


glob llm_empty = MockLLM(model_name="mockllm", config={"outputs": outputs()}),
     llm_dict = MockLLM(model_name="mockllm", config={"outputs": outputs()}),
     llm_msg = MockLLM(model_name="mockllm", config={"outputs": outputs()}),
     llm_multi = MockLLM(model_name="mockllm", config={"outputs": outputs_two_turns()});

glob h_empty: list = [],
     h_dict: list = [{"role": "user", "content": "PRIOR_DICT"}],
     h_msg: list = [Message(role=MessageRole.USER, content="PRIOR_MESSAGE")],
     h_multi: list = [];


def ask_e(message: str) -> str by llm_empty(
    tools=[get_weather], conversation=h_empty, stream=True
);

def ask_d(message: str) -> str by llm_dict(
    tools=[get_weather], conversation=h_dict, stream=True
);

def ask_m(message: str) -> str by llm_msg(
    tools=[get_weather], conversation=h_msg, stream=True
);

def ask_multi(message: str) -> str by llm_multi(
    tools=[get_weather], conversation=h_multi, stream=True
);


def assert_dict_history_with_assistant(label: str, history: list, expected: str) {
    for m in history {
        assert isinstance(m, dict) , f"[{label}] expected dict, got {type(m).__name__}";
    }
    asst = [
        str(m.get("content", ""))
        for m in history
        if m.get("role") == "assistant"
    ];
    assert asst , f"[{label}] streamed assistant message missing from history";
    assert any(expected in c for c in asst) , (
        f"[{label}] streamed answer not in history: {asst}"
    );
}


glob full = "";
with entry {
    for tok in ask_e("How is Paris?") {
        full += tok;
    }
    assert_dict_history_with_assistant("empty seed", h_empty, full);

    for tok in ask_d("How is Paris?") {
        tok;
    }
    assert_dict_history_with_assistant("dict seed", h_dict, full);

    for tok in ask_m("How is Paris?") {
        tok;
    }
    assert_dict_history_with_assistant("Message seed", h_msg, full);
}

# Same `ask` called twice — history must grow and both streamed answers must persist.
glob s1 = "";
with entry {
    for tok in ask_multi("How is Paris?") {
        s1 += tok;
    }
    assert_dict_history_with_assistant("multi-turn t1", h_multi, s1);
}

glob len_after_t1 = len(h_multi),
     s2 = "";

with entry {
    for tok in ask_multi("Still sunny?") {
        s2 += tok;
    }
    assert len(h_multi) > len_after_t1 , (
        f"history did not grow on turn 2: was {len_after_t1}, now {len(h_multi)}"
    );
    assert_dict_history_with_assistant("multi-turn t2 (s1)", h_multi, s1);
    assert_dict_history_with_assistant("multi-turn t2 (s2)", h_multi, s2);
}

glob asst_count = len(
         [
             m
             for m in h_multi
             if m.get("role") == "assistant"
         ]
     ),
     user_count = len(
         [
             m
             for m in h_multi
             if m.get("role") == "user"
         ]
     );

with entry {
    assert asst_count == 2 , f"expected 2 assistant msgs, got {asst_count}";
    assert user_count == 2 , f"expected 2 user msgs, got {user_count}";

    print("STREAM_CONV_PASS");
}
