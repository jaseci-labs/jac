"""Tests for LLM usage limits admin endpoints."""

import types;
import unittest.mock;
import from typing { Any }
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

"""Build a minimal fake litellm ModelResponse for use in mocks.

cost   – value placed in _hidden_params["response_cost"]
tokens – total_tokens; prompt_tokens is fixed at 10, completion = tokens-10
"""
def _fake_llm_response(cost: float = 0.001, tokens: int = 30) -> Any {
    resp: Any = types.SimpleNamespace();
    usage: Any = types.SimpleNamespace();
    usage.prompt_tokens = 10;
    usage.completion_tokens = tokens - 10;
    usage.total_tokens = tokens;
    resp.usage = usage;
    resp._hidden_params = {"response_cost": cost};
    return resp;
}


"""Build a fake streaming response — a list of chunk SimpleNamespaces.

The final chunk carries usage + _hidden_params (cost), mirroring what
litellm emits when stream_options={"include_usage": True} is set.
Intermediate chunks have no usage and no finish_reason.
"""
def _fake_stream_chunks(cost: float = 0.002, tokens: int = 40) -> list {
    def _choice(finish_reason: Any = None) -> Any {
        c: Any = types.SimpleNamespace();
        c.finish_reason = finish_reason;
        return c;
    }

    # Two intermediate chunks with no usage
    chunk1: Any = types.SimpleNamespace();
    chunk1.choices = [_choice()];
    chunk1.usage = None;
    chunk1._hidden_params = {};

    chunk2: Any = types.SimpleNamespace();
    chunk2.choices = [_choice()];
    chunk2.usage = None;
    chunk2._hidden_params = {};

    # Final chunk: finish_reason="stop" + usage + cost
    final_usage: Any = types.SimpleNamespace();
    final_usage.prompt_tokens = 10;
    final_usage.completion_tokens = tokens - 10;
    final_usage.total_tokens = tokens;

    final_chunk: Any = types.SimpleNamespace();
    final_chunk.choices = [_choice("stop")];
    final_chunk.usage = final_usage;
    final_chunk._hidden_params = {"response_cost": cost};

    return [chunk1, chunk2, final_chunk];
}

# ============================================================================
# Default Limits Tests
# ============================================================================
test "llm limits get default limits" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/limits/default", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "budget_limit" in data;
        assert "budget_period" in data;
        assert "rpm_limit" in data;
        assert "tpm_limit" in data;
        assert "enabled" in data;
    } finally {
        client.close();
    }
}

test "llm limits get default limits requires auth" {
    client = make_client();
    try {
        response = client.get("/admin/llm/limits/default");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "llm limits set default limits" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.put(
            "/admin/llm/limits/default",
            json={
                "budget_limit": 25.0,
                "budget_period": "weekly",
                "rpm_limit": 120,
                "tpm_limit": 200000,
                "allowed_models": ["gpt-4o", "gpt-4o-mini"],
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        # Verify the update
        get_resp = client.get(
            "/admin/llm/limits/default", headers={"Authorization": f"Bearer {token}"}
        );
        data = extract_data(get_resp.json());
        assert data["budget_limit"] == 25.0;
        assert data["budget_period"] == "weekly";
        assert data["rpm_limit"] == 120;
        assert data["tpm_limit"] == 200000;
        assert "gpt-4o" in data["allowed_models"];
    } finally {
        client.close();
    }
}

# ============================================================================
# Per-User Limits Tests
# ============================================================================
test "llm limits list user limits empty" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/limits", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "items" in data;
        assert "total" in data;
        assert data["total"] == 0;
    } finally {
        client.close();
    }
}

test "llm limits set user limits" {
    client = make_client();
    try {
        token = client.admin_login();

        # Set limits for a user
        response = client.put(
            "/admin/llm/limits/testuser",
            json={
                "budget_limit": 5.0,
                "budget_period": "daily",
                "rpm_limit": 30,
                "tpm_limit": 50000,
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        # Verify in list
        list_resp = client.get(
            "/admin/llm/limits", headers={"Authorization": f"Bearer {token}"}
        );
        data = extract_data(list_resp.json());
        assert data["total"] >= 1;

        found = False;
        for item in data["items"] {
            if item["username"] == "testuser" {
                assert item["budget_limit"] == 5.0;
                assert item["budget_period"] == "daily";
                assert item["rpm_limit"] == 30;
                found = True;
            }
        }
        assert found;
    } finally {
        client.close();
    }
}

test "llm limits get user limits" {
    client = make_client();
    try {
        token = client.admin_login();

        # Set limits first
        client.put(
            "/admin/llm/limits/alice",
            json={
                "budget_limit": 10.0,
                "budget_period": "monthly",
                "rpm_limit": 60,
                "tpm_limit": 100000,
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );

        # Get specific user limits
        response = client.get(
            "/admin/llm/limits/alice", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["username"] == "alice";
        assert data["budget_limit"] == 10.0;
    } finally {
        client.close();
    }
}

test "llm limits delete user limits" {
    client = make_client();
    try {
        token = client.admin_login();

        # Set limits
        client.put(
            "/admin/llm/limits/bob",
            json={
                "budget_limit": 5.0,
                "budget_period": "daily",
                "rpm_limit": 10,
                "tpm_limit": 10000,
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );

        # Delete
        response = client.delete(
            "/admin/llm/limits/bob", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        # Verify gone from list
        list_resp = client.get(
            "/admin/llm/limits", headers={"Authorization": f"Bearer {token}"}
        );
        data = extract_data(list_resp.json());
        for item in data["items"] {
            assert item["username"] != "bob";
        }
    } finally {
        client.close();
    }
}

test "llm limits requires auth" {
    client = make_client();
    try {
        # All endpoints should reject without auth
        assert client.get("/admin/llm/limits").status_code == 403;
        assert client.put(
            "/admin/llm/limits/testuser", json={"budget_limit": 5.0}
        ).status_code == 403;
        assert client.delete("/admin/llm/limits/testuser").status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Usage Tracking Tests
# ============================================================================
test "llm usage get all usage empty" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/usage", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "items" in data;
        assert "total" in data;
    } finally {
        client.close();
    }
}

test "llm usage get user usage" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/usage/nonexistent",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        # Should return zero usage for unknown user
        assert data["total_cost"] == 0.0;
        assert data["total_tokens"] == 0;
        assert data["total_requests"] == 0;
    } finally {
        client.close();
    }
}

test "llm usage reset user usage" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.post(
            "/admin/llm/usage/testuser/reset",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
    } finally {
        client.close();
    }
}

test "llm usage requires auth" {
    client = make_client();
    try {
        assert client.get("/admin/llm/usage").status_code == 403;
        assert client.get("/admin/llm/usage/testuser").status_code == 403;
        assert client.post("/admin/llm/usage/testuser/reset").status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Provider Keys Config Tests
# ============================================================================
test "llm provider keys get empty" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/config/provider-keys",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert isinstance(data, dict);
    } finally {
        client.close();
    }
}

test "llm provider keys set and verify masked" {
    client = make_client();
    try {
        token = client.admin_login();

        set_resp = client.put(
            "/admin/llm/config/provider-keys/openai",
            json={"api_key": "sk-test-1234567890"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert set_resp.status_code == 200;
        set_data = extract_data(set_resp.json());
        assert "masked_key" in set_data;
        assert "****" in set_data["masked_key"];
        assert set_data["masked_key"].endswith("7890");

        # Verify appears in list
        list_data = extract_data(
            client.get(
                "/admin/llm/config/provider-keys",
                headers={"Authorization": f"Bearer {token}"}
            ).json()
        );
        assert "openai" in list_data;

        # Cleanup
        client.delete(
            "/admin/llm/config/provider-keys/openai",
            headers={"Authorization": f"Bearer {token}"}
        );
    } finally {
        client.close();
    }
}

test "llm provider keys delete removes key" {
    client = make_client();
    try {
        token = client.admin_login();

        client.put(
            "/admin/llm/config/provider-keys/anthropic",
            json={"api_key": "sk-ant-test-12345678"},
            headers={"Authorization": f"Bearer {token}"}
        );

        del_resp = client.delete(
            "/admin/llm/config/provider-keys/anthropic",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert del_resp.status_code == 200;

        list_data = extract_data(
            client.get(
                "/admin/llm/config/provider-keys",
                headers={"Authorization": f"Bearer {token}"}
            ).json()
        );
        assert "anthropic" not in list_data;
    } finally {
        client.close();
    }
}

test "llm provider keys multiple providers independent" {
    client = make_client();
    try {
        token = client.admin_login();

        client.put(
            "/admin/llm/config/provider-keys/openai",
            json={"api_key": "sk-openai-test-key-1234"},
            headers={"Authorization": f"Bearer {token}"}
        );
        client.put(
            "/admin/llm/config/provider-keys/anthropic",
            json={"api_key": "sk-ant-test-key-5678"},
            headers={"Authorization": f"Bearer {token}"}
        );

        list_data = extract_data(
            client.get(
                "/admin/llm/config/provider-keys",
                headers={"Authorization": f"Bearer {token}"}
            ).json()
        );
        assert "openai" in list_data;
        assert "anthropic" in list_data;

        # Delete only openai — anthropic must survive
        client.delete(
            "/admin/llm/config/provider-keys/openai",
            headers={"Authorization": f"Bearer {token}"}
        );
        list_after = extract_data(
            client.get(
                "/admin/llm/config/provider-keys",
                headers={"Authorization": f"Bearer {token}"}
            ).json()
        );
        assert "openai" not in list_after;
        assert "anthropic" in list_after;

        # Cleanup
        client.delete(
            "/admin/llm/config/provider-keys/anthropic",
            headers={"Authorization": f"Bearer {token}"}
        );
    } finally {
        client.close();
    }
}

test "llm provider keys requires auth" {
    client = make_client();
    try {
        assert client.get("/admin/llm/config/provider-keys").status_code == 403;
        assert client.put(
            "/admin/llm/config/provider-keys/openai", json={"api_key": "sk-test"}
        ).status_code == 403;
        assert client.delete("/admin/llm/config/provider-keys/openai").status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Integration: Full Limits Lifecycle
# ============================================================================
test "llm limits full lifecycle" {
    client = make_client();
    try {
        token = client.admin_login();

        # 1. Set default limits
        client.put(
            "/admin/llm/limits/default",
            json={
                "budget_limit": 50.0,
                "budget_period": "monthly",
                "rpm_limit": 100,
                "tpm_limit": 500000,
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );

        # 2. Set per-user override
        client.put(
            "/admin/llm/limits/poweruser",
            json={
                "budget_limit": 100.0,
                "budget_period": "monthly",
                "rpm_limit": 200,
                "tpm_limit": 1000000,
                "enabled": True
            },
            headers={"Authorization": f"Bearer {token}"}
        );

        # 3. Verify default
        def_resp = client.get(
            "/admin/llm/limits/default", headers={"Authorization": f"Bearer {token}"}
        );
        def_data = extract_data(def_resp.json());
        assert def_data["budget_limit"] == 50.0;

        # 4. Verify user override
        user_resp = client.get(
            "/admin/llm/limits/poweruser", headers={"Authorization": f"Bearer {token}"}
        );
        user_data = extract_data(user_resp.json());
        assert user_data["budget_limit"] == 100.0;
        assert user_data["rpm_limit"] == 200;

        # 5. Check usage is zero
        usage_resp = client.get(
            "/admin/llm/usage/poweruser", headers={"Authorization": f"Bearer {token}"}
        );
        usage_data = extract_data(usage_resp.json());
        assert usage_data["total_cost"] == 0.0;

        # 6. Reset usage (should succeed even with no usage)
        reset_resp = client.post(
            "/admin/llm/usage/poweruser/reset",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert reset_resp.status_code == 200;

        # 7. Delete user limits
        del_resp = client.delete(
            "/admin/llm/limits/poweruser", headers={"Authorization": f"Bearer {token}"}
        );
        assert del_resp.status_code == 200;

        # 8. Verify user falls back to default
        fallback_resp = client.get(
            "/admin/llm/limits/poweruser", headers={"Authorization": f"Bearer {token}"}
        );
        fallback_data = extract_data(fallback_resp.json());
        # After deletion, should get default limits
        assert fallback_data["budget_limit"] == 50.0;
    } finally {
        client.close();
    }
}

# ============================================================================
# LLM Enforcement Tests
#
# Strategy: patch litellm.completion BEFORE make_client() so that when
# register_llm_limits_endpoints() runs during server startup it captures our
# mock as _original_completion inside the _guarded_completion closure.
# Requests then flow:  litellm.completion (= _guarded_completion)
#                           → _original_completion (= mock)
# All enforcement logic (limits checks, key injection, usage recording) runs
# normally; only the actual network call is replaced.
# ============================================================================
test "llm enforcement provider key injected into litellm kwargs" {
    captured: dict[str, Any] = {};
    fake = _fake_llm_response(cost=0.001, tokens=30);

    def mock_completion(*args: Any, **kwargs: Any) -> Any {
        captured.update(kwargs);
        return fake;
    }

    with unittest.mock.patch("litellm.completion", mock_completion) {
        client = make_client();
        try {
            token = client.admin_login();

            # Set an openai provider key via admin
            client.put(
                "/admin/llm/config/provider-keys/openai",
                json={"api_key": "sk-test-injected-key"},
                headers={"Authorization": f"Bearer {token}"}
            );

            # Register a user and make a walker call
            (_, user_token) = client.register_user("inject_user", "Pass123!");
            client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );

            # The guarded wrapper should have injected the provider key
            assert captured.get("api_key") == "sk-test-injected-key";

            # Cleanup
            client.delete(
                "/admin/llm/config/provider-keys/openai",
                headers={"Authorization": f"Bearer {token}"}
            );
        } finally {
            client.close();
        }
    }
}

test "llm enforcement username propagated to usage tracking" {
    fake = _fake_llm_response(cost=0.005, tokens=50);

    with unittest.mock.patch("litellm.completion", return_value=fake) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("usage_alice", "Pass123!");

            client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );

            # Usage should be recorded under the authenticated username
            usage_data = extract_data(
                client.get(
                    "/admin/llm/usage/usage_alice",
                    headers={"Authorization": f"Bearer {token}"}
                ).json()
            );
            assert usage_data["total_requests"] >= 1;
            assert usage_data["total_tokens"] >= 50;
            assert usage_data["total_cost"] >= 0.005;
        } finally {
            client.close();
        }
    }
}

test "llm enforcement model not in allowed list blocks request" {
    # No litellm mock needed — the model check fires before _original_completion
    fake = _fake_llm_response();

    with unittest.mock.patch("litellm.completion", return_value=fake) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("model_bob", "Pass123!");

            # Allow only gpt-4o; walker will call gpt-4o-mini
            client.put(
                "/admin/llm/limits/model_bob",
                json={
                    "budget_limit": 100.0,
                    "budget_period": "monthly",
                    "rpm_limit": 100,
                    "tpm_limit": 1000000,
                    "allowed_models": ["gpt-4o"],
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            resp = client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            body = resp.json();
            assert not body.get("ok");
        } finally {
            client.close();
        }
    }
}

test "llm enforcement rpm limit blocks after first request" {
    fake = _fake_llm_response();

    with unittest.mock.patch("litellm.completion", return_value=fake) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("rpm_carol", "Pass123!");

            # Set rpm_limit=1 so the second call in the same minute is blocked
            client.put(
                "/admin/llm/limits/rpm_carol",
                json={
                    "budget_limit": 100.0,
                    "budget_period": "monthly",
                    "rpm_limit": 1,
                    "tpm_limit": 1000000,
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            # First call — allowed, increments rpm counter to 1
            first = client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert first.json().get("ok");

            # Second call — counter(1) >= limit(1) → blocked
            second = client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert not second.json().get("ok");
        } finally {
            client.close();
        }
    }
}

test "llm enforcement budget limit blocks after spend exceeded" {
    # cost per call = 0.005; budget = 0.001 → blocked on second call
    fake = _fake_llm_response(cost=0.005, tokens=30);

    with unittest.mock.patch("litellm.completion", return_value=fake) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("budget_dave", "Pass123!");

            client.put(
                "/admin/llm/limits/budget_dave",
                json={
                    "budget_limit": 0.001,
                    "budget_period": "monthly",
                    "rpm_limit": 100,
                    "tpm_limit": 1000000,
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            # First call — succeeds and records cost=0.005 (exceeds budget)
            first = client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert first.json().get("ok");

            # Second call — total_cost(0.005) >= budget_limit(0.001) → blocked
            second = client.post(
                "/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert not second.json().get("ok");
        } finally {
            client.close();
        }
    }
}

# ============================================================================
# Streaming Enforcement Tests
# ============================================================================

test "llm streaming debug" {
    import sys;
    # Compare username resolution: streaming vs non-streaming
    fake_resp = _fake_llm_response(cost=0.002, tokens=30);
    chunks = _fake_stream_chunks(cost=0.003, tokens=45);

    captured_users: list = [];
    def mock_capture(*args: Any, **kwargs: Any) -> Any {
        import sys;
        # Check all possible module keys for llm_limits
        llm_mods: Any = {k: sys.modules[k] for k in list(sys.modules.keys()) if 'llm_limits' in k};
        for (mk, mod) in llm_mods.items() {
            cru = getattr(mod, 'current_request_user', None);
            if cru is not None {
                u = cru.get();
                captured_users.append(("stream=" + str(kwargs.get("stream", False)), mk, u));
            }
        }
        if not llm_mods {
            captured_users.append(("stream=" + str(kwargs.get("stream", False)), "(no_mod)", "(no_var)"));
        }
        if kwargs.get("stream") {
            return iter(chunks);
        }
        return fake_resp;
    }

    with unittest.mock.patch("litellm.completion", mock_capture) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, u1) = client.register_user("ns_user2", "Pass123!");
            (_, u2) = client.register_user("st_user2", "Pass123!");

            # Check if serve.endpoints can import current_request_user
            import sys;
            try {
                import from jac_scale.admin.impl.llm_limits { current_request_user as cru_test }
                sys.stderr.write(f"[DEBUG] import from impl path OK: id={id(cru_test)}\n");
            } except Exception as imp_err {
                sys.stderr.write(f"[DEBUG] import from impl path FAILED: {imp_err}\n");
            }
            try {
                import from jac_scale.admin.llm_limits { current_request_user as cru_test2 }
                sys.stderr.write(f"[DEBUG] import from non-impl path OK: id={id(cru_test2)}\n");
            } except Exception as imp_err2 {
                sys.stderr.write(f"[DEBUG] import from non-impl path FAILED: {imp_err2}\n");
            }

            client.post("/walker/CallLlm",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {u1}"});
            client.post("/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {u2}"});

            sys.stderr.write(f"[DEBUG] captured users in wrapper: {captured_users}\n");

            ns_usage = client.get("/admin/llm/usage/ns_user2", headers={"Authorization": f"Bearer {token}"}).json();
            st_usage = client.get("/admin/llm/usage/st_user2", headers={"Authorization": f"Bearer {token}"}).json();
            anon_usage = client.get("/admin/llm/usage/__anonymous__", headers={"Authorization": f"Bearer {token}"}).json();
            sys.stderr.write(f"[DEBUG] ns_user usage: {ns_usage.get('data',{}).get('total_requests')}\n");
            sys.stderr.write(f"[DEBUG] st_user usage: {st_usage.get('data',{}).get('total_requests')}\n");
            sys.stderr.write(f"[DEBUG] __anonymous__ usage: {anon_usage.get('data',{}).get('total_requests')}\n");
        } finally {
            client.close();
        }
    }
}

test "llm streaming usage recorded after generator consumed" {
    # The mock returns an iterable of chunks; the wrapper must consume the
    # generator fully and then record cost + tokens in the store.
    chunks = _fake_stream_chunks(cost=0.003, tokens=45);

    with unittest.mock.patch("litellm.completion", return_value=iter(chunks)) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("stream_eve", "Pass123!");

            resp = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert resp.json().get("ok");

            # Usage must be recorded after the generator was exhausted
            usage_data = extract_data(
                client.get(
                    "/admin/llm/usage/stream_eve",
                    headers={"Authorization": f"Bearer {token}"}
                ).json()
            );
            assert usage_data["total_requests"] >= 1;
            assert usage_data["total_tokens"] >= 45;
            assert usage_data["total_cost"] >= 0.003;
        } finally {
            client.close();
        }
    }
}

test "llm streaming pre-call model block still fires" {
    # Model allowlist check happens before any chunk is yielded — streaming
    # should not bypass the pre-call enforcement path.
    chunks = _fake_stream_chunks();

    with unittest.mock.patch("litellm.completion", return_value=iter(chunks)) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("stream_frank", "Pass123!");

            # Allow only gpt-4o; walker will request gpt-4o-mini
            client.put(
                "/admin/llm/limits/stream_frank",
                json={
                    "budget_limit": 100.0,
                    "budget_period": "monthly",
                    "rpm_limit": 100,
                    "tpm_limit": 1000000,
                    "allowed_models": ["gpt-4o"],
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            resp = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert not resp.json().get("ok");
        } finally {
            client.close();
        }
    }
}

test "llm streaming rpm limit blocks after first stream" {
    # RPM is incremented pre-call, so it applies equally to streaming calls.
    chunks = _fake_stream_chunks();

    with unittest.mock.patch("litellm.completion", return_value=iter(chunks)) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("stream_grace", "Pass123!");

            client.put(
                "/admin/llm/limits/stream_grace",
                json={
                    "budget_limit": 100.0,
                    "budget_period": "monthly",
                    "rpm_limit": 1,
                    "tpm_limit": 1000000,
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            # First streaming call — allowed, rpm counter becomes 1
            first = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert first.json().get("ok");

            # Second call — counter(1) >= limit(1) → blocked
            second = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert not second.json().get("ok");
        } finally {
            client.close();
        }
    }
}

test "llm streaming budget blocks after cost recorded" {
    # After a streaming call completes, the cost is recorded. A second call
    # that would exceed the budget must be blocked.
    # cost per stream = 0.005; budget = 0.001 → blocked on second call
    chunks = _fake_stream_chunks(cost=0.005, tokens=30);

    with unittest.mock.patch("litellm.completion", return_value=iter(chunks)) {
        client = make_client();
        try {
            token = client.admin_login();
            (_, user_token) = client.register_user("stream_hank", "Pass123!");

            client.put(
                "/admin/llm/limits/stream_hank",
                json={
                    "budget_limit": 0.001,
                    "budget_period": "monthly",
                    "rpm_limit": 100,
                    "tpm_limit": 1000000,
                    "enabled": True
                },
                headers={"Authorization": f"Bearer {token}"}
            );

            first = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert first.json().get("ok");

            second = client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            assert not second.json().get("ok");
        } finally {
            client.close();
        }
    }
}

test "llm streaming include_usage injected into kwargs" {
    # The wrapper must auto-inject stream_options={"include_usage": True}
    # so that litellm sends usage on the final chunk.
    captured: Any = {};
    chunks = _fake_stream_chunks();

    def mock_completion_capture(*args: Any, **kwargs: Any) -> Any {
        captured.update(kwargs);
        return iter(chunks);
    }

    with unittest.mock.patch("litellm.completion", mock_completion_capture) {
        client = make_client();
        try {
            (_, user_token) = client.register_user("stream_iris", "Pass123!");
            client.post(
                "/walker/CallLlmStream",
                json={"model": "gpt-4o-mini"},
                headers={"Authorization": f"Bearer {user_token}"}
            );
            stream_opts = captured.get("stream_options") or {};
            assert stream_opts.get("include_usage") == True;
        } finally {
            client.close();
        }
    }
}
