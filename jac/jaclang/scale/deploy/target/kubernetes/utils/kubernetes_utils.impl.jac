import os;
import pathlib;
import from jaclang.cli.console { console }
import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.deploy.target.kubernetes.cluster_provider {
    AWSProvider,
    ClusterProvider,
    LocalProvider
}

impl parse_cpu_quantity(quantity: str) -> float {
    trimmed = quantity.strip();
    if (trimmed == '') {
        raise ValueError('CPU quantity cannot be empty.');
    }
    lower = trimmed.lower();
    if lower.endswith('m') {
        value = lower[:-1].strip();
        if (value == '') {
            raise ValueError(
                f"CPU quantity '{quantity}' is missing a numeric component."
            );
        }
        return float(value) / 1000.0;
    }
    return float(trimmed);
}

impl parse_memory_quantity(quantity: str) -> float {
    trimmed = quantity.strip();
    if (trimmed == '') {
        raise ValueError('Memory quantity cannot be empty.');
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
                );
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
            raise ValueError(f"Invalid CPU quantity: {exc}");
        }
        if (cpu_limit_value < cpu_request_value) {
            raise ValueError(
                f"K8s_CPU_LIMIT ({cpu_limit}) must not be lower than K8s_CPU_REQUEST ({cpu_request})."
            );
        }
    }
    if (memory_request and memory_limit) {
        try {
            memory_request_value = parse_memory_quantity(memory_request);
            memory_limit_value = parse_memory_quantity(memory_limit);
        } except ValueError as exc {
            raise ValueError(f"Invalid memory quantity: {exc}");
        }
        if (memory_limit_value < memory_request_value) {
            raise ValueError(
                f"K8s_MEMORY_LIMIT ({memory_limit}) must not be lower than K8s_MEMORY_REQUEST ({memory_request})."
            );
        }
    }
}

impl run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None {
    import shutil;
    import subprocess;
    if (shutil.which('kubectl') is None) {
        raise RuntimeError('kubectl is required to seed the bundle PVC.');
    }

    try {
        subprocess.run(
            ['kubectl', *args], check=True, text=True, cwd=str(cwd) if cwd else None
        );
    } except subprocess.CalledProcessError as exc {
        raise RuntimeError(
            f"kubectl command failed: {' '.join(['kubectl', *args])}"
        ) from exc;
    }
}

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
            raise;
        }
        time.sleep(2);
    }
    raise TimeoutError(f"Timed out waiting for pod '{pod_name}' deletion.");
}

impl wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None {
    start_time = time.time();
    last_pod: any = None;
    while ((time.time() - start_time) < timeout) {
        try {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                time.sleep(2);
                continue;
            }
            raise;
        }
        last_pod = pod;
        phase = (pod.status.phase or '').strip();
        if (phase in target_phases) {
            return;
        }
        if (phase == 'Failed') {
            raise RuntimeError(
                f"Sync pod '{pod_name}' entered Failed state." + describe_pod_status(
                    core_v1, namespace, pod_name, pod
                )
            );
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}." + describe_pod_status(
            core_v1, namespace, pod_name, last_pod
        )
    );
}

impl describe_pod_status(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, pod: any = None
) -> str {
    lines: list[str] = [];
    object_names = [pod_name];
    try {
        if pod is None {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        }
        lines.append(f"phase={(pod.status.phase or '?')}");
        for cond in (pod.status.conditions or []) {
            if (cond.status or '') != 'True' and cond.reason {
                lines.append(
                    f"condition {cond.type}={cond.status} ({cond.reason}: {cond.message
                    or ''})"
                );
            }
        }
        container_states = (pod.status.init_container_statuses or []) + (
            pod.status.container_statuses or []
        );
        for cs in container_states {
            waiting = cs.state.waiting if cs.state else None;
            if waiting and waiting.reason {
                lines.append(
                    f"container '{cs.name}' waiting: {waiting.reason} ({waiting.message
                    or ''})"
                );
            }
        }
        for vol in ((pod.spec.volumes if pod.spec else None) or []) {
            claim = vol.persistent_volume_claim;
            if not claim {
                continue;
            }
            claim_name = claim.claim_name;
            object_names.append(claim_name);
            try {
                pvc = core_v1.read_namespaced_persistent_volume_claim(
                    claim_name, namespace
                );
                modes = ",".join(pvc.spec.access_modes or []);
                lines.append(
                    f"pvc '{claim_name}' phase={(pvc.status.phase or '?')} "
                    f"accessModes=[{modes}] storageClass={pvc.spec.storage_class_name
                    or '(default)'}"
                );
            } except Exception as exc {
                lines.append(f"(could not read pvc '{claim_name}': {exc})");
            }
        }
    } except Exception as exc {
        lines.append(f"(could not read pod: {exc})");
    }
    try {
        for obj_name in object_names {
            events = core_v1.list_namespaced_event(
                namespace, field_selector=f"involvedObject.name={obj_name}"
            );
            for ev in (events.items or []) {
                lines.append(
                    f"event [{obj_name}/{ev.reason or '?'}] {ev.message or ''}"
                );
            }
        }
    } except Exception as exc {
        lines.append(f"(could not read events: {exc})");
    }
    if not lines {
        return '';
    }
    return " Pod diagnostics: " + "; ".join(lines);
}

impl parse_storage_quantity(quantity: str) -> int {
    q = quantity.strip();
    if q == '' {
        raise ValueError('Storage quantity cannot be empty.');
    }
    suffixes_binary: dict[str, int] = {
        'Ki': 1024,
        'Mi': 1024 ** 2,
        'Gi': 1024 ** 3,
        'Ti': 1024 ** 4,
        'Pi': 1024 ** 5,
        'Ei': 1024 ** 6
    };
    suffixes_decimal: dict[str, int] = {
        'k': 1000,
        'M': 1000 ** 2,
        'G': 1000 ** 3,
        'T': 1000 ** 4,
        'P': 1000 ** 5,
        'E': 1000 ** 6
    };
    for (suffix, multiplier) in suffixes_binary.items() {
        if q.endswith(suffix) {
            number_part = q[:-len(suffix)].strip();
            if number_part == '' {
                raise ValueError(
                    f"Storage quantity '{quantity}' is missing a numeric component."
                );
            }
            return int(number_part) * multiplier;
        }
    }
    for (suffix, multiplier) in suffixes_decimal.items() {
        if q.endswith(suffix) {
            number_part = q[:-len(suffix)].strip();
            if number_part == '' {
                raise ValueError(
                    f"Storage quantity '{quantity}' is missing a numeric component."
                );
            }
            return int(number_part) * multiplier;
        }
    }
    try {
        return int(q);
    } except ValueError {
        raise ValueError(
            f"Unrecognized storage quantity '{quantity}'. "
            f"Use a plain integer (bytes) or a suffix: Ki, Mi, Gi, Ti, Pi, Ei, k, M, G, T, P, E."
        );
    }
}

impl resize_pvc_if_needed(
    core_v1: client.CoreV1Api, namespace: str, pvc_name: str, desired_size: str
) -> None {
    try {
        pvc = core_v1.read_namespaced_persistent_volume_claim(pvc_name, namespace);
    } except ApiException as exc {
        if exc.status == 404 {
            return;
        }
        raise;
    }
    current_size_str = pvc.spec.resources.requests.get('storage', '0');
    current_bytes = parse_storage_quantity(current_size_str);
    desired_bytes = parse_storage_quantity(desired_size);

    if desired_bytes < current_bytes {
        raise ValueError(
            f"Cannot shrink PVC '{pvc_name}': desired size '{desired_size}' is "
            f"smaller than current size '{current_size_str}'. "
            f"Decrease of PVC size is not supported."
        );
    }
    if desired_bytes == current_bytes {
        return;
    }
    patch = {'spec': {'resources': {'requests': {'storage': desired_size}}}};
    core_v1.patch_namespaced_persistent_volume_claim(pvc_name, namespace, patch);
}

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
            raise;
        }
    }
    import from typing { Any }
    pvc_body: dict[(str, Any)] = {
        'apiVersion': 'v1',
        'kind': 'PersistentVolumeClaim',
        'metadata': {'name': pvc_name, 'labels': {'managed': 'jac-scale'}},
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

impl cluster_type -> str {
    try {
        v1 = client.CoreV1Api();
        nodes = v1.list_node();
        if not nodes.items {
            return 'local';
        }
        for nd in nodes.items {
            provider_id = nd.spec.provider_id or '';
            if provider_id.startswith('aws://') {
                return 'aws';
            }
        }
        for nd in nodes.items {
            labels = nd.metadata.labels or {};
            if (
                ('topology.kubernetes.io/region' in labels)
                and any(
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

impl get_cluster_provider -> ClusterProvider {
    if cluster_type() == 'aws' {
        return AWSProvider();
    }
    return LocalProvider();
}

impl _resolve_current_rs_hashes(namespace: str, selector: str) -> set {
    apps_v1 = client.AppsV1Api();
    rs_items = apps_v1.list_namespaced_replica_set(
        namespace=namespace, label_selector=selector
    ).items;
    best: dict = {};
    for rs in rs_items {
        app_val = (rs.metadata.labels or {}).get("app", "");
        if not app_val {
            continue;
        }
        rev_str = (rs.metadata.annotations or {}).get(
            "deployment.kubernetes.io/revision", "0"
        );
        try {
            rev = int(rev_str);
        } except (ValueError, TypeError) {
            rev = 0;
        }
        prev = best.get(app_val);
        if prev is None or rev > prev[0] {
            best[app_val] = (rev, rs);
        }
    }
    pending: set = set();
    for (_, rs) in best.values() {
        h = (rs.metadata.labels or {}).get("pod-template-hash");
        if h {
            pending.add(h);
        }
    }
    return pending;
}

impl _refresh_rs_hashes(
    namespace: str, selector: str, current: (set | None)
) -> (set | None) {
    try {
        return _resolve_current_rs_hashes(namespace, selector);
    } except Exception as exc {
        console.print(f"[warn] RS hash refresh failed, keeping prior hash set: {exc}");
        return current;
    }
}

impl check_pods_restarted(
    namespace: str,
    app_name: str,
    _rs_hashes: (set | None) = None,
    _skip_config_load: bool = False
) -> bool {
    if not _skip_config_load {
        try {
            config.load_kube_config();
        } except ConfigException {
            config.load_incluster_config();
        }
    }
    v1 = client.CoreV1Api();
    app_labels = [app_name + d[0] for d in COMPANION_DEFS];
    selector = "app in ({})".format(", ".join(app_labels));

    current_hashes: set = set();
    if _rs_hashes is not None {
        current_hashes = _rs_hashes;
    } else {
        try {
            current_hashes = _resolve_current_rs_hashes(namespace, selector);
        } except Exception as exc {
            console.print(
                f"[warn] RS hash lookup failed, falling back to broad pod scan: {exc}"
            );
        }
    }

    pods = v1.list_namespaced_pod(namespace=namespace, label_selector=selector);
    for pod in pods.items {
        if current_hashes {
            pod_hash = (pod.metadata.labels or {}).get("pod-template-hash");
            if pod_hash is not None and pod_hash not in current_hashes {
                continue;
            }
        }
        statuses = (pod.status.init_container_statuses or []) + (
            pod.status.container_statuses or []
        );
        if not statuses {
            continue;
        }

        for container in statuses {
            term = container.state.terminated if container.state else None;
            completed_ok = term is not None and (term.exit_code or 0) == 0;
            if container.restart_count > 0 and not completed_ok {
                is_running = container.state and container.state.running;
                if not is_running {
                    reason = (
                        container.state.waiting.reason
                            if (container.state and container.state.waiting)
                            else "unknown"
                    );

                    last_state = container.last_state;
                    term_reason = "n/a";
                    term_exit_code = "n/a";
                    if last_state and last_state.terminated {
                        term_reason = last_state.terminated.reason or "n/a";
                        term_exit_code = (
                            str(last_state.terminated.exit_code)
                                if (last_state.terminated.exit_code is not None)
                                else "n/a"
                        );
                    }
                    console.print(
                        f"Pod {pod.metadata.name} container "
                        f"{container.name} restarted and is not running "
                        f"(waiting={reason}, last_terminated={term_reason}, "
                        f"exit_code={term_exit_code})"
                    );

                    try {
                        prev_logs = v1.read_namespaced_pod_log(
                            name=pod.metadata.name,
                            namespace=namespace,
                            container=container.name,
                            previous=True,
                            tail_lines=500
                        );
                        console.print(
                            f"--- {pod.metadata.name}/{container.name} previous logs (last 500 lines) ---"
                        );
                        console.print(prev_logs);
                        console.print(f"--- end of {pod.metadata.name} logs ---");
                    } except Exception as log_err {
                        console.print(
                            f"(could not fetch previous logs for {pod.metadata.name}: {log_err})"
                        );
                    }

                    try {
                        field_sel = (
                            f"involvedObject.name={pod.metadata.name}"
                            f",involvedObject.namespace={namespace}"
                        );
                        events = v1.list_namespaced_event(
                            namespace=namespace, field_selector=field_sel
                        );
                        if events.items {
                            console.print(f"--- {pod.metadata.name} events ---");
                            for ev in events.items {
                                console.print(
                                    f"  [{ev.type}] {ev.reason}: {ev.message}"
                                );
                            }
                            console.print(f"--- end of {pod.metadata.name} events ---");
                        }
                    } except Exception as ev_err {
                        console.print(
                            f"(could not fetch events for {pod.metadata.name}: {ev_err})"
                        );
                    }
                    return True;
                }
            }
        }
    }
    return False;
}

impl check_deployment_status(
    node_port: int,
    path: str = '/docs',
    interval: int = 15,
    max_retries: int = 48,
    nlb_url: (str | None) = None,
    namespace: str = "default",
    app_name: str = "jaseci"
) -> tuple[bool, str] {
    if nlb_url {
        url = f"{nlb_url.rstrip('/')}{path}";
    } else {
        url = f"http://localhost:{node_port}{path}";
    }
    try {
        config.load_kube_config();
    } except ConfigException {
        config.load_incluster_config();
    }
    _app_labels = [app_name + d[0] for d in COMPANION_DEFS];
    _selector = "app in ({})".format(", ".join(_app_labels));
    rs_hashes: (set | None) = None;
    try {
        rs_hashes = _resolve_current_rs_hashes(namespace, _selector);
    } except Exception as exc {
        console.print(
            f"[warn] RS hash lookup failed, falling back to broad pod scan: {exc}"
        );
    }

    for attempt in range(1, (max_retries + 1)) {
        try {
            response = requests.get(url, timeout=10);
            if (response.status_code == 200) {
                return (True, "Successful");
            }

            if check_pods_restarted(namespace, app_name, rs_hashes, True) {
                rs_hashes = _refresh_rs_hashes(namespace, _selector, rs_hashes);
                if check_pods_restarted(namespace, app_name, rs_hashes, True) {
                    return (False, "Containers restarted");
                }
            }
        } except RequestException as e {
            if check_pods_restarted(namespace, app_name, rs_hashes, True) {
                rs_hashes = _refresh_rs_hashes(namespace, _selector, rs_hashes);
                if check_pods_restarted(namespace, app_name, rs_hashes, True) {
                    return (False, "Containers restarted");
                }
            }

            if (attempt == max_retries) {
                console.print(f"Failed to connect to {url}: {e}");
            }
        }
        if (attempt < max_retries) {
            time.sleep(interval);
        }
    }

    diag_v1 = client.CoreV1Api();
    diag_labels = [app_name + d[0] for d in COMPANION_DEFS];
    diag_selector = "app in ({})".format(", ".join(diag_labels));
    try {
        diag_pods = diag_v1.list_namespaced_pod(
            namespace=namespace, label_selector=diag_selector
        );
        for p in diag_pods.items {
            console.print(
                f"timeout diagnostics: pod {p.metadata.name}" + describe_pod_status(
                    diag_v1, namespace, p.metadata.name, p
                )
            );
        }
    } except Exception as diag_err {
        console.print(f"(timeout pod diagnostics unavailable: {diag_err})");
    }
    return (False, "Timeout reached");
}

impl delete_namespace(namespace: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        try {
            config.load_kube_config();
        } except ConfigException {
            config.load_incluster_config();
        }
        core_v1 = client.CoreV1Api();
        core_v1.delete_namespace(name=namespace);
        console.print(f"Namespace '{namespace}' deleted successfully.");
    } except ApiException as e {
        if (e.status == 404) {
            console.print(f"Namespace '{namespace}' not found, skipping deletion.");
        } else {
            raise;
        }
    }
}

impl ensure_namespace_exists(namespace: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        try {
            config.load_kube_config();
        } except ConfigException {
            config.load_incluster_config();
        }
        core_v1 = client.CoreV1Api();
        existing_ns = core_v1.read_namespace(name=namespace);
        console.print(f"Namespace '{namespace}' already exists.");

        existing_labels: dict = dict(getattr(existing_ns.metadata, "labels", {}) or {});
        patch_labels: dict = {};
        if not existing_labels.get("pod-security.kubernetes.io/enforce") {
            patch_labels["pod-security.kubernetes.io/enforce"] = "baseline";
        }
        if not existing_labels.get("pod-security.kubernetes.io/warn") {
            patch_labels["pod-security.kubernetes.io/warn"] = "restricted";
        }
        if patch_labels {
            try {
                core_v1.patch_namespace(
                    name=namespace, body={'metadata': {'labels': patch_labels}}
                );
            } except ApiException as patch_err {
                console.print(
                    f"Warning: could not apply PSS labels to namespace '{namespace}': {patch_err}"
                );
            }
        }
    } except ApiException as e {
        if (e.status == 404) {
            console.print(f"Namespace '{namespace}' not found. Creating it...");
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {
                        'name': namespace,
                        'labels': {
                            'pod-security.kubernetes.io/enforce': 'baseline',
                            'pod-security.kubernetes.io/warn': 'restricted'
                        }
                    }
                }
            );
            console.print(f"Namespace '{namespace}' created successfully.");
        } else {
            raise;
        }
    }
}

impl delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None {
    try {
        delete_func(name, namespace);
    } except ApiException as e {
        if (e.status == 404) {
            ;
        } else {
            raise;
        }
    }
}

impl check_K8s_status -> None {
    try {
        config.load_kube_config();
    } except ConfigException {
        try {
            config.load_incluster_config();
        } except ConfigException {
            raise None from Exception('Kubernetes is not configured on this machine.');
        }
    }
    try {
        v1 = client.CoreV1Api();
        v1.get_api_resources();
    } except (ApiException, urllib3.exceptions.HTTPError, OSError) {
        raise None from Exception(
            'Unable to connect to kubernetes APi.Check whether kubernetes cluster is up'
        );
    }
}

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

impl create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> bool {
    if not secret_data {
        return False;
    }
    secret_body = {
        'apiVersion': 'v1',
        'kind': 'Secret',
        'metadata': {
            'name': secret_name,
            'namespace': namespace,
            'labels': {'managed': 'jac-scale'}
        },
        'type': 'Opaque',
        'stringData': secret_data
    };
    try {
        core_v1.create_namespaced_secret(namespace=namespace, body=secret_body);
    } except ApiException as e {
        if e.status == 409 {
            core_v1.replace_namespaced_secret(
                name=secret_name, namespace=namespace, body=secret_body
            );
        } else {
            raise;
        }
    }
    return True;
}

impl delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None {
    try {
        core_v1.delete_namespaced_secret(name=secret_name, namespace=namespace);
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
}
