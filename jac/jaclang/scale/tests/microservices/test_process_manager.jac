import unittest.mock;
import subprocess;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }

"""Start a real HTTP health endpoint on a free port.

The server answers every GET with `srv.health_code` (toggle it live to flip a
service between healthy 200 and unhealthy 503) and counts requests in
`srv.request_count`. Returns the server; use `_health_url(srv)` for its base URL
and `srv.shutdown(); srv.server_close()` to kill it.
"""
def _serve_health(code: int = 200) -> any {
    import http.server;
    import threading;

    def _do_get(handler_self: any) {
        handler_self.server.request_count += 1;
        status = handler_self.server.health_code;
        handler_self.send_response(status);
        handler_self.send_header("Content-Type", "text/plain");
        handler_self.end_headers();
        handler_self.wfile.write(b"ok");
    }

    def _log_quiet(handler_self: any, fmt: str, *args: any) { }

    handler_cls = type(
        "_HealthHandler",
        (http.server.BaseHTTPRequestHandler, ),
        {"do_GET": _do_get, "log_message": _log_quiet}
    );
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_cls);
    srv.health_code = code;
    srv.request_count = 0;
    t = threading.Thread(target=srv.serve_forever, daemon=True);
    t.start();
    return srv;
}

def _health_url(srv: any) -> str {
    return f"http://127.0.0.1:{srv.server_address[1]}";
}

test "auto assigns hash-based ports in 18000-18999 range" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/payments")
    );

    pm = ServiceProcessManager(registry=reg);

    port1 = pm._assign_port(reg.entries["orders"]);
    port2 = pm._assign_port(reg.entries["payments"]);

    assert 18000 <= port1 < 19100;
    assert 18000 <= port2 < 19100;

    assert port1 != port2;
}

test "auto assigned port is deterministic for same service name" {
    reg1 = ServiceRegistry();
    reg1.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    pm1 = ServiceProcessManager(registry=reg1);
    port1 = pm1._assign_port(reg1.entries["orders"]);

    reg2 = ServiceRegistry();
    reg2.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    pm2 = ServiceProcessManager(registry=reg2);
    port2 = pm2._assign_port(reg2.entries["orders"]);

    assert port1 == port2;
}

test "uses explicit port when set" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/orders", port=9090)
    );

    pm = ServiceProcessManager(registry=reg);
    port = pm._assign_port(reg.entries["orders"]);

    assert port == 9090;
}

test "start service launches subprocess" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        result = pm.start_service("orders");
        assert result;
        assert "orders" in pm.processes;
        assert reg.entries["orders"].pid == 12345;
        assert reg.entries["orders"].status == ServiceStatus.STARTING;
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
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/payments")
    );

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 100;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) {
        pm.start_all();
        assert len(pm.processes) == 2;
    }
}

test "stop service terminates process" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/orders", port=8001)
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
        ServiceEntry(name="orders", file="orders.jac", prefix="/orders", port=8001)
    );

    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;

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
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    reg.register(
        ServiceEntry(name="payments", file="payments.jac", prefix="/payments")
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

test "check health returns false on no url" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/orders", port=8001)
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
            prefix="/orders",
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

test "start service passes the registry's subdir file path to jac start" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="social_graph", file="littlex/social_graph.jac", prefix="/social_graph"
        )
    );
    pm = ServiceProcessManager(registry=reg);

    mock_proc = unittest.mock.MagicMock();
    mock_proc.pid = 12345;

    with unittest.mock.patch("subprocess.Popen", return_value=mock_proc) as popen {
        assert pm.start_service("social_graph");
        cmd = popen.call_args[0][0];
        assert "littlex/social_graph.jac" in cmd , (
            f"spawn must use the registry file path verbatim, got: {cmd}"
        );
    }
}

test "check all health marks a dead managed process STOPPED without HTTP polling" {
    # A live, healthy 200 endpoint stands behind the service: if the dead-child
    # path ever consulted the real check_health, the entry would flip HEALTHY and
    # the server would log a request. Proving it stays STOPPED with zero requests
    # shows the real check_all_health short-circuits before any HTTP poll.
    srv = _serve_health(200);
    try {
        reg = ServiceRegistry();
        reg.register(
            ServiceEntry(
                name="orders",
                file="orders.jac",
                prefix="/orders",
                port=8001,
                url=_health_url(srv),
                status=ServiceStatus.STARTING
            )
        );
        pm = ServiceProcessManager(registry=reg);

        dead_proc = unittest.mock.MagicMock();
        dead_proc.pid = 12345;
        dead_proc.poll = unittest.mock.MagicMock(return_value=1);
        pm.processes["orders"] = dead_proc;

        results = pm.check_all_health();

        assert reg.entries["orders"].status == ServiceStatus.STOPPED , (
            f"a dead child can never become healthy; status must be STOPPED, "
            f"got {reg.entries['orders'].status}"
        );
        assert results["orders"] == False;
        assert srv.request_count == 0 , (
            f"a dead child must not be HTTP-polled, the live 200 endpoint saw "
            f"{srv.request_count} requests"
        );
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

test "check all health reports a dead process once, not every poll" {
    import jaclang.scale.runtime.orchestrator.process_manager as pm_mod;

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.STARTING
        )
    );
    pm = ServiceProcessManager(registry=reg);

    dead_proc = unittest.mock.MagicMock();
    dead_proc.pid = 12345;
    dead_proc.poll = unittest.mock.MagicMock(return_value=1);
    pm.processes["orders"] = dead_proc;

    with unittest.mock.patch.object(pm_mod, "logger") as fake_log {
        pm.check_all_health();
        pm.check_all_health();
        pm.check_all_health();
        exit_reports = [
            c
            for c in (
                list(fake_log.warning.call_args_list) + list(
                    fake_log.error.call_args_list
                )
            )
            if "exited" in str(c)
        ];
    }
    assert len(exit_reports) == 1 , (
        f"a dead child must be reported exactly once, got {len(exit_reports)}: "
        f"{exit_reports}"
    );
}

test "check all health marks service unhealthy after max failures" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/orders",
            port=8001,
            url="http://127.0.0.1:8001"
        )
    );

    pm = ServiceProcessManager(registry=reg, _max_failures=2);

    # A real endpoint that answers 503: the real check_health does a real GET
    # /healthz and genuinely fails each poll, so the failure counter climbs to
    # _max_failures on real health transitions.
    srv = _serve_health(503);
    reg.entries["orders"].url = _health_url(srv);
    try {
        pm.check_all_health();
        assert reg.entries["orders"].status != ServiceStatus.UNHEALTHY;
        pm.check_all_health();
        assert reg.entries["orders"].status == ServiceStatus.UNHEALTHY;
        assert srv.request_count == 2 , (
            f"each poll must hit the real endpoint, got {srv.request_count}"
        );
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

test "check all health resets failure count on success" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/orders",
            port=8001,
            url="http://127.0.0.1:8001"
        )
    );

    pm = ServiceProcessManager(registry=reg, _max_failures=3);

    # One real endpoint we toggle live: 503 first (a genuine failed poll bumps the
    # counter to 1), then 200 (a genuine healthy poll resets it to 0 and marks the
    # entry HEALTHY). The real check_health reacts to the real health transition.
    srv = _serve_health(503);
    reg.entries["orders"].url = _health_url(srv);
    try {
        pm.check_all_health();
        assert pm._failure_counts["orders"] == 1;

        srv.health_code = 200;
        pm.check_all_health();
        assert pm._failure_counts["orders"] == 0;
        assert reg.entries["orders"].status == ServiceStatus.HEALTHY;
    } finally {
        srv.shutdown();
        srv.server_close();
    }
}

test "restart stops then starts service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));

    pm = ServiceProcessManager(registry=reg);

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

test "stop_service with pidfile only kills by pid when Popen handle is absent" {
    import os;
    import tempfile;
    import from pathlib { Path }

    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    pm = ServiceProcessManager(registry=reg);

    tmp = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp);

    try {
        run_dir = Path(".jac/run");
        run_dir.mkdir(parents=True, exist_ok=True);
        (run_dir / "orders.pid").write_text("424242");

        with unittest.mock.patch(
            "os.kill",
            side_effect=[None, None, ProcessLookupError(), ProcessLookupError()]
        ) {
            result = pm.stop_service("orders");
        }

        assert result;

        assert not (run_dir / "orders.pid").exists();

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
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
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
    import os;
    import tempfile;
    import from pathlib { Path }

    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
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
