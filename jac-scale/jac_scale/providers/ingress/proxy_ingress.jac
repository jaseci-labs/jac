import from typing { Any }
import from jac_scale.abstractions.ingress_provider { IngressProvider }

obj ProxyIngressProvider(IngressProvider) {
    has config: dict = {};

    def create_route(
        sandbox_id: str,
        service_name: str,
        target_port: int,
        namespace: str,
        config: dict[str, Any]
    ) -> str {
        domain_template = config.get(
            "domain_template",
            self.config.get("domain_template", "{sandbox_id}.preview.example.com")
        );
        tls_enabled = config.get("tls_enabled", self.config.get("tls_enabled", False));
        hostname = domain_template.replace("{sandbox_id}", sandbox_id);
        protocol = "https" if tls_enabled else "http";
        return f"{protocol}://{hostname}";
    }

    def delete_route(sandbox_id: str, namespace: str) {
        ;
    }

    def get_url(sandbox_id: str) -> (str | None) {
        domain_template = self.config.get(
            "domain_template", "{sandbox_id}.preview.example.com"
        );
        tls_enabled = self.config.get("tls_enabled", False);
        hostname = domain_template.replace("{sandbox_id}", sandbox_id);
        protocol = "https" if tls_enabled else "http";
        return f"{protocol}://{hostname}";
    }
}
