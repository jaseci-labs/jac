"""RealizationPlanner: map the two deployment dials to a set of adapter choices.

The dials:
  environment - `--scale` present? -> kubernetes, else local
  topology    - service count from the blueprint: >1 -> microservice, else monolith

From those, one pure function decides the gateway placement, the transport, the
state backend, and whether code injection runs. This is the only component that
maps dials to concrete strategies; every other part of the runtime takes the plan
and depends on ports. The plan reproduces the 4-cell assembly table exactly.
"""

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


"""The resolved adapter choices for one deployment.

gateway_mode `embedded` means the gateway runs in the app process (no second
process); `process` means its own process or pod. transport `in_process` is a
direct call (gateway and app share a process); `http` is a network hop. These two
move together: the transport is in-process exactly when the gateway is embedded.
"""
obj RealizationPlan {
    has environment: str,
        topology: str,
        gateway_mode: str,
        transport: str,
        state_backend: str,
        uses_injector: bool;
}


"""Resolve a RealizationPlan from the dials.

Args:
    scale_enabled: the --scale dial (k8s deploy when True).
    service_count: number of services in the blueprint (sv-import closure).
    gateway_embedded: collapse the gateway into the app even in k8s for a
        monolith (the gateway_embedded flag). Ignored unless k8s + monolith.
"""
def plan_realization(
    scale_enabled: bool, service_count: int, gateway_embedded: bool = False
) -> RealizationPlan {
    environment = ENV_KUBERNETES if scale_enabled else ENV_LOCAL;
    is_monolith = service_count <= 1;
    topology = TOPOLOGY_MONOLITH if is_monolith else TOPOLOGY_MICROSERVICE;

    # A monolith embeds the gateway in its single process. In k8s the gateway is
    # its own pod by default even for N=1 (uniform topology), unless the
    # gateway_embedded flag collapses it. A microservice fleet always fronts with
    # a separate gateway process.
    embed_gateway = is_monolith and ((not scale_enabled) or gateway_embedded);
    gateway_mode = GATEWAY_EMBEDDED if embed_gateway else GATEWAY_PROCESS;

    # Transport is a direct call exactly when the gateway shares the app process.
    transport = TRANSPORT_IN_PROCESS if embed_gateway else TRANSPORT_HTTP;

    # Shared state must span replicas only under --scale; otherwise in-process.
    state_backend = STATE_REDIS if scale_enabled else STATE_IN_PROCESS;

    # Code injection is a k8s-only concern.
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
