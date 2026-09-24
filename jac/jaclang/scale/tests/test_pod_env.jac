import unittest.mock as mock;
import json;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME,
    CONFIG_REVISION_ANNOTATION,
    with_config_revision
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    create_k8s_secret
}
import from kubernetes.client.exceptions { ApiException }
import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e",
     _SV_MODULE_FIXTURE: Path = Path(__file__).parent / "fixtures" / "sv_module_service";


test "generate_service_pod_specs auto-discovers services when no routes declared" {
    # The #7137 companion: a microservice app with no
    # [scale.microservices.routes] section still deploys - services are
    # discovered from `sv import` under the project root.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE));
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    with mock.patch.object(builder, "_ms_cfg", return_value={}), mock.patch.object(
        builder, "_build_service_pod_spec", return_value={}
    ), mock.patch.object(builder, "_build_gateway_pod_spec", return_value={}) {
        specs = builder.generate_service_pod_specs(app_cfg, "img");
    }
    # discovered from the fixture's sv graph, no toml routes needed
    assert "products_app" in specs;
    assert "orders_app" in specs;
    assert "cart_app" in specs;
    assert GATEWAY_NAME in specs;
}


test "build_env injects JAC_SV_ROUTES so pods get routes without a toml table" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    routes = {"orders_app": "/api/orders", "cart_app": "/api/cart"};
    with mock.patch.object(builder, "_microservice_routes", return_value=routes) {
        env = builder._build_env("orders_app", {});
    }
    pairs = {e["name"]: e["value"] for e in env};
    assert "JAC_SV_ROUTES" in pairs;
    assert json.loads(pairs["JAC_SV_ROUTES"]) == routes;
}


test "a discovered .sv.jac service is told which module to run" {
    # jac#8693: generate_service_pod_specs merges discovered services in via
    # resolve_routes but never calls the paired resolve_service_files, so a
    # discovered service got a Deployment with no JAC_SV_FILE. The entrypoint
    # then falls back to `find . -name "<svc>.jac"`, which cannot match the
    # `<svc>.sv.jac` modules discovery exists to register, and every such pod
    # crash-loops on "couldn't read 'thing.jac'".
    cfg = KubernetesConfig(app_name="svmod", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, project_dir=str(_SV_MODULE_FIXTURE));
    app_cfg = AppConfig(
        code_folder=str(_SV_MODULE_FIXTURE), app_name="svmod", file_name="main.jac"
    );

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    assert "thing" in specs , sorted(specs.keys());
    env = {e["name"]: e["value"] for e in specs["thing"]["containers"][0]["env"]};
    assert env["JAC_SV_NAME"] == "thing" , env;
    assert env.get("JAC_SV_FILE") == "services/thing.sv.jac" , (
        f"discovered service got no module to run: {env.get('JAC_SV_FILE')!r}"
    );
}


test "an app with no declared routes deploys as one service plus the gateway" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/littlex", file_name="main.jac");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    # named after the app, not its entry file: main.jac must not turn every
    # monolith into a "main" service.
    assert set(specs.keys()) == {"littlex", GATEWAY_NAME};
    assert builder.microservices_config["routes"] == {"littlex": "/littlex"};
    env = {e["name"]: e["value"] for e in specs["littlex"]["containers"][0]["env"]};
    assert env["JAC_SV_NAME"] == "littlex";
    assert env["JAC_SV_FILE"] == "main.jac";
}


test "a solo app whose name shadows a builtin route is rejected" {
    cfg = KubernetesConfig(app_name="admin", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/admin", file_name="main.jac");

    raised = False;
    try {
        builder.generate_service_pod_specs(app_cfg, "img");
    } except ValueError as e {
        raised = True;
        assert "builtin" in str(e);
    }
    assert raised , "expected the reserved-name guard to fire";
}


test "every generated deployment rolls with surge, never delete-and-recreate" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    for name in ["littlex", GATEWAY_NAME] {
        manifest = builder._build_deployment_manifest(name, {});
        strategy = manifest["spec"]["strategy"];
        assert strategy["type"] == "RollingUpdate";
        assert strategy["rollingUpdate"] == {"maxSurge": 1, "maxUnavailable": 0};
    }
}


test "build_env bakes a direct peer URL only for peers that are not HTTP-activated" {
    # A baked JAC_SV_<PEER>_URL would send sv-to-sv calls straight at a Service
    # with no live endpoints instead of through the interceptor that wakes it.
    activated = {
        "worker": {
            "http_activation": {
                "enabled": True,
                "target_port": 8000,
                "concurrency_target": 1,
                "rules": [{"hosts": ["worker.ns.local"]}]
            }
        }
    };
    for (label, services, baked) in [
        ("HTTP-activated peer", activated, False),
        ("plain peer", {}, True)
    ] {
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig(app_name="jac-shop", namespace="ns"),
            microservices_config={
                "routes": {"app": "/", "worker": "/worker"},
                "services": services
            }
        );
        env = {e["name"]: e["value"] for e in builder._build_env("app", {})};
        assert ("JAC_SV_WORKER_URL" in env) == baked , f"{label}: {env}";
    }
}


test "build_env omits JAC_SV_ROUTES when there are no routes" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_microservice_routes", return_value={}) {
        env = builder._build_env("orders_app", {});
    }
    assert "JAC_SV_ROUTES" not in {e["name"] for e in env};
}

test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry["value"] for entry in env};
    assert pairs.get("JAC_SV_NAME") == "orders";
    assert pairs.get("K8S_APP_NAME") == "jac-shop";
    assert pairs.get("K8S_NAMESPACE") == "jac-shop-dev";
}


test "build_env keeps per-service overrides but never shadows the K8S_* vars" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env(
        "orders", {"env": {"STRIPE_KEY": "sk_test", "K8S_APP_NAME": "evil"}}
    );

    names = [entry["name"] for entry in env];
    assert "STRIPE_KEY" in names;

    first_app_name = next(
        (
            e["value"]
            for e in env
            if e["name"] == "K8S_APP_NAME"
        ),
        None
    );
    assert first_app_name == "jac-shop";
}


test "the gateway pod never rebuilds the client at boot" {
    # The deploy builds the client bundle on the host and fails fast when
    # that build fails; the pod serves what shipped and must not retry.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="main.jac") {
        entry = builder._pod_entrypoint();
    }
    args = entry["args"][0];
    assert "jac build" not in args;
    assert "exec jac scale gateway" in args;
}


test "no client entry means no client build in the gateway entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="") {
        entry = builder._pod_entrypoint();
    }
    assert "jac build" not in entry["args"][0];
}


test "a single-file full-stack app still gets its client bundle built" {
    import tempfile;
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"todo-app\"\n");
        }
        with open(os.path.join(tmp, "app.cl.jac"), "w") as f {
            f.write("");
        }
        cfg = KubernetesConfig(app_name="todo-app", namespace="ns");
        builder = ManifestBuilder(k8s_config=cfg, project_dir=tmp);
        assert builder._has_client_source();
        assert builder._client_entry() == "main.jac";
    }
}


# Config-only deploys. Secret sections are stripped from the bundle before it is
# packed and the Secret is referenced by a constant name, so a deploy that
# changed only configuration produced a byte identical pod template: the patch
# was a no-op and running pods kept the old values while the deploy reported
# success.
#
# The marker is the Secret's own resourceVersion, stamped at apply time. It
# carries no secret material, which matters because OPS_READ_RULES grants read
# on deployments and replicasets while withholding secrets: a digest of the
# resolved values would put a brute-forceable fingerprint of them on an object
# that boundary deliberately exposes.

def _revision_of(manifest: dict[str, any]) -> str {
    return dict(
        dict(dict(manifest["spec"])["template"])["metadata"].get("annotations", {})
    ).get(
        CONFIG_REVISION_ANNOTATION, ""
    );
}


def _deployment(secrets: (dict[str, str] | None) = None) -> dict[str, any] {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, secrets=secrets or {});
    return builder._build_deployment_manifest("jac-shop", {});
}


test "a changed secret changes the pod template" {
    before = with_config_revision(_deployment({"MARKER": "v1"}), "1001");
    after = with_config_revision(_deployment({"MARKER": "v2"}), "1002");

    assert _revision_of(before) != _revision_of(after) , (
        "a config-only change left the pod template identical, so the patch "
        "is a no-op and running pods keep the old value"
    );
}


test "an unchanged secret leaves the pod template untouched" {
    first = with_config_revision(_deployment({"MARKER": "v1"}), "1001");
    second = with_config_revision(_deployment({"MARKER": "v1"}), "1001");

    assert first == second;
}


# An app with no secrets has no Secret object and so no revision. Stamping a
# constant here would still change every existing pod template once, rolling
# fleets that have no configuration at all.
test "an app with no secrets gets no marker and no rollout" {
    manifest = with_config_revision(_deployment({}), "");

    assert "annotations" not in dict(
        dict(dict(manifest["spec"])["template"])["metadata"]
    );
}


# The marker must not be derived from the values themselves: OPS_READ_RULES
# exposes deployments while withholding secrets, so a digest of low entropy
# config could be recovered offline from metadata a reader is allowed to see.
test "the marker is opaque and carries no secret material" {
    manifest = with_config_revision(
        _deployment({"API_KEY": "sk-not-in-here", "MARKER": "v1"}), "4242"
    );

    rendered = json.dumps(manifest);
    assert "sk-not-in-here" not in rendered;
    assert "v1" not in _revision_of(manifest);
    assert _revision_of(manifest) == "4242" , (
        "the marker is the Secret's resourceVersion, not a function of its values"
    );
}


# The revision comes from the apply response rather than a follow up read. A
# second read would need get on secrets, which a least privilege deployer may
# not have, and a read that failed would silently produce no marker, no
# rollout, and a successful looking deploy: exactly the bug this fixes.

obj _FakeSecrets {
    has created: list = [],
        version: str = "77";

    def create_namespaced_secret(namespace: str, body: any) -> any {
        self.created.append(body["metadata"]["name"]);
        return SimpleNamespace(metadata=SimpleNamespace(resource_version=self.version));
    }
}


# Rollback depth (#8089) rode the Kubernetes default of 10 because the field was
# never set. Declaring it makes the depth something a consumer can read back and
# reason about before offering a rollback it cannot honor.
test "every deployment declares its revision history limit" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);

    for name in ["littlex", GATEWAY_NAME] {
        manifest = builder._build_deployment_manifest(name, {});
        assert manifest["spec"]["revisionHistoryLimit"] == 10;
    }
}


test "the config revision comes from the applied Secret itself" {
    api = _FakeSecrets();

    revision = create_k8s_secret(api, "ns", "app-secrets", {"MARKER": "v1"});

    assert revision == "77" , "the apply response already carries the revision";
    assert api.created == ["app-secrets"];
}


# An apply that returns no usable revision must not fall through to a deploy
# with no marker: that is the stale config failure the fix exists to remove.
test "an unusable revision is reported rather than silently skipped" {
    api = _FakeSecrets(version="");

    assert create_k8s_secret(api, "ns", "app-secrets", {"MARKER": "v1"}) == "";
    assert with_config_revision(_deployment({"MARKER": "v1"}), "") == _deployment(
        {"MARKER": "v1"}
    ) , "an empty revision stamps nothing, so the caller has to fail loudly";
}


# The redeploy is where #8115 actually lives: the Secret already exists, the
# create 409s, and the revision has to come off the replace response instead.
# _FakeSecrets only implements create, so a regression in that second capture
# would leave the suite green while every real redeploy failed on the missing
# revision.
obj _FakeSecretsExisting(_FakeSecrets) {
    has replaced: list = [];

    def create_namespaced_secret(namespace: str, body: any) -> any {
        raise ApiException(status=409);
    }

    def replace_namespaced_secret(name: str, namespace: str, body: any) -> any {
        self.replaced.append(name);
        return SimpleNamespace(metadata=SimpleNamespace(resource_version=self.version));
    }
}


test "a redeploy takes its revision from the replace, not the create" {
    api = _FakeSecretsExisting(version="88");

    revision = create_k8s_secret(api, "ns", "app-secrets", {"MARKER": "v2"});

    assert revision == "88" , (
        "the 409 path has to return the replace response's revision, or a "
        "redeploy stamps nothing and the config never reaches running pods"
    );
    assert api.replaced == ["app-secrets"];
    assert api.created == [];
}


test "an app with no secrets applies none and needs no revision" {
    api = _FakeSecrets();

    assert create_k8s_secret(api, "ns", "app-secrets", {}) == "";
    assert api.created == [];
}


test "a configured revision history limit reaches the deployment" {
    cfg = KubernetesConfig(
        app_name="littlex", namespace="ns", revision_history_limit=3
    );
    builder = ManifestBuilder(k8s_config=cfg);

    manifest = builder._build_deployment_manifest("littlex", {});

    assert manifest["spec"]["revisionHistoryLimit"] == 3;
}
