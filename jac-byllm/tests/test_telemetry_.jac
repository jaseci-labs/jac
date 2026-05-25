"""Tests for the byllm agent-level telemetry callback registry and emit logic.
"""

import types;
import from byllm.telemetry {
    register_agent_callback,
    _emit_agent_telemetry,
    _agent_callbacks
}

#  Helpers
"""Build a fake mt_run via types.SimpleNamespace (same pattern as test_byllm.jac)."""
def make_fake_mt_run(
    invocation_id: str = "inv-test-001",
    user_prompt: str = "What is 2+2?",
    caller_name: str = "math_solver",
    caller_args: dict | None = None,
    msg_list: list | None = None
) -> types.SimpleNamespace {
    # mt_run.messages[1].content[0].text — used for user_prompt extraction
    msg_content = types.SimpleNamespace(text=user_prompt);
    msg1 = types.SimpleNamespace(content=[msg_content]);

    # mt_run.mtir.caller.__name__ — used for caller_name
    caller = types.SimpleNamespace(__name__=caller_name);
    args = caller_args or {"x": "10", "y": "20"};
    mtir = types.SimpleNamespace(caller=caller, args=args);

    # mt_run.get_msg_list() — used for conversation_history
    history = msg_list
    or [
        {"role": "system", "content": "You are a math expert."},
        {"role": "user", "content": user_prompt}
    ];

    mt = types.SimpleNamespace(
        _invocation_id=invocation_id,
        messages=[types.SimpleNamespace(), msg1],
        mtir=mtir,
        get_msg_list=lambda : history
    );

    return mt;
}

#  1. register_agent_callback — deduplication
test "register_agent_callback adds callback to registry" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    try {
        def cb(record: dict) { }
        register_agent_callback(cb);
        assert len(_agent_callbacks) == 1;
        assert _agent_callbacks[0] is cb;
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "register_agent_callback deduplicates same callback" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    try {
        def cb(record: dict) { }
        register_agent_callback(cb);
        register_agent_callback(cb);  # Register again — should be ignored
        register_agent_callback(cb);  # Third time — still ignored
        assert len(_agent_callbacks) == 1 , f"Expected 1 callback, got {len(
            _agent_callbacks
        )}";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "register_agent_callback allows different callbacks" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    try {
        def cb1(record: dict) { }
        def cb2(record: dict) { }
        register_agent_callback(cb1);
        register_agent_callback(cb2);
        assert len(_agent_callbacks) == 2;
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

#  2. _emit_agent_telemetry — record field extraction
test "emit_agent_telemetry builds record with correct fields" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        mt = make_fake_mt_run(
            invocation_id="inv-field-check",
            user_prompt="What is the capital of France?",
            caller_name="geography_agent",
            caller_args={"country": "France"}
        );

        _emit_agent_telemetry(
            mt,
            "Paris",  # result
            "gpt-4o-mini",  # model_name
            150.0,  # latency_ms
            "success",  # status
            None  # error
        );

        assert len(captured) == 1;
        record = captured[0];

        assert record["invocation_id"] == "inv-field-check";
        assert record["caller_name"] == "geography_agent";
        assert record["model"] == "gpt-4o-mini";
        assert record["latency_ms"] == 150.0;
        assert record["status"] == "success";
        assert record["error"] is None;

        # user_prompt extracted from mt_run.messages[1].content[0].text
        assert record["user_prompt"] == "What is the capital of France?";

        # agent_response is str(result)[:2000]
        assert record["agent_response"] == "Paris";

        # caller_args extracted from mt_run.mtir.args
        assert "country" in record["caller_args"];

        # conversation_history from get_msg_list()
        assert isinstance(record["conversation_history"], list);
        assert len(record["conversation_history"]) == 2;
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "emit_agent_telemetry marks streaming results correctly" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        mt = make_fake_mt_run();
        # Pass a generator as result — should produce "[streaming]"
        gen = (x for x in [1, 2, 3]);

        _emit_agent_telemetry(mt, gen, "gpt-4o", 200.0, "success", None);

        assert len(captured) == 1;
        assert captured[0]["agent_response"] == "[streaming]";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "emit_agent_telemetry includes error string on failure" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        mt = make_fake_mt_run();
        err = ValueError("Rate limit exceeded");
        _emit_agent_telemetry(mt, None, "gpt-4o", 50.0, "error", err);

        assert len(captured) == 1;
        assert captured[0]["status"] == "error";
        assert "Rate limit exceeded" in captured[0]["error"];
        assert captured[0]["agent_response"] == "";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

#  3. _emit_agent_telemetry — failing callback isolation
test "failing callback does not prevent other callbacks from firing" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    results: list = [];
    try {
        def bad_cb(record: dict) {
            raise RuntimeError("I broke!");
        }
        def good_cb(record: dict) {
            results.append(record);
        }

        _agent_callbacks.append(bad_cb);
        _agent_callbacks.append(good_cb);

        mt = make_fake_mt_run(invocation_id="inv-fail-iso");
        _emit_agent_telemetry(mt, "answer", "gpt-4o", 100.0, "success", None);

        # good_cb should still have been called despite bad_cb throwing
        assert len(results) == 1;
        assert results[0]["invocation_id"] == "inv-fail-iso";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "multiple failing callbacks do not suppress any good callbacks" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    results: list = [];
    try {
        def bad1(record: dict) {
            raise ValueError("bad1");
        }
        def good1(record: dict) {
            results.append("good1");
        }
        def bad2(record: dict) {
            raise TypeError("bad2");
        }
        def good2(record: dict) {
            results.append("good2");
        }

        _agent_callbacks.append(bad1);
        _agent_callbacks.append(good1);
        _agent_callbacks.append(bad2);
        _agent_callbacks.append(good2);

        mt = make_fake_mt_run();
        _emit_agent_telemetry(mt, "ok", "gpt-4o", 50.0, "success", None);

        assert "good1" in results;
        assert "good2" in results;
        assert len(results) == 2;
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

#  4. _emit_agent_telemetry — graceful extraction failures
test "emit handles missing mt_run fields gracefully" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        # Minimal mt_run with empty messages and no mtir — SimpleNamespace, no MagicMock
        def fail_get_msg_list -> list {
            raise Exception("no messages");
        }
        mt = types.SimpleNamespace(
            _invocation_id="inv-minimal",
            messages=[],
            mtir=None,
            get_msg_list=fail_get_msg_list
        );

        _emit_agent_telemetry(mt, "fallback", "gpt-4o", 80.0, "success", None);

        assert len(captured) == 1;
        record = captured[0];
        assert record["invocation_id"] == "inv-minimal";
        assert record["caller_name"] == "unknown";
        assert record["user_prompt"] == "";
        assert record["conversation_history"] == [];
        assert record["agent_response"] == "fallback";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

#  5. parent_invocation_id — ContextVar propagation
test "emit record includes parent_invocation_id when set on mt_run" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        mt = make_fake_mt_run(invocation_id="child-inv-001");
        mt._parent_invocation_id = "parent-inv-001";

        _emit_agent_telemetry(mt, "result", "gpt-4o", 100.0, "success", None);

        assert len(captured) == 1;
        assert captured[0]["parent_invocation_id"] == "parent-inv-001";
        assert captured[0]["invocation_id"] == "child-inv-001";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

test "emit record has None parent_invocation_id for root calls" {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        mt = make_fake_mt_run(invocation_id="root-inv-001");
        # No _parent_invocation_id set — simulates root call
        _emit_agent_telemetry(mt, "result", "gpt-4o", 100.0, "success", None);

        assert len(captured) == 1;
        assert captured[0]["parent_invocation_id"] is None;
        assert captured[0]["invocation_id"] == "root-inv-001";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}

#  6. ContextVar integration — verifies get/set/reset cycle across nested invocations
test "ContextVar chains correctly across simulated nested Model.invoke calls" {
    import from byllm.telemetry { _current_invocation_id }
    import uuid;

    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        # --- Simulate outer Model.invoke ---
        outer_mt = make_fake_mt_run(caller_name="outer_agent");
        outer_mt._parent_invocation_id = _current_invocation_id.get(None);
        outer_mt._invocation_id = "outer-id-001";
        outer_token = _current_invocation_id.set(outer_mt._invocation_id);

        # At this point, ContextVar == "outer-id-001"
        assert _current_invocation_id.get() == "outer-id-001";
        assert outer_mt._parent_invocation_id is None;  # root call

        # --- Simulate inner Model.invoke (nested by llm() tool call) ---
        inner_mt = make_fake_mt_run(caller_name="inner_agent");
        inner_mt._parent_invocation_id = _current_invocation_id.get(None);
        inner_mt._invocation_id = "inner-id-001";
        inner_token = _current_invocation_id.set(inner_mt._invocation_id);

        # Inner should see outer as parent
        assert inner_mt._parent_invocation_id == "outer-id-001";
        assert _current_invocation_id.get() == "inner-id-001";

        # --- Simulate deepest Model.invoke (3-level nesting) ---
        deep_mt = make_fake_mt_run(caller_name="deep_agent");
        deep_mt._parent_invocation_id = _current_invocation_id.get(None);
        deep_mt._invocation_id = "deep-id-001";
        deep_token = _current_invocation_id.set(deep_mt._invocation_id);

        assert deep_mt._parent_invocation_id == "inner-id-001";
        assert _current_invocation_id.get() == "deep-id-001";

        # Emit deepest, then unwind
        _emit_agent_telemetry(deep_mt, "deep-result", "gpt-4o", 50.0, "success", None);
        _current_invocation_id.reset(deep_token);
        assert _current_invocation_id.get() == "inner-id-001";  # restored

        # Emit inner, then unwind
        _emit_agent_telemetry(
            inner_mt, "inner-result", "gpt-4o", 100.0, "success", None
        );
        _current_invocation_id.reset(inner_token);
        assert _current_invocation_id.get() == "outer-id-001";  # restored

        # Emit outer, then unwind
        _emit_agent_telemetry(
            outer_mt, "outer-result", "gpt-4o", 200.0, "success", None
        );
        _current_invocation_id.reset(outer_token);
        assert _current_invocation_id.get(None) is None;  # fully restored

        # --- Verify the emitted records ---
        assert len(captured) == 3;

        deep_rec = [
            r
            for r in captured
            if r["invocation_id"] == "deep-id-001"
        ][0];
        inner_rec = [
            r
            for r in captured
            if r["invocation_id"] == "inner-id-001"
        ][0];
        outer_rec = [
            r
            for r in captured
            if r["invocation_id"] == "outer-id-001"
        ][0];

        # Parent chain: deep → inner → outer → None
        assert deep_rec["parent_invocation_id"] == "inner-id-001";
        assert inner_rec["parent_invocation_id"] == "outer-id-001";
        assert outer_rec["parent_invocation_id"] is None;
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
        # Safety: ensure ContextVar is clean even if test fails mid-way
        _current_invocation_id.set(None);  # type: ignore
    }
}

test "ContextVar resets correctly even when inner invocation raises" {
    import from byllm.telemetry { _current_invocation_id }

    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    captured: list = [];
    try {
        def capture_cb(record: dict) {
            captured.append(record);
        }
        _agent_callbacks.append(capture_cb);

        # Outer invoke
        outer_mt = make_fake_mt_run(caller_name="outer");
        outer_mt._parent_invocation_id = _current_invocation_id.get(None);
        outer_mt._invocation_id = "outer-err-001";
        outer_token = _current_invocation_id.set(outer_mt._invocation_id);

        # Inner invoke that "fails"
        inner_mt = make_fake_mt_run(caller_name="inner");
        inner_mt._parent_invocation_id = _current_invocation_id.get(None);
        inner_mt._invocation_id = "inner-err-001";
        inner_token = _current_invocation_id.set(inner_mt._invocation_id);

        # Simulate error path: emit with error, then reset (like finally block)
        _emit_agent_telemetry(
            inner_mt, None, "gpt-4o", 30.0, "error", ValueError("boom")
        );
        _current_invocation_id.reset(inner_token);

        # Outer should still be active
        assert _current_invocation_id.get() == "outer-err-001";

        _emit_agent_telemetry(outer_mt, "ok", "gpt-4o", 100.0, "success", None);
        _current_invocation_id.reset(outer_token);

        assert _current_invocation_id.get(None) is None;

        # Check records
        inner_rec = [
            r
            for r in captured
            if r["invocation_id"] == "inner-err-001"
        ][0];
        outer_rec = [
            r
            for r in captured
            if r["invocation_id"] == "outer-err-001"
        ][0];

        assert inner_rec["parent_invocation_id"] == "outer-err-001";
        assert inner_rec["status"] == "error";
        assert outer_rec["parent_invocation_id"] is None;
        assert outer_rec["status"] == "success";
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
        _current_invocation_id.set(None);  # type: ignore
    }
}
