impl KEDAAutoscaler._trigger_key{
    return trigger.name or f"{trigger.type}-{trigger_index}";
}

impl KEDAAutoscaler._trigger_auth_name{
    key = f"{app_name}/{self._trigger_key(trigger, trigger_index)}";
    short_hash = hashlib.sha256(key.encode()).hexdigest()[:8];
    return f"{app_name[:20].rstrip('-')}-{short_hash}-ta";
}

impl KEDAAutoscaler._validate_triggers{
    seen: dict[str, int] = {};
    for (i, trigger) in enumerate(spec.triggers) {
        key = self._trigger_key(trigger, i);
        if key in seen {
            raise ValueError(
                f"Trigger '{key}' in autoscaler spec for '{app_name}' collides with the trigger "
                f"at index {seen[
                    key
                ]}; each trigger must resolve to a unique name so their "
                "TriggerAuthentication resources do not overwrite one another."
            );
        }
        seen[key] = i;
    }
}

impl KEDAAutoscaler._get_cluster_key{
    try {
        import from kubernetes.client { Configuration }
        return Configuration.get_default_copy().host or "default";
    } except (ImportError, AttributeError) {
        return "default";
    }
}

impl KEDAAutoscaler.preflight{
    install_warning = [
        "KEDA CRDs not found on cluster. "
        "Install KEDA from the official docs, then redeploy: "
        "https://keda.sh/docs/latest/deploy/"
    ];
    cluster_key = self._get_cluster_key();
    if cluster_key in KEDAAutoscaler._preflight_cache {
        if KEDAAutoscaler._preflight_cache[cluster_key] {
            return [];
        }
        return install_warning;
    }
    api = self._custom_api or client.CustomObjectsApi();
    try {
        api.list_cluster_custom_object(
            group="keda.sh", version="v1alpha1", plural="scaledobjects"
        );
        KEDAAutoscaler._preflight_cache[cluster_key] = True;
        return [];
    } except ApiException as e {
        if e.status in [404, 422] {
            KEDAAutoscaler._preflight_cache[cluster_key] = False;
            return install_warning;
        }
        raise;
    }
}

impl KEDAAutoscaler._build_trigger{
    if trigger.type == "cpu" {
        value = trigger.metadata.get(
            "averageUtilization", str(DEFAULT_CPU_UTILIZATION_TARGET)
        );
        keda_trigger = {
            "type": "cpu",
            "metricType": "Utilization",
            "metadata": {"value": str(value)}
        };
    } elif trigger.type == "memory" {
        value = trigger.metadata.get(
            "averageUtilization", str(DEFAULT_MEMORY_UTILIZATION_TARGET)
        );
        keda_trigger = {
            "type": "memory",
            "metricType": "Utilization",
            "metadata": {"value": str(value)}
        };
    } else {
        keda_trigger = {
            "type": trigger.type,
            "metadata": {k: str(v) for (k, v) in trigger.metadata.items()}
        };
    }
    if trigger.name {
        keda_trigger["name"] = trigger.name;
    }
    if trigger.auth and trigger.auth.secret_refs {
        auth_name = self._trigger_auth_name(app_name, trigger, trigger_index);
        keda_trigger["authenticationRef"] = {"name": auth_name};
    }
    return keda_trigger;
}

impl KEDAAutoscaler._build_manifests{
    scaled_obj_name = spec.autoscaler_name or f"{spec.scale_target_name}-scaledobject";
    keda_triggers: list[dict[str, any]] = [];
    app_name = spec.app_name or spec.scale_target_name;
    for (i, trigger) in enumerate(spec.triggers) {
        keda_triggers.append(self._build_trigger(trigger, app_name, i));
    }

    if not keda_triggers {
        keda_triggers.append(
            {
                "type": "cpu",
                "metricType": "Utilization",
                "metadata": {"value": str(DEFAULT_CPU_UTILIZATION_TARGET)}
            }
        );
    }
    scaled_obj_spec: dict[str, any] = {
        "scaleTargetRef": {
            "apiVersion": "apps/v1",
            "kind": spec.target_kind,
            "name": spec.scale_target_name
        },
        "minReplicaCount": spec.min_replicas,
        "maxReplicaCount": spec.max_replicas,
        "pollingInterval": spec.polling_interval,
        "cooldownPeriod": spec.cooldown_period,
        "triggers": keda_triggers,
        "advanced": {
            "horizontalPodAutoscalerConfig": {
                "behavior": Autoscaler._build_behavior(spec)
            }
        }
    };

    if spec.idle_replicas is not None {
        scaled_obj_spec["idleReplicaCount"] = spec.idle_replicas;
    }

    if spec.initial_cooldown_period > 0 {
        scaled_obj_spec["initialCooldownPeriod"] = spec.initial_cooldown_period;
    }
    return {
        "name": scaled_obj_name,
        "body": {
            "apiVersion": "keda.sh/v1alpha1",
            "kind": "ScaledObject",
            "metadata": {
                "name": scaled_obj_name,
                "namespace": spec.namespace,
                "labels": {
                    "app": spec.scale_target_name,
                    ** Autoscaler._managed_labels()
                }
            },
            "spec": scaled_obj_spec
        }
    };
}

impl KEDAAutoscaler._apply_trigger_auth{
    if not trigger.auth {
        return;
    }
    if not trigger.auth.secret_refs {
        return;
    }
    auth_name = self._trigger_auth_name(app_name, trigger, trigger_index);
    secret_target_refs: list[dict[str, any]] = [];
    for (param, ref) in trigger.auth.secret_refs.items() {
        if not isinstance(ref, dict) {
            raise ValueError(
                f"auth.secret_refs['{param}'] must be a table {{name = '...', key = '...'}}, got {type(
                    ref
                ).__name__}"
            );
        }
        secret_target_refs.append(
            {"parameter": param, "name": ref.get("name", ""), "key": ref.get("key", "")}
        );
    }
    auth_body = {
        "apiVersion": "keda.sh/v1alpha1",
        "kind": "TriggerAuthentication",
        "metadata": {
            "name": auth_name,
            "namespace": namespace,
            "labels": Autoscaler._managed_labels()
        },
        "spec": {"secretTargetRef": secret_target_refs}
    };
    try {
        api.get_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=namespace,
            plural="triggerauthentications",
            name=auth_name
        );
        api.patch_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=namespace,
            plural="triggerauthentications",
            name=auth_name,
            body=auth_body
        );
    } except ApiException as e {
        if e.status == 404 {
            api.create_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace=namespace,
                plural="triggerauthentications",
                body=auth_body
            );
        } else {
            raise;
        }
    }
}

impl KEDAAutoscaler.apply{
    app_name = spec.app_name or spec.scale_target_name;
    self._validate_triggers(spec, app_name);
    warnings = self.preflight();
    if warnings {
        if self.logger {
            self.logger.warn(warnings[0]);
        }
        return False;
    }
    api = self._custom_api or client.CustomObjectsApi();

    try {
        (
            self._v2_api or AutoscalingV2Api()
        ).delete_namespaced_horizontal_pod_autoscaler(
            name=f"{app_name}-hpa", namespace=spec.namespace
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }

    for (i, trigger) in enumerate(spec.triggers) {
        self._apply_trigger_auth(api, trigger, spec.namespace, app_name, i);
    }
    manifests = self._build_manifests(spec);
    name = manifests["name"];
    body = manifests["body"];
    try {
        api.get_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=spec.namespace,
            plural="scaledobjects",
            name=name
        );
        api.patch_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=spec.namespace,
            plural="scaledobjects",
            name=name,
            body=body
        );
    } except ApiException as e {
        if e.status == 404 {
            api.create_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace=spec.namespace,
                plural="scaledobjects",
                body=body
            );
        } else {
            raise;
        }
    }
    return True;
}

impl KEDAAutoscaler.destroy{
    api = self._custom_api or client.CustomObjectsApi();
    try {
        api.delete_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=namespace,
            plural="scaledobjects",
            name=autoscaler_name
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
}

impl KEDAAutoscaler.destroy_collection{
    api = self._custom_api or client.CustomObjectsApi();
    for (group, version, plural) in [
        ("keda.sh", "v1alpha1", "scaledobjects"),
        ("keda.sh", "v1alpha1", "triggerauthentications"),
        ("http.keda.sh", "v1beta1", "interceptorroutes")
    ] {
        try {
            items = api.list_namespaced_custom_object(
                group=group,
                version=version,
                namespace=namespace,
                plural=plural,
                label_selector=label_selector
            );
            for item in items.get("items", []) {
                item_name = item["metadata"]["name"];
                try {
                    api.delete_namespaced_custom_object(
                        group=group,
                        version=version,
                        namespace=namespace,
                        plural=plural,
                        name=item_name
                    );
                } except ApiException as e {
                    if e.status not in [404, 422] {
                        raise;
                    }
                }
            }
        } except ApiException as e {
            if e.status not in [404, 422] {
                raise;
            }
        }
    }

    try {
        (
            self._v2_api or AutoscalingV2Api()
        ).delete_collection_namespaced_horizontal_pod_autoscaler(
            namespace=namespace, label_selector=label_selector
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
}

impl KEDAAutoscaler.resource_name_for{
    return f"{target}-scaledobject";
}

impl KEDAAutoscaler.interceptor_route_name_for{
    return f"{target}-http-route";
}

impl KEDAAutoscaler.http_scaled_object_name_for{
    return f"{target}-http-scaledobject";
}

impl KEDAAutoscaler.apply_http_activation{
    self._validate_http_activation_spec(spec);

    cluster_key = self._get_cluster_key();
    api = self._custom_api or client.CustomObjectsApi();
    if cluster_key not in KEDAAutoscaler._http_preflight_cache {
        try {
            api.list_cluster_custom_object(
                group="http.keda.sh", version="v1beta1", plural="interceptorroutes"
            );
            KEDAAutoscaler._http_preflight_cache[cluster_key] = True;
        } except ApiException as e {
            if e.status in [404, 422] {
                KEDAAutoscaler._http_preflight_cache[cluster_key] = False;
            } else {
                raise;
            }
        }
    }
    if not KEDAAutoscaler._http_preflight_cache[cluster_key] {
        if self.logger {
            self.logger.warn(
                "KEDA HTTP Add-on CRDs not found on cluster. Install the HTTP "
                "Add-on from the official docs, then redeploy: "
                "https://keda.sh/docs/latest/deploy/#http-add-on"
            );
        }
        return False;
    }

    apps_api = self._apps_api or client.AppsV1Api();
    core_api = self._core_api or client.CoreV1Api();

    try {
        if spec.scale_target_kind == "Deployment" {
            apps_api.read_namespaced_deployment(
                name=spec.scale_target_name, namespace=spec.namespace
            );
        } elif spec.scale_target_kind == "StatefulSet" {
            apps_api.read_namespaced_stateful_set(
                name=spec.scale_target_name, namespace=spec.namespace
            );
        } elif spec.scale_target_plural is not None {
            (custom_group, _, custom_version) = spec.scale_target_api_version.rpartition(
                "/"
            );
            api.get_namespaced_custom_object(
                group=custom_group,
                version=custom_version,
                namespace=spec.namespace,
                plural=spec.scale_target_plural,
                name=spec.scale_target_name
            );
        } else {
            raise ValueError(
                f"Cannot verify scale_target_kind='{spec.scale_target_kind}' "
                f"exists before apply. Set scale_target_plural on "
                f"HTTPActivationSpec to enable validation for this custom "
                f"resource, or use scale_target_kind='Deployment' or "
                f"'StatefulSet'."
            );
        }
    } except ApiException as e {
        if e.status == 404 {
            raise ValueError(
                f"Scale target '{spec.scale_target_name}' "
                f"({spec.scale_target_kind}) not found in namespace "
                f"'{spec.namespace}'."
            );
        }
        raise;
    }

    try {
        core_api.read_namespaced_service(
            name=spec.target.service, namespace=spec.namespace
        );
    } except ApiException as e {
        if e.status == 404 {
            raise ValueError(
                f"Service '{spec.target.service}' not found in namespace "
                f"'{spec.namespace}'."
            );
        }
        raise;
    }

    route_manifest = self._build_interceptor_route(spec);
    route_name = route_manifest["name"];
    route_body = route_manifest["body"];
    try {
        api.get_namespaced_custom_object(
            group="http.keda.sh",
            version="v1beta1",
            namespace=spec.namespace,
            plural="interceptorroutes",
            name=route_name
        );
        api.patch_namespaced_custom_object(
            group="http.keda.sh",
            version="v1beta1",
            namespace=spec.namespace,
            plural="interceptorroutes",
            name=route_name,
            body=route_body
        );
    } except ApiException as e {
        if e.status == 404 {
            api.create_namespaced_custom_object(
                group="http.keda.sh",
                version="v1beta1",
                namespace=spec.namespace,
                plural="interceptorroutes",
                body=route_body
            );
        } else {
            raise;
        }
    }

    scaled_obj_manifest = self._build_http_scaled_object(spec);
    scaled_obj_name = scaled_obj_manifest["name"];
    scaled_obj_body = scaled_obj_manifest["body"];
    try {
        api.get_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=spec.namespace,
            plural="scaledobjects",
            name=scaled_obj_name
        );
        api.patch_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=spec.namespace,
            plural="scaledobjects",
            name=scaled_obj_name,
            body=scaled_obj_body
        );
    } except ApiException as e {
        if e.status == 404 {
            api.create_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace=spec.namespace,
                plural="scaledobjects",
                body=scaled_obj_body
            );
        } else {
            raise;
        }
    }

    return True;
}

impl KEDAAutoscaler.destroy_http_activation{
    api = self._custom_api or client.CustomObjectsApi();
    try {
        api.delete_namespaced_custom_object(
            group="http.keda.sh",
            version="v1beta1",
            namespace=namespace,
            plural="interceptorroutes",
            name=self.interceptor_route_name_for(target)
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
    try {
        api.delete_namespaced_custom_object(
            group="keda.sh",
            version="v1alpha1",
            namespace=namespace,
            plural="scaledobjects",
            name=self.http_scaled_object_name_for(target)
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
}

impl KEDAAutoscaler._build_routing_rules{
    result: list[dict[str, any]] = [];
    for rule in rules {
        header_matches: list[dict[str, any]] = [];
        for header in rule.headers {
            header_entry: dict[str, any] = {"name": header.name};
            if header.value is not None {
                header_entry["value"] = header.value;
            }
            header_matches.append(header_entry);
        }

        paths = rule.paths or [None];
        for path in paths {
            entry: dict[str, any] = {};
            if rule.hosts {
                entry["hosts"] = rule.hosts;
            }
            if path is not None {
                entry["path"] = {"value": path.value};
            }
            if header_matches {
                entry["headers"] = header_matches;
            }
            result.append(entry);
        }
    }
    return result;
}

impl KEDAAutoscaler._build_interceptor_route{
    route_name = self.interceptor_route_name_for(spec.scale_target_name);

    target: dict[str, any] = {"service": spec.target.service};
    if spec.target.port is not None {
        target["port"] = spec.target.port;
    } else {
        target["portName"] = spec.target.port_name;
    }

    scaling_metric: dict[str, any] = {};
    if spec.concurrency is not None {
        scaling_metric["concurrency"] = {"targetValue": spec.concurrency.target_value};
    } elif spec.request_rate is not None {
        scaling_metric["requestRate"] = {
            "targetValue": spec.request_rate.target_value,
            "window": spec.request_rate.window,
            "granularity": spec.request_rate.granularity
        };
    }

    route_spec: dict[str, any] = {
        "target": target,
        "scalingMetric": scaling_metric,
        "rules": self._build_routing_rules(spec.rules)
    };

    if spec.cold_start is not None {
        cold_start: dict[str, any] = {};
        placeholder = spec.cold_start.placeholder;
        if placeholder is not None {
            placeholder_body: dict[str, any] = {"statusCode": placeholder.status_code};
            if placeholder.body is not None {
                placeholder_body["body"] = placeholder.body;
            }
            if placeholder.body_from_config_map is not None {
                placeholder_body["bodyFromConfigMap"] = placeholder.body_from_config_map;
            }
            if placeholder.headers {
                placeholder_body["headers"] = placeholder.headers;
            }
            cold_start["placeholder"] = {"response": placeholder_body};
        }
        fallback_service = spec.cold_start.fallback_service;
        if fallback_service is not None {
            fallback_body: dict[str, any] = {"name": fallback_service.service};
            if fallback_service.port is not None {
                fallback_body["port"] = fallback_service.port;
            } else {
                fallback_body["portName"] = fallback_service.port_name;
            }
            cold_start["fallback"] = {"service": fallback_body};
        }
        if cold_start {
            route_spec["coldStart"] = cold_start;
        }
    }

    if spec.timeouts is not None {
        timeouts: dict[str, any] = {};
        if spec.timeouts.readiness is not None {
            timeouts["readiness"] = spec.timeouts.readiness;
        }
        if spec.timeouts.request is not None {
            timeouts["request"] = spec.timeouts.request;
        }
        if spec.timeouts.response_header is not None {
            timeouts["responseHeader"] = spec.timeouts.response_header;
        }
        if timeouts {
            route_spec["timeouts"] = timeouts;
        }
    }

    return {
        "name": route_name,
        "body": {
            "apiVersion": "http.keda.sh/v1beta1",
            "kind": "InterceptorRoute",
            "metadata": {
                "name": route_name,
                "namespace": spec.namespace,
                "labels": {
                    "app": spec.scale_target_name,
                    ** Autoscaler._managed_labels()
                }
            },
            "spec": route_spec
        }
    };
}

impl KEDAAutoscaler._build_http_scaled_object{
    scaled_obj_name = self.http_scaled_object_name_for(spec.scale_target_name);

    trigger_metadata: dict[str, any] = {
        "scalerAddress": self.http_scaler_address,
        "interceptorRoute": self.interceptor_route_name_for(spec.scale_target_name)
    };
    if spec.concurrency is not None {
        trigger_metadata["targetValue"] = str(spec.concurrency.target_value);
    } elif spec.request_rate is not None {
        trigger_metadata["targetValue"] = str(spec.request_rate.target_value);
        trigger_metadata["window"] = spec.request_rate.window;
        trigger_metadata["granularity"] = spec.request_rate.granularity;
    }

    scaled_obj_spec: dict[str, any] = {
        "scaleTargetRef": {
            "apiVersion": spec.scale_target_api_version,
            "kind": spec.scale_target_kind,
            "name": spec.scale_target_name
        },
        "minReplicaCount": spec.min_replicas,
        "maxReplicaCount": spec.max_replicas,
        "pollingInterval": spec.polling_interval,
        "cooldownPeriod": spec.cooldown_period,
        "triggers": [{"type": "external-push", "metadata": trigger_metadata}]
    };

    return {
        "name": scaled_obj_name,
        "body": {
            "apiVersion": "keda.sh/v1alpha1",
            "kind": "ScaledObject",
            "metadata": {
                "name": scaled_obj_name,
                "namespace": spec.namespace,
                "labels": {
                    "app": spec.scale_target_name,
                    ** Autoscaler._managed_labels()
                }
            },
            "spec": scaled_obj_spec
        }
    };
}

impl KEDAAutoscaler._validate_http_activation_spec{
    if spec.scale_target_kind == "Pod" {
        raise ValueError(
            f"HTTP activation requires a target exposing Kubernetes' /scale "
            f"subresource; got scale_target_kind='Pod' for "
            f"'{spec.scale_target_name}'. Use a Deployment, StatefulSet, or "
            f"compatible custom resource instead."
        );
    }
    if spec.target.port is not None and spec.target.port_name is not None {
        raise ValueError(
            "HTTPServiceTarget must set exactly one of port or port_name, not both."
        );
    }
    if spec.target.port is None and spec.target.port_name is None {
        raise ValueError(
            "HTTPServiceTarget must set exactly one of port or port_name."
        );
    }
    if spec.concurrency is None and spec.request_rate is None {
        raise ValueError(
            "HTTPActivationSpec requires at least one of concurrency or request_rate."
        );
    }
}
