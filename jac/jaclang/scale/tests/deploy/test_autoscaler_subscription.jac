# No Kubernetes involved at all -- _deliver is called directly, the way the
# future KubernetesAutoscalerObserver will call it once a watch event
# normalizes into a state change.
import time;
import from jaclang.scale.deploy.autoscale.observer {
    AutoscalerSubscription,
    BackpressurePolicy
}
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerTransition }


def transition(
    resource_version: str,
    autoscaler_name: str = "orders-scaledobject",
    scale_target_name: str = "orders-deployment",
    state: str = "active"
) -> AutoscalerTransition {
    return AutoscalerTransition(
        autoscaler_name=autoscaler_name,
        scale_target_name=scale_target_name,
        namespace="default",
        previous_state=None,
        state=state,
        observed_at="2026-08-21T12:00:00+00:00",
        resource_version=resource_version
    );
}


test "a subscription with no filters receives every delivered transition in order" {
    sub = AutoscalerSubscription();
    sub._deliver(transition("1"));
    sub._deliver(transition("2"));

    assert sub.poll(timeout_seconds=0).resource_version == "1";
    assert sub.poll(timeout_seconds=0).resource_version == "2";
    assert sub.poll(timeout_seconds=0) is None;
}

test "a subscription filtered by autoscaler_name and scale_target_name ignores non-matching transitions" {
    sub = AutoscalerSubscription(
        autoscaler_name="orders-scaledobject", scale_target_name="orders-deployment"
    );
    sub._deliver(transition("1", autoscaler_name="payments-scaledobject"));
    sub._deliver(transition("2", scale_target_name="payments-deployment"));
    sub._deliver(transition("3"));

    delivered = sub.poll(timeout_seconds=0);
    assert delivered is not None;
    assert delivered.resource_version == "3";
    assert sub.poll(timeout_seconds=0) is None;
}

test "drop_oldest evicts the oldest queued transition and keeps the newest in order" {
    sub = AutoscalerSubscription(
        max_queue=2, backpressure=BackpressurePolicy.DROP_OLDEST.value
    );
    for v in ["1", "2", "3", "4"] {
        sub._deliver(transition(v));
    }

    assert sub.dropped_count() == 2;
    assert sub.poll(timeout_seconds=0).resource_version == "3";
    assert sub.poll(timeout_seconds=0).resource_version == "4";
    assert sub.poll(timeout_seconds=0) is None;
}

test "drop_newest discards the incoming transition and keeps the oldest in place" {
    sub = AutoscalerSubscription(
        max_queue=2, backpressure=BackpressurePolicy.DROP_NEWEST.value
    );
    for v in ["1", "2", "3", "4"] {
        sub._deliver(transition(v));
    }

    assert sub.dropped_count() == 2;
    assert sub.poll(timeout_seconds=0).resource_version == "1";
    assert sub.poll(timeout_seconds=0).resource_version == "2";
    assert sub.poll(timeout_seconds=0) is None;
}

test "close backpressure closes the subscription instead of growing the queue further" {
    sub = AutoscalerSubscription(
        max_queue=2, backpressure=BackpressurePolicy.CLOSE.value
    );
    sub._deliver(transition("1"));
    sub._deliver(transition("2"));
    assert sub.is_closed() is False;

    sub._deliver(transition("3"));
    assert sub.is_closed() is True;

    # Further deliveries are no-ops once closed -- the queue never grows past max_queue.
    sub._deliver(transition("4"));
    assert sub.poll(timeout_seconds=0).resource_version == "1";
    assert sub.poll(timeout_seconds=0).resource_version == "2";
    assert sub.poll(timeout_seconds=0) is None;
}

test "poll returns None immediately once closed, rather than blocking for the full timeout" {
    sub = AutoscalerSubscription();
    sub.close();

    started = time.time();
    result = sub.poll(timeout_seconds=5.0);
    elapsed = time.time() - started;

    assert result is None;
    assert elapsed < 1.0 , f"poll() blocked for {elapsed}s after close()";
}

test "consumer-initiated close stops future delivery and is idempotent" {
    sub = AutoscalerSubscription();
    sub._deliver(transition("1"));
    sub.close();
    sub.close();

    assert sub.is_closed() is True;
    sub._deliver(transition("2"));
    assert sub.poll(timeout_seconds=0).resource_version == "1";
    assert sub.poll(timeout_seconds=0) is None;
}

test "poll(timeout=0) on an empty, unfiltered subscription returns None without blocking" {
    sub = AutoscalerSubscription();

    started = time.time();
    result = sub.poll(timeout_seconds=0);
    elapsed = time.time() - started;

    assert result is None;
    assert elapsed < 1.0;
}

test "an unknown backpressure policy raises rather than silently dropping data" {
    sub = AutoscalerSubscription(max_queue=1, backpressure="not-a-real-policy");
    sub._deliver(transition("1"));

    raised = False;
    try {
        sub._deliver(transition("2"));
    } except ValueError as e {
        raised = True;
        assert "not-a-real-policy" in str(e);
    }
    assert raised , "Expected ValueError for an unrecognized backpressure policy";
}
