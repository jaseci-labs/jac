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
}
