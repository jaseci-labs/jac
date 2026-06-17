"""Derive cache key from active cluster host; falls back to 'default' if config is unavailable."""
impl KEDAAutoscaler._get_cluster_key{
    try {
        import from kubernetes.client { Configuration }
        return Configuration.get_default_copy().host or "default";
    } except (ImportError, AttributeError) {
        return "default";
    }
}

"""Check KEDA CRDs are present; result cached per cluster host to avoid repeated API calls on multi-service deploys."""
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
        # 422: some distributions (OpenShift, certain EKS builds) return this instead of 404 when the keda.sh CRD group is absent
        if e.status in [404, 422] {
            KEDAAutoscaler._preflight_cache[cluster_key] = False;
            return install_warning;
        }
        raise;
    }
}

"""Convert a Trigger to a KEDA trigger dict; coerces all metadata values to strings."""
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
            # KEDA admission webhook rejects non-string metadata values (e.g. TOML parses threshold = 100 as int)
            "metadata": {k: str(v) for (k, v) in trigger.metadata.items()}
        };
    }
    if trigger.name {
        keda_trigger["name"] = trigger.name;
    }
    if trigger.auth and trigger.auth.secret_refs {
        auth_name = f"{trigger.name or trigger.type}-trigger-auth";
        keda_trigger["authenticationRef"] = {"name": auth_name};
    }
    return keda_trigger;
}

"""Build the ScaledObject body and resource name; returns both in a wrapper dict for the apply path."""
impl KEDAAutoscaler._build_manifests{
    scaled_obj_name = spec.autoscaler_name or f"{spec.scale_target_name}-scaledobject";
    keda_triggers: list[dict[str, any]] = [];
    for trigger in spec.triggers {
        keda_triggers.append(self._build_trigger(trigger));
    }
    # KEDA rejects a ScaledObject with an empty triggers array
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
            # apps/v1 covers Deployment/StatefulSet/ReplicaSet/DaemonSet; add target_api_version to AutoscalerSpec for CRD-backed workloads
            "apiVersion": "apps/v1",
            "kind": spec.target_kind,
            "name": spec.scale_target_name
        },
        "minReplicaCount": spec.min_replicas,
        "maxReplicaCount": spec.max_replicas,
        "pollingInterval": spec.polling_interval,
        "cooldownPeriod": spec.cooldown_period,
        "triggers": keda_triggers
    };
    # absent != 0: absent means "use minReplicaCount as floor"; 0 means true scale-to-zero
    if spec.idle_replicas is not None {
        scaled_obj_spec["idleReplicaCount"] = spec.idle_replicas;
    }
    # absent means no delay; emitting 0 suppresses KEDA's natural warm-up on some clusters
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

"""Create or patch the TriggerAuthentication for a trigger that carries secret references."""
impl KEDAAutoscaler._apply_trigger_auth{
    # TODO(#6535): Three known naming gaps deferred to follow-up:
    # 1. Per-service isolation: two services sharing the same trigger name share one TriggerAuthentication.
    # 2. Within-spec collision: two unnamed triggers of the same type in one spec overwrite each other's auth.
    # 3. destroy() gap: single-resource teardown has no trigger list so cannot clean up TriggerAuthentications.
    # All three are tracked in https://github.com/jaseci-labs/jaseci/issues/6535.
    if not trigger.auth {
        return;
    }
    if not trigger.auth.secret_refs {
        return;
    }
    auth_name = f"{trigger.name or trigger.type}-trigger-auth";
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

"""Run preflight, write TriggerAuthentications, then create or patch the ScaledObject."""
impl KEDAAutoscaler.apply{
    warnings = self.preflight();
    if warnings {
        if self.logger {
            self.logger.warn(warnings[0]);
        }
        return False;
    }
    api = self._custom_api or client.CustomObjectsApi();
    # Engine-switch: remove any competing HPA left from a prior hpa-engine deploy.
    # An active HPA and a new ScaledObject both drive spec.replicas on the same
    # Deployment, producing non-deterministic scaling behaviour.
    try {
        (
            self._v2_api or AutoscalingV2Api()
        ).delete_namespaced_horizontal_pod_autoscaler(
            name=f"{spec.app_name or spec.scale_target_name}-hpa",
            namespace=spec.namespace
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
    # TriggerAuthentication must exist before ScaledObject; KEDA validates authenticationRef at admission time
    for trigger in spec.triggers {
        self._apply_trigger_auth(api, trigger, spec.namespace);
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

"""Delete a single ScaledObject by name; no-op if already absent."""
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

"""Delete all jac-scale ScaledObjects and TriggerAuthentications in namespace by label."""
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
    # Also sweep any HPAs left from an hpa-engine deploy of the same app
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

"""Return the ScaledObject resource name for a scale target."""
impl KEDAAutoscaler.resource_name_for{
    return f"{target}-scaledobject";
}
