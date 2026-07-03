import logging;
import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    download_release_binary,
    node_arch,
    resolve_overlay_source,
    cleanup_overlay_source,
    pack_binary_bytes,
    pack_overlay,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { content_address }
import from jaclang.scale.config.dev_config { DevDeploy }

glob logger = logging.getLogger(__name__);


obj BinaryInjector(PvcInjector) {
    has dev: DevDeploy = DevDeploy(),
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"";

    def prepare(app_name: str, namespace: str, project_dir: str) {
        super.prepare(app_name, namespace, project_dir);
        payload = download_release_binary(self.dev.channel, node_arch());
        if self.dev.overlays_source() {
            (src, cleanup) = resolve_overlay_source(
                self.dev.repo, self.dev.branch, self.dev.jaclang_source, project_dir
            );
            try {
                raw = pack_overlay(payload, src);
            } finally {
                cleanup_overlay_source(cleanup);
            }
        } else {
            raw = pack_binary_bytes(payload);
        }
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


def _blurb(dev: DevDeploy) -> str {
    if not dev.overlays_source() {
        if dev.channel == "dev" {
            return "downloading the rolling `dev` (main HEAD) jac binary";
        }
        return "downloading the latest published (stable) jac release";
    }
    where = (
        f"{dev.repo}@{dev.branch}"
            if dev.repo
            else (dev.jaclang_source or "jaseci main")
    );
    return f"downloading the dev binary + overlaying jaclang source ({where})";
}


def select_injector(
    dev: DevDeploy, storage_class: str, app_name: str, namespace: str, project_dir: str
) -> tuple[PvcInjector, str] {
    import from jaclang.cli.console { console }
    try {
        console.print(f"Preparing the '{dev.channel}' jac runtime for pods.");
        injector = BinaryInjector(dev=dev, storage_class=storage_class);
        injector.prepare(app_name, namespace, project_dir);
        console.print(f"Ready: {_blurb(dev)}.");
        return (injector, injector._toolchain_object_key);
    } except Exception as exc {
        logger.warning(f"[{dev.channel}] binary/source prep failed: {exc}");
        raise RuntimeError(
            f"Could not prepare the '{dev.channel}' jac runtime: {exc}. Check "
            f"network access to github.com/jaseci-labs/jaseci releases (and "
            f"JAC_NODE_ARCH for cross-arch nodes); for [dev] with repo/branch "
            f"ensure the branch exists and has a jac/jaclang source tree."
        );
    }
}
