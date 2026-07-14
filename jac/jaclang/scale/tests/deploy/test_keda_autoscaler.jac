import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth
}


test "cpu trigger is translated to KEDA Utilization format" {
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(type="cpu", metadata={"averageUtilization": "70"})
    );
    assert result["type"] == "cpu";
    assert result["metricType"] == "Utilization";
    assert result["metadata"]["value"] == "70";

    assert "metricType" not in result["metadata"];
}

test "memory trigger uses its own default 80 when metadata is empty" {
    keda = KEDAAutoscaler();
    result = keda._build_trigger(Trigger(type="memory", metadata={}));
    assert result["type"] == "memory";
    assert result["metricType"] == "Utilization";
    assert result["metadata"]["value"] == "80";
}

test "non-resource trigger metadata integer values are coerced to strings" {
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(
            type="prometheus",
            metadata={"serverAddress": "http://prom:9090", "threshold": 100}
        )
    );
    assert result["type"] == "prometheus";
    assert result["metadata"]["threshold"] == "100";
    assert result["metadata"]["serverAddress"] == "http://prom:9090";

    assert "metricType" not in result;
}

test "trigger name is propagated to KEDA trigger dict" {
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(type="redis", metadata={}, name="redis-queue")
    );
    assert result["name"] == "redis-queue";
}

test "trigger with auth adds authenticationRef whose name matches the created TriggerAuthentication" {
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(
            type="redis",
            metadata={},
            name="redis-queue",
            auth=TriggerAuth(
                secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
            )
        )
    );
    assert result["authenticationRef"] == {"name": "redis-queue-trigger-auth"};
}


test "build manifests produces a complete and valid ScaledObject body" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="orders-deployment",
        namespace="staging",
        min_replicas=2,
        max_replicas=10,
        triggers=[Trigger(type="cpu", metadata={"averageUtilization": "60"})]
    );
    m = keda._build_manifests(spec);
    assert m["name"] == "orders-deployment-scaledobject";
    assert m["body"]["apiVersion"] == "keda.sh/v1alpha1";
    assert m["body"]["kind"] == "ScaledObject";
    assert m["body"]["metadata"]["labels"]["managed"] == "jac-scale";
    assert m["body"]["spec"]["scaleTargetRef"]["name"] == "orders-deployment";
    assert m["body"]["spec"]["minReplicaCount"] == 2;
    assert m["body"]["spec"]["maxReplicaCount"] == 10;
    assert m["body"]["spec"]["triggers"][0]["metadata"]["value"] == "60";
}

test "build manifests adds idleReplicaCount zero for scale-to-zero" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", idle_replicas=0
    );
    m = keda._build_manifests(spec);
    assert m["body"]["spec"]["idleReplicaCount"] == 0;
}

test "build manifests omits idleReplicaCount when not configured" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", idle_replicas=None
    );
    m = keda._build_manifests(spec);
    assert "idleReplicaCount" not in m["body"]["spec"];
}

test "build manifests adds initialCooldownPeriod when set above zero" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        initial_cooldown_period=120
    );
    m = keda._build_manifests(spec);
    assert m["body"]["spec"]["initialCooldownPeriod"] == 120;
}

test "build manifests omits initialCooldownPeriod when zero" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        initial_cooldown_period=0
    );
    m = keda._build_manifests(spec);
    assert "initialCooldownPeriod" not in m["body"]["spec"];
}

test "build manifests falls back to default cpu trigger when triggers list is empty" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", triggers=[]
    );
    m = keda._build_manifests(spec);
    assert len(m["body"]["spec"]["triggers"]) == 1;
    assert m["body"]["spec"]["triggers"][0]["type"] == "cpu";
}

test "build manifests includes every trigger in the ScaledObject spec" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[
            Trigger(type="cpu", metadata={"averageUtilization": "50"}),
            Trigger(
                type="prometheus",
                metadata={"threshold": "100", "query": "sum(rate(req[1m]))"}
            )
        ]
    );
    m = keda._build_manifests(spec);
    assert len(m["body"]["spec"]["triggers"]) == 2;
    assert m["body"]["spec"]["triggers"][0]["type"] == "cpu";
    assert m["body"]["spec"]["triggers"][1]["type"] == "prometheus";
}

test "build manifests with hpa bounds and non-cpu trigger produces ScaledObject with both triggers" {
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="orders-deployment",
        namespace="staging",
        min_replicas=2,
        max_replicas=10,
        triggers=[
            Trigger(type="cpu", metadata={"averageUtilization": "60"}),
            Trigger(
                type="redis",
                metadata={
                    "address": "redis:6379",
                    "listName": "jobs",
                    "listLength": "10"
                },
                name="redis-jobs"
            )
        ]
    );
    m = keda._build_manifests(spec);
    assert m["body"]["spec"]["minReplicaCount"] == 2;
    assert m["body"]["spec"]["maxReplicaCount"] == 10;
    trigger_types = [t["type"] for t in m["body"]["spec"]["triggers"]];
    assert "cpu" in trigger_types;
    assert "redis" in trigger_types;
    assert len(trigger_types) == 2;
}


test "preflight returns empty list when KEDA CRDs are installed" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {"items": []};
    keda = KEDAAutoscaler(_custom_api=mock_api);
    assert keda.preflight() == [];
}

test "preflight returns warning with kubectl install command when cluster returns 404" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    warnings = keda.preflight();
    assert len(warnings) == 1;
    assert "KEDA CRDs not found" in warnings[0];
    assert "keda.sh/docs" in warnings[0];
}

test "preflight treats 422 the same as 404" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=422);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    warnings = keda.preflight();
    assert len(warnings) == 1;
    assert "KEDA CRDs not found" in warnings[0];
}

test "preflight result is cached so the API is called only once across two calls" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {"items": []};
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.preflight();
    keda.preflight();
    assert mock_api.list_cluster_custom_object.call_count == 1;
}


test "apply skips ScaledObject creation when KEDA CRDs are not installed" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    result = keda.apply(spec);
    assert result == False;
    mock_api.create_namespaced_custom_object.assert_not_called();
    mock_api.patch_namespaced_custom_object.assert_not_called();
}

test "apply logs the install docs link when KEDA CRDs are not installed" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=404);
    mock_logger = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api, logger=mock_logger);
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    keda.apply(spec);
    mock_logger.warn.assert_called_once();
    warn_msg = mock_logger.warn.call_args[0][0];
    assert "KEDA CRDs not found" in warn_msg;
    assert "keda.sh/docs" in warn_msg;
}

test "apply creates TriggerAuthentication before ScaledObject" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = [
        ApiException(status=404),
        ApiException(status=404)
    ];
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[
            Trigger(
                type="redis",
                metadata={"address": "redis:6379"},
                name="redis-queue",
                auth=TriggerAuth(
                    secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                )
            )
        ]
    );
    result = keda.apply(spec);
    assert result == True;
    create_calls = mock_api.create_namespaced_custom_object.call_args_list;
    assert len(create_calls) == 2;
    assert create_calls[0][1]["plural"] == "triggerauthentications";
    assert create_calls[1][1]["plural"] == "scaledobjects";
}

test "apply creates ScaledObject when it does not yet exist on the cluster" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    result = keda.apply(spec);
    assert result == True;
    create_calls = [
        c
        for c in mock_api.create_namespaced_custom_object.call_args_list
        if c[1].get("plural") == "scaledobjects"
    ];
    assert len(create_calls) == 1;
    mock_api.patch_namespaced_custom_object.assert_not_called();
}

test "apply patches ScaledObject when it already exists on the cluster" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.return_value = {
        "metadata": {"name": "svc-deployment-scaledobject"}
    };
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    result = keda.apply(spec);
    assert result == True;
    patch_calls = [
        c
        for c in mock_api.patch_namespaced_custom_object.call_args_list
        if c[1].get("plural") == "scaledobjects"
    ];
    assert len(patch_calls) == 1;
}


test "apply deletes competing HPA when switching from hpa engine to keda" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    mock_v2 = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    keda.apply(spec);
    mock_v2.delete_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
        name="svc-hpa", namespace="default"
    );
}

test "apply engine-switch HPA deletion is a no-op when no HPA exists" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = ApiException(status=404);
    mock_v2 = unittest.mock.MagicMock();
    mock_v2.delete_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
        status=404
    );
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment",
        app_name="svc",
        namespace="default",
        triggers=[Trigger(type="cpu", metadata={})]
    );
    result = keda.apply(spec);
    assert result == True;
}

test "destroy collection also sweeps competing HPAs" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.return_value = {"items": []};
    mock_v2 = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    keda.destroy_collection("default", "managed=jac-scale");
    mock_v2.delete_collection_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
        namespace="default", label_selector="managed=jac-scale"
    );
}

test "destroy calls delete with the correct plural and resource name" {
    mock_api = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy("my-svc-scaledobject", "staging");
    mock_api.delete_namespaced_custom_object.assert_called_once_with(
        group="keda.sh",
        version="v1alpha1",
        namespace="staging",
        plural="scaledobjects",
        name="my-svc-scaledobject"
    );
}

test "destroy is a no-op when the ScaledObject is already gone" {
    mock_api = unittest.mock.MagicMock();
    mock_api.delete_namespaced_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy("my-svc-scaledobject", "staging");
}


test "destroy collection removes all labeled ScaledObjects and TriggerAuthentications" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.return_value = {
        "items": [{"metadata": {"name": "svc-scaledobject"}}]
    };
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
    delete_calls = mock_api.delete_namespaced_custom_object.call_args_list;
    assert len(delete_calls) == 2;
    plurals = [c[1]["plural"] for c in delete_calls];
    assert "scaledobjects" in plurals;
    assert "triggerauthentications" in plurals;
}

test "destroy collection is silent when KEDA CRDs are not installed (404)" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
}

test "destroy collection is silent when cluster returns 422 for absent CRD group" {
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.side_effect = ApiException(status=422);
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
}
