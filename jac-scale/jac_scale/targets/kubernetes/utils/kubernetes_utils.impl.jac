import os;
import pathlib;

impl parse_cpu_quantity(quantity: str) -> float {
    trimmed = quantity.strip();
    if (trimmed == '') {
        raise ValueError('CPU quantity cannot be empty.') ;
    }
    lower = trimmed.lower();
    if lower.endswith('m') {
        value = lower[:-1].strip();
        if (value == '') {
            raise ValueError(
                f"CPU quantity '{quantity}' is missing a numeric component."
            ) ;
        }
        return float(value) / 1000.0;
    }
    return float(trimmed);
}

impl parse_memory_quantity(quantity: str) -> float {
    trimmed = quantity.strip();
    if (trimmed == '') {
        raise ValueError('Memory quantity cannot be empty.') ;
    }
    suffixes = [
        ('EI', float(1024 ** 6)),
        ('PI', float(1024 ** 5)),
        ('TI', float(1024 ** 4)),
        ('GI', float(1024 ** 3)),
        ('MI', float(1024 ** 2)),
        ('KI', float(1024)),
        ('E', float(10 ** 18)),
        ('P', float(10 ** 15)),
        ('T', float(10 ** 12)),
        ('G', float(10 ** 9)),
        ('M', float(10 ** 6)),
        ('K', float(10 ** 3))
    ];
    upper = trimmed.upper();
    for (unit, multiplier) in suffixes {
        if upper.endswith(unit) {
            number_part = trimmed[:(-len(unit))].strip();
            if (number_part == '') {
                raise ValueError(
                    f"Memory quantity '{quantity}' is missing a numeric component."
                ) ;
            }
            return float(number_part) * multiplier;
        }
    }
    return float(trimmed);
}

impl validate_resource_limits(
    cpu_request: (str | None),
    cpu_limit: (str | None),
    memory_request: (str | None),
    memory_limit: (str | None)
) -> None {
    if (cpu_request and cpu_limit) {
        try {
            cpu_request_value = parse_cpu_quantity(cpu_request);
            cpu_limit_value = parse_cpu_quantity(cpu_limit);
        } except ValueError as exc {
            raise ValueError(f"Invalid CPU quantity: {exc}") ;
        }
        if (cpu_limit_value < cpu_request_value) {
            raise ValueError(
                f"K8s_CPU_LIMIT ({cpu_limit}) must not be lower than K8s_CPU_REQUEST ({cpu_request})."
            ) ;
        }
    }
    if (memory_request and memory_limit) {
        try {
            memory_request_value = parse_memory_quantity(memory_request);
            memory_limit_value = parse_memory_quantity(memory_limit);
        } except ValueError as exc {
            raise ValueError(f"Invalid memory quantity: {exc}") ;
        }
        if (memory_limit_value < memory_request_value) {
            raise ValueError(
                f"K8s_MEMORY_LIMIT ({memory_limit}) must not be lower than K8s_MEMORY_REQUEST ({memory_request})."
            ) ;
        }
    }
}

"""Stage the application code inside the PVC using a transient helper pod."""
impl sync_code_to_pvc(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    code_folder: str,
    app_name: str,
    sync_image: str
) -> None {
    import tempfile;
    import from pathlib { Path }
    sync_pod_name = f"{app_name}-code-sync";
    same_directory_toml_path = os.path.join(code_folder, 'jac.toml');
    pod_body = {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': sync_pod_name},
        'spec': {
            'restartPolicy': 'Never',
            'containers': [
                {
                    'name': 'sync',
                    'image': sync_image,
                    'command': ['sh', '-c', 'sleep 3600'],
                    'volumeMounts': [{'name': 'code', 'mountPath': '/data'}]
                }
            ],
            'volumes': [
                {'name': 'code', 'persistentVolumeClaim': {'claimName': pvc_name}}
            ]
        }
    };
    try {
        core_v1.create_namespaced_pod(namespace, pod_body);
    } except ApiException as exc {
        if (exc.status == 409) {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
            core_v1.create_namespaced_pod(namespace, pod_body);
        } else {
            raise ;
        }
    }
    wait_for_pod_phase(core_v1, namespace, sync_pod_name, {'Running'});
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as temp_tar {
        temp_tar_path = Path(temp_tar.name);
    }
    try {
        create_tarball(code_folder, str(temp_tar_path));
        run_kubectl_command(
            [
                'exec',
                '-n',
                namespace,
                sync_pod_name,
                '--',
                'sh',
                '-c',
                'rm -rf /data/* && mkdir -p /data/workspace'
            ]
        );
        run_kubectl_command(
            [
                'cp',
                '-n',
                namespace,
                temp_tar_path.name,
                f"{sync_pod_name}:/tmp/jaseci-code.tar.gz"
            ],
            cwd=temp_tar_path.parent
        );
        run_kubectl_command(
            [
                'exec',
                '-n',
                namespace,
                sync_pod_name,
                '--',
                'sh',
                '-c',
                'tar -xzf /tmp/jaseci-code.tar.gz -C /data/workspace && rm -f /tmp/jaseci-code.tar.gz'
            ]
        );

        if os.path.isfile(same_directory_toml_path) {
            run_kubectl_command(
                [
                    'cp',
                    '-n',
                    namespace,
                    "jac.toml",
                    f"{sync_pod_name}:/data/workspace/jac.toml"
                ],
                cwd=code_folder
            );
        } else {
            print("jac.toml file not found");
        }
    } finally {
        temp_tar_path.unlink(missing_ok=True);
        try {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
        } except ApiException as exc {
            if (exc.status != 404) {
                raise ;
            }
        }
    }
}

"""Execute a kubectl command and surface useful error details."""
impl run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None {
    import shutil;
    import subprocess;
    if (shutil.which('kubectl') is None) {
        raise RuntimeError('kubectl is required to sync code to the PVC.') ;
    }
    try {
        subprocess.run(
            ['kubectl', *args], check=True, text=True, cwd=str(cwd) if cwd else None
        );
    } except subprocess.CalledProcessError as exc {
        raise exc from RuntimeError(
            f"kubectl command failed: {' '.join(['kubectl', *args])}"
        ) ;
    }
}

"""Block until the pod disappears from the API."""
impl wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None {
    start_time = time.time();
    while ((time.time() - start_time) < timeout) {
        try {
            core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                return;
            }
            raise ;
        }
        time.sleep(2);
    }
    raise TimeoutError(f"Timed out waiting for pod '{pod_name}' deletion.") ;
}

"""Poll the pod until it reaches one of the desired phases."""
impl wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None {
    start_time = time.time();
    while ((time.time() - start_time) < timeout) {
        try {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                time.sleep(2);
                continue;
            }
            raise ;
        }
        phase = (pod.status.phase or '').strip();
        if (phase in target_phases) {
            return;
        }
        if (phase == 'Failed') {
            raise RuntimeError(f"Sync pod '{pod_name}' entered Failed state.") ;
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}."
    ) ;
}

"""Create a PersistentVolumeClaim if it does not already exist."""
impl ensure_pvc_exists(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    storage_size: str,
    storage_class: (str | None) = None,
    access_mode: str = 'ReadWriteOnce'
) -> None {
    try {
        core_v1.read_namespaced_persistent_volume_claim(pvc_name, namespace);
        return;
    } except ApiException as exc {
        if (exc.status != 404) {
            raise ;
        }
    }
    import from typing { Any }
    pvc_body: dict[(str, Any)] = {
        'apiVersion': 'v1',
        'kind': 'PersistentVolumeClaim',
        'metadata': {'name': pvc_name},
        'spec': {
            'accessModes': [access_mode],
            'resources': {'requests': {'storage': storage_size}}
        }
    };
    if storage_class {
        pvc_body['spec']['storageClassName'] = storage_class;
    }
    core_v1.create_namespaced_persistent_volume_claim(namespace, pvc_body);
}

"""
Detect if the current connected cluster is AWS or local.

    Returns:
        'aws' for AWS EKS clusters, 'local' for local/other clusters.
"""
impl cluster_type -> str {
    try {
        import from kubernetes { client }
        v1 = client.CoreV1Api();
        nodes = v1.list_node();
        if not nodes.items {
            return 'local';
        }
        for <>node in nodes.items {
            provider_id = <>node.spec.provider_id or '';
            if provider_id.startswith('aws://') {
                return 'aws';
            }
        }
        for <>node in nodes.items {
            labels = <>node.metadata.labels or {};
            if (
                ('topology.kubernetes.io/region' in labels)
                and <>any(
                    (region in labels.get('topology.kubernetes.io/region', ''))
                    for region in ['us-', 'eu-', 'ap-', 'ca-', 'sa-']
                )
                and (
                    ('karpenter.sh/provisioner-name' in labels)
                    or (
                        ('kubernetes.io/os' in labels)
                        and ('node.kubernetes.io/instance-type' in labels)
                    )
                )
            ) {
                return 'aws';
            }
        }
        return 'local';
    } except Exception {
        return 'local';
    }
}

"""
    Wait for a service to become available.

    Can work with either NodePort (localhost:node_port) or NLB (AWS Load Balancer URL).
    If nlb_url is provided, it will be used. Otherwise, localhost:node_port will be used.
"""
impl check_deployment_status(
    node_port: int,
    path: str = '/docs',
    interval: int = 15,
    max_retries: int = 30,
    nlb_url: (str | None) = None
) -> bool {
    if nlb_url {
        url = f"{nlb_url.rstrip('/')}{path}";
    } else {
        url = f"http://localhost:{node_port}{path}";
    }
    for attempt in range(1, (max_retries + 1)) {
        try {
            response = requests.get(url, timeout=10);
            if (response.status_code == 200) {
                print(f"Service is available at: {url}");
                return True;
            }
        } except RequestException as e {
            if (attempt == max_retries) {
                print(f"Failed to connect to {url}: {e}");
            }
        }
        if (attempt < max_retries) {
            time.sleep(interval);
        }
    }
    return False;
}

"""Create or update ConfigMap with binary tar.gz using Kubernetes API."""
impl create_or_update_configmap(
    namespace: str, configmap_name: str, tar_path: str
) -> None {
    config.load_kube_config();
    v1 = client.CoreV1Api();
    with open(tar_path, 'rb') as f {
        encoded_data = base64.b64encode(f.read()).decode('utf-8');
    }
    body = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(name=configmap_name),
        binary_data={'jaseci-code.tar.gz': encoded_data}
    );
    try {
        existing = v1.read_namespaced_config_map(configmap_name, namespace);
        body.metadata.resource_version = existing.metadata.resource_version;
        v1.patch_namespaced_config_map(
            name=configmap_name, namespace=namespace, body=body
        );
    } except ApiException as e {
        if (e.status == 404) {
            v1.create_namespaced_config_map(namespace, body);
        } else {
            raise ;
        }
    }
}

"""
    Create a tar.gz file from the source directory using only os module.
"""
impl create_tarball(source_dir: str, tar_path: str) -> None {
    if not os.path.exists(source_dir) {
        raise FileNotFoundError(f"Source directory not found: {source_dir}") ;
    }
    os.makedirs((os.path.dirname(tar_path) or '.'), exist_ok=True);
    with tarfile.open(tar_path, 'w:gz') as tar {
        tar.add(source_dir, arcname='.');
    }
}

"""
    Ensure that a given namespace exists in the Kubernetes cluster.
    If it doesn't exist and is not 'default', it will be created.
"""
impl ensure_namespace_exists(namespace: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        config.load_kube_config();
        core_v1 = client.CoreV1Api();
        core_v1.read_namespace(name=namespace);
        print(f"Namespace '{namespace}' already exists.");
    } except ApiException as e {
        if (e.status == 404) {
            print(f"Namespace '{namespace}' not found. Creating it...");
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {'name': namespace}
                }
            );
            print(f"Namespace '{namespace}' created successfully.");
        } else {
            raise ;
        }
    }
}

"""Deploy example."""
impl delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None {
    try {
        delete_func(name, namespace);
    } except ApiException as e {
        if (e.status == 404) {
            ;
        } else {
            raise ;
        }
    }
}

"""
    Checks if Kubernetes config is configured and the K8s API server is reachable.
"""
impl check_K8s_status -> None {
    try {
        config.load_kube_config();
    } except ConfigException {
        try {
            config.load_incluster_config();
        } except ConfigException {
            raise None from Exception('Kubernetes is not configured on this machine.') ;
        }
    }
    try {
        v1 = client.CoreV1Api();
        v1.get_api_resources();
    } except (ApiException, urllib3.exceptions.HTTPError, OSError) {
        raise None from Exception(
            'Unable to connect to kubernetes APi.Check whether kubernetes cluster is up'
        ) ;
    }
}

"""Load env variables in .env to aws beanstalk environment."""
impl load_env_variables(code_folder: str) -> list {
    env_file = os.path.join(code_folder, '.env');
    env_vars = dotenv_values(env_file);
    env_list = [];
    if os.path.exists(env_file) {
        for (key, value) in env_vars.items() {
            env_list.append({'name': key, 'value': value});
        }
    }
    return env_list;
}

"""
    Print a statement only if debug_only is True.

    Args:
        statement (str): The message to print.
        debug_only (bool): If True, print the statement; otherwise, do nothing.
"""
impl debug_print(statement: str, debug_only: bool = False) -> None {
    if debug_only {
        print(statement);
    }
}
