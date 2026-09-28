import logging;

glob logger = logging.getLogger(__name__);


obj LocalRealizer {
    has fleet: FleetSpec,
        gateway_config: dict[str, any] = {};

    def serve {
        plan = plan_realization(False, len(self.fleet.members));
        logger.info(f"LocalRealizer: {plan.topology} in {plan.environment}");
        if plan.topology == TOPOLOGY_MICROSERVICE {
            start_fleet_mode(self.fleet, self.gateway_config);
        } else {
            logger.warning(
                "LocalRealizer: a single app is not a fleet; serve it in-process"
            );
        }
    }
}
