"""BinaryInjector: ship a prebuilt release `jac` binary + plugin source from the
deploy host instead of building jaclang inside every pod.

Extends PvcInjector. The app source still travels on the bundle PVC and the
unpack init container untars it; BinaryInjector additionally packs the host
toolchain (a release binary + jac-scale/byllm/mcp source, via injector/binary.jac),
publishes it onto the same PVC in the same loader-pod session, and has the unpack
container drop it under APP_MOUNT_PATH/TOOLCHAIN_SUBDIR beside the source. The
jac-bootstrap init container, in ship_binary mode (runtime_bootstrap), then PATHs
the binary and `jac install -e`s the plugins - a pip step, no apt build deps, no
clone, no zig build: seconds, not minutes, and ~no build memory (the per-pod LLVM
+ CPython compile a small node cannot sustain).

Selection is the manifest builder's job: it tries BinaryInjector.prepare (which
builds the release binary on the host) and, on any failure (no zig, build error),
falls back to PvcInjector + the in-pod install. Keeping `--experimental` as the
hermetic, builds-from-a-clean-clone path for CI.
"""

import from jac_scale.injector.pvc_injector { PvcInjector, bundle_pvc_path }
import from jac_scale.injector.binary {
    host_repo_root,
    build_release_binary,
    pack_toolchain,
    toolchain_object_key
}
import from jac_scale.injector.bundle { content_address }


"""Code-injection adapter that ships a prebuilt release jac binary + plugin source
beside the app, so pods start in seconds instead of compiling jaclang in-pod."""
obj BinaryInjector(PvcInjector) {
    has _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"";

    """Pack the app source (PvcInjector.prepare) AND build + pack the host
    toolchain. Raises if zig is absent or the release build fails - select_injector
    turns that into a loud, actionable error (it does NOT silently fall back to the
    in-pod build, which OOMs small nodes)."""
    def prepare(app_name: str, namespace: str, project_dir: str) {
        super.prepare(app_name, namespace, project_dir);
        repo_root = host_repo_root();
        binary = build_release_binary(repo_root);
        raw = pack_toolchain(repo_root, binary);
        self._toolchain_object_key = toolchain_object_key(
            app_name, content_address(raw)
        );
        self._toolchain_bytes = raw;
    }

    """Publish the app bundle AND the toolchain bundle (one loader-pod session)."""
    def _seed_artifacts -> list[tuple[str, bytes]] {
        artifacts = super._seed_artifacts();
        artifacts.append((self._toolchain_object_key, self._toolchain_bytes));
        return artifacts;
    }

    """Untar the app source AND the toolchain onto the shared app volume."""
    def _unpack_bundle_paths -> list[str] {
        paths = super._unpack_bundle_paths();
        paths.append(bundle_pvc_path(self._toolchain_object_key));
        return paths;
    }
}


"""Select + prepare the code injector for a k8s deploy. UNIFIED across the
monolith and microservice cells so both choose identically. --experimental ships a
host-built release binary (BinaryInjector: fast, ~no build memory); the default
ships source for an in-pod install of the PUBLISHED release (PvcInjector). When
--experimental cannot ship a binary (no zig on PATH, build error) it FAILS LOUD
(warn + raise) rather than silently degrading to the in-pod clone+build, which
OOMs small nodes. Returns (prepared injector, ship_binary flag, toolchain key):
ship_binary feeds build_bootstrap_init_container; the toolchain key lets a
two-phase caller (microservice) reconstruct the injector for mutate_pod_spec."""
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
