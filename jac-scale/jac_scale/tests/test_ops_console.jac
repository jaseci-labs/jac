"""Tests for the V-track Ops Console pure helpers (V-02..V-06, V-10).

Every endpoint splits pure reshape/redaction/patch logic from the K8s I/O,
so these tests feed the pure helpers mocked `.to_dict()` payloads (the live
list/patch calls are integration-tested on a real cluster). Plus a
registration smoke test per mixin: the route exists (an unregistered
/admin/ops/* would fall to the SPA catchall and serve HTML).
"""

import from jac_scale.jserver.jserver { HTTPMethod }
import from jac_scale.jserver.jfast_api { JFastApiServer }

# Mixins (registration smoke tests).
import from jac_scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jac_scale.admin.network { JacAPIServerNetwork }
import from jac_scale.admin.images { JacAPIServerImages }
import from jac_scale.admin.events { JacAPIServerEvents }
import from jac_scale.admin.podenv { JacAPIServerPodEnv }
import from jac_scale.admin.actions { JacAPIServerActions }

# Pure helpers.
import from jac_scale.admin.deploy_health {
    summarize_deployment,
    summarize_pod,
    build_deploy_health
}
import from jac_scale.admin.network {
    endpoint_ready_counts,
    summarize_service,
    summarize_ingress,
    pvc_claimants,
    summarize_pvc
}
import from jac_scale.admin.images { build_image_freshness }
import from jac_scale.admin.events {
    is_pressure_reason,
    summarize_event,
    build_events
}
import from jac_scale.admin.podenv {
    is_allowed_key,
    redact_entry,
    pod_env_entries
}
import from jac_scale.admin.actions {
    restart_patch,
    scale_patch,
    unstick_patch,
    validate_replicas,
    validate_name
}


obj OpsHost(
    JacAPIServerDeployHealth,
    JacAPIServerNetwork,
    JacAPIServerImages,
    JacAPIServerEvents,
    JacAPIServerPodEnv,
    JacAPIServerActions
) {
    has server: any = None;
}


# --- registration smoke tests --------------------------------------------

test "every Ops Console mixin registers its /admin/ops/* route(s)" {
    host = OpsHost();
    host.server = JFastApiServer();
    host.register_deploy_health_endpoints();
    host.register_network_endpoints();
    host.register_images_endpoints();
    host.register_events_endpoints();
    host.register_podenv_endpoints();
    host.register_actions_endpoints();

    paths = [e.path for e in host.server._endpoints];
    for p in [
        "/admin/ops/deploy",
        "/admin/ops/network",
        "/admin/ops/images",
        "/admin/ops/events",
        "/admin/ops/podenv",
        "/admin/ops/actions/rollout-restart",
        "/admin/ops/actions/scale",
        "/admin/ops/actions/delete-pod",
        "/admin/ops/actions/unstick-pvc"
    ] {
        assert p in paths , f"missing route {p}";
    }
}


test "read endpoints are GET, action endpoints are POST" {
    host = OpsHost();
    host.server = JFastApiServer();
    host.register_deploy_health_endpoints();
    host.register_actions_endpoints();
    for ep in host.server._endpoints {
        if ep.path == "/admin/ops/deploy" {
            assert ep.method == HTTPMethod.GET;
        }
        if ep.path.startswith("/admin/ops/actions/") {
            assert ep.method == HTTPMethod.POST , f"{ep.path} should be POST";
        }
    }
}


# --- V-02 deploy health --------------------------------------------------

test "deploy: rollout complete vs stuck vs progressing" {
    complete = summarize_deployment({
        "metadata": {"name": "gw"},
        "spec": {"replicas": 2, "template": {"spec": {"containers": [{"image": "app:dev-abc"}]}}},
        "status": {"ready_replicas": 2, "available_replicas": 2, "updated_replicas": 2}
    });
    assert complete["rollout"]["status"] == "complete" , f"{complete['rollout']}";
    assert complete["images"] == ["app:dev-abc"];

    stuck = summarize_deployment({
        "metadata": {"name": "gw"},
        "spec": {"replicas": 2},
        "status": {
            "available_replicas": 1,
            "conditions": [{"type": "Progressing", "reason": "ProgressDeadlineExceeded", "message": "stuck"}]
        }
    });
    assert stuck["rollout"]["status"] == "stuck" , f"{stuck['rollout']}";

    prog = summarize_deployment({
        "metadata": {"name": "gw"},
        "spec": {"replicas": 3},
        "status": {"available_replicas": 1, "updated_replicas": 2}
    });
    assert prog["rollout"]["status"] == "progressing";
}


test "deploy: pod summary sums restarts + counts ready containers" {
    pod = summarize_pod({
        "metadata": {"name": "gw-1", "labels": {"app": "gateway"}},
        "spec": {"node_name": "node-a"},
        "status": {
            "phase": "Running",
            "container_statuses": [
                {"name": "a", "ready": True, "restart_count": 2, "image": "app:dev", "image_id": "app@sha256:1", "state": {"running": {}}},
                {"name": "b", "ready": False, "restart_count": 3, "state": {"waiting": {"reason": "CrashLoopBackOff"}}}
            ]
        }
    });
    assert pod["app"] == "gateway";
    assert pod["ready"] == 1 and pod["total"] == 2;
    assert pod["restarts"] == 5 , f"restarts={pod['restarts']}";
    assert pod["containers"][1]["reason"] == "CrashLoopBackOff";

    out = build_deploy_health("ns", [], [
        {"metadata": {"name": "z"}, "spec": {}, "status": {}},
        {"metadata": {"name": "a"}, "spec": {}, "status": {}}
    ]);
    assert out["available"] == True and out["namespace"] == "ns";
    assert out["pods"][0]["name"] == "a" , "pods should sort by name";
}


# --- V-03 network --------------------------------------------------------

test "network: endpoint ready counts + zero-backend service" {
    counts = endpoint_ready_counts({
        "subsets": [{"addresses": [{}, {}], "not_ready_addresses": [{}]}]
    });
    assert counts["ready"] == 2 and counts["not_ready"] == 1;

    svc = summarize_service(
        {"metadata": {"name": "gateway-service"}, "spec": {"type": "ClusterIP", "cluster_ip": "10.0.0.1", "ports": [{"port": 80, "target_port": 8000, "protocol": "TCP"}]}},
        {"gateway-service": {"ready": 0, "not_ready": 0}}
    );
    assert svc["ready_backends"] == 0 , "no endpoints -> 0 ready (the 503 cause)";
    assert svc["ports"][0]["port"] == 80;
}


test "network: ingress rule resolves host->path->service:port + LB" {
    ing = summarize_ingress({
        "metadata": {"name": "gw-ing"},
        "spec": {"rules": [{"host": "app.example.com", "http": {"paths": [{"path": "/", "backend": {"service": {"name": "gateway-service", "port": {"number": 80}}}}]}}]},
        "status": {"load_balancer": {"ingress": [{"hostname": "abc.elb.amazonaws.com"}]}}
    });
    assert ing["rules"][0]["service"] == "gateway-service";
    assert ing["rules"][0]["port"] == "80";
    assert ing["lb"] == ["abc.elb.amazonaws.com"];
}


test "network: PVC claimants resolved from pod volumes; phase surfaced" {
    pods = [
        {"metadata": {"name": "gw-1"}, "spec": {"volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]}},
        {"metadata": {"name": "gw-2"}, "spec": {"volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]}}
    ];
    claims = pvc_claimants(pods);
    assert claims["shared"] == ["gw-1", "gw-2"];

    pvc = summarize_pvc(
        {"metadata": {"name": "shared"}, "spec": {"storage_class_name": "gp3", "volume_name": "pv-1"}, "status": {"phase": "Bound", "capacity": {"storage": "5Gi"}}},
        claims
    );
    assert pvc["phase"] == "Bound" and pvc["capacity"] == "5Gi";
    assert pvc["claimants"] == ["gw-1", "gw-2"];
}


# --- V-06 image freshness ------------------------------------------------

test "images: cross-replica digest drift flagged; build_sha lifted" {
    pods = [
        {"metadata": {"name": "gw-1", "labels": {"app": "gateway"}},
         "spec": {"containers": [{"image": "app:dev-abc", "env": [{"name": "JAC_BUILD_SHA", "value": "abc123"}]}]},
         "status": {"container_statuses": [{"image_id": "app@sha256:AAA"}]}},
        {"metadata": {"name": "gw-2", "labels": {"app": "gateway"}},
         "spec": {"containers": [{"image": "app:dev-abc", "env": []}]},
         "status": {"container_statuses": [{"image_id": "app@sha256:BBB"}]}}
    ];
    out = build_image_freshness(pods);
    app = out["apps"][0];
    assert app["app"] == "gateway" and app["replicas"] == 2;
    assert app["drift"] == True , "two distinct digests for one tag = drift";
    assert app["build_sha"] == "abc123" , "build sha lifted from the replica that has it";

    # Same digest across replicas -> no drift.
    same = build_image_freshness([
        {"metadata": {"name": "g-1", "labels": {"app": "g"}}, "spec": {"containers": [{"image": "app:dev"}]}, "status": {"container_statuses": [{"image_id": "app@sha256:X"}]}},
        {"metadata": {"name": "g-2", "labels": {"app": "g"}}, "spec": {"containers": [{"image": "app:dev"}]}, "status": {"container_statuses": [{"image_id": "app@sha256:X"}]}}
    ]);
    assert same["apps"][0]["drift"] == False;
}


# --- V-05 events ---------------------------------------------------------

test "events: pressure reasons matched; Warning sorts first" {
    assert is_pressure_reason("OOMKilled") == True;
    assert is_pressure_reason("FailedScheduling") == True;
    assert is_pressure_reason("InsufficientMemory") == True;
    assert is_pressure_reason("Pulled") == False;

    ev = summarize_event({
        "type": "Warning",
        "reason": "OOMKilled",
        "message": "killed",
        "count": 3,
        "last_timestamp": "2026-06-10T00:00:00Z",
        "involved_object": {"kind": "Pod", "name": "gw-1"}
    });
    assert ev["pressure"] == True and ev["count"] == 3 and ev["kind"] == "Pod";

    out = build_events("ns", [
        {"type": "Normal", "reason": "Pulled", "last_timestamp": "2026-06-10T01:00:00Z", "involved_object": {}},
        {"type": "Warning", "reason": "OOMKilled", "last_timestamp": "2026-06-10T00:00:00Z", "involved_object": {}}
    ]);
    assert out["events"][0]["type"] == "Warning" , "warnings first";
    assert out["warnings"] == 1 and out["pressure"] == 1;
}


# --- V-04 pod env redaction ----------------------------------------------

test "podenv: allowlisted shown, others masked, secrets never resolved" {
    prefixes = ["OTEL_", "JAC_", "K8S_"];
    assert is_allowed_key("OTEL_EXPORTER_OTLP_ENDPOINT", prefixes) == True;
    assert is_allowed_key("MONGODB_URI", prefixes) == False;

    shown = redact_entry({"name": "JAC_BUILD_SHA", "value": "abc", "source": ""}, prefixes);
    assert shown["shown"] == True and shown["value"] == "abc";

    masked = redact_entry({"name": "MONGODB_URI", "value": "mongodb://u:p@h", "source": ""}, prefixes);
    assert masked["shown"] == False and masked["value"] != "mongodb://u:p@h";

    secret = redact_entry({"name": "JWT_SECRET", "value": "", "source": "secret"}, prefixes);
    assert secret["value"] == "(from secret)" and secret["shown"] == False;
}


test "podenv: pod env entries tag valueFrom source kind" {
    entries = pod_env_entries({
        "spec": {"containers": [{"env": [
            {"name": "OTEL_X", "value": "1"},
            {"name": "SECRET_X", "value_from": {"secret_key_ref": {"name": "s"}}}
        ]}]}
    });
    assert entries[0]["source"] == "";
    assert entries[1]["source"] == "secret";
}


# --- V-10 mutation patch builders + validators ---------------------------

test "actions: patch bodies have the expected shape" {
    rp = restart_patch("2026-06-10T00:00:00Z");
    assert rp["spec"]["template"]["metadata"]["annotations"]["jac-scale.ops/restartedAt"] == "2026-06-10T00:00:00Z";

    assert scale_patch(3)["spec"]["replicas"] == 3;

    # Finalizer clear is `null` so the array is removed.
    assert unstick_patch()["metadata"]["finalizers"] == None;
}


test "actions: validators clamp replicas + reject empty names" {
    assert validate_replicas(3)["ok"] == True and validate_replicas(3)["value"] == 3;
    assert validate_replicas(-1)["ok"] == False;
    assert validate_replicas(9999)["ok"] == False , "above max rejected";
    assert validate_replicas("x")["ok"] == False;

    assert validate_name("") != "" , "empty name rejected";
    assert validate_name("gateway-deployment") == "" , "valid name ok";
}
