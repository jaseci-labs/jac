class UtilityFactory {
    static def create_logger(
        logger_type: str = 'standard', config: (dict[str, any] | None) = None
    ) -> Logger;

    static def create_metrics(
        metrics_type: str = 'prometheus',
        config: (dict[str, any] | None) = None,
        worker_count: int = 1
    ) -> MetricsCollector;
}
