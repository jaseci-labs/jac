"""Unit tests for `jac scale plan` / `--dry-run` (M-05).

Covers the plan-only path (no cluster contact, no image build, no DB
provisioning):
  - Card-view renders per-service fields (image, replicas, resources)
  - HPA / PDB inline qualifiers on the card
  - --show-yaml gate (default off, raw YAML hidden)
  - Diagnostics inline + exit-code-via-has_errors
  - Quantity parsers (CPU millicores, memory bytes)
  - PlanValidator check catalog (one test per check)"""

import io;
import unittest.mock as mock;
import from contextlib { redirect_stdout }
import from typing { Any }
import from jac_scale.microservices.cli.plan { print_plan }
import from jac_scale.microservices.cli.diagnostics {
    Diagnostic,
    PlanValidator,
    has_errors,
    _cpu_to_millicores,
    _mem_to_bytes
}
import jac_scale.microservices.cli.plan as plan_mod;
import jac_scale.microservices.cli.diagnostics as diag_mod;


def _validate(bundle: dict, ms_cfg: dict, svc_configs: dict) -> list {
    return PlanValidator(bundle=bundle, ms_cfg=ms_cfg, svc_configs=svc_configs).run();
}


# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------
obj _StubConfig {
    has namespace: str = "test-ns";
}


obj _StubTarget {
    has _bundle: dict[str, Any] = {},
        k8s_config: _StubConfig by postinit;

    def postinit {
        self.k8s_config = _StubConfig();
    }

    def generate_manifests(app_config: Any) -> dict[str, Any] {
        return self._bundle;
    }
}


def _make_app_config -> Any {
    import types;
    return types.SimpleNamespace(code_folder=".", file_name="main.jac");
}


"""Minimal Deployment manifest with given image and optional resources."""
def _dep(
    image: str | None = "a:v1", requests: dict | None = None, limits: dict | None = None
) -> dict {
    container: dict = {};
    if image is not None {
        container["image"] = image;
    }
    if requests or limits {
        resources: dict = {};
        if requests {
            resources["requests"] = requests;
        }
        if limits {
            resources["limits"] = limits;
        }
        container["resources"] = resources;
    }
    return {"spec": {"template": {"spec": {"containers": [container]}}}};
}


"""Run print_plan against a stub target and an empty ms_cfg. Returns
(stdout_text, diagnostics)."""
def _run_plan(bundle: dict[str, Any], show_yaml: bool = False) -> tuple {
    target = _StubTarget(_bundle=bundle);
    buf = io.StringIO();
    diagnostics: list = [];
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=({}, {})
            ) {
                (_, diagnostics) = print_plan(
                    target, _make_app_config(), show_yaml=show_yaml
                );
            }
        }
    }
    return (buf.getvalue(), diagnostics);
}


# ---------------------------------------------------------------------------
# Quantity parsers
# ---------------------------------------------------------------------------
test "cpu parser: '500m' -> 500 millicores" {
    assert _cpu_to_millicores("500m") == 500;
}


test "cpu parser: '1' -> 1000 millicores" {
    assert _cpu_to_millicores("1") == 1000;
}


test "cpu parser: '2.5' -> 2500 millicores" {
    assert _cpu_to_millicores("2.5") == 2500;
}


test "cpu parser: None and garbage return None" {
    assert _cpu_to_millicores(None) is None;
    assert _cpu_to_millicores("garbage") is None;
    assert _cpu_to_millicores("") is None;
}


test "mem parser: '128Mi' -> 128 * 1024**2" {
    assert _mem_to_bytes("128Mi") == 128 * 1024 ** 2;
}


test "mem parser: '1Gi' -> 1024**3" {
    assert _mem_to_bytes("1Gi") == 1024 ** 3;
}


test "mem parser: '500M' -> 500 * 1000**2 (decimal, not binary)" {
    assert _mem_to_bytes("500M") == 500 * 1000 ** 2;
}


test "mem parser: bare int -> raw bytes" {
    assert _mem_to_bytes("12345") == 12345;
}


test "mem parser: None and bad units return None" {
    assert _mem_to_bytes(None) is None;
    assert _mem_to_bytes("500MB") is None;  # 'MB' not a valid k8s suffix
    assert _mem_to_bytes("") is None;
}


# ---------------------------------------------------------------------------
# print_plan: card view
# ---------------------------------------------------------------------------
test "print_plan with empty bundle: header + no-services hint" {
    (out, _) = _run_plan({});
    assert "jac scale plan: dry-run" in out;
    assert "Cluster:" in out;
    assert "Namespace:" in out and "test-ns" in out;
    assert "no microservices declared" in out;
}


test "print_plan card shows image, replicas, cpu/mem" {
    bundle: dict[str, Any] = {
        "deployments": {
            "orders": {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "metadata": {"name": "orders-deployment"},
                "spec": {
                    "replicas": 3,
                    "template": {
                        "spec": {
                            "containers": [
                                {
                                    "name": "orders",
                                    "image": "registry/orders:v1.2",
                                    "resources": {
                                        "requests": {"cpu": "200m", "memory": "256Mi"},
                                        "limits": {"cpu": "1", "memory": "512Mi"}
                                    },
                                    "ports": [{"containerPort": 8080}]
                                }
                            ]
                        }
                    }
                }
            }
        },
        "services": {
            "orders": {"kind": "Service", "metadata": {"name": "orders-service"}}
        }
    };
    (out, _) = _run_plan(bundle);
    assert "orders" in out;
    assert "registry/orders:v1.2" in out;
    assert "replicas:  3" in out;
    assert "200m -> 1" in out;  # cpu request -> limit
    assert "256Mi -> 512Mi" in out;  # mem request -> limit
    assert "port:      8080" in out;
}


test "print_plan HPA inline: shows min -> max @ cpu%" {
    bundle: dict[str, Any] = {
        "deployments": {
            "api": {
                "spec": {
                    "replicas": 2,
                    "template": {"spec": {"containers": [{"image": "api:v1"}]}}
                }
            }
        },
        "services": {"api": {}},
        "hpas": {
            "api": {
                "kind": "HorizontalPodAutoscaler",
                "spec": {
                    "minReplicas": 2,
                    "maxReplicas": 10,
                    "metrics": [
                        {
                            "type": "Resource",
                            "resource": {
                                "name": "cpu",
                                "target": {
                                    "type": "Utilization",
                                    "averageUtilization": 75
                                }
                            }
                        }
                    ]
                }
            }
        }
    };
    (out, _) = _run_plan(bundle);
    assert "HPA: 2 -> 10 @ 75% CPU" in out;
}


test "print_plan PDB inline: shows maxUnavailable on the card" {
    bundle: dict[str, Any] = {
        "deployments": {
            "api": {
                "spec": {"template": {"spec": {"containers": [{"image": "api:v1"}]}}}
            }
        },
        "services": {"api": {}},
        "pdbs": {"api": {"spec": {"maxUnavailable": 2}}}
    };
    (out, _) = _run_plan(bundle);
    assert "maxUnavailable=2" in out;
}


test "print_plan totals: counts every section + 'no errors'" {
    bundle: dict[str, Any] = {
        "deployments": {"a": {}, "b": {}, "__gateway__": {}},
        "services": {"a": {}, "b": {}, "__gateway__": {}},
        "hpas": {"a": {}},
        "pdbs": {"a": {}, "b": {}}
    };
    (out, _) = _run_plan(bundle);
    assert "3 deployments" in out;
    assert "3 services" in out;
    assert "1 HPA" in out;
    assert "2 PDBs" in out;
    # No diagnostics from an empty ms_cfg, so green-path status line shows.
    assert "no errors or warnings" in out;
}


test "print_plan does NOT show raw YAML by default" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {"kind": "Deployment", "metadata": {"name": "a-deployment"}}
        }
    };
    (out, _) = _run_plan(bundle, show_yaml=False);
    assert "kind: Deployment" not in out;
    assert "--show-yaml" in out;  # hint visible
}


test "print_plan with --show-yaml: dumps the YAML stream" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "metadata": {"name": "a-deployment"},
                "spec": {"replicas": 1}
            }
        }
    };
    (out, _) = _run_plan(bundle, show_yaml=True);
    assert "--- YAML (would be applied) ---" in out;
    assert "kind: Deployment" in out;
    assert "name: a-deployment" in out;
}


test "print_plan does NOT call deploy / apply_manifests" {
    target = _StubTarget(_bundle={"deployments": {"x": {}}, "services": {}});
    target.deploy = mock.MagicMock(
        side_effect=AssertionError("deploy must NOT be called")
    );
    target.apply_manifests = mock.MagicMock(
        side_effect=AssertionError("apply_manifests must NOT be called")
    );
    with redirect_stdout(io.StringIO()) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=({}, {})
            ) {
                print_plan(target, _make_app_config());
            }
        }
    }
    target.deploy.assert_not_called();
    target.apply_manifests.assert_not_called();
}


# ---------------------------------------------------------------------------
# PlanValidator: error/warn catalog (one test per check)
# ---------------------------------------------------------------------------
test "validate: reserved name __gateway__ as a microservice is an error" {
    ms_cfg = {"routes": {"__gateway__": "/whatever"}};
    diags = _validate({"deployments": {}}, ms_cfg, {});
    assert any(d.severity == "error" and "reserved" in d.message for d in diags);
}


test "validate: duplicate route path is an error" {
    ms_cfg = {"routes": {"a": "/api", "b": "/api"}};
    diags = _validate({"deployments": {}}, ms_cfg, {});
    assert any(d.severity == "error" and "claimed by both" in d.message for d in diags);
}


test "validate: HPA min > max is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    svc_configs = {"a": {"hpa": {"min": 5, "max": 2}, "cpu_request": "100m"}};
    diags = _validate({"deployments": {"a": {}}}, ms_cfg, svc_configs);
    assert any(
        d.severity == "error"
        and d.service == "a"
        and "min" in d.message
        and "max" in d.message for d in diags
    );
}


test "validate: HPA cpu_target out of range is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    svc_configs = {"a": {"hpa": {"cpu_target": 150}, "cpu_request": "100m"}};
    diags = _validate({"deployments": {"a": {}}}, ms_cfg, svc_configs);
    assert any(d.severity == "error" and "cpu_target=150" in d.message for d in diags);
}


test "validate: HPA enabled but no cpu_request is a warning" {
    ms_cfg = {"routes": {"a": "/a"}};
    svc_configs = {"a": {"hpa": {"min": 2, "max": 5, "cpu_target": 70}}};
    diags = _validate({"deployments": {"a": {}}}, ms_cfg, svc_configs);
    assert any(
        d.severity == "warn" and "cpu_request is unset" in d.message for d in diags
    );
}


test "validate: PDB max_unavailable=0 with replicas=1 is a drain-deadlock warning" {
    ms_cfg = {"routes": {"a": "/a"}};
    svc_configs = {
        "a": {"pdb": {"enabled": True, "max_unavailable": 0}, "cpu_request": "100m"}
    };
    dep = _dep(requests={"cpu": "100m"});
    dep["spec"]["replicas"] = 1;
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, svc_configs);
    assert any(
        d.severity == "warn" and "drains will block" in d.message for d in diags
    );
}


test "validate: PDB max_unavailable=1 with replicas=1 is NOT a warning (regression: false positive on default config)" {
    ms_cfg = {"routes": {"a": "/a"}};
    svc_configs = {
        "a": {
            "pdb": {"enabled": True, "max_unavailable": 1},
            "hpa": {"enabled": False},
            "cpu_request": "100m"
        }
    };
    dep = _dep(requests={"cpu": "100m"});
    dep["spec"]["replicas"] = 1;
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, svc_configs);
    assert not any(
        d.severity == "warn" and "drains will block" in d.message for d in diags
    );
}


test "validate: cpu_request > cpu_limit is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    dep = _dep(requests={"cpu": "2"}, limits={"cpu": "500m"});
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, {});
    assert any(
        d.severity == "error"
        and "cpu_request" in d.message
        and "cpu_limit" in d.message for d in diags
    );
}


test "validate: memory_request > memory_limit is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    dep = _dep(requests={"memory": "1Gi"}, limits={"memory": "256Mi"});
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, {});
    assert any(d.severity == "error" and "memory_request" in d.message for d in diags);
}


test "validate: invalid CPU unit '500MB' is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    dep = _dep(requests={"cpu": "500MB"});
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, {});
    assert any(
        d.severity == "error" and "not a valid Kubernetes CPU quantity" in d.message
        for d in diags
    );
}


test "validate: no resource limits at all is a warning" {
    ms_cfg = {"routes": {"a": "/a"}};
    dep = _dep(requests={"cpu": "100m"});
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, {});
    assert any(d.severity == "warn" and "OOM-killed" in d.message for d in diags);
}


test "validate: deployment with no container image is an error" {
    ms_cfg = {"routes": {"a": "/a"}};
    dep = {"spec": {"template": {"spec": {"containers": [{"name": "a"}]}}}};
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, {});
    assert any(
        d.severity == "error" and "no image resolved" in d.message for d in diags
    );
}


test "validate: clean config returns no diagnostics" {
    ms_cfg = {"routes": {"a": "/api"}};
    svc_configs = {
        "a": {"hpa": {"min": 2, "max": 10, "cpu_target": 70}, "pdb": {"enabled": True}}
    };
    dep = _dep(
        image="a:v1",
        requests={"cpu": "100m", "memory": "128Mi"},
        limits={"cpu": "500m", "memory": "256Mi"}
    );
    diags = _validate({"deployments": {"a": dep}}, ms_cfg, svc_configs);
    assert diags == [];
}


test "has_errors: True iff any diagnostic has severity='error'" {
    assert has_errors([]) is False;
    assert has_errors([Diagnostic(severity="warn", message="x")]) is False;
    assert has_errors(
        [
            Diagnostic(severity="warn", message="x"),
            Diagnostic(severity="error", message="y")
        ]
    ) is True;
}


# ---------------------------------------------------------------------------
# Diagnostics integration: errors flow into print_plan output + exit code
# ---------------------------------------------------------------------------
test "validate: route with no generated Deployment is an error (skips downstream checks)" {
    ms_cfg = {"routes": {"a": "/a"}};
    diags = _validate({"deployments": {}}, ms_cfg, {"a": {"cpu_request": "100m"}});
    # Exactly one error: the missing-deployment one. Downstream checks
    # (HPA cpu_request baseline, no image, etc.) must NOT chain on None.
    assert any(d.severity == "error" and "no generated Deployment" in d.message for d in diags);
    assert not any("cpu_request is unset" in d.message for d in diags);
    assert not any("no image resolved" in d.message for d in diags);
}


test "print_plan HPA card: cpu_target=0 renders as '(no CPU target)' not '0% CPU'" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {"spec": {"template": {"spec": {"containers": [{"image": "a:v1"}]}}}}
        },
        "hpas": {
            "a": {
                "spec": {
                    "minReplicas": 1,
                    "maxReplicas": 3,
                    # No Resource:cpu metric -> HPAView.cpu_target stays 0
                    "metrics": []
                }
            }
        }
    };
    (out, _) = _run_plan(bundle);
    assert "(no CPU target)" in out;
    assert "0% CPU" not in out;
}


test "ingress card: host + paths rendered, no diagnostics" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {"spec": {"template": {"spec": {"containers": [{"image": "a:v1"}]}}}}
        },
        "ingress": {
            "spec": {"rules": [{"host": "shop.example.com", "http": {"paths": []}}]}
        }
    };
    target = _StubTarget(_bundle=bundle);
    fake_ms = ({"routes": {"a": "/api/a"}}, {});
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=fake_ms
            ) {
                print_plan(target, _make_app_config());
            }
        }
    }
    out = buf.getvalue();
    assert "Ingress" in out;
    assert "shop.example.com" in out;
    assert "/api/a" in out;
    assert "gateway" in out;  # the / -> gateway tail entry
}


test "cluster-wide card: rate_limit + cors + user_secret all render" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {"spec": {"template": {"spec": {"containers": [{"image": "a:v1"}]}}}}
        },
        "user_secret": {
            "metadata": {"name": "app-secrets"},
            "data": {"k1": "...", "k2": "...", "k3": "..."}
        }
    };
    target = _StubTarget(_bundle=bundle);
    fake_ms = (
        {
            "routes": {"a": "/api/a"},
            "rate_limit": {"enabled": True, "requests_per_minute": 120},
            "cors": {"enabled": True, "allow_origins": ["https://app.example.com"]}
        },
        {}
    );
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=fake_ms
            ) {
                print_plan(target, _make_app_config());
            }
        }
    }
    out = buf.getvalue();
    assert "Cluster-wide" in out;
    assert "120/min per IP" in out;
    assert "https://app.example.com" in out;
    assert "app-secrets" in out and "3 keys" in out;
}


test "print_plan shows error count in summary and inline on card" {
    # Inject a fake ms_cfg with a broken HPA so the validator fires.
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {"spec": {"template": {"spec": {"containers": [{"image": "a:v1"}]}}}}
        },
        "services": {"a": {}}
    };
    target = _StubTarget(_bundle=bundle);
    fake_ms = ({"routes": {"a": "/a"}}, {"a": {"hpa": {"min": 5, "max": 2}}});
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=fake_ms
            ) {
                (_, diagnostics) = print_plan(target, _make_app_config());
            }
        }
    }
    out = buf.getvalue();
    assert has_errors(diagnostics) is True;
    assert "error" in out.lower();
    # Inline diagnostic on the service card mentions the failing constraint.
    assert "min" in out and "max" in out;
}
