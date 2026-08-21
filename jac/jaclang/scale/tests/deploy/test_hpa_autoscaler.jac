import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerState }


test "get_runtime_status returns unknown without touching the cluster when the HPA is missing" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        mock_v2 = mock_v2_cls.return_value;
        mock_v2.read_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
            status=404
        );
        status = HPAAutoscaler().get_runtime_status(
            "orders-hpa", "orders-deployment", "default"
        );
        assert status.state == AutoscalerState.UNKNOWN.value;
        mock_v2.create_namespaced_horizontal_pod_autoscaler.assert_not_called();
        mock_v2.patch_namespaced_horizontal_pod_autoscaler.assert_not_called();
        mock_v2.delete_namespaced_horizontal_pod_autoscaler.assert_not_called();
    }
}

test "get_runtime_status treats a 422 HPA read the same as not found" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        mock_v2_cls.return_value.read_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
            status=422
        );
        status = HPAAutoscaler().get_runtime_status(
            "orders-hpa", "orders-deployment", "default"
        );
        assert status.state == AutoscalerState.UNKNOWN.value;
    }
}

test "get_runtime_status re-raises a non-404/422 HPA read error instead of masking it" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        mock_v2_cls.return_value.read_namespaced_horizontal_pod_autoscaler.side_effect = ApiException(
            status=403
        );
        raised = False;
        try {
            HPAAutoscaler().get_runtime_status(
                "orders-hpa", "orders-deployment", "default"
            );
        } except ApiException as e {
            raised = True;
            assert e.status == 403;
        }
        assert raised , "Expected a 403 ApiException to propagate, not be swallowed";
    }
}

test "get_runtime_status normalizes a healthy HPA read from the cluster" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        mock_v2 = mock_v2_cls.return_value;
        mock_hpa = unittest.mock.MagicMock();
        mock_hpa.to_dict.return_value = {
            "metadata": {"resource_version": "9"},
            "status": {
                "current_replicas": 3,
                "desired_replicas": 3,
                "conditions": [
                    {
                        "type": "ScalingActive",
                        "status": "True",
                        "reason": "ValidMetricFound"
                    }
                ]
            }
        };
        mock_v2.read_namespaced_horizontal_pod_autoscaler.return_value = mock_hpa;
        status = HPAAutoscaler().get_runtime_status(
            "orders-hpa", "orders-deployment", "default"
        );
        assert status.state == AutoscalerState.ACTIVE.value;
        assert status.resource_version == "9";
        assert status.current_replicas == 3;
        assert status.desired_replicas == 3;
        mock_v2.read_namespaced_horizontal_pod_autoscaler.assert_called_once_with(
            name="orders-hpa", namespace="default"
        );
    }
}

test "get_runtime_status surfaces a degraded HPA without mutating the cluster" {
    with unittest.mock.patch(
        "jaclang.scale.deploy.autoscale.hpa_autoscaler.AutoscalingV2Api"
    ) as mock_v2_cls {
        mock_v2 = mock_v2_cls.return_value;
        mock_hpa = unittest.mock.MagicMock();
        mock_hpa.to_dict.return_value = {
            "status": {
                "current_replicas": 1,
                "desired_replicas": 1,
                "conditions": [
                    {
                        "type": "ScalingActive",
                        "status": "False",
                        "reason": "FailedGetResourceMetric"
                    }
                ]
            }
        };
        mock_v2.read_namespaced_horizontal_pod_autoscaler.return_value = mock_hpa;
        status = HPAAutoscaler().get_runtime_status(
            "orders-hpa", "orders-deployment", "default"
        );
        assert status.state == AutoscalerState.DEGRADED.value;
        mock_v2.create_namespaced_horizontal_pod_autoscaler.assert_not_called();
        mock_v2.patch_namespaced_horizontal_pod_autoscaler.assert_not_called();
        mock_v2.delete_namespaced_horizontal_pod_autoscaler.assert_not_called();
    }
}
