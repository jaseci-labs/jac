"""Kubernetes MongoDB provider implementation."""
import from typing { Any }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }

"""MongoDB provider for Kubernetes deployments."""
class KubernetesMongoProvider(DatabaseProvider) {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, Any] = {},
        app_name: str = '',
        connection_string: str = '';

    def init(
        self: KubernetesMongoProvider,
        target: (DeploymentTarget | None) = None,
        config: dict[str, Any] = {}
    ) -> None {
        self.target = target;
        self.config = config;
        self.app_name = config.get('app_name', 'jaseci');
    }

    def deploy(
        self: KubernetesMongoProvider, config: dict[str, Any] = {}
    ) -> dict[str, Any] {
        mongodb_name = f"{self.app_name}-mongodb";
        mongodb_port = 27017;
        mongodb_service_name = f"{mongodb_name}-service";
        mongodb_volume_name = f"{self.app_name}-mongo-data";

        mongodb_statefulset = {
            'apiVersion': 'apps/v1',
            'kind': 'StatefulSet',
            'metadata': {'name': mongodb_name},
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
                                        'value': 'admin'
                                    },
                                    {
                                        'name': 'MONGO_INITDB_ROOT_PASSWORD',
                                        'value': 'password'
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
            'metadata': {'name': mongodb_service_name},
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

        self.connection_string = f"mongodb://admin:password@{mongodb_service_name}:{mongodb_port}";

        return {
            'deployment': mongodb_statefulset,
            'service': mongodb_service,
            'connection_string': self.connection_string,
            'service_name': mongodb_service_name
        };
    }

    def get_connection_string(self: KubernetesMongoProvider) -> str {
        if not self.connection_string {
            # Generate default connection string
            service_name = f"{self.app_name}-mongodb-service";
            self.connection_string = f"mongodb://admin:password@{service_name}:27017";
        }
        return self.connection_string;
    }

    def is_available(self: KubernetesMongoProvider) -> bool {
        # TODO: Implement actual check
        return True;
    }

    def cleanup(self: KubernetesMongoProvider) -> None {
    # Cleanup is handled by the deployment target
    }

    override def get_init_container(
        self: KubernetesMongoProvider, app_name: str, wait_image: str
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
}
