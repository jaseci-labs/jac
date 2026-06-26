"""Tests for no-image microservice deploy (copy local source, install at startup)."""

import io;
import tarfile;
import base64;
import tempfile;
import shutil;
import unittest.mock as mock;
import from pathlib { Path }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.microservice.source_bundle {
    pack_source,
    build_source_configmap,
    source_configmap_name,
    build_bootstrap_init_container,
    pinned_install_commands,
    auto_no_image_fallback,
    decide_zeroconfig_image_strategy,
    IMAGE_STRATEGY_IMAGE,
    IMAGE_STRATEGY_NO_IMAGE,
    SOURCE_ARCHIVE_KEY,
    APP_MOUNT_PATH,
    PYDEPS_DIR
}

# =============================================================================
# source_bundle: packing
# =============================================================================
test "pack_source archives jac files and skips build artifacts" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / "orders_app.jac").write_text("to sv:\n");
    sub = Path(tmp) / "shared";
    sub.mkdir();
    (sub / "models.jac").write_text("obj X {}\n");
    # excluded artifacts
    cache = Path(tmp) / ".jac";
    cache.mkdir();
    (cache / "junk.jbc").write_text("nope");
    nm = Path(tmp) / "node_modules";
    nm.mkdir();
    (nm / "dep.js").write_text("nope");

    raw = pack_source(tmp);
    names = set();
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        for m in tar.getmembers() {
            names.add(m.name);
        }
    }

    assert "main.jac" in names;
    assert "orders_app.jac" in names;
    assert "shared/models.jac" in names;
    assert not any([n.startswith(".jac/") for n in names]);
    assert not any([n.startswith("node_modules/") for n in names]);

    shutil.rmtree(tmp);
}

test "pack_source ships a [plugins.scale]-stripped jac.toml; excludes other secrets" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / ".env").write_text("DB_PASSWORD=hunter2\n");
    (Path(tmp) / ".env.production").write_text("API_KEY=sk_live\n");
    (Path(tmp) / "jac.toml").write_text(
        "[project]\nname = \"shop\"\n\n"
        "[dependencies.npm]\nreact = \"^18\"\n\n"
        "[plugins.scale.kubernetes]\ndocker_password = \"hunter2\"\n"
        "registry_password = \"sekret\"\n\n"
        "[plugins.scale.microservices.client]\nentry = \"main.jac\"\n"
    );
    (Path(tmp) / "tls.key").write_text("PRIVATE KEY");
    (Path(tmp) / "server.pem").write_text("CERT");

    raw = pack_source(tmp);
    names = set();
    toml_body = "";
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        for m in tar.getmembers() {
            names.add(m.name);
            if m.name == "jac.toml" {
                toml_body = tar.extractfile(m).read().decode();
            }
        }
    }

    assert "main.jac" in names;
    # .env / key / cert files are still excluded outright.
    for secret in [".env", ".env.production", "tls.key", "server.pem"] {
        assert secret not in names , f"{secret} must not be packed into the ConfigMap";
    }
    # jac.toml IS shipped, but with the [plugins.scale...] tables (deploy creds)
    # stripped out...
    assert "jac.toml" in names;
    assert "docker_password" not in toml_body;
    assert "registry_password" not in toml_body;
    assert "plugins.scale" not in toml_body;
    # ...while the app + client-build config is retained (so jac build / jac start work).
    assert "[project]" in toml_body;
    assert "[dependencies.npm]" in toml_body;
    assert "react" in toml_body;

    shutil.rmtree(tmp);
}

# =============================================================================
# auto_no_image_fallback: zero-config default
# =============================================================================
test "auto_no_image_fallback: no image/registry/build -> True (fallback)" {
    assert auto_no_image_fallback(
        False, "jac-shop:latest", "jac-shop:latest", ""
    ) == True;
    # bare default image still counts as 'no explicit image'
    assert auto_no_image_fallback(False, "", "jac-shop:latest", "") == True;
}

test "auto_no_image_fallback: explicit image or registry or --build -> False" {
    # explicit (non-default) image
    assert auto_no_image_fallback(
        False, "myrepo/app:v1", "jac-shop:latest", ""
    ) == False;
    # registry configured
    assert auto_no_image_fallback(
        False, "jac-shop:latest", "jac-shop:latest", "ghcr.io/me"
    ) == False;
    # --build forces the image pipeline
    assert auto_no_image_fallback(
        True, "jac-shop:latest", "jac-shop:latest", ""
    ) == False;
}

# =============================================================================
# decide_zeroconfig_image_strategy: prefer a real image; no-image is last resort
# =============================================================================
test "strategy: docker + local cluster -> build a real image (no registry)" {
    # The win: a zero-config app on kind/k3d/minikube gets a REAL image built
    # and loaded with no registry, instead of the source-ConfigMap workaround.
    s = decide_zeroconfig_image_strategy(docker_usable=True, cluster_is_local=True);
    assert s.mode == IMAGE_STRATEGY_IMAGE;
    assert "real image" in s.reason;
}

test "strategy: no docker -> no-image is the only option" {
    s = decide_zeroconfig_image_strategy(docker_usable=False, cluster_is_local=True);
    assert s.mode == IMAGE_STRATEGY_NO_IMAGE;
    assert "docker" in s.reason;
    # docker absence dominates even if the cluster would otherwise be local
    s2 = decide_zeroconfig_image_strategy(docker_usable=False, cluster_is_local=False);
    assert s2.mode == IMAGE_STRATEGY_NO_IMAGE;
}

test "strategy: docker but remote cluster, no registry -> no-image fallback" {
    s = decide_zeroconfig_image_strategy(docker_usable=True, cluster_is_local=False);
    assert s.mode == IMAGE_STRATEGY_NO_IMAGE;
    assert "registry" in s.reason;
}

test "build_source_configmap holds the base64 archive in binaryData" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");

    cm = build_source_configmap("jac-shop", "jac-shop-dev", tmp);

    assert cm["kind"] == "ConfigMap";
    assert cm["metadata"]["name"] == "jac-shop-source";
    assert cm["metadata"]["namespace"] == "jac-shop-dev";
    assert cm["metadata"]["labels"]["jac-scale.role"] == "source";
    # binaryData value round-trips back to a valid gzip tar
    encoded = cm["binaryData"][SOURCE_ARCHIVE_KEY];
    raw = base64.b64decode(encoded);
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        assert "main.jac" in [m.name for m in tar.getmembers()];
    }

    shutil.rmtree(tmp);
}

test "build_source_configmap rejects oversized source trees" {
    tmp = tempfile.mkdtemp();
    # ~2MB of incompressible random-ish content blows the ConfigMap limit.
    import os;
    (Path(tmp) / "big.bin").write_bytes(os.urandom(2 * 1024 * 1024));
    raised = False;
    try {
        build_source_configmap("jac-shop", "default", tmp);
    } except ValueError {
        raised = True;
    }
    assert raised;
    shutil.rmtree(tmp);
}

test "pinned_install_commands install jac-scale[all] and requests --global, not jaclang" {
    cmds = pinned_install_commands("/app/.pydeps/bin/jac");
    joined = " ".join(cmds);
    # Extras ride in the spec as PEP 508 brackets: `jac install`'s --extras flag
    # is dropped for named packages, so `jac-scale[all]` is the only form that
    # actually installs the deploy/data/tracing deps the plugin needs in-pod.
    assert "install 'jac-scale[all]' --global" in joined;
    assert "--extras" not in joined;
    # requests is a scale-plugin runtime dep but ships only in jac-scale's
    # `test` extra, so it must be installed explicitly or the plugin can't load
    # in-pod (gateway crashes, services 404 on /healthz).
    assert "install requests --global" in joined;
    # --global is required: plugins must land in the binary's own site (shared
    # volume), not an ephemeral project venv the main container can't see.
    for c in cmds {
        assert "--global" in c;
    }
    # jaclang is the `jac` binary (fetched by install.sh), not a plugin spec.
    assert "jaclang" not in joined;
}

test "bootstrap init container fetches the jac binary and installs plugins" {
    init = build_bootstrap_init_container("python:3.12-slim");
    assert init["name"] == "jac-bootstrap";
    assert init["image"] == "python:3.12-slim";
    script = init["args"][0];
    assert "tar xzf" in script;
    # jaclang ships as the `jac` binary (not on PyPI); the installer fetches it
    # onto the main container's PATH (PYDEPS_DIR/bin), then plugins install
    # through the binary's resolver.
    assert "scripts/install.sh" in script;
    assert f"{PYDEPS_DIR}/bin/jac" in script;
    # Plugins install --global so they persist on the shared volume (not an
    # ephemeral project venv). Extras ride as PEP 508 brackets ('jac-scale[all]')
    # since `--extras` is silently dropped for named (non-editable) packages.
    assert "install 'jac-scale[all]' --global" in script;
    assert "install requests --global" in script;
    # Regression guard: no more pip-installing jaclang into a --target dir.
    assert "pip install" not in script;
    mount_names = {m["name"] for m in init["volumeMounts"]};
    assert "jac-app" in mount_names;
    assert "jac-source" in mount_names;
}

test "no-image pods get a startup probe; built-image pods do not" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    ni = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    nc = ni._build_service_pod_spec("orders_app", "ignored:image")["containers"][0];
    assert "startupProbe" in nc;
    assert nc["startupProbe"]["failureThreshold"] == 90;

    plain = MicroserviceManifestBuilder(k8s_config=cfg);
    pc = plain._build_service_pod_spec("orders_app", "jac-shop:dev-abc")["containers"][
        0
    ];
    assert "startupProbe" not in pc;
}

test "no-image gateway entrypoint builds the client when a client entry is set" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    b = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    p = mock.patch.object(b, "_client_entry", return_value="main.jac");
    p.start();
    gw = b._pod_entrypoint()["args"][0];
    p.stop();
    # The gateway builds the SPA before serving; non-fatal so the API still
    # comes up if the FE build fails.
    assert 'jac build "main.jac"' in gw;
    assert "exec jac scale gateway" in gw;
    assert "|| echo" in gw;

    # Built-image mode never builds in-pod (the image already has the bundle).
    plain = MicroserviceManifestBuilder(k8s_config=cfg);
    assert "jac build" not in plain._pod_entrypoint()["args"][0];

    # No-image but no client entry (backend-only app) -> no client build.
    nc = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    p2 = mock.patch.object(nc, "_client_entry", return_value="");
    p2.start();
    no_build = nc._pod_entrypoint()["args"][0];
    p2.stop();
    assert "jac build" not in no_build;
}

test "no-image pods default to higher memory (in-pod build); built-image stays small" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    ni = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    # service default: 4Gi limit / 1Gi request (jac install + compile in-pod).
    svc = ni._build_resources({});
    assert svc["limits"]["memory"] == "4Gi";
    assert svc["requests"]["memory"] == "1Gi";
    # gateway default: 8Gi limit / 2Gi request (also builds the client bundle).
    gw = ni._build_resources({}, is_gateway=True);
    assert gw["limits"]["memory"] == "8Gi";
    assert gw["requests"]["memory"] == "2Gi";
    # explicit config still wins over the default.
    assert ni._build_resources({"memory_limit": "512Mi"})["limits"]["memory"] == "512Mi";

    # built-image keeps the small Burstable defaults (no in-pod build).
    plain = MicroserviceManifestBuilder(k8s_config=cfg);
    pr = plain._build_resources({});
    assert pr["limits"]["memory"] == "1Gi";
    assert pr["requests"]["memory"] == "128Mi";
    assert plain._build_resources({}, is_gateway=True)["limits"]["memory"] == "2Gi";
}

test "injected microservices_config overrides the process jac.toml (platform deploys)" {
    cfg = KubernetesConfig(app_name="other-app", namespace="other-ns");
    injected = {"routes": {"svc_a": "/api/svc_a"}, "client": {"entry": "app.jac"}};
    b = MicroserviceManifestBuilder(
        k8s_config=cfg, no_image=True, microservices_config=injected
    );
    # _ms_cfg returns the injected config, not the deploying process's jac.toml.
    assert b._ms_cfg() == injected;
    # config consumers read through _ms_cfg, so the injected client entry drives
    # the in-pod gateway client build.
    assert b._client_entry() == "app.jac";

    # no injection -> falls back to the process config (a dict, no crash).
    plain = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    assert isinstance(plain._ms_cfg(), dict);
}

test "shared_ingress routes the deploy domain to the gateway (no [...ingress])" {
    cfg = KubernetesConfig(
        app_name="jac-shop",
        namespace="jac-shop-dev",
        shared_ingress=True,
        domain="shop.jaseci.app",
        shared_ingress_class="alb",
        shared_ingress_annotations={"alb.ingress.kubernetes.io/group.name": "shared"}
    );
    b = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);
    # [...ingress] unset, but config.shared_ingress + domain -> a gateway ingress
    # (this is the host-routed shared ALB/nginx subdomain a PaaS deploy needs).
    ing = b._build_ingress_manifest({});
    assert ing is not None;
    rule = ing["spec"]["rules"][0];
    assert rule["host"] == "shop.jaseci.app";
    backend = rule["http"]["paths"][0]["backend"]["service"];
    assert backend["name"] == "gateway-service";
    assert ing["spec"]["ingressClassName"] == "alb";
    annos = ing["metadata"]["annotations"];
    assert annos["alb.ingress.kubernetes.io/group.name"] == "shared";
    # ALB/ACM (no cert-manager annotation) terminates TLS at the LB -> no spec.tls.
    assert "tls" not in ing["spec"];

    # neither [...ingress] nor shared_ingress -> no ingress at all (unchanged).
    plain_cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    plain = MicroserviceManifestBuilder(k8s_config=plain_cfg, no_image=True);
    assert plain._build_ingress_manifest({}) is None;

    # cert-manager (nginx) shared controller gets a spec.tls block for its cert.
    cm_cfg = KubernetesConfig(
        app_name="jac-shop",
        namespace="ns",
        shared_ingress=True,
        domain="shop.example.com",
        shared_ingress_class="nginx",
        shared_ingress_tls=True,
        shared_ingress_annotations={"cert-manager.io/cluster-issuer": "letsencrypt"}
    );
    cm_ing = MicroserviceManifestBuilder(
        k8s_config=cm_cfg, no_image=True
    )._build_ingress_manifest(
        {}
    );
    assert cm_ing["spec"]["tls"][0]["hosts"] == ["shop.example.com"];
}

test "client entry auto-detects main.jac for a fullstack project (no [...client])" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");

    # fullstack project (ships a .cl.jac) with no [client] table -> auto main.jac
    # so the gateway still builds + serves the SPA.
    fs = tempfile.mkdtemp();
    (Path(fs) / "main.jac").write_text("to cl:\n");
    (Path(fs) / "frontend.cl.jac").write_text("# client\n");
    fs_b = MicroserviceManifestBuilder(
        k8s_config=cfg,
        no_image=True,
        project_dir=fs,
        microservices_config={"routes": {}}
    );
    assert fs_b._has_client_source();
    assert fs_b._client_entry() == "main.jac";

    # backend-only project (no .cl.jac) -> client build skipped.
    be = tempfile.mkdtemp();
    (Path(be) / "main.jac").write_text("to sv:\n");
    be_b = MicroserviceManifestBuilder(
        k8s_config=cfg,
        no_image=True,
        project_dir=be,
        microservices_config={"routes": {}}
    );
    assert not be_b._has_client_source();
    assert be_b._client_entry() == "";

    # an explicit [client].entry always wins over auto-detection.
    exp_b = MicroserviceManifestBuilder(
        k8s_config=cfg,
        no_image=True,
        project_dir=fs,
        microservices_config={"client": {"entry": "app.jac"}}
    );
    assert exp_b._client_entry() == "app.jac";

    shutil.rmtree(fs);
    shutil.rmtree(be);
}

test "experimental bootstrap git-clones the branch and zig-builds the binary" {
    init = build_bootstrap_init_container(
        "python:3.12-slim",
        experimental=True,
        repo_url="https://github.com/udithishanka/jaseci.git",
        branch="fix/no-image-bootstrap-deps"
    );
    script = init["args"][0];
    # jaclang is the self-contained `jac` binary: the checkout is compiled with
    # zig build (not pip-installed editable) so the pod runs the branch's jaclang.
    assert "zig build" in script;
    assert "/app/.jacbin/jac install -e ./jac-scale --extras all --global" in script;
    # Regression guard: no editable pip install (jac/pyproject.toml is gone).
    assert "pip install" not in script;
    # repo/branch ride as env data, referenced as $VARs - never spliced into the
    # script, so a hostile branch name can't inject shell.
    assert 'git clone --branch "$JACX_BRANCH"' in script;
    assert "fix/no-image-bootstrap-deps" not in script;
    env = {e["name"]: e["value"] for e in init["env"]};
    assert env["JACX_BRANCH"] == "fix/no-image-bootstrap-deps";
    assert env["JACX_REPO_URL"] == "https://github.com/udithishanka/jaseci.git";
    # build deps install on Debian and Alpine bases, and only when missing.
    assert "command -v git" in script;
    assert "apk add" in script;
}

test "experimental clone URL normalizes SCP/ssh GitHub URLs to https" {
    scp = build_bootstrap_init_container(
        "python:3.12-slim", experimental=True, repo_url="git@github.com:org/repo.git"
    );
    scp_env = {e["name"]: e["value"] for e in scp["env"]};
    assert scp_env["JACX_REPO_URL"] == "https://github.com/org/repo.git";

    ssh = build_bootstrap_init_container(
        "python:3.12-slim",
        experimental=True,
        repo_url="ssh://git@github.com/org/repo.git"
    );
    ssh_env = {e["name"]: e["value"] for e in ssh["env"]};
    assert ssh_env["JACX_REPO_URL"] == "https://github.com/org/repo.git";
}

# =============================================================================
# manifest_builder: no-image pod spec
# =============================================================================
test "no-image pod spec runs the python base image with source volumes" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);

    spec = builder._build_service_pod_spec("orders_app", "ignored:image");
    container = spec["containers"][0];

    # Generic base image, not a built app image.
    assert container["image"] == "python:3.12-slim";
    assert container["workingDir"] == APP_MOUNT_PATH;

    pairs = {e["name"]: e["value"] for e in container["env"]};
    assert pairs.get("PYTHONPATH") == PYDEPS_DIR;
    assert PYDEPS_DIR in pairs.get("PATH", "");

    mount_paths = {m["mountPath"] for m in container["volumeMounts"]};
    assert APP_MOUNT_PATH in mount_paths;

    vol_names = {v["name"] for v in spec["volumes"]};
    assert "jac-app" in vol_names;
    assert "jac-source" in vol_names;
    # source ConfigMap volume references the right ConfigMap name
    src_vol = next(
        (
            v
            for v in spec["volumes"]
            if v["name"] == "jac-source"
        ),
        None
    );
    assert src_vol["configMap"]["name"] == source_configmap_name("jac-shop");

    init_names = {c["name"] for c in spec["initContainers"]};
    assert "jac-bootstrap" in init_names;
}

test "generate_manifests (no-image) emits a source ConfigMap + python-base pods" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / "orders_app.jac").write_text("to sv:\n");

    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, no_image=True, project_dir=tmp
    );
    app_config = AppConfig(code_folder=tmp, file_name="main.jac", no_image=True);

    fake_cfg = mock.MagicMock();
    fake_cfg.get_microservices_config.return_value = {
        "routes": {"orders_app": "/api/orders"},
        "services": {},
        "ingress": {},
        "shared_volumes": [],
        "logs": {},
        "drain_timeout_seconds": 10
    };
    with mock.patch(
        "jac_scale.config_loader.get_scale_config", return_value=fake_cfg
    ) {
        bundle = builder.generate_manifests(app_config, "python:3.12-slim");
    }

    # The source ConfigMap is in the bundle and carries the packed archive.
    assert "source_configmap" in bundle;
    cm = bundle["source_configmap"];
    assert cm["metadata"]["name"] == "jac-shop-source";
    assert SOURCE_ARCHIVE_KEY in cm["binaryData"];

    # Both the service and the gateway run on the python base image.
    orders_dep = bundle["deployments"]["orders_app"];
    pod = orders_dep["spec"]["template"]["spec"];
    assert pod["containers"][0]["image"] == "python:3.12-slim";
    assert "jac-bootstrap" in {c["name"] for c in pod["initContainers"]};

    shutil.rmtree(tmp);
}


test "image-mode pod spec is unchanged (no source volumes / bootstrap)" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, no_image=False);

    spec = builder._build_service_pod_spec("orders_app", "jac-shop:dev-abc123");
    container = spec["containers"][0];

    assert container["image"] == "jac-shop:dev-abc123";
    assert "workingDir" not in container;
    assert "volumes" not in spec;
    assert "initContainers" not in spec;
}
