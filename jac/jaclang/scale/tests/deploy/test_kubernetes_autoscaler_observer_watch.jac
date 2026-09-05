# KubernetesAutoscalerObserver's watch loop and the KEDA state normalizer it
# calls into. Scoped to the review-caught bugs that have no other test net,
# per the "no unit tests, ~750 lines total" review pass:
#   - target correlation by scaleTargetRef, not app label (a0e5c2213) -- kept
#     as one lean direct assertion here rather than the full live-cluster
#     scenario, because keda_gateway_correlation_real_e2e.sh already proves
#     this end-to-end against a real cluster; this is just the fast local
#     regression net for the same bug.
#   - concurrent watch_namespace calls must never leave more or fewer than
#     one thread per kind (a check-then-act race)
#   - concurrent reconciles of the same target must fully serialize, or a
#     real "active" moment can be silently dropped (reproduced on a live
#     cluster during manual testing)
#   - three KEDA normalization bugs found on a live cluster: activating
#     before the generated HPA/Deployment join (103dd8057/51bd23f55), a
#     scaler read as active during its cooldown window before replicas
#     actually drop (2abc22371), and deactivating on inconsistent settling
#     replica counts while the trigger is inactive (666454207)
import unittest.mock;
import time;
import threading;
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver,
    WATCHED_KINDS
}
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerState,
    AutoscalerRuntimeStatus
}


def scaled_object(
    name: str = "orders-scaledobject",
    ready: str = "True",
    active: str = "False",
    target: str = "orders-deployment"
) -> dict {
    return {
        "metadata": {"name": name, "resourceVersion": "1"},
        "spec": {"scaleTargetRef": {"name": target}},
        "status": {
            "conditions": [
                {"type": "Ready", "status": ready},
                {"type": "Active", "status": active}
            ],
            "hpaName": f"{target}-hpa"
        }
    };
}

def typed_list_response(items: list[dict]) -> any {
    response = unittest.mock.MagicMock();
    response.items = [];
    for i in items {
        item = unittest.mock.MagicMock();
        item.to_dict.return_value = i;
        response.items.append(item);
    }
    response.metadata.resource_version = "0";
    return response;
}

def build_observer(scaled_objects: list[dict]) -> any {
    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.list_namespaced_custom_object.return_value = {
        "items": scaled_objects,
        "metadata": {"resourceVersion": "0"}
    };
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.list_namespaced_horizontal_pod_autoscaler.return_value = typed_list_response(
        []
    );
    mock_apps = unittest.mock.MagicMock();
    mock_apps.list_namespaced_deployment.return_value = typed_list_response([]);

    def no_events(
        kind: str,
        list_fn: any,
        namespace: str,
        label_selector: any,
        resource_version: any
    ) -> any {
        return iter([]);
    }

    return KubernetesAutoscalerObserver(
        _custom_api=mock_custom_api,
        _v2_api=mock_v2,
        _apps_api=mock_apps,
        _watch_factory=no_events
    );
}


def ready_condition(status: str = "True") -> dict {
    return {"type": "Ready", "status": status};
}

def active_condition(status: str) -> dict {
    return {"type": "Active", "status": status, "reason": "x"};
}

def keda_so(conditions: list[dict]) -> dict {
    return {
        "metadata": {"resourceVersion": "1"},
        "spec": {},
        "status": {"conditions": conditions, "hpaName": "orders-hpa"}
    };
}

def hpa_st(current: int, desired: int) -> dict {
    return {"status": {"current_replicas": current, "desired_replicas": desired}};
}

def dep_st(replicas: int, ready: int) -> dict {
    return {
        "status": {
            "replicas": replicas,
            "ready_replicas": ready,
            "available_replicas": ready
        }
    };
}

def check_keda(
    label: str, so: dict, hpa: (dict | None), deployment: (dict | None), expected: str
) {
    status = KEDAAutoscaler()._normalize_keda_status(so, hpa, deployment);
    assert status.state == expected , f"{label}: expected {expected}, got {status.state}";
}


test "KubernetesAutoscalerObserver watch loop: correlation, concurrency, and the KEDA state-machine bugs" {
    def step_correlation_uses_resource_name_not_app_label {
        # Reproduces jac-scale's real gateway/microservice deploy shape: the
        # Deployment is labeled app=gateway, but its ScaledObject/HPA are
        # labeled app=gateway-deployment. Before a0e5c2213 the observer
        # correlated all three by that `app` label and the join never
        # completed for this exact shape.
        obs = KubernetesAutoscalerObserver();
        deployment = {
            "metadata": {"name": "gateway-deployment", "labels": {"app": "gateway"}}
        };
        assert obs._target_name_for("deployment", deployment) == "gateway-deployment";

        scaled_obj = {
            "metadata": {"name": "gateway-deployment-scaledobject"},
            "spec": {"scaleTargetRef": {"name": "gateway-deployment"}}
        };
        assert obs._target_name_for("scaled_object", scaled_obj)
            == "gateway-deployment";
    }

    def step_concurrent_watch_namespace_stays_idempotent {
        # The original bug was a check-then-act race: Thread.start() ran
        # outside the lock, so a concurrent watch_namespace call could
        # register a second thread over an already-registered one, orphaning
        # the first (invisible to stop(), never joined).
        obs = build_observer([scaled_object()]);

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

    def step_reconcile_target_fully_serializes {
        # The original bug split one reconcile into three separate lock
        # acquisitions (snapshot the cache, compute the normalized status
        # unlocked, then commit), so two threads reconciling the same
        # target -- e.g. the hpa-watch and deployment-watch threads firing
        # near-simultaneously -- could interleave and lose whichever
        # transition was computed from a staler snapshot. Reproduced on a
        # real cluster: a real "active" moment never appeared in the
        # observed transition sequence at all.
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

    def step_keda_normalize_state_machine_bugs {
        check_keda(
            "Active=True with HPA still 0/0 is activating, not unknown",
            keda_so([ready_condition(), active_condition("True")]),
            hpa_st(0, 0),
            None,
            AutoscalerState.ACTIVATING.value
        );
        # Observed on a real cluster: KEDA flips Active=False (ScalerCooldown)
        # the instant traffic stops, well before the cooldown timer expires
        # and the HPA/Deployment actually reduce replicas. Nothing observable
        # has changed yet, so this must read as active, not deactivating.
        check_keda(
            "active during the cooldown window, before replicas actually drop",
            keda_so([ready_condition(), active_condition("False")]),
            hpa_st(1, 1),
            dep_st(1, 1),
            AutoscalerState.ACTIVE.value
        );
        # Observed during an actual scale-down: the trigger goes inactive and
        # the HPA's desired/current readings can be transiently inconsistent
        # for a moment before settling at zero. This fell through to unknown
        # before the fix.
        check_keda(
            "inconsistent settling replica counts while inactive is deactivating",
            keda_so([ready_condition(), active_condition("False")]),
            hpa_st(0, 1),
            dep_st(1, 1),
            AutoscalerState.DEACTIVATING.value
        );
    }

    step_correlation_uses_resource_name_not_app_label();
    step_concurrent_watch_namespace_stays_idempotent();
    step_reconcile_target_fully_serializes();
    step_keda_normalize_state_machine_bugs();
}
