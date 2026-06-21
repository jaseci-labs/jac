"""Tests for the new factory-based architecture."""

import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.autoscaler_factory { AutoscalerFactory }
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.abstractions.autoscaler { AutoscalerSpec, Trigger }
import from jac_scale.abstractions.autoscalers.hpa_autoscaler { HPAAutoscaler }
import from jac_scale.abstractions.autoscalers.keda_autoscaler { KEDAAutoscaler }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }

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

test "image registry factory creates dockerhub" {
    config = {
        "app_name": "test-app",
        "docker_username": "testuser",
        "docker_password": "testpass"
    };

    registry = ImageRegistryFactory.create("dockerhub", config);

    assert registry is not None;
    assert hasattr(registry, "build_image");
    assert hasattr(registry, "push_image");
    assert hasattr(registry, "get_image_url");
    assert registry.docker_username == "testuser";
}

test "image registry factory raises for unsupported registry" {
    config = {"app_name": "test-app"};

    raised = False;
    try {
        ImageRegistryFactory.create("unsupported", config);
    } except ValueError as e {
        raised = True;
        assert "Unsupported image registry" in str(e);
    }
    assert raised , "Expected ValueError for unsupported registry";
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
        code_folder="/path/to/code", file_name="main.jac", build=True
    );

    assert app_config.code_folder == "/path/to/code";
    assert app_config.file_name == "main.jac";
    assert app_config.build is True;
    assert app_config.testing is False;
}

test "deployment target with logger" {
    # KubernetesTarget is lazily imported inside create() (gated by
    # require_optional), so patch it at its source module, not on the factory.
    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.KubernetesTarget"
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
    # Clean up registry
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
    # Clean up registry
    del DeploymentTargetFactory._registry["logged-test"];
}

test "deployment target factory custom target overrides builtin" {
    mock_target = unittest.mock.MagicMock();

    def override_factory(config: dict, logger: object = None) -> object {
        return mock_target;
    }

    # Register a custom 'kubernetes' target to override the built-in
    DeploymentTargetFactory.register("kubernetes", override_factory);
    result = DeploymentTargetFactory.create("kubernetes", {"app_name": "test"});
    assert result is mock_target;
    # Clean up - restore built-in behavior
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
    # Ensures "keda" is a registered built-in engine — not just a custom override.
    # This test will fail until KEDAAutoscaler and its factory registration exist.
    autoscaler = AutoscalerFactory.create("keda", {});
    assert isinstance(autoscaler, KEDAAutoscaler);
}

test "autoscaler factory error message lists both hpa and keda as valid engines" {
    # When an operator typos the engine name they need to see valid options in the
    # error.  A message that only says "hpa" after Phase 2 is shipped is misleading.
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
    # Callers that formerly hardcoded f'{name}-hpa' must switch to this method.
    # The test pins the exact contract so a rename doesn't silently break destroy.
    hpa = AutoscalerFactory.create("hpa", {});
    assert hpa.resource_name_for("my-app") == "my-app-hpa";
}

test "keda resource_name_for returns target name with scaledobject suffix" {
    # destroy() on the Kubernetes target looks up the ScaledObject by name.
    # A suffix mismatch means destroy() tries to delete a non-existent resource
    # and the ScaledObject stays alive, continuing to scale the workload.
    keda = AutoscalerFactory.create("keda", {});
    assert keda.resource_name_for("my-app") == "my-app-scaledobject";
}

test "hpa apply deletes competing ScaledObject when switching from keda engine" {
    # If an operator switches autoscaler_engine from keda to hpa and redeploys,
    # the old ScaledObject stays on the cluster and fights the new HPA for
    # spec.replicas.  apply() must attempt to remove it before writing the HPA.
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    with unittest.mock.patch(
        "jac_scale.abstractions.autoscalers.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        with unittest.mock.patch(
            "jac_scale.abstractions.autoscalers.hpa_autoscaler.client"
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
    # 404 or 422 on the ScaledObject delete means nothing to clean up; must not raise.
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    with unittest.mock.patch(
        "jac_scale.abstractions.autoscalers.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        with unittest.mock.patch(
            "jac_scale.abstractions.autoscalers.hpa_autoscaler.client"
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
    # destroy_collection is called on teardown.  Any ScaledObjects and
    # TriggerAuthentications left from a prior keda-engine deploy must be removed.
    with unittest.mock.patch(
        "jac_scale.abstractions.autoscalers.hpa_autoscaler.AutoscalingV2Api"
    ) {
        with unittest.mock.patch(
            "jac_scale.abstractions.autoscalers.hpa_autoscaler.client"
        ) as mock_client {
            mock_client.CustomObjectsApi.return_value.list_namespaced_custom_object.return_value = {
                "items": []
            };
            HPAAutoscaler().destroy_collection("default", "managed=jac-scale");
            assert mock_client.CustomObjectsApi.return_value.list_namespaced_custom_object.call_count == 2;
        }
    }
}

test "image registry factory register and create custom registry" {
    mock_registry = unittest.mock.MagicMock();

    def custom_factory(config: dict) -> object {
        mock_registry.config = config;
        return mock_registry;
    }

    ImageRegistryFactory.register("custom-registry", custom_factory);
    config = {"username": "test", "password": "test"};
    result = ImageRegistryFactory.create("custom-registry", config);
    assert result is mock_registry;
    assert result.config == config;
    # Clean up registry
    del ImageRegistryFactory._registry["custom-registry"];
}
