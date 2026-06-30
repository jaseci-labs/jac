import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    host_repo_root,
    build_release_binary,
    resolve_pod_build_target,
    precompile_plugins,
    pack_toolchain,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { content_address }


obj BinaryInjector(PvcInjector) {
    # node_arch is the target pod node architecture (x86_64 / aarch64); it drives
    # the cross-compile target so aarch64/Graviton pods get an aarch64 binary.
    has node_arch: str = "x86_64",
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"";

    def prepare(app_name: str, namespace: str, project_dir: str) {
        super.prepare(app_name, namespace, project_dir);
        repo_root = host_repo_root();
        # Pods are linux; cross-compile when the host OS/arch differs from the pod
        # so we never ship a binary that cannot exec in the container.
        binary = build_release_binary(
            repo_root, target=resolve_pod_build_target(self.node_arch)
        );

        precompile_plugins(repo_root);
        raw = pack_toolchain(repo_root, binary);
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
    experimental: bool,
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str
) -> tuple[PvcInjector, bool, str] {
    if experimental {
        import from jaclang.cli.console { console }
        import logging;
        try {
            console.print(
                "Building the jac binary on the host to ship into pods "
                "(--experimental) - one-time (cached after), a few minutes on the "
                "first run. The faster, OOM-free alternative to the in-pod build."
            );
            binary_injector = BinaryInjector(storage_class=storage_class);
            binary_injector.prepare(app_name, namespace, project_dir);
            console.print(
                "Built jac binary; shipping your local code to pods (pods skip "
                "the in-pod build)."
            );
            return (binary_injector, True, binary_injector._toolchain_object_key);
        } except Exception as exc {
            logging.getLogger(__name__).warning(
                f"--experimental binary-ship failed: {exc}"
            );
            raise RuntimeError(
                f"--experimental could not ship a host-built jac binary: {exc}. "
                "Put zig 0.16.0 on PATH and run 'cd jac && zig build --prefix "
                ".ship-out', or deploy without --experimental to use the published "
                "release. (Not silently falling back to the in-pod build - it OOMs "
                "small nodes.)"
            );
        }
    }
    source_injector = PvcInjector(storage_class=storage_class);
    source_injector.prepare(app_name, namespace, project_dir);
    return (source_injector, False, "");
}
