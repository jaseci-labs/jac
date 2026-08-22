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

        assert apis["env_list"] == [{"name": "JAC_DB_URL", "value": SHARED_DB_URL}];
        assert apis["apps_v1"].create_namespaced_stateful_set.call_count == 0 , "external mode must not provision a StatefulSet";
        assert apis["core_v1"].create_namespaced_secret.call_count == 0;
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

        assert apis["env_list"]
            == [
                {
                    "name": "JAC_DB_URL",
                    "value": "postgresql://platform@platform-postgres-service.platform.svc.cluster.local:5432/platform"
                }
            ];
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

        assert apis["env_list"] == [{"name": "JAC_DB_URL", "value": PLATFORM_DB_URL}];
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
