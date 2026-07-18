import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTarget
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

glob MS_SELECTOR: str = (
         "managed=jac-scale,jac-scale.role in (microservice,gateway)"
     );


def _target -> KubernetesTarget {
    return KubernetesTarget(config=KubernetesConfig(namespace="jac-test"));
}


def _run_destroy_application(mgr: unittest.mock.MagicMock) {
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.AutoscalerFactory"
    ) {
        with unittest.mock.patch(
            "kubernetes.client.NetworkingV1Api", return_value=unittest.mock.MagicMock()
        ) {
            _target()._destroy_application("shop", "jac-test", mgr.apps, mgr.core);
        }
    }
}


test "label-managed workloads are deleted before the bundle PVC" {
    mgr = unittest.mock.MagicMock();
    _run_destroy_application(mgr);

    calls = [str(c[0]) for c in mgr.mock_calls];
    workloads = calls.index("apps.delete_collection_namespaced_deployment");
    pvc = calls.index("core.delete_namespaced_persistent_volume_claim");
    assert workloads < pvc;

    kwargs = mgr.apps.delete_collection_namespaced_deployment.call_args.kwargs;
    assert kwargs["label_selector"] == MS_SELECTOR;
    assert kwargs["namespace"] == "jac-test";
}


test "a cluster with no managed workloads (404) does not abort the teardown" {
    mgr = unittest.mock.MagicMock();
    mgr.apps.delete_collection_namespaced_deployment.side_effect = ApiException(
        status=404
    );
    _run_destroy_application(mgr);
    mgr.core.delete_namespaced_persistent_volume_claim.assert_called();
}


test "non-404 errors deleting managed workloads do abort" {
    mgr = unittest.mock.MagicMock();
    mgr.apps.delete_collection_namespaced_deployment.side_effect = ApiException(
        status=500
    );
    caught = False;
    try {
        _run_destroy_application(mgr);
    } except ApiException {
        caught = True;
    }
    assert caught;
    mgr.core.delete_namespaced_persistent_volume_claim.assert_not_called();
}
