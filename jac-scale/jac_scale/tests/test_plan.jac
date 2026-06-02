"""Unit tests for `jac scale plan` / `--dry-run` (M-05).

Scope - only the contracts that broke (or could break) in production:
  - Validator catalog: one test per check (every check represents a
    real config-bug class)
  - CLI contracts: --show-yaml gate, dry-run touches nothing
  - Quantity parsers: K8s suffix correctness
  - Rendering smoke: full bundle renders all sections (refactor guard)

Cosmetic per-field render asserts were dropped in the post-review
cleanup - if a section disappears the smoke test catches it; if a
field formats wrong the user will see it the same second a developer
would. Per-field tests were boilerplate without bug-catching value."""

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


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
def _validate(bundle: dict, ms_cfg: dict, svc_configs: dict) -> list {
    return PlanValidator(bundle=bundle, ms_cfg=ms_cfg, svc_configs=svc_configs).run();
}


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


"""Run print_plan with stubbed cluster_type + _load_ms_cfg. Returns
(stdout, diagnostics). Optional `ms_cfg` overrides empty default."""
def _run_plan(
    bundle: dict[str, Any], show_yaml: bool = False, ms_cfg_pair: tuple | None = None
) -> tuple {
    target = _StubTarget(_bundle=bundle);
    buf = io.StringIO();
    diagnostics: list = [];
    cfg_pair = ms_cfg_pair if ms_cfg_pair is not None else ({}, {});
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            with mock.patch.object(
                plan_mod.Plan, "_load_ms_cfg", return_value=cfg_pair
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
# Quantity parsers - K8s suffix correctness matters because mis-parsing
# silently rounds to a default and the OOM-killer hits in production.
# ---------------------------------------------------------------------------
test "cpu parser: valid millicore + core forms, invalid -> None" {
    assert _cpu_to_millicores("500m") == 500;
    assert _cpu_to_millicores("1") == 1000;
    assert _cpu_to_millicores("2.5") == 2500;
    assert _cpu_to_millicores(None) is None;
    assert _cpu_to_millicores("garbage") is None;
}


test "mem parser: Mi/Gi binary, M decimal, bare int; rejects 'MB' and garbage" {
    assert _mem_to_bytes("128Mi") == 128 * 1024 ** 2;
    assert _mem_to_bytes("1Gi") == 1024 ** 3;
    assert _mem_to_bytes("500M") == 500 * 1000 ** 2;
    assert _mem_to_bytes("12345") == 12345;
    assert _mem_to_bytes("500MB") is None;
    assert _mem_to_bytes(None) is None;
}


# ---------------------------------------------------------------------------
# CLI contracts - the dry-run promise: touches nothing, --show-yaml gates raw.
# ---------------------------------------------------------------------------
test "dry-run contract: print_plan must NOT call deploy / apply_manifests" {
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


test "--show-yaml gate: YAML hidden by default, dumped on opt-in" {
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
    (off, _) = _run_plan(bundle, show_yaml=False);
    assert "kind: Deployment" not in off;
    assert "--show-yaml" in off;
    (on, _) = _run_plan(bundle, show_yaml=True);
    assert "--- YAML (would be applied) ---" in on;
    assert "kind: Deployment" in on;
}


# ---------------------------------------------------------------------------
# Render smoke - one realistic bundle exercises every section. If a section
# silently disappears in a refactor, this catches it.
# ---------------------------------------------------------------------------
test "render smoke: realistic bundle prints every section" {
    bundle: dict[str, Any] = {
        "deployments": {
            "api": _dep(
                image="api:v1", requests={"cpu": "100m"}, limits={"cpu": "500m"}
            ),
            "__gateway__": _dep(image="gateway:v1")
        },
        "services": {"api": {}, "__gateway__": {}},
        "autoscalers": {"api": {"min": 2, "max": 10, "cpu_target": 70}},
        "pdbs": {"api": {"spec": {"maxUnavailable": 1}}},
        "ingress": {
            "spec": {"rules": [{"host": "shop.example.com", "http": {"paths": []}}]}
        },
        "user_secret": {
            "metadata": {"name": "app-secrets"},
            "data": {"k1": "...", "k2": "..."}
        }
    };
    ms_cfg = (
        {
            "routes": {"api": "/api"},
            "rate_limit": {"enabled": True, "requests_per_minute": 120}
        },
        {}
    );
    (out, _) = _run_plan(bundle, ms_cfg_pair=ms_cfg);
    assert "jac scale plan: dry-run" in out;
    assert "Microservices" in out;
    assert "api" in out;
    assert "HPA: 2 -> 10 @ 70% CPU" in out;
    assert "maxUnavailable=1" in out;
    assert "Ingress" in out and "shop.example.com" in out;
    assert "Cluster-wide" in out and "120/min" in out;
    assert "app-secrets" in out and "2 keys" in out;
    assert "Totals" in out;
}


# ---------------------------------------------------------------------------
# Validator catalog - one test per check. Each represents a real config-bug
# class that either breaks at kube-apiserver apply time or, worse, applies
# silently and breaks in production.
# ---------------------------------------------------------------------------
test "validate: reserved name __gateway__ as a microservice -> error" {
    diags = _validate({"deployments": {}}, {"routes": {"__gateway__": "/x"}}, {});
    assert any(d.severity == "error" and "reserved" in d.message for d in diags);
}


test "validate: duplicate route paths -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(), "b": _dep()}},
        {"routes": {"a": "/api", "b": "/api"}},
        {}
    );
    assert any(d.severity == "error" and "claimed by both" in d.message for d in diags);
}


test "validate: HPA bounds (min < 1, min > max, cpu_target out of 1-100)" {
    cfgs = {
        "a": {"hpa": {"min": 5, "max": 2, "cpu_target": 150}, "cpu_request": "100m"}
    };
    diags = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "100m"})}},
        {"routes": {"a": "/a"}},
        cfgs
    );
    msgs = [
        d.message
        for d in diags
        if d.severity == "error"
    ];
    assert any("min (5) > max (2)" in m for m in msgs);
    assert any("cpu_target=150" in m for m in msgs);
}


test "validate: HPA enabled with no cpu_request -> warning" {
    diags = _validate(
        {"deployments": {"a": _dep()}},
        {"routes": {"a": "/a"}},
        {"a": {"hpa": {"min": 2, "max": 5, "cpu_target": 70}}}
    );
    assert any(
        d.severity == "warn" and "cpu_request is unset" in d.message for d in diags
    );
}


test "validate: PDB drain-deadlock (max_unavailable=0 + replicas=1) -> warning, no false positive on default" {
    # The bug: warning fires on max_unavailable=0 + replicas=1 (real deadlock).
    # The regression: must NOT fire on jac-scale's default max_unavailable=1.
    dep = _dep(requests={"cpu": "100m"});
    dep["spec"]["replicas"] = 1;
    deadlock = _validate(
        {"deployments": {"a": dep}},
        {"routes": {"a": "/a"}},
        {"a": {"pdb": {"enabled": True, "max_unavailable": 0}, "cpu_request": "100m"}}
    );
    assert any(
        d.severity == "warn" and "drains will block" in d.message for d in deadlock
    );
    default_ok = _validate(
        {"deployments": {"a": dep}},
        {"routes": {"a": "/a"}},
        {
            "a": {
                "pdb": {"enabled": True, "max_unavailable": 1},
                "hpa": {"enabled": False},
                "cpu_request": "100m"
            }
        }
    );
    assert not any(
        d.severity == "warn" and "drains will block" in d.message for d in default_ok
    );
}


test "validate: request > limit (cpu and memory) -> error" {
    diags_cpu = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "2"}, limits={"cpu": "500m"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error"
        and "cpu_request" in d.message
        and "cpu_limit" in d.message for d in diags_cpu
    );
    diags_mem = _validate(
        {
            "deployments": {
                "a": _dep(requests={"memory": "1Gi"}, limits={"memory": "256Mi"})
            }
        },
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error" and "memory_request" in d.message for d in diags_mem
    );
}


test "validate: invalid Kubernetes resource quantity ('500MB' not 'Mi') -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(requests={"memory": "500MB"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error"
        and "memory_request" in d.message
        and "not a valid" in d.message for d in diags
    );
}


test "validate: no cpu_limit AND no memory_limit -> BestEffort warning" {
    diags = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "100m"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(d.severity == "warn" and "BestEffort" in d.message for d in diags);
}


test "validate: deployment with no container image -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(image=None)}},
        {"routes": {"a": "/a"}},
        {"a": {"cpu_request": "100m", "cpu_limit": "500m"}}
    );
    assert any(
        d.severity == "error" and "no image resolved" in d.message for d in diags
    );
}


test "validate: route declared with no generated Deployment -> error + skips downstream checks" {
    diags = _validate(
        {"deployments": {}}, {"routes": {"a": "/a"}}, {"a": {"cpu_request": "100m"}}
    );
    assert any(
        d.severity == "error" and "no generated Deployment" in d.message for d in diags
    );
    # Downstream checks (HPA cpu baseline, image) MUST NOT chain on None
    assert not any("cpu_request is unset" in d.message for d in diags);
    assert not any("no image resolved" in d.message for d in diags);
}


test "validate: clean config returns no diagnostics (regression guard)" {
    diags = _validate(
        {
            "deployments": {
                "a": _dep(
                    requests={"cpu": "100m", "memory": "128Mi"},
                    limits={"cpu": "500m", "memory": "256Mi"}
                )
            }
        },
        {"routes": {"a": "/a"}},
        {
            "a": {
                "hpa": {"min": 2, "max": 10, "cpu_target": 70},
                "pdb": {"enabled": True, "max_unavailable": 1},
                "cpu_request": "100m",
                "cpu_limit": "500m",
                "memory_request": "128Mi",
                "memory_limit": "256Mi"
            }
        }
    );
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
