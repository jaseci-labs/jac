import os;
import logging;
import from jaclang.scale.injector.injector { Injector }
import from jaclang.scale.injector.bundle {
    pack_jab,
    content_address,
    bundle_object_key,
    ensure_jac_toml_cmd,
    APP_VOLUME_NAME,
    APP_MOUNT_PATH
}

glob logger = logging.getLogger(__name__);

glob BUNDLE_VOLUME_NAME: str = "jac-bundles",
     BUNDLE_MOUNT_PATH: str = "/jac-bundles";

glob LOADER_UID: int = 1000,
     LOADER_GID: int = 1000;


def bundle_pvc_name(app_name: str) -> str {
    return f"{app_name}-bundles";
}


def bundle_pvc_path(object_key: str) -> str {
    return f"{BUNDLE_MOUNT_PATH}/{object_key}";
}


def build_bundle_pvc(
    app_name: str, namespace: str, size: str, storage_class: str
) -> dict[str, any] {
    access_modes = ["ReadWriteMany"];
    if not storage_class {
        raise ValueError(
            f"Bundle PVC '{bundle_pvc_name(app_name)}' requests accessModes "
            "[ReadWriteMany] but no bundle_storage_class is set, so it would use "
            "the cluster default StorageClass. Most cloud defaults (e.g. EKS gp3 / "
            "ebs.csi.aws.com) are ReadWriteOnce and cannot provision a "
            "ReadWriteMany volume, leaving the bundle-loader pod Pending. Set "
            "'bundle_storage_class' under [scale.kubernetes] to a "
            "RWX-capable StorageClass (e.g. 'efs-sc'), or, on a single-node "
            "local cluster (kind / k3d / minikube), set 'bundle_host_path' to "
            "stage bundles in a directory on the host node instead (no PVC "
            "needed)."
        );
    }
    spec: dict[str, any] = {
        "accessModes": access_modes,
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


def build_loader_perms_init_container(loader_image: str) -> dict[str, any] {
    # The pod's fsGroup is only honored on volumes whose plugin manages
    # ownership: hostPath and NFS never do, and CSI drivers with the default
    # fsGroupPolicy (ReadWriteOnceWithFSType) skip ReadWriteMany volumes --
    # exactly what the bundle PVC must be. On such storage the volume root
    # arrives root-owned 0755 and the non-root loader dies at its first mkdir
    # with "Permission denied" (#7432). This init container runs as root just
    # long enough to hand the mount to the loader identity; the hardened
    # non-root loader then takes over. It is best-effort: storage that squashes
    # root (EFS access points, root-squash NFS) rejects the chown, but there
    # the backend's own identity mapping decides writability and the loader's
    # mkdir still surfaces a clear error if the volume is truly unwritable.
    script = (
        f"chown -R {LOADER_UID}:{LOADER_GID} {BUNDLE_MOUNT_PATH} "
        f"&& chmod 0775 {BUNDLE_MOUNT_PATH} "
        "|| echo 'bundle-perms: chown/chmod not permitted by the storage "
        "backend; relying on the volume permissions as provisioned' >&2"
    );
    return {
        "name": "bundle-perms",
        "image": loader_image,
        "command": ["sh", "-c", script],
        "securityContext": {
            "runAsNonRoot": False,
            "runAsUser": 0,
            "readOnlyRootFilesystem": True,
            "allowPrivilegeEscalation": False,
            "capabilities": {
                "drop": ["ALL"],
                "add": ["CHOWN", "FOWNER", "DAC_OVERRIDE"]
            },
            "seccompProfile": {"type": "RuntimeDefault"}
        },
        "volumeMounts": [{"name": "bundles", "mountPath": BUNDLE_MOUNT_PATH}]
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
        # Local-cluster (kind / k3d / minikube) escape hatch: stage bundles in
        # a directory on the host node instead of an RWX PVC. On a single node
        # every pod sees the same filesystem, so ReadWriteMany degenerates to a
        # shared hostPath and no RWX provisioner is required (#7433).
        host_path: str = "",
        loader_image: str = "busybox:1.36",
        provisioned_database: str = "",
        _object_key: str = "",
        _bundle_bytes: bytes = b"";

    def _seed_artifacts -> list[tuple[str, bytes]] {
        return [(self._object_key, self._bundle_bytes)];
    }

    def _bundle_volume_source(app_name: str) -> dict[str, any] {
        if self.host_path {
            return {"hostPath": {"path": self.host_path, "type": "DirectoryOrCreate"}};
        }
        return {"persistentVolumeClaim": {"claimName": bundle_pvc_name(app_name)}};
    }

    def _loader_pod_manifest(app_name: str) -> dict[str, any] {
        container_security: dict[str, any] = {
            "readOnlyRootFilesystem": True,
            "allowPrivilegeEscalation": False,
            "capabilities": {"drop": ["ALL"]},
            "seccompProfile": {"type": "RuntimeDefault"}
        };
        pod_security: dict[str, any] = {"seccompProfile": {"type": "RuntimeDefault"}};
        init_containers: list[dict[str, any]] = [];
        if self.host_path {
            # hostPath mode: kubelet creates the directory root-owned (0755) and
            # never applies fsGroup, so the loader must run as root to write the
            # staged bundles. Set runAsUser explicitly (rather than leaning on
            # the loader image's default user) so this holds image-independently
            # - acceptable for a local-single-node-only mode (#7433).
            pod_security.update({"runAsUser": 0});
            container_security.update({"runAsUser": 0});
        } else {
            # PVC mode: fsGroup makes the volume group-writable, so the loader
            # runs non-root. But fsGroup is not honored on hostPath/NFS or most
            # ReadWriteMany CSI volumes (exactly what the bundle PVC must be),
            # where the volume root arrives root-owned 0755; the bundle-perms
            # init container runs as root just long enough to chown the mount to
            # the loader identity so the non-root loader can write (#7432).
            pod_security.update(
                {"runAsNonRoot": True, "runAsUser": LOADER_UID, "fsGroup": LOADER_GID}
            );
            container_security.update({"runAsNonRoot": True, "runAsUser": LOADER_UID});
            init_containers.append(
                build_loader_perms_init_container(self.loader_image)
            );
        }
        bundles_volume: dict[str, any] = {"name": "bundles"};
        bundles_volume.update(self._bundle_volume_source(app_name));
        spec: dict[str, any] = {
            "restartPolicy": "Never",
            "securityContext": pod_security,
            "containers": [
                {
                    "name": "loader",
                    "image": self.loader_image,
                    "command": ["sh", "-c", "sleep 3600"],
                    "securityContext": container_security,
                    "volumeMounts": [
                        {"name": "bundles", "mountPath": BUNDLE_MOUNT_PATH},
                        {"name": "tmp", "mountPath": "/tmp"}
                    ]
                }
            ],
            "volumes": [bundles_volume, {"name": "tmp", "emptyDir": {}}]
        };
        if init_containers {
            spec["initContainers"] = init_containers;
        }
        return {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "name": f"{app_name}-bundle-loader",
                "labels": {"managed": "jac-scale", "jac-scale.role": "bundle-loader"}
            },
            "spec": spec
        };
    }

    def _unpack_bundle_paths -> list[str] {
        return [bundle_pvc_path(self._object_key)];
    }

    def prepare(app_name: str, namespace: str, project_dir: str) {
        # BinaryInjector sets _pod_binary_bytes; pack_jab needs it to seal the .jab.
        raw = pack_jab(
            project_dir,
            self.provisioned_database,
            getattr(self, "_pod_binary_bytes", b"")
        );
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
        import from jaclang.scale._optdeps.kubernetes { client, ApiException }
        import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
            run_kubectl_command,
            wait_for_pod_phase,
            wait_for_pod_deletion
        }
        import tempfile;
        import from pathlib { Path }

        core_v1 = client.CoreV1Api();
        bundle_store = (
            f"host path {self.host_path}"
                if self.host_path
                else f"PVC {bundle_pvc_name(app_name)}"
        );
        loader_pod = f"{app_name}-bundle-loader";

        pod_body = self._loader_pod_manifest(app_name);
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
                # Object keys are content-addressed (sha256 of the bytes), so a
                # file already on the PVC IS this payload - skip the upload.
                # This is what makes warm redeploys cheap: the ~170MB toolchain
                # and unchanged bundles never cross the wire twice (#7179).
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
                            f"test -f '{bundle_path}'"
                        ]
                    );
                    logger.info(
                        f"pvc-injector: {object_key} already seeded "
                        f"(content-addressed hit); skipping upload."
                    );
                    continue;
                } except RuntimeError as probe_err {
                    # Expected when the object is absent (test -f exits 1); any
                    # real infra problem resurfaces loudly on the upload below.
                    logger.debug(f"pvc-injector: presence probe: {probe_err}");
                }
                # Local scratch file only: kubectl cp needs a path to copy FROM.
                # The suffix is irrelevant (nothing reads it); the real PVC
                # filename comes from object_key (.jab app bundle / .tar.gz
                # toolchain). Deleted right after the copy.
                with tempfile.NamedTemporaryFile(delete=False) as tmp {
                    tmp.write(raw);
                    tmp_path = Path(tmp.name);
                }
                # Copy to a unique staging path first, then atomically `mv` it
                # into the content-addressed slot. `kubectl cp` is not atomic, so
                # an interruption mid-transfer would otherwise leave a truncated
                # file that `test -f` accepts forever (poisoning the cache); the
                # mv only names the object once its bytes are complete.
                staging_path = f"{bundle_path}.{os.getpid()}.part";
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
                            f"{loader_pod}:{staging_path}"
                        ],
                        cwd=tmp_path.parent
                    );
                    # Concatenated, not an f-string: a jac f-string with two
                    # quoted interpolations collapses them into ONE quoted
                    # operand ("mv -f 'src dst'"), so mv sees a single argument
                    # and the seed fails with a usage error.
                    run_kubectl_command(
                        [
                            "exec",
                            "-n",
                            namespace,
                            loader_pod,
                            "--",
                            "sh",
                            "-c",
                            "mv -f '" + staging_path + "' '" + bundle_path + "'"
                        ]
                    );
                    logger.info(
                        f"pvc-injector: seeded {len(raw)} bytes to "
                        f"{bundle_store} at {bundle_path}"
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
        bundle_volume: dict[str, any] = {"name": BUNDLE_VOLUME_NAME};
        bundle_volume.update(self._bundle_volume_source(app_name));
        _ensure_volume(pod_spec, bundle_volume);

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
        if self.host_path {
            # hostPath mode stages bundles directly on the node's filesystem;
            # there is no PVC to create (and no RWX StorageClass to require).
            return [];
        }
        return [build_bundle_pvc(app_name, namespace, self.size, self.storage_class)];
    }
}
