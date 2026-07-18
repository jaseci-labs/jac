import time;
import kubernetes;
import from datetime { datetime, timezone, timedelta }
import from types { SimpleNamespace }
import unittest.mock;
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

def _cs(
    name: str,
    restarts: int = 0,
    waiting_reason: str = "",
    last_term_reason: str = "",
    last_term_message: str = "",
    last_term_exit: int = 0
) -> object {
    waiting = SimpleNamespace(reason=waiting_reason, message="")
        if waiting_reason
        else None;
    last_term = None;
    if last_term_reason or last_term_message {
        last_term = SimpleNamespace(
            reason=last_term_reason, message=last_term_message, exit_code=last_term_exit
        );
    }
    return SimpleNamespace(
        name=name,
        restart_count=restarts,
        state=SimpleNamespace(waiting=waiting, terminated=None, running=None),
        last_state=SimpleNamespace(terminated=last_term)
    );
}

def _pod(
    name: str, app: str, phase: str, inits: list, mains: list, deleting: bool = False
) -> object {
    return SimpleNamespace(
        metadata=SimpleNamespace(
            name=name,
            labels={"app": app},
            deletion_timestamp=("2026-01-01T00:00:00Z" if deleting else None)
        ),
        status=SimpleNamespace(
            phase=phase,
            init_container_statuses=inits,
            container_statuses=mains,
            conditions=[]
        ),
        spec=SimpleNamespace(volumes=[])
    );
}

def _bundle(deploy_name: str, app: str) -> dict {
    return {
        "deployments": {
            app: {
                "metadata": {"name": deploy_name},
                "spec": {"selector": {"matchLabels": {"app": app}}}
            }
        }
    };
}

def _apis(ready: int, pods: list) -> tuple {
    apps = unittest.mock.MagicMock();
    apps.read_namespaced_deployment.return_value = SimpleNamespace(
        status=SimpleNamespace(ready_replicas=ready)
    );
    core = unittest.mock.MagicMock();
    core.list_namespaced_pod.return_value = SimpleNamespace(items=pods);
    core.list_namespaced_event.return_value = SimpleNamespace(items=[]);
    return (apps, core);
}

def _run(
    target: object, bundle: dict, apps: object, core: object, timeout: int
) -> object {
    err = None;
    with unittest.mock.patch.object(
        kubernetes.client, "AppsV1Api", return_value=apps
    ) {
        with unittest.mock.patch.object(
            kubernetes.client, "CoreV1Api", return_value=core
        ) {
            with unittest.mock.patch.object(target, "_load_kube_config") {
                with unittest.mock.patch.object(time, "sleep") {
                    try {
                        target._wait_for_fleet_rollout(bundle, timeout=timeout);
                    } except Exception as e {
                        err = e;
                    }
                }
            }
        }
    }
    return err;
}

test "init-container crashloop surfaces jac-bootstrap exec format error" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs(
        "jac-bootstrap",
        restarts=3,
        waiting_reason="CrashLoopBackOff",
        last_term_reason="StartError",
        last_term_message="exec /app/.jachome/.local/bin/jac: exec format error",
        last_term_exit=1
    );
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], []);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 60);

    assert err is not None , "expected a failure to be raised";
    msg = str(err);
    assert "jac-bootstrap" in msg , f"bootstrap container not named: {msg}";
    assert "exec format error" in msg , f"terminated message not surfaced: {msg}";
    assert "crash-looping" in msg , f"crashloop not reported: {msg}";
}

test "image pull failure fails fast after it persists" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    app_c = _cs("gateway", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [], [app_c]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 60);

    assert err is not None , "expected an image-pull failure";
    assert "cannot pull image" in str(err) , f"image pull reason missing: {err}";
    assert "ImagePullBackOff" in str(err) , f"image pull reason missing: {err}";
}

test "unrelated failing pod does not abort the fleet" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    stranger = _cs("prometheus", restarts=9, waiting_reason="ImagePullBackOff");
    pod = _pod("prometheus-xyz", "prometheus", "Pending", [], [stranger]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 15);

    assert err is not None , "deployment never became ready, expected timeout";
    assert "timed out" in str(err) , f"expected a timeout, got: {err}";
    assert "cannot pull image" not in str(err) , (
        f"out-of-fleet pod must not trigger early-fail: {err}"
    );
}

test "ready fleet returns without raising" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    (apps, core) = _apis(1, []);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 60);

    assert err is None , f"ready fleet should not raise: {err}";
}

test "multiple image-pull containers do not fail on the first poll" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    c1 = _cs("init-a", restarts=0, waiting_reason="ImagePullBackOff");
    c2 = _cs("app", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [c1], [c2]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 5);

    assert err is not None , "deployment never became ready, expected timeout";
    assert "timed out" in str(err) , f"expected timeout on a single poll: {err}";
    assert "cannot pull image" not in str(err) , (
        f"two image-pull containers must not fast-fail on the first poll: {err}"
    );
}

test "multiple image-pull containers still fail once it persists" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    c1 = _cs("init-a", restarts=0, waiting_reason="ImagePullBackOff");
    c2 = _cs("app", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [c1], [c2]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 60);

    assert err is not None , "expected an image-pull failure";
    assert "cannot pull image" in str(err) , f"image pull reason missing: {err}";
}

test "crashloop is reported before image-pull in the same poll" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs(
        "jac-bootstrap",
        restarts=3,
        waiting_reason="CrashLoopBackOff",
        last_term_reason="StartError",
        last_term_message="exec format error",
        last_term_exit=1
    );
    puller = _cs("app", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], [puller]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 60);

    assert err is not None , "expected a crashloop failure";
    assert "crash-looping" in str(err) , f"crashloop should take priority: {err}";
    assert "cannot pull image" not in str(err) , (
        f"crashloop must not be masked by image-pull: {err}"
    );
}

test "persistent pull failure is healed once, then fails when it recurs" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    app_c = _cs("gateway", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [], [app_c]);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 120);

    # First persistence triggers one reschedule; the mock keeps returning the
    # same wedged pod, so the replacement "fails too" and the rollout aborts
    # through the normal path.
    assert core.delete_namespaced_pod.call_count == 1 , (
        f"expected exactly one self-heal delete, got "
        f"{core.delete_namespaced_pod.call_count}"
    );
    assert err is not None , "expected the recurring pull failure to abort";
    assert "cannot pull image" in str(err) , f"pull reason missing: {err}";
}

test "a heal that unwedges the pod lets the rollout succeed" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    app_c = _cs("gateway", restarts=0, waiting_reason="ImagePullBackOff");
    pod = _pod("gateway-xyz", "gateway", "Pending", [], [app_c]);
    (apps, core) = _apis(0, [pod]);
    not_ready = SimpleNamespace(status=SimpleNamespace(ready_replicas=0));
    ready = SimpleNamespace(status=SimpleNamespace(ready_replicas=1));
    apps.read_namespaced_deployment.side_effect = [
        not_ready,
        not_ready,
        ready,
        ready,
        ready
    ];

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 120);

    assert err is None , f"rollout should succeed after the heal: {err}";
    assert core.delete_namespaced_pod.call_count == 1;
}

test "pod stuck ContainerCreating with FailedMount events is healed" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs("wait-for-mongodb", restarts=0, waiting_reason="ContainerCreating");
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], []);
    (apps, core) = _apis(0, [pod]);
    core.list_namespaced_event.return_value = SimpleNamespace(
        items=[
            SimpleNamespace(
                reason="FailedMount",
                last_timestamp=datetime.now(timezone.utc),
                event_time=None,
                first_timestamp=None
            )
        ]
    );

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 400);

    assert core.delete_namespaced_pod.call_count == 1 , (
        f"expected one mount-wedge heal, got "
        f"{core.delete_namespaced_pod.call_count}"
    );
    assert err is not None and "timed out" in str(err) , (
        f"budget-exhausted wedge should reach the normal timeout: {err}"
    );
}

test "slow ContainerCreating without FailedMount events is left alone" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs("wait-for-mongodb", restarts=0, waiting_reason="ContainerCreating");
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], []);
    (apps, core) = _apis(0, [pod]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 400);

    assert core.delete_namespaced_pod.call_count == 0 , (
        "a merely slow pod must never be deleted"
    );
    assert err is not None and "timed out" in str(err);
}


test "a stale FailedMount event from a recovered hiccup never heals" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs("wait-for-mongodb", restarts=0, waiting_reason="ContainerCreating");
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], []);
    (apps, core) = _apis(0, [pod]);
    core.list_namespaced_event.return_value = SimpleNamespace(
        items=[
            SimpleNamespace(
                reason="FailedMount",
                last_timestamp=datetime.now(timezone.utc) - timedelta(minutes=45),
                event_time=None,
                first_timestamp=None
            )
        ]
    );

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 400);

    assert core.delete_namespaced_pod.call_count == 0 , (
        "an event 45 minutes old is history, not a wedge"
    );
    assert err is not None and "timed out" in str(err);
}

test "a pod running init containers (PodInitializing) is never mount-healed" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    boot = _cs("jac-bootstrap", restarts=0, waiting_reason="PodInitializing");
    pod = _pod("gateway-xyz", "gateway", "Pending", [boot], []);
    (apps, core) = _apis(0, [pod]);
    core.list_namespaced_event.return_value = SimpleNamespace(
        items=[
            SimpleNamespace(
                reason="FailedMount",
                last_timestamp=datetime.now(timezone.utc),
                event_time=None,
                first_timestamp=None
            )
        ]
    );

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 400);

    assert core.delete_namespaced_pod.call_count == 0 , (
        "PodInitializing means volumes mounted; a slow init is not a wedge"
    );
    assert err is not None and "timed out" in str(err);
}


test "a terminating pod is invisible to the scanner (no false re-abort)" {
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="jac-shop", namespace="ns")
    );
    app_c = _cs("gateway", restarts=0, waiting_reason="ImagePullBackOff");
    dying = _pod("gateway-old", "gateway", "Pending", [], [app_c], deleting=True);
    (apps, core) = _apis(0, [dying]);

    err = _run(target, _bundle("gateway-deployment", "gateway"), apps, core, 120);

    assert core.delete_namespaced_pod.call_count == 0 , (
        "a pod already terminating must not be counted or re-healed"
    );
    assert err is not None and "timed out" in str(err) , (
        f"only the plain timeout may fire: {err}"
    );
}
