"""Factory for creating autoscaler engine instances.

Supports both built-in engines (hpa) and plugin-registered engines.
External packages can register custom engines via AutoscalerFactory.register().
"""
import from typing { Callable }
import from jac_scale.abstractions.autoscaler { Autoscaler }
import from jac_scale.abstractions.logger { Logger }

"""Type alias for autoscaler engine factory callables.""" type AutoscalerFactoryFn = Callable[
    [dict[str, any], Logger | None],
    Autoscaler
];

"""Factory for creating autoscaler engine instances.

Maintains a registry of engine factories that can be extended by external
plugins. Built-in engines (hpa) are always available. Custom engines
are checked first, allowing plugins to override built-in behaviour.

Example:
    # Register a custom engine from an external plugin
    AutoscalerFactory.register(
        "my-scaler",
        lambda config, logger: MyScaler(config=config, logger=logger)
    )

    # Create the engine via the standard factory
    autoscaler = AutoscalerFactory.create("my-scaler", config)
"""
class AutoscalerFactory {
    static has _registry: dict[str, AutoscalerFactoryFn] = {};

    """Register a custom autoscaler engine factory.

    Args:
        engine: Unique name for the engine (e.g. 'my-custom-scaler')
        factory: Callable that accepts (config: dict, logger: Logger | None)
                 and returns an Autoscaler instance
    """
    static def register(engine: str, factory: AutoscalerFactoryFn) {
        AutoscalerFactory._registry[engine] = factory;
    }

    """Create an autoscaler engine based on the engine name.

    Checks the plugin registry first, then falls back to built-in engines.

    Args:
        engine: Engine name ('hpa', or a registered custom name)
        config: Configuration dictionary
        logger: Optional logger instance

    Returns:
        Autoscaler instance

    Raises:
        ValueError: If engine is not supported
    """
    static def create(
        engine: (str | None), config: dict[str, any], logger: (Logger | None) = None
    ) -> Autoscaler {
        # Check plugin registry first
        if engine in AutoscalerFactory._registry {
            factory = AutoscalerFactory._registry[engine];
            return factory(config, logger);
        }
        # Built-in engines
        if engine is None or engine == "hpa" {
            import from jac_scale.abstractions.autoscalers.hpa_autoscaler {
                HPAAutoscaler
            }
            return HPAAutoscaler(logger=logger);
        }
        raise ValueError(
            f"Unsupported autoscaler engine: '{engine}'. Supported engines: 'hpa'."
        );
    }
}
