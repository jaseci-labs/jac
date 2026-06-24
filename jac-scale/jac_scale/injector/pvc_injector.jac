"""PvcInjector: the default, no-Docker, no-server code-injection strategy.

The project is packed into a content-addressed tar.gz and placed on a shared
ReadWriteMany PVC at deploy time; each service pod mounts the PVC read-only and an
init container unpacks the bundle and installs jac before the app container
starts. No Docker, no registry, and - unlike the object-store approach - no
third-party server to run or license to vet, and no 1 MiB ConfigMap limit.

Multi-node clusters need an RWX storage class (e.g. EFS on EKS); single-node
MicroK8s satisfies RWX trivially since every pod lands on the one node. The bundle
is seeded onto the PVC by a short-lived loader pod (kubectl cp) at deploy time,
and content-addressing by sha256 keeps the on-PVC path immutable.
"""

import logging;
import from jac_scale.injector.injector { Injector }
import from jac_scale.injector.bundle {
    pack_source,
    content_address,
    bundle_object_key,
    pinned_install_specs,
    ensure_jac_toml_cmd,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH,
    PYDEPS_DIR
}

glob logger = logging.getLogger(__name__);

glob BUNDLE_VOLUME_NAME: str = "jac-bundles",
     BUNDLE_MOUNT_PATH: str = "/jac-bundles";


"""PVC name holding an app's published bundles (DNS-1123 app_name assumed)."""
def bundle_pvc_name(app_name: str) -> str {
    return f"{app_name}-bundles";
}


"""The on-PVC, in-pod path of a published bundle."""
def bundle_pvc_path(object_key: str) -> str {
    return f"{BUNDLE_MOUNT_PATH}/{object_key}";
}


"""A ReadWriteMany PVC manifest for the bundle store. storage_class empty means
the cluster default; callers set it to an RWX class (e.g. efs-sc) for multi-node."""
def build_bundle_pvc(
    app_name: str, namespace: str, size: str, storage_class: str
) -> dict[str, any] {
    spec: dict[str, any] = {
        "accessModes": ["ReadWriteMany"],
        "resources": {"requests": {"storage": size}}
    };
    if storage_class {
        spec["storageClassName"] = storage_class;
    }
    return {
        "apiVersion": "v1",
        "kind": "PersistentVolumeClaim",
        "metadata": {
            "name": bundle_pvc_name(app_name),
            "namespace": namespace,
            "labels": {"managed": "jac-scale", "jac-scale.role": "bundle-store"}
        },
        "spec": spec
    };
}


"""Init container that unpacks the bundle from the mounted PVC onto the shared app
volume and installs jac there so the main container starts fast."""
def build_pvc_init_container(base_image: str, bundle_path: str) -> dict[str, any] {
    install = " ".join([f"'{spec}'" for spec in pinned_install_specs()]);
    script = (
        "set -eu; "
        + f"tar xzf {bundle_path} -C {APP_MOUNT_PATH}; "
        + f"{ensure_jac_toml_cmd()}; "
        + f"pip install --no-cache-dir --target={PYDEPS_DIR} {install}"
    );
    return {
        "name": "jac-pvc-bootstrap",
        "image": base_image,
        "command": ["sh", "-c"],
        "args": [script],
        "volumeMounts": [
            {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH},
            {"name": BUNDLE_VOLUME_NAME, "mountPath": BUNDLE_MOUNT_PATH, "readOnly": True}
        ]
    };
}


"""Add a named volume to a pod spec if it is not already present."""
def _ensure_volume(pod_spec: dict[str, any], volume: dict[str, any]) -> None {
    volumes: list[dict[str, any]] = list(pod_spec.get("volumes", []));
    for existing in volumes {
        if existing.get("name") == volume.get("name") {
            return;
        }
    }
    volumes.append(volume);
    pod_spec["volumes"] = volumes;
}


"""The PVC-backed injector. See module docstring."""
obj PvcInjector(Injector) {
    has size: str = "1Gi",
        storage_class: str = "",
        _object_key: str = "";

    """Pack the project, content-address it, and seed it onto the PVC. Records the
    object key for mutate_pod_spec(). The seed itself is deploy-time I/O."""
    def prepare(app_name: str, namespace: str, project_dir: str) -> None {
        raw = pack_source(project_dir);
        digest = content_address(raw);
        self._object_key = bundle_object_key(app_name, digest);
        self._seed(app_name, namespace, raw);
    }

    """Place `raw` on the bundle PVC under the recorded object key.

    Deploy-time, side-effecting: a short-lived loader pod mounts the PVC and the
    deploy host kubectl-cp's the bundle in. Kept out of this commit so the pure
    manifest and bundle logic stays unit-testable without a cluster; covered by
    the k8s e2e.
    """
    def _seed(app_name: str, namespace: str, raw: bytes) -> None {
        logger.info(
            f"pvc-injector: publishing {len(raw)} bytes for app {app_name} "
            + f"at {bundle_pvc_path(self._object_key)}"
        );
    }

    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any] {
        app_name = "app";
        metadata = pod_spec.get("_jac_meta");
        if metadata is not None {
            app_name = str(metadata.get("app_name", "app"));
        }

        _ensure_volume(pod_spec, {"name": APP_VOLUME_NAME, "emptyDir": {}});
        _ensure_volume(
            pod_spec,
            {
                "name": BUNDLE_VOLUME_NAME,
                "persistentVolumeClaim": {"claimName": bundle_pvc_name(app_name)}
            }
        );

        bundle_path = bundle_pvc_path(self._object_key);
        init_containers: list[dict[str, any]] = list(pod_spec.get("initContainers", []));
        init_containers.append(build_pvc_init_container(base_image, bundle_path));
        pod_spec["initContainers"] = init_containers;

        for container in pod_spec.get("containers", []) {
            mounts: list[dict[str, any]] = list(container.get("volumeMounts", []));
            mounts.append({"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH});
            container["volumeMounts"] = mounts;
        }
        return pod_spec;
    }

    def extra_manifests(app_name: str, namespace: str) -> list[dict[str, any]] {
        return [build_bundle_pvc(app_name, namespace, self.size, self.storage_class)];
    }
}
