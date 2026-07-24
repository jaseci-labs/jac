"""Shared test helpers for jac-scale's KEDA HTTP activation tests.

Canonical, copy-paste-free fixtures used by both the programmatic-API tests
(test_keda_http_activation.jac) and the jac.toml config-translation/wiring
tests (test_http_activation_config.jac and friends): a defaulted
HTTPActivationSpec, a defaulted jac.toml-shaped config dict, and a
KEDAAutoscaler wired to MagicMock Kubernetes clients.

Example:
    import from jaclang.scale.tests.deploy.http_activation_test_support {
        default_http_activation_spec as _spec,
        mocked_keda_autoscaler as _mocked_keda
    }
    spec = _spec(namespace="staging");
"""

import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPActivationSpec,
    HTTPServiceTarget,
    HTTPConcurrencyMetric
}

# Base HTTPActivationSpec shared by most tests: a Deployment target on port
# 8080 with a concurrency=10 trigger. Override only what a given test cares
# about; pass concurrency=None when testing the metric-required check.
def default_http_activation_spec(**overrides: any) -> HTTPActivationSpec {
    defaults = {
        "name": "preview",
        "namespace": "default",
        "scale_target_name": "preview-deployment",
        "target": HTTPServiceTarget(service="preview-svc", port=8080),
        "concurrency": HTTPConcurrencyMetric(target_value=10)
    };
    if "request_rate" in overrides {
        defaults.pop("concurrency");
    }
    defaults.update(overrides);
    return HTTPActivationSpec(**defaults);
}

# Base jac.toml [*.http_activation] config dict, the dict-side counterpart to
# default_http_activation_spec above: enabled, target_port=8080,
# concurrency_target=10. Override only what a given test cares about; pass
# request_rate_target=... to switch to the request-rate metric (drops
# concurrency_target the same way default_http_activation_spec drops
# concurrency when request_rate is supplied).
def default_http_activation_config(**overrides: any) -> dict[str, any] {
    defaults: dict[str, any] = {
        "enabled": True,
        "target_port": 8080,
        "concurrency_target": 10
    };
    if "request_rate_target" in overrides {
        defaults.pop("concurrency_target");
    }
    defaults.update(overrides);
    return defaults;
}

# KEDAAutoscaler wired to MagicMock clients, with the HTTP Add-on preflight
# check (list_cluster_custom_object) pre-configured as installed by default.
# Pass a pre-configured apps_api/core_api/custom_api to control target,
# Service, or route/ScaledObject existence for a specific test. Returns the
# mocks alongside the instance since KEDAAutoscaler's api fields are typed
# `any | None`, which the checker won't let a caller re-narrow after the fact.
def mocked_keda_autoscaler(
    http_addon_installed: bool = True,
    custom_api: any = None,
    apps_api: any = None,
    core_api: any = None
) -> tuple[KEDAAutoscaler, any, any, any] {
    KEDAAutoscaler._http_preflight_cache.clear();
    custom_api = custom_api or unittest.mock.MagicMock();
    if http_addon_installed {
        custom_api.list_cluster_custom_object.return_value = {};
    } else {
        custom_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    }
    apps_api = apps_api or unittest.mock.MagicMock();
    core_api = core_api or unittest.mock.MagicMock();
    keda = KEDAAutoscaler(
        _custom_api=custom_api, _apps_api=apps_api, _core_api=core_api
    );
    return (keda, custom_api, apps_api, core_api);
}
