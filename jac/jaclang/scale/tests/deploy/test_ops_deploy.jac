"""Focused tests for V-02 deploy-health pure reshape helpers + registration.

The K8s `.to_dict()` reshaping is pure, so these feed mocked payloads (the
live list calls are integration-tested on a real cluster).
"""

import from jaclang.runtimelib.serving.endpoint { HTTPMethod }
import from jaclang.scale.server.native_server { NativeJServer }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.deploy_health { summarize_deployment, summarize_pod }


obj DeployHost(JacAPIServerDeployHealth) {
    has server: any = None;
}


test "rollout status: complete vs stuck vs progressing" {
    complete = summarize_deployment(
        {
            "metadata": {"name": "gw"},
            "spec": {
                "replicas": 2,
                "template": {"spec": {"containers": [{"image": "app:dev-abc"}]}}
            },
            "status": {
                "ready_replicas": 2,
                "available_replicas": 2,
                "updated_replicas": 2
            }
        }
    );
    assert complete["rollout"]["status"] == "complete";
    assert complete["images"] == ["app:dev-abc"];

    # A deliberate scale-to-zero is complete, not stuck in "progressing".
    zeroed = summarize_deployment(
        {"metadata": {"name": "z"}, "spec": {"replicas": 0}, "status": {}}
    );
    assert zeroed["rollout"]["status"] == "complete" , f"{zeroed['rollout']}";

    stuck = summarize_deployment(
        {
            "metadata": {"name": "gw"},
            "spec": {"replicas": 2},
            "status": {
                "available_replicas": 1,
                "conditions": [
                    {
                        "type": "Progressing",
                        "reason": "ProgressDeadlineExceeded",
                        "message": "stuck"
                    }
                ]
            }
        }
    );
    assert stuck["rollout"]["status"] == "stuck";
}

test "rollout status agrees with the deploy gate on stale and draining states" {
    draining = summarize_deployment(
        {
            "metadata": {"name": "gw", "generation": 5},
            "spec": {"replicas": 2},
            "status": {
                "observed_generation": 5,
                "replicas": 3,
                "updated_replicas": 2,
                "available_replicas": 2,
                "ready_replicas": 2
            }
        }
    );
    assert draining["rollout"]["status"] == "progressing" , (
        f"an old replica is still serving: {draining['rollout']}"
    );

    unobserved = summarize_deployment(
        {
            "metadata": {"name": "gw", "generation": 6},
            "spec": {"replicas": 2},
            "status": {
                "observed_generation": 5,
                "replicas": 2,
                "updated_replicas": 2,
                "available_replicas": 2,
                "ready_replicas": 2,
                "conditions": [
                    {
                        "type": "Progressing",
                        "reason": "ProgressDeadlineExceeded",
                        "message": "stuck"
                    }
                ]
            }
        }
    );
    assert unobserved["rollout"]["status"] == "progressing" , (
        "a status describing the previous spec is neither complete nor "
        f"stuck: {unobserved['rollout']}"
    );
}


test "pod summary sums restarts + counts ready containers" {
    pod = summarize_pod(
        {
            "metadata": {"name": "gw-1", "labels": {"app": "gateway"}},
            "spec": {"node_name": "node-a"},
            "status": {
                "phase": "Running",
                "container_statuses": [
                    {
                        "name": "a",
                        "ready": True,
                        "restart_count": 2,
                        "state": {"running": {}}
                    },
                    {
                        "name": "b",
                        "ready": False,
                        "restart_count": 3,
                        "state": {"waiting": {"reason": "CrashLoopBackOff"}}
                    }
                ]
            }
        }
    );
    assert pod["ready"] == 1 and pod["total"] == 2;
    assert pod["restarts"] == 5 , f"restarts={pod['restarts']}";
    assert pod["containers"][1]["reason"] == "CrashLoopBackOff";
}


test "register adds GET /admin/ops/deploy" {
    host = DeployHost();
    host.server = NativeJServer();
    host.register_deploy_health_endpoints();
    eps = [
        e
        for e in host.server._endpoints
        if e.path == "/admin/ops/deploy"
    ];
    assert len(eps) == 1 and eps[0].method == HTTPMethod.GET;
}

test "a baseline-free stall verdict carries when the controller stamped it" {
    stuck = summarize_deployment(
        {
            "metadata": {"name": "gw", "generation": 6},
            "spec": {"replicas": 2},
            "status": {
                "observed_generation": 6,
                "replicas": 2,
                "updated_replicas": 0,
                "available_replicas": 2,
                "ready_replicas": 2,
                "conditions": [
                    {
                        "type": "Progressing",
                        "reason": "ProgressDeadlineExceeded",
                        "message": "timed out progressing",
                        "last_update_time": "2026-08-11T10:00:00Z"
                    }
                ]
            }
        }
    );
    assert stuck["rollout"]["status"] == "stuck" , f"{stuck['rollout']}";
    assert stuck["rollout"]["reason"] == "ProgressDeadlineExceeded" , (
        f"the machine-readable verdict stays isolated: {stuck['rollout']}"
    );
    message = stuck["rollout"]["message"];
    assert "2026-08-11T10:00:00Z" in message and "may predate" in message , (
        "a single read has no previous poll to inherit a mark from, so the "
        f"verdict must carry when it was stamped: {message!r}"
    );
}
