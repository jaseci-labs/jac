glob ENV_LOCAL: str = "local",
     ENV_KUBERNETES: str = "kubernetes";

glob TOPOLOGY_MONOLITH: str = "monolith",
     TOPOLOGY_MICROSERVICE: str = "microservice";

glob GATEWAY_EMBEDDED: str = "embedded",
     GATEWAY_PROCESS: str = "process";

glob TRANSPORT_IN_PROCESS: str = "in_process",
     TRANSPORT_HTTP: str = "http";

glob STATE_IN_PROCESS: str = "in_process",
     STATE_REDIS: str = "redis";


obj RealizationPlan {
    has environment: str,
        topology: str,
        gateway_mode: str,
        transport: str,
        state_backend: str,
        uses_injector: bool;
}


def plan_realization(
    scale_enabled: bool, service_count: int, gateway_embedded: bool = False
) -> RealizationPlan {
    environment = ENV_KUBERNETES if scale_enabled else ENV_LOCAL;
    is_monolith = service_count <= 1;
    topology = TOPOLOGY_MONOLITH if is_monolith else TOPOLOGY_MICROSERVICE;

    embed_gateway = is_monolith and ((not scale_enabled) or gateway_embedded);
    gateway_mode = GATEWAY_EMBEDDED if embed_gateway else GATEWAY_PROCESS;

    transport = TRANSPORT_IN_PROCESS if embed_gateway else TRANSPORT_HTTP;

    state_backend = STATE_REDIS if scale_enabled else STATE_IN_PROCESS;

    uses_injector = scale_enabled;

    return RealizationPlan(
        environment=environment,
        topology=topology,
        gateway_mode=gateway_mode,
        transport=transport,
        state_backend=state_backend,
        uses_injector=uses_injector
    );
}
