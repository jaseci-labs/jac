import logging;

glob logger = logging.getLogger(__name__);


obj LocalRealizer {
    has fleet: FleetSpec,
        gateway_config: dict[str, any] = {};

    def serve;
}
