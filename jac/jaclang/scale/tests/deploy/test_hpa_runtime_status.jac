# _normalize_hpa_status consumes the *typed* kubernetes client's `.to_dict()`
# output for a V2HorizontalPodAutoscaler, which uses snake_case keys
# (current_replicas, desired_replicas, last_transition_time, ...) -- not the
# camelCase of the raw REST JSON. get_runtime_status (Phase 2) is responsible
# for calling .to_dict() before handing data to this pure function.
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerState }


test "hpa normalize returns unknown when the HPA does not exist" {
    status = HPAAutoscaler()._normalize_hpa_status(None);
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.desired_replicas == 0;
    assert status.current_replicas == 0;
    assert status.ready_replicas == 0;
    assert "not found" in status.message.lower();
}

test "hpa normalize reports active when ScalingActive is healthy" {
    hpa = {
        "metadata": {"resource_version": "42"},
        "status": {
            "current_replicas": 2,
            "desired_replicas": 2,
            "conditions": [
                {
                    "type": "AbleToScale",
                    "status": "True",
                    "reason": "ReadyForNewScale",
                    "message": ""
                },
                {
                    "type": "ScalingActive",
                    "status": "True",
                    "reason": "ValidMetricFound",
                    "message": ""
                },
                {
                    "type": "ScalingLimited",
                    "status": "False",
                    "reason": "DesiredWithinRange",
                    "message": ""
                }
            ]
        }
    };
    status = HPAAutoscaler()._normalize_hpa_status(hpa);
    assert status.state == AutoscalerState.ACTIVE.value;
    assert status.desired_replicas == 2;
    assert status.current_replicas == 2;
    # Plain HPA status carries no readiness field -- current_replicas is the
    # closest available signal, so ready_replicas mirrors it by design.
    assert status.ready_replicas == 2;
    assert status.resource_version == "42";
    assert status.scaler_ready is True;
}

test "hpa normalize reports degraded when ScalingActive is false" {
    hpa = {
        "metadata": {"resource_version": "7"},
        "status": {
            "current_replicas": 1,
            "desired_replicas": 1,
            "conditions": [
                {
                    "type": "ScalingActive",
                    "status": "False",
                    "reason": "FailedGetResourceMetric",
                    "message": "unable to fetch metrics"
                }
            ]
        }
    };
    status = HPAAutoscaler()._normalize_hpa_status(hpa);
    assert status.state == AutoscalerState.DEGRADED.value;
    assert status.scaler_ready is False;
    assert "FailedGetResourceMetric" in status.message
        or "unable to fetch metrics" in status.message;
}

test "hpa normalize being clamped by ScalingLimited does not demote active to degraded" {
    hpa = {
        "status": {
            "current_replicas": 3,
            "desired_replicas": 3,
            "conditions": [
                {
                    "type": "ScalingActive",
                    "status": "True",
                    "reason": "ValidMetricFound"
                },
                {
                    "type": "ScalingLimited",
                    "status": "True",
                    "reason": "TooManyReplicas",
                    "message": "the desired replica count is more than the maximum replica count"
                }
            ]
        }
    };
    status = HPAAutoscaler()._normalize_hpa_status(hpa);
    assert status.state == AutoscalerState.ACTIVE.value;
    limited = [
        c
        for c in status.conditions
        if c["type"] == "ScalingLimited"
    ][0];
    assert limited["status"] == "True";
}

test "hpa normalize with missing conditions is unknown, not a crash" {
    hpa = {"status": {"current_replicas": 1, "desired_replicas": 1}};
    status = HPAAutoscaler()._normalize_hpa_status(hpa);
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.current_replicas == 1;
    assert status.desired_replicas == 1;
    assert status.ready_replicas == 1;
}

test "hpa normalize with an entirely empty status dict is unknown, not a crash" {
    status = HPAAutoscaler()._normalize_hpa_status({});
    assert status.state == AutoscalerState.UNKNOWN.value;
    assert status.desired_replicas == 0;
    assert status.current_replicas == 0;
    assert status.ready_replicas == 0;
}
