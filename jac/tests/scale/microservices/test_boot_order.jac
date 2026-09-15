"""The service that compiles the client boots alone, and first.

A module another service analyzed first reaches the client backend with its
calls unresolved, so the client-serving service has to finish before its peers
touch the analysis cache. Everything else still starts in parallel, and a
fleet with no client keeps the plain parallel boot.
"""

import subprocess;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry,
    ServiceStatus
}
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }


def _registry(client_owner: str = "") -> ServiceRegistry {
    reg = ServiceRegistry();
    for name in ["scoring", "social", "main"] {
        reg.register(
            ServiceEntry(
                name=name,
                file=f"{name}.jac",
                prefix=f"/{name}",
                serves_client=(name == client_owner)
            )
        );
    }
    return reg;
}


test "the client-serving service leads the boot order" {
    pm = ServiceProcessManager(registry=_registry("main"));
    assert pm._boot_order()[0] == "main" , (
        f"the service that compiles the client goes first; got {pm._boot_order()}"
    );
    assert sorted(pm._boot_order()) == ["main", "scoring", "social"] , (
        "leading a service must not drop the rest"
    );
}


test "a fleet with no client keeps its registration order" {
    pm = ServiceProcessManager(registry=_registry());
    assert pm._boot_order() == ["scoring", "social", "main"] , (
        f"nothing compiles a client here, so nothing needs to go first; got "
        f"{pm._boot_order()}"
    );
}


test "waiting on the lead is skipped when it never started" {
    pm = ServiceProcessManager(registry=_registry("main"));
    pm._await_lead("main");
    assert pm.registry.entries["main"].status == ServiceStatus.REGISTERED , (
        "with no process and no url there is nothing to wait for"
    );
}


test "a lead that exits during startup is reported, not waited out" {
    pm = ServiceProcessManager(registry=_registry("main"), app_boot_timeout=5.0);
    `entry = pm.registry.entries["main"];
    `entry.port = 1;
    `entry.url = "http://127.0.0.1:1";
    dead = subprocess.Popen(["true"]);
    dead.`wait();
    pm.processes["main"] = dead;

    pm._await_lead("main");
    assert `entry.status == ServiceStatus.STOPPED , (
        f"a lead that died cannot become healthy, and the fleet must not sit "
        f"on the full app_boot_timeout for it; got {`entry.status}"
    );
    assert `entry.pid is None;
}


test "each service gets a port of its own, peers included" {
    pm = ServiceProcessManager(registry=_registry("main"));
    for (_name, svc) in pm.registry.entries.items() {
        pm._prepare_ports(svc);
    }
    ports: list[int] = [];
    for (_name, svc) in pm.registry.entries.items() {
        ports.append(svc.port);
        if svc.page_port > 0 {
            ports.append(svc.page_port);
        }
    }
    assert len(ports) == len(set(ports)) , (
        f"two services sharing a port is a boot race; got {ports}"
    );
}
