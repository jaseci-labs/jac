"""Guarded re-exports for kubernetes (install group: [deploy])."""

with entry {
    try {
        import from kubernetes { client, config }
        import from kubernetes.client {
            AutoscalingV2Api,
            V2CrossVersionObjectReference,
            V2HorizontalPodAutoscaler,
            V2HorizontalPodAutoscalerSpec,
            V2MetricSpec,
            V2ResourceMetricSource
        }
        import from kubernetes.client.exceptions { ApiException }
        import from kubernetes.config.config_exception { ConfigException }
        HAS_KUBERNETES = True;
    } except ImportError {
        client = None;
        config = None;
        ApiException = Exception;
        ConfigException = Exception;
        AutoscalingV2Api = None;
        V2CrossVersionObjectReference = None;
        V2HorizontalPodAutoscaler = None;
        V2HorizontalPodAutoscalerSpec = None;
        V2MetricSpec = None;
        V2ResourceMetricSource = None;
        HAS_KUBERNETES = False;
    }
}
