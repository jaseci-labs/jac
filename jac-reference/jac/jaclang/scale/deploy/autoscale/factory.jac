type AutoscalerFactoryFn = Callable[[dict[str, any], Logger | None], Autoscaler];

class AutoscalerFactory {
    static has _registry: dict[str, AutoscalerFactoryFn] = {};

    static def register(engine: str, factory: AutoscalerFactoryFn);
    static def create(
        engine: (str | None), config: dict[str, any], logger: (Logger | None) = None
    ) -> Autoscaler;
}
