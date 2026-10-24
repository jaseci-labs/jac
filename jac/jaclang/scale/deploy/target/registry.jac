type TargetFactory = Callable[[dict[str, any], Logger | None], DeploymentTarget];

glob BUILTIN_TARGET_TYPES: tuple[str, ...] = (
         "kubernetes",
         "kubernetes-microservice",
         "aws",
         "gcp"
     );

class DeploymentTargetRegistry {
    static has _registry: dict[str, TargetFactory] = {};

    static def register(target_type: str, factory: TargetFactory);
    static def known_targets -> list[str];
}
