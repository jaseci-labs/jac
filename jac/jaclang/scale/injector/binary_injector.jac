import logging;
import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    host_repo_root,
    build_release_binary,
    download_release_binary,
    node_arch,
    pack_binary_bytes,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { content_address }
import from jaclang.scale.config.dev_config { DevDeploy, CHANNEL_LOCAL }

glob logger = logging.getLogger(__name__);


obj BinaryInjector(PvcInjector) {
    # Ships a self-contained `jac` binary into pods over the bundle PVC, on top
    # of the app source PvcInjector already seeds. The binary is either downloaded
    # from a published release (stable/dev) or host-built from a local checkout
    # (local); either way the pod skips the in-pod jaclang build.
    has channel: str = "",
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"";

    def prepare(app_name: str, namespace: str, project_dir: str) {
        super.prepare(app_name, namespace, project_dir);
        if self.channel == CHANNEL_LOCAL {
            binary = build_release_binary(host_repo_root());
            payload = binary.read_bytes();
        } else {
            payload = download_release_binary(self.channel, node_arch());
        }
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


def _channel_blurb(channel: str) -> str {
    if channel == "stable" {
        return "downloading the latest published jac release";
    } elif channel == "dev" {
        return "downloading the rolling `dev` (main) jac build";
    }
    return "building jac from your local checkout (a few minutes on first run)";
}


def select_injector(
    dev: DevDeploy, storage_class: str, app_name: str, namespace: str, project_dir: str
) -> tuple[PvcInjector, bool, str] {
    # stable/dev/local all ship a prebuilt-or-host-built binary; only the BRANCH
    # escape hatch ships source and clones + builds jaclang inside the pod.
    if dev.ships_binary() {
        import from jaclang.cli.console { console }
        try {
            console.print(
                f"Preparing the '{dev.channel}' jac runtime for pods "
                f"({_channel_blurb(dev.channel)})."
            );
            binary_injector = BinaryInjector(
                channel=dev.channel, storage_class=storage_class
            );
            binary_injector.prepare(app_name, namespace, project_dir);
            console.print(
                "Shipping the jac binary to pods (pods skip the in-pod build)."
            );
            return (binary_injector, True, binary_injector._toolchain_object_key);
        } except Exception as exc {
            logger.warning(f"[{dev.channel}] binary-ship failed: {exc}");
            raise RuntimeError(
                f"Could not prepare the '{dev.channel}' jac binary: {exc}. For "
                f"stable/dev check network access to github.com/jaseci-labs/jaseci "
                f"releases (and JAC_NODE_ARCH for cross-arch nodes); for local put "
                f"zig 0.16.0 on PATH. (Not silently falling back to an in-pod build "
                f"- it OOMs small nodes.)"
            );
        }
    }
    source_injector = PvcInjector(storage_class=storage_class);
    source_injector.prepare(app_name, namespace, project_dir);
    return (source_injector, False, "");
}
