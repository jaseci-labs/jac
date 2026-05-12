"""Runtime service URL resolution abstraction.

Implementations resolve the base URL at which a registered microservice
is reachable. Mode-specific shapes:

  LocalDeployer (subprocess mode)  -> http://127.0.0.1:{entry.port}
  K8sRuntimeServiceResolver (K8s)  -> http://{svc}.{ns}.svc.cluster.local:{port}

Kept narrow on purpose: this is the single seam the gateway, orchestrator,
process manager, and peer-URL env-var injection all consult. Implementations
that don't own service lifecycle (K8s, where the K8s controller owns pod
lifecycle) implement only this interface.
"""

import from jac_scale.microservices.service_registry { ServiceEntry }


"""Resolves the runtime URL of a microservice. Stateless w.r.t. the
registry - takes a ServiceEntry directly, no lookup."""
class RuntimeServiceResolver {
    """Construct the base URL at which the given service is reachable.

    Args:
        service_entry: The ServiceEntry to resolve.

    Returns:
        The fully-qualified base URL (scheme + host + port). No path.
    """
    def url_for(self: RuntimeServiceResolver, service_entry: ServiceEntry) -> str;
}
