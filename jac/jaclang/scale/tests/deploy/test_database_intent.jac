"""Deployment intent, not the deployer's ambient environment, picks the deployed app's database."""

import jaclang;
import os;
import unittest.mock;
import from pathlib { Path }

import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.database { kubernetes_postgres as pg_module }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTargetBase
}
import from jaclang.scale._optdeps.kubernetes { ApiException }

# The bare host is namespace-relative: exactly what a platform pod has in JAC_DB_URL.
glob PLATFORM_DB_URL = "postgresql://platform@platform-postgres-service:5432/platform",
     SHARED_DB_URL = "postgresql://app:pw@shared-db.data.svc.cluster.local:5432/app",
     NO_SUCH_NS_FILE = "/nonexistent/jac-test/serviceaccount/namespace";


with entry {
    # Pin the in-cluster namespace file out of reach so these tests read the
    # deployer's namespace only from POD_NAMESPACE, wherever they run.
    pg_module.POD_NAMESPACE_FILE = NO_SUCH_NS_FILE;
}


# Kubernetes API doubles where every read is a 404, so every create path is taken.
def _mock_apis -> dict {
    apps_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    apps_v1.read_namespaced_stateful_set.side_effect = ApiException(status=404);
    core_v1.read_namespaced_secret.side_effect = ApiException(status=404);
    core_v1.read_namespaced_service.side_effect = ApiException(status=404);
    core_v1.read_namespaced_service_account.side_effect = ApiException(status=404);
    core_v1.read_namespaced_persistent_volume_claim.side_effect = ApiException(
        status=404
    );
    return {"apps_v1": apps_v1, "core_v1": core_v1};
}


# Run the database half of a deploy against API doubles and report what it did.
def _run_deploy(cfg: KubernetesConfig, app_name: str) -> dict {
    target = KubernetesTargetBase(config=cfg);
    apis = _mock_apis();
    target._deploy_databases(app_name, cfg.namespace, apis["apps_v1"], apis["core_v1"]);
    apis["env_list"] = list(target.env_list);
    return apis;
}


# The external url reaches pods through a secret, so read what the deploy wrote.
def _db_url_written(apis: dict) -> str {
    call = apis["core_v1"].create_namespaced_secret.call_args;
    assert call is not None , "external mode wrote no secret for JAC_DB_URL";
    return call.kwargs["body"]["stringData"]["connection-string"];
}


# Point the deploying process at a database, the way a platform pod is pointed at one.
def _set_ambient_db_url(url: (str | None)) -> (str | None) {
    prior = os.environ.get("JAC_DB_URL");
    if url is None {
        os.environ.pop("JAC_DB_URL", None);
    } else {
        os.environ["JAC_DB_URL"] = url;
    }
    reset_scale_config();
    return prior;
}


# The namespace the deploying process itself runs in, as the downward API sets it.
def _set_pod_namespace(namespace: (str | None)) -> (str | None) {
    prior = os.environ.get("POD_NAMESPACE");
    if namespace is None {
        os.environ.pop("POD_NAMESPACE", None);
    } else {
        os.environ["POD_NAMESPACE"] = namespace;
    }
    return prior;
}


test "ambient JAC_DB_URL does not decide the deployed app's database" {
    # A platform service deploying user apps in-process has JAC_DB_URL set to its
    # own fleet database. The app it deploys must still get a database of its own.
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        cfg = KubernetesConfig(app_name="tenant-app", namespace="tenant-a");
        apis = _run_deploy(cfg, "tenant-app");

        env_list = apis["env_list"];
        assert len(env_list) == 1 , f"expected one database env var, got {env_list}";
        `entry = env_list[0];
        assert `entry["name"] == "JAC_DB_URL";
        assert "valueFrom" in `entry , f"the deployed app was handed the deployer's own database url verbatim: {`entry}";
        assert `entry.get("value") != PLATFORM_DB_URL;

        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 1 , "no per-app postgres StatefulSet was provisioned";
        assert apis["core_v1"].create_namespaced_secret.call_count == 1 , "no per-app postgres Secret was provisioned";
        assert apis["core_v1"].create_namespaced_service.call_count == 1 , "no per-app postgres Service was provisioned";
        assert apis["core_v1"].create_namespaced_service_account.call_count == 1 , "no per-app postgres ServiceAccount was provisioned";
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "an explicit external database_url skips provisioning" {
    prior = _set_ambient_db_url(None);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=SHARED_DB_URL
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert apis["env_list"]
            == [
                {
                    "name": "JAC_DB_URL",
                    "valueFrom": {
                        "secretKeyRef": {
                            "name": "tenant-app-external-db",
                            "key": "connection-string"
                        }
                    }
                }
            ] , f"an external url must reach pods by reference, not by value: {apis[
            'env_list'
        ]}";
        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 0 , "external mode must not provision a StatefulSet";
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "an external database url never reaches a pod spec as a literal value" {
    # The env list is copied verbatim into every service pod spec and every
    # Deployment manifest, so a plain value here is a credential readable by
    # anyone with get on pods, and by the --show-yaml dump.
    prior = _set_ambient_db_url(None);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=SHARED_DB_URL
        );
        apis = _run_deploy(cfg, "tenant-app");

        for `entry in apis["env_list"] {
            assert "value" not in `entry , (
                f"JAC_DB_URL carries a literal value in the pod spec: {`entry}"
            );
            assert SHARED_DB_URL not in str(`entry) , (
                f"the connection string appears in the env list: {`entry}"
            );
        }
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "the external database url is written to a labelled secret the deploy owns" {
    prior = _set_ambient_db_url(None);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=SHARED_DB_URL
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert apis["core_v1"].create_namespaced_secret.call_count == 1 , (
            "the url has to land somewhere pods can reference"
        );
        body = apis["core_v1"].create_namespaced_secret.call_args.kwargs["body"];
        assert body["metadata"]["name"] == "tenant-app-external-db";
        assert body["metadata"]["labels"]["managed"] == "jac-scale" , (
            f"destroy sweeps by this label, so an unlabelled secret leaks: {body}"
        );
        assert body["stringData"]["connection-string"] == SHARED_DB_URL;
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "an explicit provision request wins over ambient JAC_DB_URL" {
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app", namespace="tenant-a", database_mode="provision"
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 1;
        assert "valueFrom" in apis["env_list"][0];
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "database_mode=none wires no database at all" {
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app", namespace="tenant-a", database_mode="none"
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert apis["env_list"] == [];
        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 0;
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "external mode requested with no url is a hard error" {
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app", namespace="tenant-a", database_mode="external"
        );
        raised = False;
        try {
            _run_deploy(cfg, "tenant-app");
        } except ValueError as e {
            raised = True;
            assert "JAC_DB_URL" in str(e);
        }
        assert raised , "external mode without a url must not silently fall back to the ambient env";
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "a bare service host that cannot be qualified fails the deploy" {
    prior = _set_ambient_db_url(None);
    prior_ns = _set_pod_namespace(None);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=PLATFORM_DB_URL
        );
        raised = False;
        try {
            _run_deploy(cfg, "tenant-app");
        } except ValueError as e {
            raised = True;
            message = str(e);
            assert "platform-postgres-service" in message;
            assert "tenant-a" in message;
            assert "svc.cluster.local" in message;
            assert "database_namespace" in message;
        }
        assert raised , "a manifest whose database host cannot resolve must not be reported as a successful deploy";
    } finally {
        _set_pod_namespace(prior_ns);
        _set_ambient_db_url(prior);
    }
}


test "a bare service host is qualified against the namespace that owns it" {
    prior = _set_ambient_db_url(None);
    prior_ns = _set_pod_namespace(None);
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=PLATFORM_DB_URL,
            database_namespace="platform"
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert _db_url_written(apis)
            == "postgresql://platform@platform-postgres-service.platform.svc.cluster.local:5432/platform";
    } finally {
        _set_pod_namespace(prior_ns);
        _set_ambient_db_url(prior);
    }
}


test "a bare service host in the target namespace is left alone" {
    prior = _set_ambient_db_url(None);
    prior_ns = _set_pod_namespace("tenant-a");
    try {
        cfg = KubernetesConfig(
            app_name="tenant-app",
            namespace="tenant-a",
            database_mode="external",
            database_url=PLATFORM_DB_URL
        );
        apis = _run_deploy(cfg, "tenant-app");

        assert _db_url_written(apis) == PLATFORM_DB_URL;
    } finally {
        _set_pod_namespace(prior_ns);
        _set_ambient_db_url(prior);
    }
}


test "the runtime path still honours ambient JAC_DB_URL for this process" {
    # JAC_DB_URL keeps meaning 'the database THIS PROCESS connects to'.
    prior = _set_ambient_db_url(PLATFORM_DB_URL);
    try {
        runtime = get_scale_config().get_database_config();
        assert runtime.get("url") == PLATFORM_DB_URL;
        deploy_view = get_scale_config().get_deploy_database_config();
        assert deploy_view.get("url") != PLATFORM_DB_URL , "the deploy-intent view must not see the process's own database";
    } finally {
        _set_ambient_db_url(prior);
    }
}


test "no deploy module can reach the env-reading database resolver" {
    # The separation is structural: get_database_config() answers 'what database
    # does THIS PROCESS use', and nothing on the deploy path may ask it.
    deploy_root = Path(jaclang.__file__).parent / "scale" / "deploy";
    assert deploy_root.is_dir() , f"could not locate the deploy package at {deploy_root}";

    offenders = [];
    for source in sorted(deploy_root.rglob("*.jac")) {
        if "get_database_config" in source.read_text() {
            offenders.append(str(source));
        }
    }
    assert offenders == [] , f"deploy modules must call get_deploy_database_config(), not the env-reading get_database_config(): {offenders}";
}
