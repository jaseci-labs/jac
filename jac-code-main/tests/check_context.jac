"""Phase 3 tests: smart context management and compaction."""

import from jac_coder.context {
    estimate_tokens,
    needs_compaction,
    build_context,
    ContextConfig
}


def make_turn(i: int, content_size: int = 400, files: list = []) -> list[dict] {
    user = {"role": "user", "content": f"Turn {i}: " + "x" * content_size};
    asst = {
        "role": "assistant",
        "content": f"Done {i}: " + "y" * content_size,
        "files_modified": files
    };
    return [user, asst];
}


with entry {
    # Test 1: estimate_tokens basic heuristic
    msgs = [
        {"role": "user", "content": "a" * 400},
        {"role": "assistant", "content": "b" * 400}
    ];
    tokens = estimate_tokens(msgs);
    assert tokens == 200 , f"estimate_tokens: expected 200, got {tokens}";
    print("estimate_tokens basic: OK");

    # Test 2: needs_compaction short vs long
    short = [{"role": "user", "content": "hi"}, {"role": "assistant", "content": "ok"}];
    assert not needs_compaction(short, 20000) , "Short messages should not need compaction";
    long_msgs = [{"role": "user", "content": "x" * 5000}] * 5;
    assert needs_compaction(long_msgs, 5000) , "Long messages should need compaction";
    print("needs_compaction short/long: OK");

    # Test 3: short history passes through unchanged (no compaction, no prefix)
    history = make_turn(0) + make_turn(1);
    result = build_context(history);
    assert len(result) == 4 , f"Short history should pass through: expected 4 msgs, got {len(
        result
    )}";
    assert result[0]["role"] == "user";
    assert result[3]["role"] == "assistant";
    print("build_context passthrough: OK");

    # Test 4: active_files prefix prepended
    result = build_context(history, active_files=["auth.jac", "main.jac"]);
    assert len(result) == 5 , f"Should have prefix + 4 msgs: got {len(result)}";
    assert result[0]["role"] == "system";
    assert "auth.jac" in result[0]["content"];
    assert "main.jac" in result[0]["content"];
    print("build_context active_files prefix: OK");

    # Test 5: pending_errors prefix prepended
    result = build_context(history, pending_errors=["Type error in auth.jac line 5"]);
    assert result[0]["role"] == "system";
    assert "Type error in auth.jac line 5" in result[0]["content"];
    print("build_context pending_errors prefix: OK");

    # Test 6: compaction preserves recent turns verbatim
    # 20 messages (10 turns), each 400 chars -> 8000 chars -> 2000 tokens
    # budget=2000 -> threshold=1600 -> compaction triggers
    # recent_window=5 -> keeps last 5 turns (10 msgs)
    long_history = [];
    for i in range(10) {
        long_history.extend(make_turn(i));
    }
    cfg = ContextConfig(recent_window=5, token_budget=2000);
    result = build_context(long_history, config=cfg);
    last_user_content = long_history[-2]["content"];
    last_asst_content = long_history[-1]["content"];
    found_last_user = any(msg.get("content") == last_user_content for msg in result);
    found_last_asst = any(msg.get("content") == last_asst_content for msg in result);
    assert found_last_user , "Most recent user turn must be preserved verbatim";
    assert found_last_asst , "Most recent assistant turn must be preserved verbatim";
    print("build_context preserves recent turns: OK");

    # Test 7: compaction preserves session goal (first user message)
    history_with_files = [];
    for i in range(10) {
        files = ["auth.jac"] if i == 2 else [];
        history_with_files.extend(make_turn(i, files=files));
    }
    cfg = ContextConfig(recent_window=5, token_budget=2000);
    result = build_context(history_with_files, config=cfg);
    sys_msgs = [msg for msg in result if msg.get("role") == "system"];
    has_goal = any("Session goal" in msg.get("content", "") for msg in sys_msgs);
    assert has_goal , "Compacted result must include session goal from first user message";
    print("build_context preserves session goal: OK");

    # Test 8: compaction adds summary entry for older turns
    plain_history = [];
    for i in range(10) {
        plain_history.extend(make_turn(i));
    }
    cfg = ContextConfig(recent_window=5, token_budget=2000);
    result = build_context(plain_history, config=cfg);
    sys_msgs = [msg for msg in result if msg.get("role") == "system"];
    has_summary = any(
        "Summary of previous work" in msg.get("content", "")
        or "earlier turns" in msg.get("content", "")
        for msg in sys_msgs
    );
    assert has_summary , f"Compacted result must include a summary of older turns";
    print("build_context summary entry: OK");

    # Test 9: empty history handled gracefully
    result = build_context([]);
    assert result == [] , f"Empty history should return empty list: got {result}";
    result = build_context([], active_files=["x.jac"]);
    assert len(result) == 1 and result[0]["role"] == "system";
    print("build_context empty history: OK");

    print("\n=== All context tests passed! ===");
}
