"""Tests for the admin /workloads endpoints.

Covers the admin-auth gate, the graceful-degradation path (metrics_available:
false, no Prometheus), and unit tests for the pure projection helpers
(status / pod-owner heuristics, name validation).
"""

import from jac_scale.tests.scale_test_client { make_client, extract_data }
import from jac_scale.admin.workload_helpers {
    phase_to_status,
    owner_name_from_pod,
    match_owner
}

# ============================================================================
# Endpoint auth gating
# ============================================================================
test "workloads summary requires admin" {
    client = make_client();
    try {
        response = client.get("/admin/workloads");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "workloads list requires admin" {
    client = make_client();
    try {
        response = client.get("/admin/workloads/list");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "workloads pods requires admin" {
    client = make_client();
    try {
        response = client.get("/admin/workloads/pods");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

# ============================================================================
# Graceful degradation when Prometheus is not reachable
# ============================================================================
test "workloads summary returns metrics_available false when no prometheus" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/workloads", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["metrics_available"] is False;
        assert "reason" in data;
    } finally {
        client.close();
    }
}

test "workloads list returns empty array when no prometheus" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/workloads/list", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["metrics_available"] is False;
        assert data["workloads"] == [];
    } finally {
        client.close();
    }
}

test "workloads pods returns empty array when no prometheus" {
    client = make_client();
    try {
        token = client.admin_login();
        response = client.get(
            "/admin/workloads/pods", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["metrics_available"] is False;
        assert data["pods"] == [];
    } finally {
        client.close();
    }
}

# ============================================================================
# Pure helper: phase_to_status
# ============================================================================
test "phase_to_status: fully ready is Healthy" {
    assert phase_to_status(3, 3, 0) == "Healthy";
}

test "phase_to_status: partial readiness is Starting" {
    assert phase_to_status(1, 3, 0) == "Starting";
}

test "phase_to_status: zero ready with restarts is Broken" {
    assert phase_to_status(0, 1, 4) == "Broken";
}

test "phase_to_status: ready but recently restarted is Unstable" {
    assert phase_to_status(2, 2, 1) == "Unstable";
}

test "phase_to_status: nothing scheduled is Unknown" {
    assert phase_to_status(0, 0, 0) == "Unknown";
}

# ============================================================================
# Pure helper: owner_name_from_pod (controller-specific pod naming)
# ============================================================================
test "owner_name_from_pod: deployment pod strips two hash segments" {
    assert owner_name_from_pod("jaseci-7d9b5f8c4d-xk2p9") == "jaseci";
    assert owner_name_from_pod("jaseci-redis-698f764f94-lpw4c") == "jaseci-redis";
}

test "owner_name_from_pod: statefulset pod strips numeric ordinal" {
    assert owner_name_from_pod("jaseci-mongodb-0") == "jaseci-mongodb";
    assert owner_name_from_pod("jaseci-mongodb-2") == "jaseci-mongodb";
}

test "owner_name_from_pod: short/empty names returned as-is" {
    assert owner_name_from_pod("single") == "single";
    assert owner_name_from_pod("") == "";
}

# ============================================================================
# Pure helper: match_owner (longest known-name prefix wins)
# ============================================================================
test "match_owner: longest workload-name prefix wins" {
    names = ["jaseci", "jaseci-redis", "jaseci-redis-insight"];
    assert match_owner("jaseci-redis-insight-abc-def", names) == "jaseci-redis-insight";
    assert match_owner("jaseci-redis-698f-lpw4c", names) == "jaseci-redis";
    assert match_owner("jaseci-7d9b-xk2p9", names) == "jaseci";
}

test "match_owner: statefulset pod matches its workload" {
    names = ["jaseci", "jaseci-mongodb"];
    assert match_owner("jaseci-mongodb-0", names) == "jaseci-mongodb";
}

test "match_owner: no match falls back to name heuristic" {
    assert match_owner("other-app-7d9b-xk2p9", ["jaseci"]) == "other-app";
}
