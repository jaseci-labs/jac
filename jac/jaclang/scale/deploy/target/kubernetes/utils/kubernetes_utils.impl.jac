import os;
import pathlib;
import from jaclang.cli.console { console }
import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.deploy.target.kubernetes.cluster_provider {
    AWSProvider,
    ClusterProvider,
    LocalProvider
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
                f"Sync pod '{pod_name}' entered Failed state."
                    + describe_pod_status(core_v1, namespace, pod_name, pod)
            );
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}."
            + describe_pod_status(core_v1, namespace, pod_name, last_pod)
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
        container_states = (pod.status.init_container_statuses or [])
            + (pod.status.container_statuses or []);
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

impl cluster_type -> str {
    try {
        v1 = client.CoreV1Api();
        nodes = v1.list_node();
        node_items: list[any] = nodes.items;
        if not node_items {
            return 'local';
        }
        for nd in node_items {
            provider_id: str = nd.spec.provider_id or '';
            if provider_id.startswith('aws://') {
                return 'aws';
            }
        }
        for nd in node_items {
            labels: dict[str, str] = nd.metadata.labels or {};
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
    } except ApiException as exc {
        console.print(
            f"[warn] could not read cluster nodes to detect the provider "
            f"(HTTP {exc.status} {exc.reason}). {_LOCAL_FALLBACK_NOTE}"
        );
        return 'local';
    } except Exception as exc {
        console.print(
            f"[warn] provider detection failed "
            f"({type(exc).__name__}: {exc}). {_LOCAL_FALLBACK_NOTE}"
        );
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
    rs_items: list[any] = apps_v1.list_namespaced_replica_set(
        namespace=namespace, label_selector=selector
    ).items;
    best: dict[str, tuple[int, any]] = {};
    for rs in rs_items {
        rs_labels: dict[str, str] = rs.metadata.labels or {};
        app_val = rs_labels.get("app", "");
        if not app_val {
            continue;
        }
        rs_annotations: dict[str, str] = rs.metadata.annotations or {};
        rev_str = rs_annotations.get("deployment.kubernetes.io/revision", "0");
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
    pending: set[str] = set();
    for (_, rs) in best.values() {
        best_labels: dict[str, str] = rs.metadata.labels or {};
        h = best_labels.get("pod-template-hash");
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

impl default_pss_labels -> dict[str, str] {
    return {
        PSS_ENFORCE_LABEL: "baseline",
        PSS_WARN_LABEL: "restricted",
        PSS_SOURCE_LABEL: "baseline"
    };
}


impl privileged_pss_labels(existing: dict[str, str]) -> dict[str, str] | None {
    current = existing.get(PSS_ENFORCE_LABEL, "");
    if current == "privileged" {
        return {};
    }
    if current and current != existing.get(PSS_SOURCE_LABEL, "") {
        return None;
    }
    return {PSS_ENFORCE_LABEL: "privileged", PSS_SOURCE_LABEL: "privileged"};
}


impl ensure_namespace_exists(namespace: str, owner: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        core_v1 = client.CoreV1Api();
        existing_ns = core_v1.read_namespace(name=namespace);
        console.print(f"Namespace '{namespace}' already exists.");

        existing_labels: dict = dict(getattr(existing_ns.metadata, "labels", {}) or {});
        patch_labels: dict = {};
        for (label, value) in default_pss_labels().items() {
            if not existing_labels.get(label) {
                patch_labels[label] = value;
            }
        }
        if patch_labels and not existing_labels.get(PSS_ENFORCE_LABEL) {
            patch_labels[PSS_SOURCE_LABEL] = "baseline";
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
            create_labels: dict = dict(default_pss_labels());
            if owner {
                create_labels[NAMESPACE_OWNER_LABEL] = owner;
            }
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {'name': namespace, 'labels': create_labels}
                }
            );
            console.print(f"Namespace '{namespace}' created successfully.");
        } else {
            raise;
        }
    }
}

impl namespace_is_owned(core_v1: client.CoreV1Api, namespace: str, owner: str) -> bool {
    if (namespace == 'default') or not owner {
        return False;
    }
    try {
        ns = core_v1.read_namespace(name=namespace);
    } except ApiException as e {
        if (e.status == 404) {
            return False;
        }
        raise;
    }
    labels: dict = dict(getattr(ns.metadata, "labels", {}) or {});
    return labels.get(NAMESPACE_OWNER_LABEL) == owner;
}


impl delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None {
    try {
        delete_func(name, namespace);
    } except ApiException as e {
        if (e.status == 404) {} else {
            raise;
        }
    }
}

impl create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> str {
    if not secret_data {
        return "";
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
    applied: any = None;
    try {
        applied = core_v1.create_namespaced_secret(
            namespace=namespace, body=secret_body
        );
    } except ApiException as e {
        if e.status == 409 {
            applied = core_v1.replace_namespaced_secret(
                name=secret_name, namespace=namespace, body=secret_body
            );
        } else {
            raise;
        }
    }
    return str(applied.metadata.resource_version or "") if applied else "";
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
