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
        def cb(record: dict) -> None { }
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
        def cb(record: dict) -> None { }
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
        def cb1(record: dict) -> None { }
        def cb2(record: dict) -> None { }
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
        def capture_cb(record: dict) -> None {
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
        def capture_cb(record: dict) -> None {
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
        def capture_cb(record: dict) -> None {
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
        def bad_cb(record: dict) -> None {
            raise RuntimeError("I broke!");
        }
        def good_cb(record: dict) -> None {
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
        def bad1(record: dict) -> None {
            raise ValueError("bad1");
        }
        def good1(record: dict) -> None {
            results.append("good1");
        }
        def bad2(record: dict) -> None {
            raise TypeError("bad2");
        }
        def good2(record: dict) -> None {
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
        def capture_cb(record: dict) -> None {
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
