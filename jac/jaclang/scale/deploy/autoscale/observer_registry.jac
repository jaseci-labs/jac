import from threading { Lock, Event }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale.deploy.autoscale.observer { AutoscalerObserver }
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    default_cluster_key
}

type ObserverFactoryFn = Callable[[], AutoscalerObserver];

class AutoscalerObserverRegistry {
    static has _instances: dict[str, AutoscalerObserver] = {},
        _refcounts: dict[str, int] = {},
        _stopping: dict[str, Event] = {},
        _lock: Lock = Lock();

    static def get_or_create(
        namespace: str,
        cluster_key: (str | None) = None,
        observer_factory: (ObserverFactoryFn | None) = None
    ) -> AutoscalerObserver {
        key = f"{cluster_key or default_cluster_key()}::{namespace}";
        while True {
            wait_for: (Event | None) = None;
            with AutoscalerObserverRegistry._lock {
                existing = AutoscalerObserverRegistry._instances.get(key);
                if existing is not None {
                    AutoscalerObserverRegistry._refcounts[key] = (
                        AutoscalerObserverRegistry._refcounts.get(key, 0) + 1
                    );
                    return existing;
                }
                wait_for = AutoscalerObserverRegistry._stopping.get(key);
                if wait_for is None {
                    if observer_factory {
                        created = observer_factory();
                    } else {
                        require_optional("kubernetes", "deploy.k8s");
                        created = KubernetesAutoscalerObserver();
                    }
                    try {
                        created.start();
                        created.watch_namespace(namespace);
                    } except Exception {
                        created.stop(drain=False);
                        raise;
                    }
                    AutoscalerObserverRegistry._instances[key] = created;
                    AutoscalerObserverRegistry._refcounts[key] = 1;
                    return created;
                }
            }
            if wait_for is not None {
                wait_for.`wait();
            }
        }
    }

    static def release(
        namespace: str, cluster_key: (str | None) = None, drain: bool = True
    ) -> None {
        key = f"{cluster_key or default_cluster_key()}::{namespace}";
        to_stop: (AutoscalerObserver | None) = None;
        stopped: (Event | None) = None;
        with AutoscalerObserverRegistry._lock {
            count = AutoscalerObserverRegistry._refcounts.get(key);
            if count is None {
                return;
            }
            count -= 1;
            if count <= 0 {
                AutoscalerObserverRegistry._refcounts.pop(key, None);
                to_stop = AutoscalerObserverRegistry._instances.pop(key, None);
                if to_stop is not None {
                    stopped = Event();
                    AutoscalerObserverRegistry._stopping[key] = stopped;
                }
            } else {
                AutoscalerObserverRegistry._refcounts[key] = count;
            }
        }
        if to_stop is not None {
            try {
                to_stop.stop(drain=drain);
            } finally {
                with AutoscalerObserverRegistry._lock {
                    AutoscalerObserverRegistry._stopping.pop(key, None);
                }
                if stopped is not None {
                    stopped.set();
                }
            }
        }
    }

    static def shutdown_all(drain: bool = True) {
        with AutoscalerObserverRegistry._lock {
            instances = list(AutoscalerObserverRegistry._instances.values());
            AutoscalerObserverRegistry._instances = {};
            AutoscalerObserverRegistry._refcounts = {};
        }
        for observer in instances {
            observer.stop(drain=drain);
        }
    }
}
