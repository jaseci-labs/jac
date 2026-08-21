# AutoscalerObserverRegistry is the structural enforcement of "no code path
# opens its own watch": every test here injects a lightweight test double
# via observer_factory so these stay pure registry-semantics tests (identity,
# keying, shutdown) with no Kubernetes/thread mechanics involved -- those are
# already covered by test_kubernetes_autoscaler_observer.jac.
import unittest.mock;
import from jaclang.scale.deploy.autoscale.observer_registry {
    AutoscalerObserverRegistry
}
import from jaclang.scale.deploy.autoscale.observer {
    AutoscalerObserver,
    AutoscalerSubscription
}


obj FakeObserver(AutoscalerObserver) {
    has watch_calls: list = [],
        stop_calls: list = [],
        started: bool = False;

    def start {
        self.started = True;
    }

    def stop(drain: bool = True) {
        self.stop_calls.append(drain);
    }

    def watch_namespace(namespace: str, label_selector: (str | None) = None) {
        self.watch_calls.append((namespace, label_selector));
    }

    def subscribe(
        autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = "drop_oldest"
    ) -> AutoscalerSubscription {
        return AutoscalerSubscription();
    }
}


test "get_or_create returns the identical instance for the same namespace and cluster" {
    AutoscalerObserverRegistry._instances = {};

    first = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    second = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );

    assert first is second;
    assert first.started is True;
    # watch_namespace only runs on the first, actually-creating call.
    assert first.watch_calls == [("ns-a", None)];
}

test "get_or_create returns different instances for different namespaces" {
    AutoscalerObserverRegistry._instances = {};

    ns_a = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    ns_b = AutoscalerObserverRegistry.get_or_create(
        "ns-b", observer_factory=FakeObserver
    );

    assert ns_a is not ns_b;
}

test "get_or_create returns different instances for the same namespace under different clusters" {
    AutoscalerObserverRegistry._instances = {};

    cluster_1 = AutoscalerObserverRegistry.get_or_create(
        "ns-a", cluster_key="cluster-1", observer_factory=FakeObserver
    );
    cluster_2 = AutoscalerObserverRegistry.get_or_create(
        "ns-a", cluster_key="cluster-2", observer_factory=FakeObserver
    );

    assert cluster_1 is not cluster_2;
}

test "get_or_create propagates label_selector to the underlying watch only on first creation" {
    AutoscalerObserverRegistry._instances = {};

    obs = AutoscalerObserverRegistry.get_or_create(
        "ns-a", label_selector="managed=jac-scale", observer_factory=FakeObserver
    );
    assert obs.watch_calls == [("ns-a", "managed=jac-scale")];

    # A second caller asking for the same (cluster, namespace) shares the
    # watch the first caller already established -- their label_selector is
    # not re-applied.
    AutoscalerObserverRegistry.get_or_create(
        "ns-a", label_selector="app=other", observer_factory=FakeObserver
    );
    assert obs.watch_calls == [("ns-a", "managed=jac-scale")];
}

test "shutdown_all stops every created instance and clears the registry" {
    AutoscalerObserverRegistry._instances = {};

    ns_a = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    ns_b = AutoscalerObserverRegistry.get_or_create(
        "ns-b", observer_factory=FakeObserver
    );

    AutoscalerObserverRegistry.shutdown_all(drain=True);

    assert ns_a.stop_calls == [True];
    assert ns_b.stop_calls == [True];
    assert AutoscalerObserverRegistry._instances == {};
}

test "get_or_create after shutdown_all returns a fresh instance, not the stopped one" {
    AutoscalerObserverRegistry._instances = {};

    original = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    AutoscalerObserverRegistry.shutdown_all();

    fresh = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    assert fresh is not original;
    assert fresh.stop_calls == [];
}

test "shutdown_all defaults to draining" {
    AutoscalerObserverRegistry._instances = {};

    obs = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    AutoscalerObserverRegistry.shutdown_all();

    assert obs.stop_calls == [True];
}

test "shutdown_all with drain=False passes it through to every instance" {
    AutoscalerObserverRegistry._instances = {};

    obs = AutoscalerObserverRegistry.get_or_create(
        "ns-a", observer_factory=FakeObserver
    );
    AutoscalerObserverRegistry.shutdown_all(drain=False);

    assert obs.stop_calls == [False];
}

test "the default construction path (no observer_factory) builds a real KubernetesAutoscalerObserver" {
    AutoscalerObserverRegistry._instances = {};
    import from jaclang.scale.deploy.autoscale.kubernetes_observer {
        KubernetesAutoscalerObserver
    }

    obs = AutoscalerObserverRegistry.get_or_create("ns-default-path");
    assert isinstance(obs, KubernetesAutoscalerObserver);

    AutoscalerObserverRegistry.shutdown_all();
}
