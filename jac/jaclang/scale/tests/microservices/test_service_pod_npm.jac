import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "service-pod bootstrap strips npm deps unconditionally" {
    svc = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=False
        )["args"][0]
    );
    assert "dependencies\\.npm" in svc;
    assert "if [ -f .jac/client/dist/index.html ]" not in svc;
    # The strip must land before the install that would fetch the packages.
    assert svc.index("npm") < svc.index("jac install");
}


test "gateway strips npm only when the bundle ships a prebuilt dist" {
    gw = str(
        build_bootstrap_init_container(
            KubernetesConfig(), "python:3.12-slim", is_gateway=True
        )["args"][0]
    );
    # dist present -> strip runs (no build can happen); dist absent -> npm
    # stays so the on-boot client build fallback still works
    guard = gw.index("if [ -f .jac/client/dist/index.html ]");
    assert "dependencies\\.npm" in gw;
    assert guard < gw.index("dependencies\\.npm");
    assert guard < gw.index("jac install");
}
