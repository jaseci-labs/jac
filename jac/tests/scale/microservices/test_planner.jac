import from jaclang.scale.runtime.planner.planner { plan_realization }


test "a single local process is planned as a monolith" {
    plan = plan_realization(False, 1);
    assert plan.environment == "local";
    assert plan.topology == "monolith";
}


test "several local processes are planned as a microservice fleet" {
    plan = plan_realization(False, 3);
    assert plan.environment == "local";
    assert plan.topology == "microservice";
}


test "a single kubernetes process is planned as a monolith" {
    plan = plan_realization(True, 1);
    assert plan.environment == "kubernetes";
    assert plan.topology == "monolith";
}


test "several kubernetes processes are planned as a microservice fleet" {
    plan = plan_realization(True, 5);
    assert plan.environment == "kubernetes";
    assert plan.topology == "microservice";
}


test "zero processes is treated as a monolith" {
    plan = plan_realization(False, 0);
    assert plan.topology == "monolith";
}
