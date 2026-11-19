import hashlib;
import json;
import logging;
import os;
import shutil;
import tempfile;
import tomllib;

glob logger = logging.getLogger(__name__),
     DRY_RUN_DIGEST: str = "sha256-computed-at-deploy",
     BUILD_SCHEMA: int = 1,
     BUILD_RECORD: str = "build.json",
     BUILD_BUNDLE: str = "bundle.jab",
     _DRIFT_SHOWN: int = 10;


obj BinaryInjector(PvcInjector) {
    has channel: Channel = Channel.STABLE,
        _toolchain_object_key: str = "",
        _toolchain_bytes: bytes = b"",
        _pod_binary_sha256: str = "",
        _seal_binary_bytes: bytes = b"",
        _pod_arch: str = "";

    def prepare(app_name: str, namespace: str, project_dir: str);
    def _fetch_pod_binary(project_dir: str, pod_arch: str, version: str) -> bytes;
    def _adopt_pod_binary(app_name: str, pod_arch: str, payload: bytes);
    def _resolve_seal_binary(pod_payload: bytes, pod_arch: str, version: str) -> bytes;
    def _seed_artifacts -> list[tuple[str, bytes]];
    def _unpack_bundle_paths -> list[str];
    def _skip_when_image_binary -> dict[str, str];
    def write_build(out_dir: str, app_name: str) -> dict[str, any];
    static def from_build(
        build_dir: str,
        app_name: str,
        project_dir: str,
        config_tomls: dict[str, str],
        pod_arch: str = "",
        storage_class: str = "",
        access_mode: str = "ReadWriteMany",
        dry_run: bool = False
    ) -> BinaryInjector;
}


def config_digest(tomls: dict[str, str]) -> str;


def config_drift(sealed: dict[str, str], applying: dict[str, str]) -> list[str];


def select_injector(
    storage_class: str,
    app_name: str,
    namespace: str,
    project_dir: str,
    dry_run: bool = False,
    access_mode: str = "ReadWriteMany",
    fleet: any = None,
    client_ready: any = None,
    bake_client: bool = False,
    pod_arch: str = ""
) -> tuple[BinaryInjector, str];
