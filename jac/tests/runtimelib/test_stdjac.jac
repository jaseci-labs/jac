"""stdjac on jac's runtime: what neojac programs import, behaving as they expect.

`codec.encode` writes an enum member by name whatever its base, and an object's
fields down its whole class hierarchy. `llm(...)` configures one call without
touching the shared model or another call in flight, and hands byllm's model the
call rebuilt without the conversation parameter the plugin was given whole.
"""

import os;
import from jaclang.byllm.lib { MTIR }
import from stdjac.codec { encode }
import from stdjac.llm { Message, Part, PartKind, _the_model, llm }

enum Shade: str {
    LIGHT = "light",
    DARK = "dark",
}

enum Rank: int {
    LOW = 1,
    HIGH = 2,
}

obj Base {
    has id: str = "b";
}

obj Child(Base) {
    has extra: int = 1;
}

def ask(question: str, conversation: list[Message]) -> str {
    return "";
}

test "codec encodes enum members by name and fields across the hierarchy" {
    assert encode(Shade.DARK) == "DARK" , encode(Shade.DARK);
    assert encode(Rank.HIGH) == "HIGH" , encode(Rank.HIGH);
    assert encode({"k": Rank.LOW}) == {"k": "LOW"};
    assert encode(Child()) == {"id": "b", "extra": 1} , encode(Child());
}

test "llm configures each call apart from the shared model and from other calls" {
    os.environ["JAC_LLM_MODEL"] = "mockllm";
    try {
        first = llm(max_tokens=1);
        second = llm(max_tokens=2, num_retries=3);
        assert first is not second;
        assert first.call_params["max_tokens"] == 1 , first.call_params;
        assert second.call_params["num_retries"] == 3 , second.call_params;
        assert first.call_params["num_retries"] == 0 , first.call_params;
        assert _the_model().call_params == {} , _the_model().call_params;
        assert first._request_retries() == 0 and second._request_retries() == 3;
    } finally {
        del os.environ["JAC_LLM_MODEL"];
    }
}

test "the conversation a call continues is kept out of the model's inputs" {
    os.environ["JAC_LLM_MODEL"] = "mockllm";
    try {
        conv = [Message(role="user", parts=[Part(kind=PartKind.TEXT, text="earlier turn")])];
        call = llm(conversation=conv);
        assert call.plugin_args == [conv];
        run = MTIR(ask, {0: "now", 1: conv}, call.call_params, None).runtime;
        assert set(run.mtir.args.keys()) == {0, 1};
        prepared = call._prepared(run);
        assert prepared is not run;
        assert set(prepared.mtir.args.keys()) == {0} , prepared.mtir.args;
        plain = MTIR(ask, {0: "now"}, llm().call_params, None).runtime;
        assert llm()._prepared(plain) is plain;
    } finally {
        del os.environ["JAC_LLM_MODEL"];
    }
}
