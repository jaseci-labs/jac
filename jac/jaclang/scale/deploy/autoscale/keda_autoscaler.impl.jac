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
        # cooldownPeriod only covers scale-to-zero; 1..N scaling needs this.
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
    for plural in ["scaledobjects", "triggerauthentications"] {
        try {
            items = api.list_namespaced_custom_object(
                group="keda.sh",
                version="v1alpha1",
                namespace=namespace,
                plural=plural,
                label_selector=label_selector
            );
            for item in items.get("items", []) {
                item_name = item["metadata"]["name"];
                try {
                    api.delete_namespaced_custom_object(
                        group="keda.sh",
                        version="v1alpha1",
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
