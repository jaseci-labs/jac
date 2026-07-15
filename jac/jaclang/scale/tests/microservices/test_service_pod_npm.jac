import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "service-pod bootstrap always installs without the npm closure" {
    svc = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=False
        )["args"][0]
    );
    assert "jac install --no-npm" in svc;
    assert "if [ -f .jac/client/dist/index.html ]" not in svc;
}


test "gateway skips the npm closure only when the bundle ships a prebuilt dist" {
    gw = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=True
        )["args"][0]
    );
    # dist shipped -> no build can happen -> closure skipped; dist absent ->
    # plain install so the on-boot client build fallback still works
    guard = gw.index("if [ -f .jac/client/dist/index.html ]");
    skip_at = gw.index("jac install --no-npm");
    full = gw.index("else");
    assert guard < skip_at and skip_at < full;
    assert "jac install; fi" in gw;
}
