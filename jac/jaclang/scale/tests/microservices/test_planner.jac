import from jaclang.scale.runtime.planner.planner { plan_realization }


test "local monolith embeds the gateway and uses in-process everything" {
    plan = plan_realization(False, 1);
    assert plan.environment == "local";
    assert plan.topology == "monolith";
    assert plan.gateway_mode == "embedded";
    assert plan.transport == "in_process";
    assert plan.state_backend == "in_process";
    assert plan.uses_injector == False;
}


test "local microservice fronts with a process gateway over http, no injector" {
    plan = plan_realization(False, 3);
    assert plan.environment == "local";
    assert plan.topology == "microservice";
    assert plan.gateway_mode == "process";
    assert plan.transport == "http";
    assert plan.state_backend == "in_process";
    assert plan.uses_injector == False;
}


test "k8s monolith uses its own gateway pod, redis state, and the injector" {
    plan = plan_realization(True, 1);
    assert plan.environment == "kubernetes";
    assert plan.topology == "monolith";
    assert plan.gateway_mode == "process";
    assert plan.transport == "http";
    assert plan.state_backend == "redis";
    assert plan.uses_injector == True;
}


test "the gateway_embedded flag collapses the gateway for a k8s monolith" {
    plan = plan_realization(True, 1, gateway_embedded=True);
    assert plan.gateway_mode == "embedded";
    assert plan.transport == "in_process";

    assert plan.state_backend == "redis";
}


test "k8s microservice is fully distributed: process gateway, http, redis, injector" {
    plan = plan_realization(True, 5);
    assert plan.environment == "kubernetes";
    assert plan.topology == "microservice";
    assert plan.gateway_mode == "process";
    assert plan.transport == "http";
    assert plan.state_backend == "redis";
    assert plan.uses_injector == True;
}


test "the gateway_embedded flag is ignored for a microservice fleet" {
    plan = plan_realization(True, 4, gateway_embedded=True);
    assert plan.gateway_mode == "process";
    assert plan.transport == "http";
}


test "zero declared services is treated as a monolith" {
    plan = plan_realization(False, 0);
    assert plan.topology == "monolith";
    assert plan.gateway_mode == "embedded";
}
