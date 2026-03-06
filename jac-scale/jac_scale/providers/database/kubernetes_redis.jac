"""Kubernetes Redis provider implementation."""

import hashlib;
import logging;
import from pathlib { Path }
import from typing { Any }
import hashlib;
import base64;
import from jac_scale.abstractions.database_provider { DatabaseProvider }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.config_loader { get_scale_config }

glob logger = logging.getLogger(__name__);

"""Redis provider for Kubernetes deployments."""
obj KubernetesRedisProvider(DatabaseProvider) {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, Any] = {},
        app_name: str by postinit,
        connection_string: str = '';

    def postinit {
        self.app_name = self.config.get('app_name', 'jaseci');
    }

    """Load and generate Redis configuration from template."""
    def _load_redis_config -> str {
        scale_config = get_scale_config();
        db_config = scale_config.get_database_config();

        redis_max_memory = db_config.get('redis_max_memory', '200mb');
        redis_eviction_policy = db_config.get('redis_eviction_policy', 'allkeys-lru');
        redis_eviction_samples = db_config.get('redis_eviction_samples', 5);
        redis_default_ttl = db_config.get('redis_default_ttl', 0);
        redis_enable_keyspace_notifications = db_config.get(
            'redis_enable_keyspace_notifications', False
        );

        valid_policies = [
            'allkeys-lru',
            'volatile-lru',
            'allkeys-lfu',
            'volatile-lfu',
            'allkeys-random',
            'volatile-random',
            'volatile-ttl',
            'noeviction'
        ];
        if redis_eviction_policy not in valid_policies {
            logger.warning(
                f"Invalid Redis eviction policy '{redis_eviction_policy}'. "
                f"Using default 'allkeys-lru'. Valid options: {', '.join(
                    valid_policies
                )}"
            );
            redis_eviction_policy = 'allkeys-lru';
        }

        # Validate eviction samples (must be 1-10)
        try {
            samples = int(redis_eviction_samples);
            if samples < 1 or samples > 10 {
                logger.warning(
                    f"Redis eviction samples {samples} out of range [1-10]. Using default 5."
                );
                redis_eviction_samples = 5;
            } else {
                redis_eviction_samples = samples;
            }
        } except (ValueError, TypeError) {
            logger.warning(f"Invalid eviction samples value. Using default 5.");
            redis_eviction_samples = 5;
        }

        # Validate TTL
        try {
            ttl = int(redis_default_ttl);
            if ttl < 0 {
                logger.warning(
                    f"Redis default TTL {ttl} is negative. Using 0 (no expiration)."
                );
                redis_default_ttl = 0;
            } else {
                redis_default_ttl = ttl;
            }
        } except (ValueError, TypeError) {
            logger.warning(f"Invalid TTL value. Using default 0 (no expiration).");
            redis_default_ttl = 0;
        }

        # Configure keyspace notifications
        if redis_enable_keyspace_notifications {
            redis_keyspace_events_line = '\nnotify-keyspace-events Ex';
            logger.info("Redis keyspace notifications enabled for expired events");
        } else {
            redis_keyspace_events_line = '';
        }

        # Load template file with error handling
        try {
            template_path = Path(__file__).parent / 'redis.conf.template';
            if not template_path.exists() {
                raise FileNotFoundError(
                    f"Redis config template not found at: {template_path}\n"
                    f"Please ensure redis.conf.template exists in the same directory."
                );
            }

            template_content = template_path.read_text(encoding='utf-8');
            logger.debug(f"Loaded Redis config template from {template_path}");
        } except FileNotFoundError as e {
            logger.error(f"Redis config template missing: {e}");
            raise;
        } except PermissionError as e {
            logger.error(f"Permission denied reading Redis config template: {e}");
            raise ValueError(f"Cannot read Redis config template: {e}");
        } except Exception as e {
            logger.error(f"Unexpected error reading Redis config template: {e}");
            raise ValueError(f"Failed to load Redis config template: {e}");
        }

        # Populate template with configuration values
        try {
            config_content = template_content.format(
                redis_max_memory=redis_max_memory,
                redis_eviction_policy=redis_eviction_policy,
                redis_eviction_samples=redis_eviction_samples,
                redis_keyspace_events_line=redis_keyspace_events_line
            );

            ttl_info = f"TTL={redis_default_ttl}s"
                if redis_default_ttl > 0
                else "no TTL";
            keyspace_info = "enabled"
                if redis_enable_keyspace_notifications
                else "disabled";
            logger.info(
                f"Generated Redis config: maxmemory={redis_max_memory}, "
                f"policy={redis_eviction_policy}, samples={redis_eviction_samples}, "
                f"{ttl_info}, keyspace_events={keyspace_info}"
            );

            return config_content;
        } except KeyError as e {
            logger.error(f"Missing template variable in redis.conf.template: {e}");
            raise ValueError(f"Invalid Redis config template - missing variable: {e}");
        } except Exception as e {
            logger.error(f"Error populating Redis config template: {e}");
            raise ValueError(f"Failed to generate Redis config: {e}");
        }
    }

    """Calculate hash of Redis configuration for change detection."""
    def _calculate_config_hash(config_content: str) -> str {
        config_bytes = config_content.encode('utf-8');
        hash_obj = hashlib.md5(config_bytes);
        # Return first 8 chars for brevity (sufficient for change detection)
        return hash_obj.hexdigest()[:8];
    }

    def deploy(config: dict[str, Any] = {}) -> dict[str, Any] {
        redis_name = f"{self.app_name}-redis";
        redis_port = 6379;
        redis_service_name = f"{redis_name}-service";
        redis_config_name = f"{redis_name}-config";

        # Get configuration values
        scale_config = get_scale_config();
        db_config = scale_config.get_database_config();
        redis_default_ttl = db_config.get('redis_default_ttl', 0);
        redis_enable_keyspace_notifications = db_config.get(
            'redis_enable_keyspace_notifications', False
        );

        # Load and generate Redis configuration
        redis_conf_content = self._load_redis_config();
        config_hash = self._calculate_config_hash(redis_conf_content);

        logger.debug(f"Redis config hash: {config_hash}");

        # Create ConfigMap for redis.conf
        redis_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': redis_config_name,
                'labels': {
                    'app': redis_name,
                    'component': 'cache',
                    'managed-by': 'jac-scale'
                },
                'annotations': {
                    'config-hash': config_hash,
                    'description': 'Redis L2 cache configuration with eviction and TTL support'
                }
            },
            'data': {'redis.conf': redis_conf_content}
        };

        # Create Redis Deployment
        redis_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': redis_name,
                'labels': {
                    'app': redis_name,
                    'component': 'cache',
                    'managed-by': 'jac-scale'
                }
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': redis_name}},
                'template': {
                    'metadata': {
                        'labels': {'app': redis_name, 'component': 'cache'},
                        'annotations': {
                            # This annotation triggers pod restart when config changes
                            'redis-config-hash': config_hash,
                            'description': 'Redis L2 cache with eviction and TTL support'
                        }
                    },
                    'spec': {
                        'containers': [
                            {
                                'name': 'redis',
                                'image': 'redis:7.2',
                                'ports': [
                                    {'containerPort': redis_port, 'name': 'redis'}
                                ],
                                'command': ['redis-server', '/etc/redis/redis.conf'],
                                'volumeMounts': [
                                    {
                                        'name': 'redis-config',
                                        'mountPath': '/etc/redis',
                                        'readOnly': True
                                    }
                                ],
                                'resources': {
                                    'requests': {'cpu': '100m', 'memory': '128Mi'},
                                    'limits': {'cpu': '500m', 'memory': '256Mi'}
                                },
                                'livenessProbe': {
                                    'tcpSocket': {'port': redis_port},
                                    'initialDelaySeconds': 10,
                                    'periodSeconds': 10,
                                    'timeoutSeconds': 5,
                                    'failureThreshold': 3
                                },
                                'readinessProbe': {
                                    'exec': {'command': ['redis-cli', 'ping']},
                                    'initialDelaySeconds': 5,
                                    'periodSeconds': 5,
                                    'timeoutSeconds': 3,
                                    'failureThreshold': 3
                                }
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'redis-config',
                                'configMap': {'name': redis_config_name}
                            }
                        ]
                    }
                }
            }
        };

        redis_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': redis_service_name,
                'labels': {
                    'app': redis_name,
                    'component': 'cache',
                    'managed-by': 'jac-scale'
                }
            },
            'spec': {
                'selector': {'app': redis_name},
                'ports': [
                    {
                        'protocol': 'TCP',
                        'port': redis_port,
                        'targetPort': redis_port,
                        'name': 'redis'
                    }
                ],
                'type': 'ClusterIP'
            }
        };

        self.connection_string = f"redis://{redis_service_name}:{redis_port}/0";

        logger.info(
            f"Prepared Redis deployment: {redis_name} "
            f"(connection: {self.connection_string}, config hash: {config_hash})"
        );

        return {
            'configmap': redis_configmap,
            'deployment': redis_deployment,
            'service': redis_service,
            'connection_string': self.connection_string,
            'service_name': redis_service_name,
            'config_hash': config_hash,
            'default_ttl': redis_default_ttl,
            'keyspace_notifications_enabled': redis_enable_keyspace_notifications
        };
    }

    def get_connection_string -> str {
        if not self.connection_string {
            # Generate default connection string
            service_name = f"{self.app_name}-redis-service";
            self.connection_string = f"redis://{service_name}:6379/0";
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
            'name': 'wait-for-redis',
            'image': wait_image,
            'command': [
                'sh',
                '-c',
                f"until nc -z {app_name}-redis-service 6379; do echo waiting for redis; sleep 3; done"
            ]
        };
    }

    """Return RedisInsight dashboard resource specs.

    Returns deployment and service specs for the caller to apply via the K8s API.
    Follows the same pattern as deploy(): pure spec construction, no API calls.

    When insight_htpasswd is provided (htpasswd-formatted string, e.g. the output
    of `htpasswd -nB admin mypassword`), an nginx sidecar is injected that enforces
    HTTP basic auth in front of RedisInsight. This works identically for local
    NodePort, AWS NLB, and Ingress (ClusterIP) deployments.
    """
    def deploy_dashboard(
        cluster_env: str,
        node_port: int,
        ingress_enabled: bool = False,
        username: str = '',
        password: str = ''
    ) -> dict[str, Any] {
        redis_service_name = f"{self.app_name}-redis-service";
        insight_name = f"{self.app_name}-redis-insight";
        auth_enabled = bool(username and password);

        # Generate htpasswd entry using SHA1 (no external deps required).
        # Format: username:{SHA}base64(sha1(password))
        if auth_enabled {
            pw_hash = base64.b64encode(
                hashlib.sha1(password.encode('utf-8')).digest()
            ).decode(
                'utf-8'
            );
            insight_htpasswd = f"{username}:{{SHA}}{pw_hash}";
        }

        # When auth is on, nginx sidecar listens on 8080 and proxies to localhost:5540.
        # The service targets this port so auth is enforced for all access paths.
        service_port = 8080 if auth_enabled else 5540;

        # RedisInsight v3 supports RI_REDIS_HOST / RI_REDIS_PORT env vars to
        # pre-seed a database connection on first start (no manual setup needed).
        containers = [
            {
                'name': 'redisinsight',
                'image': 'redis/redisinsight:3.2.0',
                'ports': [{'containerPort': 5540}],
                'env': [
                    {'name': 'RI_REDIS_HOST', 'value': redis_service_name},
                    {'name': 'RI_REDIS_PORT', 'value': '6379'},
                    {'name': 'RI_REDIS_ALIAS', 'value': 'Jaseci Redis'}
                ],
                'resources': {
                    'requests': {'cpu': '100m', 'memory': '128Mi'},
                    'limits': {'cpu': '500m', 'memory': '512Mi'}
                }
            }
        ];

        pod_spec = {'containers': containers};

        if auth_enabled {
            nginx_config_name = f"{insight_name}-nginx-config";
            auth_secret_name = f"{insight_name}-auth";

            nginx_conf = """server {
    listen 8080;
    location / {
        auth_basic "RedisInsight";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://localhost:5540;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}""";

            nginx_configmap = {
                'apiVersion': 'v1',
                'kind': 'ConfigMap',
                'metadata': {
                    'name': nginx_config_name,
                    'labels': {'app': insight_name, 'managed': 'jac-scale'}
                },
                'data': {'nginx.conf': nginx_conf}
            };

            auth_secret = {
                'apiVersion': 'v1',
                'kind': 'Secret',
                'metadata': {
                    'name': auth_secret_name,
                    'labels': {'app': insight_name, 'managed': 'jac-scale'}
                },
                'stringData': {'.htpasswd': insight_htpasswd}
            };

            containers.append(
                {
                    'name': 'nginx-auth',
                    'image': 'nginx:1.27-alpine',
                    'ports': [{'containerPort': 8080}],
                    'volumeMounts': [
                        {
                            'name': 'nginx-config',
                            'mountPath': '/etc/nginx/conf.d/default.conf',
                            'subPath': 'nginx.conf'
                        },
                        {
                            'name': 'htpasswd',
                            'mountPath': '/etc/nginx/.htpasswd',
                            'subPath': '.htpasswd'
                        }
                    ],
                    'resources': {
                        'requests': {'cpu': '50m', 'memory': '32Mi'},
                        'limits': {'cpu': '100m', 'memory': '64Mi'}
                    }
                }
            );

            pod_spec['volumes'] = [
                {'name': 'nginx-config', 'configMap': {'name': nginx_config_name}},
                {'name': 'htpasswd', 'secret': {'secretName': auth_secret_name}}
            ];
        }

        insight_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': insight_name,
                'labels': {'app': insight_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': insight_name}},
                'template': {
                    'metadata': {'labels': {'app': insight_name}},
                    'spec': pod_spec
                }
            }
        };

        if ingress_enabled {
            insight_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{insight_name}-service",
                    'labels': {'app': insight_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'type': 'ClusterIP',
                    'selector': {'app': insight_name},
                    'ports': [
                        {
                            'protocol': 'TCP',
                            'port': service_port,
                            'targetPort': service_port
                        }
                    ]
                }
            };
        } elif cluster_env == 'aws' {
            insight_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{insight_name}-service",
                    'labels': {'app': insight_name, 'managed': 'jac-scale'},
                    'annotations': {
                        'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb',
                        'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing'
                    }
                },
                'spec': {
                    'type': 'LoadBalancer',
                    'selector': {'app': insight_name},
                    'ports': [
                        {'protocol': 'TCP', 'port': 80, 'targetPort': service_port}
                    ]
                }
            };
        } else {
            insight_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{insight_name}-service",
                    'labels': {'app': insight_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'type': 'NodePort',
                    'selector': {'app': insight_name},
                    'ports': [
                        {
                            'protocol': 'TCP',
                            'port': service_port,
                            'targetPort': service_port,
                            'nodePort': node_port
                        }
                    ]
                }
            };
        }

        result = {
            'deployment': insight_deployment,
            'service': insight_service,
            'deployment_name': insight_name,
            'service_name': f"{insight_name}-service"
        };

        if auth_enabled {
            result['auth_configmap'] = nginx_configmap;
            result['auth_secret'] = auth_secret;
        }

        return result;
    }
}
