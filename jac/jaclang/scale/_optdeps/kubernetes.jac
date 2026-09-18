with entry {
    try {
        import from kubernetes { client, config, watch }
        import from kubernetes.client {
            AppsV1Api,
            AutoscalingV2Api,
            CustomObjectsApi,
            V2CrossVersionObjectReference,
            V2HorizontalPodAutoscaler,
            V2HorizontalPodAutoscalerSpec,
            V2MetricSpec,
            V2ResourceMetricSource
        }
        import from kubernetes.client.exceptions { ApiException }
        import from kubernetes.config.config_exception { ConfigException }
        import from kubernetes.watch { Watch }
        HAS_KUBERNETES = True;
    } except ImportError {
        client = None;
        config = None;
        watch = None;
        ApiException = Exception;
        ConfigException = Exception;
        AppsV1Api = None;
        AutoscalingV2Api = None;
        CustomObjectsApi = None;
        V2CrossVersionObjectReference = None;
        V2HorizontalPodAutoscaler = None;
        V2HorizontalPodAutoscalerSpec = None;
        V2MetricSpec = None;
        V2ResourceMetricSource = None;
        Watch = None;
        HAS_KUBERNETES = False;
    }
}
