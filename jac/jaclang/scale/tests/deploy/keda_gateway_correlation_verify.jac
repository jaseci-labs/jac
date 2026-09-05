"""Deploy/observe/teardown driver for the KEDA gateway target-correlation
e2e (keda_gateway_correlation_real_e2e.sh). Deploys a real jac.toml project
(a sanitized copy of jac/examples/todo_app, KEDA-autoscaled) through the
SDK's one-call deploy() -- the same KubernetesTarget.deploy() path
`jac scale deploy` drives, and the same path that creates the ScaledObject
via KEDAAutoscaler.apply() -- instead of hand-building a Deployment manifest
and calling KEDAAutoscaler.apply() directly. Then runs the real
KubernetesAutoscalerObserver against the live cluster it just deployed, no
mocking, to exercise the real observer's watch_namespace()/_target_cache
against a real ScaledObject, KEDA-generated HPA, and Deployment.

Reproduces jac-scale's actual gateway deploy shape (see
target.jac:_autoscaler_spec and manifest_builder.jac:k8s_safe_name):
scale_target_name is the Deployment's own resource name
("gateway-deployment"), which also becomes the app label KEDA propagates
onto the ScaledObject/HPA it manages -- while the Deployment itself is
labeled with the bare app name ("gateway"), since that label doubles as its
pod selector. Before a0e5c2213 the observer correlated all three resource
kinds by that `app` label, so the ScaledObject/HPA (labelled
"gateway-deployment") and the Deployment (labelled "gateway") never joined
into one _target_cache slot.

    jac run keda_gateway_correlation_verify.jac deploy
    jac run keda_gateway_correlation_verify.jac observe
    jac run keda_gateway_correlation_verify.jac teardown

Namespace/app/source are read from env vars so the orchestrating shell
script controls them without editing this file.
"""
import os;
import sys;
import time;
import from jaclang.scale._optdeps.kubernetes { config as k8s_config, ConfigException }
import from jaclang.scale.sdk { ProgressEvent, ScaleClient, deploy }
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver
}
import from jaclang.scale.observability.standard_logger { StandardLogger }

glob SOURCE: str = os.environ.get("KEDA_GW_CORR_E2E_SOURCE", ""),
     NAMESPACE: str = os.environ.get("KEDA_GW_CORR_E2E_NAMESPACE", "jac-gw-corr-e2e"),
     APP_NAME: str = os.environ.get("KEDA_GW_CORR_E2E_APP", "gw-corr-app"),
     STORAGE_CLASS: str = os.environ.get("KEDA_GW_CORR_E2E_STORAGE_CLASS", ""),
     POD_BASE_IMAGE: str = os.environ.get("E2E_POD_BASE_IMAGE", ""),
     DEPLOYMENT_NAME: str = "gateway-deployment",
     OBSERVE_TIMEOUT: int = int(
         os.environ.get("KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT", "180")
     );

def load_config {
    # any: sidesteps a checker false positive on _optdeps' guarded import (NoneType inferred from its ImportError fallback branch).
    kube_config: any = k8s_config;
    try {
        kube_config.load_kube_config();
    } except ConfigException {
        kube_config.load_incluster_config();
    }
}

def build_config -> dict[str, any] {
    # DeploySpec.to_target_config() builds the KubernetesConfig fields it
    # passes to the target entirely from this dict; unlike `jac scale deploy`,
    # the SDK path never reads the staged app's own jac.toml [scale.kubernetes]
    # table, so autoscaler_engine must be set here, not in the staged jac.toml.
    return {
        "app_name": APP_NAME,
        "namespace": NAMESPACE,
        "extra": {
            "bundle_storage_class": STORAGE_CLASS,
            "python_image": POD_BASE_IMAGE,
            "autoscaler_engine": "keda"
        }
    };
}

def print_event(event: ProgressEvent) {
    print(f"[{event.phase}:{event.status}] {event.message}", flush=True);
}

def deploy_app {
    if not SOURCE {
        print("KEDA_GW_CORR_E2E_SOURCE must point at the app folder to deploy");
        sys.`exit(2);
    }
    result = deploy(SOURCE, build_config(), on_event=print_event);
    if not result.success {
        print(f"DEPLOY_FAILED: {result.message}");
        sys.`exit(1);
    }
    print(f"DEPLOY_OK service_url={result.service_url or ''}");
}

def observe_and_assert {
    load_config();

    observer = KubernetesAutoscalerObserver(logger=StandardLogger());
    observer.start();
    observer.watch_namespace(NAMESPACE);

    key = f"{NAMESPACE}::{DEPLOYMENT_NAME}";
    deadline = time.monotonic() + float(OBSERVE_TIMEOUT);
    all_keys: list[str] = [];
    full_slot: dict[str, any] = {};
    while time.monotonic() < deadline {
        with observer._lock {
            all_keys = list(observer._target_cache.keys());
            full_slot = dict(observer._target_cache.get(key, {}));
        }
        if (
            full_slot.get("scaled_object") is not None
            and full_slot.get("hpa") is not None
            and full_slot.get("deployment") is not None
        ) {
            break;
        }
        time.sleep(1.0);
    }
    observer.stop(drain=True);

    print(f"_target_cache keys: {all_keys}");
    print(
        f"slot for '{key}': "
        f"scaled_object={'set' if full_slot.get('scaled_object') else 'None'}, "
        f"hpa={'set' if full_slot.get('hpa') else 'None'}, "
        f"deployment={'set' if full_slot.get('deployment') else 'None'}"
    );

    correlated = (
        key in all_keys
        and full_slot.get("scaled_object") is not None
        and full_slot.get("hpa") is not None
        and full_slot.get("deployment") is not None
    );
    if not correlated {
        print(
            "FAIL: expected a fully populated _target_cache slot for "
            f"'{key}'; got {len(all_keys)} slot(s): {all_keys}"
        );
        sys.`exit(1);
    }
    print(
        f"PASS: '{key}' has one fully populated _target_cache slot -- "
        "scaled_object, hpa, and deployment all joined under the same key."
    );
}

def teardown {
    ScaleClient().destroy(APP_NAME, NAMESPACE);
    print("teardown -> done");
}

with entry {
    if len(sys.argv) < 2 or sys.argv[1] not in ("deploy", "observe", "teardown") {
        print(
            "usage: jac run keda_gateway_correlation_verify.jac "
            "[deploy|observe|teardown]"
        );
        sys.`exit(1);
    }
}

glob action = sys.argv[1];

with entry {
    if action == "deploy" {
        deploy_app();
    } elif action == "observe" {
        observe_and_assert();
    } else {
        teardown();
    }
}
