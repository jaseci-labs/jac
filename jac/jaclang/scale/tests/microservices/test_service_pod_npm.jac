import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "service-pod bootstrap strips npm deps; the gateway keeps them" {
    svc = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=False
        )["args"][0]
    );
    gw = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=True
        )["args"][0]
    );
    assert "dependencies\\.npm" in svc;
    assert "dependencies\\.npm" not in gw;
    # The strip must land before the install that would fetch the packages.
    assert svc.index("npm") < svc.index("jac install");
}
