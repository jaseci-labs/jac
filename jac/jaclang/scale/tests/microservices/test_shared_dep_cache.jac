import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.injector.pvc_injector {
    BUNDLE_MOUNT_PATH,
    BUNDLE_VOLUME_NAME
}


test "bootstrap points the pip cache at the shared bundle PVC, best-effort" {
    ctr = build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim");
    script = str(ctr["args"][0]);
    assert f"PIP_CACHE_DIR={BUNDLE_MOUNT_PATH}/.cache/pip" in script;
    # bun's cache is deliberately NOT shared: thousands of tiny files are
    # pathological on EFS/NFS; it stays on the pod-local disk.
    assert "BUN_INSTALL_CACHE_DIR" not in script;
    # mkdir-guarded (unwritable PVC degrades to plain installs), size-bounded.
    assert script.index("if mkdir") < script.index("PIP_CACHE_DIR");
    assert "du -sm" in script;
    assert script.index("PIP_CACHE_DIR") < script.index("jac install");
    mounts = [m["name"] for m in ctr["volumeMounts"]];
    assert BUNDLE_VOLUME_NAME in mounts;
}
