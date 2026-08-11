"""The rollout scanner must judge only pods the deploy owns: the fleet's own
Deployments plus the companions it provisions beside them (postgres). A
namespace can also hold pods the deploy never touched - most commonly an
orphaned Deployment from a pre-rename generation of the same app - and a
crash-looping stranger must not fail a healthy rollout. The ImagePull and
stuck-ContainerCreating branches already guard on fleet membership; these
tests pin the same contract for the crash-loop branch, which shipped without
it, while keeping companion crashes fatal.

The scanner takes its CoreV1 client as a parameter, so these drive a real
KubernetesTarget with real kubernetes.client model objects; the only stand-in
is a hand-rolled pod-list stub at the API boundary. No cluster, no mocks."""

import from kubernetes.client {
    V1ContainerState,
    V1ContainerStateWaiting,
    V1ContainerStatus,
    V1ObjectMeta,
    V1Pod,
    V1PodList,
    V1PodStatus
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }


obj PodListStub {
    has pods: list;

    def list_namespaced_pod(namespace: str) -> V1PodList {
        return V1PodList(items=self.pods);
    }
}


def _cs(name: str, restarts: int, waiting_reason: str = "") -> V1ContainerStatus {
    waiting = V1ContainerStateWaiting(reason=waiting_reason)
        if waiting_reason
        else None;
    return V1ContainerStatus(
        name=name,
        image="jaseci/jaclang:test",
        image_id="",
        ready=(restarts == 0 and not waiting_reason),
        restart_count=restarts,
        state=V1ContainerState(waiting=waiting)
    );
}


def _pod(name: str, app: str, phase: str, statuses: list, pth: str = "") -> V1Pod {
    labels = {"app": app};
    if pth {
        labels["pod-template-hash"] = pth;
    }
    return V1Pod(
        metadata=V1ObjectMeta(name=name, labels=labels),
        status=V1PodStatus(
            phase=phase, init_container_statuses=[], container_statuses=statuses
        )
    );
}


def _target -> KubernetesTarget {
    return KubernetesTarget(
        config=KubernetesConfig(app_name="standup", namespace="jb-standup")
    );
}


def _scan(pods: list) -> dict {
    return _target()._scan_for_crash_loop(
        PodListStub(pods=pods),
        "jb-standup",
        {"6874b99c85", "8cb84f5d9"},
        {"main", "gateway"},
        {"standup-postgres"}
    );
}


glob _FLEET: list = [
         _pod(
             "main-deployment-6874b99c85-dh4p8",
             "main",
             "Running",
             [_cs("main", 0)],
             pth="6874b99c85"
         ),
         _pod(
             "gateway-deployment-8cb84f5d9-r88zb",
             "gateway",
             "Running",
             [_cs("gateway", 0)],
             pth="8cb84f5d9"
         )
     ];


test "a healthy fleet scans clean" {
    scan = _scan(_FLEET);
    assert scan["crash"] == "" , f"healthy fleet flagged: {scan['crash']}";
}


test "a crash-looping pod outside the fleet does not fail the deploy" {
    orphan = _pod(
        "standup-599456d78c-r7gcp",
        "standup",
        "Running",
        [_cs("standup", 26, waiting_reason="CrashLoopBackOff")],
        pth="599456d78c"
    );
    scan = _scan(_FLEET + [orphan]);
    assert scan["crash"] == "" , (
        f"an out-of-fleet pod failed the deploy: {scan['crash']}"
    );
}


test "a crash-looping pod from a stale fleet ReplicaSet stays ignored" {
    stale = _pod(
        "main-deployment-57bcd4f487-q4vf4",
        "main",
        "Running",
        [_cs("main", 26, waiting_reason="CrashLoopBackOff")],
        pth="57bcd4f487"
    );
    scan = _scan(_FLEET + [stale]);
    assert scan["crash"] == "" , f"stale-RS pod flagged: {scan['crash']}";
}


test "a genuine crash loop in the current fleet generation still fails" {
    crashing_fleet = [
        _pod(
            "main-deployment-6874b99c85-dh4p8",
            "main",
            "Running",
            [_cs("main", 7, waiting_reason="CrashLoopBackOff")],
            pth="6874b99c85"
        )
    ];
    scan = _scan(crashing_fleet);
    assert "crash-looping" in scan["crash"] , (
        f"a real fleet crash loop went undetected: {scan['crash']}"
    );
    assert "main-deployment-6874b99c85-dh4p8" in scan["crash"];
}


test "a crash-looping companion (postgres) still fails the deploy" {
    postgres = _pod(
        "standup-postgres-0",
        "standup-postgres",
        "Running",
        [_cs("postgres", 5, waiting_reason="CrashLoopBackOff")],
        pth="7bd94b56c"
    );
    scan = _scan(_FLEET + [postgres]);
    assert "crash-looping" in scan["crash"] , (
        f"a crashing companion went undetected: {scan['crash']}"
    );
    assert "standup-postgres" in scan["crash"];
}


test "with no fleet names every pod still counts (fail-safe)" {
    orphan = _pod(
        "standup-599456d78c-r7gcp",
        "standup",
        "Running",
        [_cs("standup", 26, waiting_reason="CrashLoopBackOff")]
    );
    scan = _target()._scan_for_crash_loop(
        PodListStub(pods=[orphan]), "jb-standup", set(), set()
    );
    assert "crash-looping" in scan["crash"] , (
        f"unknown-fleet scan lost its fail-safe: {scan['crash']}"
    );
}


test "out-of-fleet pods keep contributing to the phase diagnostics" {
    orphan = _pod(
        "standup-599456d78c-r7gcp",
        "standup",
        "Running",
        [_cs("standup", 26, waiting_reason="CrashLoopBackOff")],
        pth="599456d78c"
    );
    scan = _scan(_FLEET + [orphan]);
    assert any(["standup=" in t for t in scan["phases"]]) , (
        f"orphan vanished from diagnostics: {scan['phases']}"
    );
}
