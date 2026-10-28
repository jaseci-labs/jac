import hashlib;
import logging;

glob logger = logging.getLogger(__name__),
     DRY_RUN_DIGEST: str = "sha256-computed-at-deploy";


obj BinaryInjector(PvcInjector) {
    has channel: Channel = Channel.STABLE,
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"",
        _pod_binary_bytes: bytes = b"",
        _pod_binary_sha256: str = "",
        _seal_binary_bytes: bytes = b"",
        _pod_arch: str = "";

    def prepare(app_name: str, namespace: str, project_dir: str);
    def _resolve_seal_binary(pod_payload: bytes, pod_arch: str, version: str) -> bytes;
    def _seed_artifacts -> list[tuple[str, bytes]];
    def _unpack_bundle_paths -> list[str];
    def _skip_when_image_binary -> dict[str, str];
}


def select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    dry_run: bool = False,
    access_mode: str = "ReadWriteMany",
    fleet: any = None,
    client_ready: any = None
) -> tuple[PvcInjector, str];
