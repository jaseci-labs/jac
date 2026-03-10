"""Tests for abstraction base classes."""

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.resource_status {
    ResourceStatus,
    ResourceStatusInfo
}

test "deployment result success" {
    result = DeploymentResult(
        success=True,
        service_url="http://localhost:8000",
        message="Deployment successful"
    );

    assert result.success is True;
    assert result.is_successful() is True;
    assert result.service_url == "http://localhost:8000";
    assert result.message == "Deployment successful";
}

test "deployment result failure" {
    result = DeploymentResult(
        success=False,
        message="Deployment failed",
        details={"error": "Connection timeout"}
    );

    assert result.success is False;
    assert result.is_successful() is False;
    assert result.message == "Deployment failed";
    assert "error" in result.details;
}

test "resource status info ready" {
    status = ResourceStatusInfo(
        status=ResourceStatus.RUNNING, replicas=3, ready_replicas=3
    );

    assert status.is_ready() is True;
    assert status.replicas == 3;
    assert status.ready_replicas == 3;
}

test "resource status info not ready" {
    status = ResourceStatusInfo(
        status=ResourceStatus.PENDING, replicas=3, ready_replicas=1
    );

    assert status.is_ready() is False;
    assert status.replicas == 3;
    assert status.ready_replicas == 1;
}

test "resource status enum" {
    assert ResourceStatus.UNKNOWN == "unknown";
    assert ResourceStatus.PENDING == "pending";
    assert ResourceStatus.RUNNING == "running";
    assert ResourceStatus.FAILED == "failed";
    assert ResourceStatus.STOPPED == "stopped";
}

test "app config get code path" {
    app_config = AppConfig(code_folder="/path/to/code");

    path = app_config.get_code_path();

    assert str(path) == "/path/to/code";
    assert hasattr(path, "exists");
}
