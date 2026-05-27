"""Tests for the admin /workloads endpoints.

These tests run without a real Prometheus instance, so they exercise the
graceful-degradation path (metrics_available: false) and the admin-auth gate.
"""

import from jac_scale.tests.scale_test_client { make_client, extract_data }

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

test "workload detail requires admin" {
    client = make_client();
    try {
        response = client.get("/admin/workloads/jac-app");
        assert response.status_code == 403;
    } finally {
        client.close();
    }
}

test "workload timeseries requires admin" {
    client = make_client();
    try {
        response = client.get("/admin/workloads/jac-app/timeseries");
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
