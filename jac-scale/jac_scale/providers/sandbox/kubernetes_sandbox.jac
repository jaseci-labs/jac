import os;
import time;
import uuid;
import json;
import from threading { Lock, Thread }
import from typing { Any }
import from jac_scale.abstractions.sandbox_environment {
    SandboxEnvironment,
    validate_sandbox_path
}
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.models.sandbox_result { SandboxResult }
import from jac_scale.abstractions.models.sandbox_status {
    SandboxState,
    SandboxStatus,
    SandboxInfo
}
import from jac_scale.abstractions.logger { Logger }
import from jaclang.cli.console { console }
import from jac_scale.factories.ingress_factory { IngressFactory }

glob _SANDBOX_LABEL: str = "jac-sandbox",
     _INTERNAL_PORT: int = 8000,
     _CONFIGMAP_SIZE_LIMIT: int = 1048576;

obj KubernetesSandbox(SandboxEnvironment) {
    has _registry: dict = {},
        _lock: Lock = Lock(),
        _k8s_initialized: bool = False,
        _rbac_provisioned: bool = False,
        _ingress_provider: Any = None,
        _warm_pool: list = [],
        _pool_initialized: bool = False,
        _cleanup_started: bool = False;

    def _init_k8s -> None {
        if self._k8s_initialized {
            return;
        }
        import from kubernetes { config as k8s_config }
        import from kubernetes.config { ConfigException }
        try {
            k8s_config.load_kube_config();
        } except ConfigException {
            k8s_config.load_incluster_config();
        }
        self._k8s_initialized = True;
    }

    def _get_ingress_provider -> Any {
        if self._ingress_provider is None {
            if self.config.proxy_mode {
                ingress_type = "proxy";
            } elif self.config.tls_enabled
            or self.config.domain_template != "{sandbox_id}.preview.example.com" {
                ingress_type = "kubernetes";
            } else {
                ingress_type = "local";
            }
            self._ingress_provider = IngressFactory.create(
                ingress_type,
                {
                    "ingress_class": self.config.ingress_class,
                    "tls_enabled": self.config.tls_enabled,
                    "tls_issuer": self.config.tls_issuer,
                    "domain_template": self.config.domain_template
                }
            );
        }
        return self._ingress_provider;
    }

    def _ensure_namespace {
        import from kubernetes { client }
        core_v1 = client.CoreV1Api();
        try {
            core_v1.read_namespace(self.config.namespace);
        } except Exception {
            ns_body = client.V1Namespace(
                metadata=client.V1ObjectMeta(
                    name=self.config.namespace, labels={_SANDBOX_LABEL: "namespace"}
                )
            );
            core_v1.create_namespace(ns_body);
            if self.logger {
                self.logger.info(f"Created namespace: {self.config.namespace}");
            }
        }
    }

    def _ensure_rbac -> None {
        if self._rbac_provisioned {
            return;
        }
        import from kubernetes { client }
        rbac_v1 = client.RbacAuthorizationV1Api();
        role_name = "jac-sandbox-manager";
        binding_name = "jac-sandbox-manager-binding";
        namespace = self.config.namespace;

        # Create Role
        role_body = {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "Role",
            "metadata": {"name": role_name, "namespace": namespace},
            "rules": [
                {
                    "apiGroups": [""],
                    "resources": [
                        "pods",
                        "pods/exec",
                        "pods/log",
                        "services",
                        "configmaps"
                    ],
                    "verbs": [
                        "create",
                        "get",
                        "list",
                        "watch",
                        "delete",
                        "update",
                        "patch"
                    ]
                },
                {
                    "apiGroups": ["networking.k8s.io"],
                    "resources": ["ingresses"],
                    "verbs": ["create", "get", "list", "delete", "update"]
                }
            ]
        };
        try {
            rbac_v1.read_namespaced_role(role_name, namespace);
        } except Exception {
            rbac_v1.create_namespaced_role(namespace, role_body);
        }

        # Create RoleBinding — bind to the default ServiceAccount in the
        # namespace where the main app is running (usually 'default')
        app_namespace = str(os.environ.get("POD_NAMESPACE", "default"));
        app_sa = str(os.environ.get("POD_SERVICE_ACCOUNT", "default"));
        binding_body = {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "RoleBinding",
            "metadata": {"name": binding_name, "namespace": namespace},
            "roleRef": {
                "apiGroup": "rbac.authorization.k8s.io",
                "kind": "Role",
                "name": role_name
            },
            "subjects": [
                {"kind": "ServiceAccount", "name": app_sa, "namespace": app_namespace}
            ]
        };
        try {
            rbac_v1.read_namespaced_role_binding(binding_name, namespace);
        } except Exception {
            rbac_v1.create_namespaced_role_binding(namespace, binding_body);
        }

        self._rbac_provisioned = True;
        if self.logger {
            self.logger.info(
                f"RBAC provisioned: Role={role_name}, "
                f"Binding={binding_name} in ns={namespace}"
            );
        }
    }

    def _get_pod_name(sandbox_id: str) -> str {
        rec: Any = self._registry.get(sandbox_id);
        if rec {
            rec_d: dict = dict(rec);
            return str(rec_d.get("pod_name", sandbox_id));
        }
        return sandbox_id;
    }

    def _generate_id(user_id: str, project_id: str) -> str {
        short = str(uuid.uuid4())[:8];
        # K8s names must be lowercase, alphanumeric, max 63 chars
        safe_user = str(user_id[:20]).lower().replace("_", "-");
        safe_proj = str(project_id[:10]).lower().replace("_", "-")
            if project_id
            else "def";
        return f"jac-sbx-{safe_user}-{safe_proj}-{short}";
    }

    def _create_configmap(sandbox_id: str, code_path: str, namespace: str) -> str {
        import from kubernetes { client }
        core_v1 = client.CoreV1Api();
        cm_name = f"{sandbox_id}-code";

        # Walk code_path and collect files
        import base64 as b64;
        data: dict[str, str] = {};
        binary_data: dict[str, str] = {};
        total_size = 0;

        if os.path.isdir(code_path) {
            skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git"];
            for walk_rec in os.walk(code_path) {
                dirpath: Any = walk_rec[0];
                dirnames: Any = walk_rec[1];
                filenames: Any = walk_rec[2];
                kept = [
                    d
                    for d in dirnames
                    if d not in skip_dirs
                ];
                dirnames.clear();
                for d in kept {
                    dirnames.append(d);
                }
                for fname in filenames {
                    full = os.path.join(str(dirpath), str(fname));
                    rel = os.path.relpath(full, code_path);
                    try {
                        with open(full, "r", encoding="utf-8") as f {
                            content = f.read();
                        }
                        total_size += len(str(content).encode("utf-8"));
                        if total_size > _CONFIGMAP_SIZE_LIMIT {
                            if self.logger {
                                self.logger.warn(
                                    f"Code exceeds ConfigMap limit ({_CONFIGMAP_SIZE_LIMIT} bytes), "
                                    f"truncating at {rel}"
                                );
                            }
                            break;
                        }
                        # ConfigMap keys: replace / with -- for flat storage
                        safe_key = str(rel).replace("/", "--");
                        data[safe_key] = str(content);
                    } except UnicodeDecodeError {
                        # Binary file — use binaryData field
                        with open(full, "rb") as bf {
                            raw = bf.read();
                        }
                        total_size += len(raw);
                        if total_size > _CONFIGMAP_SIZE_LIMIT {
                            if self.logger {
                                self.logger.warn(
                                    f"Code exceeds ConfigMap limit ({_CONFIGMAP_SIZE_LIMIT} bytes), "
                                    f"truncating at binary file {rel}"
                                );
                            }
                            break;
                        }
                        safe_key = str(rel).replace("/", "--");
                        binary_data[safe_key] = str(b64.b64encode(raw).decode("ascii"));
                    }
                }
            }
        }

        cm = client.V1ConfigMap(
            metadata=client.V1ObjectMeta(
                name=cm_name,
                namespace=namespace,
                labels={_SANDBOX_LABEL: "true", "jac-sandbox-id": sandbox_id}
            ),
            data=data,
            binary_data=binary_data
        );
        core_v1.create_namespaced_config_map(namespace, cm);
        return cm_name;
    }

    def _build_pod_spec(
        sandbox_id: str, cm_name: str, user_id: str, project_id: str
    ) -> dict {
        import from kubernetes { client }

        # Security context
        security_context = None;
        if self.config.security_context_enabled {
            security_context = client.V1SecurityContext(
                run_as_non_root=True,
                run_as_user=1000,
                read_only_root_filesystem=False,
                allow_privilege_escalation=False,
                capabilities=client.V1Capabilities(drop=["ALL"]),
                seccomp_profile=client.V1SeccompProfile(type="RuntimeDefault")
            );
        }

        # Resource limits
        resources = client.V1ResourceRequirements(
            limits={"cpu": self.config.cpu_limit, "memory": self.config.memory_limit},
            requests={"cpu": "100m", "memory": "64Mi"}
        );

        # Init container to unpack ConfigMap files into /app
        init_container = client.V1Container(
            name="code-setup",
            image=self.config.base_image,
            command=[
                "sh",
                "-c",
                "cd /code-flat && for f in *; do "
                "  target=$(echo \"$f\" | sed 's/--/\\//g'); "
                "  mkdir -p \"/app/$(dirname \"$target\")\"; "
                "  cp \"$f\" \"/app/$target\"; "
                "done && chown -R 1000:1000 /app && echo 'Code copied to /app'"
            ],
            volume_mounts=[
                client.V1VolumeMount(
                    name="code-configmap", mount_path="/code-flat", read_only=True
                ),
                client.V1VolumeMount(name="app-data", mount_path="/app")
            ]
        );

        # Main container
        main_container = client.V1Container(
            name="sandbox",
            image=self.config.base_image,
            command=[
                "bash",
                "-c",
                f"cd /app && jac install 2>/dev/null; "
                f"jac start main.jac -p {_INTERNAL_PORT} --dev"
            ],
            ports=[client.V1ContainerPort(container_port=_INTERNAL_PORT)],
            resources=resources,
            security_context=security_context,
            volume_mounts=[
                client.V1VolumeMount(name="app-data", mount_path="/app"),
                client.V1VolumeMount(name="tmp-scratch", mount_path="/tmp")
            ],
            env=[
                client.V1EnvVar(name="JAC_SANDBOX_ID", value=sandbox_id),
                client.V1EnvVar(name="JAC_SANDBOX_USER", value=user_id),
                client.V1EnvVar(name="JAC_SANDBOX_PROJECT", value=project_id),
                client.V1EnvVar(name="CHOKIDAR_USEPOLLING", value="1"),
                client.V1EnvVar(name="WATCHPACK_POLLING", value="true")
            ]
        );

        # Volumes
        volumes = [
            client.V1Volume(
                name="code-configmap",
                config_map=client.V1ConfigMapVolumeSource(name=cm_name)
            ),
            client.V1Volume(
                name="app-data",
                empty_dir=client.V1EmptyDirVolumeSource(
                    size_limit=self.config.app_storage_limit
                )
            ),
            client.V1Volume(
                name="tmp-scratch",
                empty_dir=client.V1EmptyDirVolumeSource(
                    size_limit=self.config.storage_limit
                )
            )
        ];

        pod = client.V1Pod(
            metadata=client.V1ObjectMeta(
                name=sandbox_id,
                namespace=self.config.namespace,
                labels={
                    _SANDBOX_LABEL: "true",
                    "jac-sandbox-id": sandbox_id,
                    "jac-sandbox-user": user_id,
                    "jac-sandbox-project": project_id
                }
            ),
            spec=client.V1PodSpec(
                init_containers=[init_container],
                containers=[main_container],
                volumes=volumes,
                restart_policy="Never",
                active_deadline_seconds=self.config.ttl_seconds,
                termination_grace_period_seconds=10,
                automount_service_account_token=False
            )
        );
        return pod;
    }

    def _create_service(sandbox_id: str, namespace: str) -> str {
        import from kubernetes { client }
        core_v1 = client.CoreV1Api();
        svc_name = f"{sandbox_id}-svc";

        svc = client.V1Service(
            metadata=client.V1ObjectMeta(
                name=svc_name,
                namespace=namespace,
                labels={_SANDBOX_LABEL: "true", "jac-sandbox-id": sandbox_id}
            ),
            spec=client.V1ServiceSpec(
                selector={"jac-sandbox-id": sandbox_id},
                ports=[
                    client.V1ServicePort(
                        port=_INTERNAL_PORT, target_port=_INTERNAL_PORT, protocol="TCP"
                    )
                ],
                type="ClusterIP"
            )
        );
        core_v1.create_namespaced_service(namespace, svc);
        return svc_name;
    }

    def _build_warm_pod_spec(pod_name: str) -> Any {
        import from kubernetes { client }

        security_context = None;
        if self.config.security_context_enabled {
            security_context = client.V1SecurityContext(
                run_as_non_root=True,
                run_as_user=1000,
                read_only_root_filesystem=False,
                allow_privilege_escalation=False,
                capabilities=client.V1Capabilities(drop=["ALL"]),
                seccomp_profile=client.V1SeccompProfile(type="RuntimeDefault")
            );
        }

        resources = client.V1ResourceRequirements(
            limits={"cpu": self.config.cpu_limit, "memory": self.config.memory_limit},
            requests={"cpu": "100m", "memory": "64Mi"}
        );

        main_container = client.V1Container(
            name="sandbox",
            image=self.config.base_image,
            command=[
                "bash",
                "-c",
                "while [ ! -f /app/.jac-start ]; do sleep 0.5; done; "
                f"cd /app && jac install 2>/dev/null; "
                f"jac start main.jac -p {_INTERNAL_PORT} --dev"
            ],
            ports=[client.V1ContainerPort(container_port=_INTERNAL_PORT)],
            resources=resources,
            security_context=security_context,
            volume_mounts=[
                client.V1VolumeMount(name="app-data", mount_path="/app"),
                client.V1VolumeMount(name="tmp-scratch", mount_path="/tmp")
            ],
            env=[
                client.V1EnvVar(name="JAC_SANDBOX_ID", value="warm-pool"),
                client.V1EnvVar(name="CHOKIDAR_USEPOLLING", value="1"),
                client.V1EnvVar(name="WATCHPACK_POLLING", value="true")
            ]
        );

        volumes = [
            client.V1Volume(
                name="app-data",
                empty_dir=client.V1EmptyDirVolumeSource(
                    size_limit=self.config.app_storage_limit
                )
            ),
            client.V1Volume(
                name="tmp-scratch",
                empty_dir=client.V1EmptyDirVolumeSource(
                    size_limit=self.config.storage_limit
                )
            )
        ];

        warm_ttl = self.config.warm_pool_ttl if self.config.warm_pool_ttl > 0 else None;
        pod = client.V1Pod(
            metadata=client.V1ObjectMeta(
                name=pod_name,
                namespace=self.config.namespace,
                labels={_SANDBOX_LABEL: "true", "jac-sandbox-pool": "warm"}
            ),
            spec=client.V1PodSpec(
                containers=[main_container],
                volumes=volumes,
                restart_policy="Never",
                active_deadline_seconds=warm_ttl,
                termination_grace_period_seconds=10,
                automount_service_account_token=False
            )
        );
        return pod;
    }

    def _ensure_warm_pool -> None {
        if self.config.warm_pool_size <= 0 {
            return;
        }
        try {
            import from kubernetes { client }
            core_v1 = client.CoreV1Api();
            namespace = self.config.namespace;

            # List existing warm pods
            existing = core_v1.list_namespaced_pod(
                namespace,
                label_selector=f"{_SANDBOX_LABEL}=true,jac-sandbox-pool=warm"
            );
            warm_count = 0;
            for p in existing.items {
                if p.status.phase in ["Pending", "Running"] {
                    warm_count += 1;
                    # Track in our pool list
                    pn = p.metadata.name;
                    self._lock.acquire();
                    try {
                        if pn not in self._warm_pool {
                            self._warm_pool.append(pn);
                        }
                    } finally {
                        self._lock.release();
                    }
                }
            }

            # Create pods to reach target size
            needed = self.config.warm_pool_size - warm_count;
            for i in range(needed) {
                pod_name = f"jac-warm-{str(uuid.uuid4())[:8]}";
                pod_spec = self._build_warm_pod_spec(pod_name);
                core_v1.create_namespaced_pod(namespace, pod_spec);
                self._lock.acquire();
                try {
                    self._warm_pool.append(pod_name);
                } finally {
                    self._lock.release();
                }
                if self.logger {
                    self.logger.info(f"Created warm pool pod: {pod_name}");
                }
            }
            self._pool_initialized = True;
        } except Exception as e {
            if self.logger {
                self.logger.warn(f"Warm pool error: {str(e)}");
            }
        }
    }

    def _claim_warm_pod(sandbox_id: str, user_id: str, project_id: str) -> (str | None) {
        self._lock.acquire();
        try {
            if not self._warm_pool {
                return None;
            }
            pod_name = self._warm_pool.pop(0);
        } finally {
            self._lock.release();
        }

        try {
            import from kubernetes { client }
            core_v1 = client.CoreV1Api();
            namespace = self.config.namespace;

            # Verify pod is still running
            pod = core_v1.read_namespaced_pod_status(pod_name, namespace);
            if pod.status.phase not in ["Pending", "Running"] {
                return None;
            }

            # Relabel pod from warm → active
            body = {
                "metadata": {
                    "labels": {
                        _SANDBOX_LABEL: "true",
                        "jac-sandbox-id": sandbox_id,
                        "jac-sandbox-pool": "active",
                        "jac-sandbox-user": user_id,
                        "jac-sandbox-project": project_id
                    }
                }
            };
            core_v1.patch_namespaced_pod(pod_name, namespace, body);
            return pod_name;
        } except Exception as e {
            if self.logger {
                self.logger.warn(f"Failed to claim warm pod {pod_name}: {str(e)}");
            }
            return None;
        }
    }

    def _inject_code(pod_name: str, code_path: str) -> bool {
        import from kubernetes { client }
        import from kubernetes.stream { stream }
        core_v1 = client.CoreV1Api();
        namespace = self.config.namespace;

        if not os.path.isdir(code_path) {
            return False;
        }

        try {
            import tarfile;
            import io;

            skip_dirs = {".jac","node_modules","__pycache__","dist",".git"};
            tar_buffer = io.BytesIO();

            with tarfile.open(fileobj=tar_buffer, mode="w:gz") as tar {
                for walk_rec in os.walk(code_path) {
                    dirpath: Any = walk_rec[0];
                    dirnames: Any = walk_rec[1];
                    filenames: Any = walk_rec[2];
                    # Filter out skip dirs
                    kept = [
                        d
                        for d in dirnames
                        if d not in skip_dirs
                    ];
                    dirnames.clear();
                    for d in kept {
                        dirnames.append(d);
                    }
                    for fname in filenames {
                        full = os.path.join(str(dirpath), str(fname));
                        arcname = os.path.relpath(full, code_path);
                        try {
                            tar.add(full, arcname=arcname);
                        } except Exception {
                            ;  # Skip files that can't be read
                        }
                    }
                }
            }

            tar_data = tar_buffer.getvalue();

            # Pipe tar into pod via exec
            import base64;
            encoded = str(base64.b64encode(tar_data).decode("ascii"));

            # Split into chunks to avoid command-line length limits
            chunk_size = 65536;
            chunks = [
                encoded[i:i + chunk_size] for i in range(0, len(encoded), chunk_size)
            ];

            # Write chunks to a temp file inside the pod, then extract
            stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=["sh", "-c", "rm -f /tmp/code.tar.gz"],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );

            for chunk in chunks {
                stream(
                    core_v1.connect_get_namespaced_pod_exec,
                    pod_name,
                    namespace,
                    container="sandbox",
                    command=["sh", "-c", f"echo -n '{chunk}' >> /tmp/code.b64"],
                    stderr=True,
                    stdout=True,
                    stdin=False,
                    tty=False
                );
            }

            # Decode and extract
            stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=[
                    "sh",
                    "-c",
                    "base64 -d /tmp/code.b64 > /tmp/code.tar.gz && "
                    "tar xzf /tmp/code.tar.gz -C /app && "
                    "rm -f /tmp/code.b64 /tmp/code.tar.gz"
                ],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );

            if self.logger {
                self.logger.info(
                    f"Injected code into pod {pod_name} "
                    f"({len(tar_data)} bytes compressed)"
                );
            }
            return True;
        } except Exception as e {
            if self.logger {
                self.logger.warn(f"Code injection failed for {pod_name}: {str(e)}");
            }
            return False;
        }
    }

    def _signal_start(pod_name: str) {
        import from kubernetes { client }
        import from kubernetes.stream { stream }
        core_v1 = client.CoreV1Api();
        namespace = self.config.namespace;
        stream(
            core_v1.connect_get_namespaced_pod_exec,
            pod_name,
            namespace,
            container="sandbox",
            command=["touch", "/app/.jac-start"],
            stderr=True,
            stdout=True,
            stdin=False,
            tty=False
        );
    }

    def _poll_pod_readiness(sandbox_id: str) {
        import from kubernetes { client }
        core_v1 = client.CoreV1Api();
        namespace = self.config.namespace;
        start_time = time.time();
        ready = False;

        # Warm pods have a different pod name than sandbox_id
        rec: Any = self._registry.get(sandbox_id);
        pod_name = sandbox_id;
        if rec {
            rec_d_init: dict = dict(rec);
            pod_name = str(rec_d_init.get("pod_name", sandbox_id));
        }

        while time.time() - start_time < 120 {
            try {
                pod = core_v1.read_namespaced_pod_status(pod_name, namespace);
                phase = pod.status.phase;
                if phase == "Running" {
                    # Check container readiness
                    container_statuses = pod.status.container_statuses or [];
                    for cs in container_statuses {
                        if cs.name == "sandbox" and cs.ready {
                            ready = True;
                            break;
                        }
                    }
                    if ready {
                        break;
                    }
                    # Even if not marked ready, if Running, check logs
                    try {
                        log_content = str(
                            core_v1.read_namespaced_pod_log(
                                pod_name, namespace, container="sandbox", tail_lines=50
                            )
                        );
                        if "Server ready" in log_content {
                            ready = True;
                            break;
                        }
                    } except Exception {
                        ;
                    }
                } elif phase in ["Failed", "Succeeded"] {
                    break;
                }
            } except Exception {
                ;
            }
            time.sleep(3);
        }

        self._lock.acquire();
        try {
            rec_inner: Any = self._registry.get(sandbox_id);
            if rec_inner {
                rec_inner["status"] = SandboxState.RUNNING
                    if ready
                    else SandboxState.ERROR;
            }
        } finally {
            self._lock.release();
        }
    }

    def create(user_id: str, project_id: str, code_path: str) -> SandboxResult {
        try {
            self._init_k8s();
            self._ensure_namespace();
            self._ensure_rbac();
        } except Exception as e {
            return SandboxResult(
                success=False, message=f"K8s initialization failed: {str(e)}"
            );
        }

        # Start background cleanup on first use
        self._start_cleanup_loop();

        # Bootstrap warm pool on first use
        if self.config.warm_pool_size > 0 and not self._pool_initialized {
            replenish = Thread(target=self._ensure_warm_pool, daemon=True);
            replenish.start();
        }

        # Enforce max_per_user
        self._lock.acquire();
        try {
            user_count = 0;
            for (sid, rec) in self._registry.items() {
                rec_d: dict = dict(rec);
                if str(rec_d.get("user_id", "")) == user_id
                and rec_d.get("status") not in [
                    SandboxState.STOPPED,
                    SandboxState.ERROR
                ] {
                    user_count += 1;
                }
            }
            if user_count >= self.config.max_per_user {
                return SandboxResult(
                    success=False,
                    message=f"Max sandboxes per user ({self.config.max_per_user}) reached"
                );
            }
        } finally {
            self._lock.release();
        }

        import from kubernetes { client }
        core_v1 = client.CoreV1Api();
        namespace = self.config.namespace;
        sandbox_id = self._generate_id(user_id, project_id);

        # --- Warm start path ---
        if self.config.warm_pool_size > 0 {
            claimed_pod = self._claim_warm_pod(sandbox_id, user_id, project_id);
            if claimed_pod {
                try {
                    # Inject code into the warm pod
                    injected = self._inject_code(claimed_pod, code_path);
                    if not injected {
                        self._cleanup_k8s_resources(sandbox_id, namespace);
                        return SandboxResult(
                            success=False,
                            message="Failed to inject code into warm pod"
                        );
                    }

                    # Signal the pod to start
                    self._signal_start(claimed_pod);

                    # Get URL via ingress provider
                    ingress = self._get_ingress_provider();
                    svc_name = "";
                    if not self.config.proxy_mode {
                        svc_name = self._create_service(sandbox_id, namespace);
                    }
                    url = ingress.create_route(
                        sandbox_id,
                        svc_name,
                        _INTERNAL_PORT,
                        namespace,
                        {
                            "domain_template": self.config.domain_template,
                            "ingress_class": self.config.ingress_class,
                            "tls_enabled": self.config.tls_enabled,
                            "tls_issuer": self.config.tls_issuer,
                            "ingress_annotations": self.config.ingress_annotations
                        }
                    );

                    # Register
                    self._lock.acquire();
                    try {
                        self._registry[sandbox_id] = {
                            "sandbox_id": sandbox_id,
                            "user_id": user_id,
                            "project_id": project_id,
                            "pod_name": claimed_pod,
                            "namespace": namespace,
                            "status": SandboxState.STARTING,
                            "url": url,
                            "port": _INTERNAL_PORT,
                            "created_at": time.time(),
                            "warm_start": True
                        };
                    } finally {
                        self._lock.release();
                    }

                    # Poll readiness in background
                    checker = Thread(
                        target=self._poll_pod_readiness,
                        args=(sandbox_id, ),
                        daemon=True
                    );
                    checker.start();

                    # Replenish pool in background
                    replenish = Thread(target=self._ensure_warm_pool, daemon=True);
                    replenish.start();

                    if self.logger {
                        self.logger.info(
                            f"Warm start: {sandbox_id} on pod {claimed_pod}"
                        );
                    }

                    return SandboxResult(
                        success=True,
                        sandbox_id=sandbox_id,
                        url=url,
                        port=_INTERNAL_PORT,
                        message="warm-starting"
                    );
                } except Exception as e {
                    self._cleanup_k8s_resources(sandbox_id, namespace);
                    return SandboxResult(success=False, message=str(e));
                }
            }
        }

        # --- Cold start path ---
        try {
            # 1. Create ConfigMap with project code
            cm_name = self._create_configmap(sandbox_id, code_path, namespace);

            # 2. Create Pod
            pod_spec = self._build_pod_spec(sandbox_id, cm_name, user_id, project_id);
            core_v1.create_namespaced_pod(namespace, pod_spec);

            # 3. Create Service (skip in proxy mode)
            svc_name = "";
            if not self.config.proxy_mode {
                svc_name = self._create_service(sandbox_id, namespace);
            }

            # 4. Create Ingress route
            ingress = self._get_ingress_provider();
            url = ingress.create_route(
                sandbox_id,
                svc_name,
                _INTERNAL_PORT,
                namespace,
                {
                    "domain_template": self.config.domain_template,
                    "ingress_class": self.config.ingress_class,
                    "tls_enabled": self.config.tls_enabled,
                    "tls_issuer": self.config.tls_issuer,
                    "ingress_annotations": self.config.ingress_annotations
                }
            );

            # 5. Register
            self._lock.acquire();
            try {
                self._registry[sandbox_id] = {
                    "sandbox_id": sandbox_id,
                    "user_id": user_id,
                    "project_id": project_id,
                    "pod_name": sandbox_id,
                    "configmap": cm_name,
                    "namespace": namespace,
                    "status": SandboxState.STARTING,
                    "url": url,
                    "port": _INTERNAL_PORT,
                    "created_at": time.time(),
                    "warm_start": False
                };
            } finally {
                self._lock.release();
            }

            # 6. Poll readiness in background
            checker = Thread(
                target=self._poll_pod_readiness, args=(sandbox_id, ), daemon=True
            );
            checker.start();

            return SandboxResult(
                success=True,
                sandbox_id=sandbox_id,
                url=url,
                port=_INTERNAL_PORT,
                message="cold-starting"
            );
        } except Exception as e {
            # Clean up on failure
            self._cleanup_k8s_resources(sandbox_id, namespace);
            return SandboxResult(success=False, message=str(e));
        }
    }

    def _cleanup_k8s_resources(sandbox_id: str, namespace: str) {
        import from kubernetes { client }
        import from kubernetes.client.exceptions { ApiException }
        core_v1 = client.CoreV1Api();

        # Find actual pod name (warm pods have different names)
        rec: Any = self._registry.get(sandbox_id);
        pod_name = sandbox_id;
        if rec {
            rec_d: dict = dict(rec);
            pod_name = str(rec_d.get("pod_name", sandbox_id));
        }

        # Delete pod
        try {
            core_v1.delete_namespaced_pod(pod_name, namespace);
        } except ApiException {
            ;
        }
        # Delete service (skip in proxy mode — no per-sandbox service)
        if not self.config.proxy_mode {
            try {
                core_v1.delete_namespaced_service(f"{sandbox_id}-svc", namespace);
            } except ApiException {
                ;
            }
        }
        # Delete configmap (skip for warm pods — no configmap)
        rec_cleanup: dict = dict(rec) if rec else {};
        if not (rec and rec_cleanup.get("warm_start")) {
            try {
                core_v1.delete_namespaced_config_map(f"{sandbox_id}-code", namespace);
            } except ApiException {
                ;
            }
        }
        # Delete ingress
        try {
            ingress = self._get_ingress_provider();
            ingress.delete_route(sandbox_id, namespace);
        } except Exception {
            ;
        }
    }

    def stop(sandbox_id: str) {
        self._init_k8s();
        rec: Any = self._registry.get(sandbox_id);
        namespace = self.config.namespace;
        if rec {
            rec_d: dict = dict(rec);
            namespace = str(rec_d.get("namespace", self.config.namespace));
        }
        self._cleanup_k8s_resources(sandbox_id, namespace);
        self._lock.acquire();
        try {
            if sandbox_id in self._registry {
                self._registry[sandbox_id]["status"] = SandboxState.STOPPED;
            }
        } finally {
            self._lock.release();
        }
    }

    def status(sandbox_id: str) -> SandboxStatus {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return SandboxStatus(state=SandboxState.STOPPED, sandbox_id=sandbox_id);
        }
        rec_d: dict = dict(rec);
        # Check actual pod status
        try {
            self._init_k8s();
            import from kubernetes { client }
            core_v1 = client.CoreV1Api();
            pod_name = self._get_pod_name(sandbox_id);
            pod = core_v1.read_namespaced_pod_status(
                pod_name, str(rec_d.get("namespace", self.config.namespace))
            );
            phase = str(pod.status.phase);
            if phase == "Running" {
                state: Any = SandboxState.RUNNING;
            } elif phase == "Pending" {
                state = SandboxState.STARTING;
            } elif phase in ["Failed", "Unknown"] {
                state = SandboxState.ERROR;
            } else {
                state = SandboxState.STOPPED;
            }
        } except Exception as e {
            console.print(f"[sandbox-status] Pod query failed for {sandbox_id}: {e}");
            state = SandboxState.STOPPED;
        }
        created_at = float(rec_d.get("created_at", time.time()));
        uptime = time.time() - created_at if state == SandboxState.RUNNING else 0.0;
        return SandboxStatus(
            state=state,
            sandbox_id=sandbox_id,
            uptime_seconds=uptime,
            url=str(rec_d.get("url", "")),
            port=int(rec_d.get("port", 0))
        );
    }

    def destroy(sandbox_id: str) {
        self.stop(sandbox_id);
        self._lock.acquire();
        try {
            self._registry.pop(sandbox_id, None);
        } finally {
            self._lock.release();
        }
    }

    def list_sandboxes(user_id: str) -> list[SandboxInfo] {
        results: list[SandboxInfo] = [];
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("user_id", "")) == user_id {
                state_val: Any = rec_d.get("status", SandboxState.STOPPED);
                results.append(
                    SandboxInfo(
                        sandbox_id=sid,
                        user_id=str(rec_d.get("user_id", "")),
                        project_id=str(rec_d.get("project_id", "")),
                        state=state_val,
                        url=str(rec_d.get("url", "")),
                        created_at=float(rec_d.get("created_at", 0.0))
                    )
                );
            }
        }
        return results;
    }

    def _start_cleanup_loop -> None {
        if self._cleanup_started {
            return;
        }
        self._cleanup_started = True;
        thread = Thread(target=self._cleanup_loop, daemon=True);
        thread.start();
        if self.logger {
            self.logger.info(
                f"Started cleanup loop (interval=60s, ttl={self.config.ttl_seconds}s)"
            );
        }
    }

    def _cleanup_loop {
        while True {
            time.sleep(60);
            try {
                self.cleanup_expired();
            } except Exception {
                ;
            }
        }
    }

    def _find_registry_key(pod_name: str) -> (str | None) {
        if pod_name in self._registry {
            return pod_name;
        }
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("pod_name", "")) == pod_name {
                return sid;
            }
        }
        return None;
    }

    def cleanup_expired -> int {
        self._init_k8s();
        import from kubernetes { client }
        import from kubernetes.client.exceptions { ApiException }
        core_v1 = client.CoreV1Api();
        namespace = self.config.namespace;

        try {
            pods = core_v1.list_namespaced_pod(
                namespace, label_selector=f"{_SANDBOX_LABEL}=true"
            );
        } except Exception {
            return 0;
        }

        now = time.time();
        import from datetime { timezone }
        live_pod_names: set = set();
        pods_to_delete: list[str] = [];
        cleaned = 0;

        # Phase 1: Identify expired or terminal pods
        for pod in pods.items {
            pod_name = str(pod.metadata.name);
            phase = str(pod.status.phase) if pod.status else "Unknown";
            is_terminal = phase in ["Failed", "Succeeded"];
            is_expired = False;

            # Warm pods with ttl=0 never expire from age-based cleanup
            is_warm = pod.metadata.labels.get("jac-sandbox-pool") == "warm"
                if pod.metadata.labels
                else False;
            if is_warm and self.config.warm_pool_ttl <= 0 {
                if not is_terminal {
                    live_pod_names.add(pod_name);
                    continue;
                }
            }

            created: Any = pod.metadata.creation_timestamp;
            if created {
                age = now - created.replace(tzinfo=timezone.utc).timestamp();
                ttl = self.config.warm_pool_ttl
                    if (is_warm and self.config.warm_pool_ttl > 0)
                    else self.config.ttl_seconds;
                is_expired = age > ttl;
            }
            if is_terminal or is_expired {
                pods_to_delete.append(pod_name);
            } else {
                live_pod_names.add(pod_name);
            }
        }

        # Phase 2: Delete pods and their associated K8s resources
        for pod_name in pods_to_delete {
            registry_key = self._find_registry_key(pod_name);
            if registry_key {
                self._cleanup_k8s_resources(registry_key, namespace);
                self._lock.acquire();
                try {
                    self._registry.pop(registry_key, None);
                } finally {
                    self._lock.release();
                }
            } else {
                try {
                    core_v1.delete_namespaced_pod(pod_name, namespace);
                } except ApiException {
                    ;
                }
            }
            self._lock.acquire();
            try {
                if pod_name in self._warm_pool {
                    self._warm_pool.remove(pod_name);
                }
            } finally {
                self._lock.release();
            }
            cleaned += 1;
        }

        # Phase 3: Purge registry/warm-pool entries whose pods no longer exist
        self._lock.acquire();
        try {
            stale_keys = [
                sid
                for (sid, rec) in self._registry.items()
                if str(dict(rec).get("pod_name", sid)) not in live_pod_names
            ];
            for key in stale_keys {
                self._registry.pop(key, None);
                cleaned += 1;
            }
            self._warm_pool = [
                p
                for p in self._warm_pool
                if p in live_pod_names
            ];
        } finally {
            self._lock.release();
        }

        if cleaned > 0 and self.logger {
            self.logger.info(f"Cleanup: removed {cleaned} stale sandboxes/pods");
        }
        return cleaned;
    }

    def logs(sandbox_id: str, offset: int = 0) -> dict {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);
            log_content = str(
                core_v1.read_namespaced_pod_log(
                    pod_name, namespace, container="sandbox"
                )
            );
            if offset > 0 {
                if offset >= len(log_content) {
                    return {"success": True, "content": "", "offset": offset};
                }
                log_content = log_content[offset:];
            }
            new_offset = offset + len(log_content);
            return {"success": True, "content": log_content, "offset": new_offset};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def write_file(sandbox_id: str, path: str, content: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            import from kubernetes.stream { stream }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);

            # Ensure parent directory exists
            parent_dir = os.path.dirname(path);
            if parent_dir {
                stream(
                    core_v1.connect_get_namespaced_pod_exec,
                    pod_name,
                    namespace,
                    container="sandbox",
                    command=["mkdir", "-p", f"/app/{parent_dir}"],
                    stderr=True,
                    stdout=True,
                    stdin=False,
                    tty=False
                );
            }

            # Write file content via exec
            # Use base64 encoding to safely transfer content
            import base64;
            encoded = str(base64.b64encode(content.encode("utf-8")).decode("utf-8"));
            stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=["sh", "-c", f"echo '{encoded}' | base64 -d > /app/{path}"],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );
            return {"success": True, "path": path};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def read_file(sandbox_id: str, path: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            import from kubernetes.stream { stream }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);
            result = stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=["cat", f"/app/{path}"],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );
            return {"success": True, "path": path, "content": result};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def delete_file(sandbox_id: str, path: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            import from kubernetes.stream { stream }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);
            stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=["rm", "-rf", f"/app/{path}"],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );
            return {"success": True, "path": path};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def list_files(sandbox_id: str, path: str = ".") -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            import from kubernetes.stream { stream }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);
            result = stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=[
                    "find",
                    f"/app/{path}",
                    "-type",
                    "f",
                    "-not",
                    "-path",
                    "*/node_modules/*",
                    "-not",
                    "-path",
                    "*/.jac/*",
                    "-not",
                    "-path",
                    "*/__pycache__/*",
                    "-not",
                    "-path",
                    "*/dist/*"
                ],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );
            files = [
                os.path.relpath(str(f).strip(), "/app")
                for f in str(result).strip().split("\n")
                if str(f).strip()
            ];
            files.sort();
            return {"success": True, "files": files};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def exec_command(sandbox_id: str, command: str, timeout: int = 30) -> dict {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            self._init_k8s();
            import from kubernetes { client }
            import from kubernetes.stream { stream }
            core_v1 = client.CoreV1Api();
            namespace = str(rec_d.get("namespace", self.config.namespace));
            pod_name = self._get_pod_name(sandbox_id);
            result = stream(
                core_v1.connect_get_namespaced_pod_exec,
                pod_name,
                namespace,
                container="sandbox",
                command=["bash", "-c", command],
                stderr=True,
                stdout=True,
                stdin=False,
                tty=False
            );
            return {"success": True, "exit_code": 0, "stdout": result, "stderr": ""};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    # ---- Convenience methods for preview_manager compatibility ----
    def get_sandbox_id(user_id: str, project_id: str) -> (str | None) {
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("user_id", "")) == user_id
            and str(rec_d.get("project_id", "")) == project_id {
                return sid;
            }
        }
        return None;
    }
}
# 1MB
