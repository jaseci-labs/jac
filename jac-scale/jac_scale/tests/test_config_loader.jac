"""Tests for jac_scale.config_loader against the real loader (other
tests stub get_microservices_config; this catches bugs in the loader
itself - e.g. when the ingress block was dropped from the return dict)."""

import from jac_scale.config_loader { JacScaleConfig }


test "get_microservices_config returns ingress block" {
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "ingress": {
                "enabled": True,
                "host": "jac-shop.local",
                "ingress_class_name": "nginx",
                "annotations": {"nginx.ingress.kubernetes.io/proxy-body-size": "10m"}
            }
        }
    };
    out = cfg.get_microservices_config();
    assert "ingress" in out;
    ing = out["ingress"];
    assert ing["enabled"] is True;
    assert ing["host"] == "jac-shop.local";
    assert ing["ingress_class_name"] == "nginx";
    assert ing["annotations"]["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
}


test "get_microservices_config ingress defaults to {} when section absent" {
    cfg = JacScaleConfig();
    cfg._config = {"microservices": {"enabled": True}};
    out = cfg.get_microservices_config();
    assert out["ingress"] == {};
}


test "get_microservices_config preserves all sections (regression guard)" {
    cfg = JacScaleConfig();
    cfg._config = {
        "microservices": {
            "enabled": True,
            "gateway_port": 9000,
            "drain_timeout_seconds": 15,
            "http_forward_timeout": 60,
            "routes": {"orders_app": "/api/orders"},
            "services": {"orders_app": {"replicas": 2}},
            "ingress": {"enabled": False}
        }
    };
    out = cfg.get_microservices_config();
    expected_keys: set[str] = {
        "enabled",
        "gateway_port",
        "gateway_host",
        "drain_timeout_seconds",
        "http_forward_timeout",
        "routes",
        "services",
        "rate_limit",
        "cors",
        "client",
        "ingress"
    };
    missing = expected_keys - set(out.keys());
    assert not missing , f"missing keys: {missing}";
}


test "get_scale_config implements path-keyed caching" {
    import from pathlib { Path }
    import tempfile;
    import from jac_scale.config_loader {
        get_scale_config,
        reset_scale_config,
        _scale_config_instances
    }

    reset_scale_config();

    with tempfile.TemporaryDirectory() as tmp1_str, tempfile.TemporaryDirectory() as tmp2_str {
        tmp1 = Path(tmp1_str).resolve();
        tmp2 = Path(tmp2_str).resolve();
        # Write different jac.toml configurations to each directory
        toml1 = tmp1 / "jac.toml";
        toml1_content = (
            "[plugins.scale.kubernetes]\n"
            "app_name = \"app1\"\n"
            "image_registry = \"registry1\"\n"
            "mongodb_root_username = \"user1\"\n"
            "mongodb_root_password = \"mock-mongodb-root-password-1\"\n"
            "redis_username = \"redisuser1\"\n"
            "redis_password = \"mock-redis-password-1\"\n"
            "domain = \"domain1.local\"\n"
            "cert_manager_email = \"email1@domain1.local\"\n\n"
            "[plugins.scale.database]\n"
            "redis_url = \"redis://user1:mock-redis-url-password-1@host1:6379\"\n\n"
            "[plugins.scale.secrets]\n"
            "api_key = \"mock-api-key-1\"\n"
        );
        toml1.write_text(toml1_content);
        toml2 = tmp2 / "jac.toml";
        toml2_content = (
            "[plugins.scale.kubernetes]\n"
            "app_name = \"app2\"\n"
            "image_registry = \"registry2\"\n"
            "mongodb_root_username = \"user2\"\n"
            "mongodb_root_password = \"mock-mongodb-root-password-2\"\n"
            "redis_username = \"redisuser2\"\n"
            "redis_password = \"mock-redis-password-2\"\n"
            "domain = \"domain2.local\"\n"
            "cert_manager_email = \"email2@domain2.local\"\n\n"
            "[plugins.scale.database]\n"
            "redis_url = \"redis://user2:mock-redis-url-password-2@host2:6379\"\n\n"
            "[plugins.scale.secrets]\n"
            "api_key = \"mock-api-key-2\"\n"
        );
        toml2.write_text(toml2_content);
        # Load configurations
        cfg1 = get_scale_config(tmp1);
        cfg2 = get_scale_config(tmp2);
        # 1. Verify separate cache instances are created
        assert cfg1 is not cfg2;
        # 2. Verify independent configuration values are correctly parsed
        # App Names
        assert cfg1.get_kubernetes_config()["app_name"] == "app1";
        assert cfg2.get_kubernetes_config()["app_name"] == "app2";
        # Image Registries
        assert cfg1.load().get("kubernetes", {}).get("image_registry") == "registry1";
        assert cfg2.load().get("kubernetes", {}).get("image_registry") == "registry2";
        # Database URLs
        assert cfg1.get_database_config()["redis_url"] == "redis://user1:mock-redis-url-password-1@host1:6379";
        assert cfg2.get_database_config()["redis_url"] == "redis://user2:mock-redis-url-password-2@host2:6379";
        # MongoDB Credentials
        assert cfg1.get_kubernetes_config()["mongodb_root_username"] == "user1";
        assert cfg2.get_kubernetes_config()["mongodb_root_username"] == "user2";
        assert cfg1.get_kubernetes_config()["mongodb_root_password"] == "mock-mongodb-root-password-1";
        assert cfg2.get_kubernetes_config()["mongodb_root_password"] == "mock-mongodb-root-password-2";
        # Redis Credentials
        assert cfg1.get_kubernetes_config()["redis_username"] == "redisuser1";
        assert cfg2.get_kubernetes_config()["redis_username"] == "redisuser2";
        assert cfg1.get_kubernetes_config()["redis_password"] == "mock-redis-password-1";
        assert cfg2.get_kubernetes_config()["redis_password"] == "mock-redis-password-2";
        # Domain / Ingress Settings
        assert cfg1.get_kubernetes_config()["domain"] == "domain1.local";
        assert cfg2.get_kubernetes_config()["domain"] == "domain2.local";
        assert cfg1.get_kubernetes_config()["cert_manager_email"] == "email1@domain1.local";
        assert cfg2.get_kubernetes_config()["cert_manager_email"] == "email2@domain2.local";
        # Custom Secrets
        assert cfg1.get_secrets_config()["api_key"] == "mock-api-key-1";
        assert cfg2.get_secrets_config()["api_key"] == "mock-api-key-2";
        # 3. Verify equivalent paths normalize and resolve to the same instance
        rel_tmp1 = Path(tmp1_str);
        cfg1_rel = get_scale_config(rel_tmp1);
        assert cfg1_rel is cfg1;
        # 4. Verify cache resetting works correctly
        reset_scale_config();
        assert len(_scale_config_instances) == 0;
    }
}
