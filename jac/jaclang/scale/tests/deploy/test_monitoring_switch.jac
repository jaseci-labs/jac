"""`[scale.monitoring].enabled` must decide whether the metrics stack deploys.
The observability path force-set `monitoring_enabled = True` on the config it
handed the deployer, so a configured `false` was overridden and a configured
`true` alone never reached the deployer at all. Real config objects, no mocks:
`gateway_config` is injected as a plain dict, which is the same seam
`_gateway_cfg` reads in production."""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.deploy.target.kubernetes.monitoring { MonitoringDeployer }
import yaml;


def _target(
    monitoring: bool, logs: bool = False, tracing: bool = False
) -> KubernetesTarget {
    return KubernetesTarget(
        config=KubernetesConfig(
            app_name="t", namespace="t-ns", monitoring_enabled=monitoring
        ),
        gateway_config={"logs": {"enabled": logs}, "tracing": {"enabled": tracing}}
    );
}


test "a disabled monitoring switch is not overridden on the way to the deployer" {
    target = _target(monitoring=False, logs=True);
    obs = target._build_observability_config();
    assert obs.monitoring_enabled == False;
    assert obs.loki_enabled == True;
}


test "an enabled monitoring switch reaches the deployer" {
    target = _target(monitoring=True);
    obs = target._build_observability_config();
    assert obs.monitoring_enabled == True;
}


test "the monitoring switch alone requests the observability stack" {
    assert _target(monitoring=True)._observability_requested() == True;
}


test "logs or tracing still request the stack without the monitoring switch" {
    assert _target(monitoring=False, logs=True)._observability_requested() == True;
    assert _target(monitoring=False, tracing=True)._observability_requested() == True;
}


test "nothing enabled requests nothing" {
    assert _target(monitoring=False)._observability_requested() == False;
}


test "prometheus scrapes every gateway and app pod in the fleet" {
    deployer = MonitoringDeployer(
        KubernetesConfig(app_name="t", namespace="t-ns", container_port=8000)
    );
    scrape = yaml.safe_load(deployer._scrape_config("t", "t-ns"));
    jobs = {j["job_name"]: j for j in scrape["scrape_configs"]};
    app_job = jobs["t"];
    assert "static_configs" not in app_job;
    assert app_job["kubernetes_sd_configs"]
        == [{"role": "pod", "namespaces": {"names": ["t-ns"]}}];
    assert app_job["basic_auth"]["password_file"]
        == "/etc/prometheus/scrape-secret/password";
    keeps = {
        ";".join(rule["source_labels"]): rule["regex"]
        for rule in app_job["relabel_configs"]
        if rule.get("action") == "keep"
    };
    assert keeps
        == {
            "__meta_kubernetes_pod_label_managed;__meta_kubernetes_pod_label_jac_scale_role": "jac-scale;(gateway|microservice)",
            "__meta_kubernetes_pod_container_port_number": "8000"
        };
    target_labels = [
        rule["target_label"]
        for rule in app_job["relabel_configs"]
        if "target_label" in rule
    ];
    assert target_labels == ["role", "app", "pod"];
}
