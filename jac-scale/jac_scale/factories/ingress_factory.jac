import from typing { Any }
import from jac_scale.abstractions.ingress_provider { IngressProvider }

obj IngressFactory {
    static def create(
        ingress_type: str, config: (dict[str, Any] | None) = None
    ) -> IngressProvider {
        if ingress_type == "kubernetes" {
            import from jac_scale.providers.ingress.kubernetes_ingress {
                KubernetesIngressProvider
            }
            return KubernetesIngressProvider(config=config or {});
        } elif ingress_type == "proxy" {
            import from jac_scale.providers.ingress.proxy_ingress {
                ProxyIngressProvider
            }
            return ProxyIngressProvider(config=config or {});
        } elif ingress_type == "local" {
            import from jac_scale.providers.ingress.local_ingress {
                LocalIngressProvider
            }
            return LocalIngressProvider(config=config or {});
        } else {
            raise ValueError(f"Unsupported ingress type: {ingress_type}");
        }
    }
}
