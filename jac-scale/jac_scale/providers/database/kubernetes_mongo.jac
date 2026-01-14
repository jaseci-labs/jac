"""Kubernetes MongoDB provider implementation."""
import from typing { Any }
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.kubernetes.database.mongo { mongo_db }

"""MongoDB provider for Kubernetes deployments."""
class KubernetesMongoProvider(DatabaseProvider) {
    has target: (DeploymentTarget | None) = None;
    has config: dict[str, Any] = {};
    has app_name: str = '';
    has connection_string: str = '';

    def init(
        self: KubernetesMongoProvider,
        target: (DeploymentTarget | None) = None,
        config: dict[str, Any] = {}
    ) -> None {
        self.target = target;
        self.config = config;
        self.app_name = config.get('app_name', 'jaseci');
    }

    def deploy(self: KubernetesMongoProvider, config: dict[str, Any] = {}) -> dict[str, Any] {
        env_vars: list = [];
        (deployment, service) = mongo_db(self.app_name, env_vars);
        # Extract connection string from env_vars
        for env_var in env_vars {
            if env_var.get('name') == 'MONGODB_URI' {
                self.connection_string = env_var.get('value', '');
                break;
            }
        }
        return {
            'deployment': deployment,
            'service': service,
            'connection_string': self.connection_string,
            'service_name': f"{self.app_name}-mongodb-service"
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
        pass;
    }
    
    override def get_init_container(self: KubernetesMongoProvider, app_name: str, wait_image: str) -> (dict[(str, Any)] | None) {
        return {
            'name': 'wait-for-mongodb',
            'image': wait_image,
            'command': [
                'sh', '-c',
                f"until nc -z {app_name}-mongodb-service 27017; do echo waiting for mongodb; sleep 3; done"
            ]
        };
    }
}

