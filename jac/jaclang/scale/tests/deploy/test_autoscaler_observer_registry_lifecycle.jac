# AutoscalerObserverRegistry is the structural enforcement of "no code path
# opens its own watch". Scoped to the 5 review-caught bugs this registry was
# actually built to fix -- not a completeness sweep of every getter/setter --
# per the "no unit tests, ~750 lines total" review pass:
#   1. label_selector silently dropped (review comment #1)
#   2. an instance published before its watch had started (review comment #2)
#   3. nothing ever released an observer -- refcount leak (review comment #3)
#   4. a watch_namespace failure during creation leaked the partial observer
#      (residual review note (a), fixed in 60f39615f)
#   5. get_or_create racing a concurrent release for the same key (residual
#      review note (b), fixed in 60f39615f)
# Each is one scripted step below, using a lightweight FakeObserver test
# double injected via observer_factory -- the real registry class, its real
# locking/refcounting, with only "does this open a real k8s watch" faked.
import time;
import from threading { Thread, Lock }
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
        watch_called: bool = False;

    def start {}
    def stop(drain: bool = True) {
        self.stop_calls.append(drain);
    }

    def watch_namespace(namespace: str) {
        # A small delay makes the publish-before-watching race observable if
        # it regresses: without the fix, a concurrent caller could see this
        # instance in the registry before this method -- and therefore this
        # flag -- has run.
        time.sleep(0.02);
        self.watch_calls.append(namespace);
        self.watch_called = True;
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


obj FailingObserver(AutoscalerObserver) {
    has stop_calls: list = [];

    def start {}
    def watch_namespace(namespace: str) {
        raise RuntimeError("watch_namespace failed");
    }

    def stop(drain: bool = True) {
        self.stop_calls.append(drain);
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


obj SlowStoppingObserver(AutoscalerObserver) {
    # stop() sleeps long enough that a concurrent get_or_create for the same
    # key would observe the overlap (a second observer created and watching
    # before this one has finished stopping) if the "stopping" gate
    # regressed.
    has stop_finished_at: (float | None) = None,
        watch_started_at: (float | None) = None;

    def start {}
    def stop(drain: bool = True) {
        time.sleep(0.05);
        self.stop_finished_at = time.monotonic();
    }

    def watch_namespace(namespace: str) {
        self.watch_started_at = time.monotonic();
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


test "AutoscalerObserverRegistry: fixed selector, publish-before-watch atomicity, refcounted release, the watch-failure leak, and the in-flight-release race" {
    def step_fixed_selector {
        # There is no per-caller label_selector: get_or_create always watches
        # the shared, jac-scale-managed selector -- scoping to a single scale
        # target happens client-side via AutoscalerSubscription instead.
        AutoscalerObserverRegistry._instances = {};
        obs: any = AutoscalerObserverRegistry.get_or_create(
            "ns-a", observer_factory=FakeObserver
        );
        assert obs.watch_calls == ["ns-a"];
        AutoscalerObserverRegistry.get_or_create("ns-a", observer_factory=FakeObserver);
        assert obs.watch_calls == ["ns-a"] , "a caller-supplied selector must never reach watch_namespace";
    }

    def step_publish_after_watch_concurrent {
        AutoscalerObserverRegistry._instances = {};
        violations: list = [];
        violations_lock = Lock();

        def worker {
            obs: any = AutoscalerObserverRegistry.get_or_create(
                "ns-race", observer_factory=FakeObserver
            );
            if not obs.watch_called {
                with violations_lock {
                    violations.append(obs);
                }
            }
        }

        workers = [Thread(target=worker) for _ in range(16)];
        for w in workers {
            w.start();
        }
        for w in workers {
            w.join();
        }
        assert violations == [] , "an observer must never be visible before its watch has started";
    }

    def step_refcount_shared_and_released_at_zero {
        AutoscalerObserverRegistry._instances = {};
        first: any = AutoscalerObserverRegistry.get_or_create(
            "ns-a", observer_factory=FakeObserver
        );
        second: any = AutoscalerObserverRegistry.get_or_create(
            "ns-a", observer_factory=FakeObserver
        );
        assert second is first , "repeat get_or_create calls for the same key must share one instance";

        AutoscalerObserverRegistry.release("ns-a");
        assert first.stop_calls == [] , "release must not stop the observer while another reference remains";

        AutoscalerObserverRegistry.release("ns-a");
        assert first.stop_calls == [True] , "release must stop and evict the observer once its refcount reaches zero";
        fresh: any = AutoscalerObserverRegistry.get_or_create(
            "ns-a", observer_factory=FakeObserver
        );
        assert fresh is not first;
    }

    def step_watch_failure_does_not_leak {
        AutoscalerObserverRegistry._instances = {};
        AutoscalerObserverRegistry._refcounts = {};
        AutoscalerObserverRegistry._stopping = {};
        created_instances: list = [];

        def failing_factory -> AutoscalerObserver {
            obs = FailingObserver();
            created_instances.append(obs);
            return obs;
        }

        threw = False;
        try {
            AutoscalerObserverRegistry.get_or_create(
                "ns-fail", observer_factory=failing_factory
            );
        } except RuntimeError {
            threw = True;
        }
        assert threw;
        assert created_instances[0].stop_calls == [False] , "a started-but-unpublished observer must be stopped, not leaked";

        # The failed key must not block subsequent creation.
        fresh: any = AutoscalerObserverRegistry.get_or_create(
            "ns-fail", observer_factory=FakeObserver
        );
        assert fresh.watch_calls == ["ns-fail"];
    }

    def step_waits_for_inflight_release {
        AutoscalerObserverRegistry._instances = {};
        AutoscalerObserverRegistry._refcounts = {};
        AutoscalerObserverRegistry._stopping = {};
        first: any = AutoscalerObserverRegistry.get_or_create(
            "ns-evict-race", observer_factory=SlowStoppingObserver
        );

        def releaser {
            AutoscalerObserverRegistry.release("ns-evict-race");
        }

        release_thread = Thread(target=releaser);
        release_thread.start();
        # Give release() time to pop the instance, mark it stopping, and
        # enter its (slow) stop() call before this thread races in behind it.
        time.sleep(0.01);

        second: any = AutoscalerObserverRegistry.get_or_create(
            "ns-evict-race", observer_factory=SlowStoppingObserver
        );
        release_thread.join();

        assert second is not first;
        assert first.stop_finished_at is not None;
        assert second.watch_started_at is not None;
        assert first.stop_finished_at <= second.watch_started_at , "a concurrent get_or_create must wait for an in-flight release, not race a duplicate create";
    }

    step_fixed_selector();
    step_publish_after_watch_concurrent();
    step_refcount_shared_and_released_at_zero();
    step_watch_failure_does_not_leak();
    step_waits_for_inflight_release();
}
