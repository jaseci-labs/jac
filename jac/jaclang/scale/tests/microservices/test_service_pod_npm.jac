import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "pod bootstrap always skips the npm closure" {
    # Pods never build the client: the deploy ships the bundle built on the
    # host or fails fast, so no pod - gateway included - needs npm deps.
    script = str(
        build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim")["args"][
            0
        ]
    );
    assert "export JAC_CLIENT_SKIP_NPM_INSTALL=1" in script;
    assert script.index("JAC_CLIENT_SKIP_NPM_INSTALL") < script.index("jac install");
}
