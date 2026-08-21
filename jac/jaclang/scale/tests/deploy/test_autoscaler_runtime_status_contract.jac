import from jaclang.scale.deploy.autoscale.autoscaler {
    Autoscaler,
    AutoscalerState,
    AutoscalerRuntimeStatus,
    AutoscalerTransition
}


test "AutoscalerState enumerates exactly the six normalized states" {
    assert AutoscalerState.INACTIVE.value == "inactive";
    assert AutoscalerState.ACTIVATING.value == "activating";
    assert AutoscalerState.ACTIVE.value == "active";
    assert AutoscalerState.DEACTIVATING.value == "deactivating";
    assert AutoscalerState.DEGRADED.value == "degraded";
    assert AutoscalerState.UNKNOWN.value == "unknown";
}

test "AutoscalerRuntimeStatus requires state and replica counts, everything else defaults" {
    status = AutoscalerRuntimeStatus(
        state=AutoscalerState.ACTIVE.value,
        desired_replicas=2,
        current_replicas=2,
        ready_replicas=2
    );
    assert status.state == "active";
    assert status.desired_replicas == 2;
    assert status.current_replicas == 2;
    assert status.ready_replicas == 2;
    assert status.trigger_active is None;
    assert status.scaler_ready is None;
    assert status.conditions == [];
    assert status.resource_version is None;
    assert status.message is None;
}

test "AutoscalerRuntimeStatus carries engine condition passthrough and identifiers" {
    status = AutoscalerRuntimeStatus(
        state=AutoscalerState.DEGRADED.value,
        desired_replicas=1,
        current_replicas=1,
        ready_replicas=0,
        trigger_active=True,
        scaler_ready=False,
        conditions=[
            {"type": "Ready", "status": "False", "reason": "ScaledObjectCheckFailed"}
        ],
        resource_version="12345",
        message="spec not reconciled"
    );
    assert status.trigger_active is True;
    assert status.scaler_ready is False;
    assert status.conditions[0]["reason"] == "ScaledObjectCheckFailed";
    assert status.resource_version == "12345";
    assert status.message == "spec not reconciled";
}

test "AutoscalerRuntimeStatus omitting a required field raises TypeError" {
    raised = False;
    try {
        AutoscalerRuntimeStatus(state=AutoscalerState.ACTIVE.value, desired_replicas=1);
    } except TypeError {
        raised = True;
    }
    assert raised , "Expected TypeError when current_replicas/ready_replicas are omitted";
}

test "AutoscalerTransition requires identity, state pair, observed_at, and resource_version" {
    transition = AutoscalerTransition(
        autoscaler_name="orders-scaledobject",
        scale_target_name="orders-deployment",
        namespace="staging",
        previous_state=AutoscalerState.INACTIVE.value,
        state=AutoscalerState.ACTIVATING.value,
        observed_at="2026-08-21T12:00:00+00:00",
        resource_version="999"
    );
    assert transition.autoscaler_name == "orders-scaledobject";
    assert transition.scale_target_name == "orders-deployment";
    assert transition.namespace == "staging";
    assert transition.previous_state == "inactive";
    assert transition.state == "activating";
    assert transition.observed_at == "2026-08-21T12:00:00+00:00";
    assert transition.resource_version == "999";
    assert transition.reason is None;
    assert transition.message is None;
}

test "AutoscalerTransition allows previous_state=None for a first-ever observation" {
    transition = AutoscalerTransition(
        autoscaler_name="orders-scaledobject",
        scale_target_name="orders-deployment",
        namespace="staging",
        previous_state=None,
        state=AutoscalerState.ACTIVE.value,
        observed_at="2026-08-21T12:00:00+00:00",
        resource_version="1"
    );
    assert transition.previous_state is None;
}

test "AutoscalerTransition omitting resource_version raises TypeError" {
    raised = False;
    try {
        AutoscalerTransition(
            autoscaler_name="orders-scaledobject",
            scale_target_name="orders-deployment",
            namespace="staging",
            previous_state=None,
            state=AutoscalerState.ACTIVE.value,
            observed_at="2026-08-21T12:00:00+00:00"
        );
    } except TypeError {
        raised = True;
    }
    assert raised , "Expected TypeError when resource_version is omitted";
}

test "base Autoscaler.get_runtime_status raises NotImplementedError" {
    raised = False;
    try {
        Autoscaler().get_runtime_status(
            "orders-scaledobject", "orders-deployment", "staging"
        );
    } except NotImplementedError as e {
        raised = True;
        assert "get_runtime_status" in str(e);
    }
    assert raised , "Expected NotImplementedError from the base Autoscaler class";
}
