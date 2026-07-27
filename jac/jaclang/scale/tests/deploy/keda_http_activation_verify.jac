"""Apply/destroy driver for the KEDA HTTP Add-on activation e2e
(keda_http_activation_real_e2e.sh). Talks to whatever cluster the current
kubeconfig/in-cluster context points at -- no mocking, this exercises
KEDAAutoscaler.apply_http_activation / destroy_http_activation for real.

    jac run keda_http_activation_verify.jac apply
    jac run keda_http_activation_verify.jac destroy

Target namespace/name/host are read from env vars (defaults match
../fixtures/keda_http_activation_e2e/fixture.yaml) so the orchestrating
shell script controls them without editing this file.
"""
import os;
import sys;
import from jaclang.scale._optdeps.kubernetes { config as k8s_config, ConfigException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.http_activation {
    HTTPActivationSpec,
    HTTPServiceTarget,
    HTTPRoutingRule,
    HTTPConcurrencyMetric
}
import from jaclang.scale.observability.standard_logger { StandardLogger }

glob NAMESPACE: str = os.environ.get("KEDA_HTTP_E2E_NAMESPACE", "jac-http-e2e"),
     DEPLOYMENT: str = os.environ.get("KEDA_HTTP_E2E_DEPLOYMENT", "echo"),
     SERVICE: str = os.environ.get("KEDA_HTTP_E2E_SERVICE", "echo-svc"),
     ROUTE_HOST: str = os.environ.get(
         "KEDA_HTTP_E2E_ROUTE_HOST", "echo.jac-http-e2e.local"
     ),
     POLLING_INTERVAL: int = int(
         os.environ.get("KEDA_HTTP_E2E_POLLING_INTERVAL", "10")
     ),
     COOLDOWN_PERIOD: int = int(os.environ.get("KEDA_HTTP_E2E_COOLDOWN_PERIOD", "60"));

def load_config {
    # any: sidesteps a checker false positive on _optdeps' guarded import (NoneType inferred from its ImportError fallback branch).
    kube_config: any = k8s_config;
    try {
        kube_config.load_kube_config();
    } except ConfigException {
        kube_config.load_incluster_config();
    }
}

def build_spec -> HTTPActivationSpec {
    return HTTPActivationSpec(
        name="e2e",
        namespace=NAMESPACE,
        scale_target_name=DEPLOYMENT,
        target=HTTPServiceTarget(service=SERVICE, port=80),
        rules=[HTTPRoutingRule(hosts=[ROUTE_HOST])],
        min_replicas=0,
        max_replicas=1,
        polling_interval=POLLING_INTERVAL,
        cooldown_period=COOLDOWN_PERIOD,
        concurrency=HTTPConcurrencyMetric(target_value=1)
    );
}

with entry {
    if len(sys.argv) < 2 or sys.argv[1] not in ("apply", "destroy") {
        print("usage: jac run keda_http_activation_verify.jac [apply|destroy]");
        sys.exit(1);
    }

    load_config();
}

glob keda = KEDAAutoscaler(logger=StandardLogger());

with entry {
    if sys.argv[1] == "apply" {
        ok = keda.apply_http_activation(build_spec());
        if not ok {
            print("apply_http_activation returned False (HTTP Add-on CRDs missing?)");
            sys.exit(1);
        }
        print(f"apply_http_activation -> {ok}");
        print(f"InterceptorRoute: {keda.interceptor_route_name_for(DEPLOYMENT)}");
        print(f"ScaledObject:     {keda.http_scaled_object_name_for(DEPLOYMENT)}");
    } else {
        keda.destroy_http_activation(DEPLOYMENT, NAMESPACE);
        print("destroy_http_activation -> done");
    }
}
