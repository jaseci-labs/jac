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


def _destroy(mgr: unittest.mock.MagicMock, component: str = "") {
    mgr.core.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    target = KubernetesMicroserviceTarget(
        config=KubernetesConfig(namespace="jac-test")
    );
    with unittest.mock.patch.object(
        KubernetesMicroserviceTarget, "_load_kube_config", unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch.object(KubernetesTarget, "destroy", mgr.base) {
            with unittest.mock.patch(
                "jaclang.scale.deploy.target.kubernetes.microservice.target.AutoscalerFactory"
            ) {
                with unittest.mock.patch(
                    "kubernetes.client.AppsV1Api", return_value=mgr.apps
                ) {
                    with unittest.mock.patch(
                        "kubernetes.client.CoreV1Api", return_value=mgr.core
                    ) {
                        with unittest.mock.patch(
                            "kubernetes.client.PolicyV1Api", return_value=mgr.policy
                        ) {
                            with unittest.mock.patch(
                                "kubernetes.client.NetworkingV1Api",
                                return_value=mgr.net
                            ) {
                                target.destroy("shop", component);
                            }
                        }
                    }
                }
            }
        }
    }
}


test "microservice destroy hands shared teardown to the base target" {
    # Without the base pass the bundle PVC and the namespace leak: nothing in
    # the label-based cleanup deletes them.
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
