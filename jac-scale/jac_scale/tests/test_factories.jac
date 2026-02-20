"""Tests for the new factory-based architecture."""

import unittest.mock;
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }

test "deployment target factory creates kubernetes target" {
    config = {
        "app_name": "test-app",
        "namespace": "default",
        "container_port": 8000,
        "node_port": 30001
    };

    target = DeploymentTargetFactory.create("kubernetes", config);

    assert target is not None;
    assert hasattr(target, "deploy");
    assert hasattr(target, "destroy");
    assert hasattr(target, "get_status");
    assert hasattr(target, "scale");
    assert target.k8s_config.app_name == "test-app";
}

test "deployment target factory raises for unsupported target" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        DeploymentTargetFactory.create("unsupported", config);
    } except ValueError as e {
        raised = True;
        assert "Unsupported deployment target" in str(e);
    }
    assert raised , "Expected ValueError for unsupported target";
}

test "deployment target factory raises for not implemented target" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        DeploymentTargetFactory.create("aws", config);
    } except NotImplementedError as e {
        raised = True;
        assert "not yet implemented" in str(e);
    }
    assert raised , "Expected NotImplementedError for aws target";
}

test "image registry factory creates dockerhub" {
    config = {
        "app_name": "test-app",
        "docker_username": "testuser",
        "docker_password": "testpass"
    };

    registry = ImageRegistryFactory.create("dockerhub", config);

    assert registry is not None;
    assert hasattr(registry, "build_image");
    assert hasattr(registry, "push_image");
    assert hasattr(registry, "get_image_url");
    assert registry.docker_username == "testuser";
}

test "image registry factory raises for unsupported registry" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        ImageRegistryFactory.create("unsupported", config);
    } except ValueError as e {
        raised = True;
        assert "Unsupported image registry" in str(e);
    }
    assert raised , "Expected ValueError for unsupported registry";
}

test "utility factory creates standard logger" {
    logger = UtilityFactory.create_logger("standard");

    assert logger is not None;
    assert hasattr(logger, "info");
    assert hasattr(logger, "error");
    assert hasattr(logger, "warn");
    assert hasattr(logger, "debug");
}

test "utility factory defaults to standard logger" {
    logger = UtilityFactory.create_logger();

    assert logger is not None;
    assert hasattr(logger, "info");
}

test "kubernetes config from dict" {
    config_dict = {
        "app_name": "my-app",
        "namespace": "test-ns",
        "container_port": 9000,
        "node_port": 30002,
        "mongodb_enabled": False,
        "redis_enabled": False
    };

    config = KubernetesConfig.from_dict(config_dict);

    assert config.app_name == "my-app";
    assert config.namespace == "test-ns";
    assert config.container_port == 9000;
    assert config.node_port == 30002;
    assert config.mongodb_enabled is False;
    assert config.redis_enabled is False;
}

test "app config creation" {
    app_config = AppConfig(
        code_folder="/path/to/code", file_name="main.jac", build=True
    );

    assert app_config.code_folder == "/path/to/code";
    assert app_config.file_name == "main.jac";
    assert app_config.build is True;
    assert app_config.testing is False;
}

test "deployment target with logger" {
    with unittest.mock.patch("jac_scale.factories.deployment_factory.KubernetesTarget") as mock_kubernetes_target {
        mock_target = unittest.mock.MagicMock();
        mock_kubernetes_target.return_value = mock_target;
        config = {"app_name": "test-app", "namespace": "default"};
        logger = UtilityFactory.create_logger("standard");
        DeploymentTargetFactory.create("kubernetes", config, logger);
        mock_kubernetes_target.assert_called_once();
        call_kwargs = mock_kubernetes_target.call_args[1];
        assert "logger" in call_kwargs;
        assert call_kwargs["logger"] == logger;
    }
}
