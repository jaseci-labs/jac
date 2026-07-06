import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.injector.pvc_injector { BUNDLE_MOUNT_PATH }


test "bootstrap points pip/bun caches at the shared bundle PVC, best-effort" {
    ctr = build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim");
    script = str(ctr["args"][0]);
    assert f"PIP_CACHE_DIR={BUNDLE_MOUNT_PATH}/.cache/pip" in script;
    assert f"BUN_INSTALL_CACHE_DIR={BUNDLE_MOUNT_PATH}/.cache/bun" in script;
    # Guarded by the mkdir so an unwritable PVC degrades to plain installs.
    assert script.index("if mkdir") < script.index("PIP_CACHE_DIR");
    assert script.index("PIP_CACHE_DIR") < script.index("jac install");
    mounts = [m["name"] for m in ctr["volumeMounts"]];
    assert "jac-bundles" in mounts;
}
