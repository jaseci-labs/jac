import kubernetes;
import unittest.mock;
import jaclang.scale.deploy.target.kubernetes.microservice.target as target_mod;
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def _target(logs: bool, tracing: bool) -> KubernetesMicroserviceTarget {
    return KubernetesMicroserviceTarget(
        config=KubernetesConfig(app_name="shop", namespace="shop-ns"),
        microservices_config={
            "logs": {"enabled": logs},
            "tracing": {"enabled": tracing}
        }
    );
}


test "observability disabled tears down any stack a prior deploy left" {
    t = _target(False, False);
    with unittest.mock.patch.object(t, "_load_kube_config"), unittest.mock.patch.object(
        kubernetes.client, "AppsV1Api"
    ), unittest.mock.patch.object(kubernetes.client, "CoreV1Api"), unittest.mock.patch.object(
        target_mod, "MonitoringDeployer"
    ) as Deployer {
        t._deploy_observability("shop");
        Deployer.return_value.destroy.assert_called_once();
        (app, ns) = Deployer.return_value.destroy.call_args[0][:2];
        assert app == "shop";
        assert ns == "shop-ns";
        assert not Deployer.return_value.deploy.called;
    }
}


test "observability enabled deploys the stack and does not destroy" {
    t = _target(True, False);
    with unittest.mock.patch.object(t, "_load_kube_config"), unittest.mock.patch.object(
        kubernetes.client, "AppsV1Api"
    ), unittest.mock.patch.object(kubernetes.client, "CoreV1Api"), unittest.mock.patch.object(
        target_mod, "get_cluster_provider"
    ), unittest.mock.patch.object(t, "_ensure_privileged_namespace"), unittest.mock.patch.object(
        t, "_build_observability_config"
    ), unittest.mock.patch.object(target_mod, "MonitoringDeployer") as Deployer {
        t._deploy_observability("shop");
        Deployer.return_value.deploy.assert_called_once();
        assert not Deployer.return_value.destroy.called;
    }
}
