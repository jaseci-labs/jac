impl BinaryInjector.prepare(app_name: str, namespace: str, project_dir: str) {
    version = resolve_deploy_version(project_dir, self.channel.value);
    stage_admin_dist(
        project_dir,
        self.channel.value,
        resolve_console_version(project_dir, self.channel.value, version)
    );

    pod_arch = node_arch();
    payload = read_local_binary(project_dir)
        if self.channel == Channel.LOCAL
        else download_release_binary(self.channel.value, pod_arch, version);
    self._pod_binary_bytes = payload;
    self._pod_binary_sha256 = hashlib.sha256(payload).hexdigest();
    self._pod_arch = pod_arch;
    self._seal_binary_bytes = self._resolve_seal_binary(payload, pod_arch, version);
    super.prepare(app_name, namespace, project_dir);
    raw = pack_binary_bytes(payload);
    self._toolchain_object_key = toolchain_object_key(app_name, content_address(raw));
    self._toolchain_bytes = raw;
}

impl BinaryInjector._resolve_seal_binary(
    pod_payload: bytes, pod_arch: str, version: str
) -> bytes {
    if self.channel == Channel.LOCAL {
        return pod_payload;
    }
    plat = host_seal_platform();
    arch = host_arch();
    if plat == "linux" and arch == pod_arch {
        return pod_payload;
    }
    return download_release_binary(self.channel.value, arch, version, plat);
}

impl BinaryInjector._seed_artifacts -> list[tuple[str, bytes]] {
    artifacts = super._seed_artifacts();
    artifacts.append((self._toolchain_object_key, self._toolchain_bytes));
    return artifacts;
}

impl BinaryInjector._unpack_bundle_paths -> list[str] {
    paths = super._unpack_bundle_paths();
    paths.append(bundle_pvc_path(self._toolchain_object_key));
    return paths;
}

impl BinaryInjector._skip_when_image_binary -> dict[str, str] {
    if not self._pod_binary_sha256 or not self._toolchain_object_key {
        return {};
    }
    return {bundle_pvc_path(self._toolchain_object_key): self._pod_binary_sha256};
}

impl select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    dry_run: bool = False,
    access_mode: str = "ReadWriteMany",
    fleet: any = None,
    client_ready: any = None
) -> tuple[PvcInjector, str] {
    channel = resolve_dev_channel(project_dir);
    blurbs = {
        Channel.LOCAL: "shipping the local jac binary",
        Channel.DEV: "downloading the rolling `dev` (main HEAD) jac binary",
        Channel.STABLE: "downloading the latest published (stable) jac release",
        Channel.EXPERIMENTAL: "downloading the `dev` jac binary to seal .jir (pods run the PR's experimental image)"
    };
    if dry_run {
        injector = BinaryInjector(
            channel=channel,
            storage_class=storage_class,
            access_mode=access_mode,
            _fleet=fleet
        );
        injector._object_key = bundle_object_key(app_name, DRY_RUN_DIGEST);
        injector._toolchain_object_key = toolchain_object_key(app_name, DRY_RUN_DIGEST);
        console.print(
            f"dry-run: skipped preparing the '{channel.value}' jac runtime "
            f"({blurbs[channel]}); a real deploy computes the content digests."
        );
        return (injector, injector._toolchain_object_key);
    }
    try {
        console.print(f"Preparing the '{channel.value}' jac runtime for pods.");
        injector = BinaryInjector(
            channel=channel,
            storage_class=storage_class,
            access_mode=access_mode,
            _fleet=fleet,
            _client_ready=client_ready
        );
        injector.prepare(app_name, namespace, project_dir);
        console.print(f"Ready: {blurbs[channel]}.");
        return (injector, injector._toolchain_object_key);
    } except Exception as exc {
        logger.warning(f"[{channel.value}] binary prep failed: {exc}");
        raise RuntimeError(
            f"Could not prepare the '{channel.value}' jac runtime: {exc}. Check "
            "network access to github.com/jaseci-labs/jac releases (and "
            "JAC_NODE_ARCH for cross-arch nodes)."
        );
    }
}
