"""Runtime service URL resolver: implementations return the base URL
at which a registered microservice is reachable (loopback for subprocess
mode, K8s DNS for in-cluster mode)."""

class RuntimeServiceResolver {
    """Return the base URL for the given service entry.
    `service_entry` is typed `any` to keep abstractions/ free of
    microservices imports; concrete subclasses accept a ServiceEntry."""
    def url_for(self: RuntimeServiceResolver, service_entry: any) -> str;
}
