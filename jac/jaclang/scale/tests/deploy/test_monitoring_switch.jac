"""`[scale.monitoring].enabled` must decide whether the metrics stack deploys.
The observability path force-set `monitoring_enabled = True` on the config it
handed the deployer, so a configured `false` was overridden and a configured
`true` alone never reached the deployer at all. Real config objects, no mocks:
`gateway_config` is injected as a plain dict, which is the same seam
`_gateway_cfg` reads in production."""
import re;
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


test "kube-state-metrics reads no secrets or configmaps and watches only what it is granted" {
    # A cluster-wide LIST on secrets or configmaps returns their data, so a
    # grant there hands every tenant's credentials to this pod's token.
    # `--resources` must match the grant, or kube-state-metrics keeps retrying
    # the types it is forbidden from.
    obs = _target(monitoring=True)._build_observability_config();
    rbac = MonitoringDeployer(k8s_config=obs)._kube_state_metrics_rbac("t", "t-ns");
    granted: list[str] = [];
    for rule in rbac["cluster_role"]["rules"] {
        assert sorted(rule["verbs"]) == ["list", "watch"] , rule;
        for res in rule["resources"] {
            granted.append(res);
        }
    }
    for forbidden in ["secrets", "configmaps"] {
        assert forbidden not in granted , forbidden;
    }
    watched = [
        a
        for a in rbac["args"]
        if a.startswith("--resources=")
    ];
    assert len(watched) == 1 , rbac["args"];
    assert sorted(watched[0].split("=", 1)[1].split(",")) == sorted(granted);
    binding = rbac["cluster_role_binding"];
    assert binding["roleRef"]["name"] == rbac["cluster_role"]["metadata"]["name"];
    assert binding["subjects"][0]["namespace"] == "t-ns";
}


def _relabel(rules: list[dict[str, any]], meta: dict[str, str]) -> (dict[str, str] | None) {
    labels = dict(meta);
    for rule in rules {
        value = ";".join([labels.get(src, "") for src in rule.get("source_labels", [])]);
        matched = re.fullmatch(str(rule.get("regex", "(.*)")), value);
        if rule.get("action", "replace") == "keep" {
            if not matched {
                return None;
            }
        } elif matched {
            replacement = str(rule.get("replacement", "$1")).replace("$1", "\\1");
            labels[rule["target_label"]] = matched.expand(replacement);
        }
    }
    return labels;
}


test "prometheus scrapes every fleet pod on the app port at the path its role serves" {
    config = KubernetesConfig(
        app_name="t", namespace="t-ns", container_port=8000, metrics_endpoint="/app-metrics"
    );
    scrape = yaml.safe_load(MonitoringDeployer(k8s_config=config)._scrape_config("t", "t-ns"));
    job = {j["job_name"]: j for j in scrape["scrape_configs"]}["t"];
    assert job["kubernetes_sd_configs"]
        == [
            {
                "role": "pod",
                "namespaces": {"names": ["t-ns"]},
                "selectors": [{"role": "pod", "label": FLEET_SELECTOR}]
            }
        ];
    assert job["basic_auth"]["password_file"] == "/etc/prometheus/scrape-secret/password";
    for (role, port, want_path) in [
        ("gateway", "8000", "/metrics"),
        ("microservice", "8000", "/app-metrics"),
        ("microservice", "", None)
    ] {
        target = _relabel(
            job["relabel_configs"],
            {
                "__metrics_path__": job["metrics_path"],
                "__meta_kubernetes_pod_label_jac_scale_role": role,
                "__meta_kubernetes_pod_container_port_number": port,
                "__meta_kubernetes_pod_label_app": "svc",
                "__meta_kubernetes_pod_name": "svc-0"
            }
        );
        if want_path is None {
            assert target is None , (role, port);
            continue;
        }
        assert target is not None , (role, port);
        assert target["__metrics_path__"] == want_path , (role, target);
        assert (target["role"], target["app"], target["pod"]) == (role, "svc", "svc-0");
    }
}
