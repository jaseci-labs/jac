import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
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

test "deployment target factory creates kubernetes target" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    target = DeploymentTargetFactory.create("kubernetes", config);

    assert target is not None;
    assert hasattr(target, "deploy");
    assert hasattr(target, "destroy");
    assert hasattr(target, "get_status");
    assert hasattr(target, "scale");
    assert target.k8s_config.app_name == "test-app";
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

test "deployment target factory creates kubernetes-microservice target" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    target = DeploymentTargetFactory.create("kubernetes-microservice", config);

    assert target is not None;
    assert hasattr(target, "deploy");
    assert hasattr(target, "destroy");
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
        "mongodb_enabled": False,
        "redis_enabled": False
    };

    config = KubernetesConfig.from_dict(KubernetesConfig, config_dict);

    assert config.app_name == "my-app";
    assert config.namespace == "test-ns";
    assert config.container_port == 9000;
    assert config.ingress_node_port == 30082;
    assert config.mongodb_enabled is False;
    assert config.redis_enabled is False;
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
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.KubernetesTarget"
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

    def custom_factory(config: dict, logger: object = None) -> object {
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
    calls: list = [];

    def custom_factory(config: dict, logger: object = None) -> object {
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

    def override_factory(config: dict, logger: object = None) -> object {
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

    def custom_factory(config: dict, logger: object = None) -> object {
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

    def override_factory(config: dict, logger: object = None) -> object {
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
    expected = {
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
            ]
        }
    };
    assert result == expected;
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
            mock_client.CustomObjectsApi.return_value.delete_namespaced_custom_object.assert_called_once_with(
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
            mock_client.CustomObjectsApi.return_value.delete_namespaced_custom_object.side_effect = ApiException(
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
            mock_client.CustomObjectsApi.return_value.list_namespaced_custom_object.return_value = {
                "items": []
            };
            HPAAutoscaler().destroy_collection("default", "managed=jac-scale");
            assert mock_client.CustomObjectsApi.return_value.list_namespaced_custom_object.call_count == 2;
        }
    }
}
