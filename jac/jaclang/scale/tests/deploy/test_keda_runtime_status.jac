# _normalize_keda_status joins three raw objects with two different casing
# conventions, matching what each Kubernetes API actually returns:
#   - scaled_object: raw REST JSON from CustomObjectsApi -> camelCase
#     (resourceVersion, hpaName, minReplicaCount, ...)
#   - hpa / deployment: the typed clients' `.to_dict()` output -> snake_case
#     (current_replicas, ready_replicas, ...)
# get_runtime_status (Phase 2) is responsible for fetching all three and
# handing them to this pure function untouched.
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerState }


def ready_condition(status: str = "True") -> dict {
    return {
        "type": "Ready",
        "status": status,
        "reason": "ScaledObjectReady",
        "message": ""
    };
}

def active_condition(status: str) -> dict {
    reason = "ScalerActive" if status == "True" else "ScalerNotActive";
    return {"type": "Active", "status": status, "reason": reason, "message": ""};
}


test "keda normalize returns unknown when the ScaledObject does not exist" {
    status = KEDAAutoscaler()._normalize_keda_status(None, None, None);
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.desired_replicas == 0;
    assert status.current_replicas == 0;
    assert status.ready_replicas == 0;
    assert "not found" in status.message.lower();
}

test "keda normalize reports degraded when Ready is false" {
    scaled_object = {
        "metadata": {"resourceVersion": "10"},
        "status": {
            "conditions": [
                {
                    "type": "Ready",
                    "status": "False",
                    "reason": "ScaledObjectCheckFailed",
                    "message": "invalid trigger metadata"
                },
                active_condition("False")
            ]
        }
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, None, None);
    assert status.state == AutoscalerState.DEGRADED.value;
    assert status.scaler_ready is False;
    assert "ScaledObjectCheckFailed" in status.message
        or "invalid trigger metadata" in status.message;
}

test "keda normalize reports degraded and names the static fallback when Fallback is true" {
    scaled_object = {
        "metadata": {"resourceVersion": "11"},
        "status": {
            "conditions": [
                ready_condition(),
                active_condition("True"),
                {
                    "type": "Fallback",
                    "status": "True",
                    "reason": "FallbackExists",
                    "message": "using fallback"
                }
            ]
        }
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, None, None);
    assert status.state == AutoscalerState.DEGRADED.value;
    assert "fallback" in status.message.lower();
}

test "keda normalize reports inactive with a distinct message when Paused is true" {
    scaled_object = {
        "metadata": {"resourceVersion": "12"},
        "status": {
            "conditions": [
                ready_condition(),
                active_condition("False"),
                {"type": "Paused", "status": "True"}
            ]
        }
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, None, None);
    assert status.state == AutoscalerState.INACTIVE.value;
    assert "paused" in status.message.lower();
}

test "keda normalize reports inactive for idle scale-to-zero -- this is not an error" {
    scaled_object = {
        "metadata": {"resourceVersion": "13"},
        "spec": {"minReplicaCount": 0, "maxReplicaCount": 5},
        "status": {
            "conditions": [ready_condition(), active_condition("False")],
            "hpaName": "orders-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 0, "desired_replicas": 0}};
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, None);
    assert status.state == AutoscalerState.INACTIVE.value;
    assert status.desired_replicas == 0;
    assert status.current_replicas == 0;
    assert status.trigger_active is False;
}

test "keda normalize reports activating when the trigger fired before any HPA/Deployment data exists" {
    # The ScaledObject watch event can arrive before the observer has cached
    # anything for the HPA or Deployment kind -- Active=True is still real
    # signal (something is starting up), so this must not read as "unknown".
    scaled_object = {
        "metadata": {"resourceVersion": "20"},
        "status": {
            "conditions": [ready_condition(), active_condition("True")],
            "hpaName": "orders-hpa"
        }
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, None, None);
    assert status.state == AutoscalerState.ACTIVATING.value;
    assert status.desired_replicas == 0;
    assert status.current_replicas == 0;
    assert status.ready_replicas == 0;
    assert status.trigger_active is True;
}

test "keda normalize reports activating while trigger fired but pods are not ready yet" {
    scaled_object = {
        "metadata": {"resourceVersion": "14"},
        "status": {
            "conditions": [ready_condition(), active_condition("True")],
            "hpaName": "orders-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 1, "desired_replicas": 1}};
    deployment = {
        "status": {"replicas": 1, "ready_replicas": 0, "available_replicas": 0}
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, deployment);
    assert status.state == AutoscalerState.ACTIVATING.value;
    assert status.trigger_active is True;
    assert status.ready_replicas == 0;
    assert status.desired_replicas == 1;
}

test "keda normalize reports active once desired current and ready all agree" {
    scaled_object = {
        "metadata": {"resourceVersion": "15"},
        "status": {
            "conditions": [ready_condition(), active_condition("True")],
            "hpaName": "orders-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 2, "desired_replicas": 2}};
    deployment = {
        "status": {"replicas": 2, "ready_replicas": 2, "available_replicas": 2}
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, deployment);
    assert status.state == AutoscalerState.ACTIVE.value;
    assert status.ready_replicas == 2;
}

test "keda normalize reports deactivating while draining down toward a lower target" {
    scaled_object = {
        "metadata": {"resourceVersion": "16"},
        "status": {
            "conditions": [ready_condition(), active_condition("False")],
            "hpaName": "orders-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 2, "desired_replicas": 1}};
    deployment = {
        "status": {"replicas": 2, "ready_replicas": 2, "available_replicas": 2}
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, deployment);
    assert status.state == AutoscalerState.DEACTIVATING.value;
}

test "keda normalize distinguishes cold-started-but-not-yet-ready from fully active" {
    # The HTTP Add-on's external-push trigger has already told KEDA to scale
    # up (Active=True, desired bumped), but the target Deployment has not
    # passed readiness probes yet -- traffic must not be considered served.
    scaled_object = {
        "metadata": {"resourceVersion": "17"},
        "status": {
            "conditions": [ready_condition(), active_condition("True")],
            "hpaName": "orders-http-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 1, "desired_replicas": 1}};
    deployment = {
        "status": {"replicas": 1, "ready_replicas": 0, "available_replicas": 0}
    };
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, deployment);
    assert status.state == AutoscalerState.ACTIVATING.value;
    assert status.state != AutoscalerState.ACTIVE.value;
}

test "keda normalize with no conditions at all is unknown, not a crash" {
    scaled_object = {"metadata": {"resourceVersion": "18"}, "status": {}};
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, None, None);
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.trigger_active is None;
    assert status.scaler_ready is None;
}

test "keda normalize with an unclassifiable combination falls through to unknown, not a crash" {
    # Ready and Active both healthy but desired is zero while Active=True --
    # not a shape any of the documented transitions describe.
    scaled_object = {
        "metadata": {"resourceVersion": "19"},
        "status": {
            "conditions": [ready_condition(), active_condition("True")],
            "hpaName": "orders-hpa"
        }
    };
    hpa = {"status": {"current_replicas": 0, "desired_replicas": 0}};
    status = KEDAAutoscaler()._normalize_keda_status(scaled_object, hpa, None);
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.message is not None;
}

test "hpa and keda normalizers agree on the AutoscalerState vocabulary" {
    hpa_status = HPAAutoscaler()._normalize_hpa_status(
        {
            "status": {
                "current_replicas": 1,
                "desired_replicas": 1,
                "conditions": [
                    {
                        "type": "ScalingActive",
                        "status": "True",
                        "reason": "ValidMetricFound"
                    }
                ]
            }
        }
    );
    keda_status = KEDAAutoscaler()._normalize_keda_status(
        {
            "metadata": {"resourceVersion": "1"},
            "status": {
                "conditions": [ready_condition(), active_condition("True")],
                "hpaName": "x-hpa"
            }
        },
        {"status": {"current_replicas": 1, "desired_replicas": 1}},
        {"status": {"replicas": 1, "ready_replicas": 1, "available_replicas": 1}}
    );
    valid_states = {s.value for s in AutoscalerState};
    assert hpa_status.state in valid_states;
    assert keda_status.state in valid_states;
    assert hpa_status.state == AutoscalerState.ACTIVE.value;
    assert keda_status.state == AutoscalerState.ACTIVE.value;
}
