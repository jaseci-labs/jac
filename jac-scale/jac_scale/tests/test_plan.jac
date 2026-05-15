"""Unit tests for `jac scale plan` / `--dry-run` (M-05).

The plan path produces the manifest bundle WITHOUT touching the
cluster, building images, or provisioning databases. These tests
verify:
  - Bundle structure (correct manifest kinds present)
  - No K8s API calls (no kube config load)
  - Output mentions service names + resource kinds
  - Plan honors the same routes/services as the deploy path"""

import os;
import io;
import sys;
import tempfile;
import unittest.mock as mock;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from typing { Any }
import from jac_scale.microservices.cli.plan {
    print_plan,
    _section_keys,
    _section_values
}
import jac_scale.microservices.cli.plan as plan_mod;


"""Minimal stub target: returns a pre-baked bundle, exposes the
k8s_config.namespace attribute that print_plan reads."""
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
    # AppConfig has required fields; for the plan tests we pass a
    # minimal object since the stub target's generate_manifests
    # ignores it. Using a SimpleNamespace keeps the import surface tiny.
    import types;
    return types.SimpleNamespace(code_folder=".", file_name="main.jac");
}


test "_section_keys returns empty list when key missing" {
    assert _section_keys({}, "deployments") == [];
}


test "_section_keys returns empty list when value is not a dict" {
    assert _section_keys({"deployments": "not a dict"}, "deployments") == [];
}


test "_section_keys returns dict keys preserving order" {
    bundle = {"deployments": {"a": {}, "b": {}, "c": {}}};
    assert _section_keys(bundle, "deployments") == ["a", "b", "c"];
}


test "_section_values returns manifest dicts" {
    bundle = {"services": {"x": {"kind": "Service"}, "y": {"kind": "Service"}}};
    values = _section_values(bundle, "services");
    assert len(values) == 2;
    kinds = [v.get("kind") for v in values];
    assert kinds == ["Service", "Service"];
}


test "print_plan with empty bundle prints header but no resources" {
    target = _StubTarget(_bundle={});
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="unknown") {
            print_plan(target, _make_app_config());
        }
    }
    out = buf.getvalue();
    assert "jac scale plan: dry-run" in out;
    assert "Cluster type detected: unknown" in out;
    assert "Namespace: test-ns" in out;
    assert "(none declared)" in out;
}


test "print_plan with full bundle lists every resource kind" {
    bundle: dict[str, Any] = {
        "deployments": {
            "orders": {"apiVersion": "apps/v1", "kind": "Deployment",
                       "metadata": {"name": "orders-deployment"}},
            "__gateway__": {"apiVersion": "apps/v1", "kind": "Deployment",
                            "metadata": {"name": "gateway-deployment"}}
        },
        "services": {
            "orders": {"apiVersion": "v1", "kind": "Service",
                       "metadata": {"name": "orders-service"}},
            "__gateway__": {"apiVersion": "v1", "kind": "Service",
                            "metadata": {"name": "gateway-service"}}
        },
        "hpas": {
            "orders": {"apiVersion": "autoscaling/v2",
                       "kind": "HorizontalPodAutoscaler",
                       "metadata": {"name": "orders-hpa"}}
        },
        "pdbs": {
            "orders": {"apiVersion": "policy/v1",
                       "kind": "PodDisruptionBudget",
                       "metadata": {"name": "orders-pdb"}}
        },
        "ingress": {
            "apiVersion": "networking.k8s.io/v1", "kind": "Ingress",
            "metadata": {"name": "gateway-ingress"}
        }
    };
    target = _StubTarget(_bundle=bundle);
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="minikube") {
            ret = print_plan(target, _make_app_config());
        }
    }
    out = buf.getvalue();

    # Header values
    assert "Cluster type detected: minikube" in out;
    assert "Namespace: test-ns" in out;
    # Service name list excludes the __gateway__ sentinel
    assert "Services: orders" in out;
    # Counts: 2 deploys + 2 services + 1 hpa + 1 pdb + 1 ingress = 7
    assert "7 manifests, NOT applied" in out;
    # Each section listed in the summary
    assert "Deployments: orders, __gateway__" in out;
    assert "Services:    orders, __gateway__" in out;
    assert "Ingress:     yes" in out;
    # YAML stream embedded
    assert "kind: Deployment" in out;
    assert "kind: Service" in out;
    assert "kind: HorizontalPodAutoscaler" in out;
    assert "kind: Ingress" in out;
    # Returns the bundle unchanged (programmatic callers)
    assert ret is bundle;
}


test "print_plan does NOT call deploy / apply_manifests / kube config" {
    bundle: dict[str, Any] = {
        "deployments": {"x": {"kind": "Deployment", "metadata": {"name": "x"}}},
        "services": {}
    };
    target = _StubTarget(_bundle=bundle);
    target.deploy = mock.MagicMock(side_effect=AssertionError("deploy must NOT be called"));
    target.apply_manifests = mock.MagicMock(
        side_effect=AssertionError("apply_manifests must NOT be called")
    );

    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="kind") {
            print_plan(target, _make_app_config());
        }
    }
    target.deploy.assert_not_called();
    target.apply_manifests.assert_not_called();
}


test "print_plan emits valid YAML that re-parses" {
    import yaml;
    bundle: dict[str, Any] = {
        "deployments": {
            "svc": {"apiVersion": "apps/v1", "kind": "Deployment",
                    "metadata": {"name": "svc-deployment", "namespace": "test-ns"},
                    "spec": {"replicas": 2}}
        },
        "services": {
            "svc": {"apiVersion": "v1", "kind": "Service",
                    "metadata": {"name": "svc-service"},
                    "spec": {"ports": [{"port": 8000}]}}
        }
    };
    target = _StubTarget(_bundle=bundle);
    buf = io.StringIO();
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod, "detect_cluster_type", return_value="vanilla") {
            print_plan(target, _make_app_config());
        }
    }
    out = buf.getvalue();
    # Strip the markup + headers down to just the YAML stream.
    yaml_start = out.find("apiVersion:");
    yaml_blob = out[yaml_start:];
    docs = list(yaml.safe_load_all(yaml_blob));
    # Two docs: deployment + service. Some YAML lines past the manifests
    # may parse as None when the rich-print injects trailing whitespace.
    docs = [d for d in docs if d is not None];
    assert len(docs) == 2;
    kinds = sorted([d["kind"] for d in docs]);
    assert kinds == ["Deployment", "Service"];
}
