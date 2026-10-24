def ensure_deploy_tooling(dry_run: bool = False);

def require_deploy_tooling(dry_run: bool = False);

class DeploymentTargetFactory(DeploymentTargetRegistry) {
    static def create(
        target_type: str,
        config: dict[str, any],
        logger: (Logger | None) = None,
        dry_run: bool = False
    ) -> DeploymentTarget;
}
