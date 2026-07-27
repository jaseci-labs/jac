import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "service-pod bootstrap always skips the npm closure" {
    svc = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=False
        )["args"][0]
    );
    assert "export JAC_CLIENT_SKIP_NPM_INSTALL=1" in svc;
    assert svc.index("JAC_CLIENT_SKIP_NPM_INSTALL") < svc.index("jac install");
}


test "gateway skips the npm closure only when the bundle ships a prebuilt dist" {
    gw = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=True
        )["args"][0]
    );
    # dist shipped -> no build can happen -> closure skipped; dist absent ->
    # full install so the on-boot client build fallback still works
    guard = gw.index("if [ -f .jac/client/dist/index.html ]");
    skip_at = gw.index("export JAC_CLIENT_SKIP_NPM_INSTALL=1", guard);
    install_at = gw.index("jac install", skip_at);
    assert guard < skip_at and skip_at < install_at;
}
