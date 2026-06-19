"""Unit tests for KEDAAutoscaler.

All tests run without a real cluster — cluster I/O is replaced by a
MagicMock injected via the _custom_api constructor parameter.

IMPORTANT: KEDAAutoscaler._preflight_cache is a class-level dict shared
across the process. Every test that calls preflight() or apply() MUST call
KEDAAutoscaler._preflight_cache.clear() at its start to prevent a cached
result from a previous test leaking into the current one.
"""

import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.abstractions.autoscalers.keda_autoscaler { KEDAAutoscaler }
import from jac_scale.abstractions.autoscaler { AutoscalerSpec, Trigger, TriggerAuth }


# ─────────────────────────────────────────────────────────────────────────────
# _build_trigger
# ─────────────────────────────────────────────────────────────────────────────
test "cpu trigger is translated to KEDA Utilization format" {
    # HPA uses a nested resource+averageUtilization shape; KEDA expects a flat
    # metricType + metadata.value pair.  A wrong mapping produces a ScaledObject
    # KEDA accepts but never acts on.
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(type="cpu", metadata={"averageUtilization": "70"})
    );
    assert result["type"] == "cpu";
    assert result["metricType"] == "Utilization";
    assert result["metadata"]["value"] == "70";
    # metricType must NOT appear inside metadata — that would also break KEDA
    assert "metricType" not in result["metadata"];
}

test "memory trigger uses its own default 80 when metadata is empty" {
    # cpu and memory share the same code structure but have different defaults
    # (50 for cpu, 80 for memory).  Passing empty metadata exercises the default
    # branch; checking "80" confirms we hit the memory branch, not the cpu one.
    keda = KEDAAutoscaler();
    result = keda._build_trigger(Trigger(type="memory", metadata={}));
    assert result["type"] == "memory";
    assert result["metricType"] == "Utilization";
    assert result["metadata"]["value"] == "80";
}

test "non-resource trigger metadata integer values are coerced to strings" {
    # TOML parses `threshold = 100` as int.  KEDA's admission webhook rejects
    # ScaledObject metadata with non-string values (HTTP 422).  Coercion here
    # prevents a silent deploy-time failure.
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
    # prometheus is pass-through: no metricType wrapper
    assert "metricType" not in result;
}

test "trigger name is propagated to KEDA trigger dict" {
    # The name field is the base for TriggerAuthentication resource names;
    # dropping it breaks authenticationRef resolution.
    keda = KEDAAutoscaler();
    result = keda._build_trigger(
        Trigger(type="redis", metadata={}, name="redis-queue")
    );
    assert result["name"] == "redis-queue";
}

test "trigger with auth adds authenticationRef whose name matches the created TriggerAuthentication" {
    # The ScaledObject's authenticationRef.name must exactly match the name that
    # _apply_trigger_auth uses when it creates the TriggerAuthentication resource.
    # A mismatch means KEDA can't resolve the secret and the trigger never fires.
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


# ─────────────────────────────────────────────────────────────────────────────
# _build_manifests
# ─────────────────────────────────────────────────────────────────────────────
test "build manifests produces a complete and valid ScaledObject body" {
    # Covers: apiVersion, kind, metadata labels (needed by destroy_collection),
    # scaleTargetRef, replica bounds, and trigger content in one shot.
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
    # idleReplicaCount: 0 is the KEDA mechanism that drops replicas to zero
    # when all triggers go inactive.  Without it KEDA respects minReplicaCount
    # as a hard floor and scale-to-zero never happens.
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", idle_replicas=0
    );
    m = keda._build_manifests(spec);
    assert m["body"]["spec"]["idleReplicaCount"] == 0;
}

test "build manifests omits idleReplicaCount when not configured" {
    # Absent field and field=0 have different semantics in KEDA.  Absent means
    # "use minReplicaCount as floor"; present means "scale to exactly this value".
    # Emitting 0 when the user didn't ask for it silently changes scaling behavior.
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", idle_replicas=None
    );
    m = keda._build_manifests(spec);
    assert "idleReplicaCount" not in m["body"]["spec"];
}

test "build manifests adds initialCooldownPeriod when set above zero" {
    # A non-zero value delays scale-to-zero after a fresh deploy so slow-booting
    # apps are not killed before their first request arrives.
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
    # The default is 0, which means no delay.  Emitting initialCooldownPeriod: 0
    # on clusters that interpret 0 differently from absent could suppress KEDA's
    # natural warm-up period.  Keep the field absent unless explicitly requested.
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
    # autoscaler_engine = "keda" with no triggers defined should still autoscale
    # on CPU as it did under HPA.  An empty triggers array is rejected by KEDA.
    keda = KEDAAutoscaler();
    spec = AutoscalerSpec(
        scale_target_name="svc-deployment", namespace="default", triggers=[]
    );
    m = keda._build_manifests(spec);
    assert len(m["body"]["spec"]["triggers"]) == 1;
    assert m["body"]["spec"]["triggers"][0]["type"] == "cpu";
}

test "build manifests includes every trigger in the ScaledObject spec" {
    # The common real-world deployment uses CPU as a floor plus one event-driven
    # trigger.  If only the first trigger makes it into the ScaledObject, the
    # event-driven signal is silently ignored.
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
    # Resolved precedence rule: engine=keda + [hpa] block coexist.  The [hpa]
    # block contributes min/max/cpu_target (expressed as a cpu Trigger); the
    # [[triggers]] block adds event-driven triggers.  Both must appear in the
    # ScaledObject — dropping the cpu trigger removes the floor, dropping the
    # event trigger defeats the purpose of using KEDA.
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


# ─────────────────────────────────────────────────────────────────────────────
# preflight
# ─────────────────────────────────────────────────────────────────────────────
test "preflight returns empty list when KEDA CRDs are installed" {
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {"items": []};
    keda = KEDAAutoscaler(_custom_api=mock_api);
    assert keda.preflight() == [];
}

test "preflight returns warning with kubectl install command when cluster returns 404" {
    # The install one-liner is the actionable output an operator uses to unblock
    # themselves.  A missing or wrong URL in the warning leaves them with no path
    # forward when KEDA is not installed.
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
    # Some Kubernetes distributions (OpenShift, certain EKS builds) return 422
    # instead of 404 when a CRD group does not exist.  Without this branch the
    # exception propagates and the deploy crashes instead of degrading gracefully.
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.side_effect = ApiException(status=422);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    warnings = keda.preflight();
    assert len(warnings) == 1;
    assert "KEDA CRDs not found" in warnings[0];
}

test "preflight result is cached so the API is called only once across two calls" {
    # preflight() is called once per service inside apply().  A 10-service deploy
    # must not make 10 identical CRD-check API calls; the cache absorbs calls 2-N.
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {"items": []};
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.preflight();
    keda.preflight();
    assert mock_api.list_cluster_custom_object.call_count == 1;
}


# ─────────────────────────────────────────────────────────────────────────────
# apply
# ─────────────────────────────────────────────────────────────────────────────
test "apply skips ScaledObject creation when KEDA CRDs are not installed" {
    # This is the graceful-degrade path: deploy succeeds, autoscaling is absent.
    # If apply() raised here the entire jac start --scale would fail on any
    # cluster where KEDA is not installed.
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
    # The operator's only signal that autoscaling is silently absent is this log
    # line.  If apply() calls preflight() but discards the returned warnings, the
    # deployment appears healthy and the missing KEDA install is invisible.
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
    # KEDA validates the ScaledObject at admission time and rejects it if the
    # referenced TriggerAuthentication does not already exist.  Reversing the
    # order produces a 422 error on the ScaledObject create that is hard to
    # diagnose because both resources exist after a retry.
    KEDAAutoscaler._preflight_cache.clear();
    mock_api = unittest.mock.MagicMock();
    mock_api.list_cluster_custom_object.return_value = {};
    mock_api.get_namespaced_custom_object.side_effect = [
        ApiException(status=404),  # TriggerAuthentication does not exist yet
        ApiException(status=404)  # ScaledObject does not exist yet
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
    # First jac start --scale on a fresh environment.  The correct K8s verb is
    # create; using patch on a non-existent resource returns 404 and leaves the
    # deployment without autoscaling.
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
    # jac start --scale on a running service must not crash with AlreadyExists.
    # Patch preserves KEDA's internal state (currentReplicas, lastScaleTime)
    # that delete+create would reset, potentially causing a brief scale-to-zero.
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


# ─────────────────────────────────────────────────────────────────────────────
# engine-switch cleanup
# ─────────────────────────────────────────────────────────────────────────────
test "apply deletes competing HPA when switching from hpa engine to keda" {
    # If an operator switches autoscaler_engine from hpa to keda and redeploys,
    # the old HPA stays on the cluster and fights the new ScaledObject for
    # spec.replicas.  apply() must attempt to remove it before writing the
    # ScaledObject.  A 404 (no HPA present) must be silently ignored.
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
    # 404 on the HPA delete means there was nothing to clean up; must not raise.
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
    # destroy_collection is called on jac start --scale --destroy.  Any HPA left
    # from a prior hpa-engine deploy must be removed alongside ScaledObjects.
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.return_value = {"items": []};
    mock_v2 = unittest.mock.MagicMock();
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=mock_v2);
    keda.destroy_collection("default", "managed=jac-scale");
    mock_v2.delete_collection_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
        namespace="default", label_selector="managed=jac-scale"
    );
}

# ─────────────────────────────────────────────────────────────────────────────
# destroy
# ─────────────────────────────────────────────────────────────────────────────
test "destroy calls delete with the correct plural and resource name" {
    # Using the wrong plural (e.g. scaledobject vs scaledobjects) returns 404 and
    # leaves the ScaledObject running.  The test pins the exact API call shape.
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
    # jac start --scale --destroy after a partially failed deploy should not
    # crash.  The ScaledObject may never have been created.
    mock_api = unittest.mock.MagicMock();
    mock_api.delete_namespaced_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api);
    keda.destroy("my-svc-scaledobject", "staging");
    # reaching here without an exception is the assertion
}


# ─────────────────────────────────────────────────────────────────────────────
# destroy_collection
# ─────────────────────────────────────────────────────────────────────────────
test "destroy collection removes all labeled ScaledObjects and TriggerAuthentications" {
    # --destroy must clean up both resource types.  Orphaned TriggerAuthentications
    # accumulate across deploys and hold stale references to secrets that may be
    # rotated or deleted independently.
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
    # jac start --scale --destroy on a cluster that never had KEDA installed
    # must not crash.  Operators tear down staging environments regularly.
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.side_effect = ApiException(status=404);
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
    # reaching here without an exception is the assertion
}

test "destroy collection is silent when cluster returns 422 for absent CRD group" {
    # Some distributions return 422 instead of 404 when the keda.sh API group
    # does not exist.  Both must be treated as "nothing to delete".
    mock_api = unittest.mock.MagicMock();
    mock_api.list_namespaced_custom_object.side_effect = ApiException(status=422);
    keda = KEDAAutoscaler(_custom_api=mock_api, _v2_api=unittest.mock.MagicMock());
    keda.destroy_collection("staging", "managed=jac-scale");
    # reaching here without an exception is the assertion
}
