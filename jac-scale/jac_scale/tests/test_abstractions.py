"""Tests for abstraction base classes."""

import pytest

# Note: These imports will work once the Jac files are compiled to Python
try:
    from ..abstractions.config.app_config import AppConfig
    from ..abstractions.models.deployment_result import DeploymentResult
    from ..abstractions.models.resource_status import (
        ResourceStatus,
        ResourceStatusInfo,
    )
except ImportError:
    # If Jac files aren't compiled yet, skip these tests
    pytest.skip("Jac modules not compiled", allow_module_level=True)


def test_deployment_result_success():
    """Test DeploymentResult with success."""
    result = DeploymentResult(
        success=True,
        service_url="http://localhost:8000",
        message="Deployment successful",
    )

    assert result.success is True
    assert result.is_successful() is True
    assert result.service_url == "http://localhost:8000"
    assert result.message == "Deployment successful"


def test_deployment_result_failure():
    """Test DeploymentResult with failure."""
    result = DeploymentResult(
        success=False,
        message="Deployment failed",
        details={"error": "Connection timeout"},
    )

    assert result.success is False
    assert result.is_successful() is False
    assert result.message == "Deployment failed"
    assert "error" in result.details


def test_resource_status_info_ready():
    """Test ResourceStatusInfo when resource is ready."""
    status = ResourceStatusInfo(
        status=ResourceStatus.RUNNING,
        replicas=3,
        ready_replicas=3,
    )

    assert status.is_ready() is True
    assert status.replicas == 3
    assert status.ready_replicas == 3


def test_resource_status_info_not_ready():
    """Test ResourceStatusInfo when resource is not ready."""
    status = ResourceStatusInfo(
        status=ResourceStatus.PENDING,
        replicas=3,
        ready_replicas=1,
    )

    assert status.is_ready() is False
    assert status.replicas == 3
    assert status.ready_replicas == 1


def test_resource_status_enum():
    """Test ResourceStatus enum values."""
    assert ResourceStatus.UNKNOWN == "unknown"
    assert ResourceStatus.PENDING == "pending"
    assert ResourceStatus.RUNNING == "running"
    assert ResourceStatus.FAILED == "failed"
    assert ResourceStatus.STOPPED == "stopped"


def test_app_config_get_code_path():
    """Test AppConfig.get_code_path() method."""
    app_config = AppConfig(code_folder="/path/to/code")

    path = app_config.get_code_path()

    assert str(path) == "/path/to/code"
    assert hasattr(path, "exists")  # Should be a Path object
