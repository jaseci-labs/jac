import os;
import from typing { Any }
import from jac_scale.abstractions.sandbox_environment { SandboxEnvironment }
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.logger { Logger }

obj SandboxFactory {
    static def create(
        sandbox_type: str,
        config: (dict[str, Any] | None) = None,
        logger: (Logger | None) = None
    ) -> SandboxEnvironment {
        cfg: dict[str, Any] = config if config is not None else {};
        sandbox_config = SandboxConfig.from_dict(cfg);

        if sandbox_type == "kubernetes" {
            import from jac_scale.providers.sandbox.kubernetes_sandbox {
                KubernetesSandbox
            }
            return KubernetesSandbox(config=sandbox_config, logger=logger);
        } elif sandbox_type == "docker" {
            import from jac_scale.providers.sandbox.docker_sandbox { DockerSandbox }
            return DockerSandbox(config=sandbox_config, logger=logger);
        } elif sandbox_type == "local" {
            import from jac_scale.providers.sandbox.local_sandbox { LocalSandbox }
            return LocalSandbox(config=sandbox_config, logger=logger);
        } else {
            raise ValueError(f"Unsupported sandbox type: {sandbox_type}");
        }
    }

    static def get_default(
        config_override: (dict[str, Any] | None) = None, logger: (Logger | None) = None
    ) -> SandboxEnvironment {
        sandbox_type = "local";
        cfg: dict[str, Any] = {};

        try {
            import from jac_scale.config_loader { get_scale_config }
            scale_config = get_scale_config();
            sandbox_cfg: dict[str, Any] = scale_config.get_section("sandbox");
            if sandbox_cfg and sandbox_cfg.get("enabled", False) {
                sandbox_type = str(sandbox_cfg.get("type", "local"));
                cfg = sandbox_cfg;
            }
        } except Exception {
            ;
        }

        env_type = str(os.environ.get("JAC_SANDBOX_TYPE", "")).strip();
        if env_type {
            sandbox_type = env_type;
        }
        env_ns = str(os.environ.get("JAC_SANDBOX_NAMESPACE", "")).strip();
        if env_ns {
            cfg["namespace"] = env_ns;
        }
        env_domain = str(os.environ.get("JAC_SANDBOX_DOMAIN", "")).strip();
        if env_domain {
            cfg["domain_template"] = env_domain;
        }

        if config_override {
            if "type" in config_override {
                sandbox_type = str(config_override["type"]);
            }
            for (k, v) in config_override.items() {
                cfg[k] = v;
            }
        }

        return SandboxFactory.create(sandbox_type, cfg, logger);
    }
}
