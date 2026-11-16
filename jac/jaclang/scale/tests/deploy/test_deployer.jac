import unittest.mock;
import subprocess;

def _as_any(v: any) -> any {
    return v;
}

test "process manager url tracks port mutations" {
    reg = ServiceRegistry();
    pm = ServiceProcessManager(registry=reg);
    `entry = ServiceEntry(
        name="orders", file="orders.jac", prefix="/api/orders", port=0
    );

    assert pm._url_for(`entry) == "http://127.0.0.1:0";
    `entry.port = 18999;
    assert pm._url_for(`entry) == "http://127.0.0.1:18999";
}

test "stop service stops subprocess" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;
    mock_proc.`wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = _as_any(mock_proc);

    result = pm.stop_service("orders");
    assert result;
    mock_proc.terminate.assert_called_once();
}

test "restart service stops then starts" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);

    old_proc = unittest.mock.MagicMock();
    old_proc.pid = 100;
    old_proc.`wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = _as_any(old_proc);

    new_proc = unittest.mock.MagicMock();
    new_proc.pid = 200;

    with unittest.mock.patch("subprocess.Popen", return_value=new_proc) {
        result = pm.restart_service("orders");
        assert result;
        old_proc.terminate.assert_called_once();
    }
}

test "status returns all services" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001"
        )
    );
    reg.register(
        ServiceEntry(
            name="cart",
            file="cart.jac",
            prefix="/api/cart",
            port=8002,
            url="http://127.0.0.1:8002"
        )
    );
    pm = ServiceProcessManager(registry=reg);

    with unittest.mock.patch.object(pm, "check_all_health", return_value={}) {
        svc_status = pm.status();
        assert "orders" in svc_status;
        assert "cart" in svc_status;
        assert svc_status["orders"]["target"] == "local";
        assert svc_status["orders"]["prefix"] == "/api/orders";
    }
}

test "get logs for missing service" {
    reg = ServiceRegistry();
    pm = ServiceProcessManager(registry=reg);
    result = pm.get_logs("nonexistent");
    assert "not found" in result;
}

test "get logs returns string for registered service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);
    result = pm.get_logs("orders");

    assert isinstance(result, str);
}

test "stop all stops everything" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(ServiceEntry(name="cart", file="cart.jac", prefix="/api/cart"));
    pm = ServiceProcessManager(registry=reg);

    for name in ["orders", "cart"] {
        mock_proc = unittest.mock.MagicMock();
        mock_proc.pid = 100;
        mock_proc.`wait = unittest.mock.MagicMock(return_value=0);
        pm.processes[name] = _as_any(mock_proc);
    }

    pm.stop_all();
    assert len(pm.processes) == 0;
}


test "start all starts all services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(ServiceEntry(name="cart", file="cart.jac", prefix="/api/cart"));
    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        pm.start_all();
        assert len(pm.processes) == 2;
    }
}
