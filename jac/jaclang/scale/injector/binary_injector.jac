import logging;
import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    download_release_binary,
    node_arch,
    pack_binary_bytes,
    stage_admin_dist,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { bundle_object_key, content_address }
import from jaclang.scale.config.dev_config { Channel }

glob logger = logging.getLogger(__name__),
     DRY_RUN_DIGEST: str = "sha256-computed-at-deploy";


obj BinaryInjector(PvcInjector) {
    has channel: Channel = Channel.STABLE,
        version: str = "",
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"",
        _pod_binary_bytes: bytes = b"";

    def prepare(app_name: str, namespace: str, project_dir: str) {
        stage_admin_dist(project_dir, self.channel.value, self.version);

        payload = download_release_binary(
            self.channel.value, node_arch(), self.version
        );
        self._pod_binary_bytes = payload;
        super.prepare(app_name, namespace, project_dir);
        raw = pack_binary_bytes(payload);
        self._toolchain_object_key = toolchain_object_key(
            app_name, content_address(raw)
        );
        self._toolchain_bytes = raw;
    }

    def _seed_artifacts -> list[tuple[str, bytes]] {
        artifacts = super._seed_artifacts();
        artifacts.append((self._toolchain_object_key, self._toolchain_bytes));
        return artifacts;
    }

    def _unpack_bundle_paths -> list[str] {
        paths = super._unpack_bundle_paths();
        paths.append(bundle_pvc_path(self._toolchain_object_key));
        return paths;
    }
}


def _release_blurb(channel: Channel, version: str) -> str {
    if version {
        return (
            f"downloading the pinned jac {version} release "
            f"(releases/tags/v{version})"
        );
    }
    blurbs: dict[Channel, str] = {
        Channel.LOCAL: "shipping the local jac binary",
        Channel.DEV: "downloading the rolling `dev` (main HEAD) jac binary",
        Channel.STABLE: "downloading the latest published (stable) jac release",
        Channel.EXPERIMENTAL: "downloading the `dev` jac binary to seal .jir (pods run the PR's experimental image)"
    };
    return blurbs.get(channel, f"preparing the '{channel.value}' jac runtime");
}


def select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    provisioned_database: str = "",
    dry_run: bool = False
) -> tuple[PvcInjector, str] {
    import from jaclang.cli.console { console }
    import from jaclang.scale.config.dev_config {
        resolve_dev_channel,
        resolve_pinned_version
    }

    channel = resolve_dev_channel(project_dir);
    version = resolve_pinned_version(project_dir) if channel != Channel.LOCAL else "";
    label = f"pinned v{version}" if version else f"'{channel.value}'";
    if dry_run {
        injector = BinaryInjector(
            channel=channel,
            version=version,
            storage_class=storage_class,
            provisioned_database=provisioned_database
        );
        injector._object_key = bundle_object_key(app_name, DRY_RUN_DIGEST);
        injector._toolchain_object_key = toolchain_object_key(app_name, DRY_RUN_DIGEST);
        console.print(
            f"dry-run: skipped preparing the {label} jac runtime "
            f"({_release_blurb(channel, version)}); a real deploy computes "
            "the content digests."
        );
        return (injector, injector._toolchain_object_key);
    }
    try {
        console.print(f"Preparing the {label} jac runtime for pods.");
        injector = BinaryInjector(
            channel=channel,
            version=version,
            storage_class=storage_class,
            provisioned_database=provisioned_database
        );
        injector.prepare(app_name, namespace, project_dir);
        console.print(f"Ready: {_release_blurb(channel, version)}.");
        return (injector, injector._toolchain_object_key);
    } except Exception as exc {
        logger.warning(f"[{channel.value}] binary prep failed: {exc}");
        raise RuntimeError(
            f"Could not prepare the {label} jac runtime: {exc}. Check "
            "network access to github.com/jaseci-labs/jaseci releases (and "
            "JAC_NODE_ARCH for cross-arch nodes)."
        );
    }
}
