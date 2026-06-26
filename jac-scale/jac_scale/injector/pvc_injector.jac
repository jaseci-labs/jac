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
        "set -eu; " + f"tar xzf {bundle_path} -C {APP_MOUNT_PATH}; " + f"{ensure_jac_toml_cmd()}; " + f"pip install --no-cache-dir --target={PYDEPS_DIR} {install}"
    );
    return {
        "name": "jac-pvc-bootstrap",
        "image": base_image,
        "command": ["sh", "-c"],
        "args": [script],
        "volumeMounts": [
            {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH},
            {
                "name": BUNDLE_VOLUME_NAME,
                "mountPath": BUNDLE_MOUNT_PATH,
                "readOnly": True
            }
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
        # Image for the short-lived loader pod that kubectl-cp's the bundle onto
        # the PVC. Needs only `sh`, `tar`, and `mkdir`; busybox is tiny and has all
        # three. Override only for air-gapped registries.
        loader_image: str = "busybox:1.36",
        _object_key: str = "",
        _bundle_bytes: bytes = b"";

    """Pack the project and content-address it, recording the object key (for
    mutate_pod_spec) and the packed bytes (for seed). Build-time and free of
    cluster I/O so it can run during manifest generation, before the PVC exists."""
    def prepare(app_name: str, namespace: str, project_dir: str) {
        raw = pack_source(project_dir);
        digest = content_address(raw);
        self._object_key = bundle_object_key(app_name, digest);
        self._bundle_bytes = raw;
    }

    """Publish the packed bundle onto the bundle PVC. Deploy-time, side-effecting,
    and run AFTER extra_manifests() are applied so the PVC exists: a short-lived
    loader pod mounts the PVC read-write, the deploy host kubectl-cp's the
    content-addressed tar.gz onto it, then the pod is deleted. App pods mount the
    same PVC read-only and unpack the bundle in their init container.

    Idempotent: the on-PVC path is content-addressed, so re-seeding identical bytes
    just overwrites the same file. `kubectl` must be on the deploy host PATH (the
    monolith code-sync path already requires it)."""
    def seed(app_name: str, namespace: str) {
        if not self._bundle_bytes {
            raise ValueError(
                "PvcInjector.seed() called before prepare(); there are no bundle "
                "bytes to publish. prepare() must run first to pack the project."
            );
        }
        import from jac_scale._optdeps.kubernetes { client, ApiException }
        import from jac_scale.deploy.target.kubernetes.utils.kubernetes_utils {
            run_kubectl_command,
            wait_for_pod_phase,
            wait_for_pod_deletion
        }
        import tempfile;
        import from pathlib { Path }

        core_v1 = client.CoreV1Api();
        pvc_name = bundle_pvc_name(app_name);
        loader_pod = f"{app_name}-bundle-loader";
        bundle_path = bundle_pvc_path(self._object_key);
        parent_dir = str(Path(bundle_path).parent);

        pod_body = {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "name": loader_pod,
                "labels": {"managed": "jac-scale", "jac-scale.role": "bundle-loader"}
            },
            "spec": {
                "restartPolicy": "Never",
                "securityContext": {
                    "runAsNonRoot": True,
                    "runAsUser": 1000,
                    "fsGroup": 1000,
                    "seccompProfile": {"type": "RuntimeDefault"}
                },
                "containers": [
                    {
                        "name": "loader",
                        "image": self.loader_image,
                        "command": ["sh", "-c", "sleep 3600"],
                        "securityContext": {
                            "runAsNonRoot": True,
                            "runAsUser": 1000,
                            "readOnlyRootFilesystem": True,
                            "allowPrivilegeEscalation": False,
                            "capabilities": {"drop": ["ALL"]},
                            "seccompProfile": {"type": "RuntimeDefault"}
                        },
                        "volumeMounts": [
                            {"name": "bundles", "mountPath": BUNDLE_MOUNT_PATH},
                            {"name": "tmp", "mountPath": "/tmp"}
                        ]
                    }
                ],
                "volumes": [
                    {
                        "name": "bundles",
                        "persistentVolumeClaim": {"claimName": pvc_name}
                    },
                    {"name": "tmp", "emptyDir": {}}
                ]
            }
        };
        try {
            core_v1.create_namespaced_pod(namespace, pod_body);
        } except ApiException as exc {
            if exc.status == 409 {
                core_v1.delete_namespaced_pod(loader_pod, namespace);
                wait_for_pod_deletion(core_v1, namespace, loader_pod);
                core_v1.create_namespaced_pod(namespace, pod_body);
            } else {
                raise;
            }
        }
        # Loader Pending past this wait usually means the PVC never bound (no RWX
        # storage class on a multi-node cluster); the timeout surfaces it.
        wait_for_pod_phase(core_v1, namespace, loader_pod, {"Running"});

        with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp {
            tmp.write(self._bundle_bytes);
            tmp_path = Path(tmp.name);
        }
        try {
            run_kubectl_command(
                [
                    "exec",
                    "-n",
                    namespace,
                    loader_pod,
                    "--",
                    "sh",
                    "-c",
                    f"mkdir -p '{parent_dir}'"
                ]
            );
            run_kubectl_command(
                ["cp", "-n", namespace, tmp_path.name, f"{loader_pod}:{bundle_path}"],
                cwd=tmp_path.parent
            );
            logger.info(
                f"pvc-injector: seeded {len(self._bundle_bytes)} bytes to "
                f"{pvc_name} at {bundle_path}"
            );
        } finally {
            tmp_path.unlink(missing_ok=True);
            try {
                core_v1.delete_namespaced_pod(loader_pod, namespace);
                wait_for_pod_deletion(core_v1, namespace, loader_pod);
            } except ApiException as exc {
                if exc.status != 404 {
                    raise;
                }
            }
        }
    }

    def mutate_pod_spec(pod_spec: dict[str, any], base_image: str) -> dict[str, any] {
        # Fail loudly rather than default to "app": the claim name is derived
        # from app_name and must match the PVC that prepare() / extra_manifests()
        # created under the real app name. Silently defaulting here would mount an
        # `app-bundles` claim that was never created. The manifest builder sets
        # _jac_meta before delegating, so a miss is a wiring bug, not a runtime
        # state.
        metadata = pod_spec.get("_jac_meta");
        app_name = str(metadata.get("app_name", "")) if metadata is not None else "";
        if not app_name {
            raise ValueError(
                "PvcInjector.mutate_pod_spec requires pod_spec['_jac_meta']['app_name'] "
                "(set by the manifest builder before delegating); without it the bundle "
                "PVC claim name would not match the PVC created by prepare() / "
                "extra_manifests(), so the pod would mount a claim that was never created."
            );
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
        init_containers: list[dict[str, any]] = list(
            pod_spec.get("initContainers", [])
        );
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
