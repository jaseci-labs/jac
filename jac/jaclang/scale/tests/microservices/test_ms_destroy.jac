import contextlib;
import unittest.mock;
import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTarget
}
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def _mocked_cluster(mgr: unittest.mock.MagicMock) -> contextlib.ExitStack {
    stack = contextlib.ExitStack();
    stack.enter_context(
        unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "_load_kube_config", unittest.mock.MagicMock()
        )
    );
    stack.enter_context(
        unittest.mock.patch.object(KubernetesTarget, "destroy", mgr.base)
    );
    stack.enter_context(
        unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.microservice.target.AutoscalerFactory"
        )
    );
    stack.enter_context(
        unittest.mock.patch("kubernetes.client.AppsV1Api", return_value=mgr.apps)
    );
    stack.enter_context(
        unittest.mock.patch("kubernetes.client.CoreV1Api", return_value=mgr.core)
    );
    stack.enter_context(
        unittest.mock.patch("kubernetes.client.PolicyV1Api", return_value=mgr.policy)
    );
    stack.enter_context(
        unittest.mock.patch("kubernetes.client.NetworkingV1Api", return_value=mgr.net)
    );
    return stack;
}


def _destroy(mgr: unittest.mock.MagicMock, component: str = "") {
    mgr.core.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(namespace="jac-test")
    );
    with _mocked_cluster(mgr) {
        target.destroy("shop", component);
    }
}


test "microservice destroy hands shared teardown to the base target" {
    mgr = unittest.mock.MagicMock();
    _destroy(mgr);
    mgr.base.assert_called_once_with("shop");
}


test "the fleet is deleted before the base teardown removes the PVCs" {
    mgr = unittest.mock.MagicMock();
    _destroy(mgr);
    calls = [str(c[0]) for c in mgr.mock_calls];
    fleet = calls.index("apps.delete_collection_namespaced_deployment");
    base = calls.index("base");
    assert fleet < base;
}


test "component destroy passes straight through to the base target" {
    mgr = unittest.mock.MagicMock();
    _destroy(mgr, component="database");
    mgr.base.assert_called_once_with("shop", "database");
    mgr.apps.delete_collection_namespaced_deployment.assert_not_called();
}
