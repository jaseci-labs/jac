import base64;
import secrets as _pysecrets;
import from typing { Any }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.config_loader { get_scale_config }

glob PG_PORT = 5432,
     PG_IMAGE = 'postgres:18';


obj KubernetesPostgresProvider {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, any] = {},
        app_name: str postinit,
        connection_string: str = '';

    def postinit {
        self.app_name = self.config.get('app_name', 'jaseci');
    }

    def _db_cfg -> dict {
        return get_scale_config().get_database_config();
    }

    def _mode -> str {
        cfg = self._db_cfg();
        if cfg.get('url') or cfg.get('postgres_url') {
            return 'external';
        }
        return str(cfg.get('deploy_mode') or 'image');
    }

    def _names -> dict[str, str] {
        base = f"{self.app_name}-postgres";
        return {
            'name': base,
            'service': f"{base}-service",
            'secret': f"{base}-secret",
            'volume': f"{base}-data",
            'sa': f"{base}-sa"
        };
    }

    def get_connection_string -> str {
        cfg = self._db_cfg();
        ext = cfg.get('url') or cfg.get('postgres_url');
        if ext {
            return str(ext);
        }
        n = self._names();
        return f"postgresql://jac@{n['service']}:{PG_PORT}/jac";
    }

    def is_available -> bool {
        return True;
    }

    def deploy(config: dict[str, any] = {}) -> dict[str, any] {
        n = self._names();
        mode = self._mode();
        if mode == 'external' {
            return {
                'mode': mode,
                'connection_string': self.get_connection_string(),
                'secret': None,
                'statefulset': None,
                'service': None,
                'service_account': None
            };
        }
        password = _pysecrets.token_urlsafe(24);
        url = f"postgresql://jac:{password}@{n['service']}:{PG_PORT}/jac";
        secret = {
            'apiVersion': 'v1',
            'kind': 'Secret',
            'metadata': {'name': n['secret'], 'labels': {'managed': 'jac-scale'}},
            'type': 'Opaque',
            'stringData': {
                'username': 'jac',
                'password': password,
                'connection-string': url
            }
        };
        service_account = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {'name': n['sa'], 'labels': {'managed': 'jac-scale'}},
            'automountServiceAccountToken': False
        };
        embedded = mode == 'embedded';
        image = (
            str(self.config.get('app_image') or self._db_cfg().get('app_image') or '')
                if embedded
                else str(self._db_cfg().get('postgres_image') or PG_IMAGE)
        );
        container: dict[str, Any] = {
            'name': 'postgres',
            'image': image,
            'securityContext': {
                'runAsNonRoot': True,
                'runAsUser': 999,
                'allowPrivilegeEscalation': False,
                'capabilities': {'drop': ['ALL']},
                'seccompProfile': {'type': 'RuntimeDefault'}
            },
            'ports': [{'containerPort': PG_PORT}],
            'readinessProbe': {
                'exec': {'command': ['pg_isready', '-U', 'jac']},
                'initialDelaySeconds': 5,
                'periodSeconds': 5
            },
            'livenessProbe': {
                'exec': {'command': ['pg_isready', '-U', 'jac']},
                'initialDelaySeconds': 30,
                'periodSeconds': 10
            },
            'volumeMounts': [
                {'name': n['volume'], 'mountPath': '/var/lib/jac/pgdata'},
                {'name': 'dshm', 'mountPath': '/dev/shm'}
            ]
        };
        if embedded {
            container['command'] = ['jac', 'db', 'serve'];
            container['env'] = [
                {'name': 'JAC_PGDATA', 'value': '/var/lib/jac/pgdata/data'},
                {'name': 'JAC_DB_PORT', 'value': str(PG_PORT)},
                {
                    'name': 'POSTGRES_PASSWORD',
                    'valueFrom': {
                        'secretKeyRef': {'name': n['secret'], 'key': 'password'}
                    }
                }
            ];
        } else {
            container['env'] = [
                {'name': 'POSTGRES_USER', 'value': 'jac'},
                {'name': 'POSTGRES_DB', 'value': 'jac'},
                {'name': 'PGDATA', 'value': '/var/lib/jac/pgdata/data'},
                {
                    'name': 'POSTGRES_PASSWORD',
                    'valueFrom': {
                        'secretKeyRef': {'name': n['secret'], 'key': 'password'}
                    }
                }
            ];
        }
        statefulset = {
            'apiVersion': 'apps/v1',
            'kind': 'StatefulSet',
            'metadata': {'name': n['name'], 'labels': {'managed': 'jac-scale'}},
            'spec': {
                'serviceName': n['service'],
                'replicas': 1,
                'selector': {'matchLabels': {'app': n['name']}},
                'template': {
                    'metadata': {'labels': {'app': n['name']}},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'serviceAccountName': n['sa'],
                        'terminationGracePeriodSeconds': 60,
                        'securityContext': {
                            'runAsNonRoot': True,
                            'runAsUser': 999,
                            'fsGroup': 999,
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [container],
                        'volumes': [
                            {
                                'name': 'dshm',
                                'emptyDir': {'medium': 'Memory', 'sizeLimit': '256Mi'}
                            }
                        ]
                    }
                },
                'volumeClaimTemplates': [
                    {
                        'metadata': {'name': n['volume']},
                        'spec': {
                            'accessModes': ['ReadWriteOnce'],
                            'resources': {
                                'requests': {
                                    'storage': str(
                                        self._db_cfg().get('postgres_storage') or '2Gi'
                                    )
                                }
                            }
                        }
                    }
                ]
            }
        };
        service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {'name': n['service'], 'labels': {'managed': 'jac-scale'}},
            'spec': {
                'selector': {'app': n['name']},
                'ports': [{'port': PG_PORT, 'targetPort': PG_PORT}],
                'clusterIP': 'None'
            }
        };
        self.connection_string = url;
        return {
            'mode': mode,
            'connection_string': url,
            'secret': secret,
            'statefulset': statefulset,
            'service': service,
            'service_account': service_account
        };
    }

    def cleanup { }
    def get_init_container(
        app_name: str, wait_image: str
    ) -> (dict[(str, Any)] | None) {
        if self._mode() == 'external' {
            return None;
        }
        n = self._names();
        return {
            'name': 'wait-for-postgres',
            'image': wait_image,
            'securityContext': {
                'runAsNonRoot': True,
                'runAsUser': 1000,
                'readOnlyRootFilesystem': True,
                'allowPrivilegeEscalation': False,
                'capabilities': {'drop': ['ALL']}
            },
            'command': [
                'sh',
                '-c',
                f"until nc -z {n['service']} {PG_PORT}; "
                "do echo waiting for postgres; sleep 3; done"
            ]
        };
    }
}
