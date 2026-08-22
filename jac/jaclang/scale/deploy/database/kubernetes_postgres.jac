import base64;
import os;
import secrets as _pysecrets;
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.config_loader { get_scale_config }

glob PG_PORT = 5432,
     PG_IMAGE = 'postgres:18',
     POD_NAMESPACE_FILE = '/var/run/secrets/kubernetes.io/serviceaccount/namespace',
     CLUSTER_DNS_SUFFIX = 'svc.cluster.local';


obj KubernetesPostgresProvider {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, any] = {},
        app_name: str postinit,
        connection_string: str = '';

    def postinit {
        self.app_name = self.config.get('app_name', 'jaseci');
    }

    def _db_cfg -> dict {
        return get_scale_config().get_deploy_database_config();
    }

    def _requested_mode -> str {
        import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
            resolve_database_mode
        }
        return resolve_database_mode(self.config);
    }

    def _configured_url -> str {
        explicit = str(self.config.get('database_url') or '').strip();
        if explicit {
            return explicit;
        }
        return str(self._db_cfg().get('url') or '').strip();
    }

    def _source_namespace -> str {
        explicit = str(self.config.get('database_namespace') or '').strip();
        if explicit {
            return explicit;
        }
        from_env = str(os.environ.get('POD_NAMESPACE') or '').strip();
        if from_env {
            return from_env;
        }
        try {
            with open(POD_NAMESPACE_FILE) as handle {
                return handle.read().strip();
            }
        } except OSError {
            return '';
        }
    }

    def _qualify_external_url(url: str) -> str {
        import from urllib.parse { urlsplit, urlunsplit }
        parts = urlsplit(url);
        host = str(parts.hostname or '');
        if not host or '.' in host or ':' in host or host == 'localhost' {
            return url;
        }
        target_ns = str(self.config.get('namespace') or '').strip();
        source_ns = self._source_namespace();
        if not source_ns {
            raise ValueError(
                f"External database host '{host}' is a bare Kubernetes service "
                "name, which only resolves inside the namespace that owns it, "
                f"and this deploy targets namespace '{target_ns or 'default'}'. "
                "The deployed pod would fail DNS resolution on startup. Either "
                "write the fully qualified host (for example "
                f"'{host}.<namespace>.{CLUSTER_DNS_SUFFIX}'), or set "
                "[scale.kubernetes] database_namespace to the namespace that "
                f"runs '{host}'."
            );
        }
        if not target_ns or source_ns == target_ns {
            return url;
        }
        userinfo = '';
        if parts.username {
            userinfo = str(parts.username);
            if parts.password {
                userinfo = f"{userinfo}:{parts.password}";
            }
            userinfo = f"{userinfo}@";
        }
        port = f":{parts.port}" if parts.port else '';
        netloc = f"{userinfo}{host}.{source_ns}.{CLUSTER_DNS_SUFFIX}{port}";
        return urlunsplit(
            (parts.scheme, netloc, parts.path, parts.query, parts.fragment)
        );
    }

    def _intent -> dict[str, str] {
        requested = self._requested_mode();
        if requested == 'none' {
            return {'mode': 'none', 'url': ''};
        }
        deploy_mode = str(self._db_cfg().get('deploy_mode') or 'image').strip().lower();
        url = self._configured_url();
        wants_external = requested == 'external'
            or (requested == 'auto' and (bool(url) or deploy_mode == 'external'));
        if wants_external {
            if not url {
                raise ValueError(
                    "An external database was requested for this deploy but no "
                    "url was given. Set [scale.kubernetes] database_url, or "
                    "[scale.database] url, or use database_mode = \"provision\" "
                    "to get a per-app Postgres. The deploying process's "
                    "JAC_DB_URL is deliberately not consulted here."
                );
            }
            return {'mode': 'external', 'url': self._qualify_external_url(url)};
        }
        if deploy_mode not in ('image', 'embedded') {
            deploy_mode = 'image';
        }
        return {'mode': deploy_mode, 'url': ''};
    }

    def _mode -> str {
        return self._intent()['mode'];
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
        intent = self._intent();
        if intent['mode'] == 'external' {
            return intent['url'];
        }
        n = self._names();
        return f"postgresql://jac@{n['service']}:{PG_PORT}/jac";
    }

    def is_available -> bool {
        return True;
    }

    def deploy(config: dict[str, any] = {}) -> dict[str, any] {
        n = self._names();
        intent = self._intent();
        mode = intent['mode'];
        if mode in ('external', 'none') {
            return {
                'mode': mode,
                'connection_string': intent['url'],
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
        container: dict[str, any] = {
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
            import from jaclang.runtimelib.pgembed { pg_tuning_settings }
            server_args: list[str] = ['postgres'];
            for (setting, value) in pg_tuning_settings().items() {
                server_args.extend(['-c', f"{setting}={value}"]);
            }
            container['args'] = server_args;
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
    ) -> (dict[(str, any)] | None) {
        if self._mode() in ('external', 'none') {
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
