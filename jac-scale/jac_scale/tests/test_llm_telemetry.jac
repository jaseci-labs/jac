"""Tests for TelemetryStore — the core of the LLM telemetry feature.

All tests instantiate TelemetryStore directly
"""
import time;
import json;
import from jac_scale.admin.llm_telemetry { TelemetryStore, LLMCallRecord, Trace }

#  Helpers
"""Build a minimal LLM event dict for record_llm_event."""
def make_llm_event(
    inv_id: str = "inv-001",
    caller_name: str = "test_caller",
    model: str = "gpt-4o-mini",
    prompt_tokens: int = 100,
    completion_tokens: int = 50,
    total_tokens: int = 150,
    response_cost: float = 0.0001,
    response_time: float = 0.5,
    messages: list | None = None,
    response: dict | str | None = None
) -> dict {
    return {
        "id": f"call-{inv_id}",
        "model": model,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": total_tokens,
        "response_cost": response_cost,
        "response_time": response_time,
        "status": "success",
        "error_str": None,
        "startTime": time.time(),
        "messages": messages
        or [
            {"role": "system", "content": "You are helpful."},
            {"role": "user", "content": "Hello"}
        ],
        "response": response or {"choices": [{"message": {"content": "Hi there"}}]},
        "metadata": {"jac_invocation_id": inv_id, "jac_caller_name": caller_name}
    };
}

"""Build a minimal agent completion record for record_agent_completion."""
def make_agent_record(
    inv_id: str = "inv-001",
    caller_name: str = "test_caller",
    model: str = "gpt-4o-mini",
    user_prompt: str = "Hello",
    agent_response: str = "Hi there",
    status: str = "success",
    latency_ms: float = 500.0,
    conversation_history: list | None = None,
    caller_args: dict | None = None
) -> dict {
    return {
        "invocation_id": inv_id,
        "caller_name": caller_name,
        "caller_args": caller_args or {"name": "test"},
        "user_prompt": user_prompt,
        "agent_response": agent_response,
        "conversation_history": conversation_history
        or [{"role": "system", "content": "sys"}, {"role": "user", "content": "Hello"}],
        "model": model,
        "latency_ms": latency_ms,
        "status": status,
        "error": None
    };
}

#  1. record_llm_event
test "record_llm_event creates trace with correct fields" {
    store = TelemetryStore();
    event = make_llm_event(
        inv_id="inv-100",
        caller_name="get_personality",
        model="gpt-4o-mini",
        prompt_tokens=128,
        completion_tokens=7,
        total_tokens=135,
        response_cost=0.000023
    );
    store.record_llm_event(event);

    traces = store.get_traces();
    assert traces["total"] == 1;

    trace = traces["traces"][0];
    assert trace["invocation_id"] == "inv-100";
    assert trace["caller_name"] == "get_personality";
    assert trace["model"] == "gpt-4o-mini";
    assert trace["total_tokens"] == 135;
    assert trace["total_cost"] == 0.000023;
    assert trace["llm_call_count"] == 1;
}

test "record_llm_event accumulates multiple calls in same trace" {
    store = TelemetryStore();

    # First LLM call in the ReAct loop
    store.record_llm_event(
        make_llm_event(inv_id="inv-200", total_tokens=100, response_cost=0.0001)
    );
    # Second LLM call (tool result → next turn)
    store.record_llm_event(
        make_llm_event(inv_id="inv-200", total_tokens=80, response_cost=0.00008)
    );

    traces = store.get_traces();
    assert traces["total"] == 1;

    trace = traces["traces"][0];
    assert trace["llm_call_count"] == 2;
    assert trace["total_tokens"] == 180;
    assert round(trace["total_cost"], 6) == 0.00018;
}

test "record_llm_event truncates messages over 20" {
    store = TelemetryStore();
    # Build 25 messages
    big_messages = [{"role": "user", "content": f"msg-{i}"} for i in range(25)];
    event = make_llm_event(inv_id="inv-trunc", messages=big_messages);
    store.record_llm_event(event);

    detail = store.get_trace("inv-trunc");
    # Should keep only last 20
    stored_msgs = detail["llm_calls"][0]["messages"];
    assert len(stored_msgs) == 20;
    # Should be the LAST 20 (msg-5 through msg-24)
    assert stored_msgs[0]["content"] == "msg-5";
    assert stored_msgs[-1]["content"] == "msg-24";
}

test "record_llm_event truncates response over 10KB" {
    store = TelemetryStore();
    # Build a response >10KB
    large_response = {"data": "x" * 15000};
    event = make_llm_event(inv_id="inv-bigr", response=large_response);
    store.record_llm_event(event);

    detail = store.get_trace("inv-bigr");
    stored_resp = detail["llm_calls"][0]["response"];
    # Should be truncated string ending with ...[truncated]
    assert isinstance(stored_resp, str);
    assert stored_resp.endswith("...[truncated]");
    assert len(stored_resp) <= 10240 + 20;
}

#  2. record_agent_completion
test "record_agent_completion finalizes existing trace" {
    store = TelemetryStore();

    # First: LLM call creates the trace
    store.record_llm_event(make_llm_event(inv_id="inv-300"));
    # Then: agent callback finalizes it
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-300",
            caller_name="summarize",
            user_prompt="Summarize this",
            agent_response="Done."
        )
    );

    trace = store.get_trace("inv-300");
    assert trace["completed"] is True;
    assert trace["caller_name"] == "summarize";
    assert trace["user_prompt"] == "Summarize this";
    assert trace["agent_response"] == "Done.";
    assert trace["status"] == "success";
}

test "record_agent_completion creates trace when no prior LLM calls (MockLLM path)" {
    store = TelemetryStore();

    # No record_llm_event first — simulates MockLLM or proxy
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-mock",
            caller_name="mock_caller",
            agent_response="mocked answer"
        )
    );

    traces = store.get_traces();
    assert traces["total"] == 1;

    trace = traces["traces"][0];
    assert trace["invocation_id"] == "inv-mock";
    assert trace["caller_name"] == "mock_caller";
    assert trace["agent_response"] == "mocked answer";
    assert trace["completed"] is True;
}

test "record_agent_completion caps conversation history at 40" {
    store = TelemetryStore();
    store.record_llm_event(make_llm_event(inv_id="inv-cap"));

    # Build 60-message conversation history
    big_history = [{"role": "user", "content": f"msg-{i}"} for i in range(60)];
    store.record_agent_completion(
        make_agent_record(inv_id="inv-cap", conversation_history=big_history)
    );

    detail = store.get_trace("inv-cap");
    history = detail["conversation_history"];
    assert len(history) == 40;
    # Should keep last 40 (msg-20 through msg-59)
    assert history[0]["content"] == "msg-20";
    assert history[-1]["content"] == "msg-59";
}

test "record_agent_completion caps history at 40 for MockLLM path too" {
    store = TelemetryStore();
    big_history = [{"role": "user", "content": f"m-{i}"} for i in range(50)];
    store.record_agent_completion(
        make_agent_record(inv_id="inv-cap2", conversation_history=big_history)
    );

    detail = store.get_trace("inv-cap2");
    history = detail["conversation_history"];
    assert len(history) == 40;
}

#  3. _backfill_streaming_response
test "backfill streaming response with finish_tool in last call" {
    store = TelemetryStore();

    # Simulate an LLM call whose response has finish_tool
    event = make_llm_event(
        inv_id="inv-stream",
        response={
            "choices": [
                {
                    "message": {
                        "content": None,
                        "tool_calls": [
                            {
                                "function": {
                                    "name": "finish_tool",
                                    "arguments": "{\"final_output\": \"Paris is the capital.\"}"
                                }
                            }
                        ]
                    }
                }
            ]
        }
    );
    store.record_llm_event(event);

    # Agent callback says [streaming]
    store.record_agent_completion(
        make_agent_record(inv_id="inv-stream", agent_response="[streaming]")
    );

    # get_traces triggers backfill
    traces = store.get_traces();
    trace = traces["traces"][0];
    assert trace["agent_response"] == "Paris is the capital.";
}

test "backfill streaming response with direct text content" {
    store = TelemetryStore();

    event = make_llm_event(
        inv_id="inv-stream2",
        response={
            "choices": [
                {"message": {"content": "Direct text answer", "tool_calls": None}}
            ]
        }
    );
    store.record_llm_event(event);

    store.record_agent_completion(
        make_agent_record(inv_id="inv-stream2", agent_response="[streaming]")
    );

    traces = store.get_traces();
    trace = traces["traces"][0];
    assert trace["agent_response"] == "Direct text answer";
}

test "backfill does nothing for non-streaming response" {
    store = TelemetryStore();

    store.record_llm_event(make_llm_event(inv_id="inv-normal"));
    store.record_agent_completion(
        make_agent_record(inv_id="inv-normal", agent_response="Normal answer")
    );

    traces = store.get_traces();
    trace = traces["traces"][0];
    # Should stay as "Normal answer", NOT be overwritten by backfill
    assert trace["agent_response"] == "Normal answer";
}

#  4. get_traces / get_trace — pagination & filtering
test "get_traces pagination with limit and offset" {
    store = TelemetryStore();

    # Insert 5 traces
    for i in range(5) {
        store.record_llm_event(make_llm_event(inv_id=f"inv-page-{i}"));
        store.record_agent_completion(make_agent_record(inv_id=f"inv-page-{i}"));
    }

    # Get first 2
    result = store.get_traces(limit=2, offset=0);
    assert len(result["traces"]) == 2;
    assert result["total"] == 5;
    assert result["has_more"] is True;

    # Get next 2
    result2 = store.get_traces(limit=2, offset=2);
    assert len(result2["traces"]) == 2;
    assert result2["has_more"] is True;

    # Get last 1
    result3 = store.get_traces(limit=2, offset=4);
    assert len(result3["traces"]) == 1;
    assert result3["has_more"] is False;
}

test "get_traces filter by model" {
    store = TelemetryStore();

    store.record_llm_event(make_llm_event(inv_id="inv-m1", model="gpt-4o"));
    store.record_llm_event(make_llm_event(inv_id="inv-m2", model="gpt-4o-mini"));
    store.record_llm_event(make_llm_event(inv_id="inv-m3", model="gpt-4o"));

    result = store.get_traces(model="gpt-4o");
    assert result["total"] == 2;
    for t in result["traces"] {
        assert t["model"] == "gpt-4o";
    }
}

test "get_traces filter by status" {
    store = TelemetryStore();

    store.record_llm_event(make_llm_event(inv_id="inv-s1"));
    store.record_agent_completion(make_agent_record(inv_id="inv-s1", status="success"));

    store.record_llm_event(make_llm_event(inv_id="inv-s2"));
    store.record_agent_completion(make_agent_record(inv_id="inv-s2", status="error"));

    result = store.get_traces(status="error");
    assert result["total"] == 1;
    assert result["traces"][0]["status"] == "error";
}

test "get_traces filter by caller" {
    store = TelemetryStore();

    store.record_llm_event(make_llm_event(inv_id="inv-c1", caller_name="agent_a"));
    store.record_llm_event(make_llm_event(inv_id="inv-c2", caller_name="agent_b"));
    store.record_llm_event(make_llm_event(inv_id="inv-c3", caller_name="agent_a"));

    result = store.get_traces(caller="agent_a");
    assert result["total"] == 2;
    for t in result["traces"] {
        assert t["caller_name"] == "agent_a";
    }
}

test "get_trace returns full detail with conversation_history and llm_calls" {
    store = TelemetryStore();

    store.record_llm_event(make_llm_event(inv_id="inv-detail"));
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-detail",
            conversation_history=[{"role": "user", "content": "test"}]
        )
    );

    detail = store.get_trace("inv-detail");
    assert detail is not None;
    assert "conversation_history" in detail;
    assert "llm_calls" in detail;
    assert len(detail["llm_calls"]) == 1;
    assert detail["llm_calls"][0]["call_id"] == "call-inv-detail";
}

test "get_trace returns None for missing invocation_id" {
    store = TelemetryStore();
    assert store.get_trace("nonexistent") is None;
}

#  5. get_summary — aggregation math
test "get_summary aggregates tokens cost and errors correctly" {
    store = TelemetryStore();

    # Trace 1: gpt-4o, success, 200 tokens, cost 0.001
    store.record_llm_event(
        make_llm_event(
            inv_id="inv-sum1", model="gpt-4o", total_tokens=200, response_cost=0.001
        )
    );
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-sum1", model="gpt-4o", status="success", latency_ms=500.0
        )
    );

    # Trace 2: gpt-4o-mini, error, 100 tokens, cost 0.0002
    store.record_llm_event(
        make_llm_event(
            inv_id="inv-sum2",
            model="gpt-4o-mini",
            total_tokens=100,
            response_cost=0.0002
        )
    );
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-sum2", model="gpt-4o-mini", status="error", latency_ms=300.0
        )
    );

    # Trace 3: gpt-4o, success, 150 tokens, cost 0.0005
    store.record_llm_event(
        make_llm_event(
            inv_id="inv-sum3", model="gpt-4o", total_tokens=150, response_cost=0.0005
        )
    );
    store.record_agent_completion(
        make_agent_record(
            inv_id="inv-sum3", model="gpt-4o", status="success", latency_ms=400.0
        )
    );

    summary = store.get_summary();
    assert summary["total_invocations"] == 3;
    assert summary["total_llm_calls"] == 3;
    assert summary["total_tokens"] == 450;
    assert summary["total_cost"] == round(0.001 + 0.0002 + 0.0005, 6);
    assert summary["error_count"] == 1;

    # Per-model
    assert summary["per_model"]["gpt-4o"]["calls"] == 2;
    assert summary["per_model"]["gpt-4o"]["tokens"] == 350;
    assert summary["per_model"]["gpt-4o"]["errors"] == 0;
    assert summary["per_model"]["gpt-4o-mini"]["calls"] == 1;
    assert summary["per_model"]["gpt-4o-mini"]["tokens"] == 100;
    assert summary["per_model"]["gpt-4o-mini"]["errors"] == 1;

    # Per-caller
    assert summary["per_caller"]["test_caller"]["calls"] == 3;
    assert summary["per_caller"]["test_caller"]["tokens"] == 450;
}

test "get_summary returns zeros when store is empty" {
    store = TelemetryStore();
    summary = store.get_summary();
    assert summary["total_invocations"] == 0;
    assert summary["total_llm_calls"] == 0;
    assert summary["total_tokens"] == 0;
    assert summary["total_cost"] == 0.0;
    assert summary["avg_latency_ms"] == 0.0;
    assert summary["error_count"] == 0;
    assert summary["per_model"] == {};
    assert summary["per_caller"] == {};
}

#  6. Eviction — max_traces boundary
test "eviction removes oldest trace when max_traces exceeded via record_llm_event" {
    store = TelemetryStore(max_traces=2);

    store.record_llm_event(make_llm_event(inv_id="old"));
    store.record_llm_event(make_llm_event(inv_id="mid"));
    store.record_llm_event(make_llm_event(inv_id="new"));

    traces = store.get_traces();
    assert traces["total"] == 2;

    ids = [t["invocation_id"] for t in traces["traces"]];
    assert "old" not in ids;
    assert "mid" in ids;
    assert "new" in ids;
}

test "eviction removes oldest trace when max_traces exceeded via record_agent_completion" {
    store = TelemetryStore(max_traces=2);

    # Two traces created by agent completion (MockLLM path)
    store.record_agent_completion(make_agent_record(inv_id="first"));
    store.record_agent_completion(make_agent_record(inv_id="second"));
    store.record_agent_completion(make_agent_record(inv_id="third"));

    traces = store.get_traces();
    assert traces["total"] == 2;

    ids = [t["invocation_id"] for t in traces["traces"]];
    assert "first" not in ids;
    assert "second" in ids;
    assert "third" in ids;
}

#  7. get_available_filters
test "get_available_filters returns unique models callers statuses" {
    store = TelemetryStore();

    store.record_llm_event(
        make_llm_event(inv_id="f1", model="gpt-4o", caller_name="agent_a")
    );
    store.record_llm_event(
        make_llm_event(inv_id="f2", model="gpt-4o-mini", caller_name="agent_b")
    );
    store.record_llm_event(
        make_llm_event(inv_id="f3", model="gpt-4o", caller_name="agent_a")
    );
    # Pass matching caller_name so agent_completion doesn't overwrite it
    store.record_agent_completion(
        make_agent_record(inv_id="f1", caller_name="agent_a", status="success")
    );
    store.record_agent_completion(
        make_agent_record(inv_id="f2", caller_name="agent_b", status="error")
    );

    filters = store.get_available_filters();
    assert "gpt-4o" in filters["models"];
    assert "gpt-4o-mini" in filters["models"];
    assert "agent_a" in filters["callers"];
    assert "agent_b" in filters["callers"];
    assert "success" in filters["statuses"] or "in_progress" in filters["statuses"];
}

#  8. REST Endpoint Tests — auth enforcement & response shape
import uuid;
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

glob DEFAULT_ADMIN_PASSWORD: str = "changeme";

# --- Auth enforcement: all telemetry endpoints require admin token ---
test "REST summary endpoint returns 403 without auth token" {
    client = make_client();
    try {
        response = client.get("/admin/llm/telemetry/summary");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "REST traces endpoint returns 403 without auth token" {
    client = make_client();
    try {
        response = client.get("/admin/llm/telemetry/traces");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "REST trace detail endpoint returns 403 without auth token" {
    client = make_client();
    try {
        response = client.get("/admin/llm/telemetry/traces/some-id");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "REST filters endpoint returns 403 without auth token" {
    client = make_client();
    try {
        response = client.get("/admin/llm/telemetry/filters");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "REST summary endpoint returns 403 with invalid token" {
    client = make_client();
    try {
        response = client.get(
            "/admin/llm/telemetry/summary",
            headers={"Authorization": "Bearer invalid-token-xyz"}
        );
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

# --- Response shape: empty store ---
test "REST summary returns correct shape on empty store" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/telemetry/summary",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        body = response.json();
        assert body["ok"] is True;
        data = body["data"];
        assert data["total_invocations"] == 0;
        assert data["total_llm_calls"] == 0;
        assert data["total_tokens"] == 0;
        assert data["total_cost"] == 0.0;
        assert data["avg_latency_ms"] == 0.0;
        assert data["error_count"] == 0;
        assert data["per_model"] == {};
        assert data["per_caller"] == {};
    } finally {
        client.close();
    }
}

test "REST traces returns correct shape on empty store" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/telemetry/traces", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        body = response.json();
        assert body["ok"] is True;
        data = body["data"];
        assert data["traces"] == [];
        assert data["total"] == 0;
        assert data["has_more"] is False;
    } finally {
        client.close();
    }
}

test "REST filters returns correct shape on empty store" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/telemetry/filters",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        body = response.json();
        assert body["ok"] is True;
        data = body["data"];
        assert "models" in data;
        assert "callers" in data;
        assert "statuses" in data;
        assert data["models"] == [];
        assert data["callers"] == [];
        assert data["statuses"] == [];
    } finally {
        client.close();
    }
}

test "REST trace detail returns 404 for nonexistent trace" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/telemetry/traces/nonexistent-id",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 404;
        body = response.json();
        assert body["ok"] is False;
    } finally {
        client.close();
    }
}

# --- Response shape: populated store ---
"""Access the TelemetryStore that the REST handlers use at runtime."""
def get_telemetry_store -> TelemetryStore | None {
    import sys;
    mod = sys.modules.get("jac_scale.admin.llm_telemetry");
    if mod is not None {
        return getattr(mod, "_telemetry_store", None);
    }
    return None;
}

test "REST summary returns populated data after telemetry events" {
    client = make_client();
    try {
        token = client.admin_login();

        store = get_telemetry_store();
        assert store is not None , "TelemetryStore should be initialized";

        store.record_llm_event(
            make_llm_event(
                inv_id="rest-sum1",
                model="gpt-4o",
                total_tokens=200,
                response_cost=0.001
            )
        );
        store.record_agent_completion(
            make_agent_record(
                inv_id="rest-sum1", model="gpt-4o", status="success", latency_ms=500.0
            )
        );

        response = client.get(
            "/admin/llm/telemetry/summary",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = response.json()["data"];
        assert data["total_invocations"] >= 1;
        assert data["total_llm_calls"] >= 1;
        assert data["total_tokens"] >= 200;
    } finally {
        client.close();
    }
}

test "REST traces returns populated data and supports pagination" {
    client = make_client();
    try {
        token = client.admin_login();
        store = get_telemetry_store();
        assert store is not None;

        # Insert 3 traces
        for i in range(3) {
            store.record_llm_event(make_llm_event(inv_id=f"rest-pg-{i}"));
            store.record_agent_completion(make_agent_record(inv_id=f"rest-pg-{i}"));
        }

        # Get all
        response = client.get(
            "/admin/llm/telemetry/traces", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = response.json()["data"];
        assert data["total"] >= 3;

        # Paginate: limit=2, offset=0
        response = client.get(
            "/admin/llm/telemetry/traces",
            params={"limit": "2", "offset": "0"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = response.json()["data"];
        assert len(data["traces"]) == 2;
        assert data["has_more"] is True;
    } finally {
        client.close();
    }
}

test "REST trace detail returns full detail for existing trace" {
    client = make_client();
    try {
        token = client.admin_login();
        store = get_telemetry_store();
        assert store is not None;

        store.record_llm_event(make_llm_event(inv_id="rest-detail"));
        store.record_agent_completion(
            make_agent_record(
                inv_id="rest-detail",
                user_prompt="Tell me about Paris",
                agent_response="Paris is the capital of France."
            )
        );

        response = client.get(
            "/admin/llm/telemetry/traces/rest-detail",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        body = response.json();
        assert body["ok"] is True;
        data = body["data"];
        assert data["invocation_id"] == "rest-detail";
        assert data["user_prompt"] == "Tell me about Paris";
        assert data["agent_response"] == "Paris is the capital of France.";
        assert "llm_calls" in data;
        assert "conversation_history" in data;
    } finally {
        client.close();
    }
}

test "REST filters returns populated filter values" {
    client = make_client();
    try {
        token = client.admin_login();
        store = get_telemetry_store();
        assert store is not None;

        store.record_llm_event(
            make_llm_event(inv_id="rest-f1", model="gpt-4o", caller_name="agent_x")
        );
        store.record_llm_event(
            make_llm_event(inv_id="rest-f2", model="claude-3", caller_name="agent_y")
        );
        store.record_agent_completion(
            make_agent_record(
                inv_id="rest-f1", caller_name="agent_x", status="success"
            )
        );
        store.record_agent_completion(
            make_agent_record(inv_id="rest-f2", caller_name="agent_y", status="error")
        );

        response = client.get(
            "/admin/llm/telemetry/filters",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = response.json()["data"];
        assert "models" in data;
        assert "callers" in data;
        assert "statuses" in data;
        assert isinstance(data["models"], list) and data["models"];
        assert isinstance(data["callers"], list) and data["callers"];
        assert isinstance(data["statuses"], list) and data["statuses"];
    } finally {
        client.close();
    }
}

# --- Trace Hierarchy Tests ---

test "parent_invocation_id stored from llm_event metadata" {
    store = TelemetryStore();
    event = make_llm_event(inv_id="child-001", caller_name="inner_agent");
    event["metadata"]["jac_parent_invocation_id"] = "parent-001";
    store.record_llm_event(event);

    traces = store.get_traces();
    assert traces["total"] == 1;
    trace = traces["traces"][0];
    assert trace["parent_invocation_id"] == "parent-001";
    assert trace["invocation_id"] == "child-001";
}

test "parent_invocation_id is None for root traces from llm_event" {
    store = TelemetryStore();
    event = make_llm_event(inv_id="root-001", caller_name="root_agent");
    # No jac_parent_invocation_id in metadata
    store.record_llm_event(event);

    traces = store.get_traces();
    trace = traces["traces"][0];
    assert trace["parent_invocation_id"] is None;
}

test "parent_invocation_id stored from agent_completion record" {
    store = TelemetryStore();
    # Create trace via llm event first
    store.record_llm_event(make_llm_event(inv_id="child-002"));
    # Then complete it with parent info
    record = make_agent_record(inv_id="child-002", caller_name="nested_agent");
    record["parent_invocation_id"] = "parent-002";
    store.record_agent_completion(record);

    traces = store.get_traces();
    trace = traces["traces"][0];
    assert trace["parent_invocation_id"] == "parent-002";
}

test "agent_completion creates new trace with parent when no prior llm_event" {
    store = TelemetryStore();
    record = make_agent_record(inv_id="orphan-001", caller_name="orphan_agent");
    record["parent_invocation_id"] = "parent-003";
    store.record_agent_completion(record);

    traces = store.get_traces();
    trace = traces["traces"][0];
    assert trace["parent_invocation_id"] == "parent-003";
}

test "get_traces root_only filter returns only root traces" {
    store = TelemetryStore();
    # Root trace
    root_event = make_llm_event(inv_id="root-r1", caller_name="root_agent");
    store.record_llm_event(root_event);
    store.record_agent_completion(make_agent_record(inv_id="root-r1", caller_name="root_agent"));

    # Child trace
    child_event = make_llm_event(inv_id="child-r1", caller_name="inner_agent");
    child_event["metadata"]["jac_parent_invocation_id"] = "root-r1";
    store.record_llm_event(child_event);
    child_rec = make_agent_record(inv_id="child-r1", caller_name="inner_agent");
    child_rec["parent_invocation_id"] = "root-r1";
    store.record_agent_completion(child_rec);

    # All traces (no filter)
    all_result = store.get_traces();
    assert all_result["total"] == 2;

    # Root only
    root_result = store.get_traces(root_only=True);
    assert root_result["total"] == 1;
    assert root_result["traces"][0]["invocation_id"] == "root-r1";
    assert root_result["traces"][0]["parent_invocation_id"] is None;
}

test "get_trace returns child_traces for parent" {
    store = TelemetryStore();
    # Root trace
    store.record_llm_event(make_llm_event(inv_id="parent-det", caller_name="parent_agent"));
    store.record_agent_completion(
        make_agent_record(inv_id="parent-det", caller_name="parent_agent")
    );

    # Child trace 1
    child1_event = make_llm_event(inv_id="child-det-1", caller_name="tool_agent_1");
    child1_event["metadata"]["jac_parent_invocation_id"] = "parent-det";
    store.record_llm_event(child1_event);
    child1_rec = make_agent_record(inv_id="child-det-1", caller_name="tool_agent_1");
    child1_rec["parent_invocation_id"] = "parent-det";
    store.record_agent_completion(child1_rec);

    # Child trace 2
    child2_event = make_llm_event(inv_id="child-det-2", caller_name="tool_agent_2");
    child2_event["metadata"]["jac_parent_invocation_id"] = "parent-det";
    store.record_llm_event(child2_event);
    child2_rec = make_agent_record(inv_id="child-det-2", caller_name="tool_agent_2");
    child2_rec["parent_invocation_id"] = "parent-det";
    store.record_agent_completion(child2_rec);

    detail = store.get_trace("parent-det");
    assert detail is not None;
    assert "child_traces" in detail;
    assert len(detail["child_traces"]) == 2;
    child_ids = [c["invocation_id"] for c in detail["child_traces"]];
    assert "child-det-1" in child_ids;
    assert "child-det-2" in child_ids;
}

test "get_trace returns empty child_traces for leaf trace" {
    store = TelemetryStore();
    store.record_llm_event(make_llm_event(inv_id="leaf-001"));
    store.record_agent_completion(make_agent_record(inv_id="leaf-001"));

    detail = store.get_trace("leaf-001");
    assert detail is not None;
    assert detail["child_traces"] == [];
}

test "to_dict includes parent_invocation_id field" {
    store = TelemetryStore();
    event = make_llm_event(inv_id="dict-check");
    event["metadata"]["jac_parent_invocation_id"] = "dict-parent";
    store.record_llm_event(event);

    traces = store.get_traces();
    trace = traces["traces"][0];
    assert "parent_invocation_id" in trace;
    assert trace["parent_invocation_id"] == "dict-parent";
}

test "child trace detail includes full llm_calls and conversation_history" {
    store = TelemetryStore();
    # Parent
    store.record_llm_event(make_llm_event(inv_id="full-parent"));
    store.record_agent_completion(make_agent_record(inv_id="full-parent"));

    # Child with data
    child_event = make_llm_event(
        inv_id="full-child",
        caller_name="child_agent",
        model="gpt-4o",
        prompt_tokens=200,
        completion_tokens=100,
        total_tokens=300,
        response_cost=0.001
    );
    child_event["metadata"]["jac_parent_invocation_id"] = "full-parent";
    store.record_llm_event(child_event);
    child_rec = make_agent_record(
        inv_id="full-child",
        caller_name="child_agent",
        user_prompt="nested question",
        agent_response="nested answer"
    );
    child_rec["parent_invocation_id"] = "full-parent";
    store.record_agent_completion(child_rec);

    detail = store.get_trace("full-parent");
    assert len(detail["child_traces"]) == 1;
    child = detail["child_traces"][0];
    assert child["invocation_id"] == "full-child";
    assert child["caller_name"] == "child_agent";
    assert child["total_tokens"] == 300;
    assert child["total_cost"] == 0.001;
    # Detail includes llm_calls since include_detail=True
    assert "llm_calls" in child;
    assert len(child["llm_calls"]) == 1;
}

#  --- Aggregated cost/token roll-up tests ---

test "get_trace aggregates tokens and cost from child traces" {
    store = TelemetryStore();
    # Parent: 150 tokens, cost 0.0001
    store.record_llm_event(
        make_llm_event(inv_id="agg-parent", total_tokens=150, response_cost=0.0001)
    );
    store.record_agent_completion(make_agent_record(inv_id="agg-parent"));

    # Child 1: 200 tokens, cost 0.0005
    child1_event = make_llm_event(
        inv_id="agg-child-1", total_tokens=200, response_cost=0.0005
    );
    child1_event["metadata"]["jac_parent_invocation_id"] = "agg-parent";
    store.record_llm_event(child1_event);
    child1_rec = make_agent_record(inv_id="agg-child-1");
    child1_rec["parent_invocation_id"] = "agg-parent";
    store.record_agent_completion(child1_rec);

    # Child 2: 300 tokens, cost 0.001
    child2_event = make_llm_event(
        inv_id="agg-child-2", total_tokens=300, response_cost=0.001
    );
    child2_event["metadata"]["jac_parent_invocation_id"] = "agg-parent";
    store.record_llm_event(child2_event);
    child2_rec = make_agent_record(inv_id="agg-child-2");
    child2_rec["parent_invocation_id"] = "agg-parent";
    store.record_agent_completion(child2_rec);

    detail = store.get_trace("agg-parent");
    # Own values
    assert detail["total_tokens"] == 150;
    assert detail["total_cost"] == 0.0001;
    assert detail["llm_call_count"] == 1;

    # Aggregated = parent + child1 + child2
    assert detail["aggregated_total_tokens"] == 650;  # 150 + 200 + 300
    assert detail["aggregated_total_cost"] == round(0.0001 + 0.0005 + 0.001, 6);
    assert detail["aggregated_llm_call_count"] == 3;
}

test "get_trace aggregated fields equal own values when no children" {
    store = TelemetryStore();
    store.record_llm_event(
        make_llm_event(inv_id="agg-leaf", total_tokens=100, response_cost=0.0002)
    );
    store.record_agent_completion(make_agent_record(inv_id="agg-leaf"));

    detail = store.get_trace("agg-leaf");
    assert detail["aggregated_total_tokens"] == detail["total_tokens"];
    assert detail["aggregated_total_cost"] == detail["total_cost"];
    assert detail["aggregated_llm_call_count"] == detail["llm_call_count"];
}

test "get_trace aggregated fields include multi-call children" {
    store = TelemetryStore();
    # Parent: 1 LLM call, 100 tokens
    store.record_llm_event(
        make_llm_event(inv_id="agg-multi-p", total_tokens=100, response_cost=0.0001)
    );
    store.record_agent_completion(make_agent_record(inv_id="agg-multi-p"));

    # Child with 2 LLM calls (ReAct loop)
    child_evt1 = make_llm_event(
        inv_id="agg-multi-c", total_tokens=80, response_cost=0.00005
    );
    child_evt1["metadata"]["jac_parent_invocation_id"] = "agg-multi-p";
    store.record_llm_event(child_evt1);
    child_evt2 = make_llm_event(
        inv_id="agg-multi-c", total_tokens=120, response_cost=0.00008
    );
    child_evt2["metadata"]["jac_parent_invocation_id"] = "agg-multi-p";
    store.record_llm_event(child_evt2);
    child_rec = make_agent_record(inv_id="agg-multi-c");
    child_rec["parent_invocation_id"] = "agg-multi-p";
    store.record_agent_completion(child_rec);

    detail = store.get_trace("agg-multi-p");
    # Parent: 1 call, 100 tokens. Child: 2 calls, 200 tokens.
    assert detail["aggregated_total_tokens"] == 300;
    assert detail["aggregated_llm_call_count"] == 3;
    assert detail["aggregated_total_cost"] == round(0.0001 + 0.00005 + 0.00008, 6);
}

test "get_traces recursive aggregation includes grandchildren" {
    store = TelemetryStore();
    # Root: 100 tokens, cost 0.0001
    store.record_llm_event(
        make_llm_event(inv_id="rec-root", total_tokens=100, response_cost=0.0001)
    );
    store.record_agent_completion(make_agent_record(inv_id="rec-root"));

    # Child: 200 tokens, cost 0.0005
    child_evt = make_llm_event(
        inv_id="rec-child", total_tokens=200, response_cost=0.0005
    );
    child_evt["metadata"]["jac_parent_invocation_id"] = "rec-root";
    store.record_llm_event(child_evt);
    child_rec = make_agent_record(inv_id="rec-child");
    child_rec["parent_invocation_id"] = "rec-root";
    store.record_agent_completion(child_rec);

    # Grandchild: 50 tokens, cost 0.0002
    gc_evt = make_llm_event(
        inv_id="rec-grandchild", total_tokens=50, response_cost=0.0002
    );
    gc_evt["metadata"]["jac_parent_invocation_id"] = "rec-child";
    store.record_llm_event(gc_evt);
    gc_rec = make_agent_record(inv_id="rec-grandchild");
    gc_rec["parent_invocation_id"] = "rec-child";
    store.record_agent_completion(gc_rec);

    # Root-only list should aggregate root + child + grandchild.
    root_result = store.get_traces(root_only=True);
    assert root_result["total"] == 1;
    root_trace = root_result["traces"][0];
    assert root_trace["child_count"] == 1;
    assert root_trace["aggregated_total_tokens"] == 350;  # 100 + 200 + 50
    assert root_trace["aggregated_total_cost"] == 0.0001 + 0.0005 + 0.0002;
    assert root_trace["aggregated_llm_call_count"] == 3;

    # Detail endpoint should also aggregate recursively.
    detail = store.get_trace("rec-root");
    assert detail["aggregated_total_tokens"] == 350;
    assert detail["aggregated_llm_call_count"] == 3;

    # Child in detail should have its own child_count and aggregated stats.
    child_detail = detail["child_traces"][0];
    assert child_detail["invocation_id"] == "rec-child";
    assert child_detail["child_count"] == 1;
    assert child_detail["aggregated_total_tokens"] == 250;  # 200 + 50
    assert child_detail["aggregated_total_cost"] == round(0.0005 + 0.0002, 6);
    assert child_detail["aggregated_llm_call_count"] == 2;
}
