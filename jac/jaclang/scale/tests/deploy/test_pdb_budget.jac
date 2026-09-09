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


def _pdbs(services: dict) -> dict {
    import tempfile;
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as project {
        for name in list(services.keys()) + ["main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig(
                app_name="shop", namespace="shop-ns", bundle_storage_class="standard"
            ),
            fleet=fleet_of(
                {name: f"/{name}" for name in services},
                root_app="main",
                overrides=services
            ),
            dry_run=True
        );
        bundle = builder.generate_manifests(
            AppConfig(code_folder=project, app_name="shop"), ""
        );
        return dict(bundle.get("pdbs", {}));
    }
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
