def redis_db(app_name: str, env_vars: list) -> tuple[dict, dict]:
    redis_name = f"{app_name}-redis"
    redis_port = 6379
    redis_service_name = f"{redis_name}-service"

    # Redis Deployment (for caching — stateless)
    redis_deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": redis_name},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": redis_name}},
            "template": {
                "metadata": {"labels": {"app": redis_name}},
                "spec": {
                    "containers": [
                        {
                            "name": "redis",
                            "image": "redis:7.2",
                            "ports": [{"containerPort": redis_port}],
                            "args": [
                                "--save",
                                "",
                                "--appendonly",
                                "no",
                            ],  # disable persistence
                            "resources": {
                                "requests": {"cpu": "100m", "memory": "128Mi"},
                                "limits": {"cpu": "500m", "memory": "256Mi"},
                            },
                        }
                    ]
                },
            },
        },
    }

    # Redis Service (ClusterIP by default)
    redis_service = {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {"name": redis_service_name},
        "spec": {
            "type": "NodePort",
            "selector": {"app": redis_name},
            "ports": [
                {
                    "protocol": "TCP",
                    "port": redis_port,
                    "targetPort": redis_port,
                    "nodePort": 32001,
                }
            ],
        },
    }

    # Add Redis connection string to environment
    env_vars.append(
        {
            "name": "REDIS_URL",
            "value": f"redis://{redis_service_name}:{redis_port}/0",
        }
    )

    return redis_deployment, redis_service
