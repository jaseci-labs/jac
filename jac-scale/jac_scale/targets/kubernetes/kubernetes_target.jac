"""Kubernetes deployment target implementation."""
import os;
import from typing { Any }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.resource_status { ResourceStatus, ResourceStatusInfo }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.kubernetes.K8s { deploy_K8s as _deploy_K8s }
import from jac_scale.kubernetes.utils { check_deployment_status, cluster_type, delete_if_exists }
import from kubernetes { client, config as k8s_config }

"""Kubernetes deployment target implementation."""
class KubernetesTarget(DeploymentTarget) {
    has k8s_config: KubernetesConfig;

    def init(
        self: KubernetesTarget,
        config: KubernetesConfig,
        logger: (Logger | None) = None
    ) -> None {
        self.config = config;
        self.k8s_config = config;
        if logger {
            self.logger = logger;
        }
    }

    def deploy(self: KubernetesTarget, app_config: AppConfig) -> DeploymentResult {
        # Use app_name from app_config if provided, otherwise use config
        app_name = app_config.app_name or self.k8s_config.app_name;
        
        # Log deployment start
        if self.logger {
            self.logger.info(
                f"Deploying application '{app_name}' to Kubernetes",
                {'namespace': self.k8s_config.namespace, 'build': app_config.build}
            );
        }
        
        # Call existing deploy_K8s function
        _deploy_K8s(
            code_folder=app_config.code_folder,
            file_name=app_config.file_name,
            build=app_config.build,
            testing=app_config.testing
        );
        
        # Get service URL
        service_url = self.get_service_url(app_name);
        
        if self.logger {
            self.logger.info(
                f"Deployment complete for '{app_name}'",
                {'service_url': service_url}
            );
        }
        
        return DeploymentResult(
            success=True,
            service_url=service_url,
            message=f"Application '{app_name}' deployed successfully"
        );
    }

    def destroy(self: KubernetesTarget, app_name: str) -> None {
        if self.logger {
            self.logger.info(f"Destroying application '{app_name}' from Kubernetes");
        }
        
        try {
            k8s_config.load_kube_config();
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;
            
            # Delete main deployment and service
            delete_if_exists(
                apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
            );
            delete_if_exists(
                core_v1.delete_namespaced_service, f"{app_name}-service", namespace, 'Service'
            );
            
            # Delete MongoDB if enabled
            if self.k8s_config.mongodb_enabled {
                mongodb_name = f"{app_name}-mongodb";
                delete_if_exists(
                    apps_v1.delete_namespaced_stateful_set, mongodb_name, namespace, 'StatefulSet'
                );
                delete_if_exists(
                    core_v1.delete_namespaced_service,
                    f"{mongodb_name}-service",
                    namespace,
                    'Service'
                );
            }
            
            # Delete Redis if enabled
            if self.k8s_config.redis_enabled {
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
            }
            
            # Delete code sync pod and PVCs
            delete_if_exists(
                core_v1.delete_namespaced_pod, f"{app_name}-code-sync", namespace, 'Pod'
            );
            
            # Delete PVCs
            pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
            for pvc in pvcs.items {
                if pvc.metadata.name.startswith(app_name) {
                    try {
                        core_v1.delete_namespaced_persistent_volume_claim(
                            name=pvc.metadata.name, namespace=namespace
                        );
                    } except Exception {
                        pass;
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

    def get_status(self: KubernetesTarget, app_name: str) -> ResourceStatusInfo {
        try {
            k8s_config.load_kube_config();
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
                status=status,
                replicas=replicas,
                ready_replicas=ready_replicas
            );
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to get status for '{app_name}': {e}");
            }
            return ResourceStatusInfo(
                status=ResourceStatus.UNKNOWN,
                message=str(e)
            );
        }
    }

    def scale(self: KubernetesTarget, app_name: str, replicas: int) -> None {
        if self.logger {
            self.logger.info(
                f"Scaling application '{app_name}' to {replicas} replicas"
            );
        }
        
        try {
            k8s_config.load_kube_config();
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

    def get_service_url(self: KubernetesTarget, app_name: str) -> (str | None) {
        try {
            k8s_config.load_kube_config();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;
            service_name = f"{app_name}-service";
            
            service = core_v1.read_namespaced_service(
                name=service_name, namespace=namespace
            );
            
            cluster_env = cluster_type();
            is_aws = cluster_env == 'aws';
            
            if is_aws {
                # AWS LoadBalancer
                ingress = service.status.load_balancer.ingress;
                if ingress and len(ingress) > 0 {
                    endpoint = ingress[0].hostname or ingress[0].ip;
                    return f"http://{endpoint}";
                }
            } else {
                # NodePort
                node_port = self.k8s_config.node_port;
                return f"http://localhost:{node_port}";
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(f"Could not get service URL for '{app_name}': {e}");
            }
        }
        return None;
    }
}

