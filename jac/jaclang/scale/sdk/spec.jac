import from pathlib { Path }

glob _RESOURCE_KEYS: list[str] = [
         'cpu_request',
         'cpu_limit',
         'memory_request',
         'memory_limit'
     ];


obj DeploySpec {
    has app_name: str,
        namespace: str = 'default',
        source: str = '',
        target: str = 'auto',
        secrets: dict[str, str] = {},
        env: dict[str, str] = {},
        domain: str = '',
        replicas: int = 1,
        resources: dict[str, str] = {},
        autoscaler: dict[str, any] = {},
        client: dict[str, any] = {},
        microservices: dict[str, any] = {},
        kube_context: str = '',
        labels: dict[str, str] = {},
        extra: dict[str, any] = {};

    static def from_config(
        path: str, config: (dict[str, any] | None) = None
    ) -> DeploySpec {
        cfg = dict(config or {});
        cfg.setdefault('source', path);
        import dataclasses;
        known = {field.name for field in dataclasses.fields(DeploySpec)};
        unknown = sorted(set(cfg.keys()) - known);
        if unknown {
            raise ValueError(
                f"Unknown deploy option(s) {', '.join(unknown)}; valid keys: "
                f"{', '.join(sorted(known))}."
            );
        }
        if not cfg.get('app_name') {
            import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
                k8s_safe_slug
            }
            base = Path(str(cfg['source']));
            name_source = base.name if base.suffix != '.jac' else base.parent.name;
            cfg['app_name'] = k8s_safe_slug(name_source);
        }
        return DeploySpec(**cfg);
    }

    def resolved_target -> str {
        if self.target == 'auto' {
            enabled = self.microservices.get('enabled', None);
            has_routes = bool(dict(self.microservices.get('routes', {}) or {}));
            if enabled is True or has_routes {
                return 'kubernetes-microservice';
            }
            return 'kubernetes';
        }
        if self.target in ('kubernetes', 'kubernetes-microservice') {
            return self.target;
        }
        raise ValueError(
            f"DeploySpec.target must be 'auto', 'kubernetes' or "
            f"'kubernetes-microservice', got {self.target!r}."
        );
    }

    def resolve_entry -> tuple[str, str] {
        if not self.source {
            raise ValueError(
                "DeploySpec.source is required: the app's entry .jac file, "
                "or a folder containing main.jac."
            );
        }
        path = Path(self.source);
        if path.is_dir() {
            entry = path / 'main.jac';
            if not entry.is_file() {
                raise FileNotFoundError(
                    f"DeploySpec.source folder '{path}' has no main.jac; "
                    f"point source at the entry .jac file instead."
                );
            }
            return (str(path), 'main.jac');
        }
        if path.suffix != '.jac' {
            raise ValueError(
                f"DeploySpec.source must be a .jac file or a folder, "
                f"got '{self.source}'."
            );
        }
        if not path.is_file() {
            raise FileNotFoundError(f"DeploySpec.source not found: '{self.source}'");
        }
        return (str(path.parent) or '.', path.name);
    }

    def to_target_config -> dict[str, any] {
        config: dict[str, any] = {
            'app_name': self.app_name,
            'namespace': self.namespace,
            'domain': self.domain,
            'kube_context': self.kube_context,
            'labels': dict(self.labels)
        };

        unknown = sorted(set(self.resources.keys()) - set(_RESOURCE_KEYS));
        if unknown {
            raise ValueError(
                f"DeploySpec.resources has unsupported key(s) "
                f"{', '.join(unknown)}; allowed: {', '.join(_RESOURCE_KEYS)}."
            );
        }
        config.update(dict(self.resources));

        if self.replicas < 1 {
            raise ValueError(f"DeploySpec.replicas must be >= 1, got {self.replicas}.");
        }
        config['min_replicas'] = self.replicas;
        import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
            KubernetesConfig
        }
        default_max = KubernetesConfig(app_name=self.app_name).max_replicas;
        if self.replicas > default_max {
            config['max_replicas'] = self.replicas;
        }
        config.update(dict(self.autoscaler));
        config.update(dict(self.extra));
        return config;
    }

    def to_microservices_config -> dict[str, any] {
        ms = dict(self.microservices);
        ms['routes'] = dict(ms.get('routes', {}));
        if self.client {
            merged_client = dict(ms.get('client', {}));
            merged_client.update(dict(self.client));
            ms['client'] = merged_client;
        }
        services = dict(ms.get('services', {}));
        if self.replicas != 1 {
            import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
                GATEWAY_NAME
            }
            gateway_cfg = dict(services.get(GATEWAY_NAME, {}));
            gateway_cfg.setdefault('replicas', self.replicas);
            services[GATEWAY_NAME] = gateway_cfg;
        }
        ms['services'] = services;
        return ms;
    }
}
