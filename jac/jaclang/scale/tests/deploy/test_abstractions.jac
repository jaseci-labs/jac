import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatus, ResourceStatusInfo }

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

test "resource status info settled and serving" {
    status = ResourceStatusInfo(
        status=ResourceStatus.ACTIVE, replicas=3, ready_replicas=3
    );

    assert status.is_settled() is True;
    assert status.is_serving() is True;
    assert status.replicas == 3;
    assert status.ready_replicas == 3;
}

test "resource status info activating is not settled" {
    status = ResourceStatusInfo(
        status=ResourceStatus.ACTIVATING, replicas=3, ready_replicas=0
    );

    assert status.is_settled() is False;
    assert status.is_serving() is False;
    assert status.replicas == 3;
    assert status.ready_replicas == 0;
}

test "resource status info inactive is settled and serving at zero replicas" {
    status = ResourceStatusInfo(
        status=ResourceStatus.INACTIVE, replicas=0, ready_replicas=0, replica_floor=0
    );

    assert status.is_settled() is True;
    assert status.is_serving() is True;
}

test "resource status enum" {
    assert ResourceStatus.UNKNOWN.value == "unknown";
    assert ResourceStatus.INACTIVE.value == "inactive";
    assert ResourceStatus.ACTIVATING.value == "activating";
    assert ResourceStatus.ACTIVE.value == "active";
    assert ResourceStatus.DEACTIVATING.value == "deactivating";
    assert ResourceStatus.DEGRADED.value == "degraded";
}

test "app config get code path" {
    app_config = AppConfig(code_folder="/path/to/code");

    path = app_config.get_code_path();

    assert str(path) == "/path/to/code";
    assert hasattr(path, "exists");
}
