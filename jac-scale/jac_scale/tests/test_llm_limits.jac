"""Tests for LLM usage limits admin endpoints."""

import from typing { Any }
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

# ============================================================================
# Default Limits Tests
# ============================================================================

test "llm limits get default limits" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/limits/default",
            headers={"Authorization": f"Bearer {token}"}
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
            "/admin/llm/limits/default",
            headers={"Authorization": f"Bearer {token}"}
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
            "/admin/llm/limits",
            headers={"Authorization": f"Bearer {token}"}
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
            "/admin/llm/limits",
            headers={"Authorization": f"Bearer {token}"}
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
            json={"budget_limit": 10.0, "budget_period": "monthly", "rpm_limit": 60, "tpm_limit": 100000, "enabled": True},
            headers={"Authorization": f"Bearer {token}"}
        );

        # Get specific user limits
        response = client.get(
            "/admin/llm/limits/alice",
            headers={"Authorization": f"Bearer {token}"}
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
            json={"budget_limit": 5.0, "budget_period": "daily", "rpm_limit": 10, "tpm_limit": 10000, "enabled": True},
            headers={"Authorization": f"Bearer {token}"}
        );

        # Delete
        response = client.delete(
            "/admin/llm/limits/bob",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        # Verify gone from list
        list_resp = client.get(
            "/admin/llm/limits",
            headers={"Authorization": f"Bearer {token}"}
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
            "/admin/llm/limits/testuser",
            json={"budget_limit": 5.0}
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
            "/admin/llm/usage",
            headers={"Authorization": f"Bearer {token}"}
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
# API Key Config Tests
# ============================================================================

test "llm config get api key status" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/llm/config/api-key",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "has_key" in data;
        assert data["has_key"] is False;
    } finally {
        client.close();
    }
}

test "llm config set and clear api key" {
    client = make_client();
    try {
        token = client.admin_login();

        # Set key
        set_resp = client.put(
            "/admin/llm/config/api-key",
            json={"api_key": "sk-test-1234567890"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert set_resp.status_code == 200;
        set_data = extract_data(set_resp.json());
        assert set_data["has_key"] is True;
        assert "****" in set_data["masked_key"];

        # Verify status
        status_resp = client.get(
            "/admin/llm/config/api-key",
            headers={"Authorization": f"Bearer {token}"}
        );
        status_data = extract_data(status_resp.json());
        assert status_data["has_key"] is True;

        # Clear key
        clear_resp = client.delete(
            "/admin/llm/config/api-key",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert clear_resp.status_code == 200;

        # Verify cleared
        final_resp = client.get(
            "/admin/llm/config/api-key",
            headers={"Authorization": f"Bearer {token}"}
        );
        final_data = extract_data(final_resp.json());
        assert final_data["has_key"] is False;
    } finally {
        client.close();
    }
}

test "llm config api key requires auth" {
    client = make_client();
    try {
        assert client.get("/admin/llm/config/api-key").status_code == 403;
        assert client.put(
            "/admin/llm/config/api-key",
            json={"api_key": "sk-test"}
        ).status_code == 403;
        assert client.delete("/admin/llm/config/api-key").status_code == 403;
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
            "/admin/llm/limits/default",
            headers={"Authorization": f"Bearer {token}"}
        );
        def_data = extract_data(def_resp.json());
        assert def_data["budget_limit"] == 50.0;

        # 4. Verify user override
        user_resp = client.get(
            "/admin/llm/limits/poweruser",
            headers={"Authorization": f"Bearer {token}"}
        );
        user_data = extract_data(user_resp.json());
        assert user_data["budget_limit"] == 100.0;
        assert user_data["rpm_limit"] == 200;

        # 5. Check usage is zero
        usage_resp = client.get(
            "/admin/llm/usage/poweruser",
            headers={"Authorization": f"Bearer {token}"}
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
            "/admin/llm/limits/poweruser",
            headers={"Authorization": f"Bearer {token}"}
        );
        assert del_resp.status_code == 200;

        # 8. Verify user falls back to default
        fallback_resp = client.get(
            "/admin/llm/limits/poweruser",
            headers={"Authorization": f"Bearer {token}"}
        );
        fallback_data = extract_data(fallback_resp.json());
        # After deletion, should get default limits
        assert fallback_data["budget_limit"] == 50.0;
    } finally {
        client.close();
    }
}
