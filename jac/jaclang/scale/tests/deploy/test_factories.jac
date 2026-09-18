import unittest.mock;
import kubernetes;
import from typing { cast }
import from types { SimpleNamespace }
import from kubernetes.client.exceptions { ApiException }
import from kubernetes.config.config_exception { ConfigException }
import from jaclang.scale.models.resource_status { ResourceStatus }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerSpec, Trigger }
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes { kubernetes_target as kt_module }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.runtime.fleet { fleet_of }

def _as_any(v: any) -> any {
    return v;
}

test "deployment target factory creates kubernetes target" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    target = DeploymentTargetFactory.create("kubernetes", config);

    assert target is not None;
    assert hasattr(target, "deploy");
    assert hasattr(target, "destroy");
    assert hasattr(target, "get_status");
    assert hasattr(target, "scale");
    assert cast(any, target).k8s_config.app_name == "test-app";
}

test "kubernetes target creation auto-syncs missing deploy tooling globally" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.missing_capability_dists"
    ) as mock_missing, unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.ensure_global_capability"
    ) as mock_ensure {
        mock_missing.return_value = ["kubernetes>=34.1.0,<35.0.0"];
        target = DeploymentTargetFactory.create("kubernetes", config);
        assert target is not None;
        mock_ensure.assert_called_once_with("deploy.k8s");
    }

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.missing_capability_dists"
    ) as mock_missing, unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.ensure_global_capability"
    ) as mock_ensure {
        mock_missing.return_value = [];
        DeploymentTargetFactory.create("kubernetes-microservice", config);
        mock_ensure.assert_not_called();
    }
}

test "deployment target factory raises for unsupported target" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        DeploymentTargetFactory.create("unsupported", config);
    } except ValueError as e {
        raised = True;
        assert "Unsupported deployment target" in str(e);
    }
    assert raised , "Expected ValueError for unsupported target";
}

test "deployment target factory raises for not implemented target" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        DeploymentTargetFactory.create("aws", config);
    } except NotImplementedError as e {
        raised = True;
        assert "not yet implemented" in str(e);
    }
    assert raised , "Expected NotImplementedError for aws target";
}

test "kubernetes-microservice stays a working alias for the unified target" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    aliased = DeploymentTargetFactory.create("kubernetes-microservice", config);
    plain = DeploymentTargetFactory.create("kubernetes", config);

    assert aliased is not None;
    assert type(aliased) is type(plain);
    assert hasattr(aliased, "deploy");
    assert hasattr(aliased, "destroy");
}

test "utility factory creates standard logger" {
    logger = UtilityFactory.create_logger("standard");

    assert logger is not None;
    assert hasattr(logger, "info");
    assert hasattr(logger, "error");
    assert hasattr(logger, "warn");
    assert hasattr(logger, "debug");
}

test "utility factory defaults to standard logger" {
    logger = UtilityFactory.create_logger();

    assert logger is not None;
    assert hasattr(logger, "info");
}

test "kubernetes config from dict" {
    config_dict = {
        "app_name": "my-app",
        "namespace": "test-ns",
        "container_port": 9000,
        "ingress_node_port": 30082,
        "postgres_enabled": False
    };

    config = KubernetesConfig.from_dict(KubernetesConfig, config_dict);

    assert config.app_name == "my-app";
    assert config.namespace == "test-ns";
    assert config.container_port == 9000;
    assert config.ingress_node_port == 30082;
    # The retired boolean migrates onto the tri-state it could only half express.
    assert config.database_mode == "none";
    assert config.database_enabled() is False;
}

test "kubernetes config database_mode survives a to_dict round trip" {
    config = KubernetesConfig.from_dict(
        KubernetesConfig,
        {
            "app_name": "my-app",
            "namespace": "test-ns",
            "database_mode": "external",
            "database_url": "postgresql://u@db.other-ns.svc.cluster.local:5432/app",
            "database_namespace": "other-ns"
        }
    );
    round_tripped = KubernetesConfig.from_dict(KubernetesConfig, config.to_dict());

    assert round_tripped.database_mode == "external";
    assert round_tripped.database_url
        == "postgresql://u@db.other-ns.svc.cluster.local:5432/app";
    assert round_tripped.database_namespace == "other-ns";
    assert round_tripped.database_enabled() is True;
}

test "kubernetes config rejects an unknown database_mode" {
    raised = False;
    try {
        KubernetesConfig.from_dict(
            KubernetesConfig, {"app_name": "my-app", "database_mode": "maybe"}
        );
    } except ValueError as e {
        raised = True;
        assert "database_mode" in str(e);
    }
    assert raised , "Expected ValueError for an unknown database_mode";
}

test "direct construction rejects an unknown database_mode too" {
    # from_dict is not the only way in: a platform service builds the config
    # object itself, and an unvalidated mode would sail past database_enabled().
    raised = False;
    try {
        KubernetesConfig(app_name="my-app", database_mode="maybe");
    } except ValueError as e {
        raised = True;
        assert "database_mode" in str(e);
    }
    assert raised , "Expected ValueError constructing KubernetesConfig with an unknown database_mode";
}

test "direct construction canonicalizes a non-canonical database_mode" {
    # ' NONE ' asks for no database; without normalization database_enabled()
    # answered True and the deploy gate ran backwards.
    config = KubernetesConfig(app_name="my-app", database_mode=" NONE ");

    assert config.database_mode == "none";
    assert config.database_enabled() is False;
    assert config.database_deploy_intent("my-app")["database_mode"] == "none";
    assert config.to_dict()["database_mode"] == "none";

    mixed_case = KubernetesConfig(app_name="my-app", database_mode="External");
    assert mixed_case.database_mode == "external";
    assert mixed_case.database_enabled() is True;
}

test "app config creation" {
    app_config = AppConfig(
        code_folder="/path/to/code", file_name="main.jac", no_image=True
    );

    assert app_config.code_folder == "/path/to/code";
    assert app_config.file_name == "main.jac";
    assert app_config.no_image is True;
    assert app_config.testing is False;
}

test "deployment target with logger" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget"
    ) as mock_kubernetes_target {
        mock_target = unittest.mock.MagicMock();
        mock_kubernetes_target.return_value = mock_target;
        config = {"app_name": "test-app", "namespace": "default"};
        logger = UtilityFactory.create_logger("standard");
        DeploymentTargetFactory.create("kubernetes", config, logger);
        mock_kubernetes_target.assert_called_once();
        call_kwargs = mock_kubernetes_target.call_args[1];
        assert "logger" in call_kwargs;
        assert call_kwargs["logger"] == logger;
    }
}

test "deployment target factory register and create custom target" {
    mock_target = unittest.mock.MagicMock();

    def custom_factory(config: dict[str, any], logger: any = None) -> any {
        mock_target.config = config;
        mock_target.logger = logger;
        return mock_target;
    }

    DeploymentTargetFactory.register("custom-test", custom_factory);
    config = {"app_name": "custom-app", "namespace": "custom-ns"};
    result = DeploymentTargetFactory.create("custom-test", config);
    assert result is mock_target;
    assert result.config == config;

    del DeploymentTargetFactory._registry["custom-test"];
}

test "deployment target factory custom target with logger" {
    calls: list[dict[str, any]] = [];

    def custom_factory(config: dict[str, any], logger: any = None) -> any {
        calls.append({"config": config, "logger": logger});
        return unittest.mock.MagicMock();
    }

    DeploymentTargetFactory.register("logged-test", custom_factory);
    logger = UtilityFactory.create_logger("standard");
    config = {"app_name": "test"};
    DeploymentTargetFactory.create("logged-test", config, logger);
    assert len(calls) == 1;
    assert calls[0]["config"] == config;
    assert calls[0]["logger"] == logger;

    del DeploymentTargetFactory._registry["logged-test"];
}

test "deployment target factory custom target overrides builtin" {
    mock_target = unittest.mock.MagicMock();

    def override_factory(config: dict[str, any], logger: any = None) -> any {
        return mock_target;
    }

    DeploymentTargetFactory.register("kubernetes", override_factory);
    result = DeploymentTargetFactory.create("kubernetes", {"app_name": "test"});
    assert result is mock_target;

    del DeploymentTargetFactory._registry["kubernetes"];
}

test "autoscaler factory creates hpa autoscaler for engine=hpa" {
    autoscaler = AutoscalerFactory.create("hpa", {});
    assert isinstance(autoscaler, HPAAutoscaler);
}

test "autoscaler factory creates hpa autoscaler for engine=None" {
    autoscaler = AutoscalerFactory.create(None, {});
    assert isinstance(autoscaler, HPAAutoscaler);
}

test "autoscaler factory raises for unsupported engine" {
    raised = False;
    try {
        AutoscalerFactory.create("unsupported", {});
    } except ValueError as e {
        raised = True;
        assert "Unsupported autoscaler engine" in str(e);
    }
    assert raised , "Expected ValueError for unsupported engine";
}

test "autoscaler factory register and create custom engine" {
    mock_autoscaler = unittest.mock.MagicMock();

    def custom_factory(config: dict[str, any], logger: any = None) -> any {
        return mock_autoscaler;
    }

    AutoscalerFactory.register("custom-scaler", custom_factory);
    try {
        result = AutoscalerFactory.create("custom-scaler", {});
        assert result is mock_autoscaler;
    } finally {
        del AutoscalerFactory._registry["custom-scaler"];
    }
}

test "autoscaler factory custom engine overrides builtin" {
    mock_autoscaler = unittest.mock.MagicMock();

    def override_factory(config: dict[str, any], logger: any = None) -> any {
        return mock_autoscaler;
    }

    AutoscalerFactory.register("hpa", override_factory);
    try {
        result = AutoscalerFactory.create("hpa", {});
        assert result is mock_autoscaler;
    } finally {
        del AutoscalerFactory._registry["hpa"];
    }
}

test "hpa autoscaler build manifests produces correct dict" {
    spec = AutoscalerSpec(
        scale_target_name="my-service-deployment",
        autoscaler_name="my-service-hpa",
        namespace="default",
        min_replicas=1,
        max_replicas=3,
        triggers=[Trigger(type="cpu", metadata={"averageUtilization": "70"})]
    );
    result = HPAAutoscaler()._build_manifests(spec);
    expected = [
        {
            "apiVersion": "autoscaling/v2",
            "kind": "HorizontalPodAutoscaler",
            "metadata": {
                "name": "my-service-hpa",
                "namespace": "default",
                "labels": {"app": "my-service-deployment", "managed": "jac-scale"}
            },
            "spec": {
                "scaleTargetRef": {
                    "apiVersion": "apps/v1",
                    "kind": "Deployment",
                    "name": "my-service-deployment"
                },
                "minReplicas": 1,
                "maxReplicas": 3,
                "metrics": [
                    {
                        "type": "Resource",
                        "resource": {
                            "name": "cpu",
                            "target": {"type": "Utilization", "averageUtilization": 70}
                        }
                    }
                ],
                "behavior": {
                    "scaleUp": {
                        "stabilizationWindowSeconds": 60,
                        "policies": [{"type": "Pods", "value": 2, "periodSeconds": 60}]
                    },
                    "scaleDown": {
                        "stabilizationWindowSeconds": 300,
                        "policies": [
                            {"type": "Percent", "value": 50, "periodSeconds": 60}
                        ]
                    }
                }
            }
        }
    ];
    assert result == expected;
}

test "hpa autoscaler build manifests applies behavior_overlay onto the default shape" {
    spec = AutoscalerSpec(
        scale_target_name="my-service-deployment",
        autoscaler_name="my-service-hpa",
        namespace="default",
        min_replicas=1,
        max_replicas=3,
        triggers=[Trigger(type="cpu", metadata={"averageUtilization": "70"})],
        behavior_overlay={
            "scaleDown": {
                "stabilizationWindowSeconds": 600,
                "selectPolicy": "Min",
                "policies": [{"type": "Pods", "value": 2, "periodSeconds": 300}]
            }
        }
    );
    result = HPAAutoscaler()._build_manifests(spec)[0];
    behavior = result["spec"]["behavior"];
    assert behavior["scaleDown"]["stabilizationWindowSeconds"] == 600;
    assert behavior["scaleDown"]["selectPolicy"] == "Min";
    assert behavior["scaleDown"]["policies"]
        == [{"type": "Pods", "value": 2, "periodSeconds": 300}];
    assert behavior["scaleUp"]["stabilizationWindowSeconds"] == 60;
}

test "autoscaler factory creates keda autoscaler for engine=keda" {
    autoscaler = AutoscalerFactory.create("keda", {});
    assert isinstance(autoscaler, KEDAAutoscaler);
}

test "autoscaler factory error message lists both hpa and keda as valid engines" {
    raised = False;
    try {
        AutoscalerFactory.create("unknown-engine", {});
    } except ValueError as e {
        raised = True;
        assert "hpa" in str(e);
        assert "keda" in str(e);
    }
    assert raised , "Expected ValueError for unknown engine";
}

test "hpa resource_name_for returns target name with hpa suffix" {
    hpa = AutoscalerFactory.create("hpa", {});
    assert hpa.resource_name_for("my-app") == "my-app-hpa";
}

test "keda resource_name_for returns target name with scaledobject suffix" {
    keda = AutoscalerFactory.create("keda", {});
    assert keda.resource_name_for("my-app") == "my-app-scaledobject";
}

test "hpa apply deletes competing ScaledObject when switching from keda engine" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        with unittest.mock.patch(
            "jaclang.scale.deploy.autoscale.hpa_autoscaler.client"
        ) as mock_client {
            mock_v2_cls.return_value.read_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
                status=404
            );
            HPAAutoscaler().apply(spec);
            _as_any(
                mock_client
            ).CustomObjectsApi.return_value.delete_namespaced_custom_object.assert_called_once_with(
                group="keda.sh",
                version="v1alpha1",
                namespace="default",
                plural="scaledobjects",
                name="svc-scaledobject"
            );
        }
    }
}

test "hpa apply engine-switch ScaledObject deletion is a no-op when no ScaledObject exists" {
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        with unittest.mock.patch(
            "jaclang.scale.deploy.autoscale.hpa_autoscaler.client"
        ) as mock_client {
            mock_v2_cls.return_value.read_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
                status=404
            );
            _as_any(
                mock_client
            ).CustomObjectsApi.return_value.delete_namespaced_custom_object.side_effect = ApiException(
                status=404
            );
            result = HPAAutoscaler().apply(spec);
            assert result == True;
        }
    }
}

test "hpa destroy collection also sweeps competing KEDA resources" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.autoscale.hpa_autoscaler.client"
        ) as mock_client {
            _as_any(
                mock_client
            ).CustomObjectsApi.return_value.list_namespaced_custom_object.return_value = {
                "items": []
            };
            HPAAutoscaler().destroy_collection("default", "managed=jac-scale");
            assert _as_any(
                mock_client
            ).CustomObjectsApi.return_value.list_namespaced_custom_object.call_count
                == 2;
        }
    }
}

test "kubernetes_target falls back to in-cluster config when kubeconfig is unavailable" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};
    target = DeploymentTargetFactory.create("kubernetes", config);

    fake_cfg = unittest.mock.MagicMock();
    # Simulate running in a pod: no ~/.kube/config, so load_kube_config raises.
    fake_cfg.load_kube_config.side_effect = ConfigException("no kubeconfig");
    # Halt after the fallback; get_status folds the error into an UNKNOWN status.
    fake_cfg.load_incluster_config.side_effect = RuntimeError("stop after fallback");

    with unittest.mock.patch.object(kt_module, "k8s_cluster_config", fake_cfg) {
        target.get_status("test-app");
    }

    # The except ConfigException clause must catch and reach the in-cluster fallback.
    fake_cfg.load_kube_config.assert_called_once();
    fake_cfg.load_incluster_config.assert_called_once();
}

def _status_apis(replicas: int, ready: int) -> tuple[any, ...] {
    apps = unittest.mock.MagicMock();
    apps.read_namespaced_deployment.return_value = SimpleNamespace(
        spec=SimpleNamespace(replicas=replicas),
        status=SimpleNamespace(ready_replicas=ready)
    );
    core = unittest.mock.MagicMock();
    return (apps, core);
}

def _seed_ms_config(ms_toml: str) -> str {
    # get_status's own call site builds ManifestBuilder(k8s_config=..., logger=...)
    # with no fleet kwarg, so _service_config()/_service_key_for_deployment()
    # fall back to reading get_scale_config()'s live singleton. Point that at a
    # real seeded jac.toml so get_status drives real per-app config resolution
    # end to end instead of one told what to answer. That seam
    # (autoscaler_config_for_deployment mocked outright) is what let a broken
    # _service_key_for_deployment or a type-blind is_scale_to_zero_eligible
    # through with every test green.
    import tempfile;
    import from pathlib { Path }
    project_dir = tempfile.mkdtemp(prefix="jac-status-test-");
    toml_body = "[project]\nname = \"status-test\"\n" + ms_toml;
    (Path(project_dir) / "jac.toml").write_text(toml_body);
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}

def _teardown_ms_config(project_dir: str) {
    import shutil;
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}

def _get_status(
    target: any,
    ms_toml: str,
    replicas: int,
    ready: int,
    deployment_name: str = "order-service-deployment"
) -> any {
    (apps, core) = _status_apis(replicas, ready);
    project_dir = _seed_ms_config(ms_toml);
    try {
        with unittest.mock.patch.object(
            kubernetes.client, "AppsV1Api", return_value=apps
        ) {
            with unittest.mock.patch.object(
                kubernetes.client, "CoreV1Api", return_value=core
            ) {
                with unittest.mock.patch.object(target, "_load_cluster_config") {
                    return target.get_status(deployment_name);
                }
            }
        }
    } finally {
        _teardown_ms_config(project_dir);
    }
}

def _hpa_toml(trigger_type: str | None) -> str {
    triggers = (f"\n[[apps.order-service.scale.triggers]]\ntype = \"{trigger_type}\"\n")
        if trigger_type
        else "";
    return (
        "[apps.order-service]\n"
        "kind = \"service\"\n"
        "entry-point = \"order_service\"\n"
        "\n[apps.order-service.scale.hpa]\n"
        "min = 0\n"
        "max = 3\n"
        + triggers
    );
}

test "get_status resolves zero-replica eligibility through a real ManifestBuilder: a real trigger parks under keda, a cpu-only or missing trigger still fails, an http_activation service parks regardless of engine, the gateway never borrows that exemption, and the plain HPA engine never parks" {
    keda_target = DeploymentTargetFactory.create(
        "kubernetes",
        {"app_name": "order-service", "namespace": "ns", "autoscaler_engine": "keda"}
    );
    hpa_target = DeploymentTargetFactory.create(
        "kubernetes", {"app_name": "order-service", "namespace": "ns"}
    );

    info = _get_status(keda_target, _hpa_toml("cron"), replicas=0, ready=0);
    assert info.status == ResourceStatus.STOPPED , (
        f"a real non-cpu/memory trigger under keda must resolve through the "
        f"real service-key lookup and park at zero, got {info.status}"
    );
    assert not info.is_ready() , "a parked-at-zero deployment is not ready to serve";

    info = _get_status(hpa_target, _hpa_toml("cron"), replicas=0, ready=0);
    assert info.status == ResourceStatus.FAILED , (
        f"the plain HPA engine cannot scale to zero by design: {info.status}"
    );

    info = _get_status(keda_target, _hpa_toml("cpu"), replicas=0, ready=0);
    assert info.status == ResourceStatus.FAILED , (
        f"a cpu-only trigger can never reach zero, so this must still be a "
        f"real failure, not STOPPED: {info.status}"
    );

    info = _get_status(keda_target, _hpa_toml(None), replicas=0, ready=0);
    assert info.status == ResourceStatus.FAILED , (
        f"no configured trigger at all must still be a real failure: {info.status}"
    );

    # An http_activation service has no hpa/triggers of its own -- its replica
    # floor defaults to min=1 with no keda triggers at all, which
    # is_scale_to_zero_eligible alone would call a real failure. Regression
    # cover for the worker in #8779's rpc-wake fixture: an http_activation app
    # parked at zero used to report FAILED here even though it is
    # scale-to-zero by design.
    http_activation_toml = (
        "[apps.order-service]\n"
        "kind = \"service\"\n"
        "entry-point = \"order_service\"\n"
        "\n[apps.order-service.scale.http_activation]\n"
        "enabled = true\n"
    );
    info = _get_status(hpa_target, http_activation_toml, replicas=0, ready=0);
    assert info.status == ResourceStatus.STOPPED , (
        f"an http_activation service parked at zero must resolve to STOPPED, "
        f"not FAILED: {info.status}"
    );

    # _resolve_scaling always forces the gateway out of HTTP_ACTIVATION (it is
    # the ingress entry point and must stay warm), so a zero-replica gateway
    # must not borrow that exemption from the shared default either.
    gateway_target = DeploymentTargetFactory.create(
        "kubernetes",
        {
            "app_name": "order-service",
            "namespace": "ns",
            "http_activation": {"enabled": True}
        }
    );
    info = _get_status(
        gateway_target,
        _hpa_toml(None),
        replicas=0,
        ready=0,
        deployment_name="gateway-deployment"
    );
    assert info.status == ResourceStatus.FAILED , (
        f"the gateway must never be treated as intentionally parked via the "
        f"shared http_activation default: {info.status}"
    );
}

test "get_status reports FAILED, not UNKNOWN and not a raised exception, when the real hpa config cannot be parsed" {
    keda_target = DeploymentTargetFactory.create(
        "kubernetes",
        {"app_name": "order-service", "namespace": "ns", "autoscaler_engine": "keda"}
    );
    # hpa.min must be int()-able; a real project can absolutely get this
    # wrong (a stray quoted value, an env-var placeholder left unresolved).
    # autoscaler_config_for_deployment must not be allowed to take a
    # read-only status check down over it.
    malformed_toml = (
        "[apps.order-service]\n"
        "kind = \"service\"\n"
        "entry-point = \"order_service\"\n"
        "\n[apps.order-service.scale.hpa]\n"
        "min = \"banana\"\n"
        "max = 3\n"
    );

    info = _get_status(keda_target, malformed_toml, replicas=0, ready=0);

    assert info.status == ResourceStatus.FAILED , (
        f"a config the real chain cannot parse must resolve to the same "
        f"FAILED verdict as any other non-eligible zero-replica deployment, "
        f"not UNKNOWN: {info.status}"
    );
}

test "get_status resolves scale-to-zero eligibility for an app name with an underscore" {
    # The app_name deliberately has an underscore: the real k8s Deployment is
    # always named via k8s_safe_name (order-service-deployment, hyphen), so
    # this only passes if _service_key_for_deployment resolves the real
    # declared app name ("order_service") rather than coincidentally matching
    # the mangled k8s name -- the same real-name-mangling case
    # autoscaler_config_for_deployment is already tested against below, but
    # driven through the live get_scale_config() fallback instead of a
    # hand-built fleet.
    keda_target = DeploymentTargetFactory.create(
        "kubernetes",
        {"app_name": "order_service", "namespace": "ns", "autoscaler_engine": "keda"}
    );
    solo_toml = (
        "[apps.order_service]\n"
        "kind = \"service\"\n"
        "entry-point = \"order_service\"\n"
        "\n[apps.order_service.scale.hpa]\n"
        "min = 0\n"
        "max = 3\n"
        "\n[[apps.order_service.scale.triggers]]\n"
        "type = \"cron\"\n"
    );

    info = _get_status(keda_target, solo_toml, replicas=0, ready=0);

    assert info.status == ResourceStatus.STOPPED , (
        f"a real trigger under keda must resolve through the real app name "
        f"the same way a hyphenated one does, and park at zero, got "
        f"{info.status}"
    );
}

test "autoscaler_config_for_deployment and http_activation_config_for_deployment resolve a service's real k8s Deployment name back to its config key" {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="jac-shop", namespace="ns"),
        fleet=fleet_of(
            {"order_service": "/orders", "cart_service": "/cart"},
            overrides={
                "order_service": {
                    "hpa": {"min": 0, "max": 2},
                    "triggers": [{"type": "cron", "metadata": {}}],
                    "http_activation": {"enabled": True}
                }
            }
        )
    );

    cfg = mb.autoscaler_config_for_deployment("order-service-deployment");
    assert cfg is not None and cfg["min"] == 0 , (
        f"the real k8s Deployment name (with its '_' -> '-' k8s_safe_name "
        f"mangling and '-deployment' suffix) must resolve back to the "
        f"'order_service' config key, not fall back to defaults: {cfg}"
    );

    # Same service-key resolution feeds http_activation_config_for_deployment
    # -- it must land on the same 'order_service' key, not fall back to None.
    http_cfg = mb.http_activation_config_for_deployment("order-service-deployment");
    assert http_cfg is not None , (
        f"the real k8s Deployment name must resolve back to the "
        f"'order_service' config key here too: {http_cfg}"
    );
}

test "autoscaler_config_for_deployment resolves the gateway's deployment name, and http_activation_config_for_deployment always returns None for it" {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="jac-shop", namespace="ns", http_activation={"enabled": True}
        ),
        fleet=fleet_of({"order_service": "/orders"})
    );

    # No per-service config for the gateway means hpa defaults (min=1), but the
    # key resolution itself must not raise and must not collide with a real
    # service -- this only proves the gateway's synthetic name resolves at all.
    cfg = mb.autoscaler_config_for_deployment("gateway-deployment");
    assert cfg is not None and cfg["min"] == 1;

    # _resolve_scaling always forces the gateway out of HTTP_ACTIVATION -- it
    # is the ingress entry point and must stay warm -- so it must never
    # resolve an http_activation config even under the shared default enabled
    # here.
    http_cfg = mb.http_activation_config_for_deployment("gateway-deployment");
    assert http_cfg is None , (
        f"the gateway must never resolve an http_activation config: {http_cfg}"
    );
}
