# Scope note: the first block of tests below exercises the ScaledObject
# watch/relist/dedup mechanics in isolation, per the Phase 4 plan. The "hpa"
# and "deployment" kinds are left empty (no items) in most of those fixtures
# so the KEDA normalizer's replica counts default to 0 -- the reachable
# states from toggling only ScaledObject conditions are then INACTIVE
# (Active=False), DEGRADED (Ready=False), and ACTIVATING/UNKNOWN (Active=True
# with no replica data to resolve against). The cross-resource join tests at
# the bottom of this file (Phase 5) exercise the HPA and Deployment kinds for
# real, reaching ACTIVE by combining all three.
import unittest.mock;
import time;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver,
    WATCHED_KINDS
}


def scaled_object(
    name: str = "orders-scaledobject",
    resource_version: str = "1",
    ready: str = "True",
    active: str = "False",
    target: str = "orders-deployment"
) -> dict {
    return {
        "metadata": {
            "name": name,
            "resourceVersion": resource_version,
            "labels": {"app": target}
        },
        "status": {
            "conditions": [
                {"type": "Ready", "status": ready},
                {"type": "Active", "status": active}
            ],
            "hpaName": f"{target}-hpa"
        }
    };
}

def hpa_item(target: str, current: int, desired: int) -> dict {
    return {
        "metadata": {"name": f"{target}-hpa", "labels": {"app": target}},
        "status": {"current_replicas": current, "desired_replicas": desired}
    };
}

def deployment_item(target: str, replicas: int, ready_replicas: int) -> dict {
    return {
        "metadata": {"name": target, "labels": {"app": target}},
        "status": {
            "replicas": replicas,
            "ready_replicas": ready_replicas,
            "available_replicas": ready_replicas
        }
    };
}

def typed_item(to_dict_value: dict) -> any {
    item = unittest.mock.MagicMock();
    item.to_dict.return_value = to_dict_value;
    return item;
}

def typed_list_response(items: list[dict], resource_version: str = "0") -> any {
    response = unittest.mock.MagicMock();
    response.items = [typed_item(i) for i in items];
    response.metadata.resource_version = resource_version;
    return response;
}

def _stream_then_410(events: list) -> Iterator {
    for e in events {
        yield e;
    }
    raise ApiException(status=410);
}

def make_watch_factory(first_call_events: list) -> any {
    calls = [0];
    def factory(
        kind: str,
        list_fn: any,
        namespace: str,
        label_selector: any,
        resource_version: any
    ) -> any {
        if kind != "scaled_object" {
            return iter([]);
        }
        calls[0] = calls[0] + 1;
        if calls[0] == 1 {
            return iter(first_call_events);
        }
        return iter([]);
    }
    return factory;
}

def make_watch_factory_with_410(first_call_events: list) -> any {
    calls = [0];
    def factory(
        kind: str,
        list_fn: any,
        namespace: str,
        label_selector: any,
        resource_version: any
    ) -> any {
        if kind != "scaled_object" {
            return iter([]);
        }
        calls[0] = calls[0] + 1;
        if calls[0] == 1 {
            return _stream_then_410(first_call_events);
        }
        return iter([]);
    }
    return factory;
}

def make_list_dispatcher(first_response: dict, second_response: dict) -> any {
    # The real list call goes through functools.partial(..., group=, version=,
    # plural=), so this must tolerate arbitrary kwargs, not just namespace/
    # label_selector.
    calls = [0];
    def dispatcher(*args: any, **kwargs: any) -> dict {
        calls[0] = calls[0] + 1;
        if calls[0] == 1 {
            return first_response;
        }
        return second_response;
    }
    return dispatcher;
}

def build_observer(
    scaled_objects: list[dict],
    hpas: (list[dict] | None) = None,
    deployments: (list[dict] | None) = None,
    watch_factory: any = None
) -> any {
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.return_value = {
        "items": scaled_objects,
        "metadata": {"resourceVersion": "0"}
    };
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        hpas or []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response(
        deployments or []
    );

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=watch_factory or make_watch_factory([])
    );
    return (obs, mock_custom_api);
}


test "seed-only observation with no live stream events emits zero transitions" {
    seed_item = scaled_object(ready="True", active="False");
    (obs, _) = build_observer(scaled_objects=[seed_item]);
    sub = obs.subscribe();
    obs.watch_namespace("default");

    assert sub.poll(timeout_seconds=0.5) is None;

    obs.stop(drain=True);
}

test "a real state change on the ScaledObject alone delivers exactly one transition" {
    seed_item = scaled_object(ready="True", active="False");
    modified_item = scaled_object(resource_version="2", ready="False", active="False");

    # The relist mock must reflect the post-change state too, the same way a
    # real cluster's LIST would -- otherwise the next relist cycle reverts
    # the cache to the stale seed and fires a spurious second transition.
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = make_list_dispatcher(
        {"items": [seed_item], "metadata": {"resourceVersion": "1"}},
        {"items": [modified_item], "metadata": {"resourceVersion": "2"}}
    );
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response([]);

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=make_watch_factory(
            [{"type": "MODIFIED", "object": modified_item}]
        )
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    delivered = sub.poll(timeout_seconds=3.0);
    assert delivered is not None;
    assert delivered.previous_state == "inactive";
    assert delivered.state == "degraded";
    assert delivered.autoscaler_name == "orders-scaledobject";
    assert delivered.scale_target_name == "orders-deployment";

    assert sub.poll(timeout_seconds=0.4) is None;

    obs.stop(drain=True);
}

test "a MODIFIED event that does not change the normalized state emits no transition" {
    seed_item = scaled_object(ready="True", active="False");
    modified_same = scaled_object(resource_version="2", ready="True", active="False");

    (obs, _) = build_observer(
        scaled_objects=[seed_item],
        watch_factory=make_watch_factory(
            [{"type": "MODIFIED", "object": modified_same}]
        )
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    assert sub.poll(timeout_seconds=0.6) is None;

    obs.stop(drain=True);
}

test "a 410 mid-stream reconnect with an unchanged relist emits no transitions" {
    seed_item = scaled_object(ready="True", active="False");
    noop_modified = scaled_object(resource_version="5", ready="True", active="False");

    (obs, _) = build_observer(
        scaled_objects=[seed_item],
        watch_factory=make_watch_factory_with_410(
            [{"type": "MODIFIED", "object": noop_modified}]
        )
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    assert sub.poll(timeout_seconds=0.6) is None;

    obs.stop(drain=True);
}

test "a 410 mid-stream reconnect surfaces exactly one transition for the object that changed during the gap" {
    orders_seed = scaled_object(
        name="orders-scaledobject",
        target="orders-deployment",
        ready="True",
        active="False"
    );
    payments_seed = scaled_object(
        name="payments-scaledobject",
        target="payments-deployment",
        ready="True",
        active="False"
    );
    payments_changed = scaled_object(
        name="payments-scaledobject",
        target="payments-deployment",
        resource_version="9",
        ready="False",
        active="False"
    );

    first_list = {
        "items": [orders_seed, payments_seed],
        "metadata": {"resourceVersion": "1"}
    };
    second_list = {
        "items": [orders_seed, payments_changed],
        "metadata": {"resourceVersion": "2"}
    };

    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = make_list_dispatcher(
        first_list, second_list
    );
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response([]);

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=make_watch_factory_with_410([])
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    delivered = sub.poll(timeout_seconds=3.0);
    assert delivered is not None;
    assert delivered.scale_target_name == "payments-deployment";
    assert delivered.previous_state == "inactive";
    assert delivered.state == "degraded";

    assert sub.poll(timeout_seconds=0.4) is None;

    obs.stop(drain=True);
}

test "DELETED of a target ScaledObject transitions it to unknown with an explanatory message" {
    seed_item = scaled_object(ready="True", active="False");

    # The relist mock must stop returning the item once "deleted", the same
    # way a real cluster's LIST would -- otherwise the next relist cycle
    # resurrects it and fires a spurious second transition back to inactive.
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = make_list_dispatcher(
        {"items": [seed_item], "metadata": {"resourceVersion": "1"}},
        {"items": [], "metadata": {"resourceVersion": "2"}}
    );
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response([]);

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=make_watch_factory([{"type": "DELETED", "object": seed_item}])
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    delivered = sub.poll(timeout_seconds=3.0);
    assert delivered is not None;
    assert delivered.previous_state == "inactive";
    assert delivered.state == "unknown";
    assert delivered.message is not None;

    assert sub.poll(timeout_seconds=0.4) is None;

    obs.stop(drain=True);
}

test "watch_namespace is idempotent -- calling it twice does not spawn duplicate threads" {
    seed_item = scaled_object(ready="True", active="False");
    (obs, _) = build_observer(scaled_objects=[seed_item]);

    obs.watch_namespace("default");
    first_threads = dict(obs._threads);
    assert len(first_threads) == len(WATCHED_KINDS);

    obs.watch_namespace("default");
    second_threads = dict(obs._threads);
    assert len(second_threads) == len(WATCHED_KINDS);
    for key in first_threads {
        assert second_threads[key] is first_threads[key];
    }

    obs.stop(drain=True);
}

test "stop(drain=True) joins every watch thread before returning" {
    seed_item = scaled_object(ready="True", active="False");
    (obs, _) = build_observer(scaled_objects=[seed_item]);

    obs.watch_namespace("default");
    threads = list(obs._threads.values());
    assert len(threads) == len(WATCHED_KINDS);

    obs.stop(drain=True);

    for t in threads {
        assert t.is_alive() is False;
    }
    assert obs._threads == {};
}


# --- Phase 5: cross-resource join ---
# These two exercise the "hpa" and "deployment" kinds for real, joining them
# with the ScaledObject cache through _reconcile_target.

test "a ScaledObject reconciled with no cached HPA/Deployment data starts activating, not unknown" {
    seed_item = scaled_object(ready="True", active="True");
    degraded_item = scaled_object(resource_version="2", ready="False", active="True");

    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = make_list_dispatcher(
        {"items": [seed_item], "metadata": {"resourceVersion": "1"}},
        {"items": [degraded_item], "metadata": {"resourceVersion": "2"}}
    );
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response([]);

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=make_watch_factory_with_410([])
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    # The first observation (activating) is recorded silently, per the
    # no-manufactured-history rule -- force a second, real change so it
    # surfaces as this transition's previous_state instead of asserting on
    # the observer's internal cache directly.
    delivered = sub.poll(timeout_seconds=3.0);
    assert delivered is not None;
    assert delivered.previous_state == "activating";
    assert delivered.state == "degraded";

    obs.stop(drain=True);
}

test "a Deployment readiness update alone can flip a target from activating to active" {
    target = "orders-deployment";
    seed_scaled_object = scaled_object(target=target, ready="True", active="True");
    seed_hpa = hpa_item(target, current=1, desired=1);
    seed_deployment = deployment_item(target, replicas=1, ready_replicas=0);
    updated_deployment = deployment_item(target, replicas=1, ready_replicas=1);

    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.return_value = {
        "items": [seed_scaled_object],
        "metadata": {"resourceVersion": "1"}
    };
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        [seed_hpa]
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response(
        [seed_deployment]
    );

    def factory(
        kind: str,
        list_fn: any,
        namespace: str,
        label_selector: any,
        resource_version: any
    ) -> any {
        if kind == "deployment" {
            return iter(
                [{"type": "MODIFIED", "object": typed_item(updated_deployment)}]
            );
        }
        return iter([]);
    }

    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=factory
    );
    sub = obs.subscribe();
    obs.watch_namespace("default");

    # The three kinds seed on independent threads, so which one populates
    # the target's cache slot first (and therefore what the silently-recorded
    # first state is) is a genuine race. "active" (desired == current ==
    # ready == 1) is only reachable after the scripted Deployment update
    # fires, though -- no partial-cache reconcile from any arrival order can
    # coincidentally land there -- so draining until it appears is race-
    # tolerant regardless of thread scheduling.
    found_active = False;
    deadline = time.time() + 3.0;
    while time.time() < deadline {
        delivered = sub.poll(timeout_seconds=0.5);
        if delivered is None {
            continue;
        }
        assert delivered.scale_target_name == target;
        if delivered.state == "active" {
            found_active = True;
            break;
        }
    }
    assert found_active , "expected a transition to active driven by the Deployment update alone";

    obs.stop(drain=True);
}


# --- target correlation ---
# jac-scale controls the `app` label on the ScaledObject/HPA resources it
# creates itself (_managed_labels/_build_manifests), but not on the user's
# own target Deployment -- so the deployment kind must correlate by the
# resource's own name, not by a label jac-scale never promised to set there.

test "_target_name_for uses the app label for scaled_object and hpa resources" {
    obs = KubernetesAutoscalerObserver();
    scaled_object = {
        "metadata": {
            "name": "orders-scaledobject",
            "labels": {"app": "orders-deployment"}
        }
    };
    hpa = {"metadata": {"name": "orders-hpa", "labels": {"app": "orders-deployment"}}};

    assert obs._target_name_for("scaled_object", scaled_object) == "orders-deployment";
    assert obs._target_name_for("hpa", hpa) == "orders-deployment";
}

test "_target_name_for uses the deployment's own name, with no app label required" {
    obs = KubernetesAutoscalerObserver();
    # A user's Deployment jac-scale did not create, and so never labeled --
    # this is the realistic shape most target Deployments actually have.
    deployment = {"metadata": {"name": "orders-deployment", "labels": {}}};

    assert obs._target_name_for("deployment", deployment) == "orders-deployment";
}

test "_target_name_for returns None for a scaled_object/hpa resource with no app label" {
    obs = KubernetesAutoscalerObserver();
    scaled_object = {"metadata": {"name": "orphan-scaledobject", "labels": {}}};
    assert obs._target_name_for("scaled_object", scaled_object) is None;
}

test "_handle_event logs and silently ignores a resource that cannot be correlated" {
    mock_logger = unittest.mock.MagicMock();
    obs = KubernetesAutoscalerObserver(logger=mock_logger);
    orphan = {"metadata": {"name": "orphan-scaledobject", "labels": {}}};

    obs._handle_event("default", "scaled_object", "ADDED", orphan);

    assert obs._target_cache == {};
    mock_logger.debug.assert_called_once();
    logged_msg = mock_logger.debug.call_args[0][0];
    assert "orphan-scaledobject" in logged_msg;
}


# --- watch_namespace concurrency ---
# The original bug was a check-then-act race: Thread.start() ran outside the
# lock, so a concurrent watch_namespace call could see the just-registered
# (but not-yet-started) thread's is_alive() as False and register a second
# thread over it, orphaning the first (invisible to stop()/health(), never
# joined). This can't be reproduced deterministically without a hook into
# the exact register/start window, so this is a best-effort concurrent
# stress test: it hammers watch_namespace from many threads at once and
# checks the invariant that must always hold afterward, rather than proving
# the original race on a single run.
import threading;

test "concurrent watch_namespace calls never leave more or fewer than one thread per kind" {
    seed_item = scaled_object(ready="True", active="False");
    (obs, _) = build_observer(scaled_objects=[seed_item]);

    def call_watch_namespace {
        for _ in range(20) {
            obs.watch_namespace("default");
        }
    }

    callers = [threading.Thread(target=call_watch_namespace) for _ in range(8)];
    for c in callers {
        c.start();
    }
    for c in callers {
        c.join(timeout=10.0);
    }

    assert len(obs._threads) == len(WATCHED_KINDS);
    for t in obs._threads.values() {
        assert t.is_alive() is True;
    }

    obs.stop(drain=True);
}


# --- _reconcile_target concurrency ---
# The original bug split one reconcile into three separate lock acquisitions
# (snapshot the cache, compute the normalized status unlocked, then commit
# to _last_state), so two threads reconciling the same target -- e.g. the
# hpa-watch and deployment-watch threads both firing for one target near-
# simultaneously -- could interleave: whichever commits last wins, even if
# it was computed from a staler snapshot. This was independently reproduced
# against a real cluster during manual testing: a real "active" moment (the
# pod really was 1/1 ready) never appeared in the observed transition
# sequence at all.
test "_reconcile_target fully serializes concurrent reconciles of the same target" {
    import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
    import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerRuntimeStatus }

    obs = KubernetesAutoscalerObserver();
    key = "default::orders-deployment";
    obs._target_cache[key] = {
        "scaled_object": {
            "metadata": {"name": "orders-scaledobject", "resourceVersion": "1"},
            "status": {
                "conditions": [
                    {"type": "Ready", "status": "True"},
                    {"type": "Active", "status": "False"}
                ]
            }
        },
        "hpa": None,
        "deployment": None
    };

    in_flight = [0];
    max_in_flight = [0];
    counter_lock = threading.Lock();

    def slow_normalize(scaled_object: any, hpa: any, deployment: any) -> any {
        with counter_lock {
            in_flight[0] = in_flight[0] + 1;
            max_in_flight[0] = max(max_in_flight[0], in_flight[0]);
        }
        time.sleep(0.05);
        with counter_lock {
            in_flight[0] = in_flight[0] - 1;
        }
        return AutoscalerRuntimeStatus(
            state="active", desired_replicas=1, current_replicas=1, ready_replicas=1
        );
    }

    def reconcile {
        obs._reconcile_target("default", "orders-deployment");
    }

    with unittest.mock.patch.object(
        KEDAAutoscaler, "_normalize_keda_status", side_effect=slow_normalize
    ) {
        threads = [threading.Thread(target=reconcile) for _ in range(5)];
        for t in threads {
            t.start();
        }
        for t in threads {
            t.join(timeout=5.0);
        }
    }

    assert max_in_flight[0] == 1 , f"expected concurrent reconciles of the same target to be fully serialized, but saw {max_in_flight[
        0
    ]} run their compute step at once";
}


# --- stop() drain bookkeeping ---

test "stop(drain=True) keeps tracking a thread that did not finish joining within the deadline" {
    obs = KubernetesAutoscalerObserver();
    stuck = unittest.mock.MagicMock();
    stuck.is_alive.return_value = True;
    finished = unittest.mock.MagicMock();
    finished.is_alive.return_value = False;
    obs._threads = {"default::scaled_object": stuck, "default::hpa": finished};

    obs.stop(drain=True);

    assert "default::scaled_object" in obs._threads;
    assert "default::hpa" not in obs._threads;
    stuck.join.assert_called_once();
    finished.join.assert_called_once();
}

test "stop(drain=False) clears bookkeeping immediately without joining" {
    obs = KubernetesAutoscalerObserver();
    t = unittest.mock.MagicMock();
    obs._threads = {"default::scaled_object": t};

    obs.stop(drain=False);

    assert obs._threads == {};
    t.join.assert_not_called();
}


# --- watch-loop retry backoff ---

test "_watch_loop backs off with increasing delay across consecutive failures, not a flat retry" {
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = RuntimeError(
        "permanent failure (e.g. missing RBAC)"
    );
    obs = KubernetesAutoscalerObserver(_custom_api=mock_custom_api);

    delays = [];
    def fake_wait_or_stop(observer: any, seconds: float) -> bool {
        delays.append(seconds);
        if len(delays) >= 4 {
            obs._stop_event.set();
        }
        return obs._stop_event.is_set();
    }

    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.kubernetes_observer.wait_or_stop",
        side_effect=fake_wait_or_stop
    ) {
        obs._watch_loop("default", "scaled_object", None);
    }

    assert len(delays) >= 3;
    assert delays[1] > delays[0] , f"expected increasing backoff, got {delays}";
    assert delays[2] > delays[1] , f"expected increasing backoff, got {delays}";
}

test "_watch_loop resets the backoff after a successful iteration" {
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.side_effect = [
        RuntimeError("transient"),
        RuntimeError("transient"),
        {"items": [], "metadata": {"resourceVersion": "1"}},
        RuntimeError("transient again")
    ];
    obs = KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api, _watch_factory=make_watch_factory([])
    );

    delays = [];
    def fake_wait_or_stop(observer: any, seconds: float) -> bool {
        delays.append(seconds);
        if len(delays) >= 4 {
            obs._stop_event.set();
        }
        return obs._stop_event.is_set();
    }

    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.kubernetes_observer.wait_or_stop",
        side_effect=fake_wait_or_stop
    ) {
        obs._watch_loop("default", "scaled_object", None);
    }

    assert delays[1] > delays[0] , f"expected backoff to grow across the first two failures, got {delays}";
    assert delays[2] < delays[1] , f"expected the successful 3rd iteration to reset the backoff, got {delays}";
}


# --- API client caching ---

test "_kind_config caches the constructed API client across repeated calls" {
    obs = KubernetesAutoscalerObserver();

    obs._kind_config("scaled_object");
    first = obs._custom_api;
    assert first is not None;

    obs._kind_config("scaled_object");
    assert obs._custom_api is first;
}
