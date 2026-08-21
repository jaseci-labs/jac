# Scope note: these tests exercise the ScaledObject watch/relist/dedup
# mechanics in isolation, per the Phase 4 plan. The "hpa" and "deployment"
# kinds are left empty (no items) in most fixtures here so the KEDA
# normalizer's replica counts default to 0 -- the reachable states from
# toggling only ScaledObject conditions are then INACTIVE (Active=False),
# DEGRADED (Ready=False), and UNKNOWN (no replica data to resolve Active=True
# against). Cross-kind joins that reach ACTIVATING/ACTIVE/DEACTIVATING by
# combining ScaledObject + HPA + Deployment are Phase 5's job.
import unittest.mock;
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
