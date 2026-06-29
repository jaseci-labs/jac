"""Minimal jac-scale event-streaming example.
`jac start app.jac` and POST to /walker/place_order. With no Redis URL set this runs on LocalBroker; set `[plugins.scale.events].url` to use Redis Streams.
"""

import logging;
import from jac_scale.events.publisher { publish }
import from jac_scale.events.subscriber { subscribe }
import from jac_scale.events.broker { Event }

glob _logger = logging.getLogger("events-example");


# A walker that publishes on completion. Note: no broker reference
# needed at the call site; publish() finds the active broker via
# the events.publisher facade.
walker:pub place_order {
    has order_id: int,
        amount: float;

    can fire with Root entry {
        publish(
            "orders.placed",
            Event(
                data={"order_id": self.order_id, "amount": self.amount},
                source="place_order"
            )
        );
        report {"status": "queued", "order_id": self.order_id};
    }
}


# A subscriber. Registered at import time; wired up by the framework
# at server startup. Runs from a daemon consumer thread.
@subscribe("orders.placed")
def on_order_placed(event: Event) {
    _logger.info(
        f"order received: id={event.data.get('order_id')} "
        f"amount={event.data.get('amount')} event_id={event.id}"
    );
}
