import unittest.mock;
import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget,
    crashloop_reason,
    deployment_rolled_out
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def _deployment(
    generation: int,
    observed: int,
    want: int,
    updated: int,
    total: int,
    available: int,
    ready: int = 0
) -> SimpleNamespace {
    return SimpleNamespace(
        metadata=SimpleNamespace(generation=generation, name="svc-deployment"),
        spec=SimpleNamespace(replicas=want),
        status=SimpleNamespace(
            observed_generation=observed,
            updated_replicas=updated,
            replicas=total,
            available_replicas=available,
            ready_replicas=ready
        )
    );
}


def _pod(name: str, restarts: int = 0, init_restarts: int = 0) -> SimpleNamespace {
    return SimpleNamespace(
        metadata=SimpleNamespace(name=name, labels={"app": name}),
        status=SimpleNamespace(
            phase="Pending",
            container_statuses=[SimpleNamespace(restart_count=restarts)],
            init_container_statuses=[SimpleNamespace(restart_count=init_restarts)]
        )
    );
}


test "a fully available current generation is rolled out" {
    dep = _deployment(1, 1, 1, 1, 1, 1, ready=1);
    assert deployment_rolled_out(dep);
}


test "old-ReplicaSet ready pods do not count for the new generation" {
    # Redeploy: pods of the previous ReplicaSet are still Ready while the new
    # generation's pods crash-loop; ready_replicas alone looks healthy.
    stale_status = _deployment(2, 1, 1, 0, 1, 1, ready=1);
    assert not deployment_rolled_out(stale_status);
    observed_but_not_updated = _deployment(2, 2, 1, 0, 1, 1, ready=1);
    assert not deployment_rolled_out(observed_but_not_updated);
}


test "draining old pods block rollout completion" {
    dep = _deployment(2, 2, 1, 1, 2, 1, ready=2);
    assert not deployment_rolled_out(dep);
}


test "missing status fields mean not rolled out" {
    dep = SimpleNamespace(
        metadata=SimpleNamespace(generation=1, name="svc-deployment"),
        spec=SimpleNamespace(replicas=None),
        status=SimpleNamespace(
            observed_generation=None,
            updated_replicas=None,
            replicas=None,
            available_replicas=None,
            ready_replicas=None
        )
    );
    assert not deployment_rolled_out(dep);
}


test "crash-looping init container is reported" {
    reason = crashloop_reason(_pod("gateway-abc", init_restarts=5));
    assert "gateway-abc" in reason;
    assert "5 restarts" in reason;
}


test "crash-looping app container is reported" {
    reason = crashloop_reason(_pod("orders-xyz", restarts=4));
    assert "orders-xyz" in reason;
}


test "a few restarts are not a crash loop" {
    assert crashloop_reason(_pod("gateway-abc", restarts=2, init_restarts=2)) == "";
}


def _target -> KubernetesMicroserviceTarget {
    return KubernetesMicroserviceTarget(config=KubernetesConfig(namespace="jac-test"));
}


glob _BUNDLE: dict[str, any] = {
         "deployments": {"svc": {"metadata": {"name": "svc-deployment"}}}
     };


test "fleet wait returns once the new generation serves" {
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_deployment.side_effect = [
        _deployment(2, 1, 1, 0, 1, 1, ready=1),
        _deployment(2, 2, 1, 1, 1, 1, ready=1)
    ];
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_pod.return_value = SimpleNamespace(items=[_pod("svc-abc")]);
    with unittest.mock.patch.object(
        KubernetesMicroserviceTarget, "_load_kube_config", unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch("kubernetes.client.AppsV1Api", return_value=apps_v1) {
            with unittest.mock.patch(
                "kubernetes.client.CoreV1Api", return_value=core_v1
            ) {
                with unittest.mock.patch("time.sleep") {
                    _target()._wait_for_fleet_rollout(_BUNDLE, timeout=60);
                }
            }
        }
    }
    assert apps_v1.read_namespaced_deployment.call_count == 2;
}


test "fleet wait fails fast on an init-container crash loop" {
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_deployment.return_value = _deployment(1, 1, 1, 0, 1, 0);
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_pod.return_value = SimpleNamespace(
        items=[_pod("svc-abc", init_restarts=6)]
    );
    caught = "";
    with unittest.mock.patch.object(
        KubernetesMicroserviceTarget, "_load_kube_config", unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch("kubernetes.client.AppsV1Api", return_value=apps_v1) {
            with unittest.mock.patch(
                "kubernetes.client.CoreV1Api", return_value=core_v1
            ) {
                with unittest.mock.patch("time.sleep") {
                    try {
                        _target()._wait_for_fleet_rollout(_BUNDLE, timeout=60);
                    } except Exception as e {
                        caught = str(e);
                    }
                }
            }
        }
    }
    assert "crash-looping" in caught;
    assert "svc-abc" in caught;
}
