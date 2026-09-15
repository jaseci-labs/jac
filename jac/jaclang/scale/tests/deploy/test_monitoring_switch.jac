"""`[scale.monitoring].enabled` must decide whether the metrics stack deploys,
and the collectors it decides about must be cluster singletons rather than one
copy per app.
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
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { LocalProvider }
import from jaclang.scale._optdeps.kubernetes { ApiException }
import from jaclang.scale.deploy.target.kubernetes.shared_observability {
    SharedObservability,
    lane_key,
    NODE_EXPORTER_NAME,
    KSM_NAME,
    PROMETHEUS_NAME,
    ALLOY_NAME,
    PROMETHEUS_LANES_CM
}


def _shared(app: str, ns: str, logs: bool = False) -> SharedObservability {
    return SharedObservability(
        k8s_config=KubernetesConfig(
            app_name=app,
            namespace=ns,
            monitoring_enabled=True,
            loki_enabled=logs,
            admin_username="scraper"
        )
    );
}


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


test "the shared collector names carry no app or namespace prefix" {
    # A name that varies per app is what makes N objects instead of one.
    # jacBuilder#1711: every deployed app stamped out its own
    # `{app}-node-exporter` DaemonSet on every node of the cluster.
    for name in [NODE_EXPORTER_NAME, KSM_NAME, PROMETHEUS_NAME, ALLOY_NAME] {
        assert name.startswith("jac-");
        for app_or_ns in ["alpha", "beta", "jb-299afd1f-dev-flowline"] {
            assert app_or_ns not in name;
        }
    }
}


test "two apps get two scrape lanes, each labelled with its own namespace" {
    alpha = _shared("alpha", "ns-alpha");
    beta = _shared("beta", "ns-beta");
    lane_a = alpha.prometheus_lane("alpha", "ns-alpha", "alpha-service", 8000);
    lane_b = beta.prometheus_lane("beta", "ns-beta", "beta-service", 8000);

    assert "alpha-service.ns-alpha.svc.cluster.local:8000" in lane_a;
    assert "beta-service.ns-beta.svc.cluster.local:8000" in lane_b;
    # Attribution is the bar that matters most once the collector is shared.
    assert "namespace: 'ns-alpha'" in lane_a;
    assert "jac_app: 'alpha'" in lane_a;
    assert "ns-beta" not in lane_a;
    assert "ns-alpha" not in lane_b;
    # Each app keeps its own scrape credential rather than sharing one.
    assert lane_key("alpha", "ns-alpha") in lane_a;
    assert lane_key("beta", "ns-beta") in lane_b;
    assert "username: 'scraper'" in lane_a;
}


test "one rendered config holds every app's lane over a single base" {
    shared = _shared("alpha", "ns-alpha");
    lanes = {
        lane_key("alpha", "ns-alpha"): shared.prometheus_lane(
            "alpha", "ns-alpha", "alpha-service", 8000
        ),
        lane_key("beta", "ns-beta"): shared.prometheus_lane(
            "beta", "ns-beta", "beta-service", 8000
        )
    };
    rendered = shared._render_prometheus_config(lanes);

    assert rendered.count("global:") == 1;
    assert rendered.count("job_name: 'node-exporter'") == 1;
    assert rendered.count("job_name: 'kube-state-metrics'") == 1;
    assert rendered.count("job_name: 'kubernetes-cadvisor'") == 1;
    assert "ns-alpha" in rendered;
    assert "ns-beta" in rendered;

    # Removing one app leaves the other app's lane and the shared base intact.
    lanes.pop(lane_key("beta", "ns-beta"));
    after = shared._render_prometheus_config(lanes);
    assert "ns-alpha" in after;
    assert "ns-beta" not in after;
    assert after.count("job_name: 'node-exporter'") == 1;
}


test "a shared log agent keeps only its own app's pods and ships them home" {
    shared = _shared("alpha", "ns-alpha", logs=True);
    lane = shared.alloy_lane("alpha", "ns-alpha");

    # Without this keep rule a shared agent reads every pod on the node.
    assert 'action        = "keep"' in lane;
    assert 'regex         = "ns-alpha"' in lane;
    assert "alpha-loki-service.ns-alpha.svc.cluster.local:3100" in lane;

    other = shared.alloy_lane("beta", "ns-beta");
    assert "beta-loki-service.ns-beta" in other;
    assert "ns-alpha" not in other;
}


test "grafana is pointed at the shared prometheus, not a per-app one" {
    shared = _shared("alpha", "ns-alpha");
    url = shared.prometheus_url();
    assert PROMETHEUS_NAME in url;
    assert "jac-observability" in url;
    assert "alpha" not in url;
}


test "the observability namespace is configurable but defaults to one place" {
    assert _shared("alpha", "ns-alpha").namespace() == "jac-observability";
    pinned = SharedObservability(
        k8s_config=KubernetesConfig(
            app_name="alpha", namespace="ns-alpha", observability_namespace="obs"
        )
    );
    assert pinned.namespace() == "obs";
}


obj StoredMeta {
    """The metadata attributes the deployer reads off a k8s object."""
    has name: str = "",
        namespace: str = "",
        resource_version: str = "",
        labels: dict[str, str] = {};
}


obj Stored {
    """What a read returns: enough of a k8s object for the deployer's getattr."""
    has data: dict[str, any] = {},
        metadata: StoredMeta = StoredMeta();
}


obj ApiRecorder {
    """Boundary stub for the kubernetes client, answering the way the API
    server does: reads return what exists, create on an existing name is 409,
    replace on a missing name is 404, and every write bumps resourceVersion.
    A permissive stub here let create silently overwrite, which is what hid a
    swallowed 409 from the suite."""
    has created: list[dict[str, any]] = [],
        store: dict[str, dict[str, any]] = {},
        deleted: list[tuple] = [];

    def __getattr__(name: str) -> any {
        created = self.created;
        store = self.store;
        deleted = self.deleted;
        if name.startswith("read_") {
            def _read(*a: any, **kw: any) -> any {
                key = f"{kw.get('namespace', '')}/{kw.get('name', '')}";
                if key in store {
                    body = store[key];
                    m = dict(body.get("metadata", {}) or {});
                    return Stored(
                        data=dict(body.get("data", {}) or {}),
                        metadata=StoredMeta(
                            name=str(m.get("name", "")),
                            namespace=str(m.get("namespace", "")),
                            resource_version=str(m.get("resourceVersion", "1")),
                            labels=dict(m.get("labels", {}) or {})
                        )
                    );
                }
                raise ApiException(status=404, reason="Not Found");
            }
            return _read;
        }
        if name.startswith("delete_") {
            def _delete(*a: any, **kw: any) -> any {
                n = kw.get("name", a[0] if a else "");
                ns = kw.get("namespace", a[1] if len(a) > 1 else "");
                deleted.append((name, str(n), str(ns)));
                store.pop(f"{ns}/{n}", None);
                return None;
            }
            return _delete;
        }
        def _write(*a: any, **kw: any) -> any {
            body = kw.get("body");
            if not isinstance(body, dict) {
                return None;
            }
            meta = dict(body.get("metadata", {}) or {});
            key = f"{meta.get('namespace', '')}/{meta.get('name', '')}";
            if name.startswith("create_") and key in store {
                raise ApiException(status=409, reason="AlreadyExists");
            }
            if name.startswith("replace_") and key not in store {
                raise ApiException(status=404, reason="Not Found");
            }
            bump = int(
                str(
                    dict(store.get(key, {}).get("metadata", {}) or {}).get(
                        "resourceVersion", "0"
                    )
                )
                    or "0"
            )
                + 1;
            meta["resourceVersion"] = str(bump);
            body["metadata"] = meta;
            created.append(body);
            store[key] = body;
            return None;
        }
        return _write;
    }
}


obj ConflictOnceRecorder(ApiRecorder) {
    """Rejects the first replace with 409, the way the API server does when
    another writer got there first."""
    has conflicts: int = 0;

    def __getattr__(name: str) -> any {
        if name.startswith("replace_") and self.conflicts == 0 {
            def _conflict(*a: any, **kw: any) -> any {
                self.conflicts += 1;
                raise ApiException(status=409, reason="Conflict");
            }
            return _conflict;
        }
        return super.__getattr__(name);
    }
}


def _kinds_in(recorder: ApiRecorder, kind: str, namespace: str = "") -> list[str] {
    out: list[str] = [];
    for body in recorder.created {
        if body.get("kind") != kind {
            continue;
        }
        meta = dict(body.get("metadata", {}) or {});
        if namespace and str(meta.get("namespace", "")) != namespace {
            continue;
        }
        out.append(str(meta.get("name", "")));
    }
    return out;
}


test "an app deploy puts no DaemonSet in the app's own namespace" {
    # jac#9058's acceptance criterion: node-level agents must cost O(nodes),
    # not O(nodes x apps). With logs on, the old path stamped out both a
    # node-exporter and an Alloy DaemonSet per app namespace.
    cfg = KubernetesConfig(
        app_name="dev-flowline",
        namespace="jb-299afd1f-dev-flowline",
        monitoring_enabled=True,
        loki_enabled=True
    );
    apps = ApiRecorder();
    core = ApiRecorder();
    MonitoringDeployer(cfg, rbac_api=core).deploy(
        "dev-flowline",
        "jb-299afd1f-dev-flowline",
        apps,
        core,
        LocalProvider(),
        scrape_target_service="dev-flowline-service"
    );
    assert _kinds_in(apps, "DaemonSet", "jb-299afd1f-dev-flowline") == [];

    # They exist once, in the shared namespace, whatever the app count.
    shared_ds = sorted(_kinds_in(apps, "DaemonSet", "jac-observability"));
    assert shared_ds == ["jac-alloy", "jac-node-exporter"];
}


test "a second app adds lanes, not another collector" {
    # The multiplicity that jac#9058 measures: deploying app two must not
    # create a second copy of anything node-level.
    apps = ApiRecorder();
    core = ApiRecorder();
    for (app, ns) in [("alpha", "ns-alpha"), ("beta", "ns-beta")] {
        cfg = KubernetesConfig(
            app_name=app, namespace=ns, monitoring_enabled=True, loki_enabled=True
        );
        MonitoringDeployer(cfg, rbac_api=core).deploy(
            app, ns, apps, core, LocalProvider(), scrape_target_service=f"{app}-service"
        );
    }
    # Count objects that exist, not writes: a second deploy re-applies the
    # shared templates so a later release's image bump lands, which is a write
    # against the same single object.
    assert sorted(set(_kinds_in(apps, "DaemonSet", "jac-observability")))
        == ["jac-alloy", "jac-node-exporter"];
    assert sorted(set(_kinds_in(apps, "Deployment", "jac-observability")))
        == ["jac-kube-state-metrics", "jac-prometheus"];
    # The cluster ends up with one ClusterRole per collector, whatever the app
    # count. Re-deploying an app replaces its content rather than adding another
    # object, so the distinct set is what matters, not the write count.
    roles = set(_kinds_in(core, "ClusterRole"));
    assert roles
        == {
            "jac-observability-prometheus",
            "jac-observability-kube-state-metrics",
            "jac-observability-alloy"
        };
    # None of them is named after an app or a namespace, which is what made
    # them multiply before (jac#9058).
    for role in roles {
        for owner in ["alpha", "beta", "ns-alpha", "ns-beta"] {
            assert owner not in role;
        }
    }
}


test "opting out of k8s metrics leaves the node-level collectors undeployed" {
    # k8s_metrics_enabled gated node-exporter and kube-state-metrics before the
    # shared tier; a deploy that opts out must not get them cluster-wide either.
    cfg = KubernetesConfig(
        app_name="alpha",
        namespace="ns-alpha",
        monitoring_enabled=True,
        k8s_metrics_enabled=False
    );
    apps = ApiRecorder();
    core = ApiRecorder();
    MonitoringDeployer(cfg, rbac_api=core).deploy(
        "alpha",
        "ns-alpha",
        apps,
        core,
        LocalProvider(),
        scrape_target_service="alpha-service"
    );
    assert _kinds_in(apps, "DaemonSet") == [];
    assert "jac-kube-state-metrics" not in _kinds_in(apps, "Deployment");
    assert "jac-prometheus" in _kinds_in(apps, "Deployment");

    # ... and its Prometheus is not configured to scrape them either.
    shared = _shared("alpha", "ns-alpha");
    lean = shared._render_prometheus_config({}, False);
    for job in ["node-exporter", "kube-state-metrics", "kubernetes-cadvisor"] {
        assert job not in lean;
    }
    assert "scrape_configs:" in lean;
}


test "cluster-scoped identities are named after the observability namespace" {
    # Two clusters' worth of config in one cluster: fixed names would let the
    # second namespace rewrite the first one's binding subject.
    a = _shared("alpha", "ns-alpha");
    b = SharedObservability(
        k8s_config=KubernetesConfig(
            app_name="beta", namespace="ns-beta", observability_namespace="obs-two"
        )
    );
    for component in ["prometheus", "kube-state-metrics", "alloy"] {
        assert a.cluster_scoped_name(component) != b.cluster_scoped_name(component);
        assert a.cluster_scoped_name(component).startswith("jac-observability-");
        assert b.cluster_scoped_name(component).startswith("obs-two-");
    }
}


test "a lane write that loses a race retries against the winner" {
    # Two deploys read the same ConfigMap; the loser must not drop the lane the
    # winner just added.
    shared = _shared("alpha", "ns-alpha");
    core = ConflictOnceRecorder();
    core.store["jac-observability/jac-prometheus-lanes"] = {
        "metadata": {
            "name": "jac-prometheus-lanes",
            "namespace": "jac-observability",
            "resourceVersion": "1"
        },
        "data": {"ns-beta__beta": "beta-lane"}
    };
    lanes = shared._put_lane(
        core, PROMETHEUS_LANES_CM, lane_key("alpha", "ns-alpha"), "alpha-lane"
    );
    assert core.conflicts == 1;
    assert lanes["ns-beta__beta"] == "beta-lane";
    assert lanes[lane_key("alpha", "ns-alpha")] == "alpha-lane";
}


test "destroying an app that never had observability writes nothing" {
    # destroy() runs for every app. On a cluster with no shared tier the
    # observability namespace does not exist, so writing a rendered config
    # would 404, and the raise blocked namespace reclamation (#7968).
    cfg = KubernetesConfig(app_name="alpha", namespace="ns-alpha");
    apps = ApiRecorder();
    core = ApiRecorder();
    MonitoringDeployer(cfg, rbac_api=core).destroy("alpha", "ns-alpha", apps, core);
    for body in core.created {
        meta = dict(body.get("metadata", {}) or {});
        assert str(meta.get("namespace", "")) != "jac-observability" , (
            f"destroy wrote {meta.get('name')} into the shared namespace"
        );
    }
}


def _deploy_app(app: str, ns: str, apps: ApiRecorder, core: ApiRecorder) {
    cfg = KubernetesConfig(
        app_name=app, namespace=ns, monitoring_enabled=True, loki_enabled=True
    );
    MonitoringDeployer(cfg, rbac_api=core).deploy(
        app, ns, apps, core, LocalProvider(), scrape_target_service=f"{app}-service"
    );
}


def _rendered(core: ApiRecorder, cm: str, key: str) -> str {
    body = core.store.get(f"jac-observability/{cm}", {});
    return str(dict(body.get("data", {}) or {}).get(key, ""));
}


test "a second app's lane reaches the rendered prometheus.yml" {
    # Registering a lane is not enough: the rendered config is what Prometheus
    # reads, and a write that no-ops leaves the second app unscraped.
    apps = ApiRecorder();
    core = ApiRecorder();
    _deploy_app("alpha", "ns-alpha", apps, core);
    _deploy_app("beta", "ns-beta", apps, core);
    prom = _rendered(core, "jac-prometheus-config", "prometheus.yml");
    assert "job_name: 'ns-alpha__alpha'" in prom;
    assert "job_name: 'ns-beta__beta'" in prom;
}


test "a second app's lane reaches the rendered config.alloy" {
    apps = ApiRecorder();
    core = ApiRecorder();
    _deploy_app("alpha", "ns-alpha", apps, core);
    _deploy_app("beta", "ns-beta", apps, core);
    alloy = _rendered(core, "jac-alloy-config", "config.alloy");
    assert "ns-alpha" in alloy;
    assert "ns-beta" in alloy;
}


test "destroying an app drains its job from the rendered config" {
    apps = ApiRecorder();
    core = ApiRecorder();
    _deploy_app("alpha", "ns-alpha", apps, core);
    _deploy_app("beta", "ns-beta", apps, core);
    cfg = KubernetesConfig(
        app_name="alpha", namespace="ns-alpha", monitoring_enabled=True
    );
    MonitoringDeployer(cfg, rbac_api=core).destroy("alpha", "ns-alpha", apps, core);
    prom = _rendered(core, "jac-prometheus-config", "prometheus.yml");
    assert "job_name: 'ns-alpha__alpha'" not in prom;
    assert "job_name: 'ns-beta__beta'" in prom;
}


test "destroy sweeps the per-app collectors an older release left behind" {
    # The migration story is that a redeploy moves an app onto the shared tier,
    # which only holds if destroy removes what the previous release created.
    apps = ApiRecorder();
    core = ApiRecorder();
    cfg = KubernetesConfig(
        app_name="alpha",
        namespace="ns-alpha",
        monitoring_enabled=True,
        loki_enabled=True
    );
    MonitoringDeployer(cfg, rbac_api=core).destroy("alpha", "ns-alpha", apps, core);
    names = [d[1] for d in apps.deleted] + [d[1] for d in core.deleted];
    for legacy in [
        "alpha-node-exporter",
        "alpha-alloy",
        "alpha-prometheus",
        "alpha-kube-state-metrics",
        "ns-alpha-alpha-prometheus",
        "ns-alpha-alpha-kube-state-metrics",
        "ns-alpha-alpha-alloy"
    ] {
        assert legacy in names , f"destroy never deletes legacy '{legacy}'";
    }
}


def _grafana_datasources(core: ApiRecorder, app: str, ns: str) -> str {
    body = core.store.get(f"{ns}/{app}-grafana-datasources", {});
    return str(dict(body.get("data", {}) or {}).get("datasource.yaml", ""));
}


def _grafana_dashboards(core: ApiRecorder, app: str, ns: str) -> dict[str, any] {
    body = core.store.get(f"{ns}/{app}-grafana-dashboard", {});
    return dict(body.get("data", {}) or {});
}


test "an app's own Grafana gets no datasource on the shared Prometheus" {
    # One Prometheus holds every tenant's series and has no auth in front of
    # it, so wiring it into a per-app Grafana hands that app's owner every
    # other app's metrics through Explore, whatever the dashboards say.
    apps = ApiRecorder();
    core = ApiRecorder();
    _deploy_app("alpha", "ns-alpha", apps, core);
    ds = _grafana_datasources(core, "alpha", "ns-alpha");
    assert "jac-observability" not in ds;
    assert "type: prometheus" not in ds;
    # Loki is genuinely per-app, so it stays.
    assert "type: loki" in ds;
}


test "opting in wires the shared Prometheus back for a single-tenant cluster" {
    apps = ApiRecorder();
    core = ApiRecorder();
    cfg = KubernetesConfig(
        app_name="alpha",
        namespace="ns-alpha",
        monitoring_enabled=True,
        loki_enabled=True,
        app_grafana_metrics=True
    );
    MonitoringDeployer(cfg, rbac_api=core).deploy(
        "alpha",
        "ns-alpha",
        apps,
        core,
        LocalProvider(),
        scrape_target_service="alpha-service"
    );
    ds = _grafana_datasources(core, "alpha", "ns-alpha");
    assert "type: prometheus" in ds;
    assert "jac-prometheus-service.jac-observability" in ds;
}


test "the metric dashboards ship only when the datasource does" {
    # A dashboard whose datasource was never provisioned renders as an error
    # panel, so the two have to move together.
    apps = ApiRecorder();
    core = ApiRecorder();
    _deploy_app("alpha", "ns-alpha", apps, core);
    off = _grafana_dashboards(core, "alpha", "ns-alpha");
    assert "jac-scale.json" not in off;
    assert "k8s-metrics.json" not in off;
    assert "pod-logs.json" in off;

    apps2 = ApiRecorder();
    core2 = ApiRecorder();
    cfg = KubernetesConfig(
        app_name="beta",
        namespace="ns-beta",
        monitoring_enabled=True,
        loki_enabled=True,
        app_grafana_metrics=True
    );
    MonitoringDeployer(cfg, rbac_api=core2).deploy(
        "beta",
        "ns-beta",
        apps2,
        core2,
        LocalProvider(),
        scrape_target_service="beta-service"
    );
    on = _grafana_dashboards(core2, "beta", "ns-beta");
    assert "jac-scale.json" in on;
}


test "the scrape credential is not mounted inside another volume" {
    # A secret volume nested inside the config volume comes back empty after a
    # restart, which makes password_file unreadable, which makes Prometheus
    # reject every reload with a 500, which silently freezes the config at
    # whatever the first app rendered.
    shared = _shared("alpha", "ns-alpha");
    spec = shared._prometheus_deployment("hash")["spec"]["template"]["spec"];
    mounts: dict[str, str] = {};
    for c in spec["containers"] {
        for m in c.get("volumeMounts", []) {
            mounts[str(m["name"])] = str(m["mountPath"]);
        }
    }
    config_path = mounts["prometheus-config-vol"];
    scrape_path = mounts["prometheus-scrape-secret"];
    assert not scrape_path.startswith(config_path + "/") , (
        f"scrape secret at {scrape_path} is nested inside {config_path}"
    );
    # The rendered lane has to agree with wherever it is mounted.
    lane = shared.prometheus_lane("alpha", "ns-alpha", "alpha-service", 8000);
    assert f"password_file: {scrape_path}/" in lane;
}
