import type from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import type from jaclang.scale.observability.logger { Logger }

type TargetFactory = Callable[[dict[str, any], Logger | None], DeploymentTarget];

glob BUILTIN_TARGET_TYPES: tuple[str, ...] = (
         "kubernetes",
         "kubernetes-microservice",
         "aws",
         "gcp"
     );

class DeploymentTargetRegistry {
    static has _registry: dict[str, TargetFactory] = {};

    static def register(target_type: str, factory: TargetFactory) {
        DeploymentTargetRegistry._registry[target_type] = factory;
    }

    static def known_targets -> list[str] {
        names: set[str] = set(BUILTIN_TARGET_TYPES);
        names.update(DeploymentTargetRegistry._registry.keys());
        return sorted(names);
    }
}
