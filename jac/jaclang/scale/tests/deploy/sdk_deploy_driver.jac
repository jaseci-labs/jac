"""SDK deploy driver for the real-cluster e2e (sdk_deploy_real_e2e.sh).

Deploys an ordinary app folder (the e2e uses a sanitized copy of
jac/examples/todo_app) through the programmatic SDK instead of
`jac scale deploy`, using the one-call form:

    result = deploy(path, config, on_event=...);

    jac run sdk_deploy_driver.jac deploy     # deploy SDK_DEPLOY_SOURCE
    jac run sdk_deploy_driver.jac status     # full status dict (JSON)
    jac run sdk_deploy_driver.jac url        # externally reachable URL
    jac run sdk_deploy_driver.jac revisions  # retained releases (JSON)
    jac run sdk_deploy_driver.jac rollback N # roll the fleet back to release N
    jac run sdk_deploy_driver.jac destroy    # tear down; never prompts

Env: SDK_DEPLOY_SOURCE (required), SDK_DEPLOY_APP_NAME, SDK_DEPLOY_NAMESPACE,
SDK_DEPLOY_STORAGE_CLASS, SDK_DEPLOY_GREETING, SDK_DEPLOY_SECRET,
SDK_DEPLOY_COMPONENT (destroy only; empty tears down the whole app),
SDK_DEPLOY_REVISION_HISTORY_LIMIT, E2E_POD_BASE_IMAGE.
"""
import json;
import os;
import sys;

glob SOURCE: str = os.environ.get("SDK_DEPLOY_SOURCE", ""),
     APP_NAME: str = os.environ.get("SDK_DEPLOY_APP_NAME", "sdk-todo"),
     NAMESPACE: str = os.environ.get("SDK_DEPLOY_NAMESPACE", "sdk-todo"),
     STORAGE_CLASS: str = os.environ.get("SDK_DEPLOY_STORAGE_CLASS", ""),
     GREETING: str = os.environ.get("SDK_DEPLOY_GREETING", "hello"),
     SECRET: str = os.environ.get("SDK_DEPLOY_SECRET", "s3cret-demo"),
     COMPONENT: str = os.environ.get("SDK_DEPLOY_COMPONENT", ""),
     HISTORY_LIMIT: str = os.environ.get("SDK_DEPLOY_REVISION_HISTORY_LIMIT", ""),
     POD_BASE_IMAGE: str = os.environ.get("E2E_POD_BASE_IMAGE", "");


def build_config -> dict[str, any] {
    extra: dict[str, any] = {
        "bundle_storage_class": STORAGE_CLASS, "python_image": POD_BASE_IMAGE
    };
    if HISTORY_LIMIT {
        extra["revision_history_limit"] = int(HISTORY_LIMIT);
    }
    return {
        "app_name": APP_NAME,
        "namespace": NAMESPACE,
        "env": {"GREETING_PREFIX": GREETING},
        "secrets": {"GREETER_SECRET": SECRET},
        "labels": {"jac-scale.example": "sdk-deploy"},
        "extra": extra
    };
}


def print_event(event: ProgressEvent) {
    print(f"[{event.phase}:{event.status}] {event.message}", flush=True);
}


with entry {
    action = sys.argv[1] if len(sys.argv) > 1 else "";
    actions = ("deploy", "status", "url", "revisions", "rollback", "destroy");
    if action not in actions {
        print(f"usage: jac run sdk_deploy_driver.jac [{'|'.join(actions)}]");
        sys.`exit(2);
    }
    if action == "deploy" {
        if not SOURCE {
            print("SDK_DEPLOY_SOURCE must point at the app folder to deploy");
            sys.`exit(2);
        }
        result = deploy(SOURCE, build_config(), on_event=print_event);
        if not result.success {
            print(f"DEPLOY_FAILED: {result.message}");
            sys.`exit(1);
        }
        print(f"DEPLOY_OK service_url={result.service_url or ''}");
    } elif action == "status" {
        print(json.dumps(ScaleClient().status(APP_NAME, NAMESPACE)));
    } elif action == "url" {
        print(ScaleClient().service_url(APP_NAME, NAMESPACE) or "");
    } elif action == "revisions" {
        print(json.dumps(ScaleClient().revisions(APP_NAME, NAMESPACE)));
    } elif action == "rollback" {
        result = ScaleClient().rollback(APP_NAME, NAMESPACE, int(sys.argv[2]));
        if not result.success {
            print(f"ROLLBACK_FAILED: {result.message}");
            sys.`exit(1);
        }
        print("ROLLBACK_OK");
    } else {
        ScaleClient().destroy(APP_NAME, NAMESPACE, COMPONENT);
        print("DESTROY_OK");
    }
}
