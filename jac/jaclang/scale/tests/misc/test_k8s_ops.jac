"""Direct tests for admin/k8s_ops helpers.

These helpers are normally reached only transitively through the network /
deploy-health / podenv admin impls, where k8s is unavailable and every branch
collapses to a stub. Here we drive the real functions directly: real
kubernetes ApiException objects for the error-detail mapping, real env-var
resolution for namespace / availability, and a mocked config-loader boundary
(the one genuine external call) for the _ensure_config branching.
"""

import os;
import from unittest.mock { patch, MagicMock }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.admin { k8s_ops }


test "api_error_detail maps 403 to actionable RBAC guidance" {
    detail = k8s_ops.api_error_detail(ApiException(status=403, reason="Forbidden"));
    assert detail.startswith("RBAC denied (403).");
    assert "ops_console = true" in detail;
    assert "ServiceAccount" in detail;
}


test "api_error_detail formats non-403 status with extracted reason" {
    not_found = k8s_ops.api_error_detail(ApiException(status=404, reason="Not Found"));
    assert not_found == "Kubernetes API error 404 Not Found";

    server_err = k8s_ops.api_error_detail(
        ApiException(status=500, reason="Internal Server Error")
    );
    assert server_err == "Kubernetes API error 500 Internal Server Error";

    # reason missing -> the trailing space is stripped, no "None" leaks in
    no_reason = k8s_ops.api_error_detail(ApiException(status=500));
    assert no_reason == "Kubernetes API error 500";
}


test "api_error_detail falls back to str(e) when status is absent" {
    err = ApiException();
    detail = k8s_ops.api_error_detail(err);
    # no status -> neither the 403 branch nor the status-format branch fires
    assert detail == str(err);
    assert "Reason:" in detail;
}


test "unavailable_detail reflects capability, cluster, and config states" {
    # client absent -> capability message (image lacks deploy.k8s)
    with patch.object(k8s_ops, "HAS_KUBERNETES", False) {
        assert k8s_ops.unavailable_detail() == "kubernetes client not installed (image lacks the 'deploy.k8s' capability).";
    }

    # client present but no service host -> not in a cluster
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.dict(os.environ) {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
            assert k8s_ops.unavailable_detail() == "not running inside a Kubernetes cluster.";
        }
        # client present and in a cluster -> config could not load
        with patch.dict(os.environ) {
            os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
            assert k8s_ops.unavailable_detail() == "in-cluster Kubernetes config could not be loaded.";
        }
    }
}


test "ops_namespace resolves POD_NAMESPACE env and falls back to default" {
    with patch.dict(os.environ) {
        os.environ["POD_NAMESPACE"] = "team-ops";
        assert k8s_ops.ops_namespace() == "team-ops";
    }

    # unset env and no mounted serviceaccount namespace file -> "default"
    with patch.dict(os.environ) {
        os.environ.pop("POD_NAMESPACE", None);
        assert k8s_ops.ops_namespace() == "default";
    }
}


test "k8s_available gates on client presence and service host env" {
    # client present + host set (non-blank) -> available
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.dict(os.environ) {
            os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
            assert k8s_ops.k8s_available() == True;
        }
        # host unset -> unavailable
        with patch.dict(os.environ) {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
            assert k8s_ops.k8s_available() == False;
        }
        # host present but blank/whitespace -> unavailable (stripped)
        with patch.dict(os.environ) {
            os.environ["KUBERNETES_SERVICE_HOST"] = "   ";
            assert k8s_ops.k8s_available() == False;
        }
    }

    # client absent short-circuits regardless of host env
    with patch.object(k8s_ops, "HAS_KUBERNETES", False) {
        with patch.dict(os.environ) {
            os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
            assert k8s_ops.k8s_available() == False;
        }
    }
}


test "_ensure_config short-circuits to False when not in a cluster" {
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.dict(os.environ) {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
            assert k8s_ops._ensure_config() == False;
            # it records the resolution so it will not retry
            assert k8s_ops._config_loaded == True;
            assert k8s_ops._config_ok == False;
        }
    }
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
}


test "_ensure_config returns True when in-cluster config loads" {
    ok_cfg = MagicMock();
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.object(k8s_ops, "config", ok_cfg) {
            with patch.dict(os.environ) {
                os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
                assert k8s_ops._ensure_config() == True;
                assert k8s_ops._config_ok == True;
                assert ok_cfg.load_incluster_config.call_count == 1;
            }
        }
    }
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
}


test "_ensure_config returns False when in-cluster config load raises" {
    fail_cfg = MagicMock();
    fail_cfg.load_incluster_config.side_effect = RuntimeError("no cluster");
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.object(k8s_ops, "config", fail_cfg) {
            with patch.dict(os.environ) {
                os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
                assert k8s_ops._ensure_config() == False;
                assert k8s_ops._config_ok == False;
                assert k8s_ops._config_loaded == True;
            }
        }
    }
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
}


test "_ensure_config caches the first resolution and skips reloading" {
    ok_cfg = MagicMock();
    # prime the cache as already loaded + ok; loader must never be called again
    k8s_ops._config_loaded = True;
    k8s_ops._config_ok = True;
    with patch.object(k8s_ops, "config", ok_cfg) {
        with patch.dict(os.environ) {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
            # cached True wins even though k8s now looks unavailable
            assert k8s_ops._ensure_config() == True;
            # flip the cached verdict and confirm it is honoured verbatim
            k8s_ops._config_ok = False;
            assert k8s_ops._ensure_config() == False;
        }
    }
    assert ok_cfg.load_incluster_config.call_count == 0;
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
}
