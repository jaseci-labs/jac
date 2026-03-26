"""Test on_iteration callback — both ABORT and ABORT_WITH_SUMMARY."""
import from byllm.lib { MockLLM, MockToolCall }
import from byllm.types { IterationAction, IterationContext }

glob tool_calls: int = 0;

def get_data(key: str) -> str {
    global tool_calls;
    tool_calls += 1;
    print(f"get_data called: {key}");
    return f"value_for_{key}";
}

# --- Test 1: ABORT (stop immediately, no summary) ---
def abort_hook(ctx: IterationContext) -> IterationAction {
    print(f"ABORT_HOOK iter={ctx.iteration}");
    if ctx.iteration > 2 {
        print("ABORT_TRIGGERED");
        return IterationAction.ABORT;
    }
    return IterationAction.CONTINUE;
}

def fetch_abort(query: str) -> str by llm(
    tools=[get_data],
    on_iteration=abort_hook
);

# --- Test 2: ABORT_WITH_SUMMARY (stop and ask LLM to summarize) ---
def summary_hook(ctx: IterationContext) -> IterationAction {
    print(f"SUMMARY_HOOK iter={ctx.iteration}");
    if ctx.iteration > 2 {
        print("SUMMARY_TRIGGERED");
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}

def fetch_summary(query: str) -> str by llm(
    tools=[get_data],
    on_iteration=summary_hook
);

# --- Run both tests ---
glob llm: MockLLM = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            # Test 1 (ABORT): iterations 1-2 consume a,b → abort at 3
            MockToolCall(tool=get_data, args={"key": "a"}),
            MockToolCall(tool=get_data, args={"key": "b"}),
            # Test 2 (ABORT_WITH_SUMMARY): iterations 1-2 consume c,d → summary call consumes the string
            MockToolCall(tool=get_data, args={"key": "c"}),
            MockToolCall(tool=get_data, args={"key": "d"}),
            "SUMMARY_OUTPUT"
        ]
    }
);

with entry {
    # Test 1: ABORT
    tool_calls = 0;
    result1 = fetch_abort("get everything");
    print(f"ABORT_TOOLS: {tool_calls}");

    # Test 2: ABORT_WITH_SUMMARY
    tool_calls = 0;
    result2 = fetch_summary("get everything");
    print(f"SUMMARY_TOOLS: {tool_calls}");
    print(f"SUMMARY_RESULT: {result2}");
}
