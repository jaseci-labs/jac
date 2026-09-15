"""Boot grace is a window that ends once, not a counter that keeps running.

While a fleet boots, a service that has not answered `/healthz` yet is
STARTING, and the monitor must not write it off. The grace used to be a guard
on the verdict only: the failure counter kept climbing through every boot poll,
so the moment boot ended the next tick found dozens of banked failures and
marked the service UNHEALTHY anyway. Boot now leaves no failures behind, and a
manager that never booted a fleet is not treated as booting forever.
"""
import socket;
import time;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry,
    ServiceStatus
}
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }

"""A port nobody listens on, so every health probe is refused at once."""
def _unbound_port -> int {
    sock = socket.socket();
    sock.bind(("127.0.0.1", 0));
    port: int = int(sock.getsockname()[1]);
    sock.close();
    return port;
}

def _manager(status: ServiceStatus) -> ServiceProcessManager {
    port = _unbound_port();
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/__main__",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=status,
            is_root=True
        )
    );
    pm = ServiceProcessManager(registry=reg);
    pm._health_check_timeout = 1;
    return pm;
}

test "a service still starting when boot ends is not written off on the first tick" {
    pm = _manager(ServiceStatus.STARTING);
    `entry = pm.registry.entries["main"];
    pm._booting = True;
    for _ in range(6) {
        pm.check_all_health();
    }
    assert `entry.status == ServiceStatus.STARTING , (
        f"boot polls must not change a starting service's status; got {`entry.status}"
    );
    assert pm._failure_counts.get("main", 0) == 0 , (
        f"boot polls banked {pm._failure_counts.get('main')} failures against the "
        "service; the grace only ever deferred the verdict"
    );

    pm.end_boot();
    pm.check_all_health();
    assert `entry.status == ServiceStatus.STARTING , (
        f"one failure after boot is one strike, not {pm._max_failures}; got "
        f"{`entry.status}"
    );
    for _ in range(pm._max_failures - 1) {
        pm.check_all_health();
    }
    assert `entry.status == ServiceStatus.UNHEALTHY , (
        f"{pm._max_failures} consecutive post-boot failures must still count; got "
        f"{`entry.status}"
    );
}

test "starting the health monitor ends boot and forgets boot-time failures" {
    pm = _manager(ServiceStatus.STARTING);
    `entry = pm.registry.entries["main"];
    pm._booting = True;
    pm._failure_counts["main"] = 40;
    pm.start_health_monitor(interval=60.0);
    try {
        assert not pm._booting;
        time.sleep(0.3);
        assert `entry.status == ServiceStatus.STARTING , (
            f"the first monitor tick found banked boot failures; got {`entry.status}"
        );
        assert pm._failure_counts.get("main", 0) <= 1 , (
            "boot-time failures survived into the monitor: "
            f"{pm._failure_counts.get('main')}"
        );
    } finally {
        pm.stop_health_monitor();
    }
}

test "a manager that never booted a fleet still marks a dead service unhealthy" {
    pm = _manager(ServiceStatus.HEALTHY);
    `entry = pm.registry.entries["main"];
    for _ in range(pm._max_failures) {
        pm.check_all_health();
    }
    assert `entry.status == ServiceStatus.UNHEALTHY , (
        "a bare manager is not booting; its health verdicts must stand; got "
        f"{`entry.status}"
    );
}
