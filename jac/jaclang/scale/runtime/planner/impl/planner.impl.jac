impl plan_realization(scale_enabled: bool, process_count: int) -> RealizationPlan {
    environment = ENV_KUBERNETES if scale_enabled else ENV_LOCAL;
    topology = TOPOLOGY_MONOLITH if process_count <= 1 else TOPOLOGY_MICROSERVICE;
    return RealizationPlan(environment=environment, topology=topology);
}
