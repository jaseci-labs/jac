import functools;
import time;
import from datetime { datetime, UTC }
import from jaclang.scale.events.streams._stream_common { wait_or_stop }
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }

impl KubernetesAutoscalerObserver.start{
    self._stop_event.clear();
}

impl KubernetesAutoscalerObserver.stop{
    self._stop_event.set();
    if drain {
        deadline = time.time() + 10.0;
        with self._lock {
            threads = list(self._threads.values());
        }
        for t in threads {
            remaining = max(0.0, deadline - time.time());
            try {
                t.join(timeout=remaining);
            } except Exception as e {
                if self.logger {
                    self.logger.warn(f"autoscaler observer thread join failed: {e}");
                }
            }
        }
    }
    with self._lock {
        self._threads = {};
    }
}

impl KubernetesAutoscalerObserver.watch_namespace{
    self._stop_event.clear();
    for kind in WATCHED_KINDS {
        thread_key = f"{namespace}::{kind}";
        with self._lock {
            existing = self._threads.get(thread_key);
            if existing is not None and existing.is_alive() {
                continue;
            }
            t = Thread(
                target=self._watch_loop,
                args=(namespace, kind, label_selector),
                name=f"jac-scale-autoscaler-observer-{namespace}-{kind}",
                daemon=True
            );
            self._threads[thread_key] = t;
        }
        t.start();
    }
}

impl KubernetesAutoscalerObserver.subscribe{
    sub = AutoscalerSubscription(
        autoscaler_name=autoscaler_name,
        scale_target_name=scale_target_name,
        max_queue=max_queue,
        backpressure=backpressure
    );
    with self._lock {
        self._subscriptions.append(sub);
    }
    return sub;
}

impl KubernetesAutoscalerObserver.health{
    with self._lock {
        return {
            "watching": list(self._threads.keys()),
            "subscriptions": len(self._subscriptions),
            "targets_cached": len(self._target_cache)
        };
    }
}

impl KubernetesAutoscalerObserver._kind_config{
    if kind == "scaled_object" {
        api = self._custom_api or client.CustomObjectsApi();
        list_fn = functools.partial(
            api.list_namespaced_custom_object,
            group="keda.sh",
            version="v1alpha1",
            plural="scaledobjects"
        );
        return {"list_fn": list_fn, "typed": False};
    }
    if kind == "hpa" {
        api = self._v2_api or AutoscalingV2Api();
        return {
            "list_fn": api.list_namespaced_horizontal_pod_autoscaler,
            "typed": True
        };
    }
    if kind == "deployment" {
        api = self._apps_api or client.AppsV1Api();
        return {"list_fn": api.list_namespaced_deployment, "typed": True};
    }
    raise ValueError(f"Unknown watch kind: {kind}");
}

impl KubernetesAutoscalerObserver._list_and_seed{
    cfg = self._kind_config(kind);
    list_fn = cfg["list_fn"];
    response = list_fn(namespace=namespace, label_selector=label_selector);
    if cfg["typed"] {
        resource_version = response.metadata.resource_version;
        items = [item.to_dict() for item in response.items];
    } else {
        resource_version = response.get("metadata", {}).get("resourceVersion");
        items = response.get("items", []);
    }
    return (resource_version, items, list_fn);
}

impl KubernetesAutoscalerObserver._stream{
    if self._watch_factory {
        return self._watch_factory(
            kind, list_fn, namespace, label_selector, resource_version
        );
    }
    return watch.Watch().stream(
        list_fn,
        namespace=namespace,
        label_selector=label_selector,
        resource_version=resource_version
    );
}

impl KubernetesAutoscalerObserver._watch_loop{
    while not self._stop_event.is_set() {
        try {
            (resource_version, items, list_fn) = self._list_and_seed(
                kind, namespace, label_selector
            );
            for resource in items {
                self._handle_event(namespace, kind, "ADDED", resource);
            }

            stream = self._stream(
                kind, list_fn, namespace, label_selector, resource_version
            );
            for event in stream {
                if self._stop_event.is_set() {
                    break;
                }
                event_type = event["type"];
                if event_type == "BOOKMARK" {
                    continue;
                }
                raw_obj = event["object"];
                resource = raw_obj if kind == "scaled_object" else raw_obj.to_dict();
                self._handle_event(namespace, kind, event_type, resource);
            }
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"autoscaler observer watch loop error ({namespace}/{kind}): {e}"
                );
            }
        }
        if self._stop_event.is_set() {
            return;
        }
        wait_or_stop(self, 0.05);
    }
}

impl KubernetesAutoscalerObserver._target_name_for{
    return (resource.get("metadata") or {}).get("labels", {}).get("app");
}

impl KubernetesAutoscalerObserver._handle_event{
    target_name = self._target_name_for(resource);
    if target_name is None {
        return;
    }
    key = f"{namespace}::{target_name}";
    with self._lock {
        slot = self._target_cache.setdefault(
            key, {"scaled_object": None, "hpa": None, "deployment": None}
        );
        slot[kind] = None if event_type == "DELETED" else resource;
    }
    self._reconcile_target(namespace, target_name);
}

impl KubernetesAutoscalerObserver._reconcile_target{
    key = f"{namespace}::{scale_target_name}";
    with self._lock {
        slot = self._target_cache.get(
            key, {"scaled_object": None, "hpa": None, "deployment": None}
        );
        scaled_object = slot.get("scaled_object");
        hpa = slot.get("hpa");
        deployment = slot.get("deployment");
    }

    if scaled_object is not None {
        status = KEDAAutoscaler()._normalize_keda_status(
            scaled_object, hpa, deployment
        );
        autoscaler_name = scaled_object.get("metadata", {}).get("name")
            or scale_target_name;
        resource_version = scaled_object.get("metadata", {}).get("resourceVersion")
            or "";
    } elif hpa is not None {
        status = HPAAutoscaler()._normalize_hpa_status(hpa);
        autoscaler_name = hpa.get("metadata", {}).get("name") or scale_target_name;
        resource_version = status.resource_version or "";
    } else {
        status = AutoscalerRuntimeStatus(
            state=AutoscalerState.UNKNOWN.value,
            desired_replicas=0,
            current_replicas=0,
            ready_replicas=0,
            message="no autoscaler resource found for target"
        );
        autoscaler_name = scale_target_name;
        resource_version = "";
    }

    with self._lock {
        previous_state = self._last_state.get(key);
        self._last_state[key] = status.state;
    }

    if previous_state is None or previous_state == status.state {
        return;
    }

    transition = AutoscalerTransition(
        autoscaler_name=autoscaler_name,
        scale_target_name=scale_target_name,
        namespace=namespace,
        previous_state=previous_state,
        state=status.state,
        observed_at=datetime.now(UTC).isoformat(),
        resource_version=str(resource_version),
        message=status.message
    );
    self._emit(transition);
}

impl KubernetesAutoscalerObserver._emit{
    with self._lock {
        subs = list(self._subscriptions);
    }
    for sub in subs {
        sub._deliver(transition);
    }
}
