import logging;
import from jac_scale.injector.injector { Injector }
import from jac_scale.injector.bundle {
    pack_source,
    content_address,
    bundle_object_key,
    ensure_jac_toml_cmd,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH
}

glob logger = logging.getLogger(__name__);

glob BUNDLE_VOLUME_NAME: str = "jac-bundles",
     BUNDLE_MOUNT_PATH: str = "/jac-bundles";


def bundle_pvc_name(app_name: str) -> str {
    return f"{app_name}-bundles";
}


def bundle_pvc_path(object_key: str) -> str {
    return f"{BUNDLE_MOUNT_PATH}/{object_key}";
}


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


def build_pvc_init_container(
    base_image: str, bundle_paths: list[str]
) -> dict[str, any] {
    untars = "".join([f"tar xzf {p} -C {APP_MOUNT_PATH}; " for p in bundle_paths]);
    script = "set -eu; " + untars + ensure_jac_toml_cmd();
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


obj PvcInjector(Injector) {
    has size: str = "1Gi",
        storage_class: str = "",
        loader_image: str = "busybox:1.36",
        _object_key: str = "",
        _bundle_bytes: bytes = b"";

    def _seed_artifacts -> list[tuple[str, bytes]] {
        return [(self._object_key, self._bundle_bytes)];
    }

    def _unpack_bundle_paths -> list[str] {
        return [bundle_pvc_path(self._object_key)];
    }

    def prepare(app_name: str, namespace: str, project_dir: str) {
        raw = pack_source(project_dir);
        digest = content_address(raw);
        self._object_key = bundle_object_key(app_name, digest);
        self._bundle_bytes = raw;
    }

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

        wait_for_pod_phase(core_v1, namespace, loader_pod, {"Running"});

        try {
            for (object_key, raw) in self._seed_artifacts() {
                bundle_path = bundle_pvc_path(object_key);
                parent_dir = str(Path(bundle_path).parent);
                with tempfile.NamedTemporaryFile(
                    suffix=".tar.gz", delete=False
                ) as tmp {
                    tmp.write(raw);
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
                        [
                            "cp",
                            "-n",
                            namespace,
                            tmp_path.name,
                            f"{loader_pod}:{bundle_path}"
                        ],
                        cwd=tmp_path.parent
                    );
                    logger.info(
                        f"pvc-injector: seeded {len(raw)} bytes to "
                        f"{pvc_name} at {bundle_path}"
                    );
                } finally {
                    tmp_path.unlink(missing_ok=True);
                }
            }
        } finally {
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

        init_containers: list[dict[str, any]] = list(
            pod_spec.get("initContainers", [])
        );
        init_containers.append(
            build_pvc_init_container(base_image, self._unpack_bundle_paths())
        );
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
