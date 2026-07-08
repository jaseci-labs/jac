import from typing { Callable }
import from jaclang.scale.deploy.autoscale.autoscaler { Autoscaler }
# HPA (the default engine) is imported eagerly, not lazily inside create().
# The prebuilt-binary runtime cache extracts lazily-imported modules on first
# access, so importing this at deploy time can race that extraction
# (jaseci#7243) and fail with "[Errno 2] No such file ... hpa_autoscaler.jac",
# aborting the manifest apply. Importing at module load extracts it before any
# deploy runs. KEDA stays lazy below (optional engine, rarely used).
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
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
        if engine in AutoscalerFactory._registry {
            factory = AutoscalerFactory._registry[engine];
            return factory(config, logger);
        }

        if engine is None or engine == "hpa" {
            return HPAAutoscaler(logger=logger);
        }
        if engine == "keda" {
            import from jaclang.scale.deploy.autoscale.keda_autoscaler {
                KEDAAutoscaler
            }
            return KEDAAutoscaler(logger=logger);
        }
        raise ValueError(
            f"Unsupported autoscaler engine: '{engine}'. Supported built-in engines: 'hpa', 'keda'."
        );
    }
}
