"""`hpa.min = 0` must be flagged as an error unless the `keda` autoscaler
engine is selected and a real (non-cpu/memory) trigger is configured --
otherwise a workload that can never actually reach zero would be scheduled
to and silently never come up. Drives the real plan validator directly
(same pattern as test_pdb_budget.jac's PlanValidator tests), so no
subprocess or cluster is needed to prove it."""

import from jaclang.scale.runtime.cli.diagnostics { PlanValidator }


glob _CASES: list[tuple[str, dict[str, any], str, bool]] = [
         (
             "keda with a real cron trigger",
             {"min": 0, "triggers": [{"type": "cron"}]},
             "keda",
             False
         ),
         ("keda with no triggers at all", {"min": 0, "triggers": []}, "keda", True),
         (
             "keda with only a cpu trigger",
             {"min": 0, "triggers": [{"type": "cpu"}]},
             "keda",
             True
         ),
         (
             "keda with only a memory trigger",
             {"min": 0, "triggers": [{"type": "memory"}]},
             "keda",
             True
         ),
         (
             "keda with a blank trigger type",
             {"min": 0, "triggers": [{"type": ""}]},
             "keda",
             True
         ),
         (
             "keda with a mixed-case CPU trigger",
             {"min": 0, "triggers": [{"type": "CPU"}]},
             "keda",
             True
         ),
         (
             "keda with a trigger dict missing 'type' entirely",
             {"min": 0, "triggers": [{"metadata": {}}]},
             "keda",
             True
         ),
         (
             "plain hpa engine with a real trigger configured anyway",
             {"min": 0, "triggers": [{"type": "cron"}]},
             "hpa",
             True
         ),
         (
             "plain hpa engine, min=1 is untouched",
             {"min": 1, "triggers": []},
             "hpa",
             False
         )
     ];


test "HPA min=0 is an error unless KEDA has a real, non-resource-only trigger" {
    for (case_name, autoscaler_cfg, engine, expect_error) in _CASES {
        validator = PlanValidator(
            bundle={
                "deployments": {"orders": {"spec": {"replicas": 1}}},
                "scaling": {"orders": {"autoscaler": autoscaler_cfg}}
            },
            routes={"orders": "/orders"},
            svc_configs={"orders": {"hpa": {"min": autoscaler_cfg["min"], "max": 5}}},
            autoscaler_engine=engine
        );
        messages = [
            d.message
            for d in validator.run()
            if d.service == "orders"
        ];
        hits = [
            m
            for m in messages
            if m.startswith("HPA min=")
        ];
        if expect_error {
            assert len(hits) == 1 , f"{case_name}: expected one HPA min=0 error, got {messages}";
        } else {
            assert hits == [] , f"{case_name}: expected no HPA min=0 error, got {messages}";
        }
    }
}
