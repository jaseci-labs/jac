"""`[scale.monitoring].enabled` must decide whether the metrics stack deploys.
The observability path force-set `monitoring_enabled = True` on the config it
handed the deployer, so a configured `false` was overridden and a configured
`true` alone never reached the deployer at all. Real config objects, no mocks:
`gateway_config` is injected as a plain dict, which is the same seam
`_gateway_cfg` reads in production."""
import re;
import tempfile;
import yaml;
import from kubernetes { client as k8s }

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


def _relabel(
    rules: list[dict[str, any]], meta: dict[str, str]
) -> (dict[str, str] | None) {
    labels = dict(meta);
    for rule in rules {
        value = ";".join(
            [labels.get(src, "") for src in rule.get("source_labels", [])]
        );
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
        app_name="t",
        namespace="t-ns",
        container_port=8000,
        metrics_endpoint="/app-metrics"
    );
    scrape = yaml.safe_load(
        MonitoringDeployer(k8s_config=config)._scrape_config("t", "t-ns")
    );
    job = {j["job_name"]: j for j in scrape["scrape_configs"]}["t"];
    assert job["kubernetes_sd_configs"]
        == [
            {
                "role": "pod",
                "namespaces": {"names": ["t-ns"]},
                "selectors": [{"role": "pod", "label": FLEET_SELECTOR}]
            }
        ];
    assert job["basic_auth"]["password_file"]
        == "/etc/prometheus/scrape-secret/password";
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


test "Alloy discovers pods only in the namespace it was deployed for" {
    obs = _target(monitoring=False, logs=True)._build_observability_config();
    for ns in ["t-ns", "other-ns"] {
        config = MonitoringDeployer(k8s_config=obs)._alloy_config("t", ns);
        discovery = config.split('discovery.kubernetes "pods" {', 1)[1].split(
            "\n}\n", 1
        )[0];
        assert f'names = ["{ns}"]' in discovery , discovery;
    }
}


def _stored(on: bool, extra: (dict[str, any] | None) = None) -> MonitoringDeployer {
    # from_dict drops keys the config does not declare, so code without the
    # feature fails on what it builds, not on the constructor.
    return MonitoringDeployer(
        k8s_config=KubernetesConfig.from_dict(
            KubernetesConfig,
            {
                "app_name": "t",
                "namespace": "t-ns",
                "monitoring_enabled": True,
                "loki_enabled": True,
                "tracing_enabled": True,
                "monitoring_storage_enabled": on
            }
                | (extra or {})
        )
    );
}


def _data_pods(
    deployer: MonitoringDeployer
) -> list[tuple[str, dict[str, any], dict[str, any]]] {
    built = [
        ("prometheus", deployer._prometheus_deployment("t", "t-ns")),
        ("loki", deployer._loki_deployment("t", "t-ns")),
        ("tempo", deployer._tempo_deployment("t", "t-ns"))
    ];
    return [
        (
            name,
            made["spec"],
            {v["name"]: v for v in made["spec"]["template"]["spec"]["volumes"]}[
                f"{name}-data"
            ]
        ) for (name, made) in built
    ];
}


def _prometheus_args(deployer: MonitoringDeployer, volume_size: str = "") -> list[str] {
    made = deployer._prometheus_deployment("t", "t-ns", volume_size);
    return made["spec"]["template"]["spec"]["containers"][0]["args"];
}


test "with storage on, each data volume is a claim the pod can write to, the rollout cannot hang and the volume cannot fill" {
    for (component, spec, volume) in _data_pods(_stored(True)) {
        pod = spec["template"]["spec"];
        container = pod["containers"][0];
        # The deployer merges into the live Deployment. A volume keeps its old
        # source and the strategy its rollingUpdate unless both are cleared,
        # and the API refuses either leftover.
        assert volume
            == {
                "name": f"{component}-data",
                "persistentVolumeClaim": {"claimName": f"t-{component}-data"},
                "emptyDir": None
            } , (component, volume);
        assert spec.get("strategy") == {"type": "Recreate", "rollingUpdate": None} , (
            component,
            spec.get("strategy")
        );
        # A new volume is owned by root and these processes are not.
        security = pod["securityContext"];
        assert (security.get("fsGroup"), security.get("fsGroupChangePolicy"))
            == (container["securityContext"]["runAsUser"], "OnRootMismatch") , (
            component,
            security
        );
        # A log kept across restarts is replayed on start, and liveness on
        # /ready would kill a long replay and start it again.
        if "livenessProbe" in container {
            assert container.get("startupProbe", {}).get("httpGet")
                == container["livenessProbe"]["httpGet"] , (component, container);
        }
    }
    # A size cap alone drops Prometheus's 15-day default, so both are passed.
    # The cap is 80% of the volume the claim really has: not of the setting
    # when a resize was refused, and the API may write it in thousandths.
    args = _prometheus_args(_stored(True, {"prometheus_storage": "10Gi"}));
    assert args[-2:]
        == [
            "--storage.tsdb.retention.time=15d",
            "--storage.tsdb.retention.size=8192MB"
        ] , args;
    raised = _stored(True, {"prometheus_storage": "30Gi"});
    assert _prometheus_args(raised, "10Gi")[-1]
        == "--storage.tsdb.retention.size=8192MB";
    assert _prometheus_args(raised, "1181116006400m")[-1]
        == "--storage.tsdb.retention.size=901MB";
    # Loki had no retention. It reads its config once, so the pod template
    # carries a hash of it and a changed period restarts the pod.
    hashes: list[str] = [];
    for period in ["72h", "96h"] {
        deployer = _stored(True, {"loki_retention": period});
        loki = yaml.safe_load(deployer._loki_config());
        assert loki.get("compactor")
            == {"retention_enabled": True, "delete_request_store": "filesystem"} , loki;
        assert loki["limits_config"].get("retention_period") == period , loki;
        template = deployer._loki_deployment("t", "t-ns")["spec"]["template"];
        hashes.append(
            template["metadata"].get("annotations", {}).get("checksum/config", "")
        );
    }
    assert hashes[0] and hashes[1] and hashes[0] != hashes[1] , hashes;
}


test "with storage off, the three pods are built as before: nothing storage set is left behind and no request that was not asked for" {
    off = _stored(False);
    for (component, spec, volume) in _data_pods(off) {
        template = spec["template"];
        # Not a null either: that would clear a request another tool put on.
        assert "resources" not in template["spec"]["containers"][0] , component;
        # Off is a patch too: what on sets is cleared, which changes nothing
        # for an app that never turned it on.
        assert volume
            == {
                "name": f"{component}-data",
                "emptyDir": {},
                "persistentVolumeClaim": None
            } , (component, volume);
        assert spec.get("strategy") == {"type": "RollingUpdate"} , (component, spec);
        assert template["spec"]["securityContext"]
            == {
                "seccompProfile": {"type": "RuntimeDefault"},
                "fsGroup": None,
                "fsGroupChangePolicy": None
            } , (component, template["spec"]["securityContext"]);
        assert template["spec"]["containers"][0].get("startupProbe")
            is None , component;
        # A changed pod template restarts the pod, and on emptyDir a restart
        # is the data loss.
        if component != "prometheus" {
            assert template["metadata"] == {"labels": {"app": f"t-{component}"}} , (
                component,
                template["metadata"]
            );
        }
    }
    assert _prometheus_args(off) == _prometheus_args(_stored(True))[:-2];
    assert "compactor" not in yaml.safe_load(off._loki_config());
    # A request is sent for a key that is set and for no other. An empty
    # string is how a profile unsets one, and an unquoted number arrives as a
    # number.
    asked = _stored(
        False,
        {
            "prometheus_cpu_request": "100m",
            "prometheus_memory_request": "768Mi",
            "loki_cpu_request": "",
            "loki_memory_request": " 1Gi ",
            "tempo_cpu_request": 0.5
        }
    );
    assert {
        component: spec["template"]["spec"]["containers"][0].get("resources")
        for (component, spec, _) in _data_pods(asked)
    }
        == {
            "prometheus": {"requests": {"cpu": "100m", "memory": "768Mi"}},
            "loki": {"requests": {"memory": "1Gi"}},
            "tempo": {"requests": {"cpu": "0.5"}}
        };
    assert asked._request_problems() == [];
}


def _storage_target(
    retention: str, observability: bool = True, extra: (dict[str, any] | None) = None
) -> KubernetesTarget {
    # The kubeconfig does not exist, so a deploy that got past the storage
    # check would fail on its first cluster call instead of reaching one.
    return KubernetesTarget(
        config=KubernetesConfig.from_dict(
            KubernetesConfig,
            {
                "app_name": "t",
                "namespace": "t-ns",
                "monitoring_enabled": observability,
                "monitoring_storage_enabled": True,
                "loki_retention": retention,
                "kubeconfig": "/nonexistent/jac-10940-kubeconfig"
            }
                | (extra or {})
        ),
        gateway_config={"logs": {"enabled": observability}},
        dry_run=True
    );
}


test "monitoring settings that cannot be applied refuse the deploy before anything is applied" {
    assert _stored(True)._storage_problems() == [];
    # The size parser forgives "10 Gi" and "1_0Gi" and Kubernetes does not.
    # Loki crash-loops on a period it cannot parse. jac.toml is not
    # type-checked, so an unquoted number arrives as a number. Kubernetes
    # takes "768m" as memory (under one byte) and "1Gi" as CPU, and that pod
    # never schedules.
    for (key, bad) in [
        ("loki_storage", "1.5Gi"),
        ("tempo_storage", "500Mi"),
        ("prometheus_storage", "10 Gi"),
        ("tempo_storage", "1_0Gi"),
        ("prometheus_storage", 30),
        ("loki_retention", "2h"),
        ("loki_retention", "١٦٨h"),
        ("loki_retention", "9999999h"),
        ("loki_retention", 168),
        ("loki_memory_request", "768m"),
        ("prometheus_cpu_request", "1Gi"),
        ("tempo_memory_request", "512"),
        ("tempo_memory_request", 512),
        ("loki_cpu_request", "١٠٠m"),
        ("prometheus_cpu_request", True)
    ] {
        checked = _stored(True, {key: bad});
        problems = checked._storage_problems() + checked._request_problems();
        assert len(problems) == 1 and key in problems[0] , (key, bad, problems);
    }
    # A part this deploy does not run is not this deploy's to refuse.
    for (off, key, bad) in [
        ("tracing_enabled", "tempo_storage", "500Mi"),
        ("loki_enabled", "loki_storage", "ten"),
        ("loki_enabled", "loki_retention", "2h"),
        ("monitoring_enabled", "prometheus_storage", "10 Gi"),
        ("tracing_enabled", "tempo_memory_request", "768m")
    ] {
        skipped = _stored(True, {off: False, key: bad});
        assert skipped._storage_problems() + skipped._request_problems() == [] , (
            off,
            key
        );
    }
    # A claim on a class the cluster lacks stays Pending after Recreate has
    # stopped the old pod, so the class is checked first.
    for (wanted, classes, refused) in [
        ("", {"gp3": True}, False),
        ("", {"gp3": False}, True),
        ("", {}, True),
        ("gp3", {"gp3": False}, False),
        ("fast", {"gp3": True}, True)
    ] {
        problem = _stored(
            True, {"monitoring_storage_class": wanted}
        )._storage_class_problem(
            classes
        );
        assert bool(problem) == refused , (wanted, classes, problem);
    }
    # Only for a claim that still has to be made, though: one that exists is
    # used as it is. And a cluster that cannot be asked is not a reason to
    # refuse. Nothing listens on the port, so the client raises from the HTTP
    # layer, not from the API.
    deployer = _stored(True, {"tracing_enabled": False});
    assert deployer._claims_to_make("t", {"t-prometheus-data", "t-loki-data"}) == [];
    assert deployer._claims_to_make("t", {"t-prometheus-data"}) == ["t-loki-data"];
    unreachable = k8s.Configuration();
    unreachable.host = "http://127.0.0.1:1";
    unreachable.retries = 0;
    core_v1 = k8s.CoreV1Api(k8s.ApiClient(unreachable));
    storage_v1 = k8s.StorageV1Api(k8s.ApiClient(unreachable));
    assert deployer._existing_data_claims(core_v1, "t", "t-ns") is None;
    assert deployer._storage_classes(storage_v1) is None;
    assert deployer._cluster_storage_problem("t", "t-ns", core_v1, storage_v1) == "";
    # The observability step runs after the app is applied, inside a try that
    # turns any error into a warning, so the deploy asks first and stops. An
    # app that asked for no stack has nothing to refuse. A request is checked
    # with storage on or off, and a storage setting only with it on: an app
    # that never turned storage on is not refused for one.
    request = {"loki_memory_request": "768m"};
    unstored = {"monitoring_storage_enabled": False};
    for (retention, observability, extra, refused) in [
        ("2h", True, request, ["loki_retention", "loki_memory_request"]),
        ("168h", True, {}, []),
        ("2h", False, request, []),
        ("2h", True, unstored, []),
        ("2h", True, unstored | request, ["loki_memory_request"])
    ] {
        refusal = _storage_target(
            retention, observability, extra
        )._monitoring_settings_refusal(
            "t", check_cluster=False
        );
        named = [
            key
            for key in ["loki_retention", "loki_memory_request"]
            if key in refusal
        ];
        assert named == refused and bool(refusal) == bool(refused) , (
            retention,
            observability,
            extra,
            refusal
        );
    }
    with tempfile.TemporaryDirectory() as project {
        result = _storage_target("2h").deploy(
            AppConfig(code_folder=project, file_name="main.jac")
        );
        assert result.success == False and "loki_retention" in str(result.message) , (
            result.message
        );
    }
}


test "a data claim is the app's own, asks for the configured size and class, and is never taken to be larger than its volume" {
    # The role keeps it out of the bundle and shared-volume sweeps, and the
    # owner tells a neighbour's claim from this app's. No class named: the
    # cluster's default provisions it. Space around a size is allowed, and
    # what is sent is the size without it.
    padded = _stored(True, {"loki_storage": " 20Gi "});
    assert padded._storage_problems() == [];
    assert padded._data_pvc("t", "t-ns", "loki")
        == {
            "apiVersion": "v1",
            "kind": "PersistentVolumeClaim",
            "metadata": {
                "name": "t-loki-data",
                "namespace": "t-ns",
                "labels": {
                    "app": "t-loki",
                    "managed": "jac-scale",
                    "jac-scale.role": "monitoring-data",
                    "jac-scale.owner": "t"
                }
            },
            "spec": {
                "accessModes": ["ReadWriteOnce"],
                "resources": {"requests": {"storage": "20Gi"}}
            }
        };
    classed = _stored(True, {"monitoring_storage_class": "gp3"})._data_pvc(
        "t", "t-ns", "tempo"
    )["spec"];
    assert (classed["storageClassName"], classed["resources"]["requests"]["storage"])
        == ("gp3", "5Gi");
    # Prometheus is capped at a share of this. A resize asked for is not one
    # that happened, so a capacity the claim reports always wins over a
    # request, and without one the smaller request is the safe guess.
    for (capacity, requested, asked, want) in [
        ("10Gi", "30Gi", "30Gi", "10Gi"),
        ("1181116006400m", "2Gi", "2Gi", "1181116006400m"),
        (None, "10Gi", "30Gi", "10Gi"),
        (None, "30Gi", "10Gi", "10Gi"),
        ("not-a-size", "2Gi", "4Gi", "2Gi"),
        (None, None, "30Gi", "30Gi")
    ] {
        got = padded._claim_size(capacity, requested, asked);
        assert got == want , (capacity, requested, asked, got);
    }
}
