"""Tests for trace-collection infra (Tempo + Alloy OTLP lane).

Manifest-shape unit tests with a mocked Kubernetes client (no cluster):
- KubernetesConfig round-trips the `tracing_enabled` flag.
- `_deploy_tempo` builds a Tempo ConfigMap with OTLP receivers, a
  `grafana/tempo` Deployment, and a Service exposing 3200 + 4317.
- `_deploy_alloy` (tracing on) emits the `otelcol.*` OTLP->Tempo lane in
  the Alloy River config.
"""

import unittest.mock;
import from jac_scale._optdeps.kubernetes { ApiException }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.monitoring { MonitoringDeployer }
import from jac_scale.targets.kubernetes { monitoring as mon_module }


"""Build a (core_v1, apps_v1) mock pair where every read_* raises 404 so
the deployer takes the create path and we can inspect the create bodies."""
def _mock_clients -> tuple {
    notfound = ApiException(status=404);
    core_v1 = unittest.mock.MagicMock();
    apps_v1 = unittest.mock.MagicMock();
    core_v1.read_namespaced_config_map.side_effect = notfound;
    core_v1.read_namespaced_service_account.side_effect = notfound;
    core_v1.read_namespaced_service.side_effect = notfound;
    apps_v1.read_namespaced_deployment.side_effect = notfound;
    apps_v1.read_namespaced_daemon_set.side_effect = notfound;
    # Deployments are applied via patch-then-create-on-404; make patch 404
    # too so the create path runs and we can inspect the create body.
    apps_v1.patch_namespaced_deployment.side_effect = notfound;
    return (core_v1, apps_v1);
}


test "KubernetesConfig round-trips tracing_enabled" {
    on = KubernetesConfig.from_dict(KubernetesConfig, {"tracing_enabled": True});
    assert on.tracing_enabled == True;
    assert on.to_dict()["tracing_enabled"] == True;

    # Default off, and survives a to_dict -> from_dict round-trip.
    off = KubernetesConfig.from_dict(KubernetesConfig, {});
    assert off.tracing_enabled == False;
    again = KubernetesConfig.from_dict(KubernetesConfig, on.to_dict());
    assert again.tracing_enabled == True;
}


test "_deploy_tempo builds a Tempo ConfigMap/Deployment/Service with OTLP" {
    (core_v1, apps_v1) = _mock_clients();
    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"tracing_enabled": True, "monitoring_enabled": True}
    );
    dep = MonitoringDeployer(cfg, None);
    dep._deploy_tempo("myapp", "ns", apps_v1, core_v1);

    # ConfigMap: tempo.yaml exposes the OTLP receivers.
    cm = core_v1.create_namespaced_config_map.call_args.kwargs["body"];
    tempo_yaml = cm["data"]["tempo.yaml"];
    assert "otlp" in tempo_yaml;
    assert "4317" in tempo_yaml;

    # Deployment: single-binary grafana/tempo.
    dpl = apps_v1.create_namespaced_deployment.call_args.kwargs["body"];
    img = dpl["spec"]["template"]["spec"]["containers"][0]["image"];
    assert "grafana/tempo" in img;

    # Service: TraceQL API (3200) + OTLP gRPC (4317).
    svc = core_v1.create_namespaced_service.call_args.kwargs["body"];
    ports = [p["port"] for p in svc["spec"]["ports"]];
    assert 3200 in ports;
    assert 4317 in ports;
}


test "_deploy_alloy emits the otelcol OTLP->Tempo lane when tracing is on" {
    (core_v1, apps_v1) = _mock_clients();
    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"tracing_enabled": True, "monitoring_enabled": True}
    );
    dep = MonitoringDeployer(cfg, None);

    # _deploy_alloy constructs a RbacAuthorizationV1Api internally; mock it.
    with unittest.mock.patch.object(
        mon_module.client,
        "RbacAuthorizationV1Api",
        lambda : unittest.mock.MagicMock()
    ) {
        dep._deploy_alloy("myapp", "ns", apps_v1, core_v1);
    }

    alloy_cm = core_v1.create_namespaced_config_map.call_args.kwargs["body"];
    river = alloy_cm["data"]["config.alloy"];
    assert "otelcol.receiver.otlp" in river;
    assert "otelcol.exporter.otlp" in river;
    assert "myapp-tempo-service:4317" in river;

    # And an OTLP Service is created so app pods can reach the collector.
    svc = core_v1.create_namespaced_service.call_args.kwargs["body"];
    ports = [p["port"] for p in svc["spec"]["ports"]];
    assert 4317 in ports;
}
