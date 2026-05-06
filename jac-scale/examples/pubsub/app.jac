"""Minimal jac-scale pub/sub example.

Run with a local Redis listening on 6379:

    docker run -d --name jac-pubsub-redis -p 6379:6379 redis:7-alpine
    jac scale start app.jac

Then trigger the publisher:

    curl -X POST http://localhost:8000/walker/place_order \
         -H 'Content-Type: application/json' \
         -d '{"order_id": 42, "amount": 99.5}'

The on_order_placed handler will print the event from a daemon
consumer thread.
"""

import logging;
import from jac_scale.events.publisher { publish }
import from jac_scale.events.subscriber { subscribe }
import from jac_scale.abstractions.pubsub { Event }

glob _logger = logging.getLogger("pubsub-example");


# A walker that publishes on completion. Note: no broker reference
# needed at the call site; publish() finds the active broker via
# the events.publisher facade.
walker place_order {
    has order_id: int;
    has amount: float;

    can fire with `root entry {
        publish("orders.placed", Event(
            event_type="orders.placed",
            data={"order_id": self.order_id, "amount": self.amount},
            source="place_order"
        ));
        report {"status": "queued", "order_id": self.order_id};
    }
}


# A subscriber. Registered at import time; wired up by the framework
# at server startup. Runs from a daemon consumer thread.
@subscribe("orders.placed")
def on_order_placed(event: Event) -> None {
    _logger.info(
        f"order received: id={event.data.get('order_id')} "
        f"amount={event.data.get('amount')} event_id={event.id}"
    );
}
