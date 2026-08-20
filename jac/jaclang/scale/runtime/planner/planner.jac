glob ENV_LOCAL: str = "local",
     ENV_KUBERNETES: str = "kubernetes";

glob TOPOLOGY_MONOLITH: str = "monolith",
     TOPOLOGY_MICROSERVICE: str = "microservice";


obj RealizationPlan {
    has environment: str,
        topology: str;
}


def plan_realization(scale_enabled: bool, process_count: int) -> RealizationPlan {
    environment = ENV_KUBERNETES if scale_enabled else ENV_LOCAL;
    topology = TOPOLOGY_MONOLITH if process_count <= 1 else TOPOLOGY_MICROSERVICE;
    return RealizationPlan(environment=environment, topology=topology);
}
