"""Tests for ServiceDeployer and LocalDeployer."""

import unittest.mock;
import subprocess;
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.local_deployer {
    LocalDeployer
}

# =============================================================================
# LocalDeployer basics
# =============================================================================

test "local deployer initializes with registry" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    assert deployer.target == "local";
    assert deployer.process_manager is None;
}

test "local deployer creates process manager on first use" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);

    pm = deployer._ensure_pm();
    assert pm is not None;
    assert deployer.process_manager is not None;
}

# =============================================================================
# url_for: LocalDeployer is the single source of service URL construction
# =============================================================================

test "local deployer url_for returns loopback URL" {
    reg = ServiceRegistry();
    deployer = LocalDeployer(registry=reg);
    entry = ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=18042);
    assert deployer.url_for(entry) == "http://127.0.0.1:18042";
}

test "local deployer url_for tracks port mutations" {
    reg = ServiceRegistry();
    deployer = LocalDeployer(registry=reg);
    entry = ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=0);
    # Pre-spawn: port=0 yields a well-formed but non-listening URL; the
    # method doesn't short-circuit on port==0 because start_all's pre-pass
    # sets the port before start_service reads URLs via this method.
    assert deployer.url_for(entry) == "http://127.0.0.1:0";
    entry.port = 18999;
    assert deployer.url_for(entry) == "http://127.0.0.1:18999";
}

test "process manager wires deployer reference via _ensure_pm" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();
    # _url_for must dispatch through the owning deployer, not the fallback
    assert pm.deployer is deployer;
}

test "process manager _url_for uses deployer.url_for when wired" {
    reg = ServiceRegistry();
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();
    entry = ServiceEntry(name="cart", file="cart.jac", prefix="/api/cart", port=18123);
    assert pm._url_for(entry) == "http://127.0.0.1:18123";
}

# =============================================================================
# Deploy / Stop / Restart
# =============================================================================

test "deploy service starts subprocess" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        result = deployer.deploy_service("orders");
        assert result;
    }
}

test "deploy nonexistent service returns false" {
    reg = ServiceRegistry();
    deployer = LocalDeployer(registry=reg);
    assert not deployer.deploy_service("nonexistent");
}

test "stop service stops subprocess" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;
    mock_proc.wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = mock_proc;

    result = deployer.stop_service("orders");
    assert result;
    mock_proc.terminate.assert_called_once();
}

test "restart service stops then starts" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();

    # Set up running process
    old_proc = unittest.mock.MagicMock();
    old_proc.pid = 100;
    old_proc.wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = old_proc;

    new_proc = unittest.mock.MagicMock();
    new_proc.pid = 200;

    with unittest.mock.patch("subprocess.Popen", return_value=new_proc) {
        result = deployer.restart_service("orders");
        assert result;
        old_proc.terminate.assert_called_once();
    }
}

# =============================================================================
# Scale
# =============================================================================

test "scale to 0 stops service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;
    mock_proc.wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = mock_proc;

    deployer.scale_service("orders", 0);
    assert "orders" not in pm.processes;
}

# =============================================================================
# Status
# =============================================================================

test "status returns all services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(
        name="orders", file="orders.jac", prefix="/api/orders",
        port=8001, url="http://127.0.0.1:8001"
    ));
    reg.register(ServiceEntry(
        name="cart", file="cart.jac", prefix="/api/cart",
        port=8002, url="http://127.0.0.1:8002"
    ));
    deployer = LocalDeployer(registry=reg);

    with unittest.mock.patch.object(deployer._ensure_pm(), "check_all_health", return_value={}) {
        svc_status = deployer.status();
        assert "orders" in svc_status;
        assert "cart" in svc_status;
        assert svc_status["orders"]["target"] == "local";
        assert svc_status["orders"]["prefix"] == "/api/orders";
    }
}

# =============================================================================
# Logs
# =============================================================================

test "get logs for missing service" {
    reg = ServiceRegistry();
    deployer = LocalDeployer(registry=reg);
    result = deployer.get_logs("nonexistent");
    assert "not found" in result;
}

test "get logs returns string for registered service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    deployer = LocalDeployer(registry=reg);
    result = deployer.get_logs("orders");
    # Returns either log content or "No log file" message
    assert isinstance(result, str);
}

# =============================================================================
# Destroy
# =============================================================================

test "destroy all stops everything" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(ServiceEntry(name="cart", file="cart.jac", prefix="/api/cart"));
    deployer = LocalDeployer(registry=reg);
    pm = deployer._ensure_pm();

    for name in ["orders", "cart"] {
        mock_proc = unittest.mock.MagicMock();
        mock_proc.pid = 100;
        mock_proc.wait = unittest.mock.MagicMock(return_value=0);
        pm.processes[name] = mock_proc;
    }

    result = deployer.destroy_all();
    assert result;
    assert len(pm.processes) == 0;
}

# =============================================================================
# Deploy all
# =============================================================================

test "deploy all starts all services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(ServiceEntry(name="cart", file="cart.jac", prefix="/api/cart"));
    deployer = LocalDeployer(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        result = deployer.deploy_all();
        assert result;
        assert len(deployer._ensure_pm().processes) == 2;
    }
}
