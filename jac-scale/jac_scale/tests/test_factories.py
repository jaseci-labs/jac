"""Tests for the new factory-based architecture."""

from unittest.mock import MagicMock, patch

import pytest

# Note: These imports will work once the Jac files are compiled to Python
# For now, we'll use relative imports that match the structure
try:
    from ..abstractions.config.app_config import AppConfig
    from ..factories.deployment_factory import DeploymentTargetFactory
    from ..factories.registry_factory import ImageRegistryFactory
    from ..factories.utility_factory import UtilityFactory
    from ..targets.kubernetes.kubernetes_config import KubernetesConfig
except ImportError:
    # If Jac files aren't compiled yet, skip these tests
    pytest.skip("Jac modules not compiled", allow_module_level=True)


def test_deployment_target_factory_creates_kubernetes_target():
    """Test that factory creates KubernetesTarget for 'kubernetes' type."""
    config = {
        "app_name": "test-app",
        "namespace": "default",
        "container_port": 8000,
        "node_port": 30001,
    }

    target = DeploymentTargetFactory.create("kubernetes", config)

    assert target is not None
    assert hasattr(target, "deploy")
    assert hasattr(target, "destroy")
    assert hasattr(target, "get_status")
    assert hasattr(target, "scale")
    assert target.k8s_config.app_name == "test-app"


def test_deployment_target_factory_raises_for_unsupported_target():
    """Test that factory raises ValueError for unsupported target."""
    config = {"app_name": "test-app"}

    with pytest.raises(ValueError, match="Unsupported deployment target"):
        DeploymentTargetFactory.create("unsupported", config)


def test_deployment_target_factory_raises_for_not_implemented_target():
    """Test that factory raises NotImplementedError for future targets."""
    config = {"app_name": "test-app"}

    with pytest.raises(NotImplementedError, match="not yet implemented"):
        DeploymentTargetFactory.create("aws", config)


def test_image_registry_factory_creates_dockerhub():
    """Test that factory creates DockerHubRegistry for 'dockerhub' type."""
    config = {
        "app_name": "test-app",
        "docker_username": "testuser",
        "docker_password": "testpass",
    }

    registry = ImageRegistryFactory.create("dockerhub", config)

    assert registry is not None
    assert hasattr(registry, "build_image")
    assert hasattr(registry, "push_image")
    assert hasattr(registry, "get_image_url")
    assert registry.docker_username == "testuser"


def test_image_registry_factory_raises_for_unsupported_registry():
    """Test that factory raises ValueError for unsupported registry."""
    config = {"app_name": "test-app"}

    with pytest.raises(ValueError, match="Unsupported image registry"):
        ImageRegistryFactory.create("unsupported", config)


def test_utility_factory_creates_standard_logger():
    """Test that factory creates StandardLogger for 'standard' type."""
    logger = UtilityFactory.create_logger("standard")

    assert logger is not None
    assert hasattr(logger, "info")
    assert hasattr(logger, "error")
    assert hasattr(logger, "warn")
    assert hasattr(logger, "debug")


def test_utility_factory_defaults_to_standard_logger():
    """Test that factory defaults to standard logger when no type specified."""
    logger = UtilityFactory.create_logger()

    assert logger is not None
    assert hasattr(logger, "info")


def test_kubernetes_config_from_dict():
    """Test KubernetesConfig creation from dictionary."""
    config_dict = {
        "app_name": "my-app",
        "namespace": "test-ns",
        "container_port": 9000,
        "node_port": 30002,
        "mongodb_enabled": False,
        "redis_enabled": False,
    }

    config = KubernetesConfig.from_dict(config_dict)

    assert config.app_name == "my-app"
    assert config.namespace == "test-ns"
    assert config.container_port == 9000
    assert config.node_port == 30002
    assert config.mongodb_enabled is False
    assert config.redis_enabled is False


def test_app_config_creation():
    """Test AppConfig creation."""
    app_config = AppConfig(
        code_folder="/path/to/code",
        file_name="main.jac",
        build=True,
    )

    assert app_config.code_folder == "/path/to/code"
    assert app_config.file_name == "main.jac"
    assert app_config.build is True
    assert app_config.testing is False


@patch("jac_scale.factories.deployment_factory.KubernetesTarget")
def test_deployment_target_with_logger(mock_kubernetes_target: MagicMock):
    """Test that deployment target is created with logger."""
    mock_target = MagicMock()
    mock_kubernetes_target.return_value = mock_target

    config = {"app_name": "test-app", "namespace": "default"}
    logger = UtilityFactory.create_logger("standard")

    DeploymentTargetFactory.create("kubernetes", config, logger)

    # Verify logger was passed to target
    mock_kubernetes_target.assert_called_once()
    call_kwargs = mock_kubernetes_target.call_args[1]
    assert "logger" in call_kwargs
    assert call_kwargs["logger"] == logger
