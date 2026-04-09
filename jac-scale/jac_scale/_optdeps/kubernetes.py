"""Guarded re-exports for kubernetes (install group: [deploy])."""

try:
    from kubernetes import client, config
    from kubernetes.client import (
        AutoscalingV2Api,
        V2CrossVersionObjectReference,
        V2HorizontalPodAutoscaler,
        V2HorizontalPodAutoscalerSpec,
        V2MetricSpec,
        V2ResourceMetricSource,
    )
    from kubernetes.client.exceptions import ApiException
    from kubernetes.config.config_exception import ConfigException

    HAS_KUBERNETES = True
except ImportError:
    client = None
    config = None
    ApiException = Exception
    ConfigException = Exception
    AutoscalingV2Api = None
    V2CrossVersionObjectReference = None
    V2HorizontalPodAutoscaler = None
    V2HorizontalPodAutoscalerSpec = None
    V2MetricSpec = None
    V2ResourceMetricSource = None

    HAS_KUBERNETES = False
