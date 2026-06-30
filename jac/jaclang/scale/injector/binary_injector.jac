import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jaclang.scale.injector.binary {
    host_repo_root,
    build_release_binary,
    resolve_prebuilt_binary,
    pod_arch,
    precompile_plugins,
    pack_toolchain,
    toolchain_object_key
}
import from jaclang.scale.injector.bundle { content_address }


obj BinaryInjector(PvcInjector) {
    has _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"",
        _jaseci_repo_url: str = "",
        _jaseci_branch: str = "",
        _jaseci_commit: (str | None) = None,
        _used_prebuilt: bool = False;

    def prepare(app_name: str, namespace: str, project_dir: str) {
        super.prepare(app_name, namespace, project_dir);
        repo_root = host_repo_root();
        binary = resolve_prebuilt_binary(
            self._jaseci_repo_url, self._jaseci_branch, self._jaseci_commit, pod_arch()
        );
        self._used_prebuilt = binary is not None;
        if binary is None {
            binary = build_release_binary(repo_root);
        }

        try {
            precompile_plugins(repo_root);
            raw = pack_toolchain(repo_root, binary);
        } finally {
            if self._used_prebuilt {
                import shutil;
                shutil.rmtree(binary.parent, ignore_errors=True);
            }
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


def select_injector(
    experimental: bool,
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    jaseci_repo_url: str = "",
    jaseci_branch: str = "",
    jaseci_commit: (str | None) = None
) -> tuple[PvcInjector, bool, str] {
    if experimental {
        import from jaclang.cli.console { console }
        import logging;
        try {
            console.print(
                "Resolving the jac binary to ship into pods (--experimental): a "
                "matching prebuilt release is downloaded when available, otherwise "
                "built on the host. The faster, OOM-free alternative to the in-pod "
                "build."
            );
            binary_injector = BinaryInjector(
                storage_class=storage_class,
                _jaseci_repo_url=jaseci_repo_url,
                _jaseci_branch=jaseci_branch,
                _jaseci_commit=jaseci_commit
            );
            binary_injector.prepare(app_name, namespace, project_dir);
            console.print(
                "Downloaded prebuilt jac binary; shipping to pods (pods skip the "
                "in-pod build)."
                    if binary_injector._used_prebuilt
                    else "Built jac binary on the host; shipping your local code to "
                    "pods (pods skip the in-pod build)."
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
