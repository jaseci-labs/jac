import from typing { Any }

obj SandboxConfig {
    has sandbox_type: str = "docker",
        namespace: str = "jac-sandboxes",
        max_per_user: int = 3,
        ttl_seconds: int = 3600,
        cpu_limit: str = "500m",
        memory_limit: str = "512Mi",
        base_image: str = "python:3.12-slim",
        storage_limit: str = "256Mi",
        app_storage_limit: str = "1Gi",
        domain_template: str = "{sandbox_id}.preview.example.com",
        security_context_enabled: bool = True,
        network_isolation: bool = True,
        ingress_class: str = "nginx",
        tls_enabled: bool = False,
        tls_issuer: str = "letsencrypt-prod",
        ingress_annotations: dict[str, str] = {},
        proxy_mode: bool = False,
        warm_pool_size: int = 0;

    static def from_dict(config: dict[str, Any]) -> SandboxConfig {
        return SandboxConfig(
            sandbox_type=str(config.get("type", config.get("sandbox_type", "docker"))),
            namespace=str(config.get("namespace", "jac-sandboxes")),
            max_per_user=int(config.get("max_per_user", 3)),
            ttl_seconds=int(config.get("ttl_seconds", 3600)),
            cpu_limit=str(config.get("cpu_limit", "500m")),
            memory_limit=str(config.get("memory_limit", "512Mi")),
            base_image=str(config.get("base_image", "python:3.12-slim")),
            storage_limit=str(config.get("storage_limit", "256Mi")),
            app_storage_limit=str(config.get("app_storage_limit", "1Gi")),
            domain_template=str(
                config.get("domain_template", "{sandbox_id}.preview.example.com")
            ),
            security_context_enabled=bool(config.get("security_context", True)),
            network_isolation=bool(config.get("network_isolation", True)),
            ingress_class=str(config.get("ingress_class", "nginx")),
            tls_enabled=bool(config.get("tls_enabled", False)),
            tls_issuer=str(config.get("tls_issuer", "letsencrypt-prod")),
            ingress_annotations=dict(config.get("ingress_annotations", {})),
            proxy_mode=bool(config.get("proxy_mode", False)),
            warm_pool_size=int(config.get("warm_pool_size", 0))
        );
    }
}
