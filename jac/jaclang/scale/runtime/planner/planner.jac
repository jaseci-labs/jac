glob ENV_LOCAL: str = "local",
     ENV_KUBERNETES: str = "kubernetes";

glob TOPOLOGY_MONOLITH: str = "monolith",
     TOPOLOGY_MICROSERVICE: str = "microservice";


obj RealizationPlan {
    has environment: str,
        topology: str;
}


def plan_realization(scale_enabled: bool, process_count: int) -> RealizationPlan;
