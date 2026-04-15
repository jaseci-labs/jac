"""Kubernetes deployment target implementation."""
import from typing { Any }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.resource_status {
    ResourceStatus,
    ResourceStatusInfo
}
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    COMPANION_DEFS,
    check_deployment_status,
    check_node_ports_available,
    cluster_type,
    create_k8s_secret,
    delete_k8s_secret,
    delete_if_exists,
    delete_namespace,
    check_K8s_status,
    ensure_namespace_exists,
    ensure_pvc_exists,
    load_env_variables,
    validate_resource_limits,
    sync_code_to_pvc
}
import from jac_scale.providers.registry.dockerhub { DockerHubRegistry }
import from jac_scale.providers.database.kubernetes_mongo { KubernetesMongoProvider }
import from jac_scale.providers.database.kubernetes_redis { KubernetesRedisProvider }
import from jac_scale._optdeps.optional_deps { require_optional }
import from jac_scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException
}
import from jac_scale.factories.database_factory { DatabaseProviderFactory }
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
import from jac_scale.targets.kubernetes.monitoring { MonitoringDeployer }
import from jac_scale.targets.kubernetes.ingress { IngressDeployer }
import from jac_scale.targets.kubernetes.hpa.hpa { create_hpa }
import time;

"""Kubernetes deployment target implementation."""
obj KubernetesTarget(DeploymentTarget) {
    has config: KubernetesConfig,
        logger: (Logger | None) = None,
        k8s_config: KubernetesConfig by postinit,
        env_list: list = [],
        secrets: dict[str, str] = {};

    def postinit {
        self.k8s_config = self.config;
    }

    """Get init containers from all enabled database providers."""
    def _get_database_init_containers(app_name: str) -> list[dict[(str, Any)]] {
        init_containers = [];
        wait_image = self.k8s_config.wait_image;

        if self.k8s_config.mongodb_enabled {
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            init_container = mongo_provider.get_init_container(app_name, wait_image);
            if init_container {
                init_containers.append(init_container);
            }
        }

        if self.k8s_config.redis_enabled {
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            init_container = redis_provider.get_init_container(app_name, wait_image);
            if init_container {
                init_containers.append(init_container);
            }
        }

        return init_containers;
    }

    """Build resource requests and limits configuration."""
    def _build_resource_config -> dict[(str, Any)] {
        resource_requests: dict[(str, str)] = {};
        if self.k8s_config.cpu_request {
            resource_requests['cpu'] = self.k8s_config.cpu_request;
        }
        if self.k8s_config.memory_request {
            resource_requests['memory'] = self.k8s_config.memory_request;
        }

        resource_limits: dict[(str, str)] = {};
        if self.k8s_config.cpu_limit {
            resource_limits['cpu'] = self.k8s_config.cpu_limit;
        }
        if self.k8s_config.memory_limit {
            resource_limits['memory'] = self.k8s_config.memory_limit;
        }

        resources: dict[(str, dict)] = {};
        if resource_requests {
            resources['requests'] = resource_requests;
        }
        if resource_limits {
            resources['limits'] = resource_limits;
        }

        return resources;
    }

    """Build readiness and liveness probe configurations."""
    def _build_probe_config(health_check_path: str) -> dict[(str, Any)] {
        probe_config = {
            'httpGet': {
                'path': health_check_path,
                'port': self.k8s_config.container_port,
                'scheme': 'HTTP'
            },
            'initialDelaySeconds': self.k8s_config.readiness_initial_delay,
            'periodSeconds': self.k8s_config.readiness_period
        };

        liveness_probe = dict(probe_config);
        liveness_probe['initialDelaySeconds'] = self.k8s_config.liveness_initial_delay;
        liveness_probe['periodSeconds'] = self.k8s_config.liveness_period;
        liveness_probe['failureThreshold'] = self.k8s_config.liveness_failure_threshold;

        return {'readiness': probe_config, 'liveness': liveness_probe};
    }

    """Build Kubernetes service configuration.

    Always ClusterIP — the app is reached exclusively through the NGINX Ingress
    controller, so no direct NodePort or cloud LoadBalancer is needed.
    """
    def _build_service_config(
        app_name: str, cluster_env: str, health_check_path: str
    ) -> dict[(str, Any)] {
        service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{app_name}-service",
                'namespace': self.k8s_config.namespace,
                'labels': {'app': app_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'ports': [
                    {
                        'protocol': 'TCP',
                        'port': self.k8s_config.container_port,
                        'targetPort': self.k8s_config.container_port
                    }
                ],
                'selector': {'app': app_name}
            }
        };

        return service;
    }

    """Build the bash command for setting up Jaseci runtime environment."""
    def _build_runtime_setup_command(app_config: AppConfig) -> list[str] {
        config = self.k8s_config;
        commands = [];

        # Base setup
        commands.append('export DEBIAN_FRONTEND=noninteractive');
        # Disable apt sandbox: CAP_SETUID/CAP_SETGID are dropped in the container
        # security context, so apt cannot drop privileges to the _apt user.
        commands.append(
            'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/00sandbox'
        );
        # Remove repos that don't exist yet on Debian testing (trixie) to prevent
        # apt-get update from failing with "no Release file" errors.
        commands.append(
            'sed -i \'/trixie-updates\\|trixie-security/d\' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true'
        );
        commands.append('apt-get update');

        # Install base packages (curl and unzip needed for Bun installation)
        base_packages = ['git', 'curl', 'unzip'];
        if config.additional_packages {
            base_packages.extend(config.additional_packages);
        }
        commands.append(f"apt-get install -y {' '.join(base_packages)}");

        # Install Bun (required for jac-client frontend builds)
        commands.append('curl -fsSL https://bun.sh/install | bash');
        commands.append('export BUN_INSTALL="$HOME/.bun"');
        commands.append('export PATH="$BUN_INSTALL/bin:$PATH"');

        if app_config.experimental {
            commands.append('rm -rf jaseci');
            clone_cmd = f"git clone --branch {config.jaseci_branch} --single-branch {config.jaseci_repo_url}";
            commands.append(clone_cmd);
            commands.append('cd ./jaseci');
            if config.jaseci_commit {
                commands.append(f"git checkout {config.jaseci_commit}");
            }
            commands.append('git submodule update --init --recursive');
            commands.append('pip install pluggy');
            commands.append('pip install -e ./jac');
            commands.append('pip install -e "./jac-scale[all]"');
            commands.append('pip install -e ./jac-client');
            commands.append('pip install -e ./jac-byllm');
            commands.append('pip install -e ./jac-mcp');
            commands.append('cd ..');
        } else {
            packages = config.plugin_versions or {};
            jaclang_v = packages.get('jaclang', 'latest');
            scale_v = packages.get('jac_scale', 'latest');
            client_v = packages.get('jac_client', 'latest');
            byllm_v = packages.get('jac_byllm', 'latest');
            mcp_v = packages.get('jac_mcp', 'latest');
            if jaclang_v == 'latest' {
                commands.append('pip install jaclang');
            } else {
                commands.append(f'pip install jaclang=={jaclang_v}');
            }
            if scale_v == 'latest' {
                commands.append('pip install "jac-scale[all]"');
            } else {
                commands.append(f'pip install "jac-scale[all]=={scale_v}"');
            }
            if client_v == 'latest' {
                commands.append('pip install jac-client');
            } else {
                commands.append(f'pip install jac-client=={client_v}');
            }
            if byllm_v and byllm_v != 'none' {
                if byllm_v == 'latest' {
                    commands.append('pip install byllm');
                } else {
                    commands.append(f'pip install byllm=={byllm_v}');
                }
            }
            if mcp_v and mcp_v != 'none' {
                if mcp_v == 'latest' {
                    commands.append('pip install jac-mcp');
                } else {
                    commands.append(f'pip install jac-mcp=={mcp_v}');
                }
            }
        }

        # Change to app directory (project is already copied there via volume mount)
        commands.append(f"cd {config.app_mount_path}");

        # Install requirements
        commands.append('jac install');

        # Pre-compile all jac-scale .jac modules so lazy imports have bytecode at runtime
        commands.append(
            "printf 'import from jac_scale.factories.sandbox_factory { SandboxFactory }\\nimport from jac_scale.providers.sandbox.kubernetes_sandbox { KubernetesSandbox }\\nimport from jac_scale.providers.sandbox.local_sandbox { LocalSandbox }\\nimport from jac_scale.providers.sandbox.docker_sandbox { DockerSandbox }\\n' > /tmp/_precompile.jac && jac run /tmp/_precompile.jac > /dev/null 2>&1 || true"
        );

        # Start the application
        commands.append(f"jac start {app_config.file_name}");

        # Join all commands
        full_command = ' && '.join(commands);

        return ['bash', '-c', full_command];
    }

    """Build container configuration."""
    def _build_container_config(
        app_name: str,
        image: str,
        probe_configs: dict[(str, Any)],
        resources_config: dict[(str, Any)],
        command: (list[str] | None) = None,
        working_dir: (str | None) = None,
        volume_mounts: (list[dict[(str, Any)]] | None) = None,
        secret_ref_name: (str | None) = None,
        needs_root: bool = False
    ) -> dict[(str, Any)] {
        # Containers that install packages at runtime (apt-get, pip) need root
        # and a writable filesystem. Pre-built image containers can be fully locked down.
        if needs_root {
            # Drop ALL then add back only what apt/pip need at runtime:
            #   CHOWN       — chown files during package post-install scripts
            #   DAC_OVERRIDE — access _apt-owned /var/lib/apt/lists/partial/
            #   FOWNER      — chmod directories not owned by the running uid
            #   FSETID      — preserve SUID/SGID bits written by package scripts
            #   SETUID/SETGID — some package post-install scripts switch uid/gid
            security_context = {
                'readOnlyRootFilesystem': False,
                'allowPrivilegeEscalation': False,
                'capabilities': {
                    'drop': ['ALL'],
                    'add': [
                        'CHOWN',
                        'DAC_OVERRIDE',
                        'FOWNER',
                        'FSETID',
                        'SETUID',
                        'SETGID'
                    ]
                },
                'seccompProfile': {'type': 'RuntimeDefault'}
            };
        } else {
            security_context = {
                'runAsNonRoot': True,
                'runAsUser': 1000,
                'readOnlyRootFilesystem': True,
                'allowPrivilegeEscalation': False,
                'capabilities': {'drop': ['ALL']},
                'seccompProfile': {'type': 'RuntimeDefault'}
            };
        }
        container_config = {
            'name': app_name,
            'image': image,
            'securityContext': security_context,
            'ports': [{'containerPort': self.k8s_config.container_port}],
            'env': self.env_list,
            'readinessProbe': probe_configs['readiness'],
            'livenessProbe': probe_configs['liveness']
        };

        if secret_ref_name {
            container_config['envFrom'] = [{'secretRef': {'name': secret_ref_name}}];
        }
        if command {
            container_config['command'] = command;
        }
        if working_dir {
            container_config['workingDir'] = working_dir;
        }
        if volume_mounts {
            container_config['volumeMounts'] = volume_mounts;
        }
        if resources_config {
            container_config['resources'] = resources_config;
        }

        return container_config;
    }

    """Build volumes and build container configuration for code sync via code-server."""
    def _build_volumes_config(
        app_name: str, app_config: AppConfig, namespace: str, core_v1: Any, apps_v1: Any
    ) -> dict[str, Any] {
        pvc_name = f"{app_name}-code-pvc";
        pvc_size = self.k8s_config.pvc_size;
        sync_image = self.k8s_config.busybox_image;

        ensure_pvc_exists(core_v1, namespace, pvc_name, pvc_size);
        if self.logger {
            self.logger.info('Syncing application code to PVC');
        }
        sync_code_to_pvc(
            core_v1, namespace, pvc_name, app_config.code_folder, app_name, sync_image
        );

        # Deploy code-server to serve code from PVC over HTTP
        self._deploy_code_server(app_name, namespace, apps_v1, core_v1);

        # Init container fetches code from code-server via wget (no PVC mount needed)
        code_server_url = f"http://{app_name}-code-server:8080/code.tar.gz";
        build_container = {
            'name': 'build-app',
            'image': self.k8s_config.busybox_image,
            'securityContext': {
                'runAsNonRoot': True,
                'runAsUser': 1000,
                'readOnlyRootFilesystem': False,
                'allowPrivilegeEscalation': False,
                'capabilities': {'drop': ['ALL']},
                'seccompProfile': {'type': 'RuntimeDefault'}
            },
            'command': [
                'sh',
                '-c',
                f"until wget -q -O {self.k8s_config.app_mount_path}/code.tar.gz {code_server_url}; do sleep 2; done && tar xzf {self.k8s_config.app_mount_path}/code.tar.gz -C {self.k8s_config.app_mount_path}/ && rm {self.k8s_config.app_mount_path}/code.tar.gz"
            ],
            'volumeMounts': [
                {'name': 'app-code', 'mountPath': self.k8s_config.app_mount_path},
                {'name': 'tmp', 'mountPath': '/tmp'}
            ]
        };

        # Only emptyDir - no PVC mount on app pods, so they can schedule on any node
        volumes = [
            {'name': 'app-code', 'emptyDir': {}},
            {'name': 'tmp', 'emptyDir': {}}
        ];

        return {'volumes': volumes, 'build_container': build_container};
    }

    """Deploy code-server: a single-replica busybox httpd that serves code from the PVC over HTTP."""
    def _deploy_code_server(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        code_server_name = f"{app_name}-code-server";
        code_server_labels = {'app': code_server_name};
        pvc_name = f"{app_name}-code-pvc";
        code_server_sa_name = f"{code_server_name}-sa";

        # ServiceAccount for code-server
        code_server_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': code_server_sa_name,
                'namespace': namespace,
                'labels': {** code_server_labels, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(
                name=code_server_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=code_server_sa
                );
            } else {
                raise;
            }
        }

        # Code-server Deployment spec
        deployment_body = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': code_server_name,
                'namespace': namespace,
                'labels': {** code_server_labels, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': code_server_labels},
                'template': {
                    'metadata': {'labels': code_server_labels},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'serviceAccountName': code_server_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'code-server',
                                'image': self.k8s_config.busybox_image,
                                # readOnlyRootFilesystem=False: busybox httpd writes
                                # the tarball to /tmp before serving it.
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 1000,
                                    'readOnlyRootFilesystem': False,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']},
                                    'seccompProfile': {'type': 'RuntimeDefault'}
                                },
                                'command': [
                                    'sh',
                                    '-c',
                                    f"echo 'Code-server starting' && tar czf /tmp/code.tar.gz -C {self.k8s_config.workspace_path} --exclude='.jac' . && echo 'Tar completed' && httpd -f -p 8080 -h /tmp"
                                ],
                                'ports': [{'containerPort': 8080}],
                                'volumeMounts': [
                                    {
                                        'name': 'code-source',
                                        'mountPath': self.k8s_config.code_mount_path,
                                        'readOnly': True
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'code-source',
                                'persistentVolumeClaim': {'claimName': pvc_name}
                            }
                        ]
                    }
                }
            }
        };

        # Code-server Service spec
        service_body = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': code_server_name,
                'namespace': namespace,
                'labels': {** code_server_labels, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'ports': [{'port': 8080, 'targetPort': 8080}],
                'selector': code_server_labels
            }
        };

        # Delete existing code-server deployment to force re-tar of fresh code
        delete_if_exists(
            apps_v1.delete_namespaced_deployment,
            code_server_name,
            namespace,
            'Deployment'
        );
        time.sleep(self.k8s_config.resource_deletion_wait);

        # Create code-server deployment
        apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment_body);
        if self.logger {
            self.logger.info(f"Deployed code-server '{code_server_name}'");
        }

        # Create code-server service (if not exists)
        try {
            core_v1.read_namespaced_service(name=code_server_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=service_body
                );
                if self.logger {
                    self.logger.info(
                        f"Created code-server service '{code_server_name}'"
                    );
                }
            } else {
                raise;
            }
        }
    }

    """Deploy all enabled databases and their optional dashboards."""
    def _deploy_databases(
        app_name: str, namespace: str, apps_v1: Any, core_v1: Any, cluster_env: str
    ) {
        if self.k8s_config.mongodb_enabled {
            mongodb_name = f"{app_name}-mongodb";
            mongodb_service_name = f"{mongodb_name}-service";
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            mongo_result = mongo_provider.deploy({});
            self._apply_provider_service_account(
                mongo_result['service_account'], namespace, core_v1
            );
            self.env_list.append(
                {
                    'name': 'MONGODB_URI',
                    'valueFrom': {
                        'secretKeyRef': {
                            'name': mongo_result['secret_name'],
                            'key': 'connection-string'
                        }
                    }
                }
            );
            try {
                core_v1.read_namespaced_secret(
                    name=mongo_result['secret']['metadata']['name'], namespace=namespace
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_secret(
                        namespace=namespace, body=mongo_result['secret']
                    );
                } else {
                    raise;
                }
            }
            try {
                apps_v1.read_namespaced_stateful_set(
                    name=mongodb_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    apps_v1.create_namespaced_stateful_set(
                        namespace=namespace, body=mongo_result['deployment']
                    );
                } else {
                    raise;
                }
            }
            try {
                core_v1.read_namespaced_service(
                    name=mongodb_service_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=mongo_result['service']
                    );
                } else {
                    raise;
                }
            }
            if self.k8s_config.mongodb_dashboard {
                express_result = mongo_provider.deploy_dashboard(
                    username=self.k8s_config.mongo_express_username,
                    password=self.k8s_config.mongo_express_password
                );
                self._apply_provider_service_account(
                    express_result['service_account'], namespace, core_v1
                );
                try {
                    apps_v1.patch_namespaced_deployment(
                        name=express_result['deployment_name'],
                        namespace=namespace,
                        body=express_result['deployment']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        apps_v1.create_namespaced_deployment(
                            namespace=namespace, body=express_result['deployment']
                        );
                    } else {
                        raise;
                    }
                }
                try {
                    core_v1.patch_namespaced_service(
                        name=express_result['service_name'],
                        namespace=namespace,
                        body=express_result['service']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        core_v1.create_namespaced_service(
                            namespace=namespace, body=express_result['service']
                        );
                    } else {
                        raise;
                    }
                }
                if self.logger {
                    self.logger.info(
                        f"mongo-express dashboard deployed for '{app_name}' (accessible via ingress at /db-dashboard)"
                    );
                }
            }
        }

        if self.k8s_config.redis_enabled {
            redis_name = f"{app_name}-redis";
            redis_service_name = f"{redis_name}-service";
            redis_config_name = f"{redis_name}-config";
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            redis_result = redis_provider.deploy({});
            self._apply_provider_service_account(
                redis_result['service_account'], namespace, core_v1
            );
            self.env_list.append(
                {
                    'name': 'REDIS_URL',
                    'valueFrom': {
                        'secretKeyRef': {
                            'name': redis_result['secret_name'],
                            'key': 'connection-string'
                        }
                    }
                }
            );
            try {
                core_v1.read_namespaced_secret(
                    name=redis_result['secret']['metadata']['name'], namespace=namespace
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_secret(
                        namespace=namespace, body=redis_result['secret']
                    );
                } else {
                    raise;
                }
            }
            config_updated = False;
            try {
                existing_cm = core_v1.read_namespaced_config_map(
                    name=redis_config_name, namespace=namespace
                );
                existing_content = existing_cm.data.get('redis.conf', '');
                new_content = redis_result['configmap']['data']['redis.conf'];

                if existing_content != new_content {
                    if self.logger {
                        self.logger.info(
                            f"Redis configuration changed (hash: {redis_result[
                                'config_hash'
                            ]}). "
                            "Updating ConfigMap..."
                        );
                    }
                    core_v1.replace_namespaced_config_map(
                        name=redis_config_name,
                        namespace=namespace,
                        body=redis_result['configmap']
                    );
                    config_updated = True;
                    if self.logger {
                        self.logger.info("Redis ConfigMap updated successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.debug(
                            "Redis configuration unchanged, skipping ConfigMap update"
                        );
                    }
                }
            } except ApiException as e {
                if (e.status == 404) {
                    if self.logger {
                        self.logger.info("Creating new Redis ConfigMap");
                    }
                    core_v1.create_namespaced_config_map(
                        namespace=namespace, body=redis_result['configmap']
                    );
                    if self.logger {
                        self.logger.info("Redis ConfigMap created successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.error(f"Failed to manage Redis ConfigMap: {e}");
                    }
                    raise;
                }
            }
            # Deploy Deployment (or update if config changed)
            try {
                existing_deploy = apps_v1.read_namespaced_deployment(
                    name=redis_name, namespace=namespace
                );

                # Check if deployment needs update (config hash changed)
                annotations = existing_deploy.spec.template.metadata.annotations;
                existing_hash = annotations.get('redis-config-hash', '')
                    if annotations
                    else '';
                new_hash = redis_result['config_hash'];

                if existing_hash != new_hash or config_updated {
                    if self.logger {
                        self.logger.info(
                            f"Redis deployment needs update. "
                            f"Old hash: {existing_hash}, New hash: {new_hash}"
                        );
                    }
                    # Update deployment to trigger pod restart with new config
                    apps_v1.replace_namespaced_deployment(
                        name=redis_name,
                        namespace=namespace,
                        body=redis_result['deployment']
                    );
                    if self.logger {
                        self.logger.info(
                            "Redis deployment updated. Pods will restart with new configuration."
                        );
                    }
                } else {
                    if self.logger {
                        self.logger.debug(
                            "Redis deployment unchanged, skipping update"
                        );
                    }
                }
            } except ApiException as e {
                if (e.status == 404) {
                    if self.logger {
                        self.logger.info("Creating new Redis deployment");
                    }
                    apps_v1.create_namespaced_deployment(
                        namespace=namespace, body=redis_result['deployment']
                    );
                    if self.logger {
                        self.logger.info("Redis deployment created successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.error(f"Failed to manage Redis deployment: {e}");
                    }
                    raise;
                }
            }
            # Deploy Service
            try {
                core_v1.read_namespaced_service(
                    name=redis_service_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=redis_result['service']
                    );
                } else {
                    raise;
                }
            }
            if self.k8s_config.redis_dashboard {
                insight_result = redis_provider.deploy_dashboard();
                self._apply_provider_service_account(
                    insight_result['service_account'], namespace, core_v1
                );
                try {
                    apps_v1.patch_namespaced_deployment(
                        name=insight_result['deployment_name'],
                        namespace=namespace,
                        body=insight_result['deployment']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        apps_v1.create_namespaced_deployment(
                            namespace=namespace, body=insight_result['deployment']
                        );
                    } else {
                        raise;
                    }
                }
                try {
                    core_v1.patch_namespaced_service(
                        name=insight_result['service_name'],
                        namespace=namespace,
                        body=insight_result['service']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        core_v1.create_namespaced_service(
                            namespace=namespace, body=insight_result['service']
                        );
                    } else {
                        raise;
                    }
                }
                if self.logger {
                    self.logger.info(
                        f"RedisInsight dashboard deployed for '{app_name}' (accessible via ingress at /cache-dashboard)"
                    );
                }
            }
        }
    }

    """Create a dedicated ServiceAccount with no automounted token for a deployment."""
    def _create_service_account(
        sa_name: str, app_label: str, namespace: str, core_v1: Any
    ) {
        sa_body = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': sa_name,
                'namespace': namespace,
                'labels': {'app': app_label, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(name=sa_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=sa_body
                );
                if self.logger {
                    self.logger.info(
                        f"Created ServiceAccount '{sa_name}' in namespace '{namespace}'"
                    );
                }
            } else {
                raise;
            }
        }
    }

    """Apply or replace a service-account resource created by a provider (mongo/redis).

    Provider-returned service accounts have no namespace in their metadata; this
    helper injects it and creates/skips if it already exists.
    """
    def _apply_provider_service_account(
        sa_spec: dict[str, Any], namespace: str, core_v1: Any
    ) {
        sa_spec['metadata']['namespace'] = namespace;
        sa_name = sa_spec['metadata']['name'];
        try {
            core_v1.read_namespaced_service_account(name=sa_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=sa_spec
                );
                if self.logger {
                    self.logger.info(
                        f"Created ServiceAccount '{sa_name}' in namespace '{namespace}'"
                    );
                }
            } else {
                raise;
            }
        }
    }

    """Generate and apply NetworkPolicies for the app namespace.

    Creates separate policies for each component to enforce proper isolation:
      - Main app: allows ingress on container port, allows egress to DNS and intra-namespace
      - MongoDB: allows ingress on 27017 from main app, allows egress to DNS and intra-namespace
      - Redis: allows ingress on 6379 from main app, allows egress to DNS and intra-namespace
      - Other components: deny all ingress, allow egress to DNS and intra-namespace
    """
    def _deploy_network_policy(app_name: str, namespace: str, networking_v1: Any) {
        # Common egress rules for all policies
        common_egress_rules = [
            # DNS — explicit kube-system selector so CNIs that evaluate policy
            # before DNAT (e.g. Flannel) can reach kube-dns.
            {
                'to': [
                    {
                        'namespaceSelector': {
                            'matchLabels': {
                                'kubernetes.io/metadata.name': 'kube-system'
                            }
                        }
                    }
                ],
                'ports': [
                    {'protocol': 'UDP', 'port': 53},
                    {'protocol': 'TCP', 'port': 53}
                ]
            },
            # All pods within the same namespace
            {'to': [{'podSelector': {}}]},
            # External HTTPS — needed for pip/apt installs during runtime setup
            {
                'ports': [
                    {'protocol': 'TCP', 'port': 443},
                    {'protocol': 'TCP', 'port': 80}
                ]
            }
        ];

        # Define policies for each component
        policies = [
            {
                'name': f"{app_name}-network-policy",
                'pod_selector': {'matchLabels': {'app': app_name}},
                'ingress_rules': [
                    # App container port — accepts traffic from NodePort/LoadBalancer
                    {
                        'ports': [
                            {'protocol': 'TCP', 'port': self.k8s_config.container_port}
                        ]
                    }
                ]
            },
            {
                'name': f"{app_name}-mongodb-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-mongodb"}},
                'ingress_rules': [
                    # MongoDB port — accepts traffic from main app and mongo-express dashboard
                    {
                        'from': [
                            {'podSelector': {'matchLabels': {'app': app_name}}},
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-mongo-express"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 27017}]
                    }
                ]
            },
            {
                'name': f"{app_name}-redis-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-redis"}},
                'ingress_rules': [
                    # Redis port — accepts traffic from main app and RedisInsight dashboard
                    {
                        'from': [
                            {'podSelector': {'matchLabels': {'app': app_name}}},
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-redis-insight"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 6379}]
                    }
                ]
            },
            # Prometheus — allow grafana to query on port 9090
            {
                'name': f"{app_name}-prometheus-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-prometheus"}},
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-grafana"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 9090}]
                    }
                ]
            },
            # Grafana — allow ingress controller to reach it on port 3000 (/grafana route)
            {
                'name': f"{app_name}-grafana-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-grafana"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 3000}]}]
            },
            {
                'name': f"{app_name}-code-server-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-code-server"}},
                'ingress_rules': [
                    # Code-server port — accepts traffic from main app
                    {
                        'from': [{'podSelector': {'matchLabels': {'app': app_name}}}],
                        'ports': [{'protocol': 'TCP', 'port': 8080}]
                    }
                ]
            },
            # kube-state-metrics — allow prometheus to scrape on port 8080
            {
                'name': f"{app_name}-kube-state-metrics-network-policy",
                'pod_selector': {
                    'matchLabels': {'app': f"{app_name}-kube-state-metrics"}
                },
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-prometheus"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 8080}]
                    }
                ]
            },
            # node-exporter — allow prometheus to scrape on port 9100
            {
                'name': f"{app_name}-node-exporter-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-node-exporter"}},
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-prometheus"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 9100}]
                    }
                ]
            },
            # mongo-express — allow ingress controller to reach it on port 8081 (/db-dashboard route)
            {
                'name': f"{app_name}-mongo-express-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-mongo-express"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 8081}]}]
            },
            # redis-insight — allow ingress controller to reach it on port 5540
            {
                'name': f"{app_name}-redis-insight-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-redis-insight"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 5540}]}]
            }
        ];

        for policy_config in policies {
            network_policy = {
                'apiVersion': 'networking.k8s.io/v1',
                'kind': 'NetworkPolicy',
                'metadata': {
                    'name': policy_config['name'],
                    'namespace': namespace,
                    'labels': {'app': app_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'podSelector': policy_config['pod_selector'],
                    'policyTypes': ['Ingress', 'Egress'],
                    'ingress': policy_config['ingress_rules'],
                    'egress': common_egress_rules
                }
            };

            try {
                networking_v1.read_namespaced_network_policy(
                    name=policy_config['name'], namespace=namespace
                );
                networking_v1.replace_namespaced_network_policy(
                    name=policy_config['name'], namespace=namespace, body=network_policy
                );
            } except ApiException as e {
                if e.status == 404 {
                    networking_v1.create_namespaced_network_policy(
                        namespace=namespace, body=network_policy
                    );
                    if self.logger {
                        self.logger.info(
                            f"Created NetworkPolicy '{policy_config[
                                'name'
                            ]}' in namespace '{namespace}'"
                        );
                    }
                } else {
                    raise;
                }
            }
        }
    }

    """Wait for deployment to be ready and check status."""
    def _wait_for_deployment(
        app_name: str, namespace: str, health_check_path: str, cluster_env: str
    ) -> str {
        path = health_check_path;
        deployment_details = "";
        if cluster_env == 'aws' {
            time.sleep(self.k8s_config.aws_nlb_wait);
            nlb_url = None;
            try {
                try {
                    k8s_cluster_config.load_kube_config();
                } except ConfigException {
                    k8s_cluster_config.load_incluster_config();
                }
                core_v1 = client.CoreV1Api();
                # The app service is ClusterIP; the NLB is on the NGINX ingress
                # controller's LoadBalancer service — same source as get_service_url().
                ingress_svc_name = f"{app_name}-ingress-nginx-service";
                service_obj = core_v1.read_namespaced_service(
                    ingress_svc_name, namespace
                );
                nlb_ingress = service_obj.status.load_balancer.ingress;
                if (nlb_ingress and (len(nlb_ingress) > 0)) {
                    endpoint = nlb_ingress[0].hostname or nlb_ingress[0].ip;
                    nlb_url = f"http://{endpoint}";
                } else {
                    if self.logger {
                        self.logger.info(
                            f"NLB is being provisioned. Run 'kubectl get svc {ingress_svc_name} -n {namespace}' to get the endpoint."
                        );
                    }
                }
            } except Exception as e {
                if self.logger {
                    self.logger.warn(f"Could not retrieve NLB endpoint: {e}");
                }
            }
            if (nlb_url) {
                (deployment_status, deployment_details) = check_deployment_status(
                    self.k8s_config.ingress_node_port,
                    path,
                    max_retries=48,
                    nlb_url=nlb_url,
                    namespace=namespace,
                    app_name=app_name
                );
                if not (deployment_status) {
                    raise Exception("Deployment failed: Application failed to deploy.");
                }
            }
        } else {
            (deployment_status, deployment_details) = check_deployment_status(
                self.k8s_config.ingress_node_port,
                path,
                namespace=namespace,
                app_name=app_name
            );
            if deployment_status is False {
                raise Exception(f"Deployment failed: {deployment_details}");
            }
        }
        return deployment_details;
    }

    """Handle image registry if build is requested."""
    def _handle_image_registry(app_name: str, app_config: AppConfig) -> str {
        image_name = self.k8s_config.docker_image_name or f"{app_name}:latest";
        repository_name: str;
        if app_config.build and self.image_registry {
            # Build and push image
            full_image = self.image_registry.build_and_push(
                app_config.code_folder, image_name
            );
            repository_name = full_image;
        } elif app_config.build {
            # Create registry if not set
            registry_config = {
                'app_name': app_name,
                'docker_username': self.k8s_config.docker_username,
                'docker_password': self.k8s_config.docker_password,
                'docker_image_name': image_name
            };
            image_registry = ImageRegistryFactory.create('dockerhub', registry_config);
            full_image = image_registry.build_and_push(
                app_config.code_folder, image_name
            );
            repository_name = full_image;
        } else {
            repository_name = self.k8s_config.python_image;
        }
        return repository_name;
    }

    def deploy(app_config: AppConfig) -> DeploymentResult {
        # 1. Initialize and validate
        app_name = app_config.app_name or self.k8s_config.app_name;
        namespace = self.k8s_config.namespace;
        success_status = False;
        details = {};

        if self.logger {
            self.logger.info(
                f"Deploying application '{app_name}' to Kubernetes",
                {'namespace': namespace, 'build': app_config.build}
            );
        }

        try {
            validate_resource_limits(
                self.k8s_config.cpu_request,
                self.k8s_config.cpu_limit,
                self.k8s_config.memory_request,
                self.k8s_config.memory_limit
            );
            details["validate_resource_limits"] = "Successful";
            # 2. Initialize Kubernetes clients
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            networking_v1 = client.NetworkingV1Api();
            check_K8s_status();
            ensure_namespace_exists(namespace);

            # 3. Load environment variables
            self.env_list = load_env_variables(app_config.code_folder);
            details["load_env_variables"] = "Successful";

            # 3b. Create K8s Secret from resolved secrets if configured
            secret_ref_name: str | None = None;
            if self.secrets {
                secret_ref_name = f"{app_name}-secrets";
                if create_k8s_secret(
                    core_v1, namespace, secret_ref_name, self.secrets
                ) {
                    if self.logger {
                        self.logger.info(f"Created K8s Secret '{secret_ref_name}'");
                    }
                } else {
                    secret_ref_name = None;
                }
            }

            # 4. Determine cluster type
            cluster_env = cluster_type();
            # 4b. On local clusters, verify that the requested NodePorts are not
            #     already bound by a service in another namespace.
            if cluster_env == 'local' {
                # All services are ClusterIP behind ingress; only the ingress
                # controller's NodePort needs a free port on the node.
                check_node_ports_available(
                    node_port=self.k8s_config.ingress_node_port,
                    current_namespace=namespace
                );
            }

            # 5. Handle image registry if build is requested
            repository_name = self._handle_image_registry(app_name, app_config);

            # 6. Get health check path
            health_check_path = self.k8s_config.health_check_path;

            # 7. Get database init containers
            init_containers = self._get_database_init_containers(app_name);

            # 8. Build configurations
            volumes = [];
            resources_config = self._build_resource_config();
            probe_configs = self._build_probe_config(health_check_path);

            # 9. Build container configuration
            container_config = self._build_container_config(
                app_name,
                repository_name,
                probe_configs,
                resources_config,
                secret_ref_name=secret_ref_name
            );

            # 10. Handle volumes and build container if not building image
            if not app_config.build {
                volumes_config = self._build_volumes_config(
                    app_name, app_config, namespace, core_v1, apps_v1
                );
                details["sync_code_to_pvc"] = "Successful";
                volumes = volumes_config['volumes'];
                build_container = volumes_config['build_container'];
                init_containers.append(build_container);
                # Build runtime setup command
                command = self._build_runtime_setup_command(app_config);
                container_config = self._build_container_config(
                    app_name,
                    self.k8s_config.python_image,
                    probe_configs,
                    resources_config,
                    command=command,
                    working_dir=self.k8s_config.app_mount_path,
                    volume_mounts=[
                        {
                            'name': 'app-code',
                            'mountPath': self.k8s_config.app_mount_path
                        },
                        {'name': 'tmp', 'mountPath': '/tmp'}
                    ],
                    secret_ref_name=secret_ref_name,
                    needs_root=True
                );
            }

            # 11. Create dedicated ServiceAccount for the app
            app_sa_name = f"{app_name}-sa";
            self._create_service_account(app_sa_name, app_name, namespace, core_v1);
            details["create_service_account"] = "Successful";

            # 11b. Build service and deployment
            service = self._build_service_config(
                app_name, cluster_env, health_check_path
            );
            deployment = {
                'apiVersion': 'apps/v1',
                'kind': 'Deployment',
                'metadata': {
                    'name': app_name,
                    'namespace': namespace,
                    'labels': {'app': app_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'replicas': 1,
                    'selector': {'matchLabels': {'app': app_name}},
                    'template': {
                        'metadata': {'labels': {'app': app_name}},
                        'spec': {
                            'automountServiceAccountToken': False,
                            'serviceAccountName': app_sa_name,
                            'securityContext': {
                                'seccompProfile': {'type': 'RuntimeDefault'}
                            },
                            'initContainers': init_containers,
                            'containers': [container_config],
                            'volumes': volumes
                        }
                    }
                }
            };

            # 12. Delete existing resources if they exist
            delete_if_exists(
                apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
            );
            details["delete_previous_existing_resources"] = "Successful";
            time.sleep(self.k8s_config.resource_deletion_wait);

            # 12b. Start NGINX Ingress controller early so it boots in parallel with
            # databases, app, HPA, and monitoring — minimising the wait in finish_ingress().
            rbac_v1 = client.RbacAuthorizationV1Api();
            networking_v1 = client.NetworkingV1Api();
            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.start_controller(
                app_name,
                namespace,
                cluster_env,
                apps_v1,
                core_v1,
                rbac_v1,
                networking_v1
            );

            # 13. Deploy databases
            self._deploy_databases(app_name, namespace, apps_v1, core_v1, cluster_env);
            details["deploy_databases"] = "Successful";
            # 13b. Apply NetworkPolicy for the app pod
            self._deploy_network_policy(app_name, namespace, networking_v1);
            details["deploy_network_policy"] = "Successful";

            # 14. Deploy main application
            if self.logger {
                self.logger.info(f'Deploying Jaseci-app app...');
            }
            apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
            details["create_jaseci_application_deployment"] = "Successful";
            try {
                core_v1.read_namespaced_service(
                    name=f"{app_name}-service", namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=service
                    );
                } else {
                    raise;
                }
            }
            details["create_jaseci_application_service"] = "Successful";
            # 16. Enable horizontal pod autoscaling
            create_hpa(
                namespace=namespace,
                deployment_name=app_name,
                min_replicas=self.k8s_config.min_replicas,
                max_replicas=self.k8s_config.max_replicas,
                cpu_target=self.k8s_config.cpu_utilization_target
            );
            details["create_horizontal_auto_scaler"] = "Successful";
            # 15. Deploy monitoring stack (Prometheus / Grafana) if enabled
            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.deploy(app_name, namespace, apps_v1, core_v1, cluster_env);
            details["deploy_monitoring"] = "Successful";

            # 15b. Finish ingress: wait for NGINX controller readiness (started at step 12b)
            # and deploy routing rules. The controller has been booting in parallel with
            # databases, app, HPA, and monitoring so the wait is typically zero.
            ingress_deployer.finish_ingress(
                app_name,
                namespace,
                self.k8s_config.container_port,
                self.k8s_config.monitoring_enabled,
                self.k8s_config.redis_dashboard,
                self.k8s_config.mongodb_dashboard,
                apps_v1,
                core_v1,
                networking_v1
            );
            details["deploy_ingress"] = "Successful";

            # 16. Wait for deployment and get service URL
            deployment_details = self._wait_for_deployment(
                app_name, namespace, health_check_path, cluster_env
            );
            details["health_check_of_deployment"] = deployment_details;
            service_url = self.get_service_url(app_name);

            # Print DNS instructions when a custom domain is set
            if self.k8s_config.domain {
                lb_endpoint = self._get_lb_endpoint(app_name);
                if lb_endpoint and self.logger {
                    import re;
                    is_ip = bool(re.match(r'^\d+\.\d+\.\d+\.\d+$', lb_endpoint));
                    record_type = "A" if is_ip else "CNAME";
                    self.logger.info(f"\n{'=' * 62}");
                    self.logger.info(
                        f"ACTION REQUIRED — add a {record_type} record in your DNS provider:"
                    );
                    self.logger.info(f"  Type   : {record_type}");
                    self.logger.info(f"  Name   : {self.k8s_config.domain}");
                    self.logger.info(f"  Value  : {lb_endpoint}");
                    self.logger.info(
                        f"\nAfter the record propagates, enable HTTPS with:"
                    );
                    self.logger.info(
                        f"  jac start <your-app.jac> --scale --enable-tls"
                    );
                    self.logger.info(f"{'=' * 62}\n");
                }
            }

            success_status = True;
            return DeploymentResult(
                success=success_status,
                service_url=service_url,
                message=f"Application '{app_name}' deployed successfully",
                details=details
            );
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Error deploying application '{app_name}': {e}");
            }
            return DeploymentResult(
                success=success_status,
                message=f"Deployment failed for application '{app_name}': {e}",
                details=details
            );
        }
    }

    """Wait for resources to be completely deleted."""
    def _wait_for_deletion(
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        max_wait: int = 60,
        poll_interval: float = 1.0
    ) -> None {
        elapsed = 0.0;
        while elapsed < max_wait {
            resources_exist = False;

            # Check deployment
            try {
                apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace);
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            # Check service
            try {
                core_v1.read_namespaced_service(
                    name=f"{app_name}-service", namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            # Check code-server deployment
            code_server_name = f"{app_name}-code-server";
            try {
                apps_v1.read_namespaced_deployment(
                    name=code_server_name, namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            # Check code-server service
            try {
                core_v1.read_namespaced_service(
                    name=code_server_name, namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            # Check MongoDB resources if enabled
            if self.k8s_config.mongodb_enabled {
                mongodb_name = f"{app_name}-mongodb";
                try {
                    apps_v1.read_namespaced_stateful_set(
                        name=mongodb_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{mongodb_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            # Check Redis resources if enabled
            if self.k8s_config.redis_enabled {
                redis_name = f"{app_name}-redis";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=redis_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{redis_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            # Check monitoring resources (Prometheus / Grafana) if enabled
            if self.k8s_config.monitoring_enabled {
                prometheus_name = f"{app_name}-prometheus";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=prometheus_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{prometheus_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                grafana_name = f"{app_name}-grafana";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=grafana_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{grafana_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            # Check PVCs
            try {
                pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
                for pvc in pvcs.items {
                    if pvc.metadata.name.startswith(app_name) {
                        resources_exist = True;
                        break;
                    }
                }
            } except Exception as e {
                if self.logger {
                    self.logger.warning(
                        f"Failed to list PVCs while checking resources for '{app_name}': {e}"
                    );
                }
            }

            # Check code sync pod
            try {
                core_v1.read_namespaced_pod(
                    name=f"{app_name}-code-sync", namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            # If no resources exist, deletion is complete
            if not resources_exist {
                if self.logger {
                    self.logger.info(
                        f"All resources for '{app_name}' have been deleted"
                    );
                }
                return;
            }
            time.sleep(poll_interval);
            elapsed = elapsed + poll_interval;
        }

        if self.logger {
            self.logger.warn(
                f"Timeout waiting for resources to be deleted after {max_wait} seconds"
            );
        }
    }

    """Destroy all databases, caches, and their dashboards."""
    def _destroy_databases(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        self._destroy_database(app_name, namespace, apps_v1, core_v1);
        self._destroy_cache(app_name, namespace, apps_v1, core_v1);
        self._destroy_dashboard(app_name, namespace, apps_v1, core_v1);
    }

    def _destroy_application(
        app_name: str, namespace: str, apps_v1: Any, core_v1: Any
    ) {
        autoscaling_v2 = client.AutoscalingV2Api();
        delete_if_exists(
            autoscaling_v2.delete_namespaced_horizontal_pod_autoscaler,
            f"{app_name}-hpa",
            namespace,
            'HorizontalPodAutoscaler'
        );
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{app_name}-service",
            namespace,
            'Service'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-secrets");
        code_server_name = f"{app_name}-code-server";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment,
            code_server_name,
            namespace,
            'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service, code_server_name, namespace, 'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_pod, f"{app_name}-code-sync", namespace, 'Pod'
        );
        delete_if_exists(
            core_v1.delete_namespaced_persistent_volume_claim,
            f"{app_name}-code-pvc",
            namespace,
            'PersistentVolumeClaim'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-sa",
            namespace,
            'ServiceAccount'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-code-server-sa",
            namespace,
            'ServiceAccount'
        );
        networking_v1 = client.NetworkingV1Api();
        # Delete all NetworkPolicies for this app
        network_policy_names = [
            f"{app_name}-network-policy",
            f"{app_name}-mongodb-network-policy",
            f"{app_name}-redis-network-policy",
            f"{app_name}-prometheus-network-policy",
            f"{app_name}-grafana-network-policy",
            f"{app_name}-code-server-network-policy",
            f"{app_name}-kube-state-metrics-network-policy",
            f"{app_name}-node-exporter-network-policy",
            f"{app_name}-mongo-express-network-policy",
            f"{app_name}-redis-insight-network-policy"
        ];
        for policy_name in network_policy_names {
            delete_if_exists(
                networking_v1.delete_namespaced_network_policy,
                policy_name,
                namespace,
                'NetworkPolicy'
            );
        }
    }

    def _destroy_database(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        mongodb_name = f"{app_name}-mongodb";
        delete_if_exists(
            apps_v1.delete_namespaced_stateful_set,
            mongodb_name,
            namespace,
            'StatefulSet'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{mongodb_name}-service",
            namespace,
            'Service'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-mongodb-secret");
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-mongodb-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_cache(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        redis_name = f"{app_name}-redis";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, redis_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{redis_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_config_map,
            f"{redis_name}-config",
            namespace,
            'ConfigMap'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-redis-secret");
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-redis-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_dashboard(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        express_name = f"{app_name}-mongo-express";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, express_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{express_name}-service",
            namespace,
            'Service'
        );
        insight_name = f"{app_name}-redis-insight";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, insight_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{insight_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_config_map,
            f"{insight_name}-nginx-config",
            namespace,
            'ConfigMap'
        );
        delete_if_exists(
            core_v1.delete_namespaced_secret,
            f"{insight_name}-auth",
            namespace,
            'Secret'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-mongo-express-sa",
            namespace,
            'ServiceAccount'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-redis-insight-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_component(
        app_name: str, namespace: str, component: str, apps_v1: Any, core_v1: Any
    ) {
        if component == 'application' {
            self._destroy_application(app_name, namespace, apps_v1, core_v1);
        } elif component == 'database' {
            self._destroy_database(app_name, namespace, apps_v1, core_v1);
        } elif component == 'cache' {
            self._destroy_cache(app_name, namespace, apps_v1, core_v1);
        } elif component == 'monitoring' {
            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.destroy(app_name, namespace, apps_v1, core_v1);
        } elif component == 'dashboard' {
            self._destroy_dashboard(app_name, namespace, apps_v1, core_v1);
        } else {
            raise ValueError(
                f"Unknown component: '{component}'. Valid choices: application, database, cache, monitoring, dashboard"
            );
        }
        if self.logger {
            self.logger.info(f"Component '{component}' of '{app_name}' destroyed");
        }
    }

    def destroy(app_name: str, component: str = "") -> None {
        if self.logger {
            if component {
                self.logger.info(
                    f"Destroying component '{component}' of '{app_name}' from Kubernetes"
                );
            } else {
                self.logger.info(
                    f"Destroying application '{app_name}' from Kubernetes"
                );
            }
        }

        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;

            if component {
                self._destroy_component(
                    app_name, namespace, component, apps_v1, core_v1
                );
                return;
            }

            self._destroy_application(app_name, namespace, apps_v1, core_v1);

            # Delete NGINX Ingress controller + routing rules
            rbac_v1 = client.RbacAuthorizationV1Api();
            networking_v1 = client.NetworkingV1Api();
            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.destroy(
                app_name, namespace, apps_v1, core_v1, rbac_v1, networking_v1
            );

            # Delete monitoring stack (Prometheus / Grafana)
            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.destroy(app_name, namespace, apps_v1, core_v1);

            # Delete databases
            self._destroy_databases(app_name, namespace, apps_v1, core_v1);

            # Broad PVC sweep (catch any PVCs not cleaned up by component methods)
            pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
            for pvc in pvcs.items {
                if pvc.metadata.name.startswith(app_name) {
                    try {
                        core_v1.delete_namespaced_persistent_volume_claim(
                            name=pvc.metadata.name, namespace=namespace
                        );
                    } except Exception as e {
                        if self.logger {
                            self.logger.warning(
                                f"Failed to delete PVC '{pvc.metadata.name}': {e}"
                            );
                        }
                    }
                }
            }

            # Wait for all resources to be completely deleted
            if self.logger {
                self.logger.info(
                    f"Waiting for all resources to be deleted for '{app_name}'..."
                );
            }
            self._wait_for_deletion(app_name, namespace, apps_v1, core_v1);

            # Delete namespace if not the default one
            if namespace != 'default' {
                delete_namespace(namespace);
                if self.logger {
                    self.logger.info(
                        f"Waiting for namespace '{namespace}' to be deleted..."
                    );
                }
                ns_deleted = False;
                ns_elapsed = 0.0;
                ns_max_wait = 120;
                ns_poll = 2.0;
                while ns_elapsed < ns_max_wait {
                    try {
                        core_v1.read_namespace(name=namespace);
                        time.sleep(ns_poll);
                        ns_elapsed = ns_elapsed + ns_poll;
                    } except ApiException as e {
                        if e.status == 404 {
                            ns_deleted = True;
                            break;
                        }
                        raise;
                    }
                }
                if self.logger {
                    if ns_deleted {
                        self.logger.info(f"Namespace '{namespace}' deleted");
                    } else {
                        self.logger.warning(
                            f"Timed out waiting for namespace '{namespace}' to be deleted"
                        );
                    }
                }
            }

            if self.logger {
                self.logger.info(f"Application '{app_name}' destroyed successfully");
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Error destroying application '{app_name}': {e}");
            }
            raise;
        }
    }

    def get_status(app_name: str) -> ResourceStatusInfo {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;

            deployment = apps_v1.read_namespaced_deployment(
                name=app_name, namespace=namespace
            );

            replicas = deployment.spec.replicas or 0;
            ready_replicas = deployment.status.ready_replicas or 0;

            if ready_replicas == replicas and replicas > 0 {
                status = ResourceStatus.RUNNING;
            } elif ready_replicas > 0 {
                status = ResourceStatus.PENDING;
            } else {
                status = ResourceStatus.FAILED;
            }

            return ResourceStatusInfo(
                status=status, replicas=replicas, ready_replicas=ready_replicas
            );
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to get status for '{app_name}': {e}");
            }
            return ResourceStatusInfo(status=ResourceStatus.UNKNOWN, message=str(e));
        }
    }

    def scale(app_name: str, replicas: int) {
        if self.logger {
            self.logger.info(
                f"Scaling application '{app_name}' to {replicas} replicas"
            );
        }

        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            namespace = self.k8s_config.namespace;

            deployment = apps_v1.read_namespaced_deployment(
                name=app_name, namespace=namespace
            );
            deployment.spec.replicas = replicas;

            apps_v1.patch_namespaced_deployment(
                name=app_name, namespace=namespace, body=deployment
            );

            if self.logger {
                self.logger.info(
                    f"Successfully scaled '{app_name}' to {replicas} replicas"
                );
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to scale '{app_name}': {e}");
            }
            raise;
        }
    }

    """Return the LoadBalancer hostname or IP for DNS instructions (any cloud env)."""
    def _get_lb_endpoint(app_name: str) -> (str | None) {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;
            ingress_svc_name = f"{app_name}-ingress-nginx-service";
            svc = core_v1.read_namespaced_service(
                name=ingress_svc_name, namespace=namespace
            );
            lb_ingress = svc.status.load_balancer.ingress;
            if lb_ingress and len(lb_ingress) > 0 {
                return lb_ingress[0].hostname or lb_ingress[0].ip;
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(
                    f"Could not get LoadBalancer endpoint for '{app_name}': {e}"
                );
            }
        }
        return None;
    }

    def get_service_url(app_name: str) -> (str | None) {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            namespace = self.k8s_config.namespace;

            # If a custom domain is configured, return the domain-based URL.
            # Check Ingress spec.tls to determine whether HTTPS is active.
            if self.k8s_config.domain {
                try {
                    networking_v1 = client.NetworkingV1Api();
                    ingress = networking_v1.read_namespaced_ingress(
                        name=f"{app_name}-ingress", namespace=namespace
                    );
                    if ingress.spec.tls {
                        return f"https://{self.k8s_config.domain}";
                    }
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not read ingress TLS status: {e}");
                    }
                }
                return f"http://{self.k8s_config.domain}";
            }

            core_v1 = client.CoreV1Api();
            cluster_env = cluster_type();

            if cluster_env == 'aws' {
                # Resolve the ingress controller's LoadBalancer endpoint
                endpoint = self._get_lb_endpoint(app_name);
                if endpoint {
                    return f"http://{endpoint}";
                }
            } else {
                return f"http://localhost:{self.k8s_config.ingress_node_port}";
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(f"Could not get service URL for '{app_name}': {e}");
            }
        }
        return None;
    }

    """Enable HTTPS for an already-deployed application.

    Installs cert-manager, creates a Let's Encrypt Issuer, patches the live
    Ingress with TLS annotations, and waits for the certificate to become Ready.
    Does NOT redeploy the application.
    """
    def enable_tls(app_name: str) {
        if self.logger {
            self.logger.info(f"Enabling TLS for '{app_name}'...");
        }
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            namespace = self.k8s_config.namespace;
            networking_v1 = client.NetworkingV1Api();
            custom_api = client.CustomObjectsApi();
            core_v1 = client.CoreV1Api();
            apps_v1 = client.AppsV1Api();

            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.enable_tls(
                app_name, namespace, networking_v1, custom_api, core_v1, apps_v1
            );

            # Determine domain for output (config or ingress annotation)
            domain = self.k8s_config.domain;
            if not domain {
                try {
                    ingress = networking_v1.read_namespaced_ingress(
                        name=f"{app_name}-ingress", namespace=namespace
                    );
                    ann = ingress.metadata.annotations or {};
                    domain = ann.get('jac-scale/domain', '');
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not read ingress annotations: {e}");
                    }
                }
            }

            # Update Grafana root URL to use HTTPS with the domain
            if domain {
                try {
                    grafana_name = f"{app_name}-grafana";
                    apps_v1.patch_namespaced_deployment(
                        name=grafana_name,
                        namespace=namespace,
                        body={
                            'spec': {
                                'template': {
                                    'spec': {
                                        'containers': [
                                            {
                                                'name': 'grafana',
                                                'env': [
                                                    {
                                                        'name': 'GF_SERVER_ROOT_URL',
                                                        'value': f"https://{domain}/grafana"
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                }
                            }
                        }
                    );
                    if self.logger {
                        self.logger.info(
                            f"Updated Grafana GF_SERVER_ROOT_URL to https://{domain}/grafana"
                        );
                    }
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not update Grafana deployment: {e}");
                    }
                }
            }

            if domain and self.logger {
                self.logger.info(f"\nTLS enabled. App is now live at:");
                self.logger.info(f"  App URL:        https://{domain}");
                self.logger.info(f"  Grafana:        https://{domain}/grafana");
                self.logger.info(f"  Mongo Express:  https://{domain}/db-dashboard");
                self.logger.info(f"  RedisInsight:   https://{domain}/cache-dashboard");
                self.logger.info(
                    f"\nCertificate renewal is automatic (cert-manager renews ~30 days before expiry).\n"
                );
            }
            if self.logger {
                self.logger.info(f"TLS successfully enabled for '{app_name}'");
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to enable TLS for '{app_name}': {e}");
            }
            raise;
        }
    }

    """Get comprehensive status of all deployed components for this application.

    Makes 4 bulk API calls instead of one per component:
      1. list_namespaced_deployment
      2. list_namespaced_stateful_set
      3. list_namespaced_pod  (to detect crash-looping pods)
      4. read_namespaced_service  (app URL)
    """
    def get_full_status(app_name: str) -> dict {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
        } except Exception as e {
            return {
                'app_name': app_name,
                'namespace': self.k8s_config.namespace,
                'error': str(e),
                'components': [],
                'urls': {}
            };
        }

        namespace = self.k8s_config.namespace;
        components = [];
        urls = {};

        # 1. Bulk-fetch all Deployments
        dep_map = {};
        try {
            for d in apps_v1.list_namespaced_deployment(namespace=namespace).items {
                dep_map[d.metadata.name] = d;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to list Deployments in '{namespace}': {e}"
                );
            }
        }

        # 2. Bulk-fetch all StatefulSets
        sts_map = {};
        try {
            for s in apps_v1.list_namespaced_stateful_set(namespace=namespace).items {
                sts_map[s.metadata.name] = s;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to list StatefulSets in '{namespace}': {e}"
                );
            }
        }

        # 3. Bulk-fetch pods to detect crash-looping (restart_count > 0)
        #    Keyed by the pod's 'app' label → True if any container has restarts
        restarting_apps = {};
        try {
            for pod in core_v1.list_namespaced_pod(namespace=namespace).items {
                pod_labels = pod.metadata.labels;
                if pod_labels and 'app' in pod_labels {
                    pod_app = pod_labels['app'];
                    if pod.status and pod.status.container_statuses {
                        for cs in pod.status.container_statuses {
                            if cs.restart_count and cs.restart_count > 0 {
                                restarting_apps[pod_app] = True;
                            }
                        }
                    }
                }
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(f"Failed to list Pods in '{namespace}': {e}");
            }
        }

        # Resolve status for each component from the cached maps.
        # Derived from COMPANION_DEFS — add new companions there, not here.
        component_defs = [
            {'k8s_name': app_name + d[0], 'display': d[1], 'is_sts': d[2]}
            for d in COMPANION_DEFS
        ];

        grafana_running = False;
        redis_insight_running = False;
        mongo_express_running = False;
        for cdef in component_defs {
            k8s_name = cdef['k8s_name'];
            display_name = cdef['display'];
            if cdef['is_sts'] {
                resource_map = sts_map;
            } else {
                resource_map = dep_map;
            }
            if k8s_name in resource_map {
                r = resource_map[k8s_name];
                replicas = r.spec.replicas or 0;
                ready = r.status.ready_replicas or 0;
                if ready == replicas and replicas > 0 {
                    status = 'running';
                } elif ready > 0 {
                    status = 'degraded';
                } elif k8s_name in restarting_apps {
                    # Pods exist but are crash-looping
                    status = 'restarting';
                } else {
                    status = 'pending';
                }
                components.append(
                    {
                        'name': display_name,
                        'status': status,
                        'ready': ready,
                        'total': replicas
                    }
                );
                if display_name == 'Grafana' {
                    grafana_running = True;
                } elif display_name == 'RedisInsight' {
                    redis_insight_running = True;
                } elif display_name == 'Mongo Express' {
                    mongo_express_running = True;
                }
            } else {
                components.append(
                    {
                        'name': display_name,
                        'status': 'not_deployed',
                        'ready': 0,
                        'total': 0
                    }
                );
            }
        }

        # 4. Application service URL
        is_aws = cluster_type() == 'aws';
        app_url = None;
        try {
            app_url = self.get_service_url(app_name);
            if app_url {
                urls['app'] = app_url;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to resolve service URL for '{app_name}': {e}"
                );
            }
        }

        # All dashboard URLs are path-based through the ingress entry point
        base_url = app_url or '';

        if grafana_running {
            urls['grafana'] = f"{base_url}/grafana";
        }

        if redis_insight_running {
            urls['redis_insight'] = f"{base_url}/cache-dashboard";
        }

        if mongo_express_running {
            urls['mongo_express'] = f"{base_url}/db-dashboard";
        }

        return {
            'app_name': app_name,
            'namespace': namespace,
            'components': components,
            'urls': urls
        };
    }
}
