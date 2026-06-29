import logging;
import from jac_scale.runtime.planner.planner {
    plan_realization,
    TOPOLOGY_MICROSERVICE
}
import from jac_scale.runtime.discovery.discovery { should_enter_local_ms }
import from jac_scale.runtime.orchestrator.orchestrator { start_microservice_mode }

glob logger = logging.getLogger(__name__);


obj LocalRealizer {
    has ms_config: dict[str, any];

    def _service_count -> int {
        routes: dict[str, any] = dict(self.ms_config.get("routes", {}));
        return len(routes);
    }

    def should_serve(enabled: (bool | None)) -> bool {
        return should_enter_local_ms(enabled, False, False, self._service_count() > 0);
    }

    def serve {
        plan = plan_realization(False, self._service_count() + 1);
        logger.info(
            f"LocalRealizer: {plan.topology} via {plan.gateway_mode} gateway, " + f"{plan.transport} transport, {plan.state_backend} state"
        );
        if plan.topology == TOPOLOGY_MICROSERVICE {
            start_microservice_mode(self.ms_config);
        }
    }
}
