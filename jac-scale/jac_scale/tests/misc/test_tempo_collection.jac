import from jac_scale.deploy.target.kubernetes.kubernetes_config { KubernetesConfig }


test "KubernetesConfig round-trips tracing_enabled" {
    on = KubernetesConfig.from_dict(KubernetesConfig, {"tracing_enabled": True});
    assert on.tracing_enabled == True;
    assert on.to_dict()["tracing_enabled"] == True;

    off = KubernetesConfig.from_dict(KubernetesConfig, {});
    assert off.tracing_enabled == False;
    again = KubernetesConfig.from_dict(KubernetesConfig, on.to_dict());
    assert again.tracing_enabled == True;
}
