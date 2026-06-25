"""LocalRealizer: serve an app on the developer's machine per the RealizationPlan.

The local environment has two topology cells:
  monolith     - the single app is served in-process by core's app server; the
                 realizer declines (returns False) so core serves it. This is the
                 embedded cell: core's JFastApiServer already provides the app, its
                 middleware, and jac-scale's enhanced JacAPIServer features, so the
                 monolith needs no separate gateway.
  microservice - a real-process fleet fronted by the ProcessGateway (the Gateway
                 port's out-of-process adapter), run by the orchestrator.

Both cells run through the same ports: the ProcessGateway serves the fleet via the
Gateway port; the EmbeddedGateway (the in-process Gateway adapter, paired with an
InProcessTransport) is the in-process collapse of a fleet into one process - a
local-dev realization whose live `jac start` wiring is the remaining step.

The pre-hook asks the realizer to decide and dispatch; it never branches on
topology itself.
"""

import logging;
import from jac_scale.runtime.planner.planner {
    plan_realization,
    TOPOLOGY_MICROSERVICE
}
import from jac_scale.runtime.discovery.discovery { should_enter_local_ms }
import from jac_scale.runtime.orchestrator.orchestrator { start_microservice_mode }

glob logger = logging.getLogger(__name__);


"""Serves the local cells. `ms_config` is the resolved
[plugins.scale.microservices] table (with routes already discovered/declared)."""
obj LocalRealizer {
    has ms_config: dict[str, any];

    """Number of declared/discovered services in the blueprint."""
    def _service_count -> int {
        routes: dict[str, any] = dict(self.ms_config.get("routes", {}));
        return len(routes);
    }

    """True when this app should be served as a local microservice fleet (the
    process-gateway topology). False means a monolith that core serves in-process.
    `enabled` is the [plugins.scale.microservices].enabled tri-state override."""
    def should_serve(enabled: (bool | None)) -> bool {
        return should_enter_local_ms(
            enabled, False, False, self._service_count() > 0
        );
    }

    """Serve the microservice topology and block on the gateway. Only call after
    should_serve() returns True. Blocks until the gateway shuts down."""
    def serve -> None {
        plan = plan_realization(False, self._service_count());
        logger.info(
            f"LocalRealizer: {plan.topology} via {plan.gateway_mode} gateway, "
            + f"{plan.transport} transport, {plan.state_backend} state"
        );
        if plan.topology == TOPOLOGY_MICROSERVICE {
            start_microservice_mode(self.ms_config);
        }
    }
}
