import logging;
import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    download_release_binary,
    node_arch,
    pack_binary_bytes,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { content_address }
import from jaclang.scale.config.dev_config { Channel }

glob logger = logging.getLogger(__name__);


obj BinaryInjector(PvcInjector) {
    has channel: Channel = Channel.STABLE,
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"",
        _pod_binary_bytes: bytes = b"";

    def prepare(app_name: str, namespace: str, project_dir: str) {
        # Download the pod binary FIRST so pack_source can precompile the app's
        # modules with it (#7179): .jir is version-locked to the compiling
        # binary, so the driver's own jac cannot produce pod-valid seeds.
        payload = download_release_binary(self.channel.value, node_arch());
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


def select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    provisioned_database: str = ""
) -> tuple[PvcInjector, str] {
    import from jaclang.cli.console { console }
    import from jaclang.scale.config.dev_config { resolve_dev_channel }
    # The one place the pod binary channel is decided (local > dev > stable).
    channel = resolve_dev_channel(project_dir);
    blurbs = {
        Channel.LOCAL: "shipping the local jac binary",
        Channel.DEV: "downloading the rolling `dev` (main HEAD) jac binary",
        Channel.STABLE: "downloading the latest published (stable) jac release"
    };
    try {
        console.print(f"Preparing the '{channel.value}' jac runtime for pods.");
        injector = BinaryInjector(
            channel=channel,
            storage_class=storage_class,
            provisioned_database=provisioned_database
        );
        injector.prepare(app_name, namespace, project_dir);
        console.print(f"Ready: {blurbs[channel]}.");
        return (injector, injector._toolchain_object_key);
    } except Exception as exc {
        logger.warning(f"[{channel.value}] binary prep failed: {exc}");
        raise RuntimeError(
            f"Could not prepare the '{channel.value}' jac runtime: {exc}. Check "
            "network access to github.com/jaseci-labs/jaseci releases (and "
            "JAC_NODE_ARCH for cross-arch nodes)."
        );
    }
}
