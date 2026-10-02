import from jaclang.scale.deploy.autoscale.autoscaler { Autoscaler }
import from jaclang.scale.observability.logger { Logger }

type AutoscalerFactoryFn = Callable[[dict[str, any], Logger | None], Autoscaler];

class AutoscalerFactory {
    static has _registry: dict[str, AutoscalerFactoryFn] = {};

    static def register(engine: str, factory: AutoscalerFactoryFn) {
        AutoscalerFactory._registry[engine] = factory;
    }

    static def create(
        engine: (str | None), config: dict[str, any], logger: (Logger | None) = None
    ) -> Autoscaler {
        if engine is not None and engine in AutoscalerFactory._registry {
            factory = AutoscalerFactory._registry[engine];
            return factory(config, logger);
        }

        if engine is None or engine == "hpa" {
            import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
            return HPAAutoscaler(logger=logger);
        }
        if engine == "keda" {
            import from jaclang.scale.deploy.autoscale.keda_autoscaler {
                KEDAAutoscaler
            }
            import from jaclang.scale.runtime.context.service_routing {
                resolve_interceptor_service_address
            }
            return KEDAAutoscaler(
                logger=logger,
                interceptor_service_address=resolve_interceptor_service_address(config)
            );
        }
        raise ValueError(
            f"Unsupported autoscaler engine: '{engine}'. Supported built-in engines: 'hpa', 'keda'."
        );
    }

    """The autoscaler that actually drives a target, read off the cluster.

    Configuration cannot answer this. `autoscaler_engine` describes what a deploy
    asked for, and an HTTP-activation service is KEDA scaled while that field
    still reads its "hpa" default, so either default misclassifies some live
    deployment. The target's own resources are the only authority: a ScaledObject
    under either of KEDA's two names means KEDA, and its confirmed absence means
    the plain HPA engine.

    An unreadable probe is neither. It keeps KEDA, which reports the workload's
    own state plus the reason the autoscaler view is missing, rather than
    asserting an engine nobody observed and silently dropping every trigger and
    scaler field.
    """
    static def create_for_target(
        scale_target_name: str,
        namespace: str,
        config: dict[str, any],
        logger: (Logger | None) = None
    ) -> Autoscaler {
        keda: any = AutoscalerFactory.create("keda", config, logger);
        drives = keda.scales_target(scale_target_name, namespace);
        if drives {
            return keda;
        }
        if drives is None {
            if logger {
                logger.warn(
                    f"Could not read whether '{scale_target_name}' in "
                    f"'{namespace}' is KEDA scaled. Reporting through KEDA so a "
                    f"failed probe is not mistaken for a plain HPA target."
                );
            }
            return keda;
        }
        return AutoscalerFactory.create("hpa", config, logger);
    }
}
