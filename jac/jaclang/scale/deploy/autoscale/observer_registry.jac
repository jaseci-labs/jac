import from threading { Lock }
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
        _lock: Lock = Lock();

    static def get_or_create(
        namespace: str,
        cluster_key: (str | None) = None,
        label_selector: (str | None) = None,
        observer_factory: (ObserverFactoryFn | None) = None
    ) -> AutoscalerObserver {
        key = f"{cluster_key or default_cluster_key()}::{namespace}";
        with AutoscalerObserverRegistry._lock {
            existing = AutoscalerObserverRegistry._instances.get(key);
            if existing is not None {
                return existing;
            }
            if observer_factory {
                created = observer_factory();
            } else {
                require_optional("kubernetes", "deploy.k8s");
                created = KubernetesAutoscalerObserver();
            }
            AutoscalerObserverRegistry._instances[key] = created;
        }
        created.start();
        created.watch_namespace(namespace, label_selector);
        return created;
    }

    static def shutdown_all(drain: bool = True) {
        with AutoscalerObserverRegistry._lock {
            instances = list(AutoscalerObserverRegistry._instances.values());
            AutoscalerObserverRegistry._instances = {};
        }
        for observer in instances {
            observer.stop(drain=drain);
        }
    }
}
