impl mongo_db(app_name: str, env_vars: list) -> tuple[dict, dict] {
    mongodb_name = f"{app_name}-mongodb";
    mongodb_port = 27017;
    mongodb_service_name = f"{mongodb_name}-service";
    mongodb_volume_name = f"{app_name}-mongo-data";
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
                                {'name': mongodb_volume_name, 'mountPath': '/data/db'}
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
                {'protocol': 'TCP', 'port': mongodb_port, 'targetPort': mongodb_port}
            ]
        }
    };
    env_vars.append(
        {
            'name': 'MONGODB_URI',
            'value': f"mongodb://admin:password@{mongodb_service_name}:{mongodb_port}"
        }
    );
    return (mongodb_statefulset, mongodb_service);
}
