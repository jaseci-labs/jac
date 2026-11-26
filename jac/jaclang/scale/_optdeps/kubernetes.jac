with entry {
    try {
        import from kubernetes { client, config, watch }
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
        import from kubernetes.stream { stream }
        import from urllib3 { exceptions as urllib3_exceptions }
        HTTPError: type[Exception] = urllib3_exceptions.HTTPError;
        HAS_KUBERNETES = True;
    } except ImportError {
        client = None;
        config = None;
        watch = None;
        stream = None;
        ApiException = Exception;
        ConfigException = Exception;
        HTTPError = Exception;
        AutoscalingV2Api = None;
        V2CrossVersionObjectReference = None;
        V2HorizontalPodAutoscaler = None;
        V2HorizontalPodAutoscalerSpec = None;
        V2MetricSpec = None;
        V2ResourceMetricSource = None;
        HAS_KUBERNETES = False;
    }
}
