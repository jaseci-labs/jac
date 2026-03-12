"""Kubernetes MongoDB provider implementation."""
import from typing { Any }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.config_loader { get_scale_config }

"""MongoDB provider for Kubernetes deployments."""
obj KubernetesMongoProvider(DatabaseProvider) {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, Any] = {},
        app_name: str by postinit,
        connection_string: str = '';

    def postinit {
        self.app_name = self.config.get('app_name', 'jaseci');
    }

    def deploy(config: dict[str, Any] = {}) -> dict[str, Any] {
        mongodb_name = f"{self.app_name}-mongodb";
        mongodb_port = 27017;
        mongodb_service_name = f"{mongodb_name}-service";
        mongodb_volume_name = f"{self.app_name}-mongo-data";
        mongodb_secret_name = f"{mongodb_name}-secret";

        scale_config = get_scale_config();
        k8s_config = scale_config.get_kubernetes_config();
        mongodb_username = k8s_config.get('mongodb_root_username', 'admin');
        mongodb_password = k8s_config.get('mongodb_root_password', 'password');
        connection_string = f"mongodb://{mongodb_username}:{mongodb_password}@{mongodb_service_name}:{mongodb_port}";

        mongodb_secret = {
            'apiVersion': 'v1',
            'kind': 'Secret',
            'metadata': {
                'name': mongodb_secret_name,
                'labels': {'managed': 'jac-scale'}
            },
            'stringData': {
                'username': mongodb_username,
                'password': mongodb_password,
                'connection-string': connection_string
            }
        };

        mongodb_statefulset = {
            'apiVersion': 'apps/v1',
            'kind': 'StatefulSet',
            'metadata': {'name': mongodb_name, 'labels': {'managed': 'jac-scale'}},
            'spec': {
                'serviceName': mongodb_service_name,
                'replicas': 1,
                'selector': {'matchLabels': {'app': mongodb_name}},
                'template': {
                    'metadata': {'labels': {'app': mongodb_name}},
                    'spec': {
                        'containers': [
                            {
                                'name': 'mongodb',
                                'image': 'mongo:6.0',
                                'ports': [{'containerPort': mongodb_port}],
                                'env': [
                                    {
                                        'name': 'MONGO_INITDB_ROOT_USERNAME',
                                        'valueFrom': {
                                            'secretKeyRef': {
                                                'name': mongodb_secret_name,
                                                'key': 'username'
                                            }
                                        }
                                    },
                                    {
                                        'name': 'MONGO_INITDB_ROOT_PASSWORD',
                                        'valueFrom': {
                                            'secretKeyRef': {
                                                'name': mongodb_secret_name,
                                                'key': 'password'
                                            }
                                        }
                                    }
                                ],
                                'volumeMounts': [
                                    {
                                        'name': mongodb_volume_name,
                                        'mountPath': '/data/db'
                                    }
                                ]
                            }
                        ]
                    }
                },
                'volumeClaimTemplates': [
                    {
                        'metadata': {'name': mongodb_volume_name},
                        'spec': {
                            'accessModes': ['ReadWriteOnce'],
                            'resources': {'requests': {'storage': '1Gi'}}
                        }
                    }
                ]
            }
        };

        mongodb_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': mongodb_service_name,
                'labels': {'managed': 'jac-scale'}
            },
            'spec': {
                'clusterIP': 'None',
                'selector': {'app': mongodb_name},
                'ports': [
                    {
                        'protocol': 'TCP',
                        'port': mongodb_port,
                        'targetPort': mongodb_port
                    }
                ]
            }
        };

        self.connection_string = connection_string;

        return {
            'secret': mongodb_secret,
            'deployment': mongodb_statefulset,
            'service': mongodb_service,
            'connection_string': self.connection_string,
            'secret_name': mongodb_secret_name,
            'service_name': mongodb_service_name
        };
    }

    def get_connection_string -> str {
        if not self.connection_string {
            scale_config = get_scale_config();
            k8s_config = scale_config.get_kubernetes_config();
            mongodb_username = k8s_config.get('mongodb_root_username', 'admin');
            mongodb_password = k8s_config.get('mongodb_root_password', 'password');
            service_name = f"{self.app_name}-mongodb-service";
            self.connection_string = f"mongodb://{mongodb_username}:{mongodb_password}@{service_name}:27017";
        }
        return self.connection_string;
    }

    def is_available -> bool {
        # TODO: Implement actual check
        return True;
    }

    def cleanup -> None {
    # Cleanup is handled by the deployment target
    }

    override def get_init_container(
        app_name: str, wait_image: str
    ) -> (dict[(str, Any)] | None) {
        return {
            'name': 'wait-for-mongodb',
            'image': wait_image,
            'command': [
                'sh',
                '-c',
                f"until nc -z {app_name}-mongodb-service 27017; do echo waiting for mongodb; sleep 3; done"
            ]
        };
    }

    """Return mongo-express dashboard resource specs.

    Returns deployment and service specs for the caller to apply via the K8s API.
    Follows the same pattern as deploy(): pure spec construction, no API calls.
    """
    def deploy_dashboard(
        username: str = 'admin', password: str = 'admin'
    ) -> dict[str, Any] {
        mongodb_service_name = f"{self.app_name}-mongodb-service";
        mongodb_secret_name = f"{self.app_name}-mongodb-secret";
        express_name = f"{self.app_name}-mongo-express";

        express_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': express_name,
                'labels': {'app': express_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': express_name}},
                'template': {
                    'metadata': {'labels': {'app': express_name}},
                    'spec': {
                        'containers': [
                            {
                                'name': 'mongo-express',
                                'image': 'mongo-express:1.0.2-20',
                                'ports': [{'containerPort': 8081}],
                                'env': [
                                    {
                                        'name': 'ME_CONFIG_MONGODB_SERVER',
                                        'value': mongodb_service_name
                                    },
                                    {
                                        'name': 'ME_CONFIG_MONGODB_PORT',
                                        'value': '27017'
                                    },
                                    {
                                        'name': 'ME_CONFIG_MONGODB_ADMINUSERNAME',
                                        'valueFrom': {
                                            'secretKeyRef': {
                                                'name': mongodb_secret_name,
                                                'key': 'username'
                                            }
                                        }
                                    },
                                    {
                                        'name': 'ME_CONFIG_MONGODB_ADMINPASSWORD',
                                        'valueFrom': {
                                            'secretKeyRef': {
                                                'name': mongodb_secret_name,
                                                'key': 'password'
                                            }
                                        }
                                    },
                                    {'name': 'ME_CONFIG_BASICAUTH', 'value': 'true'},
                                    {
                                        'name': 'ME_CONFIG_BASICAUTH_USERNAME',
                                        'value': username
                                    },
                                    {
                                        'name': 'ME_CONFIG_BASICAUTH_PASSWORD',
                                        'value': password
                                    },
                                    {
                                        'name': 'ME_CONFIG_SITE_BASEURL',
                                        'value': '/db-dashboard/'
                                    }
                                ],
                                'resources': {
                                    'requests': {'cpu': '100m', 'memory': '128Mi'},
                                    'limits': {'cpu': '500m', 'memory': '256Mi'}
                                }
                            }
                        ]
                    }
                }
            }
        };

        # Service: always ClusterIP — exposed via NGINX Ingress at /db-dashboard
        express_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{express_name}-service",
                'labels': {'app': express_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': express_name},
                'ports': [{'protocol': 'TCP', 'port': 8081, 'targetPort': 8081}]
            }
        };

        return {
            'deployment': express_deployment,
            'service': express_service,
            'deployment_name': express_name,
            'service_name': f"{express_name}-service"
        };
    }
}
