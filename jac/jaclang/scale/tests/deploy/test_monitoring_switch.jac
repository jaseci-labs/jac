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
    # from_dict reads the storage keys where the config declares them and drops
    # them where it does not, so code without the feature fails on what it
    # builds instead of on the constructor.
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


def _data_deployments(
    deployer: MonitoringDeployer
) -> list[tuple[str, dict[str, any]]] {
    return [
        ("prometheus", deployer._prometheus_deployment("t", "t-ns")),
        ("loki", deployer._loki_deployment("t", "t-ns")),
        ("tempo", deployer._tempo_deployment("t", "t-ns"))
    ];
}


test "with storage on, each data volume is a claim the pod can write to and the rollout cannot hang" {
    for (component, deployment) in _data_deployments(_stored(True)) {
        spec = deployment["spec"];
        pod = spec["template"]["spec"];
        container = pod["containers"][0];
        volume = {v["name"]: v for v in pod["volumes"]}[f"{component}-data"];
        assert volume.get("persistentVolumeClaim")
            == {"claimName": f"t-{component}-data"} , (component, volume);
        # The deployer merges its manifest into the live Deployment. A volume
        # merged by name keeps its old source, and the API refuses a volume
        # with two, so the old one is cleared in the same entry.
        assert "emptyDir" in volume and volume["emptyDir"] is None , (
            component,
            volume
        );
        # The volume attaches to one node, so starting the new pod before the
        # old one stops never finishes. The rollingUpdate the server filled in
        # is cleared too, or it refuses Recreate.
        assert spec.get("strategy") == {"type": "Recreate", "rollingUpdate": None} , (
            component,
            spec.get("strategy")
        );
        # A new volume is owned by root and these processes are not.
        security = pod["securityContext"];
        assert security.get("fsGroup") == container["securityContext"]["runAsUser"] , (
            component,
            security
        );
        assert security.get("fsGroupChangePolicy") == "OnRootMismatch" , component;
        # A log kept across restarts is replayed on start. Liveness on /ready
        # would kill a long replay and start it again, forever.
        if "livenessProbe" in container {
            assert container.get("startupProbe", {}).get("httpGet")
                == container["livenessProbe"]["httpGet"] , (component, container);
        }
    }
}


test "with storage off, the three pods are built as before and nothing storage set is left behind" {
    off = _stored(False);
    for (component, deployment) in _data_deployments(off) {
        spec = deployment["spec"];
        pod = spec["template"]["spec"];
        container = pod["containers"][0];
        volume = {v["name"]: v for v in pod["volumes"]}[f"{component}-data"];
        assert volume.get("emptyDir") == {} , (component, volume);
        # Switching back off is a patch too: each field storage sets is
        # cleared, which changes nothing for an app that never turned it on.
        assert "persistentVolumeClaim" in volume
            and volume["persistentVolumeClaim"] is None , (component, volume);
        assert spec.get("strategy") == {"type": "RollingUpdate"} , (
            component,
            spec.get("strategy")
        );
        assert pod["securityContext"]
            == {
                "seccompProfile": {"type": "RuntimeDefault"},
                "fsGroup": None,
                "fsGroupChangePolicy": None
            } , (component, pod["securityContext"]);
        assert container.get("startupProbe") is None , (component, container);
    }
    # A changed pod template restarts the pod, and on emptyDir a restart is
    # the data loss. What the template carried before is what it carries now.
    prometheus = off._prometheus_deployment("t", "t-ns")["spec"]["template"];
    assert prometheus["spec"]["containers"][0]["args"]
        == [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles",
            "--web.enable-lifecycle"
        ];
    for name in ["loki", "tempo"] {
        template = dict(_data_deployments(off))[name]["spec"]["template"];
        assert template["metadata"] == {"labels": {"app": f"t-{name}"}} , (
            name,
            template["metadata"]
        );
    }
    assert "compactor" not in yaml.safe_load(off._loki_config());
}


test "with storage on, Prometheus and Loki are bounded so the volume cannot fill" {
    deployer = _stored(True, {"prometheus_storage": "10Gi", "loki_retention": "72h"});
    args = deployer._prometheus_deployment("t", "t-ns")["spec"]["template"]["spec"][
        "containers"
    ][0]["args"];
    caps = [
        a.split("=", 1)[1]
        for a in args
        if a.startswith("--storage.tsdb.retention.size=")
    ];
    assert caps == ["8192MB"] , args;
    # A size cap on its own drops Prometheus's 15-day default, so the time
    # limit is passed with it.
    assert "--storage.tsdb.retention.time=15d" in args , args;
    # The cap is worked out from the volume the claim really has. A size
    # raised on a class that cannot expand leaves the old volume in place, and
    # 80% of the new setting would be more than that volume holds.
    raised = _stored(True, {"prometheus_storage": "30Gi"});
    on_old_volume = raised._prometheus_deployment("t", "t-ns", "10Gi")["spec"][
        "template"
    ]["spec"]["containers"][0]["args"];
    assert "--storage.tsdb.retention.size=8192MB" in on_old_volume , on_old_volume;
    # The API server can write a capacity in thousandths of a byte. It is
    # still the volume the claim has: 80% of about 1.1Gi, not of the 2Gi
    # that was asked for.
    odd = raised._prometheus_deployment("t", "t-ns", "1181116006400m")["spec"][
        "template"
    ]["spec"]["containers"][0]["args"];
    assert "--storage.tsdb.retention.size=901MB" in odd , odd;

    loki = yaml.safe_load(deployer._loki_config());
    assert loki.get("compactor")
        == {"retention_enabled": True, "delete_request_store": "filesystem"} , loki;
    assert loki["limits_config"].get("retention_period") == "72h" , loki;
    # Loki reads its config once, at start. The pod has to restart when the
    # retention changes, so its template carries a hash of the config.
    hashes = [
        _stored(True, {"loki_retention": period})._loki_deployment("t", "t-ns")["spec"][
            "template"
        ]["metadata"].get(
            "annotations", {}
        ).get(
            "checksum/config"
        ) for period in ["72h", "96h"]
    ];
    assert hashes[0] and hashes[1] and hashes[0] != hashes[1] , hashes;
}


test "storage settings that would take the stack down are refused before anything is deployed" {
    assert _stored(True)._storage_problems() == [];
    for (key, bad) in [
        ("prometheus_storage", "ten"),
        ("loki_storage", "1.5Gi"),
        ("tempo_storage", "500Mi"),
        # The size parser forgives both of these and Kubernetes does not, so
        # they would pass here and be refused when the claim is made, after
        # the app is already applied.
        ("prometheus_storage", "10 Gi"),
        ("tempo_storage", "1_0Gi"),
        ("loki_retention", "2h"),
        ("loki_retention", "soon"),
        # Loki reads only ASCII digits and has an upper limit; a period it
        # cannot parse crash-loops it after Recreate stopped the old pod.
        ("loki_retention", "\u0661\u0666\u0668h"),
        ("loki_retention", "9999999h"),
        # jac.toml is not type-checked, so an unquoted number arrives as one.
        ("prometheus_storage", 30),
        ("loki_retention", 168)
    ] {
        problems = _stored(True, {key: bad})._storage_problems();
        assert len(problems) == 1 and key in problems[0] , (key, bad, problems);
    }
    # A part this deploy does not run is not this deploy's to refuse: a size
    # left over for Tempo must not stop an app that has tracing off.
    for (off, key, bad) in [
        ("tracing_enabled", "tempo_storage", "500Mi"),
        ("loki_enabled", "loki_storage", "ten"),
        ("loki_enabled", "loki_retention", "2h"),
        ("monitoring_enabled", "prometheus_storage", "10 Gi")
    ] {
        assert _stored(True, {off: False, key: bad})._storage_problems() == [] , (
            off,
            key
        );
    }
    # A claim on a class the cluster does not have stays Pending. Recreate has
    # stopped the old pod by then, so the class is checked first.
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
}


test "each data claim is the app's own and asks for the configured size and class" {
    claim = _stored(True, {"loki_storage": "20Gi"})._data_pvc("t", "t-ns", "loki");
    assert claim["metadata"]["name"] == "t-loki-data";
    assert claim["metadata"]["namespace"] == "t-ns";
    # The role keeps it out of the bundle and shared-volume sweeps, and the
    # owner is what tells a neighbour's claim from this app's on destroy.
    assert claim["metadata"]["labels"]
        == {
            "app": "t-loki",
            "managed": "jac-scale",
            "jac-scale.role": "monitoring-data",
            "jac-scale.owner": "t"
        };
    # No class named: the cluster's default class provisions it.
    assert claim["spec"]
        == {
            "accessModes": ["ReadWriteOnce"],
            "resources": {"requests": {"storage": "20Gi"}}
        };
    classed = _stored(True, {"monitoring_storage_class": "gp3"})._data_pvc(
        "t", "t-ns", "tempo"
    );
    assert classed["spec"]["storageClassName"] == "gp3";
    assert classed["spec"]["resources"]["requests"]["storage"] == "5Gi";
    # What is checked is what is sent: space around a size is allowed, and the
    # claim asks for the size without it.
    padded = _stored(True, {"loki_storage": " 20Gi "});
    assert padded._storage_problems() == [];
    assert padded._data_pvc("t", "t-ns", "loki")["spec"]["resources"]["requests"][
        "storage"
    ]
        == "20Gi";
}


def _storage_target(
    extra: dict[str, any], observability: bool = True, dry_run: bool = False
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
                "kubeconfig": "/nonexistent/jac-10940-kubeconfig"
            }
                | extra
        ),
        gateway_config={
            "logs": {"enabled": observability},
            "tracing": {"enabled": observability}
        },
        dry_run=dry_run
    );
}


test "storage settings that cannot be applied refuse the deploy, instead of a warning after it" {
    # The observability stack is applied after the app, inside a try that
    # turns any error into a warning. A setting the user wrote on purpose and
    # that cannot be applied would then leave monitoring as it was under a
    # deploy that reports success, so the deploy asks first and stops.
    refusal = _storage_target({"loki_retention": "2h"})._monitoring_storage_refusal(
        "t", check_cluster=False
    );
    assert "loki_retention" in refusal , refusal;
    assert _storage_target({})._monitoring_storage_refusal("t", check_cluster=False)
        == "";
    # No stack is deployed for an app that asked for none, so its storage
    # settings are not this deploy's to refuse.
    assert _storage_target(
        {"loki_retention": "2h"}, observability=False
    )._monitoring_storage_refusal(
        "t", check_cluster=False
    )
        == "";
    # The deploy itself returns the refusal, before it provisions anything.
    with tempfile.TemporaryDirectory() as project {
        result = _storage_target({"loki_retention": "2h"}, dry_run=True).deploy(
            AppConfig(code_folder=project, file_name="main.jac")
        );
        assert result.success == False;
        assert "loki_retention" in str(result.message) , result.message;
    }
}


test "the size a data claim is taken to have is never more than its volume" {
    # Prometheus is capped at a share of this. A resize that is asked for is
    # not a resize that happened, so a capacity the claim reports always wins
    # over a request, and without one the smaller request is the safe guess.
    deployer = _stored(True);
    for (capacity, requested, asked, want) in [
        ("10Gi", "30Gi", "30Gi", "10Gi"),
        ("1181116006400m", "2Gi", "2Gi", "1181116006400m"),
        (None, "10Gi", "30Gi", "10Gi"),
        (None, "30Gi", "10Gi", "10Gi"),
        ("not-a-size", "2Gi", "4Gi", "2Gi"),
        (None, None, "30Gi", "30Gi")
    ] {
        got = deployer._claim_size(capacity, requested, asked);
        assert got == want , (capacity, requested, asked, got);
    }
}


test "the storage class matters only for a claim that still has to be made, and only when it can be asked" {
    deployer = _stored(True, {"tracing_enabled": False});
    # A claim that exists is used as it is, so a later deploy does not depend
    # on the class it came from.
    assert deployer._claims_to_make("t", {"t-prometheus-data", "t-loki-data"}) == [];
    assert deployer._claims_to_make("t", {"t-prometheus-data"}) == ["t-loki-data"];
    assert deployer._claims_to_make("t", set()) == ["t-prometheus-data", "t-loki-data"];
    # A cluster that cannot be reached raises from the HTTP layer, not from
    # the API. Either way the question went unanswered, which is not a reason
    # to refuse the deploy. Nothing listens on the port.
    unreachable = k8s.Configuration();
    unreachable.host = "http://127.0.0.1:1";
    unreachable.retries = 0;
    api = k8s.ApiClient(unreachable);
    assert deployer._existing_data_claims(k8s.CoreV1Api(api), "t", "t-ns") is None;
    assert deployer._storage_classes(k8s.StorageV1Api(api)) is None;
    assert deployer._cluster_storage_problem(
        "t", "t-ns", k8s.CoreV1Api(api), k8s.StorageV1Api(api)
    )
        == "";
}
