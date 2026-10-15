"""A PodDisruptionBudget must mean what it says.

Every service got maxUnavailable=1 and every HPA defaults to min=1, so at one
replica the budget permitted evicting the only pod: the eviction API reported
desiredHealthy=0 and a node drain or a consolidation took the service fully
down for its whole boot window. These drive the real manifest builder and the
real plan validator.
"""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    pdb_spec,
    ScalingMode
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.cli.diagnostics { PlanValidator }

import from jaclang.scale.runtime.fleet { fleet_of }


def _bundle(
    services: dict[str, any],
    autoscaler_engine: str = "hpa",
    idle_replicas: (int | None) = None,
    min_replicas: int = 1,
    memory_utilization_target: int = 80
) -> dict[str, any] {
    import tempfile;
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as project {
        for name in list(services.keys()) + ["main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig(
                app_name="shop",
                namespace="shop-ns",
                bundle_storage_class="standard",
                autoscaler_engine=autoscaler_engine,
                idle_replicas=idle_replicas,
                min_replicas=min_replicas,
                memory_utilization_target=memory_utilization_target
            ),
            fleet=fleet_of(
                {name: f"/{name}" for name in services},
                root_app="main",
                overrides=services
            ),
            dry_run=True
        );
        return builder.generate_manifests(
            AppConfig(code_folder=project, app_name="shop"), ""
        );
    }
}


def _pdbs(services: dict[str, any]) -> dict[str, any] {
    return dict(_bundle(services).get("pdbs", {}));
}


test "a budget that permits evicting every replica is not emitted" {
    assert pdb_spec(1, 1, None) is None;
    assert pdb_spec(2, 2, None) is None;
    assert pdb_spec(3, 5, None) is None;
}


test "a budget that leaves a replica standing is emitted as maxUnavailable" {
    assert pdb_spec(3, 1, None) == {"maxUnavailable": 1};
    assert pdb_spec(5, 2, None) == {"maxUnavailable": 2};
}


test "min_available wins and is the shape that holds at one replica" {
    assert pdb_spec(1, 1, 1) == {"minAvailable": 1};
    assert pdb_spec(4, 1, 2) == {"minAvailable": 2};
}


test "a single-replica service gets no budget rather than an empty promise" {
    pdbs = _pdbs({"orders_app": {"replicas": 1, "hpa": {"enabled": False}}});
    assert pdbs.get("orders_app") is None;
}


test "a service with room to lose a pod still gets its budget" {
    pdbs = _pdbs({"orders_app": {"replicas": 3, "hpa": {"enabled": False}}});
    manifest = pdbs.get("orders_app");
    assert manifest is not None;
    assert manifest["spec"]["maxUnavailable"] == 1;
    assert manifest["spec"]["selector"]["matchLabels"]["app"] == "orders-app";
}


test "the floor comes from hpa.min when the autoscaler is on" {
    pdbs = _pdbs({"orders_app": {"replicas": 4, "hpa": {"min": 1}}});
    assert pdbs.get("orders_app") is None , "hpa.min=1 can scale the fleet to one pod";

    pdbs = _pdbs({"orders_app": {"replicas": 1, "hpa": {"min": 3}}});
    assert pdbs.get("orders_app") is not None;
}


test "min_available brings the budget back at one replica" {
    pdbs = _pdbs(
        {
            "orders_app": {
                "replicas": 1,
                "hpa": {"enabled": False},
                "pdb": {"min_available": 1}
            }
        }
    );
    manifest = pdbs.get("orders_app");
    assert manifest is not None;
    assert manifest["spec"]["minAvailable"] == 1;
    assert "maxUnavailable" not in manifest["spec"];
}


test "the plan validator warns about the pair that produces no budget" {
    validator = PlanValidator(
        bundle={"deployments": {"orders_app": {"spec": {"replicas": 1}}}},
        routes={"orders_app": "/orders"},
        svc_configs={
            "orders_app": {"hpa": {"enabled": False}, "pdb": {"max_unavailable": 1}}
        }
    );
    messages = [
        d.message
        for d in validator.run()
        if d.service == "orders_app"
    ];
    hits = [
        m
        for m in messages
        if "permits evicting every replica" in m
    ];
    assert len(hits) == 1 , f"expected one no-budget warning, got {messages}";
}


test "the validator stays quiet when the budget actually holds" {
    validator = PlanValidator(
        bundle={"deployments": {"orders_app": {"spec": {"replicas": 3}}}},
        routes={"orders_app": "/orders"},
        svc_configs={
            "orders_app": {"hpa": {"enabled": False}, "pdb": {"max_unavailable": 1}}
        }
    );
    messages = [
        d.message
        for d in validator.run()
        if d.service == "orders_app"
    ];
    hits = [
        m
        for m in messages
        if "permits evicting every replica" in m
    ];
    assert hits == [];
}


# --- HTTP-activated services: a scale-to-zero target has no meaningful
# replica floor, so the floor-based PDB and the base-autoscaler assumptions
# behind these checks don't apply to it (mirrors _resolve_scaling's own
# decision that HTTP_ACTIVATION and METRIC are mutually exclusive).
test "an HTTP-activated service gets no PDB even with pdb.min_available set" {
    pdbs = _pdbs(
        {
            "billing_ops": {
                "replicas": 1,
                "pdb": {"min_available": 1},
                "http_activation": {
                    "enabled": True,
                    "target_port": 8080,
                    "concurrency_target": 10,
                    "rules": [{"hosts": ["*"]}]
                }
            }
        }
    );
    assert pdbs.get("billing_ops") is None;
}

test "the plan validator skips the HPA and PDB checks for an HTTP_ACTIVATION service" {
    validator = PlanValidator(
        bundle={
            "deployments": {"billing_ops": {"spec": {"replicas": 1}}},
            "scaling": {"billing_ops": {"mode": ScalingMode.HTTP_ACTIVATION}}
        },
        routes={"billing_ops": "/billing-ops"},
        svc_configs={
            "billing_ops": {"hpa": {"min": 5, "max": 1}, "pdb": {"max_unavailable": 1}}
        }
    );
    messages = [
        d.message
        for d in validator.run()
        if d.service == "billing_ops"
    ];
    assert not any("HPA" in m for m in messages) , messages;
    assert not any(
        "PodDisruptionBudget" in m or "pdb." in m for m in messages
    ) , messages;
}


# --- hpa.min = 0 is a supported KEDA scale-to-zero config, but only when a
# real trigger can wake the workload: cpu and memory utilization cannot be
# measured with zero pods, and the plain HPA engine never goes below one. The
# check used to reject every hpa.min < 1, failing --dry-run for a correctly
# configured KEDA service.
test "the plan validator rejects hpa.min below one only when nothing can wake the workload" {
    cron = {"type": "cron", "metadata": {"desiredReplicas": "2"}};
    # Each case sets only what differs from a KEDA service with hpa.min = 0; "check"
    # names the diagnostic a row is about (default: the hpa.min one).
    rows: list[dict[str, any]] = [
        {"label": "keda with a real trigger", "triggers": [cron], "error": False},
        {
            "label": "keda with idle_replicas=0 and a real trigger",
            "idle": 0,
            "triggers": [cron],
            "error": False
        },
        {"label": "keda with no triggers", "triggers": [], "error": True},
        {
            "label": "idle_replicas=0 does not stand in for a trigger",
            "idle": 0,
            "triggers": [],
            "error": True
        },
        {
            "label": "keda with a cpu-only trigger",
            "triggers": [{"type": "cpu"}],
            "error": True
        },
        {
            "label": "keda with a mixed-case CPU trigger",
            "triggers": [{"type": "CPU"}],
            "error": True
        },
        {
            "label": "keda with a blank trigger type",
            "triggers": [{"type": ""}],
            "error": True
        },
        {
            "label": "plain hpa never reaches zero",
            "engine": "hpa",
            "triggers": [cron],
            "error": True
        },
        {
            "label": "keda at the floor of one",
            "hpa": {"min": 1},
            "triggers": [],
            "error": False
        },
        {
            "label": "a fleet-wide min of zero is checked without a per-service override",
            "fleet_min": 0,
            "hpa": {},
            "triggers": [{"type": "cpu"}],
            "error": True
        },
        {
            "label": "a fleet-wide memory target out of range is checked",
            "fleet_memory": 150,
            "hpa": {},
            "triggers": [cron],
            "check": "HPA memory_target=",
            "error": True
        },
        {
            "label": "a fleet-wide memory target in range passes",
            "fleet_memory": 75,
            "hpa": {},
            "triggers": [cron],
            "check": "HPA memory_target=",
            "error": False
        }
    ];
    wrong: list[str] = [];
    for row in rows {
        hpa = row.get("hpa", {"min": 0});
        svc_cfg: dict[str, any] = {"triggers": row["triggers"]};
        if hpa {
            svc_cfg["hpa"] = hpa;
        }
        bundle = _bundle(
            {"orders_app": svc_cfg},
            autoscaler_engine=row.get("engine", "keda"),
            idle_replicas=row.get("idle"),
            min_replicas=row.get("fleet_min", 1),
            memory_utilization_target=row.get("fleet_memory", 80)
        );
        errors = [
            d.message
            for d in PlanValidator(
                bundle=bundle,
                routes={"orders_app": "/orders"},
                svc_configs={"orders_app": svc_cfg}
            ).run()
            if d.service == "orders_app"
                and d.message.startswith(row.get("check", "HPA min="))
        ];
        if bool(errors) != row["error"] {
            wrong.append(
                f"{row['label']}: expected error={row['error']}, got {errors}"
            );
        }
    }
    assert wrong == [] , "\n".join(wrong);
}
