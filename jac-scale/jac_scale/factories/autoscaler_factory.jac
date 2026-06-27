import from typing { Callable }
import from jac_scale.abstractions.autoscaler { Autoscaler }
import from jac_scale.abstractions.logger { Logger }

"""Type alias for autoscaler engine factory callables.""" type AutoscalerFactoryFn = Callable[
    [dict[str, any], Logger | None],
    Autoscaler
];


class AutoscalerFactory {
    static has _registry: dict[str, AutoscalerFactoryFn] = {};

    static def register(engine: str, factory: AutoscalerFactoryFn) {
        AutoscalerFactory._registry[engine] = factory;
    }

    static def create(
        engine: (str | None), config: dict[str, any], logger: (Logger | None) = None
    ) -> Autoscaler {
        if engine in AutoscalerFactory._registry {
            factory = AutoscalerFactory._registry[engine];
            return factory(config, logger);
        }
        if engine is None or engine == "hpa" {
            import from jac_scale.abstractions.autoscalers.hpa_autoscaler {
                HPAAutoscaler
            }
            return HPAAutoscaler(logger=logger);
        }
        if engine == "keda" {
            import from jac_scale.abstractions.autoscalers.keda_autoscaler {
                KEDAAutoscaler
            }
            return KEDAAutoscaler(logger=logger);
        }
        raise ValueError(
            f"Unsupported autoscaler engine: '{engine}'. Supported built-in engines: 'hpa', 'keda'."
        );
    }
}
