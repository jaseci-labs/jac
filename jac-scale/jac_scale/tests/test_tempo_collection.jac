"""Tests for trace-collection infra (Tempo + Alloy OTLP lane).

Pure unit test: `KubernetesConfig` round-trips the `tracing_enabled`
flag (the toggle the microservice target sets from
`[plugins.scale.microservices.tracing].enabled` to gate Tempo + the
Alloy OTLP lane). The deploy path itself is exercised end-to-end on a
live cluster rather than against a mocked Kubernetes client.
"""

import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }


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
