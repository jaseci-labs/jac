import os;
import json;
import unittest.mock as mock;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME,
    CONFIG_REVISION_ANNOTATION,
    with_config_revision
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    create_k8s_secret
}
import from kubernetes.client.exceptions { ApiException }
import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
    build_k8s_registry,
    K8sRuntimeServiceResolver
}
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.server.sv_client { peer_url_env_key }
import from jaclang.scale.runtime.fleet { FLEET_ENV, fleet_of }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parents[1] / "fixtures" / "k8s_e2e",
     _DISCOVERED_ROUTES: dict[str, str] = {
         "cart_app": "/cart",
         "orders_app": "/orders",
         "products_app": "/products"
     };


def _shop_fleet -> any {
    return fleet_of(_DISCOVERED_ROUTES, root_app="web", root_file="main.jac");
}


# The [apps] table is the authoritative fleet: every service app becomes its own
# pod and the served app hosts the gateway at /. Driven through the real builder
# via a real FleetSpec, not a patched _fleet / _build_*_pod_spec.
test "generate_service_pod_specs builds one pod per app in the fleet" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE), fleet=_shop_fleet()
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    assert set(specs.keys())
        == {"products_app", "orders_app", "cart_app", "web", GATEWAY_NAME};
    orders_env = {
        e["name"]: e["value"] for e in specs["orders_app"]["containers"][0]["env"]
    };
    shipped = json.loads(orders_env[FLEET_ENV]);
    assert shipped["root"] == "web";
    assert {
        m["app"]: m["route"]
        for m in shipped["members"]
        if not m["root"]
    }
        == _DISCOVERED_ROUTES;
}


test "an app with no [apps] deploys as one pod plus the gateway" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    app_cfg = AppConfig(code_folder="/apps/littlex", file_name="main.jac");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    # named after the app, not its entry file: main.jac must not turn every
    # monolith into a "main" service.
    assert set(specs.keys()) == {"littlex", GATEWAY_NAME};
    fleet = builder.fleet;
    assert fleet is not None and fleet.root_app == "littlex";
    env = {e["name"]: e["value"] for e in specs["littlex"]["containers"][0]["env"]};
    assert env["JAC_SV_NAME"] == "littlex";
    assert env["JAC_SV_FILE"] == "main.jac";
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

    assert "annotations"
        not in dict(dict(dict(manifest["spec"])["template"])["metadata"]);
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


test "build_env omits JAC_SV_FLEET when no fleet is resolved" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders_app", {});

    assert FLEET_ENV not in {e["name"] for e in env};
}

test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {`entry["name"]: `entry["value"] for `entry in env};
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

    names = [`entry["name"] for `entry in env];
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
        `entry = builder._pod_entrypoint();
    }
    args = `entry["args"][0];
    assert "jac build" not in args;
    assert "exec jac scale gateway" in args;
}


test "no client entry means no client build in the gateway entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="") {
        `entry = builder._pod_entrypoint();
    }
    assert "jac build" not in `entry["args"][0];
}


def _entrypoint_run(
    project: str,
    env: dict[str, str],
    cfg: (KubernetesConfig | None) = None,
    failing_tools: (list[str] | None) = None
) -> tuple[int, str, str] {
    import subprocess;
    import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
    cfg = cfg or KubernetesConfig(app_name="jac-shop", namespace="ns");
    script: str = ManifestBuilder(k8s_config=cfg)._pod_entrypoint()["args"][0];
    mount = f"cd {APP_MOUNT_PATH}; ";
    assert mount in script , script;
    script = script.replace(mount, f"cd {project}; ", 1);
    bin_dir = Path(project) / ".stub-bin";
    bin_dir.mkdir();
    record = Path(project) / ".jac-argv";
    stub = bin_dir / "jac";
    stub.write_text(f"#!/bin/sh\nprintf '%s\\n' \"$@\" > \"{record}\"\n");
    stub.chmod(0o755);
    for tool in (failing_tools or []) {
        broken = bin_dir / tool;
        broken.write_text("#!/bin/sh\nexit 1\n");
        broken.chmod(0o755);
    }
    run_env = dict(os.environ);
    run_env["PATH"] = f"{bin_dir}{os.pathsep}{run_env.get('PATH', '')}";
    run_env.pop("JAC_SV_FILE", None);
    run_env.update(env);
    proc = subprocess.run(
        ["bash", "-c", script], env=run_env, capture_output=True, text=True
    );
    argv = record.read_text() if record.is_file() else "";
    return (proc.returncode, argv, proc.stderr);
}


test "a failed system package install neither stops the boot nor drops the sibling flag" {
    # `fi && export JAC_SV_SIBLING=1` chained the export onto the apt block,
    # and `set -e` exempts the left side of `&&`: on any non-root image that
    # lacked the packages the install failed, the export was skipped, and the
    # pod entered local microservice mode with the whole fleet inside it
    # (jac#8935). The apt step is one best-effort statement now, and the flag
    # travels in the pod env, where a boot script cannot lose it.
    import tempfile;
    cfg = KubernetesConfig(
        app_name="jac-shop", namespace="ns", service_dependencies=["git", "curl"]
    );
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "svc.jac").write_text("");
        (rc, argv, err) = _entrypoint_run(
            project,
            {"JAC_SV_NAME": "svc", "JAC_SV_FILE": "svc.jac"},
            cfg=cfg,
            failing_tools=["dpkg-query", "apt-get"]
        );
        assert rc == 0 , err;
        assert argv.split() == ["run", "--serve", "svc.jac"] , argv;
        assert "could not install system packages (curl git)" in err , err;
    }
    script = ManifestBuilder(k8s_config=cfg)._pod_entrypoint()["args"][0];
    assert "fi && " not in script , script;
    assert "JAC_SV_SIBLING" not in script , (
        "the sibling flag is a property of the pod, not a boot-script side effect"
    );
}


test "every service pod carries the sibling flag in its env, and no override drops it" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(
        k8s_config=cfg,
        project_dir=str(_K8S_E2E_FIXTURE),
        fleet=fleet_of({"orders_app": "/orders"}, root_app="main", root_file="main.jac")
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    specs = builder.generate_service_pod_specs(app_cfg, "img");
    assert set(specs.keys()) == {"orders_app", "main", GATEWAY_NAME};
    for (name, spec) in specs.items() {
        env = {e["name"]: e["value"] for e in spec["containers"][0]["env"]};
        assert env.get("JAC_SV_SIBLING") == "1" , f"{name}: {env}";
    }
    overridden = builder._build_env("orders_app", {"env": {"JAC_SV_SIBLING": "0"}});
    values = [
        e["value"]
        for e in overridden
        if e["name"] == "JAC_SV_SIBLING"
    ];
    assert values == ["1"] , overridden;
}


test "a shared volume is handed to the runtime identity before the service starts" {
    # A PVC from [scale.gateway] shared_volumes arrives root-owned from most
    # provisioners, the service container runs as the image's `jac` user, and
    # nothing adjusted the mount: the first write into the volume the app
    # declared failed with EACCES (jac#8949). The bundle volume already solved
    # this with a root init container that chowns the mount root; a shared
    # volume gets the same container, plus fsGroup for the backends that honor
    # it.
    import from jaclang.scale.injector.pvc_injector {
        RUNTIME_UID,
        RUNTIME_GID,
        VOLUME_PERMS_NAME
    }
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    gateway = {
        "shared_volumes": [
            {
                "name": "workspace",
                "mount_path": "/app/.jachome/.jac-ide",
                "apps": ["orders_app"],
                "size": "1Gi",
                "access_mode": "ReadWriteMany",
                "storage_class": "standard"
            }
        ]
    };
    builder = ManifestBuilder(
        k8s_config=cfg,
        project_dir=str(_K8S_E2E_FIXTURE),
        fleet=fleet_of(
            {"orders_app": "/orders", "cart_app": "/cart"},
            root_app="main",
            root_file="main.jac"
        ),
        gateway_config=gateway
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    specs = builder.generate_service_pod_specs(app_cfg, "img");

    orders = specs["orders_app"];
    inits = orders["initContainers"];
    assert inits[0]["name"] == VOLUME_PERMS_NAME , [c["name"] for c in inits];
    perms = inits[0];
    assert perms["volumeMounts"]
        == [{"name": "workspace", "mountPath": "/app/.jachome/.jac-ide"}];
    script = perms["command"][-1];
    assert f'chown {RUNTIME_UID}:{RUNTIME_GID} "/app/.jachome/.jac-ide"'
        in script , script;
    assert "-R" not in script , "application data is never re-owned recursively";
    assert perms["securityContext"]["runAsUser"] == 0;
    assert perms["image"] == orders["containers"][0]["image"];
    assert orders["securityContext"]["fsGroup"] == RUNTIME_GID;
    assert orders["securityContext"]["fsGroupChangePolicy"] == "OnRootMismatch";

    cart = specs["cart_app"];
    assert VOLUME_PERMS_NAME not in [c["name"] for c in cart["initContainers"]];
    assert "securityContext" not in cart , "a pod without a shared volume is left as it was";
}


test "a service pod boots exactly the module the deploy resolved" {
    import tempfile;
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "svc.jac").write_text("");
        (Path(project) / "lib").mkdir();
        (Path(project) / "lib" / "svc.jac").write_text("");
        (rc, argv, err) = _entrypoint_run(
            project, {"JAC_SV_NAME": "svc", "JAC_SV_FILE": "svc.jac"}
        );
        assert rc == 0 , err;
        assert argv.split() == ["run", "--serve", "svc.jac"] , argv;
    }
}


test "a service pod refuses a file the bundle does not ship" {
    import tempfile;
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "svc.jac").write_text("");
        (rc, argv, err) = _entrypoint_run(
            project, {"JAC_SV_NAME": "svc", "JAC_SV_FILE": "lib/svc.jac"}
        );
        assert rc == 1 , (rc, err);
        assert argv == "" , argv;
        assert "does not contain" in err , err;
    }
}


test "a service pod with no resolved file refuses to guess" {
    import tempfile;
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "svc.jac").write_text("");
        (rc, argv, err) = _entrypoint_run(project, {"JAC_SV_NAME": "svc"});
        assert rc == 1 , (rc, err);
        assert argv == "" , argv;
        assert "JAC_SV_FILE is not set" in err , err;
    }
}


test "every app pod env carries its bundle-resolved file" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE), fleet=_shop_fleet()
    );
    orders = {e["name"]: e["value"] for e in builder._build_env("orders_app", {})};
    assert orders["JAC_SV_FILE"] == "orders_app.jac" , orders;
    web_env = {e["name"]: e["value"] for e in builder._build_env("web", {})};
    assert web_env["JAC_SV_FILE"] == "main.jac" , web_env;
}


def _routed_project(tmp: str, files: list[str]) -> str {
    for rel in files {
        p = Path(tmp) / rel;
        p.parent.mkdir(parents=True, exist_ok=True);
        p.write_text("def:pub ping -> str { return \"pong\"; }\n");
    }
    (Path(tmp) / "jac.toml").write_text("[project]\nname = \"mini\"\n");
    return tmp;
}


test "the pod env resolves the apps the deploy emits pods for" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        project = _routed_project(tmp, ["svc.jac", "lib/svc.jac", "main.jac"]);
        cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=project,
            fleet=fleet_of({"svc": "/svc"}, root_app="main"),
            dry_run=True
        );
        app_cfg = AppConfig(code_folder=project, app_name="jac-shop");
        specs = builder.generate_service_pod_specs(app_cfg, "img");
        env = {e["name"]: e["value"] for e in specs["svc"]["containers"][0]["env"]};
        assert env["JAC_SV_FILE"] == "svc.jac" , env;
        main_env = {
            e["name"]: e["value"] for e in specs["main"]["containers"][0]["env"]
        };
        assert main_env["JAC_SV_FILE"] == "main.jac" , main_env;
    }
}


test "the pod env carries the bundle-validated path, not the declared string" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        project = _routed_project(tmp, ["lib/svc.jac", "main.jac"]);
        cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=project,
            fleet=fleet_of({"svc": "/svc"}, files={"svc": "./lib/svc.jac"}),
            dry_run=True
        );
        env = {e["name"]: e["value"] for e in builder._build_env("svc", {})};
        assert env["JAC_SV_FILE"] == "lib/svc.jac" , env;
    }
}


test "the injector seals against the config the deploy emits pods for" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        project = _routed_project(tmp, ["svc.jac", "main.jac"]);
        cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=project,
            fleet=fleet_of({"svc": "/svc"}, root_app="main"),
            dry_run=True
        );
        app_cfg = AppConfig(code_folder=project, app_name="jac-shop");
        injector = builder._prepare_injector(app_cfg);
        assert injector._fleet is builder.fleet , injector._fleet;
        assert injector._fleet.routes() == {"svc": "/svc"};
        assert injector._fleet.root_app == "main";
    }
}


test "a routed service with no module fails manifest generation, dry run included" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        project = _routed_project(tmp, ["main.jac"]);
        cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=project,
            fleet=fleet_of({"ghost": "/ghost"}, root_app="main"),
            dry_run=True
        );
        app_cfg = AppConfig(code_folder=project, app_name="jac-shop");
        caught = "";
        try {
            builder.generate_manifests(app_cfg, "img");
        } except ValueError as e {
            caught = str(e);
        }
        assert "'ghost'" in caught , caught;
        assert "ghost.jac" in caught , caught;
    }
}


test "user env cannot point a pod at an arbitrary service file" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    env = builder._build_env(
        "orders", {"env": {"JAC_SV_FILE": "evil.jac", "JAC_SV_NAME": "evil"}}
    );
    values: dict[str, str] = {e["name"]: e["value"] for e in env};
    assert values["JAC_SV_NAME"] == "orders";
    assert "JAC_SV_FILE" not in values;
}


test "a single-file full-stack app still gets its client bundle built" {
    import tempfile;
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"todo-app\"\n\n[client]\n");
        }
        cfg = KubernetesConfig(app_name="todo-app", namespace="ns");
        builder = ManifestBuilder(k8s_config=cfg, project_dir=tmp);
        assert builder._has_client_source();
        assert builder._client_entry() == "main.jac";
    }
}


# Peer URL resolution. jac-scale injects a JAC_APP_<PEER>_URL for every peer, so
# the registry must read it rather than deriving every URL from the app name.
# The env key keeps the raw app name while Kubernetes names are RFC1123-safe,
# so orders_app injects JAC_APP_ORDERS_APP_URL beside an orders-app-service; a
# reader keyed off the safe name would miss and fall back to the derived URL.

glob _PEER_ROUTES: dict[str, str] = {"orders_app": "/orders", "cart_app": "/cart"},
     _PEER_NS: str = "shop",
     _PEER_PORT: int = 8000,
     _ORDERS_DERIVED: str = "http://orders-app-service.shop.svc.cluster.local:8000",
     _CART_DERIVED: str = "http://cart-app-service.shop.svc.cluster.local:8000";


def _peer_env_snapshot -> dict[str, str | None] {
    keys = [peer_url_env_key(name) for name in _PEER_ROUTES.keys()];
    keys.append("POD_NAMESPACE");
    return {key: os.environ.get(key) for key in keys};
}


def _peer_env_restore(saved: dict[str, str | None]) {
    for (key, value) in saved.items() {
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
}


def _peer_env_isolate {
    for name in _PEER_ROUTES.keys() {
        os.environ.pop(peer_url_env_key(name), None);
    }
    os.environ["POD_NAMESPACE"] = _PEER_NS;
}


def _peer_builder -> ManifestBuilder {
    cfg = KubernetesConfig(
        app_name="jac-shop", namespace=_PEER_NS, container_port=_PEER_PORT
    );
    return ManifestBuilder(
        k8s_config=cfg,
        project_dir=str(_K8S_E2E_FIXTURE),
        fleet=fleet_of(_PEER_ROUTES, root_app="web", root_file="main.jac")
    );
}


def _peer_env_of(svc_name: str) -> dict[str, str] {
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    specs = _peer_builder().generate_service_pod_specs(app_cfg, "img");
    return {
        `entry["name"]: `entry["value"]
        for `entry in specs[svc_name]["containers"][0]["env"]
    };
}


test "a peer with no override resolves by naming convention" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED , (
            f"expected the derived URL, got {registry['orders_app']}"
        );
        assert registry["cart_app"] == _CART_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
}


test "an override wins for its own peer and leaves the others derived" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ[peer_url_env_key("orders_app")] = standby;

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == standby;
        assert registry["cart_app"] == _CART_DERIVED , (
            "an override for one peer must not affect another"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# A pod never given an override and one whose override was blanked must behave
# the same, or clearing a value would break routing instead of restoring it.
test "a blank override falls back to the derived URL" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        os.environ[peer_url_env_key("orders_app")] = "   ";

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
}


# The literal is asserted rather than derived from peer_url_env_key, so a change
# to that helper fails here instead of moving both sides together. The override
# is a value the derivation cannot produce, so reading the wrong key shows up as
# a failure rather than an accidental match.
test "the key the builder injects is the key the registry reads" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        cart_env = _peer_env_of("cart_app");

        assert "JAC_APP_ORDERS_APP_URL" in cart_env , (
            "the builder no longer injects the underscore-preserving key; "
            f"it wrote {sorted(cart_env.keys())}"
        );

        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ["JAC_APP_ORDERS_APP_URL"] = standby;
        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == standby , (
            "the registry did not read the key the builder wrote, so it "
            f"resolved {registry['orders_app']}"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# Reading the env must be a no-op for existing deployments, which holds only
# while the injector and the resolver agree on namespace and port.
test "the injected default equals the derived URL under matching config" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        cart_env = _peer_env_of("cart_app");

        assert cart_env[peer_url_env_key("orders_app")] == _ORDERS_DERIVED , (
            "injected and derived URLs diverged, so reading the env would "
            "change behavior for existing pods"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# K8sRuntimeServiceResolver.url_for is the other k8s resolution site. It is
# dormant today, but it must not become the one path that bypasses an override
# once the admin ops that construct it are wired up.
def _peer_resolver -> K8sRuntimeServiceResolver {
    return K8sRuntimeServiceResolver(
        registry=ServiceRegistry(), namespace=_PEER_NS, port=_PEER_PORT
    );
}


test "url_for uses the override when one is set" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ[peer_url_env_key("orders_app")] = standby;

        `entry = ServiceEntry(
            name="orders_app", file="orders_app.jac", prefix="/orders"
        );

        assert _peer_resolver().url_for(`entry) == standby;
    } finally {
        _peer_env_restore(saved);
    }
}


test "url_for derives when no override is set" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        `entry = ServiceEntry(
            name="orders_app", file="orders_app.jac", prefix="/orders"
        );

        assert _peer_resolver().url_for(`entry) == _ORDERS_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
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
    assert with_config_revision(_deployment({"MARKER": "v1"}), "")
        == _deployment({"MARKER": "v1"}) , "an empty revision stamps nothing, so the caller has to fail loudly";
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
