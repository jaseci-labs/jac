"""`[scale.monitoring].enabled` must decide whether the metrics stack deploys.
The observability path force-set `monitoring_enabled = True` on the config it
handed the deployer, so a configured `false` was overridden and a configured
`true` alone never reached the deployer at all. Real config objects, no mocks:
`gateway_config` is injected as a plain dict, which is the same seam
`_gateway_cfg` reads in production."""

def _target(
    monitoring: bool,
    logs: bool = False,
    tracing: bool = False,
    k8s_metrics: bool = True
) -> KubernetesTarget {
    return KubernetesTarget(
        config=KubernetesConfig(
            app_name="t",
            namespace="t-ns",
            monitoring_enabled=monitoring,
            k8s_metrics_enabled=k8s_metrics
        ),
        gateway_config={"logs": {"enabled": logs}, "tracing": {"enabled": tracing}}
    );
}


def _needs_privileged(target: KubernetesTarget) -> bool {
    return MonitoringDeployer(
        target._build_observability_config(), None
    ).needs_privileged_namespace();
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
    assert _needs_privileged(_target(monitoring=True)) == True , "node-exporter";
    no_node_metrics = _target(monitoring=True, k8s_metrics=False);
    assert _needs_privileged(no_node_metrics) == False , "no hostPath component";
}


test "logs or tracing still request the stack without the monitoring switch" {
    assert _target(monitoring=False, logs=True)._observability_requested() == True;
    assert _target(monitoring=False, tracing=True)._observability_requested() == True;
    assert _needs_privileged(_target(monitoring=False, logs=True)) == True;
    assert _needs_privileged(_target(monitoring=False, tracing=True)) == False , (
        "tracing alone runs Alloy without host paths, so the sandbox stays"
    );
}


test "nothing enabled requests nothing" {
    assert _target(monitoring=False)._observability_requested() == False;
}


obj _DeleteLog {
    has deleted: list[str] = [],
        forbidden: bool = False;

    def delete_namespaced_daemon_set(name: str, namespace: str) {
        import from kubernetes.client.exceptions { ApiException }
        if self.forbidden {
            raise ApiException(status=403);
        }
        self.deleted.append(f"DaemonSet/{name}");
    }

    def delete_namespaced_service(name: str, namespace: str) {
        self.deleted.append(f"Service/{name}");
    }
}


obj _WarnLog {
    has warnings: list[str] = [];

    def warn(message: str, *args: any) {
        self.warnings.append(message);
    }
}


test "a host-path DaemonSet that is switched off is removed on the next deploy" {
    node_exporter = ["DaemonSet/t-node-exporter", "Service/t-node-exporter-service"];
    alloy = ["DaemonSet/t-alloy", "Service/t-alloy-service"];
    for (label, target, expected) in [
        ("everything off", _target(monitoring=False), node_exporter + alloy),
        (
            "k8s metrics off",
            _target(monitoring=True, k8s_metrics=False),
            node_exporter + alloy
        ),
        ("tracing keeps Alloy", _target(monitoring=False, tracing=True), node_exporter),
        ("all on", _target(monitoring=True, logs=True), [])
    ] {
        log = _DeleteLog();
        MonitoringDeployer(
            target._build_observability_config(), None
        ).retire_unwanted_node_daemonsets(
            "t", "t-ns", log, log
        );
        assert log.deleted == expected , (label, log.deleted);
    }

    denied = _DeleteLog(forbidden=True);
    warned = _WarnLog();
    MonitoringDeployer(
        _target(monitoring=False)._build_observability_config(), warned
    ).retire_unwanted_node_daemonsets(
        "t", "t-ns", denied, denied
    );
    assert denied.deleted == [] , denied.deleted;
    assert len(warned.warnings) == 2 , warned.warnings;
}


test "Alloy mounts host paths only for logs, and a redeploy replaces it" {
    import unittest.mock;
    import from kubernetes.client.exceptions { ApiException }
    import from jaclang.scale.deploy.target.kubernetes { monitoring as monitoring_mod }

    def _render(logs: bool, exists: bool) -> tuple[str, dict[str, any]] {
        sent: list[tuple[str, dict[str, any]]] = [];
        def _read(**kwargs: any) {
            if not exists {
                raise ApiException(status=404);
            }
        }
        def _create(**kwargs: any) {
            sent.append(("create", kwargs["body"]));
        }
        def _replace(**kwargs: any) {
            sent.append(("replace", kwargs["body"]));
        }
        apps_v1 = unittest.mock.MagicMock();
        apps_v1.read_namespaced_daemon_set.side_effect = _read;
        apps_v1.create_namespaced_daemon_set.side_effect = _create;
        apps_v1.replace_namespaced_daemon_set.side_effect = _replace;
        obs = _target(
            monitoring=False, logs=logs, tracing=True
        )._build_observability_config();
        with unittest.mock.patch.object(
            monitoring_mod, "client", unittest.mock.MagicMock()
        ) {
            MonitoringDeployer(obs, None)._deploy_alloy(
                "t", "t-ns", apps_v1, unittest.mock.MagicMock()
            );
        }
        assert len(sent) == 1 , sent;
        return sent[0];
    }

    for (logs, exists, verb) in [
        (False, False, "create"),
        (True, False, "create"),
        (False, True, "replace"),
        (True, True, "replace"),

    ] {
        (sent_verb, body) = _render(logs, exists);
        assert sent_verb == verb , (logs, exists, sent_verb);
        pod = body["spec"]["template"]["spec"];
        host_paths = [
            v["hostPath"]["path"]
            for v in pod["volumes"]
            if "hostPath" in v
        ];
        mounted = [m["mountPath"] for m in pod["containers"][0]["volumeMounts"]];
        if logs {
            assert host_paths == ["/var/log/pods", "/var/lib/docker/containers"];
            assert "/var/log/pods" in mounted;
        } else {
            assert host_paths == [] , "tracing alone must not mount the node";
            assert mounted == ["/etc/alloy"];
        }
    }
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


test "every controller that can recreate a host-path pod holds the namespace" {
    import unittest.mock;
    import from types { SimpleNamespace }
    import from kubernetes.client {
        V1Container,
        V1HostPathVolumeSource,
        V1PodSpec,
        V1Volume
    }
    import from jaclang.scale.deploy.target.kubernetes { target as target_mod }

    escaping = V1PodSpec(
        containers=[V1Container(name="x")],
        volumes=[V1Volume(name="h", host_path=V1HostPathVolumeSource(path="/proc"))]
    );
    def _workload(name: str, owned: bool = False) -> any {
        return SimpleNamespace(
            metadata=SimpleNamespace(
                name=name,
                owner_references=[SimpleNamespace(kind="Deployment")] if owned else None
            ),
            spec=SimpleNamespace(template=SimpleNamespace(spec=escaping))
        );
    }
    def _lister(items: list[any]) -> any {
        def list_fn(namespace: str) -> any {
            return SimpleNamespace(items=items);
        }
        return list_fn;
    }
    apps = SimpleNamespace(
        list_namespaced_daemon_set=_lister([_workload("ds")]),
        list_namespaced_deployment=_lister([_workload("dep")]),
        list_namespaced_stateful_set=_lister([_workload("sts")]),
        list_namespaced_replica_set=_lister(
            [_workload("rs"), _workload("dep-5d8f", owned=True)]
        )
    );
    batch = SimpleNamespace(
        list_namespaced_cron_job=_lister([]), list_namespaced_job=_lister([])
    );
    core = SimpleNamespace(
        list_namespaced_replication_controller=_lister([_workload("rc")])
    );
    fake_client = SimpleNamespace(
        AppsV1Api=lambda { apps; },
        BatchV1Api=lambda { batch; },
        CoreV1Api=lambda { core; }
    );
    with unittest.mock.patch.object(target_mod, "client", fake_client) {
        holders = _target(monitoring=False)._workloads_escaping_baseline("t-ns");
    }
    assert sorted(holders)
        == [
            "DaemonSet/ds",
            "Deployment/dep",
            "ReplicaSet/rs",
            "ReplicationController/rc",
            "StatefulSet/sts"
        ] , holders;
}
