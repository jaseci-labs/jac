"""Tests for microservices ServiceProcessManager."""

import unittest.mock;
import subprocess;
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.process_manager { ServiceProcessManager }

# =============================================================================
# Port assignment
# =============================================================================
test "auto assigns hash-based ports in 18000-18999 range" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/api/payments")
    );

    pm = ServiceProcessManager(registry=reg);

    port1 = pm._assign_port(reg.entries["orders"]);
    port2 = pm._assign_port(reg.entries["payments"]);

    # Hash-based: 18000 + hash(name) % 1000 (with retries for conflicts)
    assert 18000 <= port1 < 19100;
    assert 18000 <= port2 < 19100;
    # Different services should get different ports
    assert port1 != port2;
}

test "auto assigned port is deterministic for same service name" {
    reg1 = ServiceRegistry();
    reg1.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm1 = ServiceProcessManager(registry=reg1);
    port1 = pm1._assign_port(reg1.entries["orders"]);

    reg2 = ServiceRegistry();
    reg2.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm2 = ServiceProcessManager(registry=reg2);
    port2 = pm2._assign_port(reg2.entries["orders"]);

    # Same module name should produce same base port (deterministic hashing)
    # Note: Python's hash() is randomized per-process unless PYTHONHASHSEED is set,
    # but within a single test run both calls use the same seed.
    assert port1 == port2;
}

test "uses explicit port when set" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=9090)
    );

    pm = ServiceProcessManager(registry=reg);
    port = pm._assign_port(reg.entries["orders"]);

    assert port == 9090;
}

# =============================================================================
# Start service
# =============================================================================
test "start service launches subprocess" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        result = pm.start_service("orders");
        assert result;
        assert "orders" in pm.processes;
        assert reg.entries["orders"].pid == 12345;
        assert reg.entries["orders"].status == ServiceStatus.STARTING;
        # Hash-based port in 18000-18999 range
        assert reg.entries["orders"].url.startswith("http://127.0.0.1:18");
    }
}

test "start service with nonexistent name returns false" {
    reg = ServiceRegistry();
    pm = ServiceProcessManager(registry=reg);

    result = pm.start_service("nonexistent");
    assert not result;
}

test "start all launches all services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/api/payments")
    );

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        pm.start_all();
        assert len(pm.processes) == 2;
    }
}

# =============================================================================
# Stop service
# =============================================================================
test "stop service terminates process" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;
    mock_proc.wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = mock_proc;
    reg.entries["orders"].pid = 12345;
    reg.entries["orders"].status = ServiceStatus.HEALTHY;

    result = pm.stop_service("orders");

    assert result;
    assert "orders" not in pm.processes;
    assert reg.entries["orders"].status == ServiceStatus.STOPPED;
    assert reg.entries["orders"].pid is None;
    mock_proc.terminate.assert_called_once();
}

test "stop service force kills on timeout" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;
    # First wait(timeout=10) raises TimeoutExpired, second wait() after kill succeeds
    mock_proc.wait = unittest.mock.MagicMock(
        side_effect=[subprocess.TimeoutExpired("jac", 10), 0]
    );
    pm.processes["orders"] = mock_proc;

    pm.stop_service("orders");

    mock_proc.terminate.assert_called_once();
    mock_proc.kill.assert_called_once();
}

test "stop nonexistent service returns false" {
    reg = ServiceRegistry();
    pm = ServiceProcessManager(registry=reg);
    assert not pm.stop_service("nonexistent");
}

test "stop all stops all running services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/api/payments")
    );

    pm = ServiceProcessManager(registry=reg);

    for name in ["orders", "payments"] {
        mock_proc = unittest.mock.MagicMock();
        mock_proc.pid = 100;
        mock_proc.wait = unittest.mock.MagicMock(return_value=0);
        pm.processes[name] = mock_proc;
    }

    pm.stop_all();
    assert len(pm.processes) == 0;
}

# =============================================================================
# Health checks
# =============================================================================
test "check health returns false on no url" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );

    pm = ServiceProcessManager(registry=reg);
    assert not pm.check_health("orders");
}

test "check health returns false on network error" {
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

    pm = ServiceProcessManager(registry=reg);

    with unittest.mock.patch(
        "urllib.request.urlopen", side_effect=OSError("connection refused")
    ) {
        assert not pm.check_health("orders");
    }
}

test "check all health marks service unhealthy after max failures" {
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

    pm = ServiceProcessManager(registry=reg, _max_failures=2);

    # Mock check_health to return False (simulates failed health checks)
    with unittest.mock.patch.object(pm, "check_health", return_value=False) {
        pm.check_all_health();
        assert reg.entries["orders"].status != ServiceStatus.UNHEALTHY;
        pm.check_all_health();
        assert reg.entries["orders"].status == ServiceStatus.UNHEALTHY;
    }
}

test "check all health resets failure count on success" {
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

    pm = ServiceProcessManager(registry=reg, _max_failures=3);

    # Fail once
    with unittest.mock.patch.object(pm, "check_health", return_value=False) {
        pm.check_all_health();
    }
    assert pm._failure_counts["orders"] == 1;

    # Succeed - resets count
    with unittest.mock.patch.object(pm, "check_health", return_value=True) {
        pm.check_all_health();
    }
    assert pm._failure_counts["orders"] == 0;
    assert reg.entries["orders"].status == ServiceStatus.HEALTHY;
}

# =============================================================================
# Restart
# =============================================================================
test "restart stops then starts service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));

    pm = ServiceProcessManager(registry=reg);

    # Set up a running process to stop
    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;
    mock_proc.wait = unittest.mock.MagicMock(return_value=0);
    pm.processes["orders"] = mock_proc;

    new_proc = unittest.mock.MagicMock();
    new_proc.pid = 200;

    with unittest.mock.patch("subprocess.Popen", return_value=new_proc) {
        result = pm.restart_service("orders");
        assert result;
        assert pm.processes["orders"] == new_proc;
        mock_proc.terminate.assert_called_once();
    }
}

# =============================================================================
# Pidfile-backed cross-process stop
# =============================================================================
test "stop_service with pidfile only kills by pid when Popen handle is absent" {
    # Simulates `jac scale stop` running in a fresh CLI process: the pm
    # was just constructed and has no Popen handle, but a pidfile from a
    # previous orchestrator run still points at a (mock) live process.
    import os;
    import tempfile;
    import from pathlib { Path }

    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);

    # Use a dedicated tempdir as cwd so we don't stomp on any real pidfile
    tmp = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp);

    try {
        run_dir = Path(".jac/run");
        run_dir.mkdir(parents=True, exist_ok=True);
        (run_dir / "orders.pid").write_text("424242");

        # os.kill must be called with the pidfile's pid (not via a Popen
        # handle, since pm.processes is empty). Side-effect sequence:
        #   call 1: pre-kill alive check  -> None (pid is alive)
        #   call 2: SIGTERM dispatch      -> None (signal delivered)
        #   call 3: wait-loop alive check -> ProcessLookupError (died)
        #   call 4: post-loop alive check -> ProcessLookupError (no SIGKILL)
        # The ProcessLookupErrors keep the test from burning the full
        # 10s kill-timeout on a mocked process.
        with unittest.mock.patch(
            "os.kill",
            side_effect=[None, None, ProcessLookupError(), ProcessLookupError()]
        ) {
            result = pm.stop_service("orders");
        }

        assert result;
        # Pidfile was cleaned up after stop
        assert not (run_dir / "orders.pid").exists();
        # Entry marked stopped
        assert reg.entries["orders"].status == ServiceStatus.STOPPED;
    } finally {
        os.chdir(original_cwd);
        import shutil;
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "stop_service returns false when neither pidfile nor Popen handle exist" {
    import os;
    import tempfile;

    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);

    tmp = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp);

    try {
        result = pm.stop_service("orders");
        assert not result;
    } finally {
        os.chdir(original_cwd);
        import shutil;
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "stop_service cleans up stale pidfile when pid is already dead" {
    # ProcessLookupError from os.kill(pid, 0) means the recorded pid is
    # no longer alive. stop_service should treat this as success and
    # remove the stale pidfile instead of erroring out.
    import os;
    import tempfile;
    import from pathlib { Path }

    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders"));
    pm = ServiceProcessManager(registry=reg);

    tmp = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp);

    try {
        run_dir = Path(".jac/run");
        run_dir.mkdir(parents=True, exist_ok=True);
        (run_dir / "orders.pid").write_text("999999");

        with unittest.mock.patch("os.kill", side_effect=ProcessLookupError()) {
            result = pm.stop_service("orders");
        }

        assert result;
        assert not (run_dir / "orders.pid").exists();
    } finally {
        os.chdir(original_cwd);
        import shutil;
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
