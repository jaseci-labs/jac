import os;
import logging;

glob logger = logging.getLogger(__name__);

glob BUNDLE_VOLUME_NAME: str = "jac-bundles",
     BUNDLE_MOUNT_PATH: str = "/jac-bundles",
     PVC_BOOTSTRAP_NAME: str = "jac-pvc-bootstrap";

glob RUNTIME_UID: int = 1000,
     RUNTIME_GID: int = 1000,
     VOLUME_PERMS_NAME: str = "jac-volume-perms";


def bundle_pvc_name(app_name: str) -> str;


def bundle_pvc_path(object_key: str) -> str;


def bundle_keys_from_pod_spec(pod_spec: dict[str, any]) -> list[str];


def build_bundle_pvc(
    app_name: str,
    namespace: str,
    size: str,
    storage_class: str,
    access_mode: str = "ReadWriteMany"
) -> dict[str, any];


def build_volume_perms_init_container(
    name: str, image: str, mounts: list[dict[str, str]], recursive: bool = False
) -> dict[str, any];


def _writable_mount(mount: dict[str, str]) -> dict[str, str];


def build_loader_perms_init_container(loader_image: str) -> dict[str, any];


def runtime_pod_security_context -> dict[str, any];


def build_loader_pod(
    loader_pod: str, pvc_name: str, loader_image: str
) -> dict[str, any];


def _unpack_cmd(path: str, image_binary_sha256: str) -> str;


def pvc_unpack_script(
    bundle_paths: list[str], skip_when_image_binary: (dict[str, str] | None) = None
) -> str;


def build_pvc_init_container(
    base_image: str,
    bundle_paths: list[str],
    skip_when_image_binary: (dict[str, str] | None) = None
) -> dict[str, any];


def _ensure_volume(pod_spec: dict[str, any], volume: dict[str, any]) -> None;


obj PvcInjector(Injector) {
    has size: str = "1Gi",
        storage_class: str = "",
        access_mode: str = "ReadWriteMany",
        loader_image: str = "busybox:1.36",
        _object_key: str = "",
        _bundle_bytes: bytes = b"",
        _fleet: any = None,
        _client_ready: any = None;

    def _seed_artifacts -> list[tuple[str, bytes]];
    def _unpack_bundle_paths -> list[str];
    def _skip_when_image_binary -> dict[str, str];
    def prepare(app_name: str, namespace: str, project_dir: str);
    def seed(app_name: str, namespace: str);
    def unpack_script -> str;
    def mutate_pod_spec(
        pod_spec: dict[str, any], base_image: str, unpack_container: bool = True
    ) -> dict[str, any];

    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]];
}
